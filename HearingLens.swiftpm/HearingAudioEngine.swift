// F-01 filter application (audio engine) / F-05 relax switch (ramped) / F-06 headphone detection, feedback prevention, interruptions / F-07 test sound mode (provisional: noise only) / F-04 level meter (not implemented)
//
// Node graph (signal flow):
//   inputNode ──┐
//               ├→ sourceMixer → eq (5 fixed bands) → reverb → dynamics (threshold) → limiter (peak limiter) → mainMixerNode → output
//   noiseNode ──┘
//   (For the F-07 speaking voice, an AVAudioPlayerNode will be added to sourceMixer later.)
// - Nodes are created and attached once in init, and reconnected on every start()
//   (because the input format changes with the current route).
// - The EQ has five bands with fixed roles: high-pass x2, low-pass x2 (two stages = 24 dB/oct) and one peak.
//   All bands are always enabled; unused bands ramp to a neutral value (HPF 20 Hz / LPF 20 kHz / peak 0 dB).
//   The APD band-pass is built from HPF + LPF. Switching profiles never reconnects nodes (avoids dropouts).
// - Values are not jumped: profile switches, the F-05 toggle and tuning changes all go through retarget(),
//   which ramps the applied values to the new target over 0.3 s (log interpolation for frequencies, smoothstep easing).
// - Low latency (ADR-0003): shrink the IO buffer to about 5 ms to reduce the delay before your own voice comes back.
// - Per-source audio session (ADR-0003): microphone uses .playAndRecord + A2DP, test sound uses .playback.
//   Input is pinned to the built-in microphone; the call-oriented HFP is not used.
// - Hearing protection (ADR-0002): dynamics processor + limiter + output volume cap + fade-in from 0.
//   A user-initiated stop uses a short fade-out; unplugging headphones, interruptions and configuration changes stop immediately.
import AVFoundation
import AudioToolbox
import Observation
import os

/// F-04 voice level feedback kinds
enum VolumeFeedback {
    case tooQuiet   // voice too quiet (too far away)
    case tooLoud    // too loud (harsh for hyperacusis)
    case good       // just right
}

/// A small component that generates ambient noise (pink-noise-like).
/// The AVAudioSourceNode render block runs on a dedicated audio thread and cannot touch the MainActor.
/// So the state (filter memory, random seed) is gathered in this class and used from the block.
/// The render block is only called from a single thread, so this is `@unchecked Sendable` without locking.
private final class PinkNoiseGenerator: @unchecked Sendable {
    // Internal state of Paul Kellet's economy pink filter (memory of past values)
    private var b0: Float = 0
    private var b1: Float = 0
    private var b2: Float = 0
    /// Random number state (xorshift). System randomness is unsuited to real-time processing, so we keep our own
    private var seed: UInt32 = 0x1234_5678

    /// Output scale. The synthesized pink value can reach several times ±1, so shrink it to about ±0.2 (rule-of-thumb value)
    private static let outputScale: Float = 0.11

    /// Returns one white-noise value in -1...1
    private func nextWhite() -> Float {
        seed ^= seed << 13
        seed ^= seed >> 17
        seed ^= seed << 5
        // Map the full UInt32 range onto -1...1
        return Float(seed) / Float(UInt32.max) * 2 - 1
    }

    /// One sample of pink-noise-like value. White noise is shaped by three filter stages so lower sounds are stronger
    func nextSample() -> Float {
        let white = nextWhite()
        b0 = 0.99765 * b0 + white * 0.0990460
        b1 = 0.96300 * b1 + white * 0.2965164
        b2 = 0.57000 * b2 + white * 1.0526913
        return (b0 + b1 + b2 + white * 0.1848) * Self.outputScale
    }
}

/// Creates the AVAudioSourceNode. Creating it outside the MainActor (nonisolated)
/// keeps the render block from inheriting MainActor isolation.
private nonisolated func makeNoiseNode(format: AVAudioFormat) -> AVAudioSourceNode {
    let generator = PinkNoiseGenerator()
    return AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        for buffer in buffers {
            guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
            for frame in 0..<Int(frameCount) {
                data[frame] = generator.nextSample()
            }
        }
        return noErr
    }
}

/// Roles of the fixed EQ bands. Each role is decided up front and never reconnected when switching profiles.
/// The high-pass and low-pass each use `passFilterStages` bands with identical values (stacked = steeper slope).
///
/// | Role | Type | Used by profile |
/// |---|---|---|
/// | highPass | high-pass (x stages) | Low-Frequency Hearing Loss, APD (lower edge) |
/// | lowPass | low-pass (x stages) | High-Frequency Hearing Loss, APD (upper edge) |
/// | peak | parametric (peak EQ) | Hyperacusis |
private enum EQRole {
    case highPass
    case lowPass
    case peak
}

