// F-08 オンボーディング / S-01 オンボーディング画面
import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @Environment(\.dismiss) private var dismiss

    private let steps: [(symbol: String, text: String)] = [
        ("headphones", "ヘッドホンをつける"),
        ("ear", "聞こえ方を選ぶ"),
        ("person.2.wave.2", "会話モードで配慮を試す")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("HearingLens へようこそ")
                    .font(.largeTitle.bold())

                Text("若者から高齢者まで、見た目では分からない聞こえ方の多様性を体験し、話し方の配慮を身につけるためのアプリです。")
                    .font(.body)

                VStack(alignment: .leading, spacing: 12) {
                    Text("使い方").font(.headline)
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        Label("\(index + 1). \(step.text)", systemImage: step.symbol)
                            .font(.body)
                    }
                }

                noteRow(symbol: "info.circle", title: "ご注意",
                        text: "この体験は聞こえ方の近似であり、医学的な再現ではありません。")
                noteRow(symbol: "speaker.wave.2", title: "安全のために",
                        text: "音量は控えめから始めてください。ヘッドホンを使用します。")

                Button {
                    hasSeenOnboarding = true
                    dismiss()
                } label: {
                    Text("はじめる")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
        }
    }

    private func noteRow(symbol: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(text).font(.body)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingView()
}
