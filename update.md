# update.md — 進捗ログ（追記型・新しいものが上）

## 2026-11-17 14:00 — Bluetooth ヘッドホンで開始するとすぐ止まる不具合の修正

### 立案
- 症状: iPad 実機で Bluetooth（A2DP 出力＋内蔵マイク）のとき、開始を押すと開始直後に必ず止まる（4回中4回）。開始時のログでは経路は設計どおり（inputs=MicrophoneBuiltIn outputs=BluetoothA2DPOutput、5.33ms / 48kHz）。停止の理由はログに出ていない。
- 原因の見立て（コードから。実機ログで裏付けを取る）:
  1. 通知は「開始が終わった後」に届く。セッション設定中に OS が出した通知（ルート変更・エンジン構成変更）は `queue: .main` と `Task { @MainActor }` を経由するため、`isRunning = true` になった後に処理される。
  2. 構成変更の通知を受けると無条件で止めている（最有力）。A2DP で `setPreferredInput` を呼ぶと OS 側で入出力の組み直しが非同期で起き、`engine.start()` の後に `AVAudioEngineConfigurationChange` が届く。5ms バッファの希望も組み直しのきっかけになりうる。
  3. ルート変更では、組み直しの途中で出力が一瞬空になると「マイクモードでヘッドホンなし」の保険で止まる可能性がある。
- 方針（作者の方針: Bluetooth でも普通に体験できるように。有線推奨の注意は残す。安全方針は崩さない）:
  - 全停止経路に理由つきのログ（StopReason）を入れ、受信した通知も止めなくてもログに出す。
  - 構成変更は「止める」から「ヘッドホンが残っていれば組み直して 0 からフェードインで再開」に変更（2秒以内に3回で停止＋エラー）。
  - ルート変更で即停止する条件を明文化（ヘッドホンが外れた／マイクモードでヘッドホンなし）。
  - Bluetooth のときだけバッファの希望を 20ms に緩める。有線は 5ms のまま。
- 影響範囲: HearingAudioEngine.swift、docs/design.md（4・5章）、docs/adr/0003、detail.md、tasks/todo.md、teach.md 第4章、docs/ai-usage-log.md、baton.md。
- ブランチ: fix/bluetooth-start-stop を main から（PR #8 は自動クローズされ、同じ内容が PR #9 で main にマージ済みのため）。

### 進捗
- HearingAudioEngine.swift: `StopReason`、`performStop(reason:trigger:)`（全停止経路の入口）、受信ログ（ルート変更の理由名・割り込み・構成変更の動作）、`rebuildEngine()`（構成変更時の組み直し、2秒以内に3回まで）、`isStarting`、Bluetooth 時のバッファ約20ms を実装。
- docs/design.md 4・5章、ADR-0003 追記、detail.md、tasks/todo.md、teach.md 第4章（4.7）、ai-usage-log、baton.md を更新。
- xcodebuild: BUILD SUCCEEDED、自分たちのコードから警告なし。日本語 grep（swift ファイル）0件。
- 残課題: 実機 Bluetooth での確認（下記）。

### 実機 Bluetooth の確認手順（作者向け）
1. Xcode で iPad に実行する。端末の音量は最小から始める。
2. コンソール右下のフィルタに `audio` と入れる（HearingLens の audio ログだけ表示される）。
3. 確認すること:
   1. 開始して止まらないか
   2. ヘッドホンを外すと即停止し、`stop reason=headphonesRemoved` が出るか
   3. 稼働中にプロファイルを切り替えたり F-05 を操作しても止まらないか
   4. 開始時に出る受信ログ（`received routeChange reason=...` / `received configurationChange ... action=rebuild`）をコピーして共有する
   5. もし止まったら `stop reason=...` の行を共有する