/// Values written to the nodes right now (the ramp moves these toward the target).
private struct AppliedState: Equatable {
    var hpCutoff: Float
    var lpCutoff: Float
    var peakFrequency: Float
    var peakGain: Float
    var peakBandwidth: Float
    /// Reverb wet 0...100
    var wet: Float
    /// noiseNode.volume
    var noise: Float
    /// Reverb preset currently loaded in the node (nil = never loaded)
    var reverbPreset: AVAudioUnitReverbPreset?
}

/// Debug log. In the Xcode console, look at category "audio"
private let audioLogger = Logger(subsystem: "com.koresawa.HearingLens", category: "audio")

@Observable
@MainActor
final class HearingAudioEngine {
    // MARK: State
    var selectedProfile: HearingProfile = .highFrequencyLoss {
        didSet { retarget() }
    }
    var mode: ExperienceMode = .daily
    /// User volume (0...outputCap). Starts low.
    var outputVolume: Float = 0.3 {
        didSet {
            let clamped = min(max(outputVolume, 0), outputCap)
            if clamped != outputVolume {
                outputVolume = clamped
                return
            }
            // Apply immediately while running, but not during fade-in/out handling
            if isRunning && !isStopping && !isFadingIn {
                engine.mainMixerNode.outputVolume = outputVolume
            }
        }
    }
    /// True while the fade-in is raising the volume
    @ObservationIgnored private var isFadingIn = false
    private(set) var isRunning = false
    /// Fading out (mid-stop). The UI disables the button during this time
    private(set) var isStopping = false
    private(set) var isHeadphoneConnected = false
    /// Whether the output is Bluetooth (large delay, so the UI shows a notice)
    private(set) var isBluetoothOutput = false
    var useTestSource = false {
        didSet {
            retarget()
            // Stop if this changes while running so the session category never disagrees with the mode (restart is a user action)
            if isRunning && useTestSource != oldValue {
                stopImmediately()
            }
        }
    }
    /// F-05 Practice the tips (ON relaxes the filter)
    var isAdviceApplied = false {
        didSet { retarget() }
    }

    // MARK: Tuning state (not saved; the Tuning panel edits these)
    /// Filter values per profile. Starts from `profile.filter`; the Tuning panel edits them
    var tunedFilters: [HearingProfile: FilterParameters] = Dictionary(
        uniqueKeysWithValues: HearingProfile.allCases.map { ($0, $0.filter) }
    ) {
        didSet { retarget() }
    }
    /// F-05 relax multipliers
    var relaxFactors = RelaxFactors() {
        didSet { retarget() }
    }
    /// DynamicsProcessor threshold in dB (0 = almost no compression)
    var limiterThresholdDB: Float = HearingAudioEngine.defaultLimiterThresholdDB {
        didSet {
            let clamped = min(max(limiterThresholdDB, Self.minLimiterThresholdDB), Self.maxLimiterThresholdDB)
            if clamped != limiterThresholdDB {
                limiterThresholdDB = clamped
                return
            }
            applyDynamicsSettings()
        }
    }
    /// User-adjustable output cap (minOutputCap...absoluteMaxOutputVolume)
    var outputCap: Float = HearingAudioEngine.absoluteMaxOutputVolume {
        didSet {
            let clamped = min(max(outputCap, Self.minOutputCap), Self.absoluteMaxOutputVolume)
            if clamped != outputCap {
                outputCap = clamped
                return
            }
            // Pull the user volume down if it is now above the cap
            if outputVolume > outputCap {
                outputVolume = outputCap
            }
        }
    }
    /// Microphone input level 0...1 (normalized RMS)
    /// TODO(F-04): install a tap on inputNode, compute RMS and reflect it here
    var inputLevel: Float = 0
    /// Microphone permission was denied (the UI points to Open Settings)
    private(set) var micPermissionDenied = false
    /// Message for showing the most recent error (nil means no error)
    var lastErrorMessage: String?

    // MARK: Thresholds (normalized levels 0...1)
    /// Below this is "too quiet"
    static let quietThreshold: Float = 0.15
    /// Above this is "too loud"
    static let loudThreshold: Float = 0.7

