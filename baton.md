# baton.md — 引き継ぎノート（上書き型）

最終更新: 2026-11-13

1. **現在地**: フェーズ1「設計と土台」はほぼ完了。運用ドキュメント一式と `HearingLens.swiftpm/` の骨組み（Package / MyApp / HearingProfile / HearingAudioEngine / ContentView / OnboardingView）を作成済み。swiftc typecheck（iOS 17 シミュレータ、strict concurrency complete）は 0 errors / 0 warnings。xcodebuild は iOS 26.5 シミュレータプラットフォーム未インストールのため未実施。
2. **進行中の作業**: ブランチ `chore/project-foundation`。ビルド確認（xcodebuild）と起動確認、ドラフトPRが残り。音響処理の実体は未実装（`HearingAudioEngine` は TODO(F-01)）。
3. **次にやること**:
   - Xcode > Settings > Components で iOS プラットフォームをインストール
   - `cd HearingLens.swiftpm && xcodebuild -scheme HearingLens -destination 'generic/platform=iOS Simulator' build`、Xcode / Swift Playgrounds で起動確認（ユーザー）
   - push して `gh pr create --draft`
   - フェーズ2「音響エンジン F-01 / F-06」へ。`feat/f01-audio-engine` のようなブランチを切り、tasks/todo.md を上から
4. **重要な決定事項**: ADR-0001（.swiftpm・外部依存と音声アセットなし）、ADR-0002（出力段にピークリミッター＋音量上限）。初回コミットのみ main に直接（空リポジトリのため）。以後は必ずブランチ。
5. **ハマりポイント**:
   - 聴覚過敏の +18dB は耳を傷める危険がある。リミッターと音量上限なしで実機テストしない
   - Bluetooth は遅延が大きい（約150ms）。テストは有線ヘッドホン推奨
   - SSC の提出要項で生成AI利用の申告欄があるか確認する
   - .swiftpm は Playgrounds 形式なので Xcode のターゲット設定とは勝手が違う
6. **参照すべきドキュメント**: aim.md、docs/design.md（2章フィルタ値、4章オーディオ処理、6章要検討）、docs/adr/、tasks/todo.md、update.md（2026-11-13 15:50 のエントリ）
