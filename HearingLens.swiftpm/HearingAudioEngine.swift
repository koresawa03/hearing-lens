// F-01 filter application (audio engine) / F-06 headphone detection, feedback prevention, interruptions / F-07 test sound mode (provisional: noise only) / F-04 level meter (not implemented)
//
// Node graph (signal flow):
//   inputNode ──┐
//               ├→ sourceMixer → eq (4 fixed bands) → reverb → limiter (peak limiter) → mainMixerNode → output
//   noiseNode ──┘
//   (For the F-07 speaking voice, an AVAudioPlayerNode will be added to sourceMixer later.)
// - Nodes are created and attached once in init, and reconnected on every start()
//   (because the input format changes with the current route).
// - The EQ has four bands with fixed roles from the start; unused bands are bypassed.
//   Switching profiles only rewrites each band's values and never reconnects nodes (avoids dropouts).
// - Low latency (ADR-0003): shrink the IO buffer to about 5 ms to reduce the delay before your own voice comes back.
// - Per-source audio session (ADR-0003): microphone uses .playAndRecord + A2DP, test sound uses .playback.
//   Input is pinned to the built-in microphone; the call-oriented HFP is not used.
// - Hearing protection (ADR-0002): limiter + output volume cap + fade-in from 0.
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

/// Fixed EQ bands. Roles are decided up front and never reconnected when switching profiles.
///
/// | Band | Type | Used by profile |
/// |---|---|---|
/// | highPass | high-pass | Low-Frequency Hearing Loss |
/// | lowPass | low-pass | High-Frequency Hearing Loss |
/// | bandPass | band-pass | APD |
/// | peak | parametric (peak EQ) | Hyperacusis |
private enum EQBand: Int, CaseIterable {
    case highPass   // band0: cuts low sounds
    case lowPass    // band1: cuts high sounds
    case bandPass   // band2: passes only the mid range
    case peak       // band3: lifts a specific band
}

/// Debug log. In the Xcode console, look at category "audio"
private let audioLogger = Logger(subsystem: "com.koresawa.HearingLens", category: "audio")

@Observable
@MainActor
final class HearingAudioEngine {
    // MARK: State
    var selectedProfile: HearingProfile = .highFrequencyLoss {
        didSet { applyFilter(currentFilter) }
    }
    var mode: ExperienceMode = .daily
    /// User volume (0...maxOutputVolume). Half of the cap, so it starts quiet.
    var outputVolume: Float = 0.3 {
        didSet {
            let clamped = min(max(outputVolume, 0), Self.maxOutputVolume)
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
            applyFilter(currentFilter)
            // Stop if this changes while running so the session category never disagrees with the mode (restart is a user action)
            if isRunning && useTestSource != oldValue {
                stopImmediately()
            }
        }
    }
    /// F-05 Practice the tips (ON relaxes the filter)
    var isAdviceApplied = false {
        didSet { applyFilter(currentFilter) }
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
    /// Output volume cap (0...1). Never exceeded in any case, to protect hearing. Tune by ear on a real device
    static let maxOutputVolume: Float = 0.6
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

    var volumeFeedback: VolumeFeedback {
        if inputLevel < Self.quietThreshold { return .tooQuiet }
        if inputLevel > Self.loudThreshold { return .tooLoud }
        return .good
    }

    /// The filter values to apply now (reflects the F-05 on/off state)
    var currentFilter: FilterParameters {
        let base = selectedProfile.filter
        return isAdviceApplied ? base.relaxed : base
    }

    /// Whether starting is possible (headphones connected or test sound)
    var canStart: Bool { isHeadphoneConnected || useTestSource }

    // MARK: Nodes (created once in init)
    @ObservationIgnored private let engine = AVAudioEngine()
    /// Mixer that combines microphone and noise into one stream
    @ObservationIgnored private let sourceMixer = AVAudioMixerNode()
    /// EQ with four fixed bands. See EQBand for each band's role
    @ObservationIgnored private let eq = AVAudioUnitEQ(numberOfBands: EQBand.allCases.count)
    @ObservationIgnored private let reverb = AVAudioUnitReverb()
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
        applyFilter(currentFilter)

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

    /// Attaches nodes to the engine and sets initial EQ and limiter values (connecting happens in start)
    private func setupNodes() {
        engine.attach(sourceMixer)
        engine.attach(noiseNode)
        engine.attach(eq)
        engine.attach(reverb)
        engine.attach(limiter)

        // Each band's role (type) is fixed; applyFilter fills in values such as frequency
        eq.globalGain = 0
        // The type is set only once, here. Keep bands bypassed while unused
        eq.bands[EQBand.highPass.rawValue].filterType = .highPass
        eq.bands[EQBand.lowPass.rawValue].filterType = .lowPass
        eq.bands[EQBand.bandPass.rawValue].filterType = .bandPass
        eq.bands[EQBand.peak.rawValue].filterType = .parametric
        for band in eq.bands {
            band.bypass = true
        }

        // Silent before starting. The fade-in raises it
        engine.mainMixerNode.outputVolume = 0
    }

    // MARK: F-01 Apply filters
    /// Maps FilterParameters onto node values. Can be called whether or not the engine is running.
    /// Policy: each band has a fixed role (EQBand). Unused bands are bypassed. Nodes are never reconnected.
    private func applyFilter(_ p: FilterParameters) {
        // highPass: high-pass
        let hp = eq.bands[EQBand.highPass.rawValue]
        if let cutoff = p.highPassCutoff {
            hp.frequency = cutoff
            hp.bandwidth = Self.passFilterBandwidth
            hp.bypass = false
        } else {
            hp.bypass = true
        }

        // lowPass: low-pass
        let lp = eq.bands[EQBand.lowPass.rawValue]
        if let cutoff = p.lowPassCutoff {
            lp.frequency = cutoff
            lp.bandwidth = Self.passFilterBandwidth
            lp.bypass = false
        } else {
            lp.bypass = true
        }

        // bandPass: band-pass (APD)
        let bandPass = eq.bands[EQBand.bandPass.rawValue]
        if let bp = p.bandPass {
            bandPass.frequency = bp.center
            bandPass.bandwidth = bp.bandwidth
            bandPass.bypass = false
        } else {
            bandPass.bypass = true
        }

        // peak: parametric (high-frequency boost for hyperacusis)
        let peakBand = eq.bands[EQBand.peak.rawValue]
        if let peak = p.peakEQ {
            peakBand.frequency = peak.frequency
            peakBand.bandwidth = peak.bandwidth
            peakBand.gain = peak.gain
            peakBand.bypass = false
        } else {
            peakBand.bypass = true
        }

        // Reverb: with no preset, set wet to 0 to pass the signal through
        if let preset = p.reverbPreset {
            reverb.loadFactoryPreset(preset)
            reverb.wetDryMix = p.reverbWetDryMix
        } else {
            reverb.wetDryMix = 0
        }

        // Ambient noise volume is adjusted only through noiseNode.volume (the generator's scale is fixed).
        // In test sound mode, guarantee a minimum volume so you can tell sound is playing until the voice loop (F-07) exists
        let noiseVolume = useTestSource
            ? max(p.noiseMix, Self.testSourceMinimumNoiseVolume)
            : p.noiseMix
        noiseNode.volume = noiseVolume
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

            applyFilter(currentFilter)
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
        // The didSet of selectedProfile applies the filter values (no restart even while running)
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
        engine.connect(reverb, to: limiter, format: nil)
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
                self.engine.mainMixerNode.outputVolume = min(ratio * self.outputVolume, Self.maxOutputVolume)
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
