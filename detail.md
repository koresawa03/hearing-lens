# detail.md — ファイル構成リファレンス

「何があるか」の一覧。新規ファイル作成・大幅変更・削除・リネームのたびに更新する。

## ルート

### README.md
- 役割: プロジェクト紹介（目的・モード・動かし方・注意）
- 依存: なし
- 参照元: GitHub のトップページ

### .gitignore
- 役割: macOS・Xcode・SwiftPM・Playgrounds のユーザー状態と秘密情報（.env, *.p8 など）をコミット対象から外す
- 参照元: git

### CLAUDE.md
- 役割: Claude Code が毎回読むプロジェクト説明とルール（モデル分業、安全・プライバシー、管理ドキュメントの運用）
- 依存: aim.md、tasks/lessons.md、baton.md、docs/design.md、docs/adr/、.claude/agents/editor.md を参照
- 参照元: Claude Code（自動読み込み）、.claude/agents/editor.md

### claude-rule.md
- 役割: `~/.claude/CLAUDE.md`（個人共通ルール）のプロジェクト内コピー
- 参照元: CLAUDE.md の運用ルール

### aim.md
- 役割: AI引き継ぎ用の最上位指針（概要・技術・設計方針・禁止事項・現在のフォーカス）
- 参照元: CLAUDE.md（セッション開始時に必読）

### update.md
- 役割: 進捗ログ（追記型・新しいものが上）。立案 → 進捗 → 完了
- 参照元: CLAUDE.md、baton.md

### detail.md
- 役割: このファイル。ファイルごとの役割・主要要素・依存関係
- 参照元: CLAUDE.md、.claude/agents/editor.md

### teach.md
- 役割: 学習用解説書（教科書）。「なぜ・どう動くか」を初学者向けに説明し、各章末に審査・面接の想定質問を載せる
- 主要要素: はじめに、第1章（.swiftpm）、第2章（音のしくみと4つの聞こえ方）、第3〜5章（実装後に追記）
- 依存: docs/design.md、docs/adr/
- 参照元: CLAUDE.md

### baton.md
- 役割: 次セッションへの引き継ぎ（上書き型）
- 参照元: CLAUDE.md（セッション開始時に必読）

## docs/

### docs/design.md
- 役割: 設計書（仕様の正）。機能 F-01〜F-08、画面 S-01・S-02、オーディオ処理設計、例外、要検討事項
- 主要要素: 1 目的・対象・SSC制約 / 2 機能一覧（フィルタ値表・アドバイス文） / 3 画面一覧 / 4 オーディオ処理設計 / 5 例外 / 6 要検討 / 7 原文
- 参照元: CLAUDE.md、.claude/agents/editor.md、各 Swift ファイル

### docs/adr/0000-template.md
- 役割: ADR（設計判断の記録）のテンプレート（背景 / 決定 / 検討した他の案と捨てた理由 / 結果・影響）

### docs/adr/0001-swiftpm-no-external-assets.md
- 役割: .swiftpm 形式、外部依存・音声アセットなしの決定
- 参照元: aim.md、docs/design.md、HearingLens.swiftpm/Package.swift

### docs/ai-usage-log.md
- 役割: SSC 2027 の AI 利用の全開示に備えた記録。日付・機能ID・AIが行ったこと・作者が行ったこと（作者の欄は作者が記入）
- 参照元: CLAUDE.md（作業完了時に1行追記）、aim.md、tasks/todo.md フェーズ7

### docs/adr/0002-output-limiter-for-hearing-safety.md
- 役割: 出力段にピークリミッター＋音量上限を置く決定（聴覚保護）。2026-11-16 追記: しきい値を調整するための DynamicsProcessor を前段に置く決定
- 参照元: aim.md、CLAUDE.md、docs/design.md、HearingLens.swiftpm/HearingAudioEngine.swift

### docs/adr/0003-low-latency-and-input-routing.md
- 役割: 低遅延化（IO バッファ約5ms・48kHz）、入力ソース別セッション（マイク `.playAndRecord` / テスト音源 `.playback`）、内蔵マイク固定と HFP 除外の決定
- 参照元: docs/design.md 4章、teach.md 第3章、HearingLens.swiftpm/HearingAudioEngine.swift

## tasks/

### tasks/todo.md
- 役割: フェーズごとのタスクと進捗（機能IDつき）
- 参照元: CLAUDE.md、baton.md

