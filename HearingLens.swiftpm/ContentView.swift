// S-02 メイン画面 / F-02 日常モード / F-03 会話モード / F-04 音量メーター(枠) / F-05 実践スイッチ / F-06 ヘッドホン状態 / F-07 テスト音源 / F-08 オンボーディング表示
import SwiftUI

struct ContentView: View {
    @State private var engine = HearingAudioEngine()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    modePicker
                    profileGrid
                    detailSection
                    if engine.mode == .conversation {
                        conversationSection
                    }
                    visualizerPlaceholder
                    controlSection
                }
                .padding()
            }
            .navigationTitle("HearingLens")
        }
        .onAppear { showOnboarding = !hasSeenOnboarding }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
        }
    }

    // MARK: モード切替
    private var modePicker: some View {
        Picker("体験モード", selection: $engine.mode) {
            ForEach(ExperienceMode.allCases) { mode in
                Label(mode.title, systemImage: mode.symbolName).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: 2x2 プロファイル選択
    private var profileGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(HearingProfile.allCases) { profile in
                profileCard(profile)
            }
        }
    }

    private func profileCard(_ profile: HearingProfile) -> some View {
        let isSelected = engine.selectedProfile == profile
        return Button {
            engine.select(profile)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: profile.symbolName)
                    .font(.title)
                    .foregroundStyle(profile.tint)
                Text(profile.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                // 選択状態は枠線とチェックマークで示す（色だけに頼らない）
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? profile.tint : .secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 110)
            .padding(8)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? profile.tint : .secondary.opacity(0.3),
                            lineWidth: isSelected ? 3 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(profile.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: 解説
    private var detailSection: some View {
        let profile = engine.selectedProfile
        return VStack(alignment: .leading, spacing: 8) {
            Text(profile.title).font(.title3.bold())
            Label("主な対象：\(profile.mainTargets)", systemImage: "person.3")
                .font(.body)
            Text("どう聞こえるか").font(.headline)
            Text(profile.description).font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 会話モード
    private var conversationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("話し方の配慮").font(.headline)
            ForEach(engine.selectedProfile.conversationTips, id: \.self) { tip in
                Label(tip, systemImage: "checkmark.bubble")
                    .font(.body)
            }

            // F-04 声量・距離チェックメーター（後続で実装）
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.secondary, style: StrokeStyle(lineWidth: 1, dash: [4]))
                .frame(height: 44)
                .overlay(Text("声量メーター（F-04 で実装）").font(.footnote))

            // F-05 ビフォー・アフター
            Toggle("アドバイスを実践する", isOn: $engine.isAdviceApplied)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: ビジュアライザー枠
    private var visualizerPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.background.secondary)
            .frame(height: 140)
            .overlay(Text("波形ビジュアライザー（F-02 で実装）").font(.body))
            .accessibilityElement(children: .combine)
    }

    // MARK: 操作系
    private var controlSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // F-06 ヘッドホン状態（アイコン + 文字）
            Label(engine.isHeadphoneConnected ? "ヘッドホン：接続中" : "ヘッドホン：未接続",
                  systemImage: engine.isHeadphoneConnected ? "headphones" : "headphones.slash")
                .font(.body)

            // F-07 テスト音源モード
            Toggle("テスト音源モード", isOn: $engine.useTestSource)
                .font(.body)

            Button {
                if engine.isRunning {
                    engine.stop()
                } else {
                    Task { await engine.start() }
                }
            } label: {
                Label(engine.isRunning ? "停止" : "体験を開始",
                      systemImage: engine.isRunning ? "stop.fill" : "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(engine.isStopping || (!engine.isRunning && !engine.canStart))

            if !engine.canStart && !engine.isRunning {
                Text("ヘッドホンを接続するか、テスト音源モードをオンにしてください。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // 例外: マイク権限の拒否（説明 + 設定を開く導線 + テスト音源の案内）
            if engine.micPermissionDenied {
                VStack(alignment: .leading, spacing: 8) {
                    Label("マイクの使用が許可されていません。設定でマイクを許可すると、自分の声や周りの音で体験できます。許可しなくても「テスト音源モード」で体験できます。",
                          systemImage: "mic.slash")
                        .font(.footnote)
                    Button("設定を開く") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }

            // 例外: 開始失敗などのエラー（アイコン + 文字で示す）
            if let message = engine.lastErrorMessage {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
            }

            // Bluetooth は遅延が大きいので有線を勧める
            if engine.isBluetoothOutput {
                Label("有線ヘッドホン推奨（Bluetooth は約150msの遅延）。Bluetooth だと音が遅れて届くため、自分の声が話しにくく感じることがあります。",
                      systemImage: "info.circle")
                    .font(.footnote)
            }
        }
    }
}

#Preview {
    ContentView()
}
