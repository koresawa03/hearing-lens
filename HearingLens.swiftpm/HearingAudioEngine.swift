// F-01 フィルタ適用（音響エンジン）/ F-06 ヘッドホン検知・ハウリング防止・割り込み / F-07 テスト音源モード（仮: ノイズのみ）/ F-04 音量メーター（未実装）
//
// ノードグラフ（音の流れ）:
//   inputNode ──┐
//               ├→ sourceMixer → eq(4バンド固定) → reverb → limiter(ピークリミッター) → mainMixerNode → 出力
//   noiseNode ──┘
//   （F-07 の話し声は、後で AVAudioPlayerNode を sourceMixer に追加する予定）
// - ノードは init で一度だけ作って attach し、start() のたびに connect し直す
//   （入力フォーマットが「今のルート」で変わるため）。
// - EQ は役割の決まった4バンドを最初から持ち、使わないバンドは bypass にする。
//   プロファイル切替は各バンドの値を書き換えるだけで、ノードをつなぎ直さない（音切れ防止）。
// - 低遅延（ADR-0003）: IO バッファを約5msに小さくして、自分の声が遅れて返る遅延を減らす。
// - 入力ソース別セッション（ADR-0003）: マイクは .playAndRecord + A2DP、テスト音源は .playback。
//   入力は内蔵マイクに固定し、通話用の HFP は使わない。
// - 聴覚保護（ADR-0002）: リミッター + 出力音量の上限 + 0 からのフェードイン。
//   ユーザー操作の停止は短いフェードアウト、ヘッドホン抜去・割り込み・構成変更は即停止。
import AVFoundation
import AudioToolbox
import Observation
import os

/// F-04 声量フィードバックの種類
enum VolumeFeedback {
    case tooQuiet   // 声が小さすぎる（遠い）
    case tooLoud    // 大きすぎる（聴覚過敏には刺激が強い）
    case good       // 適切
}

/// 環境ノイズ（ピンクノイズ風）を作る小さな部品。
/// AVAudioSourceNode の render ブロックはオーディオ専用スレッドで呼ばれ、MainActor には触れない。
/// そのため状態（フィルタの記憶・乱数）をこのクラスにまとめ、ブロックから使う。
/// render ブロックは1本のスレッドからしか呼ばれないので、排他制御なしの `@unchecked Sendable` とする。
private final class PinkNoiseGenerator: @unchecked Sendable {
    // Paul Kellet の economy pink filter の内部状態（過去の値を覚えておくメモリ）
    private var b0: Float = 0
    private var b1: Float = 0
    private var b2: Float = 0
    /// 乱数の状態（xorshift）。システム乱数はリアルタイム処理に向かないので自前で持つ
    private var seed: UInt32 = 0x1234_5678

    /// 出力の大きさ。pink の合成値は ±数倍になるので、約 ±0.2 に収まるよう縮める（目安の経験値）
    private static let outputScale: Float = 0.11

    /// -1...1 の白色ノイズを1つ返す
    private func nextWhite() -> Float {
        seed ^= seed << 13
        seed ^= seed >> 17
        seed ^= seed << 5
        // UInt32 の全範囲を -1...1 に写す
        return Float(seed) / Float(UInt32.max) * 2 - 1
    }

    /// 1サンプル分のピンクノイズ風の値。白色ノイズを「低い音ほど強く」なるよう3段のフィルタで整える
    func nextSample() -> Float {
        let white = nextWhite()
        b0 = 0.99765 * b0 + white * 0.0990460
        b1 = 0.96300 * b1 + white * 0.2965164
        b2 = 0.57000 * b2 + white * 1.0526913
        return (b0 + b1 + b2 + white * 0.1848) * Self.outputScale
    }
}

/// AVAudioSourceNode を作る。MainActor の外（nonisolated）で作ることで、
/// render ブロックが MainActor 隔離を引き継がないようにする。
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

/// EQ の固定バンド。役割を決めておき、プロファイル切替でもつなぎ直さない。
///
/// | バンド | 種類 | 使うプロファイル |
/// |---|---|---|
/// | highPass | ハイパス | 低音難聴 |
/// | lowPass | ローパス | 高音難聴 |
/// | bandPass | バンドパス | APD |
/// | peak | パラメトリック（ピークEQ） | 聴覚過敏 |
private enum EQBand: Int, CaseIterable {
    case highPass   // band0: 低い音を削る
    case lowPass    // band1: 高い音を削る
    case bandPass   // band2: 中域だけ通す
    case peak       // band3: 特定の帯域を持ち上げる
}