### 進捗（実機確認 2026-11-17 14:31〜14:38、iPad Pro 11-inch 第4世代、Bluetooth A2DP ヘッドホン、xcrun devicectl でコンソール取得）
- 14:31:58 開始: ioBufferDuration=0.020000s、sampleRate=48000Hz、出力 BluetoothA2DPOutput、入力 MicrophoneBuiltIn（Bluetooth 時 20ms の希望が反映された）。
- 直後に routeChange reason=categoryChange が2回。headphones=true のため停止しなかった。configurationChange は engineRunning=true で ignored。
- 約6分間、停止なし（作者がプロファイル切替も実施）。
- 14:38:08 ヘッドホンを外す: routeChange reason=oldDeviceUnavailable、出力 Speaker → 1ms 以内に `stop reason=headphonesRemoved`（安全方針どおり即停止）。
- 結論: 修正後は Bluetooth で止まらない。旧コードの停止は、開始直後の通知（構成変更／ルート変更）を受けた停止処理と考えられる（旧コードには停止理由ログがなく、どちらだったかの直接の証拠はない）。
- 新たな発見（未対応）: ルート変更のログが毎回2行ずつ（running=true と running=false）出る。HearingAudioEngine のインスタンスが2つ存在し、両方が通知を受けている。原因の候補: ContentView の `@State private var engine = HearingAudioEngine()` が View の再生成のたびに初期化式を評価し、余分なインスタンスが残っている（通知の監視が生きている）可能性。動作への実害は今回なかったが、次の作業で調査する。

### 完了
- Bluetooth で開始直後に止まる不具合の修正は実機で確認済み。二重インスタンスの件は別件として tasks/todo.md で管理する。

## 2026-11-17 09:00 — ダークモードでスイッチの ON 表示が見えない不具合の修正

### 立案
- 依頼: ダークモードで ON のスイッチが見えない不具合を「ここで直す」。
- 原因: 画面全体に `.tint(Theme.foreground)` を掛けているため、ダークでは ON のトラックが白になり、白いノブと同化する（PR #4 からの不具合）。
- 方針: `Theme.swift` にモノクロ専用の `MonochromeToggleStyle` を作る。ON = 前景色のトラック＋背景色のノブ、OFF = 細い輪郭線のトラック＋補足色のノブ。状態はノブの位置と塗り/輪郭で示す（色に頼らない）。対象は 2 スイッチ（ⓘ シートの Test Sound、会話モードの Practice the tips）。`.tint` はスライダーにも効くので残す。
- あわせて: ai-usage-log の作者欄を【作者が記入】に統一、CLAUDE.md のルール文の修正、aim.md の現在のフォーカス更新、baton.md の更新。
- 影響範囲: Theme.swift、ContentView.swift、ProfileInfoSheet.swift、docs/design.md（3章）、detail.md、tasks/todo.md、docs/ai-usage-log.md、CLAUDE.md（1行）、aim.md、baton.md。
- ブランチ: fix/dark-mode-toggle（feat/f01-filter-tuning から積み重ね）

### 進捗
- Theme.swift に `MonochromeToggleStyle`（と `.monochrome`）と `toggle*` 定数を追加。Test Sound（ProfileInfoSheet.swift）と Practice the tips（ContentView.swift）に適用。
- OFF の輪郭線の不透明度 0.5 のコントラスト比: ダーク約 5.3:1、ライト約 3.5:1（どちらも 3:1 以上）。ON のノブ対トラック: ダーク約 19:1、ライト約 17:1。
- xcodebuild: BUILD SUCCEEDED、自分たちのコードから警告なし。日本語 grep（swift ファイル）0件。
- docs/design.md 3章、detail.md、tasks/todo.md、ai-usage-log（表記統一＋1行追記）、CLAUDE.md の1行、aim.md、baton.md を更新。
- 残課題: シミュレーターでのスクリーンショット確認（メインが実施）。

### 完了
- 実装とドキュメント更新は完了（スクリーンショット確認はメインが実施）。

## 2026-11-16 10:00 — フェーズ2-B: フィルタの作り込み（ランプ・2段フィルタ・F-05・調整パネル）

### 立案
- 依頼: フィルタ値の切り替えをなめらかにし（ランプ）、LPF / HPF を2段（24dB/oct）にして効きを強くし、F-05 緩和を作り込み、作者が実機で値を詰める調整パネルを作る。PR #6 はマージ済み。
- ユーザー決定（2つ）:
  1. リミッターのしきい値: Apple の PeakLimiter にはしきい値パラメータがないため、前段に `DynamicsProcessor` を置いてそのしきい値を調整対象にする。PeakLimiter は最終の安全装置として残す（ADR-0002 に追記）。
  2. APD のバンドパス: 専用のバンドパスではなく HPF＋LPF で作る。全バンドを常に有効にし、使わないバンドは「効かない値」（HPF 20Hz / LPF 20kHz / ピーク 0dB）へランプする。
