# baton.md — 引き継ぎノート（上書き型）

最終更新: 2026-11-13

1. **現在地**: フェーズ2「音響エンジン」の実装が完了（ブランチ `feat/f01-audio-engine`）。`HearingAudioEngine` にノードグラフ・applyFilter・安全設計（リミッター / 上限0.6 / フェードイン）・権限/割り込み/ルート処理を実装し、`ContentView` に開始/停止・権限案内・エラー・Bluetooth 注意を追加。xcodebuild は BUILD SUCCEEDED（自作コードの警告なし）。teach.md 第3・4章、detail.md、todo.md、update.md も更新済み。
2. **進行中の作業**: なし。未コミット（コミットとpushはメインが行う）。
3. **次にやること**:
   - 変更をコミットして `feat/f01-audio-engine` を push、ドラフトPR
   - 実機＋有線ヘッドホンで聴感確認（必ず低い端末音量から）、フィルタ値・`maxOutputVolume`・リミッターの調整（todo.md フェーズ2の最後の項目は未チェック）
   - その後フェーズ3（F-02 日常モード・波形ビジュアライザー）へ。F-04 の RMS メーター（`inputLevel` に TODO(F-04)）と F-07 の声ループも後続
4. **重要な決定事項**: ADR-0001（.swiftpm・外部依存と音声アセットなし）、ADR-0002（リミッター＋音量上限）。ノイズは AVAudioSourceNode（`PinkNoiseGenerator`、`@unchecked Sendable`、`nonisolated` ファクトリで MainActor 隔離を避ける）。ノードは init で attach、start で connect。テスト音源モードはマイクを接続せず、ノイズ音量を最低 0.3 にする（F-07 で声ループに置き換え予定）。
5. **ハマりポイント**:
   - 聴覚過敏の +18dB は耳を傷める危険。リミッターと音量上限なしで実機テストしない
   - Bluetooth は遅延が大きい（約150ms）。テストは有線ヘッドホン推奨
   - シミュレーターにはヘッドホンがないので、音はテスト音源モードか実機で確認
   - xcodebuild の destination は実在するシミュレーター名（例: `platform=iOS Simulator,name=iPhone 17`）
   - リミッターのしきい値は既定のまま（未調整）
   - SSC の提出要項で生成AI利用の申告欄があるか確認する
6. **参照すべきドキュメント**: aim.md、docs/design.md（4章・5章）、docs/adr/0002、tasks/todo.md フェーズ2〜3、update.md（2026-11-13 16:20 のエントリ）、teach.md 第3・4章