    // MARK: Hearing protection and audio constants (ADR-0002)
    /// Absolute output volume limit (0...1). Never exceeded in any case, to protect hearing (ADR-0002)
    static let absoluteMaxOutputVolume: Float = 0.6
    /// Lowest value the output cap can be tuned to
    static let minOutputCap: Float = 0.2
    /// DynamicsProcessor threshold: starting value in dB (nearly pass-through)
    static let defaultLimiterThresholdDB: Float = -3
    /// DynamicsProcessor threshold: tuning range in dB
    static let minLimiterThresholdDB: Float = -24
    static let maxLimiterThresholdDB: Float = 0
    /// DynamicsProcessor headroom in dB. Small means limiter-like (strong) compression above the threshold
    private static let dynamicsHeadRoomDB: Float = 1
    /// DynamicsProcessor expansion ratio. 1 disables expansion
    private static let dynamicsExpansionRatio: Float = 1
    /// DynamicsProcessor overall (make-up) gain in dB. 0 means no amplification
    private static let dynamicsOverallGainDB: Float = 0
    /// Total fade-in time (seconds). Avoids an abrupt thump at start
    private static let fadeInDuration: Double = 0.5
    /// Number of fade-in steps. The volume rises gradually over 10 steps across 0.5 seconds
    private static let fadeInSteps = 10
    /// Total fade-out time (seconds). Avoids a click when the user stops
    private static let fadeOutDuration: Double = 0.15
    /// Number of fade-out steps. The volume falls gradually over 6 steps across 0.15 seconds
    private static let fadeOutSteps = 6
    /// AVAudioSession IO buffer duration (seconds). Smaller means less delay (about 5 ms).
    /// Hearing your own voice come back late makes speaking hard (delayed auditory feedback). Too small causes dropouts, so use 5 ms (ADR-0003)
    private static let preferredIOBufferDuration: TimeInterval = 0.005
    /// Preferred sample rate (Hz). 48 kHz is the standard value for iPhone's built-in microphone and speaker
    private static let preferredSampleRate: Double = 48_000
    /// Minimum ambient noise volume in test sound mode. A provisional "sound is playing" check until the F-07 voice loop exists
    private static let testSourceMinimumNoiseVolume: Float = 0.3
    /// Default sample rate when the noise source node's rate is unavailable
    private static let fallbackSampleRate: Double = 44_100
    /// Bandwidth (octaves) used by the EQ low-pass/high-pass. A guide for how the response rises near the cutoff
    private static let passFilterBandwidth: Float = 0.5
    /// Number of stacked stages for the high-pass and low-pass. 2 stages = 24 dB/oct (1 stage = 12 dB/oct)
    private static let passFilterStages = 2
    /// Total EQ band count: high-pass stages + low-pass stages + one peak
    private static let eqBandCount = passFilterStages * 2 + 1
    /// Values that have no effect (a band stays enabled and moves to these when unused)
    private static let neutralHighPass: Float = 20
    private static let neutralLowPass: Float = 20_000
    private static let neutralPeakGain: Float = 0
    /// Starting peak frequency (Hz) and width (octaves) while the peak is unused
    private static let defaultPeakFrequency: Float = 1_000
    private static let defaultPeakBandwidth: Float = 1
    /// Maximum peak gain in dB (spec maximum, ADR-0002). Never exceeded
    private static let maxPeakGain: Float = 18
    /// Total ramp time in seconds when switching values
    private static let rampDuration: Double = 0.3
    /// Ramp update rate (frames per second)
    private static let rampFrameRate: Double = 60
    /// Share of the ramp spent lowering the reverb wet before a preset switch (the rest raises it again)
    private static let reverbSwitchSplit: Float = 0.5

    var volumeFeedback: VolumeFeedback {
        if inputLevel < Self.quietThreshold { return .tooQuiet }
        if inputLevel > Self.loudThreshold { return .tooLoud }
        return .good
    }

    /// The filter values to apply now (reflects the F-05 on/off state)
    var currentFilter: FilterParameters {
        let base = tunedFilters[selectedProfile] ?? selectedProfile.filter
        return isAdviceApplied ? base.relaxed(by: relaxFactors) : base
    }

    /// Whether starting is possible (headphones connected or test sound)
    var canStart: Bool { isHeadphoneConnected || useTestSource }

