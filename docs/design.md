# HearingLens 設計書

> 元はGeminiに書かせた仕様書（2026-11-13）を、機能ID・画面IDで整理し直したもの。
> 数値は「出発点」であり、実機で聞いて調整する（調整値は `FilterParameters` に集約する）。

## 1. 目的・対象・SSC制約

### 目的
若者から高齢者まで、見た目には分からない聞こえ方の多様性への理解を深め、配慮あるコミュニケーション（対応術）を身につけるための体験アプリ。

### 対象
- 利用者: 聴力に困りのない人（ヘッドホンで疑似体験する）
- プラットフォーム: iOS / iPadOS 17 以上、Swift Playgrounds App（`HearingLens.swiftpm`）、SwiftUI

### SSC 制約
- 提出は ZIP で **500MB まで**（SSC 2027 規約。旧 25MB 前提は撤廃）。外部音声・画像アセットを使わない方針は容量ではなく、シンプルさ・説明しやすさ・完全オフラインのため（ADR-0001）。音はコード合成、アイコンは SF Symbols、描画は SwiftUI
- **Xcode 27 または Swift Playground 4.7 以降**でビルド・動作すること。提出は Xcode アプリ、または app playground の ZIP（コマンドラインツール・パッケージは不可）
- 締切は 2027-02-28 23:59 PST（提出期間 2027-02-08〜02-28）。対応 OS は iOS / iPadOS / macOS / visionOS / tvOS / watchOS のどれでも可（本作は iOS / iPadOS）
- 完全オフラインで審査される。サインイン必須のアプリは失格
- **3分以内**で核心体験が完結する直感的な UI
- **完全オフライン**で動作
- 外部ライブラリなし、AVFoundation のみ
- アプリ内コンテンツ（画面・プロファイル名・解説・アドバイス・オンボーディング・エラー・VoiceOver ラベル・マイク用途説明）は**すべて英語**（SSC 規約: All content must be in English）。docs・コード外の説明は日本語のままでよい

## 2. 機能一覧

| ID | 機能 | 概要 |
|---|---|---|
| F-01 | 聴覚フィルタ4種 | 高音難聴・低音難聴・APD・聴覚過敏をリアルタイムに切替 |
| F-02 | 日常モード | マイク → フィルタ → ヘッドホン。対象世代・解説・中央の波紋ビジュアル |
| F-03 | 会話モード | F-02 に加え、プロファイル別の話し方アドバイスを表示 |
| F-04 | 声量・距離チェックメーター | マイクのRMSで「小さすぎ（遠い）/ 大きすぎ / 適切」を表示 |
| F-05 | 対応術実践スイッチ | ONでフィルタを緩和（ビフォー・アフター体験） |
| F-06 | ハウリング防止 | ヘッドホン接続時のみパススルー。抜けたら即停止 |
| F-07 | テスト音源モード | ヘッドホンなし・静かな部屋向けに、コード合成した環境音＋話し声ループで体験 |
| F-08 | オンボーディング | 初回起動の説明シート |

### F-01 聴覚フィルタ4種
体験中でもワンタップで切り替えられる。

| プロファイル | 主な対象 | 体験の狙い | フィルタ | 出発点の値 |
|---|---|---|---|---|
| 高音難聴（High-Frequency Hearing Loss） | 高齢者・騒音環境など | 子音（サ行・タ行）が欠け、言葉の輪郭がぼやける | ローパス（LPF） | カットオフ 1.4kHz（1.3〜1.5kHz） |
| 低音難聴（Low-Frequency Hearing Loss） | 若者〜働き盛り | 耳が詰まったような閉塞感と響き | ハイパス（HPF）+ リバーブ Small Room | カットオフ 620Hz（600〜650Hz）、リバーブ wetDry 20% |
| APD (Auditory Processing Disorder)（聴覚情報処理障害） | 学生〜大人 | 声と背景音を分離できない | バンドパス + リバーブ Medium Hall + 環境ノイズ | 中心 1kHz・帯域幅 1.5oct（約600Hz〜1.7kHz）、wetDry 40%、ノイズ混合 0.3（0〜1） |
| 聴覚過敏（Hyperacusis） | 子ども〜大人 | 小さな音も鋭く刺さる | パラメトリックEQ（高域ブースト） | 中心 3.5kHz（3〜4kHz）、+15〜18dB、帯域幅 約1oct |

