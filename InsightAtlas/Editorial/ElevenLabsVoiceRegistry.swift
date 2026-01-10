//
//  ElevenLabsVoiceRegistry.swift
//  InsightAtlas
//
//  ElevenLabs Voice Selection and Pacing Configuration.
//
//  Defines authoritative voice recommendations per reader profile,
//  with voice-specific pacing tunings for optimal narration quality.
//
//  GOVERNANCE:
//  - Voice selection is configuration-driven
//  - No voice logic in SwiftUI views
//  - Pacing tunings are per-voice, not per-profile
//  - Cache keys include voiceID for determinism
//
//  VERSION: 1.0.0
//

import Foundation

// MARK: - ElevenLabs Voice

/// Represents an ElevenLabs voice with its characteristics
struct ElevenLabsVoice: Codable, Equatable, Identifiable {
    let id: String
    let voiceID: String
    let name: String
    let description: String
    let characteristics: VoiceCharacteristics
    let recommendedProfiles: [ReaderProfile]
    let isPremium: Bool

    struct VoiceCharacteristics: Codable, Equatable {
        let tone: Tone
        let pace: Pace
        let warmth: Warmth
        let clarity: Clarity

        enum Tone: String, Codable {
            case neutral
            case warm
            case authoritative
            case conversational
            case reflective
        }

        enum Pace: String, Codable {
            case slow
            case moderate
            case brisk
        }

        enum Warmth: String, Codable {
            case cool
            case balanced
            case warm
        }

        enum Clarity: String, Codable {
            case standard
            case crisp
            case excellent
        }
    }
}

// MARK: - Voice Pacing Tuning

/// Voice-specific pacing adjustments
/// Applied on top of profile pacing for optimal narration
struct VoicePacingTuning: Codable, Equatable {
    /// Multiplier for base speaking rate (0.8 = 20% slower, 1.2 = 20% faster)
    let baseRateMultiplier: Double

    /// Multiplier for pause durations (0.8 = 20% shorter, 1.3 = 30% longer)
    let pauseMultiplier: Double

    /// Multiplier for emphasis intensity (0.9 = subtle, 1.2 = pronounced)
    let emphasisMultiplier: Double

    /// Recommended playback rates for this voice
    let preferredPlaybackRates: [Double]

    /// Default tuning (no adjustments)
    static let standard = VoicePacingTuning(
        baseRateMultiplier: 1.0,
        pauseMultiplier: 1.0,
        emphasisMultiplier: 1.0,
        preferredPlaybackRates: [1.0, 1.25, 1.5]
    )
}

// MARK: - ElevenLabs Voice Registry

/// Central registry of ElevenLabs voices with profile mappings
enum ElevenLabsVoiceRegistry {

    /// Version for cache invalidation
    static let version = "1.0.0"

    // MARK: - Voice Definitions

    /// Adam - Executive primary voice
    /// Clear, neutral delivery for focused listening and decision-making.
    static let adam = ElevenLabsVoice(
        id: "adam",
        voiceID: "pNInz6obpgDQGcFmaJgB", // ElevenLabs voice ID
        name: "Adam",
        description: "Clear, neutral delivery for focused listening and decision-making.",
        characteristics: ElevenLabsVoice.VoiceCharacteristics(
            tone: .authoritative,
            pace: .moderate,
            warmth: .cool,
            clarity: .excellent
        ),
        recommendedProfiles: [.executive],
        isPremium: true
    )

    /// Matthew - Executive backup voice
    /// Slightly warmer, still precise and composed.
    static let matthew = ElevenLabsVoice(
        id: "matthew",
        voiceID: "Yko7PKs6WkxO6Ho6f8Hq",
        name: "Matthew",
        description: "Slightly warmer, still precise and composed.",
        characteristics: ElevenLabsVoice.VoiceCharacteristics(
            tone: .neutral,
            pace: .moderate,
            warmth: .balanced,
            clarity: .crisp
        ),
        recommendedProfiles: [.executive],
        isPremium: true
    )

    /// Rachel - Practitioner primary voice
    /// Warm and instructional — ideal for applying ideas in real situations.
    static let rachel = ElevenLabsVoice(
        id: "rachel",
        voiceID: "21m00Tcm4TlvDq8ikWAM",
        name: "Rachel",
        description: "Warm and instructional — ideal for applying ideas in real situations.",
        characteristics: ElevenLabsVoice.VoiceCharacteristics(
            tone: .warm,
            pace: .moderate,
            warmth: .warm,
            clarity: .excellent
        ),
        recommendedProfiles: [.practitioner],
        isPremium: true
    )

