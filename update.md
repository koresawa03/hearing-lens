# update.md — 進捗ログ（追記型・新しいものが上）

## 2026-11-13 17:00 — フェーズ2-A: 音響エンジンの土台と安全まわり

### 立案
- 依頼: フェーズ2-A（低遅延化・入力ソース別セッション・EQ固定バンド・内蔵マイク固定/HFP除外・権限・停止の仕方・ルート変更理由・割り込み・構成変更・起動失敗）
- 方針（ユーザー承認済み）: PR #2 を土台に不足分を追加。ブランチ feat/f01-audio-engine-foundation を PR #2 のブランチから作成し、新しいドラフトPRに統合して PR #2 はクローズ。フィルタ値の適用は PR #2 で実装済みのため残す（2-B の先取り）。2-B の範囲は「値のランプ（なめらかな変化）・F-05 緩和の作り込み・聴感チューニング」。APD ノイズは AVAudioSourceNode（コード生成ピンクノイズ）のまま、F-07 の話し声は後で AVAudioPlayerNode を sourceMixer に追加する。
- 影響範囲: HearingAudioEngine.swift, ContentView.swift（文言のみ）, docs/design.md 4・5章, docs/adr/0003, teach.md 3・4章, detail.md, tasks/todo.md, baton.md, aim.md

### 進捗
- docs: design.md 4・5章を更新（低遅延化、入力ソース別セッション、EQ 4バンド固定表、内蔵マイク固定/HFP除外、停止の仕方、ルート変更理由、例外表）。ADR-0003 を追加。
- コード: HearingAudioEngine を更新（IO バッファ5ms・48kHz 希望、実値の os.Logger 出力、内蔵マイク固定、HFP 除外、EQ 4バンド固定（`EQBand`）、`stop()` はフェードアウト（約0.15秒、`isStopping`）、`stopImmediately()` は即停止、ルート変更の理由別処理と保険、割り込み・構成変更は即停止）。ContentView は Bluetooth 注意文と停止中のボタン無効化のみ。
- ビルド: xcodebuild（iPhone 17 シミュレータ）BUILD SUCCEEDED、自作コードの警告なし（AppIntents メタデータの警告のみ）。
- 文書: teach.md 第3・4章を書き直し、detail.md・tasks/todo.md（2-A / 2-B に分割）・baton.md・aim.md を更新。
- 残課題: 実機確認（下記）。ランプ・F-05 作り込み・聴感チューニングは 2-B。

#### 実機テスト手順（iPhone + 有線ヘッドホン。端末音量は最小から）
1. 有線ヘッドホンを挿し、端末音量を最小にしてから「体験を開始」。マイク許可を求められたら許可する。音量を少しずつ上げ、開始時に音が約0.5秒かけてなめらかに大きくなる（フェードイン）ことを確認
2. 体験中にヘッドホンを抜く。**即座に**止まり、ボタンが「体験を開始」に戻ることを確認（スピーカーから音が出ないこと）
3. ヘッドホンを挿し直す。**自動で再生が始まらず**、ヘッドホン状態の表示だけが「接続中」になることを確認
4. 体験中に電話をかける（別の端末から）または Siri を呼ぶ。止まること、終わっても自動で再開しないことを確認
5. 停止ボタンを押す。短くフェードアウトして止まり、クリック音が目立たないことを確認（約0.15秒の間はボタンが押せない）
6. 権限拒否: 設定 > プライバシーとセキュリティ > マイク で HearingLens をオフにして開始。説明と「設定を開く」ボタンが出ることを確認。確認後は同じ画面でオンに戻す（アプリ内の「設定を開く」からも行ける）
7. Bluetooth ヘッドホンに切り替えて開始。「有線ヘッドホン推奨（Bluetooth は約150msの遅延）」の注意が出ること、入力が内蔵マイクになっていること（下記のログの `inputs=` が `MicrophoneBuiltIn`）を確認
8. テスト音源モードをオンにし、ヘッドホンを外して開始。スピーカーからピンクノイズが鳴ることを確認（話し声は未実装）。稼働中にテスト音源のスイッチを切り替えると止まることも確認
9. ログで実際の値を確認: Xcode から実機にビルドして実行し、下部のコンソールで検索欄に `audio`（または `category:audio`）を入れる。`ioBufferDuration=` と `sampleRate=`（希望は 0.005 秒と 48000Hz）、`inputs=` / `outputs=` の種類を見る。希望と違う値なら記録しておく


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