- 表の数値は `HearingProfile.swift` の現行コード値に合わせた**未調整の出発点**。実機で聞いて調整する（調整したら本表も更新する）
- 聴覚過敏のブーストは出力段のピークリミッターと音量上限が前提（ADR-0002）
- APD のフィルタは**近似**であり、医学的な再現ではない（6章）

### F-02 日常モード（S-02）
- マイク入力にフィルタを適用してヘッドホンへ出力する
- 表示: 選択中プロファイルの名前と短い説明（shortDescription）。「主な対象世代」「聞こえ方の解説」は ⓘ シートに置く
- ビジュアライザーは画面中央の球体と波紋（`HeroSphereView`）。フェーズ3で音量に反応させる（今回は静止＋稼働中の呼吸と波紋の広がりのみ。`level` 0...1 を受け取る口だけ用意）

### F-03 会話モード（S-02）
F-02 と同じ処理に、話し方のアドバイス（見出し: Tips for talking）を加える。**英語版が正**で、日本語は参考。

| プロファイル | アドバイス（英語・正） | 日本語（参考） |
|---|---|---|
| 高音難聴 | Speak in a calm, slightly lower voice — don't shout. / Slow down and pause between phrases. / Face them so they can see your mouth. | 高い声で叫ばず、少し低めの落ち着いた声で話す／早口を避け、文節ごとにゆっくり話す／正面を向いて口元を見せる |
| 低音難聴 | Move within about 1 meter (3 feet). / Speak clearly in a mid-range voice — don't mumble. / Move away from low hums like fans or engines. | 1メートル以内に近づいて話す／ボソボソ話さず中音域でハキハキ話す／換気扇など低い騒音がない静かな場所へ移動する |
| APD | Choose a quiet place, away from cafés and crowds. / Say their name or give a signal before you start. / Use short sentences, and add notes or text. | カフェや人混みを避け静かな場所で話す／名前を呼ぶ・合図をして注意を向けてから話す／短い文で区切る・メモや文字を併用する |
| 聴覚過敏 | Use a gentle tone — never speak loudly near their ear. / If they wear earmuffs or earplugs, respect it and keep talking. / Avoid sudden noises and several people talking at once. | 耳元で大声を出さず穏やかなトーンで話す／相手がイヤーマフやイヤホンを着けていても尊重してそのまま話す／突発的な音や複数人の同時会話を避ける |

- S-02 の本体にはアドバイスを1つだけ表示し、タップで次へ進める。3つすべては ⓘ シートに載せる

### F-04 声量・距離チェックメーター
- マイク入力の RMS を監視し、3段階で表示する: 「声が小さすぎる（遠い）」「大きすぎる（聴覚過敏に対して）」「適切な声量」
- しきい値は定数にまとめる（実機で調整）
- 表示は色だけに頼らず、アイコン・文言を併用する

### F-05 対応術実践スイッチ
- 「Practice the tips」トグルをONにすると、フィルタが緩和されクリアな音声に近づく
- 配慮の有無で聞き取りやすさがどう変わるかを音で実感させる（ビフォー・アフター）
- 緩和はフィルタ値を**ランプ（0.3秒でなめらかに変化）**で動かして音切れ・プツッという音を避ける。ON/OFF の切り替えも、プロファイル切替と同じランプを通る（4章）
- 実装（`RelaxFactors` と `FilterParameters.relaxed(by:)`）: 倍率は構造体 `RelaxFactors` にまとめ、調整パネルから変更できる。既定値は次のとおり。完全にクリアにはしない（完全クリアは `FilterParameters.clear`）

| 項目 | `RelaxFactors` のプロパティ | 既定値 |
|---|---|---|
| ローパスのカットオフ | `lowPassMultiplier` | ×2.0（上限 `lowPassMax` = 20kHz） |
| ハイパスのカットオフ | `highPassMultiplier` | ×0.5 |
| バンドパス帯域幅 | `bandwidthMultiplier` | ×2.0 |
| パラメトリックEQ のゲイン | `gainFactor` | ×0.5 |
| リバーブ wet | `wetFactor` | ×0.5 |
| ノイズ混合 | `noiseFactor` | ×0.5 |

