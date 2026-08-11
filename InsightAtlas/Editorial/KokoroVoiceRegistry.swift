//
//  KokoroVoiceRegistry.swift
//  InsightAtlas
//
//  Offline Kokoro v1.0 English voice catalog.
//

import Foundation

struct KokoroVoice: UnifiedVoice, Codable, Equatable, Identifiable, Sendable {
    enum Accent: String, Codable, Sendable {
        case american
        case british
    }

    enum Presentation: String, Codable, Sendable {
        case feminine
        case masculine
    }

    let voiceID: String
    let speakerID: Int
    let name: String
    let accent: Accent
    let presentation: Presentation

    var id: String { voiceID }
    var provider: VoiceProvider { .kokoro }
    var previewText: String { VoicePreviewScript.primary }

    var description: String {
        "\(accent.displayName) English · \(presentation.displayName) presentation"
    }
}

private extension KokoroVoice.Accent {
    var displayName: String {
        switch self {
        case .american: return "American"
        case .british: return "British"
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
    static let version = "1.0.0"

    static let allVoices: [KokoroVoice] = [
        voice("af_alloy", 0, "Alloy", .american, .feminine),
        voice("af_aoede", 1, "Aoede", .american, .feminine),
        voice("af_bella", 2, "Bella", .american, .feminine),
        voice("af_heart", 3, "Heart", .american, .feminine),
        voice("af_jessica", 4, "Jessica", .american, .feminine),
        voice("af_kore", 5, "Kore", .american, .feminine),
        voice("af_nicole", 6, "Nicole", .american, .feminine),
        voice("af_nova", 7, "Nova", .american, .feminine),
        voice("af_river", 8, "River", .american, .feminine),
        voice("af_sarah", 9, "Sarah", .american, .feminine),
        voice("af_sky", 10, "Sky", .american, .feminine),
        voice("am_adam", 11, "Adam", .american, .masculine),
        voice("am_echo", 12, "Echo", .american, .masculine),
        voice("am_eric", 13, "Eric", .american, .masculine),
        voice("am_fenrir", 14, "Fenrir", .american, .masculine),
        voice("am_liam", 15, "Liam", .american, .masculine),
        voice("am_michael", 16, "Michael", .american, .masculine),
        voice("am_onyx", 17, "Onyx", .american, .masculine),
        voice("am_puck", 18, "Puck", .american, .masculine),
        voice("am_santa", 19, "Santa", .american, .masculine),
        voice("bf_alice", 20, "Alice", .british, .feminine),
        voice("bf_emma", 21, "Emma", .british, .feminine),
        voice("bf_isabella", 22, "Isabella", .british, .feminine),
        voice("bf_lily", 23, "Lily", .british, .feminine),
        voice("bm_daniel", 24, "Daniel", .british, .masculine),
        voice("bm_fable", 25, "Fable", .british, .masculine),
        voice("bm_george", 26, "George", .british, .masculine),
        voice("bm_lewis", 27, "Lewis", .british, .masculine)
    ]

    static let defaultVoice = allVoices[3]

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
            return voice(byVoiceID: "bm_daniel") ?? defaultVoice
        case .practitioner:
            return defaultVoice
        case .academic:
            return voice(byVoiceID: "bf_emma") ?? defaultVoice
        case .skeptic:
            return voice(byVoiceID: "am_puck") ?? defaultVoice
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