    /// Sarah - Practitioner backup voice
    /// Reflective and calm, well-suited for thoughtful material.
    static let sarah = ElevenLabsVoice(
        id: "sarah",
        voiceID: "EXAVITQu4vr4xnSDxMaL",
        name: "Sarah",
        description: "Reflective and calm, well-suited for thoughtful material.",
        characteristics: ElevenLabsVoice.VoiceCharacteristics(
            tone: .reflective,
            pace: .moderate,
            warmth: .warm,
            clarity: .standard
        ),
        recommendedProfiles: [.practitioner],
        isPremium: true
    )

    /// Michael - Academic primary voice
    /// Measured pace and precise diction for long-form study.
    static let michael = ElevenLabsVoice(
        id: "michael",
        voiceID: "flq6f7yk4E4fJM5XTYuZ",
        name: "Michael",
        description: "Measured pace and precise diction for long-form study.",
        characteristics: ElevenLabsVoice.VoiceCharacteristics(
            tone: .neutral,
            pace: .slow,
            warmth: .cool,
            clarity: .excellent
        ),
        recommendedProfiles: [.academic],
        isPremium: true
    )

    /// Daniel - Academic backup voice
    /// Steady and neutral, suitable for dense analytical content.
    static let daniel = ElevenLabsVoice(
        id: "daniel",
        voiceID: "onwK4e9ZLuTAKqWW03F9",
        name: "Daniel",
        description: "Steady and neutral, suitable for dense analytical content.",
        characteristics: ElevenLabsVoice.VoiceCharacteristics(
            tone: .conversational,
            pace: .slow,
            warmth: .balanced,
            clarity: .crisp
        ),
        recommendedProfiles: [.academic],
        isPremium: true
    )

    /// Josh - Audio-First primary voice
    /// Conversational and engaging without losing clarity.
    static let josh = ElevenLabsVoice(
        id: "josh",
        voiceID: "TxGEqnHWrfWFTfGW9XjX",
        name: "Josh",
        description: "Conversational and engaging without losing clarity.",
        characteristics: ElevenLabsVoice.VoiceCharacteristics(
            tone: .conversational,
            pace: .brisk,
            warmth: .balanced,
            clarity: .crisp
        ),
        recommendedProfiles: [.skeptic], // Note: skeptic used as proxy for audio_first
        isPremium: true
    )

    /// Antoni - Audio-First backup voice
    /// More expressive, best for active listening at higher speeds.
    static let antoni = ElevenLabsVoice(
        id: "antoni",
        voiceID: "ErXwobaYiN019PkySvjV",
        name: "Antoni",
        description: "More expressive, best for active listening at higher speeds.",
        characteristics: ElevenLabsVoice.VoiceCharacteristics(
            tone: .conversational,
            pace: .brisk,
            warmth: .warm,
            clarity: .standard
        ),
        recommendedProfiles: [.skeptic],
        isPremium: true
    )

    // MARK: - Voice Pacing Tunings

    /// Pacing tuning for Adam (Executive)
    /// Faster, fewer pauses, subtle emphasis
    static let adamPacing = VoicePacingTuning(
        baseRateMultiplier: 1.05,
        pauseMultiplier: 0.8,
        emphasisMultiplier: 0.9,
        preferredPlaybackRates: [1.0, 1.25]
    )

    /// Pacing tuning for Rachel (Practitioner)
    /// Balanced, standard pacing
    static let rachelPacing = VoicePacingTuning(
        baseRateMultiplier: 1.0,
        pauseMultiplier: 1.0,
        emphasisMultiplier: 1.1,
        preferredPlaybackRates: [1.0, 1.25, 1.5]
    )

    /// Pacing tuning for Michael (Academic)
    /// Slower, longer pauses, pronounced emphasis
    static let michaelPacing = VoicePacingTuning(
        baseRateMultiplier: 0.9,
        pauseMultiplier: 1.3,
        emphasisMultiplier: 1.2,
        preferredPlaybackRates: [1.0]
    )

    /// Pacing tuning for Josh (Audio-First)
    /// Faster, shorter pauses, light emphasis
    static let joshPacing = VoicePacingTuning(
        baseRateMultiplier: 1.1,
        pauseMultiplier: 0.9,
        emphasisMultiplier: 1.05,
        preferredPlaybackRates: [1.25, 1.5, 2.0]
    )