### F-06 ハウリング防止
- `AVAudioSession` のルートを監視し、ヘッドホン（有線 / Bluetooth / USB）接続時のみパススルーを有効にする
- ヘッドホンが抜かれたら即座に停止する

### F-07 テスト音源モード
- マイクの代わりに「コード合成した疑似環境音 + 話し声ループ」を再生し、4つのフィルタ効果を試せる
- ヘッドホンなしでも、静かな部屋でも体験できる（審査員向け）
- 環境ノイズ: コードで合成（ホワイト/ピンクノイズ等を加工）
- 話し声は英語音声（en-US）で生成する（SSC 規約により、アプリ内コンテンツは英語）
- 話し声: `AVSpeechSynthesizer.write(to:)` でオフライン生成したバッファを使う案（アセット0）。要検証（6章）
- 注意: テスト音源は内蔵スピーカー出力もありうるが、マイクに戻るとハウリングするため、テスト音源中はマイクを使わない

### F-08 オンボーディング（S-01）
- 初回起動時に、アプリの背景（若者から高齢者までの聴覚理解）と使い方、ヘッドホン着用の注意を簡潔に説明する
- 表示は一度だけ（`@AppStorage`）。後から見直せる導線があるとよい

## 3. 画面一覧

| ID | 画面 | 概要 |
|---|---|---|
| S-01 | オンボーディング | 初回起動の説明シート（英語）。背景・使い方・ヘッドホンと音量の注意・「理解のための近似であり医学的再現ではない」旨（"an approximation for understanding, not a medical simulation"） |
| S-02 | メイン | 完全モノクロの中央ビジュアル型。上部バー（モード文字切替・ⓘ）、中央の球体と波紋、プロファイル名と説明、会話モードのアドバイス / 実践スイッチ、プロファイル文字タブ、状態1行、音量スライダーと丸い主ボタン |

### S-02 メイン画面のレイアウト
上から順に（詳しい方針は ADR-0004）:
1. 上部バー: 左に Everyday / Conversation の文字切替（VoiceOver は "Experience mode"）、右に ⓘ（VoiceOver: "About this profile"）
2. 中央: 光沢のある球体と、その下の水面に広がる楕円の波紋（`HeroSphereView`）。画像は使わず、すべて SwiftUI で描く。`level`（0...1）と `isActive` を受け取る。音への接続はフェーズ3
   - 構成: 球体は画面幅の約45%。その下の水面に、扁平な楕円の波紋を5本、同心に置く。外側ほど薄く細くするが、最外周も背景から見える下限の不透明度を持つ
   - 質感: `RadialGradient` で丸みを出す。細い縁リングは `AngularGradient` で金属調にする。左上に blur した白い楕円のハイライトを置き、下に柔らかい影を落とす
   - ダーク: 暗い球＋白いハイライト。ライト: 明るい球＋柔らかい影。どちらもグレー階調のみ（有彩色なし）
   - 動き: `isActive` のときだけ、球体がゆっくり呼吸し、波紋が外へ広がって薄れる。`level` が大きいほど振幅と勢いが増す（音への接続はフェーズ3）。停止中は静止
   - Reduce Motion: 球体も波紋も完全に静止する
   - VoiceOver: 装飾なので `accessibilityHidden` にする
   - 値の集約: 大きさの比率・グラデーションの階調・ハイライト・影・波紋の本数と不透明度・周期などの値は、すべて `Theme.swift` にまとめる
   - 描画負荷: 球体は Shape＋グラデーションを `drawingGroup` で1枚にまとめて描く。波紋は `Canvas` で1パスで描く。60fps を目標にする
3. プロファイル名と shortDescription（例: "High sounds and consonants fade, so words blur."）
4. （会話モードのみ）アドバイスを1つ表示（タップで次へ。VoiceOver ヒント "Double-tap for the next tip"）と、Practice the tips スイッチ
5. プロファイル文字タブ（横スクロール可）。表示名は短縮名 High-Freq / Low-Freq / APD / Hyperacusis。VoiceOver は正式名（High-Frequency Hearing Loss など）
6. 状態・注意の1行（主ボタンの上）: ヘッドホン接続状態、Bluetooth の遅延注意、マイク拒否時の案内（"Open Settings" ボタン）、ヘッドホン未接続時は "Plug in headphones or use Test Sound (ⓘ)"（収まらないときは折り返す）
7. 音量スライダー（Volume。最大値は ADR-0002 の音量上限）と、丸い主ボタン（Start / Stop。VoiceOver は "Start listening" / "Stop listening"）
- iPad では余白を活かし、中央のビジュアルを大きく取る
- Dynamic Type・VoiceOver・Reduce Motion に対応する