### tasks/lessons.md
- 役割: 失敗と再発防止のパターン集（現在は記録なし）
- 参照元: CLAUDE.md（セッション開始時に必読）

## .claude/

### .claude/agents/editor.md
- 役割: ファイル変更を担当する Sonnet サブエージェントの定義（作業ルールと報告形式）
- 依存: CLAUDE.md、detail.md
- 参照元: CLAUDE.md（モデル運用）

## HearingLens.swiftpm/

### HearingLens.swiftpm/Package.swift
- 役割: Swift Playgrounds App のパッケージ定義
- 主要要素: `.iOSApplication`（iOS 17、iPhone / iPad、アプリアイコンは仮の `.placeholder(icon: .mic)`、アクセントは `.presetColor(.indigo)` を残す（placeholder アイコンに必須で、外すとビルドが失敗する。UI は `.tint(Theme.foreground)` で上書きするため画面には出ない）、カテゴリ education）、マイク権限の capability（英語の用途文字列つき）、実行ターゲット `AppModule`（path ".")
- 依存: PackageDescription、AppleProductTypes
- 参照元: Xcode / Swift Playgrounds

### HearingLens.swiftpm/MyApp.swift
- 役割: `@main` のエントリーポイント。`WindowGroup` で `ContentView` を表示（S-02）
- 主要要素: `MyApp`（App）
- 依存: ContentView.swift
- 参照元: なし（アプリ起点）

### HearingLens.swiftpm/HearingProfile.swift
- 役割: F-01 / F-03 / F-05 のデータ定義。聞こえ方プロファイル、体験モード、フィルタ値
- 主要要素:
  - `enum ExperienceMode`（`.daily` / `.conversation`）: `title`、`symbolName`
  - `struct FilterParameters`: `lowPassCutoff` / `highPassCutoff` / `bandPass` / `peakEQ`（nil は「処理しない」）、`reverbPreset`、`reverbWetDryMix`（0...100）、`noiseMix`（0...1）。タプルを含むため `==` は手書き
    - `static let clear`: 処理なし（原音）
    - `func relaxed(by:)`: F-05 用の緩和版。`RelaxFactors` の倍率で LPF / HPF のカットオフ、バンドパス帯域幅、EQ ゲイン、リバーブ wet、ノイズ混合を弱める。完全クリアではない
  - `struct RelaxFactors`: F-05 の倍率（`lowPassMultiplier` 2.0 / `highPassMultiplier` 0.5 / `bandwidthMultiplier` 2.0 / `gainFactor` 0.5 / `wetFactor` 0.5 / `noiseFactor` 0.5 / `lowPassMax` 20000）。既定値は従来の緩和と同じ。調整パネルから変更できる
  - `enum HearingProfile`（High-Frequency Hearing Loss / Low-Frequency Hearing Loss / APD / Hyperacusis）: `title`（正式名。VoiceOver にも使う）、`tabTitle`（タブ用の短い名前）、`shortDescription`（メイン画面の一行説明）、`symbolName`、`mainTargets`、`description`、`conversationTips`（各3つ）、`filter`（未調整の出発値）。`tint` は削除済み（完全モノクロ化、ADR-0004）。文字列はすべて英語
- 依存: SwiftUI、AVFoundation
- 参照元: HearingAudioEngine.swift、ContentView.swift、ProfileInfoSheet.swift、TuningPanel.swift