- 計画（要約）:
  - docs 先行: design.md 2章 F-05 と 4章（5バンド構成・ランプ・ダイナミクス・調整パネル）、ADR-0002 追記
  - EQ は 5 バンド（HPF×2・LPF×2・ピーク）。値のランプは MainActor の Task（約60Hz・0.3秒、周波数は対数補間、smoothstep）。途中で再指定されたら「いまの値」から向かい直す
  - リバーブのプリセット切替は wet を 0 に下げてから `loadFactoryPreset`、その後 wet を上げる
  - `RelaxFactors`（HearingProfile.swift）、DynamicsProcessor、`outputCap`（0.2〜0.6、絶対上限 0.6）
  - `TuningConfig.swift` / `TuningPanel.swift`（ⓘ シート下部。提出前に `isEnabled = false`）
- 影響範囲: HearingAudioEngine.swift、HearingProfile.swift、ProfileInfoSheet.swift、ContentView.swift、TuningConfig.swift（新規）、TuningPanel.swift（新規）、docs/design.md、docs/adr/0002、teach.md 第3章、detail.md、tasks/todo.md、docs/ai-usage-log.md。
- ブランチ: feat/f01-filter-tuning

### 進捗
- docs/design.md（2章 F-05、4章のバンド構成・ランプ・ダイナミクス・調整パネル）と ADR-0002 の追記を先に更新。
- 実装: EQ を5バンド化（HPF×2・LPF×2・ピーク、bypass なし）、`AppliedState` と `retarget()` によるランプ、`RelaxFactors`、DynamicsProcessor（前段）、`outputCap`、`TuningConfig.swift` / `TuningPanel.swift`（新規）。
- DynamicsProcessor のパラメーター ID: `kDynamicsProcessorParam_Threshold` / `_HeadRoom` / `_ExpansionRatio` / `_OverallGain`（make-up は 0dB）。
- teach.md 第3章に解説を追加、detail.md / tasks/todo.md / docs/ai-usage-log.md を更新。
- xcodebuild（iPhone 17）BUILD SUCCEEDED（`TuningConfig.isEnabled` が true / false の両方）、日本語 grep 0件。
- 残課題: 実機確認（下記）、聴感チューニング、提出前に `isEnabled = false`。

#### 実機テスト手順（ヘッドホンをつけたまま行う）
端末の音量は最小から始め、少しずつ上げる。Peak gain を上げるときも少しずつ。
1. プロファイルを素早く何度も切り替えても、プツッという音が鳴らないか。
2. F-05（Practice the tips）の ON / OFF が、なめらかに変わるか。
3. 低音難聴 ↔ APD を切り替えたとき、リバーブが不自然に途切れず、自然に切り替わるか。
4. LPF・HPF を2段にして、1段のときより違いがはっきり分かるか。
5. ⓘ の調整パネルで値を変えて、音に反映されるか。"Copy values" を押し、メモなどに貼って内容を確認できるか。

## 2026-11-13 19:00 — 中央ビジュアル「球体＋水面の波紋」と見た目の小修正

### 立案
- 依頼: 平面の同心円を、光沢のある球体＋水面の楕円の波紋に置き換える。同時に、タブ右端のフェード、無効ボタンの輪郭、注意文の短縮と折り返しを直す。PR #5 は先にマージ済み。注意文はユーザー承認の "Plug in headphones or use Test Sound (ⓘ)"。
- 計画（要約）:
  - docs 先行: design.md 3章の中央ビジュアルの記述と注意文を更新する
  - 新規 `HeroSphereView.swift`（球体は Shape＋グラデーションを `drawingGroup`、波紋は Canvas）。`RippleView.swift` は削除し、ContentView の呼び出しを差し替える
  - 値はすべて Theme.swift の `Sphere` / `Ripple` にまとめる
  - ContentView: タブの右端フェード、無効ボタンは輪郭線＋補足色アイコン、注意文の折り返し
  - 動きは `isActive` のときだけ。Reduce Motion では完全静止。VoiceOver には出さない