### ⓘ シートの内容
- 見出し「Common among」: 主な対象（例: Older adults and people who work in noisy places）
- 見出し「How it sounds」: 聞こえ方の解説
- 見出し「Tips for talking」: アドバイス3つ
- 注意: "This is an approximation for understanding, not a medical simulation."
- Test Sound スイッチ（説明: Plays a built-in sound through the speaker — no headphones or microphone needed.）
- 「Show Introduction Again」ボタン（S-01 を再表示）と「Done」
- テスト音源スイッチが ⓘ 内になり、ヘッドホンのない審査員が見つけるまで1手増える。対策として、状態1行で案内する（上記 6）

### 3.x デザイン方針
- **外観**: OS のライト/ダーク設定に連動する（アプリ内の切替なし）。基準はダーク
- **色**: 白・黒・グレー階調のみ。有彩色は使わない
  - 背景: ダーク `#0E0E10`、ライト `#F5F5F3`
  - 前景: ダーク 白、ライト `#111111`
  - 補足文字・線は前景の不透明度で段階をつける。補足文字もコントラスト比 4.5:1 以上
- **選択・状態**: 色ではなく太さ・明るさ・形で示す。選択中タブ = semibold＋前景100%＋下に小さな点、非選択 = regular＋補足色
- **スイッチ**: `MonochromeToggleStyle`。ON = 前景色で塗ったトラック＋背景色のノブ、OFF = 細い輪郭線のトラック＋補足色のノブ。状態はノブの位置と塗り/輪郭で示し、色に頼らない
- **文字**: システムフォント・Dynamic Type のテキストスタイルのみ。小見出しは tracking を少し広げる。極端に細いウェイトは使わない
- **アイコン**: SF Symbols。ウェイトを統一する
- **余白**: 大きく取り、詰め込まない
- **動き**: アニメーションは控えめ。Reduce Motion 時は球体と波紋を静止する
- **値の集約**: 色・余白などの値は `Theme.swift` に集約し、他のファイルに直接書かない

## 4. オーディオ処理設計

### ノードグラフ
```
[マイク入力 AVAudioInputNode] ─┐
[環境ノイズ AVAudioSourceNode] ┼→ [sourceMixer] → [AVAudioUnitEQ(5バンド固定)] → [AVAudioUnitReverb] → [DynamicsProcessor] → [ピークリミッター] → [mainMixer] → 出力
[話し声 AVAudioPlayerNode(F-07, 後で追加)] ┘
```
- 入力は「マイク」か「テスト音源」のどちらか一方を使う（F-07）。テスト音源モードではマイクをつながない
- 環境ノイズ（APD 用・テスト音源用）は `AVAudioSourceNode` で、コードが生成するピンクノイズ。音声アセットは不要で、無限に鳴らせる
- F-07 の話し声は、後で `AVAudioPlayerNode` を sourceMixer に追加して流す（まだ未実装）
- リバーブ: `loadFactoryPreset` で `.smallRoom` / `.mediumHall` を使う。不要なときは wetDryMix を 0
- ダイナミクス＋リミッター: リバーブの後に `kAudioUnitSubType_DynamicsProcessor`（しきい値を調整できる）、その後に `kAudioUnitSubType_PeakLimiter`（最終の安全装置）を置く。どちらも `AVAudioUnitEffect` 経由。ミキサーの出力音量にも上限を設ける（ADR-0002、下の「ダイナミクスとリミッター」）
- 開始時は音量 0 からフェードインする

### EQ のバンド構成（固定・5バンド）
EQ は固定数（5）のバンドを最初に作る。プロファイルを切り替えても**ノードをつなぎ直さない**（つなぎ直すと音が途切れるため）。各バンドの役割は、コードの定数（`EQBand`）で「役割＋段番号」から決まる。