    // MARK: Nodes (created once in init)
    @ObservationIgnored private let engine = AVAudioEngine()
    /// Mixer that combines microphone and noise into one stream
    @ObservationIgnored private let sourceMixer = AVAudioMixerNode()
    /// EQ with five fixed bands. See bandIndex(_:stage:) for each band's role
    @ObservationIgnored private let eq = AVAudioUnitEQ(numberOfBands: HearingAudioEngine.eqBandCount)
    @ObservationIgnored private let reverb = AVAudioUnitReverb()
    /// Compressor in front of the limiter with an adjustable threshold (the PeakLimiter has none; ADR-0002 addendum)
    @ObservationIgnored private let dynamics = AVAudioUnitEffect(
        audioComponentDescription: AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_DynamicsProcessor,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
    )
    /// Peak limiter on the output stage (Apple's standard AudioUnit). Suppresses sudden loud sounds
    @ObservationIgnored private let limiter = AVAudioUnitEffect(
        audioComponentDescription: AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_PeakLimiter,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
    )
    @ObservationIgnored private let noiseNode: AVAudioSourceNode
    /// Mono format for the noise (used to connect the source node to the mixer)
    @ObservationIgnored private let noiseFormat: AVAudioFormat
    /// Whether the microphone input node is currently connected (not connected in test sound mode)
    @ObservationIgnored private var isInputConnected = false
    @ObservationIgnored private var fadeTask: Task<Void, Never>?
    /// Values currently written to the nodes (the ramp's starting point)
    @ObservationIgnored private var applied = AppliedState(
        hpCutoff: HearingAudioEngine.neutralHighPass,
        lpCutoff: HearingAudioEngine.neutralLowPass,
        peakFrequency: HearingAudioEngine.defaultPeakFrequency,
        peakGain: HearingAudioEngine.neutralPeakGain,
        peakBandwidth: HearingAudioEngine.defaultPeakBandwidth,
        wet: 0,
        noise: 0,
        reverbPreset: nil
    )
    @ObservationIgnored private var rampTask: Task<Void, Never>?

    // MARK: Initialization
    // NotificationCenter tokens are not touched in deinit, so the engine is assumed to live as long as the app
    @ObservationIgnored private var routeObserver: NSObjectProtocol?
    @ObservationIgnored private var interruptionObserver: NSObjectProtocol?
    @ObservationIgnored private var configurationObserver: NSObjectProtocol?

    init() {
        let sessionRate = AVAudioSession.sharedInstance().sampleRate
        let rate = sessionRate > 0 ? sessionRate : Self.fallbackSampleRate
        // Creating an AVAudioFormat rarely fails, but fall back instead of force-unwrapping
        let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)
            ?? AVAudioFormat(standardFormatWithSampleRate: Self.fallbackSampleRate, channels: 1)
            ?? AVAudioFormat()
        noiseFormat = format
        noiseNode = makeNoiseNode(format: format)

