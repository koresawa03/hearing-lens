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
- 役割: 出力段にピークリミッター＋音量上限を置く決定（聴覚保護）
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
    - `var relaxed`: F-05 用の緩和版。LPF カットオフ ×2（上限 20kHz）、HPF カットオフ ×½、バンドパス帯域幅 ×2、EQ ゲイン / リバーブ wet / ノイズ混合 ×½。完全クリアではない
  - `enum HearingProfile`（High-Frequency Hearing Loss / Low-Frequency Hearing Loss / APD / Hyperacusis）: `title`（正式名。VoiceOver にも使う）、`tabTitle`（タブ用の短い名前）、`shortDescription`（メイン画面の一行説明）、`symbolName`、`mainTargets`、`description`、`conversationTips`（各3つ）、`filter`（未調整の出発値）。`tint` は削除済み（完全モノクロ化、ADR-0004）。文字列はすべて英語
- 依存: SwiftUI、AVFoundation
- 参照元: HearingAudioEngine.swift、ContentView.swift、ProfileInfoSheet.swift

### HearingLens.swiftpm/HearingAudioEngine.swift
- 役割: F-01 フィルタ適用の音響エンジン、F-06 ヘッドホン検知・割り込み処理、聴覚保護（ADR-0002）、低遅延・入力ルーティング（ADR-0003）。F-04（音量メーター）と F-07 の話し声は未実装
- ノードグラフ: `inputNode`（マイク時のみ接続）/ `noiseNode`（`AVAudioSourceNode`、コード生成ピンクノイズ）→ `sourceMixer` → `eq`（4バンド固定）→ `reverb` → `limiter`（ピークリミッター）→ `mainMixerNode` → 出力。ノードは init で attach、`start()` で connect。F-07 の話し声は後で `AVAudioPlayerNode` を sourceMixer に追加する
- 主要要素:
  - `enum VolumeFeedback`（`.tooQuiet` / `.tooLoud` / `.good`）
  - `private enum EQBand`（`highPass` / `lowPass` / `bandPass` / `peak`）: EQ バンドの固定の役割
  - `private let audioLogger`: `os.Logger`（subsystem `com.koresawa.HearingLens`、category `audio`）
  - `private final class PinkNoiseGenerator`（`@unchecked Sendable`）: Paul Kellet の簡易ピンクフィルタ + xorshift 乱数。render スレッド専用
  - `private nonisolated func makeNoiseNode(format:)`: `AVAudioSourceNode` を MainActor 外で生成
  - `@Observable @MainActor final class HearingAudioEngine`
    - 状態: `outputVolume`（ユーザー音量。初期値 0.3 = 上限の半分。didSet で 0...`maxOutputVolume` に収め、稼働中でフェード中でなければ `mainMixerNode.outputVolume` に即反映。フェードインの到達値でもある）、`selectedProfile` / `isAdviceApplied` / `useTestSource`（didSet で `applyFilter`。`useTestSource` は稼働中に切り替わると `stopImmediately()`）、`mode`、`isRunning`・`isStopping`（フェードアウト中）・`isHeadphoneConnected`・`isBluetoothOutput`・`micPermissionDenied`（外部から読み取り専用）、`lastErrorMessage`、`inputLevel`（TODO(F-04)）
    - 定数: `quietThreshold` / `loudThreshold`、`maxOutputVolume`（0.6）、フェードイン 0.5 秒・10 段、フェードアウト 0.15 秒・6 段、`preferredIOBufferDuration`（5ms）、`preferredSampleRate`（48kHz）など
    - `currentFilter` / `canStart` / `volumeFeedback`
    - `applyFilter(_:)`（private）: 各 EQ バンドの値を書き換え、未使用バンドは bypass。リバーブのプリセットと wet、ノイズ音量（`noiseNode.volume`）を設定。ノードのつなぎ直しなし。稼働中でも呼べる
    - `refreshRoute()`: 出力ルートからヘッドホン有無（HFP は含めない）と Bluetooth 出力かを更新
    - `handleRouteChange(reasonValue:)`: reason が `.oldDeviceUnavailable` でヘッドホンがなければ即停止。保険としてマイクモードでヘッドホンがなければ理由に関係なく即停止。`.newDeviceAvailable` は状態更新のみ
    - `handleInterruption(typeValue:)`: 割り込み開始で `stopImmediately()`、終了しても自動再開しない
    - `handleConfigurationChange()`: `.AVAudioEngineConfigurationChange` で稼働中なら `stopImmediately()`、自動再開なし
    - `start() async`: マイク権限要求 → AVAudioSession（マイク時 `.playAndRecord` / `.allowBluetoothA2DP`、テスト音源時 `.playback`。サンプルレートとバッファを希望指定）→ 実際の値をログ → マイク時は内蔵マイクを `setPreferredInput`（無ければエラー）→ グラフ接続 → エンジン起動 → フェードイン。失敗は `lastErrorMessage` に英語で入れる
    - `stop()`: ユーザー操作の停止。約0.15秒フェードアウト後に `teardown`。`isStopping` で二重実行を防ぐ
    - `select(_:)`、private: `stopImmediately`（フェードなしの即停止）、`connectGraph`、`startFadeIn`、`teardown`、`logAudioSession`、`deactivateSession`
