# baton.md — 引き継ぎノート（上書き型）

最終更新: 2026-11-17

00. **このセッションの更新（2026-11-17 15:00）**:
   - 現在地: PR #10（`fix/bluetooth-start-stop`）と、その上に積んだ PR（`fix/single-audio-engine`、base は `fix/bluetooth-start-stop`）。後者は HearingAudioEngine を MyApp が1つだけ所有する修正。シミュレーターと iPad 実機（Bluetooth A2DP、約4分48秒）で確認済み（`engine created id=1` のみ、受信ログはすべて engine=1）。この PR は実機確認済み。
   - 次にやること: ①PR #10 を `--delete-branch` なしでマージ ②この PR の base が main に変わったことを `gh pr view` で確認 ③この PR をマージ ④古いブランチを削除（tasks/lessons.md 参照）⑤フェーズ3（F-02 日常モード）。
0. **（1つ前）更新（2026-11-17 14:40）**:
   - 現在地: PR #10（`fix/bluetooth-start-stop`）。Bluetooth で開始直後に止まる不具合の修正を実機（iPad、Bluetooth A2DP）で確認済み。約6分止まらず、ヘッドホンを外すと `stop reason=headphonesRemoved` で即停止。
   - 次にやること: ①PR #10 をマージ ②HearingAudioEngine が2つ生成されている問題の調査（ルート変更ログが毎回2行。ContentView の `@State private var engine = HearingAudioEngine()` の初期化式が View 再生成のたびに評価されている疑い。tasks/todo.md に登録済み）③その後フェーズ3（F-02 日常モード）。
1. **現在地（それ以前）**:
   - スイッチ修正は fix/dark-mode-toggle の PR（base feat/f01-filter-tuning）。
   - フェーズ2-B「フィルタの作り込み」実装完了 → ドラフト PR #7（ブランチ `feat/f01-filter-tuning`、base main）。内容:
     - 値のランプ0.3秒（周波数は対数補間・smoothstep・途中から向かい直し）
     - LPF/HPF 2段（約24dB/oct、EQ 5バンド固定 HPF×2/LPF×2/ピーク、bypass 常に false）
     - APD のバンドパスを HPF＋LPF 化（未使用帯域は 20Hz/20kHz/0dB の効かない値へ）
     - リバーブのプリセット切替は wet→0→load→wet up
     - RelaxFactors（F-05）
     - DynamicsProcessor を PeakLimiter の前に追加（threshold 出発点 -3dB、範囲 -24〜0）
     - outputCap 0.2〜0.6（絶対上限0.6）
     - 調整パネル TuningPanel（TuningConfig.isEnabled=true、Copy values / Reset、保存なし）
   - シミュレーター確認済み: ビルド成功（isEnabled true/false 両方）、日本語 grep 0件、テスト音源稼働中にプロファイル7連続切替・F-05 3連続切替・スライダー操作で落ちない、Copy values がクリップボードに Swift コードで入る。
   - 未実施: 実機での聴感確認（update.md 2026-11-16 10:00 エントリの手順）。
   - マージ済み PR: #1 土台、#3 2-A（#2 は統合してクローズ）、#4 UI リデザイン＋英語化、#5 SSC 2027 規約ドキュメント、#6 球体＋波紋。
2. **進行中の作業**: ダークモードのスイッチ不具合の修正を `fix/dark-mode-toggle` ブランチで実装済み（`MonochromeToggleStyle`。Test Sound と Practice the tips に適用）。ドラフト PR（base は `feat/f01-filter-tuning`）を作成する段階。PR #7 がマージされると GitHub が base を main に自動で付け替える。
3. **次にやること**:
   - 実機テスト（PR #6 の 60fps と Accessibility Inspector、PR #7 の聴感）をユーザーにお願いしている。
   - その後フェーズ3: F-02 日常モード（波紋・球体を実際の音量に接続。HeroSphereView の波紋の位相は time×speed なので、level が変わると跳ぶ → 位相を積算する方式に直す）、F-04 RMS メーター、F-07 の話し声（AVSpeechSynthesizer、en-US）。
4. **重要な決定事項**:
   - ADR-0001（.swiftpm・アセット0。2027規約で容量は ZIP 500MB に緩和されたが、シンプルさ・説明しやすさ・オフラインのため継続）
   - ADR-0002（リミッター＋音量上限。2-B で DynamicsProcessor を前段に追加）
   - ADR-0003（低遅延 5ms/48kHz、マイクは .playAndRecord＋A2DP、テスト音源は .playback、内蔵マイク固定・HFP 除外）
   - ADR-0004（完全モノクロ・中央ビジュアル・OS のライト/ダーク連動）
   - SSC 2027: 締切 2027-02-28 23:59 PST、Xcode 27 / Swift Playground 4.7 以降、アプリ内は英語のみ、完全オフライン、3分、AI 利用は全開示（docs/ai-usage-log.md、作者欄は【作者が記入】に統一済み）
   - 古いリモートブランチ origin/feat/f01-audio-engine は残すとユーザーが決定済み（もう聞かない）
   - 提出前に TuningConfig.isEnabled を false にする。
5. **ハマりポイント**:
   - 実機ログは `DEVICECTL_CHILD_OS_ACTIVITY_DT_MODE=enable xcrun devicectl device process launch --console --terminate-existing --device <id> com.koresawa.HearingLens` で取れるが、出力が数分遅れてまとめて届くことがある
   - 実機ビルドは `xcodebuild ... -destination 'platform=iOS,id=00008112-000624D11A2A201E' -allowProvisioningUpdates DEVELOPMENT_TEAM=MY48Y23S2K`、インストールは `xcrun devicectl device install app --device 1BDCD3A6-22C6-5003-AE70-4050D7AC854F <app>`
   - 聴覚過敏の +16〜18dB は耳を傷める危険。実機は端末音量最小から。Peak gain は少しずつ
   - シミュレーターでスイッチを押すときは長めのタップ（0.15秒程度）でないと反応しないことがある
   - simctl のスクリーンショットは、操作直後だと1つ前の画面のことがある。1〜2秒待つ
   - シミュレーター: iPhone 17（368C6046-…）と iPad Pro 11-inch (M5) が起動中のことがある。`xcrun simctl ui booted …` は片方にしか効かないので機種名を指定する
   - xcodebuild の destination は `platform=iOS Simulator,name=iPhone 17`
   - Package.swift の accentColor `.presetColor(.indigo)` は外すとプレースホルダーアイコンのビルドが失敗するので残す（画面側は tint で上書き）
   - 新しい依頼ごとに未マージ PR があると update.md 等で競合する。先にマージするか、積み重ねるかをユーザーに確認する
   - ローカルの Xcode は 26.6。提出には Xcode 27 が必要（todo）
6. **参照すべきドキュメント**: update.md（2026-11-16 10:00 エントリ＝実機テスト手順）、docs/design.md 3章（S-02・デザイン方針）・4章（5バンド・ランプ・ダイナミクス）、docs/adr/0002〜0004、tasks/todo.md（フェーズ2-B・UI 仕上げ・フェーズ7）、teach.md 第3章・第5章、docs/ai-usage-log.md、PR #7
