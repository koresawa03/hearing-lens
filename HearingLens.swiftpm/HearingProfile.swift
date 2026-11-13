// F-01 filter definitions / F-03 conversation tips / relaxed parameters for the F-05 practice switch
// Defines the four hearing profiles and the filter values handed to the audio engine.
import SwiftUI
import AVFoundation

/// Experience mode (F-02 everyday / F-03 conversation)
enum ExperienceMode: String, CaseIterable, Identifiable {
    case daily
    case conversation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: return "Everyday"
        case .conversation: return "Conversation"
        }
    }

    var symbolName: String {
        switch self {
        case .daily: return "ear"
        case .conversation: return "person.2.wave.2"
        }
    }
}

/// Filter settings handed to the audio engine. A nil item means "do not apply that processing".
struct FilterParameters: Equatable {
    /// Low-pass (attenuates above this frequency) in Hz
    var lowPassCutoff: Float?
    /// High-pass (attenuates below this frequency) in Hz
    var highPassCutoff: Float?
    /// Band-pass (center frequency in Hz, bandwidth in octaves)
    var bandPass: (center: Float, bandwidth: Float)?
    /// Parametric EQ (frequency in Hz, gain in dB, bandwidth in octaves)
    var peakEQ: (frequency: Float, gain: Float, bandwidth: Float)?
    /// Reverb type (nil means no reverb)
    var reverbPreset: AVAudioUnitReverbPreset?
    /// Reverb wet amount 0...100
    var reverbWetDryMix: Float = 0
    /// Amount of ambient noise mixed in, 0...1
    var noiseMix: Float = 0

    /// No processing (original sound)
    static let clear = FilterParameters()

    /// Relaxed version for the F-05 "Practice the tips" switch.
    /// Simple approach: halve the effect amounts (gain, wet, noise) and move
    /// cutoff-style values in the direction that weakens them. It never becomes fully clear.
    /// Use `.clear` if it should ever switch to fully clear.
    var relaxed: FilterParameters {
        var r = self
        // Raise the low-pass (more highs pass): about double
        r.lowPassCutoff = lowPassCutoff.map { min($0 * 2, 20_000) }
        // Lower the high-pass (more lows pass): half
        r.highPassCutoff = highPassCutoff.map { $0 / 2 }
        // Widen the band-pass
        r.bandPass = bandPass.map { ($0.center, $0.bandwidth * 2) }
        // Halve the boost
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

/// The four hearing profiles
enum HearingProfile: String, CaseIterable, Identifiable {
    case highFrequencyLoss
    case lowFrequencyLoss
    case apd
    case hyperacusis

    var id: String { rawValue }

    /// Full name (also used as the VoiceOver label)
    var title: String {
        switch self {
        case .highFrequencyLoss: return "High-Frequency Hearing Loss"
        case .lowFrequencyLoss: return "Low-Frequency Hearing Loss"
        case .apd: return "APD (Auditory Processing Disorder)"
        case .hyperacusis: return "Hyperacusis"
        }
    }

    /// Short name for the profile tabs
    var tabTitle: String {
        switch self {
        case .highFrequencyLoss: return "High-Freq"
        case .lowFrequencyLoss: return "Low-Freq"
        case .apd: return "APD"
        case .hyperacusis: return "Hyperacusis"
        }
    }

    /// One-line summary shown under the profile name on the main screen
    var shortDescription: String {
        switch self {
        case .highFrequencyLoss: return "High sounds and consonants fade, so words blur."
        case .lowFrequencyLoss: return "Low sounds fade and your ears feel plugged."
        case .apd: return "Hard to pick out a voice from background sound."
        case .hyperacusis: return "Everyday sounds feel too loud and sharp."
        }
    }

    /// SF Symbols (available on iOS 17)
    var symbolName: String {
        switch self {
        case .highFrequencyLoss: return "speaker.wave.1"
        case .lowFrequencyLoss: return "ear.trianglebadge.exclamationmark"
        case .apd: return "waveform"
        case .hyperacusis: return "bolt"
        }
    }

    /// Who it is common among
    var mainTargets: String {
        switch self {
        case .highFrequencyLoss: return "Older adults and people who work in noisy places"
        case .lowFrequencyLoss: return "Teens to working-age adults"
        case .apd: return "Students to adults"
        case .hyperacusis: return "Children to adults"
        }
    }

    /// How it sounds
    var description: String {
        switch self {
        case .highFrequencyLoss:
            return "High-pitched sounds become hard to hear. Consonants like s, f, th and t drop out, so words lose their crisp edges and blur together."
        case .lowFrequencyLoss:
            return "Low-pitched sounds become hard to hear. Your ears may feel plugged or full, and sounds can seem muffled and boomy."
        case .apd:
            return "Hearing itself is typical, but the brain has trouble separating a voice from background sound. Here it is approximated with a blurred voice, echo and noise — not exactly how it sounds."
        case .hyperacusis:
            return "This is not hearing loss. Everyday sounds feel too loud or even painful, and higher sounds can feel especially sharp."
        }
    }

    /// Tips for talking, shown in conversation mode (three per profile)
    var conversationTips: [String] {
        switch self {
        case .highFrequencyLoss:
            return [
                "Speak in a calm, slightly lower voice — don't shout.",
                "Slow down and pause between phrases.",
                "Face them so they can see your mouth."
            ]
        case .lowFrequencyLoss:
            return [
                "Move within about 1 meter (3 feet).",
                "Speak clearly in a mid-range voice — don't mumble.",
                "Move away from low hums like fans or engines."
            ]
        case .apd:
            return [
                "Choose a quiet place, away from cafés and crowds.",
                "Say their name or give a signal before you start.",
                "Use short sentences, and add notes or text."
            ]
        case .hyperacusis:
            return [
                "Use a gentle tone — never speak loudly near their ear.",
                "If they wear earmuffs or earplugs, respect it and keep talking.",
                "Avoid sudden noises and several people talking at once."
            ]
        }
    }

    /// Starting values handed to the audio engine (initial values, to be tuned by ear on a real device)
    var filter: FilterParameters {
        switch self {
        case .highFrequencyLoss:
            // Attenuate above about 1.3-1.5 kHz (spec). Use the midpoint, 1400 Hz, as the cutoff
            return FilterParameters(lowPassCutoff: 1_400)
        case .lowFrequencyLoss:
            // Attenuate below about 600-650 Hz (spec). Use 620 Hz as the cutoff.
            // Add a 20% small-room reverb for a plugged-up, resonant feel
            return FilterParameters(
                highPassCutoff: 620,
                reverbPreset: .smallRoom,
                reverbWetDryMix: 20
            )
        case .apd:
            // Keep the core voice band (around 1 kHz) and blur the surroundings with a 1.5-octave width.
            // 40% hall reverb and 30% ambient noise approximate trouble separating a voice from background
            return FilterParameters(
                bandPass: (center: 1_000, bandwidth: 1.5),
                reverbPreset: .mediumHall,
                reverbWetDryMix: 40,
                noiseMix: 0.3
            )
        case .hyperacusis:
            // Boost the center of the uncomfortable 3-4 kHz range (3500 Hz) by +16 dB (spec: +15-18 dB).
            // A 1-octave bandwidth emphasizes the piercing quality
            return FilterParameters(
                peakEQ: (frequency: 3_500, gain: 16, bandwidth: 1)
            )
        }
    }
}