    // MARK: - Registry Access

    /// All available voices
    static let allVoices: [ElevenLabsVoice] = [
        adam, matthew, rachel, sarah, michael, daniel, josh, antoni
    ]

    /// Get primary voice for a reader profile
    static func primaryVoice(for profile: ReaderProfile) -> ElevenLabsVoice {
        switch profile {
        case .executive:
            return adam
        case .practitioner:
            return rachel
        case .academic:
            return michael
        case .skeptic:
            return josh // skeptic serves as proxy for audio_first
        }
    }

    /// Get premium primary voice for a reader profile
    static func premiumPrimaryVoice(for profile: ReaderProfile) -> ElevenLabsVoice {
        let primary = primaryVoice(for: profile)
        if primary.isPremium {
            return primary
        }
        return allVoices.first(where: { $0.isPremium }) ?? primary
    }

    /// Check if a voice ID is premium.
    static func isPremiumVoiceID(_ voiceID: String) -> Bool {
        allVoices.contains(where: { $0.voiceID == voiceID && $0.isPremium })
    }

    /// Get backup voice for a reader profile
    static func backupVoice(for profile: ReaderProfile) -> ElevenLabsVoice {
        switch profile {
        case .executive:
            return matthew
        case .practitioner:
            return sarah
        case .academic:
            return daniel
        case .skeptic:
            return antoni
        }
    }

    /// Get pacing tuning for a specific voice
    static func pacingTuning(for voice: ElevenLabsVoice) -> VoicePacingTuning {
        switch voice.id {
        case "adam", "matthew":
            return adamPacing
        case "rachel", "sarah":
            return rachelPacing
        case "michael", "daniel":
            return michaelPacing
        case "josh", "antoni":
            return joshPacing
        default:
            return .standard
        }
    }

    /// Get voice by ID
    static func voice(byID id: String) -> ElevenLabsVoice? {
        allVoices.first { $0.id == id }
    }

    /// Get voice by ElevenLabs voice ID
    static func voice(byVoiceID voiceID: String) -> ElevenLabsVoice? {
        allVoices.first { $0.voiceID == voiceID }
    }
}

// MARK: - Voice Selection Configuration

/// Configuration for voice selection in audio generation
struct VoiceSelectionConfig: Codable, Equatable {
    let profile: ReaderProfile
    let voiceID: String
    let voiceName: String
    let pacingTuning: VoicePacingTuning
    let isBackupVoice: Bool

    /// Create configuration for profile with primary voice
    static func primary(for profile: ReaderProfile) -> VoiceSelectionConfig {
        let voice = ElevenLabsVoiceRegistry.primaryVoice(for: profile)
        let pacing = ElevenLabsVoiceRegistry.pacingTuning(for: voice)
        return VoiceSelectionConfig(
            profile: profile,
            voiceID: voice.voiceID,
            voiceName: voice.name,
            pacingTuning: pacing,
            isBackupVoice: false
        )
    }

    /// Create configuration for profile with premium primary voice
    static func premium(for profile: ReaderProfile) -> VoiceSelectionConfig {
        let voice = ElevenLabsVoiceRegistry.premiumPrimaryVoice(for: profile)
        let pacing = ElevenLabsVoiceRegistry.pacingTuning(for: voice)
        return VoiceSelectionConfig(
            profile: profile,
            voiceID: voice.voiceID,
            voiceName: voice.name,
            pacingTuning: pacing,
            isBackupVoice: false
        )
    }

    /// Create configuration for profile with backup voice
    static func backup(for profile: ReaderProfile) -> VoiceSelectionConfig {
        let voice = ElevenLabsVoiceRegistry.backupVoice(for: profile)
        let pacing = ElevenLabsVoiceRegistry.pacingTuning(for: voice)
        return VoiceSelectionConfig(
            profile: profile,
            voiceID: voice.voiceID,
            voiceName: voice.name,
            pacingTuning: pacing,
            isBackupVoice: true
        )
    }

    /// Create configuration with specific voice
    static func custom(profile: ReaderProfile, voice: ElevenLabsVoice) -> VoiceSelectionConfig {
        let pacing = ElevenLabsVoiceRegistry.pacingTuning(for: voice)
        return VoiceSelectionConfig(
            profile: profile,
            voiceID: voice.voiceID,
            voiceName: voice.name,
            pacingTuning: pacing,
            isBackupVoice: !voice.recommendedProfiles.contains(profile)
        )
    }
}