/// デバッグ用ログ。Xcode のコンソールで category "audio" を見る
private let audioLogger = Logger(subsystem: "com.koresawa.HearingLens", category: "audio")

@Observable
@MainActor
final class HearingAudioEngine {
    // MARK: 状態
    var selectedProfile: HearingProfile = .highFrequencyLoss {
        didSet { applyFilter(currentFilter) }
    }
    var mode: ExperienceMode = .daily
    private(set) var isRunning = false
    /// フェードアウト中（停止処理の途中）。UI はこの間ボタンを無効にする
    private(set) var isStopping = false
    private(set) var isHeadphoneConnected = false
    /// 出力が Bluetooth か（遅延が大きいので UI で注意を出す）
    private(set) var isBluetoothOutput = false
    var useTestSource = false {
        didSet {
            applyFilter(currentFilter)
            // セッションのカテゴリがモードと食い違わないよう、稼働中に切り替わったら止める（再開はユーザー操作）
            if isRunning && useTestSource != oldValue {
                stopImmediately()
            }
        }
    }
    /// F-05 アドバイスを実践する（ONでフィルタ緩和）
    var isAdviceApplied = false {
        didSet { applyFilter(currentFilter) }
    }
    /// マイク入力の音量 0...1（RMS を正規化した値）
    /// TODO(F-04): inputNode にタップを付けて RMS を計算し、ここへ反映する
    var inputLevel: Float = 0
    /// マイク権限が拒否された（UI で「設定を開く」を案内する）
    private(set) var micPermissionDenied = false
    /// 直近のエラーを日本語で表示するためのメッセージ（nil ならエラーなし）
    var lastErrorMessage: String?

    // MARK: しきい値（0...1 の正規化レベル）
    /// これ未満は「小さすぎる」
    static let quietThreshold: Float = 0.15
    /// これ超は「大きすぎる」
    static let loudThreshold: Float = 0.7

    // MARK: 聴覚保護・音響の定数（ADR-0002）
    /// 出力音量の上限（0...1）。耳を守るため、どんな場合もこれを超えない。実機で聞いて調整する
    static let maxOutputVolume: Float = 0.6
    /// フェードインの総時間（秒）。開始時の「ボンッ」という急な音を避ける
    private static let fadeInDuration: Double = 0.5
    /// フェードインの分割数。0.5秒を10段階に分けて少しずつ上げる
    private static let fadeInSteps = 10
    /// フェードアウトの総時間（秒）。ユーザー操作で止めるときの「ブツッ」という音を避ける
    private static let fadeOutDuration: Double = 0.15
    /// フェードアウトの分割数。0.15秒を6段階に分けて少しずつ下げる
    private static let fadeOutSteps = 6
    /// AVAudioSession の入出力バッファ時間（秒）。小さいほど遅延が減る（約5ms）。
    /// 自分の声が遅れて返ると話しにくい（遅延聴覚フィードバック）ため。小さすぎると音切れするので 5ms にする（ADR-0003）
    private static let preferredIOBufferDuration: TimeInterval = 0.005
    /// 希望するサンプルレート（Hz）。48kHz は iPhone の内蔵マイク・スピーカーの標準的な値
    private static let preferredSampleRate: Double = 48_000
    /// テスト音源モードでの環境ノイズの最低音量。F-07 の声ループが入るまでの仮の「音が出ている」確認用
    private static let testSourceMinimumNoiseVolume: Float = 0.3
    /// ノイズ用ソースノードのサンプルレートが取れない場合の既定値
    private static let fallbackSampleRate: Double = 44_100
    /// EQ のローパス/ハイパスで使う帯域幅（オクターブ）。カットオフ付近の立ち上がり方の目安
    private static let passFilterBandwidth: Float = 0.5

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

