# baton.md — 引き継ぎノート（上書き型）

最終更新: 2026-11-13

1. **現在地**: フェーズ1「設計と土台」完了。運用ドキュメント一式と `HearingLens.swiftpm/` の骨組みを作成済み。xcodebuild（iPhone 17 シミュレータ）は BUILD SUCCEEDED、シミュレーターで S-01/S-02 の起動確認済み。PR #1 はドラフトで作成済み。
2. **進行中の作業**: なし（PR #1 のマージ待ち）。音響処理の実体は未実装（`HearingAudioEngine` は TODO(F-01)）。
3. **次にやること**:
   - PR #1 をマージ
   - `git checkout main && git pull origin main` の後 `feat/f01-audio-engine` ブランチを切り、F-01 / F-06 の音響エンジン実装へ（tasks/todo.md フェーズ2を上から）
   - 実機（iPad の Swift Playgrounds / iPhone）での起動確認は今後
4. **重要な決定事項**: ADR-0001（.swiftpm・外部依存と音声アセットなし）、ADR-0002（出力段にピークリミッター＋音量上限）。初回コミットのみ main に直接（空リポジトリのため）。以後は必ずブランチ。
5. **ハマりポイント**:
   - 聴覚過敏の +18dB は耳を傷める危険がある。リミッターと音量上限なしで実機テストしない
   - Bluetooth は遅延が大きい（約150ms）。テストは有線ヘッドホン推奨
   - SSC の提出要項で生成AI利用の申告欄があるか確認する
   - .swiftpm は Playgrounds 形式なので Xcode のターゲット設定とは勝手が違う
   - xcodebuild の destination は `generic/platform=iOS Simulator` ではなく、実在するシミュレーター名（例: `platform=iOS Simulator,name=iPhone 17`）を指定する
   - シミュレーターにはヘッドホンがないので、音の確認はテスト音源モードか実機で行う
6. **参照すべきドキュメント**: aim.md、docs/design.md（2章フィルタ値、4章オーディオ処理、6章要検討）、docs/adr/、tasks/todo.md、update.md（2026-11-13 15:50 のエントリ）