### HearingLens.swiftpm/HearingAudioEngine.swift
- 役割: F-01 フィルタ適用（ランプ付き）の音響エンジン、F-05 緩和の適用、F-06 ヘッドホン検知・割り込み処理、聴覚保護（ADR-0002）、低遅延・入力ルーティング（ADR-0003）。F-04（音量メーター）と F-07 の話し声は未実装
- ノードグラフ: `inputNode`（マイク時のみ接続）/ `noiseNode`（`AVAudioSourceNode`、コード生成ピンクノイズ）→ `sourceMixer` → `eq`（5バンド固定: HPF×2・LPF×2・ピーク）→ `reverb` → `dynamics`（DynamicsProcessor。しきい値を調整できる）→ `limiter`（ピークリミッター）→ `mainMixerNode` → 出力。ノードは init で attach、`start()` で connect
- 主要要素:
  - `enum VolumeFeedback`（`.tooQuiet` / `.tooLoud` / `.good`）
  - `private enum EQRole`（`highPass` / `lowPass` / `peak`）と `bandIndex(_:stage:)`: 役割＋段番号からバンド番号を返す
  - `private struct AppliedState`: ノードに実際に書いている値（HPF・LPF のカットオフ、ピークの周波数・ゲイン・幅、リバーブ wet、ノイズ、読み込み済みのリバーブプリセット）
  - `private let audioLogger`、`PinkNoiseGenerator`、`makeNoiseNode(format:)`（変更なし）
  - `@Observable @MainActor final class HearingAudioEngine`
    - 状態: `outputVolume`（0...`outputCap` に収める）、`selectedProfile` / `isAdviceApplied` / `useTestSource`（didSet で `retarget()`。`useTestSource` は稼働中に切り替わると `performStop(reason: .user, ...)`）、`mode`、`isRunning` 等、`lastErrorMessage`、`inputLevel`（TODO(F-04)）
    - 調整用の状態: `tunedFilters`（プロファイルごとの `FilterParameters`。出発点は `profile.filter`）、`relaxFactors`、`limiterThresholdDB`（-24〜0、既定 -3）、`outputCap`（0.2〜`absoluteMaxOutputVolume`）
    - 定数: `absoluteMaxOutputVolume`（0.6）、`minOutputCap`、`passFilterStages`（2）、`neutralHighPass` / `neutralLowPass` / `neutralPeakGain`、`maxPeakGain`（18）、`rampDuration`（0.3）、`rampFrameRate`（60）、`reverbSwitchSplit`、DynamicsProcessor の HeadRoom / ExpansionRatio / OverallGain、フェード・バッファ・サンプルレートなど
    - `currentFilter`: `tunedFilters` から作り、F-05 が ON なら `relaxed(by: relaxFactors)`
    - `makeTarget(from:)`: `FilterParameters` から目標の `AppliedState` を作る。未使用は効かない値。バンドパスは HPF＝中心÷2^(幅/2)、LPF＝中心×2^(幅/2) に変換
    - `retarget()`: 実行中のランプを cancel し、目標を決め直す。停止中は即時適用、稼働中は MainActor の Task で約60Hz・0.3秒、周波数は対数補間・それ以外は線形、smoothstep でなめらかに。リバーブのプリセットが変わるときは wet を 0 へ→`loadFactoryPreset`→wet を目標へ
    - `applyDynamicsSettings()`: `AudioUnitSetParameter` で Threshold / HeadRoom / ExpansionRatio / OverallGain を設定
    - `updateTuned(_:_:)`、`resetTuning()`、`tuningSnapshotCode()`: 調整パネル用（値の編集・初期化・Swift コード形式の文字列化）
    - `private enum StopReason`（user / headphonesRemoved / noHeadphonesAfterRouteChange / interruption / configurationChange / startFailure / restartLimit）と `routeChangeReasonName(_:)`: 停止理由と、ルート変更の理由名（ログ用）
    - `performStop(reason:trigger:)`: すべての停止が通る唯一の入口。`stop reason=... trigger=... outputs=... inputs=...` を1行ログに出してから `teardown`。`routeDescription()` はログ用に出入力ポートを「種別:名前」で返す
    - `handleRouteChange`: 受信を必ずログ。即停止は「ヘッドホンが外れた」「マイクモードでヘッドホンなし」の2条件のみ。`handleInterruption`: 受信をログし、開始なら即停止
    - `handleConfigurationChange`: 受信をログ。エンジンがまだ動いていれば何もしない／ヘッドホンなし（マイクモード）なら即停止／それ以外は `rebuildEngine()` で組み直し（`restartDates` で直近 `restartWindow`（2秒）内に `maxRestartsInWindow`（3回）まで。超えたら停止してエラー）。`rebuildEngine()` はセッションに触らず `connectGraph` → 目標値の即時反映 → 音量0 → `engine.start()` → `startFadeIn()`
    - `isStarting`: `start()` の最中（権限ダイアログ待ち含む）に届いた通知は記録だけにする
    - `start()`: Bluetooth 出力のときは IO バッファの希望を `preferredIOBufferDurationBluetooth`（約20ms）にする（カテゴリ設定後・有効化前に `refreshRoute()`）。有線は 5ms
    - `refreshRoute()` / `start() async` / `stop()`（フェードアウト後に `performStop(reason: .user)`）/ `select(_:)` と private の `connectGraph` / `startFadeIn`（到達値は `outputCap` 以下）/ `teardown`（ランプを完了させる）/ `logAudioSession` / `deactivateSession`: 従来どおり
