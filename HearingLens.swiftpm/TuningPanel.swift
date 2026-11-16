// S-02 tuning panel config (disable before submission) / F-01 filters, F-05 relax factors, F-06 safety limits
// Panel shown at the bottom of the info sheet while TuningConfig.isEnabled is true.
// Lets the author tune values by ear on a real device, then copy them out as Swift code.
import SwiftUI
import UIKit

struct TuningPanel: View {
    @Bindable var engine: HearingAudioEngine

    /// True for a moment after "Copy values" is pressed
    @State private var showsCopied = false

    /// How long the "Copied" label stays visible (seconds)
    private static let copiedDisplayDuration: Double = 2

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spaceM) {
            Text("Tuning").themeHeading()
            Text("For tuning only — disabled before submission.")
                .font(.footnote)
                .foregroundStyle(Theme.secondary)

            profileRows(engine.selectedProfile)

            Text("Relax factors").themeHeading()
            relaxRows

            Text("Safety").themeHeading()
            row(
                "Limiter threshold",
                value: $engine.limiterThresholdDB,
                range: TuningConfig.limiterThresholdRange,
                format: { String(format: "%.1f dB", $0) }
            )
            row(
                "Output cap",
                value: $engine.outputCap,
                range: TuningConfig.outputCapRange,
                format: { String(format: "%.2f", $0) }
            )

            HStack(spacing: Theme.spaceM) {
                Button {
                    copyValues()
                } label: {
                    Text(showsCopied ? "Copied" : "Copy values")
                        .font(.body)
                        .foregroundStyle(Theme.foreground)
                        .frame(maxWidth: .infinity, minHeight: Theme.minTouchTarget)
                        .overlay(Capsule().stroke(Theme.line, lineWidth: Theme.thinLineWidth))
                }
                .buttonStyle(.plain)

                Button {
                    engine.resetTuning()
                } label: {
                    Text("Reset")
                        .font(.body)
                        .foregroundStyle(Theme.foreground)
                        .frame(maxWidth: .infinity, minHeight: Theme.minTouchTarget)
                        .overlay(Capsule().stroke(Theme.line, lineWidth: Theme.thinLineWidth))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Rows for the selected profile (only the values that profile uses)
    @ViewBuilder
    private func profileRows(_ profile: HearingProfile) -> some View {
        switch profile {
        case .highFrequencyLoss:
            hzRow(
                "Low-pass cutoff",
                value: filterBinding(profile, \.lowPassCutoff, TuningConfig.lowPassCutoffRange.lowerBound),
                range: TuningConfig.lowPassCutoffRange
            )
        case .lowFrequencyLoss:
            hzRow(
                "High-pass cutoff",
                value: filterBinding(profile, \.highPassCutoff, TuningConfig.highPassCutoffRange.lowerBound),
                range: TuningConfig.highPassCutoffRange
            )
            wetRow(profile)
        case .apd:
            hzRow(
                "Band center",
                value: tupleBinding(
                    profile,
                    get: { $0.bandPass?.center },
                    set: { $0.bandPass?.center = $1 },
                    fallback: TuningConfig.bandCenterRange.lowerBound
                ),
                range: TuningConfig.bandCenterRange
            )
            row(
                "Band width",
                value: tupleBinding(
                    profile,
                    get: { $0.bandPass?.bandwidth },
                    set: { $0.bandPass?.bandwidth = $1 },
                    fallback: TuningConfig.bandWidthRange.lowerBound
                ),
                range: TuningConfig.bandWidthRange,
                format: { String(format: "%.1f oct", $0) }
            )
            wetRow(profile)
            row(
                "Noise",
                value: valueBinding(profile, get: { $0.noiseMix }, set: { $0.noiseMix = $1 }),
                range: TuningConfig.noiseRange,
                format: { String(format: "%.2f", $0) }
            )
        case .hyperacusis:
            hzRow(
                "Peak frequency",
                value: tupleBinding(
                    profile,
                    get: { $0.peakEQ?.frequency },
                    set: { $0.peakEQ?.frequency = $1 },
                    fallback: TuningConfig.peakFrequencyRange.lowerBound
                ),
                range: TuningConfig.peakFrequencyRange
            )
            row(
                "Peak gain",
                value: tupleBinding(
                    profile,
                    get: { $0.peakEQ?.gain },
                    set: { $0.peakEQ?.gain = $1 },
                    fallback: TuningConfig.peakGainRange.lowerBound
                ),
                range: TuningConfig.peakGainRange,
                format: { String(format: "+%.1f dB", $0) }
            )
            row(
                "Peak width",
                value: tupleBinding(
                    profile,
                    get: { $0.peakEQ?.bandwidth },
                    set: { $0.peakEQ?.bandwidth = $1 },
                    fallback: TuningConfig.peakWidthRange.lowerBound
                ),
                range: TuningConfig.peakWidthRange,
                format: { String(format: "%.1f oct", $0) }
            )
        }
    }

    private func wetRow(_ profile: HearingProfile) -> some View {
        row(
            "Reverb wet",
            value: valueBinding(profile, get: { $0.reverbWetDryMix }, set: { $0.reverbWetDryMix = $1 }),
            range: TuningConfig.reverbWetRange,
            format: { String(format: "%.0f %%", $0) }
        )
    }

    // MARK: Relax factor rows
    @ViewBuilder
    private var relaxRows: some View {
        row("Low-pass multiplier", value: $engine.relaxFactors.lowPassMultiplier,
            range: TuningConfig.relaxLowPassMultiplierRange, format: Self.timesText)
        row("High-pass multiplier", value: $engine.relaxFactors.highPassMultiplier,
            range: TuningConfig.relaxHighPassMultiplierRange, format: Self.timesText)
        row("Width multiplier", value: $engine.relaxFactors.bandwidthMultiplier,
            range: TuningConfig.relaxBandwidthMultiplierRange, format: Self.timesText)
        row("Gain factor", value: $engine.relaxFactors.gainFactor,
            range: TuningConfig.relaxFactorRange, format: Self.timesText)
        row("Wet factor", value: $engine.relaxFactors.wetFactor,
            range: TuningConfig.relaxFactorRange, format: Self.timesText)
        row("Noise factor", value: $engine.relaxFactors.noiseFactor,
            range: TuningConfig.relaxFactorRange, format: Self.timesText)
    }

    private static func timesText(_ value: Float) -> String {
        String(format: "x%.2f", value)
    }

    // MARK: Bindings into engine.tunedFilters
    /// Binding to an optional frequency-like field of one profile's FilterParameters
    private func filterBinding(
        _ profile: HearingProfile,
        _ keyPath: WritableKeyPath<FilterParameters, Float?>,
        _ fallback: Float
    ) -> Binding<Float> {
        Binding(
            get: { engine.tunedFilters[profile]?[keyPath: keyPath] ?? fallback },
            set: { newValue in engine.updateTuned(profile) { $0[keyPath: keyPath] = newValue } }
        )
    }

    /// Binding to a non-optional field
    private func valueBinding(
        _ profile: HearingProfile,
        get: @escaping (FilterParameters) -> Float,
        set: @escaping (inout FilterParameters, Float) -> Void
    ) -> Binding<Float> {
        Binding(
            get: { engine.tunedFilters[profile].map(get) ?? 0 },
            set: { newValue in engine.updateTuned(profile) { set(&$0, newValue) } }
        )
    }

    /// Binding to a field inside the band-pass or peak tuple (those are optional, so a fallback covers nil)
    private func tupleBinding(
        _ profile: HearingProfile,
        get: @escaping (FilterParameters) -> Float?,
        set: @escaping (inout FilterParameters, Float) -> Void,
        fallback: Float
    ) -> Binding<Float> {
        Binding(
            get: { engine.tunedFilters[profile].flatMap(get) ?? fallback },
            set: { newValue in engine.updateTuned(profile) { set(&$0, newValue) } }
        )
    }

    // MARK: Row building blocks
    /// Frequency row: log-scaled slider (equal ratios feel like equal steps)
    private func hzRow(_ label: String, value: Binding<Float>, range: ClosedRange<Float>) -> some View {
        let logBinding = Binding<Float>(
            get: { log(value.wrappedValue) },
            set: { value.wrappedValue = exp($0) }
        )
        return rowContent(
            label,
            valueText: String(format: "%.0f Hz", value.wrappedValue),
            slider: Slider(value: logBinding, in: log(range.lowerBound)...log(range.upperBound))
        )
    }

    /// Linear row
    private func row(
        _ label: String,
        value: Binding<Float>,
        range: ClosedRange<Float>,
        format: (Float) -> String
    ) -> some View {
        rowContent(label, valueText: format(value.wrappedValue), slider: Slider(value: value, in: range))
    }

    private func rowContent(_ label: String, valueText: String, slider: Slider<EmptyView, EmptyView>) -> some View {
        VStack(alignment: .leading, spacing: Theme.spaceXS) {
            HStack {
                Text(label).font(.body)
                Spacer()
                Text(valueText).font(.body.monospacedDigit()).foregroundStyle(Theme.secondary)
            }
            .foregroundStyle(Theme.foreground)
            .accessibilityHidden(true)
            slider
                .accessibilityLabel(label)
                .accessibilityValue(valueText)
        }
    }

    // MARK: Copy
    private func copyValues() {
        UIPasteboard.general.string = engine.tuningSnapshotCode()
        showsCopied = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.copiedDisplayDuration))
            showsCopied = false
        }
    }
}