        setupNodes()
        refreshRoute()
        retarget()

        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // The Notification itself can't cross actors, so extract only the reason value (UInt) first
            let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor in
                self?.handleRouteChange(reasonValue: reasonValue)
            }
        }

        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // The Notification itself can't cross actors, so extract only the needed value (UInt) first
            let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            Task { @MainActor in
                self?.handleInterruption(typeValue: typeValue)
            }
        }

        // Engine configuration change (e.g. input/output format change). The engine stops itself, so sync our state
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleConfigurationChange()
            }
        }
    }

    /// Attaches nodes to the engine and sets initial EQ, dynamics and limiter values (connecting happens in start)
    private func setupNodes() {
        engine.attach(sourceMixer)
        engine.attach(noiseNode)
        engine.attach(eq)
        engine.attach(reverb)
        engine.attach(dynamics)
        engine.attach(limiter)

        // Each band's role (type) is fixed and set only once, here. Bands are never bypassed:
        // unused ones move to a neutral value instead (so switching causes no click)
        eq.globalGain = 0
        for stage in 0..<Self.passFilterStages {
            let hp = eq.bands[bandIndex(.highPass, stage: stage)]
            hp.filterType = .highPass
            hp.bandwidth = Self.passFilterBandwidth
            hp.frequency = Self.neutralHighPass
            hp.bypass = false

            let lp = eq.bands[bandIndex(.lowPass, stage: stage)]
            lp.filterType = .lowPass
            lp.bandwidth = Self.passFilterBandwidth
            lp.frequency = Self.neutralLowPass
            lp.bypass = false
        }
        let peakBand = eq.bands[bandIndex(.peak, stage: 0)]
        peakBand.filterType = .parametric
        peakBand.frequency = applied.peakFrequency
        peakBand.bandwidth = applied.peakBandwidth
        peakBand.gain = applied.peakGain
        peakBand.bypass = false

        applyDynamicsSettings()

        // Silent before starting. The fade-in raises it
        engine.mainMixerNode.outputVolume = 0
    }

    /// Band index for a role and stage: high-pass stages first, then low-pass stages, then the peak
    private func bandIndex(_ role: EQRole, stage: Int) -> Int {
        switch role {
        case .highPass: return stage
        case .lowPass: return Self.passFilterStages + stage
        case .peak: return Self.passFilterStages * 2
        }
    }

    /// Writes DynamicsProcessor parameters (threshold is tunable; the rest are fixed constants)
    private func applyDynamicsSettings() {
        let unit = dynamics.audioUnit
        let settings: [(AudioUnitParameterID, Float)] = [
            (kDynamicsProcessorParam_Threshold, limiterThresholdDB),
            (kDynamicsProcessorParam_HeadRoom, Self.dynamicsHeadRoomDB),
            (kDynamicsProcessorParam_ExpansionRatio, Self.dynamicsExpansionRatio),
            (kDynamicsProcessorParam_OverallGain, Self.dynamicsOverallGainDB)
        ]
        for (parameter, value) in settings {
            let status = AudioUnitSetParameter(unit, parameter, kAudioUnitScope_Global, 0, value, 0)
            if status != noErr {
                audioLogger.error("AudioUnitSetParameter \(parameter, privacy: .public) failed: \(status, privacy: .public)")
            }
        }
    }

    // MARK: F-01 Apply filters (target and ramp)
    /// Builds the target values from FilterParameters. Unused items become neutral (no-effect) values.
    private func makeTarget(from p: FilterParameters) -> AppliedState {
        var hp = Self.neutralHighPass
        var lp = Self.neutralLowPass
        if let bp = p.bandPass {
            // Band-pass = HPF at the lower edge + LPF at the upper edge (width in octaves around the center)
            let halfWidthFactor = pow(2, bp.bandwidth / 2)
            hp = bp.center / halfWidthFactor
            lp = bp.center * halfWidthFactor
        }
        if let cutoff = p.highPassCutoff { hp = cutoff }
        if let cutoff = p.lowPassCutoff { lp = cutoff }

        var target = applied
        target.hpCutoff = min(max(hp, Self.neutralHighPass), Self.neutralLowPass)
        target.lpCutoff = min(max(lp, Self.neutralHighPass), Self.neutralLowPass)
        if let peak = p.peakEQ {
            target.peakFrequency = peak.frequency
            target.peakGain = min(max(peak.gain, Self.neutralPeakGain), Self.maxPeakGain)
            target.peakBandwidth = peak.bandwidth
        } else {
            // Keep the frequency and width, only fade the gain to 0 dB
            target.peakGain = Self.neutralPeakGain
        }
        if let preset = p.reverbPreset {
            target.reverbPreset = preset
            target.wet = p.reverbWetDryMix
        } else {
            // Keep the loaded preset; just fade the wet to 0
            target.wet = 0
        }
        // Ambient noise volume is adjusted only through noiseNode.volume (the generator's scale is fixed).
        // In test sound mode, guarantee a minimum volume so you can tell sound is playing until the voice loop (F-07) exists
        target.noise = useTestSource
            ? max(p.noiseMix, Self.testSourceMinimumNoiseVolume)
            : p.noiseMix
        return target
    }

    /// Re-aims at the current filter values. Called by profile switches, the F-05 toggle and tuning changes.
    /// While stopped the values are applied immediately; while running they ramp from the currently applied values.
    private func retarget() {
        rampTask?.cancel()
        rampTask = nil
        let target = makeTarget(from: currentFilter)
        guard isRunning else {
            applyImmediately(target)
            return
        }
        let start = applied
        let frames = max(1, Int(Self.rampDuration * Self.rampFrameRate))
        let interval = 1 / Self.rampFrameRate
        rampTask = Task { @MainActor [weak self] in
            for frame in 1...frames {
                if Task.isCancelled { return }
                guard let self else { return }
                let progress = Float(frame) / Float(frames)
                self.applyRampFrame(from: start, to: target, progress: progress)
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    /// Applies the target at once with no ramp (before start, and after stopping)
    private func applyImmediately(_ target: AppliedState) {
        if let preset = target.reverbPreset, preset != applied.reverbPreset {
            reverb.loadFactoryPreset(preset)
            applied.reverbPreset = preset
        }
        applied = target
        writeToNodes(applied)
    }

    /// One ramp step. `progress` is the raw time share 0...1; the easing is applied inside
    private func applyRampFrame(from start: AppliedState, to target: AppliedState, progress: Float) {
        let t = Self.smoothstep(progress)
        var next = applied
        next.hpCutoff = Self.logInterpolate(start.hpCutoff, target.hpCutoff, t)
        next.lpCutoff = Self.logInterpolate(start.lpCutoff, target.lpCutoff, t)
        next.peakFrequency = Self.logInterpolate(start.peakFrequency, target.peakFrequency, t)
        next.peakGain = Self.linearInterpolate(start.peakGain, target.peakGain, t)
        next.peakBandwidth = Self.linearInterpolate(start.peakBandwidth, target.peakBandwidth, t)
        next.noise = Self.linearInterpolate(start.noise, target.noise, t)

        if target.reverbPreset == start.reverbPreset {
            next.wet = Self.linearInterpolate(start.wet, target.wet, t)
        } else if progress < Self.reverbSwitchSplit {
            // First half: lower the wet to 0 before swapping the preset
            let down = Self.smoothstep(progress / Self.reverbSwitchSplit)
            next.wet = Self.linearInterpolate(start.wet, 0, down)
        } else {
            if next.reverbPreset != target.reverbPreset, let preset = target.reverbPreset {
                // Loading a preset resets wetDryMix to its default, so set it back to 0 right away
                reverb.loadFactoryPreset(preset)
                reverb.wetDryMix = 0
                next.reverbPreset = preset
            }
            // Second half: raise the wet to the target
            let up = Self.smoothstep((progress - Self.reverbSwitchSplit) / (1 - Self.reverbSwitchSplit))
            next.wet = Self.linearInterpolate(0, target.wet, up)
        }
        applied = next
        writeToNodes(next)
    }

    /// Writes values to the nodes. Stacked stages always get identical values
    private func writeToNodes(_ state: AppliedState) {
        for stage in 0..<Self.passFilterStages {
            eq.bands[bandIndex(.highPass, stage: stage)].frequency = state.hpCutoff
            eq.bands[bandIndex(.lowPass, stage: stage)].frequency = state.lpCutoff
        }
        let peakBand = eq.bands[bandIndex(.peak, stage: 0)]
        peakBand.frequency = state.peakFrequency
        peakBand.gain = state.peakGain
        peakBand.bandwidth = state.peakBandwidth
        reverb.wetDryMix = state.wet
        noiseNode.volume = state.noise
    }

    /// Easing curve 3t^2 - 2t^3: starts and ends gently (zero slope at both ends)
    private static func smoothstep(_ t: Float) -> Float {
        t * t * (3 - 2 * t)
    }

    private static func linearInterpolate(_ from: Float, _ to: Float, _ t: Float) -> Float {
        from + (to - from) * t
    }

    /// Frequencies are heard on a log scale (equal ratios sound like equal steps), so interpolate by ratio
    private static func logInterpolate(_ from: Float, _ to: Float, _ t: Float) -> Float {
        from * pow(to / from, t)
    }

    // MARK: Tuning helpers (for the Tuning panel)
    /// Edits one profile's tuned filter values. The change ramps in through tunedFilters' didSet
    func updateTuned(_ profile: HearingProfile, _ edit: (inout FilterParameters) -> Void) {
        var filter = tunedFilters[profile] ?? profile.filter
        edit(&filter)
        tunedFilters[profile] = filter
    }

    /// Returns every tuning value to its starting value
    func resetTuning() {
        relaxFactors = RelaxFactors()
        limiterThresholdDB = Self.defaultLimiterThresholdDB
        outputCap = Self.absoluteMaxOutputVolume
        tunedFilters = Dictionary(uniqueKeysWithValues: HearingProfile.allCases.map { ($0, $0.filter) })
    }

    /// Swift code text of the current tuning values (for "Copy values"; paste it into HearingProfile.swift and the engine)
    func tuningSnapshotCode() -> String {
        var lines: [String] = ["// HearingLens tuning snapshot"]
        for profile in HearingProfile.allCases {
            let filter = tunedFilters[profile] ?? profile.filter
            lines.append("// \(profile.title)")
            lines.append("FilterParameters(\(Self.argumentText(for: filter)))")
        }
        let r = relaxFactors
        lines.append("RelaxFactors(lowPassMultiplier: \(Self.number(r.lowPassMultiplier)), highPassMultiplier: \(Self.number(r.highPassMultiplier)), bandwidthMultiplier: \(Self.number(r.bandwidthMultiplier)), gainFactor: \(Self.number(r.gainFactor)), wetFactor: \(Self.number(r.wetFactor)), noiseFactor: \(Self.number(r.noiseFactor)), lowPassMax: \(Self.number(r.lowPassMax)))")
        lines.append("limiterThresholdDB = \(Self.number(limiterThresholdDB))")
        lines.append("outputCap = \(Self.number(outputCap))")
        return lines.joined(separator: "\n")
    }

    /// Compact number text (no trailing zeros)
    private static func number(_ value: Float) -> String {
        String(format: "%g", Double(value))
    }

    /// The argument list of `FilterParameters(...)` for the non-nil items
    private static func argumentText(for f: FilterParameters) -> String {
        var args: [String] = []
        if let v = f.lowPassCutoff { args.append("lowPassCutoff: \(number(v))") }
        if let v = f.highPassCutoff { args.append("highPassCutoff: \(number(v))") }
        if let bp = f.bandPass {
            args.append("bandPass: (center: \(number(bp.center)), bandwidth: \(number(bp.bandwidth)))")
        }
        if let peak = f.peakEQ {
            args.append("peakEQ: (frequency: \(number(peak.frequency)), gain: \(number(peak.gain)), bandwidth: \(number(peak.bandwidth)))")
        }
        switch f.reverbPreset {
        case .smallRoom: args.append("reverbPreset: .smallRoom")
        case .mediumHall: args.append("reverbPreset: .mediumHall")
        default: break
        }
        if f.reverbWetDryMix != 0 { args.append("reverbWetDryMix: \(number(f.reverbWetDryMix))") }
        if f.noiseMix != 0 { args.append("noiseMix: \(number(f.noiseMix))") }
        return args.joined(separator: ", ")
    }

    // MARK: F-06 Headphone detection
    // HFP (.bluetoothHFP) is for calls with narrow bandwidth, so the high-frequency experience would not work; excluded (ADR-0003)
    private static let headphonePortTypes: Set<AVAudioSession.Port> = [
        .headphones, .bluetoothA2DP, .bluetoothLE, .usbAudio
    ]
    private static let bluetoothPortTypes: Set<AVAudioSession.Port> = [
        .bluetoothA2DP, .bluetoothLE
    ]

    /// Checks whether the current output route has headphones and reflects it
    func refreshRoute() {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        isHeadphoneConnected = outputs.contains { Self.headphonePortTypes.contains($0.portType) }
        isBluetoothOutput = outputs.contains { Self.bluetoothPortTypes.contains($0.portType) }
    }

    private func handleRouteChange(reasonValue: UInt?) {
        refreshRoute()
        guard isRunning else { return }
        let reason = reasonValue.flatMap { AVAudioSession.RouteChangeReason(rawValue: $0) }
        // Headphones removed: stop immediately without fading, to prevent feedback
        if reason == .oldDeviceUnavailable && !isHeadphoneConnected {
            stopImmediately()
            return
        }
        // Safety net: whatever the reason, stop if in microphone mode without headphones (test sound is exempt)
        // Do nothing for .newDeviceAvailable (connected). Never start automatically; wait for the user
        if !useTestSource && !isHeadphoneConnected {
            stopImmediately()
        }
    }

    // MARK: Interruptions (calls, Siri, etc.)
    private func handleInterruption(typeValue: UInt?) {
        guard let typeValue, let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        // Stop immediately when it begins. When it ends, do not resume automatically (to avoid sudden sound); wait for the user
        if type == .began {
            stopImmediately()
        }
    }

    // MARK: Engine configuration change
    private func handleConfigurationChange() {
        // No automatic restart (to avoid sudden sound). Just reflect the stopped state in the UI
        if isRunning {
            stopImmediately()
        }
    }

    // MARK: Actions
    func start() async {
        guard canStart, !isRunning, !isStopping else { return }
        lastErrorMessage = nil
        micPermissionDenied = false

        let needsMic = !useTestSource
        if needsMic {
            let granted = await AVAudioApplication.requestRecordPermission()
            guard granted else {
                micPermissionDenied = true
                return
            }
            // Conditions may have changed during the permission dialog, so check again
            guard canStart, !isRunning, !isStopping else { return }
        }

        do {
            let session = AVAudioSession.sharedInstance()
            if needsMic {
                // Do not add .defaultToSpeaker: speaker output would be picked up by the microphone and cause feedback
                try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothA2DP])
            } else {
                // Test sound does not use the microphone, so there is no feedback risk.
                // With .playAndRecord and no headphones, sound would come from the small receiver (earpiece),
                // so use .playback to play through the built-in speaker (for reviewers without headphones)
                try session.setCategory(.playback, mode: .default, options: [])
            }
            // The OS may not honor these, so pass them as preferences and check the actual values in the log
            try session.setPreferredSampleRate(Self.preferredSampleRate)
            try session.setPreferredIOBufferDuration(Self.preferredIOBufferDuration)
            try session.setActive(true)
            logAudioSession(session)

            if needsMic {
                // Pin input to the built-in microphone. Left to the OS, it could switch to a Bluetooth microphone (ADR-0003)
                guard let builtInMic = session.availableInputs?.first(where: { $0.portType == .builtInMic }) else {
                    lastErrorMessage = "Built-in microphone not found."
                    stopImmediately()
                    return
                }
                try session.setPreferredInput(builtInMic)
            }

            // Changing the category can change the route, so check again
            refreshRoute()
            guard canStart else {
                deactivateSession()
                return
            }

            guard try connectGraph(useMic: needsMic) else {
                lastErrorMessage = "Couldn't access microphone input."
                deactivateSession()
                return
            }

            // Not running yet, so this applies the target values at once (no ramp)
            retarget()
            engine.mainMixerNode.outputVolume = 0
            try engine.start()
            isRunning = true
            startFadeIn()
        } catch {
            lastErrorMessage = "Couldn't start audio. Check your headphones and try again."
            stopImmediately()
        }
    }

    /// User-initiated stop. Stops after a short fade-out (avoids a click)
    func stop() {
        guard isRunning, !isStopping else { return }
        isStopping = true
        fadeTask?.cancel() // If fading in, cancel that first
        isFadingIn = false
        let startVolume = engine.mainMixerNode.outputVolume
        fadeTask = Task { @MainActor [weak self] in
            let steps = Self.fadeOutSteps
            let interval = Self.fadeOutDuration / Double(steps)
            for step in 1...steps {
                if Task.isCancelled { return }
                guard let self else { return }
                let ratio = 1 - Float(step) / Float(steps)
                self.engine.mainMixerNode.outputVolume = startVolume * ratio
                try? await Task.sleep(for: .seconds(interval))
            }
            // If it switched to an immediate stop or similar midway, do nothing
            if Task.isCancelled { return }
            self?.teardown()
        }
    }

    /// Immediate stop without fading. Used when stopping fast matters for safety, such as headphone removal, interruptions and configuration changes
    private func stopImmediately() {
        teardown()
    }

    func select(_ profile: HearingProfile) {
        // The didSet of selectedProfile ramps to the new filter values (no restart even while running)
        selectedProfile = profile
    }

    // MARK: Graph connection and cleanup
    /// Connects the nodes. Returns false if the microphone is unavailable.
    private func connectGraph(useMic: Bool) throws -> Bool {
        engine.stop()

        if useMic {
            // The microphone input format is only known once the current route is settled
            let input = engine.inputNode
            let inputFormat = input.outputFormat(forBus: 0)
            guard inputFormat.channelCount > 0, inputFormat.sampleRate > 0 else {
                return false
            }
            engine.connect(input, to: sourceMixer, fromBus: 0, toBus: 0, format: inputFormat)
            isInputConnected = true
        } else if isInputConnected {
            // Do not connect the microphone in test sound mode (avoids picking up our own output and feeding back)
            engine.disconnectNodeOutput(engine.inputNode)
            isInputConnected = false
        }

        engine.connect(noiseNode, to: sourceMixer, fromBus: 0, toBus: 1, format: noiseFormat)
        engine.connect(sourceMixer, to: eq, format: nil)
        engine.connect(eq, to: reverb, format: nil)
        engine.connect(reverb, to: dynamics, format: nil)
        engine.connect(dynamics, to: limiter, format: nil)
        engine.connect(limiter, to: engine.mainMixerNode, format: nil)
        return true
    }

    /// Fade-in: raises the volume gradually from 0 to the user's volume over about 0.5 seconds. Never exceeds the cap
    private func startFadeIn() {
        fadeTask?.cancel()
        isFadingIn = true
        fadeTask = Task { @MainActor [weak self] in
            let steps = Self.fadeInSteps
            let interval = Self.fadeInDuration / Double(steps)
            for step in 1...steps {
                if Task.isCancelled { return }
                guard let self else { return }
                let ratio = Float(step) / Float(steps)
                // The target is the current user volume (re-read each step so slider moves are respected)
                self.engine.mainMixerNode.outputVolume = min(ratio * self.outputVolume, self.outputCap)
                try? await Task.sleep(for: .seconds(interval))
            }
            self?.isFadingIn = false
        }
    }

    /// Common stop handling. Restores the engine, fades, volume and session
    private func teardown() {
        fadeTask?.cancel()
        fadeTask = nil
        isFadingIn = false
        engine.stop()
        engine.mainMixerNode.outputVolume = 0
        deactivateSession()
        isRunning = false
        // Finish any ramp in progress so the next start begins from the target values
        retarget()
        isStopping = false
        inputLevel = 0
    }

    /// Logs the buffer duration, sample rate and route actually applied (to check on a real device whether preferences were honored)
    private func logAudioSession(_ session: AVAudioSession) {
        let route = session.currentRoute
        let inputs = route.inputs.map { $0.portType.rawValue }.joined(separator: ",")
        let outputs = route.outputs.map { $0.portType.rawValue }.joined(separator: ",")
        let ioBuffer = session.ioBufferDuration
        let sampleRate = session.sampleRate
        audioLogger.info("ioBufferDuration=\(ioBuffer, privacy: .public)s sampleRate=\(sampleRate, privacy: .public)Hz inputs=\(inputs, privacy: .public) outputs=\(outputs, privacy: .public)")
    }

    /// Closes the session. Notifies others so other apps' audio resumes. A failure is not fatal, so it is ignored
    private func deactivateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // A deactivation failure is not shown in the UI because we have already stopped
        }
    }
}
