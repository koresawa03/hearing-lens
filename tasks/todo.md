# todo.md — タスク

## フェーズ1: 設計と土台
- [x] 仕様理解
- [x] GitHub リポジトリ作成
- [x] 運用ドキュメント（CLAUDE.md / aim.md / detail.md / teach.md / docs/design.md / ADR / editor エージェント）
- [x] .swiftpm 骨組み
- [x] ビルド確認
  - iOS 26.5 シミュレータを `xcodebuild -downloadPlatform iOS` で導入。`xcodebuild -scheme HearingLens -destination 'platform=iOS Simulator,name=iPhone 17' build` → BUILD SUCCEEDED（警告は AppIntents メタデータ抽出スキップのみ。AppIntents 未使用のため無害）
- [x] Xcode / Swift Playgrounds で起動確認
  - シミュレーターで確認済み（S-01/S-02 の表示・操作は設計どおり）。実機・Swift Playgrounds(iPad)での確認は今後
- [ ] ドラフトPR
- [ ] SSC 提出要項の確認（生成AI利用の申告欄の有無、最新の制約）

## フェーズ2: 音響エンジン（F-01, F-06）
- [ ] F-01 AVAudioEngine のノードグラフ構築（入力 → EQ → リバーブ → リミッター → 出力）
- [ ] F-01 高音難聴（LPF 約1.4kHz）
- [ ] F-01 低音難聴（HPF 約620Hz + Small Room リバーブ）
- [ ] F-01 APD（バンドパス + Medium Hall + 環境ノイズ）※近似であることを明記
- [ ] F-01 聴覚過敏（3〜4kHz パラメトリックEQ +15〜18dB）
- [ ] F-01 プロファイルのリアルタイム切替（音切れ・クリックノイズなし）
- [ ] 安全: 出力段にピークリミッター（kAudioUnitSubType_PeakLimiter）と出力音量上限、開始時フェードイン（ADR-0002）
- [ ] F-06 AVAudioSession ルート監視、ヘッドホン接続時のみパススルー、抜けたら即停止
- [ ] 例外: マイク権限の拒否 / オーディオ割り込み（電話など）
- [ ] 実機＋有線ヘッドホンで確認（低音量から）

## フェーズ3: 日常モード（F-02）
- [ ] F-02 マイク → フィルタ → ヘッドホンの通し動作
- [ ] F-02 プロファイルの対象世代・解説の表示
- [ ] F-02 波形ビジュアライザー（SwiftUI Canvas、Reduce Motion 対応）
- [ ] Bluetooth ヘッドホン時の「有線推奨」遅延表示（約150ms）

## フェーズ4: 会話モード（F-03〜F-05）
- [ ] F-03 プロファイル別の話し方アドバイス表示
- [ ] F-04 声量・距離チェックメーター（RMS、しきい値は定数化）
- [ ] F-05 対応術実践スイッチ（ビフォー・アフター、フィルタ緩和）
- [ ] 表現レビュー（APD・聴覚過敏を難聴とひとまとめにしていないか、医学的再現でない旨）

## フェーズ5: テスト音源・オンボーディング（F-07, F-08）
- [ ] F-07 環境ノイズのコード合成
- [ ] F-07 話し声: AVSpeechSynthesizer.write(to:) でオフライン生成したバッファをループ再生する案を検証（アセット0）
- [ ] F-07 テスト音源モードの切替スイッチ（ヘッドホンなしでも体験可能）
- [ ] F-08 初回起動のオンボーディング（@AppStorage で一度だけ表示）

## フェーズ6: 磨き込み
- [ ] アクセシビリティ: VoiceOver ラベル、Dynamic Type、色だけに頼らない、Reduce Motion
- [ ] 3分導線の確認（初見の人が3分で核心体験に到達できるか）
- [ ] 25MB チェック（`.swiftpm` 全体のサイズ）
- [ ] 完全オフライン確認（機内モード）
- [ ] 実機テスト（iPhone / iPad、有線・Bluetooth・ヘッドホンなし）
- [ ] teach.md の第3〜5章を実装後に執筆、各章の質問を確認

## フェーズ7: 提出
- [ ] SSC 提出要項の最終確認（生成AI利用の申告欄、ファイル形式、締切）
- [ ] 提出用ファイルの最終ビルドとサイズ確認
- [ ] 提出
