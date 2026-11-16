// S-02 tuning panel config (disable before submission)
// Switch and slider ranges for the Tuning panel in the info sheet.
// Ranges respect hearing protection (ADR-0002): peak gain max +18 dB, output cap max 0.6.
import Foundation

enum TuningConfig {
    /// Shows the Tuning panel in the info sheet. Set to false before submission.
    static let isEnabled = true

    // MARK: Frequency ranges in Hz (shown on log-scaled sliders)
    static let lowPassCutoffRange: ClosedRange<Float> = 500...8_000
    static let highPassCutoffRange: ClosedRange<Float> = 100...2_000
    static let bandCenterRange: ClosedRange<Float> = 300...3_000
    static let peakFrequencyRange: ClosedRange<Float> = 2_000...6_000

    // MARK: Width and gain ranges
    /// Band-pass width in octaves
    static let bandWidthRange: ClosedRange<Float> = 0.5...4.0
    /// Peak width in octaves
    static let peakWidthRange: ClosedRange<Float> = 0.3...2.0
    /// Peak gain in dB. The upper end is the spec maximum (+18 dB)
    static let peakGainRange: ClosedRange<Float> = 0...18

    // MARK: Effect amount ranges
    /// Reverb wet in percent
    static let reverbWetRange: ClosedRange<Float> = 0...60
    /// Noise mix (0...1 scale, limited to 0.6)
    static let noiseRange: ClosedRange<Float> = 0...0.6

    // MARK: Relax factor ranges
    /// Cutoff-raising multiplier (low-pass)
    static let relaxLowPassMultiplierRange: ClosedRange<Float> = 1...4
    /// Cutoff-lowering multiplier (high-pass)
    static let relaxHighPassMultiplierRange: ClosedRange<Float> = 0.25...1
    /// Band-pass width multiplier
    static let relaxBandwidthMultiplierRange: ClosedRange<Float> = 1...4
    /// Gain / wet / noise factors
    static let relaxFactorRange: ClosedRange<Float> = 0...1

    // MARK: Safety ranges
    /// DynamicsProcessor threshold in dB
    static let limiterThresholdRange: ClosedRange<Float> = -24...0
    /// Output cap (0...1). The upper end is ADR-0002's absolute limit
    static let outputCapRange: ClosedRange<Float> = 0.2...0.6
}
