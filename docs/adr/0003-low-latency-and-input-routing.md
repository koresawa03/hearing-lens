# ADR-0003: 低遅延化・入力ソース別のセッション設定・内蔵マイク固定（HFP 除外）

- 日付: 2026-11-13
- 状態: 採用

## 背景
会話モードでは、自分の声がヘッドホンから遅れて返ってくる。遅延聴覚フィードバック（DAF）と呼ばれ、遅れが大きいと話しにくくなる。体験の核である会話モードが成立しなくなるため、遅延を減らす必要がある。
また、AVAudioSession のカテゴリや入力ルートの選び方によって、ヘッドホンなしで音がほとんど聞こえない、スピーカーからの音をマイクが拾ってハウリングする、Bluetooth の通話用マイクに切り替わって高音域が出ない、といった問題が起きる。

## 決定
1. 低遅延化: `setPreferredIOBufferDuration` を約5ms、`setPreferredSampleRate` を 48kHz にする（いずれも定数）。OS が希望どおりにしないことがあるので、実際に適用された `ioBufferDuration` と `sampleRate` を `os.Logger` でログ出力して確認する
2. 入力ソース別のセッション: マイク体験は `.playAndRecord` / `.default` / `[.allowBluetoothA2DP]`（`.defaultToSpeaker` なし、`.allowBluetooth`＝HFP もなし）。テスト音源は `.playback`（マイクを使わないのでスピーカー出力可）。稼働中に `useTestSource` を切り替えたら停止する（自動再開しない）
3. 入力は内蔵マイクに固定: `availableInputs` から `.builtInMic` を探して `setPreferredInput` する。`headphonePortTypes` から `.bluetoothHFP` を外す。Bluetooth ヘッドホンは出力のみ（A2DP）

## 検討した他の案と捨てた理由
- バッファは既定（約10〜23ms）のまま: 遅延が積み重なり DAF で話しにくい。体験の核である会話モードが成立しにくい
- バッファをさらに小さく（〜1.5ms など）: CPU 負荷・音切れ（グリッチ）のリスクがあり、OS が受け付けないことも多い。5ms は実用的なバランス
- 常に `.playAndRecord` + `.defaultToSpeaker`: ヘッドホンなしでマイク音がスピーカーから出てハウリングする。安全原則に反する
- 常に `.playAndRecord`（defaultToSpeaker なし）: テスト音源が受話口から小さく鳴り、審査員に聞こえない
- `.allowBluetooth`（HFP）を許可して BT ヘッドセットのマイクを使う: 通話用の狭い帯域（約8kHz/16kHz サンプリング）になり、高音域を扱う高音難聴・聴覚過敏の体験が壊れる。A2DP も使えなくなる
- 入力を OS 任せにする: BT やケーブルのマイクに切り替わり、条件が揃わない

## 結果・影響
- 遅延が減り、会話モードで話しやすくなる
- 設定どおりの値になっているかは実機でログを見て確認する必要がある（OS が丸めることがある）
- Bluetooth は出力のみで、A2DP の遅延（約150ms）は残る。UI で有線ヘッドホンを推奨する
- 内蔵マイクが見つからない場合は開始できない（エラー表示）
