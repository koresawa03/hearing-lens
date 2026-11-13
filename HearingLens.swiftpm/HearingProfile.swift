// F-01 フィルタ定義 / F-03 会話モードのアドバイス / F-05 実践スイッチ用の緩和パラメータ
// 4つの聞こえ方プロファイルと、音響エンジンに渡すフィルタ値を定義する。
import SwiftUI
import AVFoundation

/// 体験モード（F-02 日常 / F-03 会話）
enum ExperienceMode: String, CaseIterable, Identifiable {
    case daily
    case conversation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: return "日常モード"
        case .conversation: return "会話モード"
        }
    }

    var symbolName: String {
        switch self {
        case .daily: return "ear"
        case .conversation: return "person.2.wave.2"
        }
    }
}

/// 音響エンジンに渡すフィルタ設定。nil の項目は「その処理を行わない」を意味する。
struct FilterParameters: Equatable {
    /// ローパス（この周波数より上を減衰） Hz
    var lowPassCutoff: Float?
    /// ハイパス（この周波数より下を減衰） Hz
    var highPassCutoff: Float?
    /// バンドパス（中心周波数 Hz, 帯域幅 オクターブ）
    var bandPass: (center: Float, bandwidth: Float)?
    /// パラメトリックEQ（周波数 Hz, ゲイン dB, 帯域幅 オクターブ）
    var peakEQ: (frequency: Float, gain: Float, bandwidth: Float)?
    /// リバーブの種類（nil なら使わない）
    var reverbPreset: AVAudioUnitReverbPreset?
    /// リバーブのウェット量 0...100
    var reverbWetDryMix: Float = 0
    /// 環境ノイズの混ぜ具合 0...1
    var noiseMix: Float = 0

    /// 処理なし（原音）
    static let clear = FilterParameters()

    /// F-05「アドバイスを実践する」用の緩和版。
    /// 簡易方針: 効果量（ゲイン・ウェット・ノイズ）を半分にし、
    /// カットオフ系は「効きが弱まる方向」へ動かす。完全にクリアにはしない。
    /// 実際に完全クリアへ切り替える場合は `.clear` を使う。
    var relaxed: FilterParameters {
        var r = self
        // ローパスは上げる（高音が通る）: 約2倍
        r.lowPassCutoff = lowPassCutoff.map { min($0 * 2, 20_000) }
        // ハイパスは下げる（低音が通る）: 半分
        r.highPassCutoff = highPassCutoff.map { $0 / 2 }
        // バンドパスは帯域を広げる
        r.bandPass = bandPass.map { ($0.center, $0.bandwidth * 2) }
        // ブーストは半分
        r.peakEQ = peakEQ.map { ($0.frequency, $0.gain / 2, $0.bandwidth) }
        r.reverbWetDryMix = reverbWetDryMix / 2
        r.noiseMix = noiseMix / 2
        return r
    }

    static func == (lhs: FilterParameters, rhs: FilterParameters) -> Bool {
        lhs.lowPassCutoff == rhs.lowPassCutoff
            && lhs.highPassCutoff == rhs.highPassCutoff
            && lhs.bandPass?.center == rhs.bandPass?.center
            && lhs.bandPass?.bandwidth == rhs.bandPass?.bandwidth
            && lhs.peakEQ?.frequency == rhs.peakEQ?.frequency
            && lhs.peakEQ?.gain == rhs.peakEQ?.gain
            && lhs.peakEQ?.bandwidth == rhs.peakEQ?.bandwidth
            && lhs.reverbPreset == rhs.reverbPreset
            && lhs.reverbWetDryMix == rhs.reverbWetDryMix
            && lhs.noiseMix == rhs.noiseMix
    }
}

/// 4つの聞こえ方プロファイル
enum HearingProfile: String, CaseIterable, Identifiable {
    case highFrequencyLoss
    case lowFrequencyLoss
    case apd
    case hyperacusis

    var id: String { rawValue }

    var title: String {
        switch self {
        case .highFrequencyLoss: return "高音難聴"
        case .lowFrequencyLoss: return "低音難聴"
        case .apd: return "APD（聴覚情報処理障害）"
        case .hyperacusis: return "聴覚過敏"
        }
    }

