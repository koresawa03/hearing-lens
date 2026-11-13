// F-01 フィルタ適用の土台 / F-04 音量メーター / F-06 ヘッドホン検知・ハウリング防止 / F-07 テスト音源モード
// 現段階はフラグ管理とルート監視のみ実装。実音声処理は TODO(F-01)。
import AVFoundation
import Observation

/// F-04 声量フィードバックの種類
enum VolumeFeedback {
    case tooQuiet   // 声が小さすぎる（遠い）
    case tooLoud    // 大きすぎる（聴覚過敏には刺激が強い）
    case good       // 適切
}

@Observable
@MainActor
final class HearingAudioEngine {
    // MARK: 状態
    var selectedProfile: HearingProfile = .highFrequencyLoss
    var mode: ExperienceMode = .daily
    private(set) var isRunning = false
    private(set) var isHeadphoneConnected = false
    var useTestSource = false
    /// F-05 アドバイスを実践する（ONでフィルタ緩和）
    var isAdviceApplied = false
    /// マイク入力の音量 0...1（RMS を正規化した値）
    var inputLevel: Float = 0

    // MARK: しきい値（0...1 の正規化レベル）
    /// これ未満は「小さすぎる」
    static let quietThreshold: Float = 0.15
    /// これ超は「大きすぎる」
    static let loudThreshold: Float = 0.7

    var volumeFeedback: VolumeFeedback {
        if inputLevel < Self.quietThreshold { return .tooQuiet }
        if inputLevel > Self.loudThreshold { return .tooLoud }
        return .good
    }

    /// 現在適用すべきフィルタ値（F-05 の ON/OFF を反映）
    var currentFilter: FilterParameters {
        let base = selectedProfile.filter
        return isAdviceApplied ? base.relaxed : base
    }

    /// 開始可能か（ヘッドホン接続 or テスト音源）
    var canStart: Bool { isHeadphoneConnected || useTestSource }

    // MARK: 初期化
    // NotificationCenter の token は deinit で触らないため、Engine は寿命がアプリと同じ前提
    @ObservationIgnored private var routeObserver: NSObjectProtocol?

    init() {
        refreshRoute()
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleRouteChange()
            }
        }
    }

    // MARK: F-06 ヘッドホン検知
    private static let headphonePortTypes: Set<AVAudioSession.Port> = [
        .headphones, .bluetoothA2DP, .bluetoothLE, .bluetoothHFP, .usbAudio
    ]

    /// 現在の出力ルートにヘッドホン類があるか確認して反映する
    func refreshRoute() {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        isHeadphoneConnected = outputs.contains { Self.headphonePortTypes.contains($0.portType) }
    }

    private func handleRouteChange() {
        refreshRoute()
        // ハウリング防止: ヘッドホンが外れたら即停止（テスト音源は例外）
        if isRunning && !isHeadphoneConnected && !useTestSource {
            stop()
        }
    }

    // MARK: 操作
    func start() {
        guard canStart else { return }
        // TODO(F-01): AVAudioSession を .playAndRecord に設定して有効化。
        //   ノードグラフ: 入力(inputNode / テスト音源は AVAudioPlayerNode)
        //     → AVAudioUnitEQ(LPF/HPF/BP/ピークEQ) → AVAudioUnitReverb
        //     → ピークリミッタ(AVAudioUnitEffect Peak Limiter) → mainMixer → 出力
        //   F-04: inputNode にタップを付けて RMS を inputLevel へ反映
        //   F-07: useTestSource が true なら合成した環境音＋声ループを player で再生
        isRunning = true
    }

    func stop() {
        // TODO(F-01): エンジン停止・タップ除去・player 停止
        isRunning = false
        inputLevel = 0
    }

    func select(_ profile: HearingProfile) {
        selectedProfile = profile
        // TODO(F-01): 稼働中ならフィルタ値(currentFilter)をノードへ即時反映（再起動なし）
    }
}