- 依存: HearingProfile.swift、AVFoundation、AudioToolbox、Observation、os
- 参照元: ContentView.swift、ProfileInfoSheet.swift、TuningPanel.swift

### HearingLens.swiftpm/Theme.swift
- 役割: 完全モノクロ UI（ADR-0004）の色・余白・サイズ・字間・アイコンのウェイトを一か所に集約する。他のファイルは色や余白の数値を直書きせず `Theme` を参照する
- 主要要素:
  - `enum Theme`: `background`（ダーク #0E0E10 / ライト #F5F5F3）、`foreground`（ダーク 白 / ライト #111111）。どちらも `UIColor` の dynamic provider で OS のライト/ダークに連動（アセットカタログなし）。`secondary`（前景 65%。コントラスト比は ダーク約 8.4:1・ライト約 5.7:1）、`line`（前景 25%）、余白スケール（`spaceXS`〜`spaceXL`）、`cornerRadius`、線の太さ、`maxContentWidth`（520）、`heroMinHeight`、`heroAccessibilityHeight`、`tabFadeWidth`、`disabledOutlineOpacity`（0.5。ダーク約 5.3:1・ライト約 3.5:1）、`outlineLineWidth`、`mainButtonDiameter`（72）、`selectedDotSize`、`minTouchTarget`、`headingTracking`（1.5）、`symbolWeight`。`extension Theme` の `enum Sphere`（球体の大きさ・グラデーション階調・縁・ハイライト・影・呼吸の定数）と `enum Ripple`（波紋の本数・縦横比・不透明度・線幅・周期・level による変化の定数）
  - `struct MonochromeToggleStyle: ToggleStyle`（`.toggleStyle(.monochrome)`）: モノクロ専用スイッチ。ON = 前景色のトラック＋背景色のノブ、OFF = 輪郭線（`toggleOffOutlineOpacity` 0.5。ダーク約 5.3:1・ライト約 3.5:1）のトラック＋補足色のノブ。行全体をタップでき（44pt 以上）、Reduce Motion ではアニメーションしない。VoiceOver は `accessibilityRepresentation` で通常の Toggle として読む。寸法・アニメ時間は `Theme.toggle*` 定数
  - `extension View { func themeHeading() }`: 小見出しの共通スタイル
- 依存: SwiftUI、UIKit
- 参照元: ContentView.swift、OnboardingView.swift、ProfileInfoSheet.swift、HeroSphereView.swift

### HearingLens.swiftpm/HeroSphereView.swift
- 役割: F-02 の土台。画面中央に、光沢のある球体と、その下の水面に広がる楕円の波紋を描く（画像アセットなし）
- 主要要素: `struct HeroSphereView`（`level: Double`（0...1 に丸める。呼吸の振幅と波紋の速さ・広がりを増やす。フェーズ3で実際の音量を渡す。今は 0）、`isActive: Bool`）。球体は `Circle` の `RadialGradient`＋`AngularGradient` の縁リング＋blur した白い楕円のハイライトを `drawingGroup` で1枚にまとめ、下に blur した扁平な楕円の影。波紋は `Canvas` で5本の楕円を1パスで描く。`isActive` かつ Reduce Motion が OFF のときだけ `TimelineView(.animation)` で、球体の呼吸と波紋の外への広がり。それ以外は静止表示。ダーク/ライトは `colorScheme` で階調を選ぶ。内部の `Layout` が利用可能な幅・高さから大きさを決める。装飾なので `.accessibilityHidden(true)`。ダーク/ライト・level 0 / 0.5 / 1・静止の `#Preview` つき
- 依存: Theme.swift（`Theme.Sphere`、`Theme.Ripple`、`foreground`）
- 参照元: ContentView.swift

### HearingLens.swiftpm/ProfileInfoSheet.swift
- 役割: S-02 の ⓘ ボタンで開くシート。選択中プロファイルの詳細、Test Sound、オンボーディング再表示
- 主要要素: `struct ProfileInfoSheet`（`@Bindable engine`、`onShowIntroduction` クロージャ）。見出し「Common among」「How it sounds」「Tips for talking」、近似の注意、`Toggle("Test Sound")`（`engine.useTestSource`、`.toggleStyle(.monochrome)`）と説明、「Show Introduction Again」、`TuningConfig.isEnabled` のときだけ `TuningPanel`、「Done」。スクロール可、Dynamic Type 対応
- 依存: HearingAudioEngine.swift、HearingProfile.swift、Theme.swift、TuningConfig.swift、TuningPanel.swift
- 参照元: ContentView.swift（`.sheet`）