- 依存: HearingProfile.swift、AVFoundation、AudioToolbox、Observation、os
- 参照元: ContentView.swift、ProfileInfoSheet.swift

### HearingLens.swiftpm/Theme.swift
- 役割: 完全モノクロ UI（ADR-0004）の色・余白・サイズ・字間・アイコンのウェイトを一か所に集約する。他のファイルは色や余白の数値を直書きせず `Theme` を参照する
- 主要要素:
  - `enum Theme`: `background`（ダーク #0E0E10 / ライト #F5F5F3）、`foreground`（ダーク 白 / ライト #111111）。どちらも `UIColor` の dynamic provider で OS のライト/ダークに連動（アセットカタログなし）。`secondary`（前景 65%。コントラスト比は ダーク約 8.4:1・ライト約 5.7:1）、`line`（前景 25%）、`disabledOpacity`、余白スケール（`spaceXS`〜`spaceXL`）、`cornerRadius`、線の太さ、`maxContentWidth`（520）、`rippleMinHeight`、`mainButtonDiameter`（72）、`selectedDotSize`、`minTouchTarget`、`headingTracking`（1.5）、`symbolWeight`、`ripplePeriod`（4秒）
  - `extension View { func themeHeading() }`: 小見出しの共通スタイル
- 依存: SwiftUI、UIKit
- 参照元: ContentView.swift、OnboardingView.swift、ProfileInfoSheet.swift、RippleView.swift

### HearingLens.swiftpm/RippleView.swift
- 役割: F-02 の土台。画面中央に細い同心円の波紋を描く（アセットなし）
- 主要要素: `struct RippleView`（`level: Double`（0...1 に丸める。リングの振幅をわずかに変える。フェーズ3で実際の音量を渡す。今は 0）、`isActive: Bool`）。`Canvas` で描画。`isActive` かつ Reduce Motion が OFF のときだけ `TimelineView(.animation)` で約4秒周期の「呼吸」。Reduce Motion のときは静止。装飾なので `.accessibilityHidden(true)`
- 依存: Theme.swift
- 参照元: ContentView.swift

### HearingLens.swiftpm/ProfileInfoSheet.swift
- 役割: S-02 の ⓘ ボタンで開くシート。選択中プロファイルの詳細、Test Sound、オンボーディング再表示
- 主要要素: `struct ProfileInfoSheet`（`@Bindable engine`、`onShowIntroduction` クロージャ）。見出し「Common among」「How it sounds」「Tips for talking」、近似の注意、`Toggle("Test Sound")`（`engine.useTestSource`）と説明、「Show Introduction Again」「Done」。スクロール可、Dynamic Type 対応
- 依存: HearingAudioEngine.swift、HearingProfile.swift、Theme.swift
- 参照元: ContentView.swift（`.sheet`）

### HearingLens.swiftpm/ContentView.swift
- 役割: S-02 メイン画面（中央ビジュアル型・完全モノクロ・英語）。上から: 上部バー（モード文字切替 Everyday / Conversation と ⓘ）、`RippleView`、プロファイル名＋`shortDescription`、（会話モードのみ）アドバイス1つ（タップで次へ）＋「Practice the tips」、プロファイル文字タブ、状態の1行、音量スライダー＋丸い主ボタン
- 主要要素: `ContentView`。`@State engine`、`@AppStorage("hasSeenOnboarding")`、`showOnboarding` / `showInfo` / `pendingIntroduction`（ⓘ シートが閉じてからオンボーディングを出し、シートが同時に2枚出ないようにする）、`tipIndex`（プロファイル変更で 0 に戻す）。選択状態は semibold＋前景100%＋下の点（`selectableText`）。状態の1行は優先順位: エラー → マイク拒否（「Open Settings」ボタン）→ Bluetooth → ヘッドホンなし案内 → 接続中 / Test Sound on。主ボタンは開始時 `Task { await engine.start() }`、`!canStart` または `isStopping` で不透明度を下げて無効化（円のまま）。ルートに `.tint(Theme.foreground)`、iPad では `Theme.maxContentWidth` で幅を制限。全体は `GeometryReader`＋縦 `ScrollView`（`minHeight` = 画面高、`.basedOnSize`）で、最大 Dynamic Type でも切れずにスクロールできる。アクセシビリティサイズでは波紋を固定高（`Theme.rippleAccessibilityHeight`）にし、主ボタンと状態行アイコンは `@ScaledMetric` で拡大（主ボタンは上限 1.4 倍）
- 依存: HearingProfile.swift、HearingAudioEngine.swift、OnboardingView.swift、ProfileInfoSheet.swift、RippleView.swift、Theme.swift
- 参照元: MyApp.swift

### HearingLens.swiftpm/OnboardingView.swift
- 役割: S-01 オンボーディング（F-08）。モノクロ・英語。3ステップ、Please note（医学的再現ではない）、For your safety。「Get Started」で `hasSeenOnboarding = true` にして閉じる
- 主要要素: `OnboardingView`（`@AppStorage("hasSeenOnboarding")`、`@Environment(\.dismiss)`）
- 依存: SwiftUI、Theme.swift
- 参照元: ContentView.swift（`.sheet`）
