# update.md — 進捗ログ（追記型・新しいものが上）

## 2026-11-13 16:20 — フェーズ2: 音響エンジン（F-01 / F-06）

### 立案
- 依頼内容: PR #1 をマージし、フェーズ2（音響エンジン F-01 / F-06）を開始する。ブランチ `feat/f01-audio-engine`。
- 計画: `HearingAudioEngine` を実装する。ノードグラフは inputNode / noiseNode → sourceMixer → EQ(3バンド) → リバーブ → ピークリミッター → mainMixer。ノイズはコード合成（AVAudioSourceNode）。出力音量は上限 0.6 とし、0 から約0.5秒でフェードイン。AVAudioSession は `.playAndRecord` + A2DP（スピーカー出力なし）。マイク権限拒否・割り込み・ルート変更・エンジン起動失敗を例外処理する。`ContentView` は開始/停止、権限拒否の案内、エラー表示、Bluetooth 注意を追加。
- 影響範囲: HearingAudioEngine.swift、ContentView.swift、detail.md、teach.md 第3・4章、tasks/todo.md、baton.md。

### 進捗
- `HearingAudioEngine` を実装: ノードグラフ（inputNode / noiseNode → sourceMixer → EQ → リバーブ → リミッター → mainMixer）、applyFilter によるプロファイル切替（再起動なし）、出力上限 0.6 と 0.5 秒フェードイン、マイク権限・割り込み・ルート変更・起動失敗の処理。ContentView に開始/停止・権限拒否案内・エラー・Bluetooth 注意を追加。
- xcodebuild（iPhone 17 シミュレータ）BUILD SUCCEEDED、自作コードの警告なし。
- 追加修正: テスト音源モードは `.playback`（内蔵スピーカー可・マイク不使用）、マイクモードは `.playAndRecord` + A2DP のまま。稼働中に `useTestSource` を切り替えたら停止。`AVAudioEngineConfigurationChange` を購読し、稼働中なら teardown（自動再開なし）。design.md 4・5章、teach.md 第4章、detail.md、baton.md を更新。xcodebuild BUILD SUCCEEDED、自作コードの警告なし。
- 残課題: 実機＋有線ヘッドホンでの聴感確認とフィルタ値調整（低音量から）。F-04 のメーター、F-07 の声ループは後続フェーズ。

## 2026-11-13 15:50 — プロジェクト立ち上げ（理解・Git作成・基盤作成）【完了】

### 立案
- 依頼内容: Gemini が書いた仕様書（プロンプト.txt）を理解し、Swift Student Challenge 提出用アプリ HearingLens のリポジトリを GitHub に作成、運用ドキュメントと `.swiftpm` の骨組みを用意する。
- 計画: ①README と .gitignore を main に初回コミットして GitHub に public で作成 ②作業ブランチ `chore/project-foundation` で運用ドキュメント（CLAUDE.md / aim.md / detail.md / teach.md / todo.md / lessons.md / baton.md / docs/design.md / ADR / editor エージェント）を作成 ③`HearingLens.swiftpm` の骨組み（Package.swift, MyApp, HearingProfile, HearingAudioEngine のインターフェース, ContentView, OnboardingView）を作成 ④ビルド確認 ⑤ドラフトPR。
- 影響範囲: リポジトリ全体（ルートの管理ドキュメント、docs/、tasks/、.claude/、HearingLens.swiftpm/）。機能IDは F-01〜F-08 の土台のみ（実装はフェーズ2以降）。

### 進捗
- README.md / .gitignore を main に初回コミットし、GitHub に public で作成した。空リポジトリだったため、**初回のみ main に直接コミットした例外**として記録する（以後は main へ直接コミットしない）。
- ブランチ `chore/project-foundation` で運用ドキュメントと `.swiftpm` の骨組みを作成中。
- 運用md一式と `.swiftpm` 骨組みを作成した。
- 検証結果: swiftc typecheck（iOS 17 シミュレータ、strict concurrency complete）は 0 errors / 0 warnings で OK。xcodebuild は iOS プラットフォーム（シミュレータ）が未インストールのため未実施。
- 残課題: iOS プラットフォーム追加後のビルド・起動確認、フィルタ値の聴感調整、ドラフトPR。

### 進捗（2026-11-13 16:08 検証）
- `xcodebuild -downloadPlatform iOS` で iOS 26.5 シミュレータプラットフォームを導入した。
- `cd HearingLens.swiftpm && xcodebuild -scheme HearingLens -destination 'platform=iOS Simulator,name=iPhone 17' build` → BUILD SUCCEEDED（警告は AppIntents メタデータ抽出スキップのみ。AppIntents 未使用のため無害）。
- iPhone 17 シミュレータで起動確認: 初回起動で S-01 オンボーディングが表示され「はじめる」で閉じる。S-02 はモード切替、2x2 のプロファイルグリッド（選択は枠線＋チェックマーク）、プロファイル解説を表示。会話モードに切り替えると 話し方の配慮 のヒント、声量メーターのプレースホルダー、アドバイスを実践する トグルが出る。聴覚過敏を選ぶと内容が更新される。ヘッドホンなしでは状態が「未接続」になり、体験を開始 は無効でヒントが出る（設計どおり）。

### 完了
- 完了。残課題: フィルタ値の聴感調整・実機確認は次フェーズへ。