    // MARK: ノード（init で一度だけ作る）
    @ObservationIgnored private let engine = AVAudioEngine()
    /// マイクとノイズを1本にまとめるミキサー
    @ObservationIgnored private let sourceMixer = AVAudioMixerNode()
    /// 4バンド固定のEQ。バンドの役割は EQBand を参照
    @ObservationIgnored private let eq = AVAudioUnitEQ(numberOfBands: EQBand.allCases.count)
    @ObservationIgnored private let reverb = AVAudioUnitReverb()
    /// 出力段のピークリミッター（Apple 標準の AudioUnit）。急な大音量を抑える
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
    /// ノイズ用のモノラルフォーマット（ソースノードとミキサーの接続で使う）
    @ObservationIgnored private let noiseFormat: AVAudioFormat
    /// マイク入力ノードを今つないでいるか（テスト音源モードではつながない）
    @ObservationIgnored private var isInputConnected = false
    @ObservationIgnored private var fadeTask: Task<Void, Never>?

    // MARK: 初期化
    // NotificationCenter の token は deinit で触らないため、Engine は寿命がアプリと同じ前提
    @ObservationIgnored private var routeObserver: NSObjectProtocol?
    @ObservationIgnored private var interruptionObserver: NSObjectProtocol?
    @ObservationIgnored private var configurationObserver: NSObjectProtocol?

    init() {
        let sessionRate = AVAudioSession.sharedInstance().sampleRate
        let rate = sessionRate > 0 ? sessionRate : Self.fallbackSampleRate
        // AVAudioFormat の生成が失敗することは通常ないが、force unwrap を避けてフォールバックする
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
            // Notification 自体はアクター間で渡せないので、理由の値（UInt）だけ先に取り出す
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
            // Notification 自体はアクター間で渡せないので、必要な値（UInt）だけ先に取り出す
            let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            Task { @MainActor in
                self?.handleInterruption(typeValue: typeValue)
            }
        }

        // エンジン構成変更（入出力フォーマットの変化など）。エンジンは自分で止まるので状態を合わせる
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

    /// ノードをエンジンに取り付け、EQ とリミッターの初期値を決める（接続は start で行う）
    private func setupNodes() {
        engine.attach(sourceMixer)
        engine.attach(noiseNode)
        engine.attach(eq)
        engine.attach(reverb)
        engine.attach(limiter)

        // 帯域ごとの役割（種類）は固定で、周波数などの値は applyFilter が入れる
        eq.globalGain = 0
        // 種類はここで一度だけ決める。使わない間は bypass にしておく
        eq.bands[EQBand.highPass.rawValue].filterType = .highPass
        eq.bands[EQBand.lowPass.rawValue].filterType = .lowPass
        eq.bands[EQBand.bandPass.rawValue].filterType = .bandPass
        eq.bands[EQBand.peak.rawValue].filterType = .parametric
        for band in eq.bands {
            band.bypass = true
        }

        // 開始前は無音。フェードインで上げる
        engine.mainMixerNode.outputVolume = 0
    }

    // MARK: F-01 フィルタ適用
    /// FilterParameters をノードの値に写す。エンジンが動いていても止まっていても呼べる。
    /// 方針: 各バンドは役割が固定（EQBand）。使わないバンドは bypass にする。ノードはつなぎ直さない。
    private func applyFilter(_ p: FilterParameters) {
        // highPass: ハイパス
        let hp = eq.bands[EQBand.highPass.rawValue]
        if let cutoff = p.highPassCutoff {
            hp.frequency = cutoff
            hp.bandwidth = Self.passFilterBandwidth
            hp.bypass = false
        } else {
            hp.bypass = true
        }

        // lowPass: ローパス
        let lp = eq.bands[EQBand.lowPass.rawValue]
        if let cutoff = p.lowPassCutoff {
            lp.frequency = cutoff
            lp.bandwidth = Self.passFilterBandwidth
            lp.bypass = false
        } else {
            lp.bypass = true
        }

        // bandPass: バンドパス（APD）
        let bandPass = eq.bands[EQBand.bandPass.rawValue]
        if let bp = p.bandPass {
            bandPass.frequency = bp.center
            bandPass.bandwidth = bp.bandwidth
            bandPass.bypass = false
        } else {
            bandPass.bypass = true
        }

        // peak: パラメトリック（聴覚過敏の高域ブースト）
        let peakBand = eq.bands[EQBand.peak.rawValue]
        if let peak = p.peakEQ {
            peakBand.frequency = peak.frequency
            peakBand.bandwidth = peak.bandwidth
            peakBand.gain = peak.gain
            peakBand.bypass = false
        } else {
            peakBand.bypass = true
        }

        // リバーブ: プリセットがなければ wet を 0 にして素通しにする
        if let preset = p.reverbPreset {
            reverb.loadFactoryPreset(preset)
            reverb.wetDryMix = p.reverbWetDryMix
        } else {
            reverb.wetDryMix = 0
        }

        // 環境ノイズの音量は noiseNode.volume だけで調整する（生成側の大きさは固定）。
        // テスト音源モードでは、声ループ（F-07）ができるまで音が出ていることを確認できるよう最低音量を保証する
        let noiseVolume = useTestSource
            ? max(p.noiseMix, Self.testSourceMinimumNoiseVolume)
            : p.noiseMix
        noiseNode.volume = noiseVolume
    }