### HearingLens.swiftpm/ContentView.swift
- 役割: S-02 メイン画面（中央ビジュアル型・完全モノクロ・英語）。上から: 上部バー（モード文字切替 Everyday / Conversation と ⓘ）、`HeroSphereView`、プロファイル名＋`shortDescription`、（会話モードのみ）アドバイス1つ（タップで次へ）＋「Practice the tips」（`.toggleStyle(.monochrome)`）、プロファイル文字タブ、状態の1行、音量スライダー（最大値は `engine.outputCap`）＋丸い主ボタン
- 主要要素: `ContentView`。`@State engine`、`@AppStorage("hasSeenOnboarding")`、`showOnboarding` / `showInfo` / `pendingIntroduction`（ⓘ シートが閉じてからオンボーディングを出し、シートが同時に2枚出ないようにする）、`tipIndex`（プロファイル変更で 0 に戻す）。選択状態は semibold＋前景100%＋下の点（`selectableText`）。状態の1行は優先順位: エラー → マイク拒否（「Open Settings」ボタン）→ Bluetooth → ヘッドホンなし案内 → 接続中 / Test Sound on。主ボタンは開始時 `Task { await engine.start() }`、`!canStart` または `isStopping` で無効化（塗りをやめ、前景の輪郭線＋補足色のアイコン）。プロファイル文字タブは右端を mask でフェード。ルートに `.tint(Theme.foreground)`、iPad では `Theme.maxContentWidth` で幅を制限。全体は `GeometryReader`＋縦 `ScrollView`（`minHeight` = 画面高、`.basedOnSize`）で、最大 Dynamic Type でも切れずにスクロールできる。アクセシビリティサイズでは中央ビジュアルを固定高（`Theme.heroAccessibilityHeight`）にし、主ボタンと状態行アイコンは `@ScaledMetric` で拡大（主ボタンは上限 1.4 倍）
- 依存: HearingProfile.swift、HearingAudioEngine.swift、OnboardingView.swift、ProfileInfoSheet.swift、HeroSphereView.swift、Theme.swift
- 参照元: MyApp.swift

### HearingLens.swiftpm/OnboardingView.swift
- 役割: S-01 オンボーディング（F-08）。モノクロ・英語。3ステップ、Please note（医学的再現ではない）、For your safety。「Get Started」で `hasSeenOnboarding = true` にして閉じる
- 主要要素: `OnboardingView`（`@AppStorage("hasSeenOnboarding")`、`@Environment(\.dismiss)`）
- 依存: SwiftUI、Theme.swift
- 参照元: ContentView.swift（`.sheet`）

### HearingLens.swiftpm/TuningConfig.swift
- 役割: S-02 調整パネルの有効/無効（`isEnabled`。**提出前に false にする**）と、スライダー範囲の定数一式（聴覚保護のため Peak gain 0〜+18dB、Limiter threshold -24〜0dB、Output cap 0.2〜0.6）
- 主要要素: `enum TuningConfig`（`isEnabled`、`lowPassCutoffRange` / `highPassCutoffRange` / `bandCenterRange` / `peakFrequencyRange`（対数スライダー）、`bandWidthRange` / `peakWidthRange` / `peakGainRange`、`reverbWetRange` / `noiseRange`、`relax*Range`、`limiterThresholdRange` / `outputCapRange`）
- 依存: Foundation
- 参照元: ProfileInfoSheet.swift、TuningPanel.swift

### HearingLens.swiftpm/TuningPanel.swift
- 役割: S-02 ⓘ シート下部の "Tuning" パネル。実機で聞きながら値を詰める（英語・モノクロ・Dynamic Type・VoiceOver ラベルに値つき）
- 主要要素: `struct TuningPanel`（`@Bindable engine`）。選択中プロファイルの使う項目だけを表示（高音難聴: Low-pass cutoff / 低音難聴: High-pass cutoff・Reverb wet / APD: Band center・Band width・Reverb wet・Noise / 聴覚過敏: Peak frequency・Peak gain・Peak width）、Relax factors（6つ）、Limiter threshold、Output cap。周波数は対数スライダー。"Copy values"（`UIPasteboard` に `tuningSnapshotCode()` を入れ、2秒 "Copied" と表示）と "Reset"
- 依存: HearingAudioEngine.swift、HearingProfile.swift、TuningConfig.swift、Theme.swift、UIKit
- 参照元: ProfileInfoSheet.swift

