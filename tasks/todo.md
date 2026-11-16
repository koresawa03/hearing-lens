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
- [x] SSC 提出要項の確認（SSC 2027 規約を 2026-11-13 に確認。ZIP 500MB、Xcode 27 / Playground 4.7、AI 全開示。CLAUDE.md の SSC 制約に反映）
- [ ] Xcode 27 へ更新し、ビルドが通ることを確認（現在のローカルは Xcode 26.6）

## UI リデザイン（完全モノクロ・中央ビジュアル・英語化）
- [x] Theme.swift（色・余白・サイズの集約。コントラスト比を計算: ダーク約 8.4:1 / ライト約 5.7:1）
- [x] RippleView.swift（Canvas の同心円、呼吸アニメ、Reduce Motion で静止）
- [x] ProfileInfoSheet.swift（ⓘ シート: 詳細・Test Sound・オンボーディング再表示）
- [x] ContentView を中央ビジュアル型に再構成（モード切替・波紋・文字タブ・状態1行・音量スライダー・丸い主ボタン）
- [x] OnboardingView を同じ見た目に揃える
- [x] HearingProfile: `tint` 削除、`tabTitle` / `shortDescription` 追加、全文字列を英語化
- [x] HearingAudioEngine: `outputVolume` 追加、エラー文言を英語化
- [x] Package.swift のマイク用途説明を英語化
- [x] Swift コメントをすべて英語化、日本語 grep 0件
- [x] xcodebuild BUILD SUCCEEDED
- [ ] VoiceOver 実地確認（ユーザー）
- [ ] Accessibility Inspector のコントラスト監査（ユーザー）
- [ ] 実機での見た目確認（ダーク/ライト、Dynamic Type 最大、Reduce Motion、iPad）

## UI 仕上げ（球体＋水面の波紋、小修正）
- [x] HeroSphereView.swift（光沢のある球体＋水面の楕円の波紋。呼吸・波紋の広がり・Reduce Motion で静止）、RippleView.swift を削除
- [x] Theme.swift に `Sphere` / `Ripple` の定数を集約
- [x] タブ右端のフェード（末尾の余白つき）
- [x] 無効ボタンを輪郭線に変更（コントラスト比 ダーク約 5.3:1 / ライト約 3.5:1）
- [x] 注意文を "Plug in headphones or use Test Sound (ⓘ)" に短縮し、折り返しを許可
- [x] docs/design.md 3章、teach.md 第5章コラム、detail.md を更新
- [x] xcodebuild BUILD SUCCEEDED、日本語 grep 0件
- [ ] 実機での 60fps 確認（iPhone 12 等の古め端末）
- [ ] Accessibility Inspector Audit（ユーザー）

## フェーズ2-A: 音響エンジンの土台と安全まわり（F-01, F-06）
- [x] F-01 AVAudioEngine のノードグラフ構築（入力 → EQ → リバーブ → リミッター → 出力）
- [x] F-01 EQ を4バンド固定（HPF / LPF / バンドパス / ピークEQ）、使わないバンドは bypass、つなぎ直さない
- [x] F-01 フィルタ値の適用（4プロファイル。2-B の先取り）
- [x] 低遅延化: IO バッファ約5ms・48kHz の希望指定、実際の値のログ出力（ADR-0003）
- [x] 入力ソース別セッション（マイク `.playAndRecord` + A2DP / テスト音源 `.playback`）
- [x] 入力を内蔵マイクに固定、HFP 除外（ADR-0003）
- [x] 安全: 出力段にピークリミッター、出力音量上限、開始時フェードイン（ADR-0002）
- [x] 停止: ユーザー操作はフェードアウト（約0.15秒）、抜去・割り込み・構成変更は即停止
- [x] F-06 ルート変更の理由別処理（`oldDeviceUnavailable` で即停止、`newDeviceAvailable` は自動開始しない）、保険の即停止
- [x] 例外: マイク権限の拒否 / 割り込み / 構成変更 / 内蔵マイクなし / 起動失敗
- [ ] 実機＋有線ヘッドホンで確認（低音量から。手順は update.md の 2026-11-13 17:00 エントリ）

## フェーズ2-B: フィルタの作り込み
- [ ] フィルタ値のランプ（なめらかな変化）。プロファイル切替・F-05 切替で値を少しずつ動かす
- [ ] F-05 緩和の作り込み
- [ ] 聴感チューニング（実機で聞いて各プロファイルの値を調整し、design.md の表を更新）
- [ ] リミッターしきい値・`maxOutputVolume` の調整
- [ ] フィルタ傾斜: LPF/HPF は 12dB/oct で弱い。多段化（バンドを重ねる）を検討

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
- [ ] 提出 ZIP が 500MB 以内か確認（Xcode 27 / Swift Playground 4.7 で開けることも）
- [ ] 完全オフライン確認（機内モード）
- [ ] 実機テスト（iPhone / iPad、有線・Bluetooth・ヘッドホンなし）
- [ ] teach.md の第3〜5章を実装後に執筆、各章の質問を確認

## フェーズ7: 提出
- [ ] SSC 提出要項の最終確認（生成AI利用の申告欄、ファイル形式、締切）
- [ ] 提出用ファイルの最終ビルドとサイズ確認
- [ ] AI 利用の開示文を docs/ai-usage-log.md から作成
- [ ] 提出フォームの作文は自分で書く（AI に書かせない）
- [ ] 提出