    // MARK: F-06 ヘッドホン検知
    // HFP（.bluetoothHFP）は通話用で帯域が狭く、高音域の体験が成立しないため含めない（ADR-0003）
    private static let headphonePortTypes: Set<AVAudioSession.Port> = [
        .headphones, .bluetoothA2DP, .bluetoothLE, .usbAudio
    ]
    private static let bluetoothPortTypes: Set<AVAudioSession.Port> = [
        .bluetoothA2DP, .bluetoothLE
    ]

    /// 現在の出力ルートにヘッドホン類があるか確認して反映する
    func refreshRoute() {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        isHeadphoneConnected = outputs.contains { Self.headphonePortTypes.contains($0.portType) }
        isBluetoothOutput = outputs.contains { Self.bluetoothPortTypes.contains($0.portType) }
    }

    private func handleRouteChange(reasonValue: UInt?) {
        refreshRoute()
        guard isRunning else { return }
        let reason = reasonValue.flatMap { AVAudioSession.RouteChangeReason(rawValue: $0) }
        // ヘッドホンが外れた → ハウリング防止のため、フェードせず即停止
        if reason == .oldDeviceUnavailable && !isHeadphoneConnected {
            stopImmediately()
            return
        }
        // 保険: 理由が何であれ、マイクモードでヘッドホンがなければ止める（テスト音源は例外）
        // .newDeviceAvailable（接続）では何もしない。自動で開始はせず、ユーザー操作を待つ
        if !useTestSource && !isHeadphoneConnected {
            stopImmediately()
        }
    }

    // MARK: 割り込み（電話・Siri など）
    private func handleInterruption(typeValue: UInt?) {
        guard let typeValue, let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        // 開始時は即停止する。終了時は急に音が出ないよう、自動再開せずユーザー操作を待つ
        if type == .began {
            stopImmediately()
        }
    }

    // MARK: エンジン構成変更
    private func handleConfigurationChange() {
        // 自動再開はしない（急に音が出ないように）。停止状態をUIへ反映するだけ
        if isRunning {
            stopImmediately()
        }
    }