LPF / HPF は1段だと 12dB/oct で効きが弱いので、**同じ値の2段を重ねて 24dB/oct** にする（段数は定数 `passFilterStages = 2`）。同じ役割の段には必ず同じ値を入れる。

| バンド | 種類 | 使うプロファイル |
|---|---|---|
| band0, band1 | ハイパス（HPF）×2段 | 低音難聴、APD（下限側） |
| band2, band3 | ローパス（LPF）×2段 | 高音難聴、APD（上限側） |
| band4 | パラメトリック（ピークEQ） | 聴覚過敏 |

- **全バンドを常に有効**にする（bypass は常に false）。使わないバンドは「効かない値」へランプする: HPF 20Hz / LPF 20kHz / ピーク 0dB（定数）。bypass を切り替えないので、切替時にもクリックが出ない。`filterType` は初期化時に一度だけ設定する
- **APD のバンドパス**は専用バンドではなく、HPF＋LPF で作る。`FilterParameters.bandPass`（中心・帯域幅 oct）はデータとして持ち、エンジン内で次の式でカットオフへ変換する（1kHz・1.5oct のとき約 595Hz〜1.68kHz）:
  - 下限（HPF）= 中心 ÷ 2^(幅/2)、上限（LPF）= 中心 × 2^(幅/2)
- 各プロファイルが使うバンドは次のとおり
  - 高音難聴: LPF のみ（HPF は効かない値）
  - 低音難聴: HPF のみ（LPF は効かない値）
  - APD: HPF＋LPF（バンドパス相当）
  - 聴覚過敏: ピークのみ

### 値のランプ（なめらかな変化）
プロファイル切替・F-05 の ON/OFF・調整パネルの変更は、すべて `retarget()` を通って「目標値」を決め直す。値は一気に変えず、ランプで動かす。

- 「実際の値」（`AppliedState`: HPF・LPF のカットオフ、ピークの周波数・ゲイン・幅、リバーブ wet、ノイズ、リバーブのプリセット）を持ち、目標値へ向かわせる
- MainActor の Task で約 60Hz、合計 0.3 秒（定数 `rampDuration`）。毎フレーム、開始値→目標値を補間してノードへ書き込む
- 周波数は**対数補間**（`f0 × (f1/f0)^t`）、それ以外は線形。時間の進み t には smoothstep（`3t² − 2t³`）をかけ、始まりと終わりをなめらかにする
- ランプの途中で再び指定されたら、実行中のランプを cancel し、「いまの実際の値」から新しい目標へ向かい直す
- エンジン起動前（`start()` の中）は、ランプなしで目標値を即時適用する
- **リバーブのプリセット切替**（smallRoom ↔ mediumHall、なし を含む）は値の補間ができない。そこで ①前半 0.15 秒で wet を 0 へ下げる ②`loadFactoryPreset` の直後に wet を 0 に設定し直す（読込で wet が初期値に戻るため）③後半で目標の wet へ上げる、の順で切り替える
- ノイズの量は `noiseNode.volume` で調整する（テスト音源モードでは最低音量を保つ）

### ダイナミクスとリミッター
- Apple の PeakLimiter にはしきい値のパラメータがない（0dBFS 固定）ため、前段に `DynamicsProcessor` を置き、そのしきい値を調整対象にする（ADR-0002 追記）。PeakLimiter は最終の安全装置として残す
- `DynamicsProcessor` の設定: しきい値は `limiterThresholdDB`（出発点 -3dB、ほぼ素通し。調整範囲 -24〜0dB）、HeadRoom は小さめの定数でリミッターに近い動きにする、ExpansionRatio は 1（無効）、OverallGain は 0dB（増幅しない）
- 出力上限: `absoluteMaxOutputVolume = 0.6`（ADR-0002 の上限。これより上げない）。ユーザー音量の上限 `outputCap` は 0.2〜0.6 で調整でき（既定 0.6）、音量スライダーの最大値とフェードインの到達値は `outputCap` に従う
- ピークゲインの最大は +18dB（仕様の最大値）を超えない

### 調整パネル（提出前に無効化）
作者が実機で値を詰めるための "Tuning" パネル。ⓘ シートの一番下に `TuningConfig.isEnabled` のときだけ表示する。**提出前に `isEnabled = false` にする**（tasks/todo.md フェーズ7）。

