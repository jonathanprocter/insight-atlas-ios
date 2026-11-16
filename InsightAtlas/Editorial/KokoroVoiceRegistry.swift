//
//  KokoroVoiceRegistry.swift
//  InsightAtlas
//
//  On-device voice catalogue for the Pocket TTS engine (Kyutai, via
//  sherpa-onnx). Pocket is a reference-audio model: each voice is a 10-second
//  clip shipped inside the model bundle under `voices/`, from which the engine
//  derives a speaker embedding. The type names keep their Kokoro prefix so the
//  persisted settings keys, the provider raw value and the rest of the
//  narration pipeline stay untouched.
//

import Foundation

struct KokoroVoice: UnifiedVoice, Codable, Equatable, Identifiable, Sendable {
    enum Accent: String, Codable, Sendable {
        case american
        case british
        case scottish
    }

    enum Presentation: String, Codable, Sendable {
        case feminine
        case masculine
    }

    let voiceID: String
    /// Stable index into the registry; Pocket has no speaker ids of its own,
    /// so this only identifies the reference clip to load.
    let speakerID: Int
    let name: String
    let accent: Accent
    let presentation: Presentation

    var id: String { voiceID }
    var provider: VoiceProvider { .kokoro }
    var previewText: String { VoicePreviewScript.primary }

    /// Reference clip inside the installed model directory.
    var referenceAudioRelativePath: String { "voices/\(voiceID).wav" }

    var description: String {
        "\(accent.displayName) English · \(presentation.displayName) presentation"
    }
}

private extension KokoroVoice.Accent {
    var displayName: String {
        switch self {
        case .american: return "American"
        case .british: return "British"
        case .scottish: return "Scottish"
        }
    }
}

private extension KokoroVoice.Presentation {
    var displayName: String {
        switch self {
        case .feminine: return "Feminine"
        case .masculine: return "Masculine"
        }
    }
}

enum KokoroVoiceRegistry {
    static let selectedVoiceStorageKey = "kokoro_selected_voice_id"
    static let version = "pocket-1.0.0"

    /// Clips come from Kyutai's published voice catalogue
    /// (huggingface.co/kyutai/tts-voices); names follow Kyutai's own labels.
    static let allVoices: [KokoroVoice] = [
        voice("alba", 0, "Alba", .scottish, .feminine),
        voice("anna", 1, "Anna", .british, .feminine),
        voice("eve", 2, "Eve", .british, .feminine),
        voice("fantine", 3, "Fantine", .british, .feminine),
        voice("jane", 4, "Jane", .american, .feminine),
        voice("charles", 5, "Charles", .british, .masculine),
        voice("george", 6, "George", .american, .masculine),
        voice("michael", 7, "Michael", .american, .masculine),
        voice("paul", 8, "Paul", .british, .masculine),
        voice("javert", 9, "Javert", .american, .masculine),
        voice("marius", 10, "Marius", .american, .masculine)
    ]

    static let defaultVoice = allVoices[0]

    static func voice(byID id: String) -> KokoroVoice? {
        voice(byVoiceID: id)
    }

    static func voice(byVoiceID voiceID: String) -> KokoroVoice? {
        allVoices.first { $0.voiceID == voiceID }
    }

    static func voice(speakerID: Int) -> KokoroVoice? {
        allVoices.first { $0.speakerID == speakerID }
    }

    static func isValidVoiceID(_ voiceID: String) -> Bool {
        voice(byVoiceID: voiceID) != nil
    }

    static func recommendedVoice(for profile: ReaderProfile) -> KokoroVoice {
        switch profile {
        case .executive:
            return voice(byVoiceID: "charles") ?? defaultVoice
        case .practitioner:
            return defaultVoice
        case .academic:
            return voice(byVoiceID: "fantine") ?? defaultVoice
        case .skeptic:
            return voice(byVoiceID: "javert") ?? defaultVoice
        }
    }

    static func voicesSorted(for profile: ReaderProfile) -> [KokoroVoice] {
        let recommended = recommendedVoice(for: profile)
        return [recommended] + allVoices.filter { $0.id != recommended.id }
    }

    private static func voice(
        _ voiceID: String,
        _ speakerID: Int,
        _ name: String,
        _ accent: KokoroVoice.Accent,
        _ presentation: KokoroVoice.Presentation
    ) -> KokoroVoice {
        KokoroVoice(
            voiceID: voiceID,
            speakerID: speakerID,
            name: name,
            accent: accent,
            presentation: presentation
        )
    }
}