    // MARK: 操作
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
            // 権限ダイアログの間に状況が変わったかもしれないので確認し直す
            guard canStart, !isRunning, !isStopping else { return }
        }

        do {
            let session = AVAudioSession.sharedInstance()
            if needsMic {
                // .defaultToSpeaker は付けない: スピーカー出力にするとマイクが拾ってハウリングするため
                try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothA2DP])
            } else {
                // テスト音源はマイクを使わないのでハウリングの心配がない。
                // .playAndRecord のままだとヘッドホンなしで小さいレシーバー（受話口）から鳴るため、
                // .playback にして内蔵スピーカーから出す（ヘッドホンなしの審査員向け）
                try session.setCategory(.playback, mode: .default, options: [])
            }
            // OS は希望どおりにしないことがあるので「希望」として伝え、実際の値はログで確認する
            try session.setPreferredSampleRate(Self.preferredSampleRate)
            try session.setPreferredIOBufferDuration(Self.preferredIOBufferDuration)
            try session.setActive(true)
            logAudioSession(session)

            if needsMic {
                // 入力は内蔵マイクに固定する。OS 任せだと Bluetooth などのマイクに切り替わってしまう（ADR-0003）
                guard let builtInMic = session.availableInputs?.first(where: { $0.portType == .builtInMic }) else {
                    lastErrorMessage = "内蔵マイクが見つかりませんでした"
                    stopImmediately()
                    return
                }
                try session.setPreferredInput(builtInMic)
            }

            // カテゴリ変更でルートが変わることがあるので確認し直す
            refreshRoute()
            guard canStart else {
                deactivateSession()
                return
            }

            guard try connectGraph(useMic: needsMic) else {
                lastErrorMessage = "マイク入力を取得できませんでした"
                deactivateSession()
                return
            }

            applyFilter(currentFilter)
            engine.mainMixerNode.outputVolume = 0
            try engine.start()
            isRunning = true
            startFadeIn()
        } catch {
            lastErrorMessage = "オーディオを開始できませんでした。ヘッドホンの接続を確認して、もう一度お試しください。"
            stopImmediately()
        }
    }

    /// ユーザー操作の停止。短いフェードアウトのあとに止める（クリック音を避ける）
    func stop() {
        guard isRunning, !isStopping else { return }
        isStopping = true
        fadeTask?.cancel() // フェードイン中なら先にやめる
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
            // 途中で即停止などに切り替わっていたら何もしない
            if Task.isCancelled { return }
            self?.teardown()
        }
    }

    /// フェードなしの即停止。ヘッドホン抜去・割り込み・構成変更など、安全のため急いで止める場面で使う
    private func stopImmediately() {
        teardown()
    }

    func select(_ profile: HearingProfile) {
        // フィルタ値の反映は selectedProfile の didSet が行う（稼働中でも再起動なし）
        selectedProfile = profile
    }

    // MARK: グラフ接続・後片付け
    /// ノードをつなぐ。マイクが使えない場合は false を返す。
    private func connectGraph(useMic: Bool) throws -> Bool {
        engine.stop()

        if useMic {
            // マイク入力の形式は、今のルートが決まってからでないと分からない
            let input = engine.inputNode
            let inputFormat = input.outputFormat(forBus: 0)
            guard inputFormat.channelCount > 0, inputFormat.sampleRate > 0 else {
                return false
            }
            engine.connect(input, to: sourceMixer, fromBus: 0, toBus: 0, format: inputFormat)
            isInputConnected = true
        } else if isInputConnected {
            // テスト音源モードではマイクをつながない（自分の出力を拾ってフィードバックするのを避ける）
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

    /// フェードイン: 0 から上限まで約0.5秒で少しずつ音量を上げる。上限は絶対に超えない
    private func startFadeIn() {
        fadeTask?.cancel()
        fadeTask = Task { @MainActor [weak self] in
            let steps = Self.fadeInSteps
            let interval = Self.fadeInDuration / Double(steps)
            for step in 1...steps {
                if Task.isCancelled { return }
                guard let self else { return }
                let ratio = Float(step) / Float(steps)
                self.engine.mainMixerNode.outputVolume = min(ratio * Self.maxOutputVolume, Self.maxOutputVolume)
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    /// 停止の共通処理。エンジン・フェード・音量・セッションを元に戻す
    private func teardown() {
        fadeTask?.cancel()
        fadeTask = nil
        engine.stop()
        engine.mainMixerNode.outputVolume = 0
        deactivateSession()
        isRunning = false
        isStopping = false
        inputLevel = 0
    }

    /// 実際に適用されたバッファ時間・サンプルレート・ルートをログに出す（希望どおりか実機で確認するため）
    private func logAudioSession(_ session: AVAudioSession) {
        let route = session.currentRoute
        let inputs = route.inputs.map { $0.portType.rawValue }.joined(separator: ",")
        let outputs = route.outputs.map { $0.portType.rawValue }.joined(separator: ",")
        let ioBuffer = session.ioBufferDuration
        let sampleRate = session.sampleRate
        audioLogger.info("ioBufferDuration=\(ioBuffer, privacy: .public)s sampleRate=\(sampleRate, privacy: .public)Hz inputs=\(inputs, privacy: .public) outputs=\(outputs, privacy: .public)")
    }

    /// セッションを閉じる。他アプリの音声を元に戻すよう通知する。失敗しても致命的ではないので無視する
    private func deactivateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // 非アクティブ化の失敗は、すでに停止済みのため UI には出さない
        }
    }
}
