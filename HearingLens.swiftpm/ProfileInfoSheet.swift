// S-02 info sheet: profile details (opened with the info button), Test Sound (F-07), replay of onboarding (F-08)
import SwiftUI

struct ProfileInfoSheet: View {
    @Bindable var engine: HearingAudioEngine
    /// Called when the user asks to see the introduction again (the caller dismisses this sheet first)
    var onShowIntroduction: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let profile = engine.selectedProfile
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spaceL) {
                Text(profile.title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                    .accessibilityAddTraits(.isHeader)

                section("Common among", text: profile.mainTargets)
                section("How it sounds", text: profile.description)

                VStack(alignment: .leading, spacing: Theme.spaceS) {
                    Text("Tips for talking").themeHeading()
                    ForEach(profile.conversationTips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: Theme.spaceS) {
                            Image(systemName: "checkmark.bubble")
                                .font(.body.weight(Theme.symbolWeight))
                                .accessibilityHidden(true)
                            Text(tip).font(.body)
                        }
                        .foregroundStyle(Theme.foreground)
                        .accessibilityElement(children: .combine)
                    }
                }

                Text("This is an approximation for understanding, not a medical simulation.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondary)

                Rectangle().fill(Theme.line).frame(height: Theme.thinLineWidth)

                // F-07 Test Sound
                VStack(alignment: .leading, spacing: Theme.spaceXS) {
                    Toggle("Test Sound", isOn: $engine.useTestSource)
                        .font(.body)
                        .foregroundStyle(Theme.foreground)
                    Text("Plays a built-in sound through the speaker — no headphones or microphone needed.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondary)
                }

                Button {
                    onShowIntroduction()
                } label: {
                    Text("Show Introduction Again")
                        .font(.body)
                        .foregroundStyle(Theme.foreground)
                        .frame(maxWidth: .infinity, minHeight: Theme.minTouchTarget)
                        .overlay(Capsule().stroke(Theme.line, lineWidth: Theme.thinLineWidth))
                }
                .buttonStyle(.plain)

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .foregroundStyle(Theme.background)
                        .frame(maxWidth: .infinity, minHeight: Theme.minTouchTarget)
                        .background(Theme.foreground, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(Theme.spaceL)
            .frame(maxWidth: Theme.maxContentWidth)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background.ignoresSafeArea())
        .tint(Theme.foreground)
    }

    private func section(_ heading: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.spaceS) {
            Text(heading).themeHeading()
            Text(text).font(.body).foregroundStyle(Theme.foreground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