    /// SF Symbols（iOS 17 で利用可能なもの）
    var symbolName: String {
        switch self {
        case .highFrequencyLoss: return "speaker.wave.1"
        case .lowFrequencyLoss: return "ear.trianglebadge.exclamationmark"
        case .apd: return "waveform"
        case .hyperacusis: return "bolt"
        }
    }

    /// 色だけに頼らない補助的なアクセントカラー
    var tint: Color {
        switch self {
        case .highFrequencyLoss: return .orange
        case .lowFrequencyLoss: return .teal
        case .apd: return .purple
        case .hyperacusis: return .pink
        }
    }

    /// 主な対象
    var mainTargets: String {
        switch self {
        case .highFrequencyLoss: return "高齢者・騒音環境で働く人など"
        case .lowFrequencyLoss: return "若者〜働き盛りの世代"
        case .apd: return "若者・学生〜大人"
        case .hyperacusis: return "子ども〜大人"
        }
    }

    /// どう聞こえるか
    var description: String {
        switch self {
        case .highFrequencyLoss:
            return "高い音が聞こえにくくなり、サ行・タ行などの子音が欠けて、言葉の輪郭がぼやけて聞こえます。"
        case .lowFrequencyLoss:
            return "低い音が聞こえにくくなり、耳が詰まったような閉塞感と、音がこもって響く感じがあります。"
        case .apd:
            return "聴力は正常でも、背景の音と話し声を脳で分けて処理するのが難しい状態です。ここでは声がぼやけ、残響や雑音に埋もれる感覚で近似しています（実際の聞こえ方そのものではありません）。"
        case .hyperacusis:
            return "聴力が低下しているのではなく、日常の音が大きすぎる・痛いと感じやすい状態です。特に高めの音が刺さるように響きます。"
        }
    }

    /// 会話モードで表示する配慮のアドバイス（各3つ）
    var conversationTips: [String] {
        switch self {
        case .highFrequencyLoss:
            return [
                "高い声で叫ばず、少し低めの落ち着いた声で話す",
                "早口を避け、文節ごとにゆっくり話す",
                "正面を向いて口元を見せる"
            ]
        case .lowFrequencyLoss:
            return [
                "1メートル以内に近づいて話す",
                "ボソボソ話さず、中音域でハキハキ話す",
                "換気扇など低い騒音がない静かな場所へ移動する"
            ]
        case .apd:
            return [
                "カフェや人混みを避け、静かな場所で話す",
                "名前を呼ぶ・合図をして注意を向けてから話す",
                "短い文で区切る。メモや文字を併用する"
            ]
        case .hyperacusis:
            return [
                "耳元で大声を出さず、穏やかなトーンで話す",
                "相手がイヤーマフやイヤホンを着けていても尊重してそのまま話す",
                "突発的な音や、複数人の同時会話を避ける"
            ]
        }
    }

    /// 音響エンジンに渡す開始値（実機で聴きながら調整する前提の初期値）
    var filter: FilterParameters {
        switch self {
        case .highFrequencyLoss:
            // 約1.3〜1.5kHz 以上を減衰（仕様）。中間の 1400Hz をカットオフに採用
            return FilterParameters(lowPassCutoff: 1_400)
        case .lowFrequencyLoss:
            // 約600〜650Hz 以下を減衰（仕様）。620Hz をカットオフに採用。
            // 小部屋リバーブ 20% で閉塞感・響きを足す
            return FilterParameters(
                highPassCutoff: 620,
                reverbPreset: .smallRoom,
                reverbWetDryMix: 20
            )
        case .apd:
            // 声の中心帯域(1kHz 付近)を残し、1.5 オクターブ幅で周辺をぼかす
            // ホール残響 40% と環境ノイズ 30% で「声と背景の分離困難」を近似
            return FilterParameters(
                bandPass: (center: 1_000, bandwidth: 1.5),
                reverbPreset: .mediumHall,
                reverbWetDryMix: 40,
                noiseMix: 0.3
            )
        case .hyperacusis:
            // 不快に感じやすい 3〜4kHz の中心 3500Hz を +16dB ブースト（仕様 +15〜18dB）
            // 帯域幅 1 オクターブで刺さる感じを強調
            return FilterParameters(
                peakEQ: (frequency: 3_500, gain: 16, bandwidth: 1)
            )
        }
    }
}