- 選択中プロファイルの使う項目だけを表示する（高音難聴: Low-pass cutoff / 低音難聴: High-pass cutoff・Reverb wet / APD: Band center・Band width・Reverb wet・Noise / 聴覚過敏: Peak frequency・Peak gain・Peak width）。稼働中の変更は即反映（ランプ経由）
- 共通: Relax factors（6つ）、Limiter threshold、Output cap
- 周波数のスライダーは対数スケール。範囲は `TuningConfig` の定数（聴覚保護のため Peak gain 0〜+18dB、Limiter threshold -24〜0dB、Output cap 0.2〜0.6）
- 値は `HearingAudioEngine.tunedFilters` に持つ（保存しない）。"Copy values" で Swift コード形式の文字列をクリップボードへ入れ（全プロファイルの `FilterParameters(...)`、`RelaxFactors(...)`、threshold、outputCap）、"Reset" で出発点に戻す
- 表示は英語・モノクロ。注記 "For tuning only — disabled before submission."

### 低遅延化
- 自分の声が遅れて返ってくると話しにくくなる（遅延聴覚フィードバック、DAF）。会話モードの体験の核なので、遅延を減らす
- `setPreferredIOBufferDuration` で IO バッファを小さくする（約5ms、定数）。`setPreferredSampleRate` は 48kHz（定数）
- OS が希望どおりにしないことがあるため、`setActive(true)` の後に実際に適用された `ioBufferDuration` と `sampleRate` をデバッグ用にログ出力する（`os.Logger`、category は "audio"）
- 詳細と他の案は ADR-0003

### AVAudioSession
入力ソースによってカテゴリを変える。

| 体験 | カテゴリ | モード | オプション |
|---|---|---|---|
| マイク体験 | `.playAndRecord` | `.default`（`.measurement` は処理が無効化されることがあるため避ける） | `[.allowBluetoothA2DP]` |
| テスト音源 | `.playback` | `.default` | なし |

- マイク体験は `.defaultToSpeaker` を付けない（スピーカー出力はマイクが拾ってハウリングするため）。`.allowBluetooth`（HFP）も付けない（下記）
- `.playAndRecord` で `.defaultToSpeaker` なしだと、ヘッドホンがないとき通話用の受話口から出てほとんど聞こえない。テスト音源はマイクを使わないので `.playback` にして内蔵スピーカーから鳴らす（ヘッドホンなしの審査員向け）。ハウリングの心配はない
- 稼働中に `useTestSource` を切り替えたら停止する（カテゴリが食い違わないように）。自動再開はしない。再開はユーザーの操作
- 両方で `setPreferredSampleRate` と `setPreferredIOBufferDuration` を設定する
- `AVAudioEngineConfigurationChange`（入出力フォーマットの変化などでエンジンが自分で止まる通知）を購読し、フェードなしで即停止して状態を戻す。自動再開はしない

### 入力は内蔵マイクに固定
- マイク体験では `availableInputs` から `.builtInMic` を探して `setPreferredInput` で指定する
- ヘッドホン判定の `headphonePortTypes` から `.bluetoothHFP` を外す。HFP は通話音質（帯域が狭い）で、高音難聴・聴覚過敏の体験が成立しないため
- Bluetooth ヘッドホンは出力のみ（A2DP）。入力は常に内蔵マイク
- 内蔵マイクが見つからない場合はエラーを表示して開始しない（ADR-0003）

### 停止の仕方
- ユーザー操作の停止: 出力音量を短くフェードアウト（約0.15秒）してから停止する
- ヘッドホン抜去・割り込み・構成変更: フェードなしで**即停止**する（ハウリング防止・安全のほうがクリック音より優先）
- フェードアウト中は開始・再停止の操作を受け付けない（UI のボタンも無効にする）