- 影響範囲: HeroSphereView.swift（新規）、RippleView.swift（削除）、Theme.swift、ContentView.swift、docs/design.md 3章、teach.md 第5章、detail.md、tasks/todo.md、docs/ai-usage-log.md。
- ブランチ: feat/ui-hero-sphere

### 進捗
- docs/design.md 3章を更新（球体＋波紋の構成・質感・動き・Reduce Motion・VoiceOver・値の集約・描画負荷、注意文、デザイン方針の「動き」）。
- `HeroSphereView.swift` を新規作成、`RippleView.swift` を削除。`Theme.swift` に `Sphere` / `Ripple` を追加し、旧波紋用の定数を整理（`rippleMinHeight` 等は `heroMinHeight` 等に改名）。
- ContentView: タブ右端のフェード、無効ボタンの輪郭（不透明度 0.5。ダーク約 5.3:1 / ライト約 3.5:1）、注意文の短縮と折り返し。
- teach.md 第5章にコラム「SwiftUI で質感を作る」と想定質問、detail.md、tasks/todo.md、docs/ai-usage-log.md を更新。
- xcodebuild（iPhone 17）BUILD SUCCEEDED、日本語 grep 0件。
- 残課題: 実機での 60fps 確認、Accessibility Inspector Audit（ユーザー）。

#### 実機での負荷確認手順
シミュレーターは Mac の GPU で動くので、60fps と負荷は実機（iPhone 12 等の古めの端末が望ましい）で測る。稼働中に Test Sound を ON にして主ボタンで開始し、球体の呼吸と波紋が動いている状態で測る。
1. Xcode の Debug ナビゲーター（実機を実行中に開く）: CPU 使用率とフレームレート（FPS）のゲージを見る。CPU が高止まりしないこと、FPS が 60 付近であることを確認する。
2. Instruments の Animation Hitches テンプレート: Product > Profile から Animation Hitches を選び、10〜20秒記録する。Hitches（カクつき）が出ていないかを見る。出る場合は、blur の半径（`Theme.Sphere` の `*BlurRatio`）や波紋の本数（`Theme.Ripple.count`）を下げて再測定する。
3. ダーク/ライト、iPad でも同様に確認する。

## 2026-11-13 18:40 — SSC 2027 規約に合わせたドキュメント更新

### 立案
- 依頼: SSC 2027 の規約（作者が developer.apple.com の policy / eligibility で 2026-11-13 に確認）に合わせて、ドキュメントの根拠と運用ルールを更新する。主な変化は、容量上限が 25MB から ZIP 500MB に緩和、Xcode 27 / Swift Playground 4.7 以降が必須、AI 利用はすべて開示が必要、の3点。
- 計画（要約）:
  - CLAUDE.md・aim.md・docs/design.md 1・6章の SSC 制約を新規約に更新する
  - ADR-0001 は状態「採用」のまま、末尾に「2027年規約による追記」を足す（経緯の 25MB 記述は残す）
  - 新規 docs/ai-usage-log.md で AI 利用を記録する（作者の欄は【要記入】）。CLAUDE.md のワークフローに「作業完了時に1行追記」を追加
  - teach.md の 25MB 根拠を書き換え、tasks/todo.md・detail.md・baton.md を更新
- 影響範囲: CLAUDE.md, aim.md, docs/design.md 1・6章, docs/adr/0001, docs/ai-usage-log.md(新規), teach.md, tasks/todo.md, detail.md, baton.md。コード変更なし（HearingLens.swiftpm は触らない）。ブランチ docs/ssc-2027-rules。PR #4 は先にマージ済み。

### 進捗
- CLAUDE.md（SSC 制約・ワークフロー・Xcode 27 の注記）、aim.md、docs/design.md 1・6章、ADR-0001 追記節、docs/ai-usage-log.md（新規、5行、作者欄は【要記入】）、teach.md、tasks/todo.md、detail.md、baton.md を更新。
- grep（25 ?MB）: 残りは ADR-0001 の経緯部分と、「25MB 前提は撤廃」と書いた新規記述のみ。HearingLens.swiftpm の差分なし。

### 完了
- 完了（2026-11-13）。コード変更なし。

