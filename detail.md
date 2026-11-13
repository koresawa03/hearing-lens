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

### docs/adr/0002-output-limiter-for-hearing-safety.md
- 役割: 出力段にピークリミッター＋音量上限を置く決定（聴覚保護）
- 参照元: aim.md、CLAUDE.md、docs/design.md、HearingLens.swiftpm/HearingAudioEngine.swift

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
- 主要要素: `.iOSApplication`（iOS 17、iPhone / iPad、アプリアイコンは仮の `.placeholder(icon: .mic)`、アクセント indigo、カテゴリ education）、マイク権限の capability（用途文字列つき）、実行ターゲット `AppModule`（path ".")
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
    - `var relaxed`: F-05 用の緩和版。LPF カットオフ ×2（上限 20kHz）、HPF カットオフ ×½、バンドパス帯域幅 ×2、EQ ゲイン / リバーブ wet / ノイズ混合 ×½。完全クリアではない
  - `enum HearingProfile`（高音難聴 / 低音難聴 / APD / 聴覚過敏）: `title`、`symbolName`、`tint`、`mainTargets`、`description`、`conversationTips`（各3つ）、`filter`（未調整の出発値）
- 依存: SwiftUI、AVFoundation
- 参照元: HearingAudioEngine.swift、ContentView.swift

### HearingLens.swiftpm/HearingAudioEngine.swift
- 役割: F-01 フィルタ適用の音響エンジン、F-06 ヘッドホン検知・割り込み処理、聴覚保護（ADR-0002）。F-04（音量メーター）と F-07 の声ループは未実装
- ノードグラフ: `inputNode`（マイク時のみ接続）/ `noiseNode` → `sourceMixer` → `eq`（3バンド）→ `reverb` → `limiter`（ピークリミッター）→ `mainMixerNode` → 出力。ノードは init で attach、`start()` で connect
- 主要要素:
  - `enum VolumeFeedback`（`.tooQuiet` / `.tooLoud` / `.good`）
  - `private final class PinkNoiseGenerator`（`@unchecked Sendable`）: Paul Kellet の簡易ピンクフィルタ + xorshift 乱数。render スレッド専用
  - `private nonisolated func makeNoiseNode(format:)`: `AVAudioSourceNode` を MainActor 外で生成
  - `@Observable @MainActor final class HearingAudioEngine`
    - 状態: `selectedProfile` / `isAdviceApplied` / `useTestSource`（didSet で `applyFilter`。`useTestSource` は稼働中に切り替わると `stop()`）、`mode`、`isRunning`・`isHeadphoneConnected`・`isBluetoothOutput`・`micPermissionDenied`（外部から読み取り専用）、`lastErrorMessage`、`inputLevel`（TODO(F-04)）
    - 定数: `quietThreshold` / `loudThreshold`、`maxOutputVolume`（0.6）、フェードイン時間 0.5 秒・10 段、IO バッファ 5ms など
    - `currentFilter` / `canStart` / `volumeFeedback`
    - `applyFilter(_:)`（private）: band0=HPF、band1=LPF、band2=バンドパス（優先）またはパラメトリック。未使用バンドは bypass。リバーブのプリセットと wet、ノイズ音量（`noiseNode.volume`）を設定。稼働中でも呼べる
    - `refreshRoute()`: 出力ルートからヘッドホン有無と Bluetooth 出力かを更新
    - `handleRouteChange()`: ヘッドホンが外れたら（テスト音源を除き）`stop()`
    - `handleInterruption(typeValue:)`: 割り込み開始で `stop()`、終了しても自動再開しない
    - `handleConfigurationChange()`: `.AVAudioEngineConfigurationChange`（object: engine、`configurationObserver`）で稼働中なら `teardown()`、自動再開なし
    - `start() async`: マイク権限要求 → AVAudioSession（マイク時 `.playAndRecord` / `.allowBluetoothA2DP`、テスト音源時 `.playback` でスピーカー可 / 5ms）→ グラフ接続 → エンジン起動 → フェードイン。失敗は `lastErrorMessage` に日本語で入れる
    - `stop()` / `select(_:)`、private: `connectGraph`、`startFadeIn`、`teardown`、`deactivateSession`
- 依存: HearingProfile.swift、AVFoundation、AudioToolbox、Observation
- 参照元: ContentView.swift

### HearingLens.swiftpm/ContentView.swift
- 役割: S-02 メイン画面。モード Picker、2x2 プロファイルグリッド、解説、会話モードのアドバイス、ビジュアライザーとメーターの場所取り、ヘッドホン状態・テスト音源・開始/停止（F-02〜F-07 の枠）
- 主要要素: `ContentView`。`@State engine`（`HearingAudioEngine`）、`@AppStorage("hasSeenOnboarding")` と `@State showOnboarding`。`onAppear` で `showOnboarding = !hasSeenOnboarding` を設定し、`.sheet` で `OnboardingView` を表示（オンボーディングは ContentView から出す）。開始ボタンは `Task { await engine.start() }`。`engine.micPermissionDenied` のとき説明と「設定を開く」ボタン（`UIApplication.openSettingsURLString`）、`engine.lastErrorMessage` のエラー表示、`engine.isBluetoothOutput` のとき Bluetooth 遅延の注意を表示
- 依存: HearingProfile.swift、HearingAudioEngine.swift、OnboardingView.swift
- 参照元: MyApp.swift

### HearingLens.swiftpm/OnboardingView.swift
- 役割: S-01 オンボーディング（F-08）。使い方3ステップ、ご注意（医学的再現ではない）、安全のための注意。「はじめる」で `hasSeenOnboarding = true` にして閉じる
- 主要要素: `OnboardingView`（`@AppStorage("hasSeenOnboarding")`、`@Environment(\.dismiss)`）
- 依存: SwiftUI
- 参照元: ContentView.swift（`.sheet`）