### ルート変更の処理（F-06）
- `AVAudioSession.routeChangeNotification` を購読し、理由（reason）を取り出して処理する
- 現在のルートの出力に、ヘッドホン系ポート（`.headphones` / `.bluetoothA2DP` / `.bluetoothLE` / `.usbAudio`）があるかで `isHeadphoneConnected` を更新する
- reason が `.oldDeviceUnavailable` でヘッドホンがなくなった → 即停止
- reason が `.newDeviceAvailable`（ヘッドホン接続）→ 状態の更新のみ。自動で開始しない
- 保険: マイクモード稼働中にヘッドホンが無くなったら、理由に関係なく即停止する
- テスト音源モードはマイクを使わないので、ヘッドホンが外れても止めない

### 割り込み
- `AVAudioSession.interruptionNotification` を購読する
- 割り込み開始（電話など）: フェードなしで即停止して UI に反映
- 割り込み終了: 自動再開せず、ユーザーの操作で再開する（急な再生を避ける）

## 5. 例外

| 状況 | 動作 |
|---|---|
| マイク権限の拒否 | パススルーを開始しない。説明と「設定を開く」導線、テスト音源モードの案内を表示 |
| ヘッドホン未接続 | マイクパススルーしない（F-06）。接続を促す。テスト音源は利用可（ただしマイクは使わない） |
| 内蔵マイクが見つからない | 「内蔵マイクが見つかりませんでした」を表示し、開始せず停止状態に戻す |
| 割り込み（電話・Siri など） | 即停止し、終了後もユーザー操作で再開 |
| ルート変更（抜去: `oldDeviceUnavailable`） | ヘッドホンがなくなったら即停止 |
| ルート変更（接続: `newDeviceAvailable`） | 状態の更新のみ。自動で再生しない（ユーザー操作を待つ） |
| 稼働中にテスト音源の ON/OFF を切り替え | 即停止（再開はユーザー操作） |
| Bluetooth 接続 | 遅延の注意（約150ms）と有線推奨を表示。入力は内蔵マイク、出力のみ A2DP |
| エンジン構成変更（AVAudioEngineConfigurationChange） | 即停止して状態を戻す。自動再開しない |
| エンジン起動失敗 | エラーを表示し停止状態に戻す（クラッシュしない） |

## 6. 要検討

1. **聴覚過敏の +18dB と聴覚保護**: 出力段にピークリミッター（`kAudioUnitSubType_PeakLimiter`、`AVAudioUnitEffect` 経由）と出力音量上限が必須。審査員の耳を守る。ブースト量自体も実機で聞いて控えめにする（ADR-0002）
2. **Bluetooth の遅延**: 約150ms の遅延があり、自分の声が遅れて返って話しにくい。有線を推奨する表示を出す。Bluetooth は A2DP 出力 + 内蔵マイク（HFP は使わない。ADR-0003）
3. **用語と表現**: APD・聴覚過敏は「聴力の低下（難聴）」ではない。文言でひとまとめにしない。APD のフィルタは近似であると明記する。医学的な再現ではない旨の注意書きを S-01 と S-02（ⓘ シート）に置く
   - 英語表現のルール: "suffer from" / "victim" / "afflicted" を使わない。APD と Hyperacusis を "hearing loss" と呼ばない
   - "an approximation for understanding, not a medical simulation" を S-01 と ⓘ シートに入れる
   - 高音難聴の子音の例は英語の s, f, th, t
4. **F-07 の話し声**: `AVSpeechSynthesizer.write(to:)` でオフライン生成したバッファを使う案（アセット0）。生成速度・品質・iOS の音声が端末に入っているかを検証する。ノイズはコード合成
5. **生成AI利用の申告**: 確定。AI ツールは補助として使用可だが、使用をすべて開示する必要がある。本人の大きな貢献と技術的理解を示すこと。提出フォームの作文は本人が書く。docs/ai-usage-log.md に毎回記録する。teach.md で、作者が自分で設計と実装を説明できる状態を作る
6. **SSC 制約の確認**: 提出 ZIP が 500MB 以内、Xcode 27 でビルドが通る、3分以内で核心体験、完全オフライン。提出前にサイズとビルドを確認する。他人の素材・OSS を使う場合はライセンス順守と理由の説明が必要

## 7. 原文について
このドキュメントの元は、Gemini に書かせた仕様書（2026-11-13、`プロンプト.txt`）。
機能一覧の機能ID・画面ID、具体的なフィルタ値、オーディオ処理設計、例外、要検討事項は、整理の際に追記した。
仕様の正は本書。