## 2026-11-13 18:00 — UI リデザイン（完全モノクロ・中央ビジュアル）＋アプリ内英語化

### 立案
- 依頼: 機能を増やさず、見た目と画面構成を変更する。完全モノクロ・黒基調・色覚の多様性に配慮。SSC 規約（All content must be in English）に合わせ、アプリ内の文字列をすべて英語にする。
- 計画（要約）:
  - docs 先行: design.md 1〜3章、ADR-0004、aim.md を更新してから実装する
  - 新規 `Theme.swift`（色・余白・字間などの値を集約。OS のライト/ダークに連動）、`RippleView.swift`（中央の波紋。`level` 0...1 と `isActive` を入力に持つ。今回は静止＋稼働中の呼吸のみ）、`ProfileInfoSheet.swift`（ⓘ シート）
  - `ContentView` を新レイアウト（上部バー／中央の波紋／プロファイル名＋説明／アドバイス／文字タブ／状態1行／音量スライダー＋丸い主ボタン）に作り直す
  - `HearingProfile` から `tint` を削除し、`shortDescription`・`tabTitle` を追加。`HearingAudioEngine` に `outputVolume` を追加しエラー文言を英語化。`Package.swift` のマイク用途説明を英語化
  - 英語文言は承認済みプラン（`~/.claude/plans/steady-wibbling-reef.md`）の文言表に従う
- 影響範囲: Theme.swift / RippleView.swift / ProfileInfoSheet.swift（新規）、ContentView / OnboardingView / HearingProfile / HearingAudioEngine / Package.swift、docs/design.md 1〜3章、docs/adr/0004、aim.md、teach.md 第5章、detail.md、tasks/todo.md
- ブランチ: feat/ui-redesign

### 進捗
- docs 先行の更新を開始（design.md、ADR-0004、aim.md）。コードは次の工程。
- コード実装（editor）: 新規 `Theme.swift` / `RippleView.swift` / `ProfileInfoSheet.swift`、`ContentView` を新レイアウトに全面書き換え、`OnboardingView` をモノクロ・英語化、`HearingProfile` から `tint` を削除して `tabTitle` / `shortDescription` を追加し全文字列を英語化、`HearingAudioEngine` に `outputVolume`（初期 0.3、上限 `maxOutputVolume` に丸め、稼働中は即反映、フェードインの到達値）を追加しエラー文言を英語化、`Package.swift` のマイク用途説明を英語化。Swift コメントはすべて英語化。
- コントラスト比（計算値）: 補足文字（前景 65%）は ダーク約 8.4:1、ライト約 5.7:1（どちらも 4.5:1 以上）。
- ビルド: xcodebuild（iPhone 17 シミュレータ）BUILD SUCCEEDED、自作コードの警告なし（AppIntents メタデータの警告のみ）。
- 日本語 grep（`HearingLens.swiftpm` の `*.swift`）: 0件。Theme.swift 以外に色リテラルなし（`Package.swift` の `accentColor: .presetColor(.indigo)` のみ。外すと placeholder アイコンのアセット生成でビルドが失敗するため残し、UI は `.tint(Theme.foreground)` で上書き）。
- 残課題: VoiceOver 実地確認、Accessibility Inspector のコントラスト監査、実機での見た目確認（ダーク/ライト、Dynamic Type 最大、Reduce Motion、iPad）。teach.md 第5章は別担当。
- 最大 Dynamic Type でのはみ出しを修正（S-02 を縦スクロール化、波紋の固定高、タイトルの縮小、状態行とボタンの @ScaledMetric 化）。

#### ユーザー向け確認手順
1. VoiceOver をオンにして、全操作を読み上げで確認する: モード切替（Experience mode の中の Everyday / Conversation、選択中が分かること）、プロファイルのタブ（正式名で読まれ、選択中が分かること）、ⓘ（About this profile）、アドバイスのタップ（Double-tap for the next tip）、Practice the tips のスイッチ、音量スライダー（Volume）、主ボタン（Start listening / Stop listening）、ⓘ シート内の Test Sound スイッチ
2. Xcode > Open Developer Tool > Accessibility Inspector でシミュレーターか実機を選び、Audit を実行する。コントラストや Dynamic Type の警告が出ないことを確認する

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
