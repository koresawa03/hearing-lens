// F-08 onboarding / S-01 onboarding screen
import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @Environment(\.dismiss) private var dismiss

    private let steps: [(symbol: String, text: String)] = [
        ("headphones", "Put on headphones"),
        ("ear", "Choose a way of hearing"),
        ("person.2.wave.2", "Try considerate speaking in Conversation mode")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spaceL) {
                Text("Welcome to HearingLens")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                    .accessibilityAddTraits(.isHeader)

                Text("Many differences in hearing can't be seen — from teenagers to older adults. Experience how others may hear, and learn small ways to speak so you're understood.")
                    .font(.body)
                    .foregroundStyle(Theme.foreground)

                VStack(alignment: .leading, spacing: Theme.spaceM) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: Theme.spaceM) {
                            Image(systemName: step.symbol)
                                .font(.title3.weight(Theme.symbolWeight))
                                .frame(width: Theme.iconColumnWidth)
                                .accessibilityHidden(true)
                            Text("\(index + 1). \(step.text)")
                                .font(.body)
                        }
                        .foregroundStyle(Theme.foreground)
                        .accessibilityElement(children: .combine)
                    }
                }

                Rectangle().fill(Theme.line).frame(height: Theme.thinLineWidth)

                noteRow(symbol: "info.circle", title: "Please note",
                        text: "This is an approximation for understanding, not a medical simulation.")
                noteRow(symbol: "speaker.wave.2", title: "For your safety",
                        text: "Start at a low volume and use headphones.")

                Button {
                    hasSeenOnboarding = true
                    dismiss()
                } label: {
                    Text("Get Started")
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

    private func noteRow(symbol: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.spaceM) {
            Image(systemName: symbol)
                .font(.title3.weight(Theme.symbolWeight))
                .frame(width: Theme.iconColumnWidth)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.spaceXS) {
                Text(title).font(.headline)
                Text(text).font(.body).foregroundStyle(Theme.secondary)
            }
        }
        .foregroundStyle(Theme.foreground)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingView()
}
