//
//  OpenAIVoiceRegistry.swift
//  InsightAtlas
//
//  OpenAI Voice Selection and Configuration.
//
//  Defines available OpenAI TTS voices with their characteristics.
//  OpenAI offers 6 high-quality voices optimized for different use cases.
//
//  GOVERNANCE:
//  - Voice selection is configuration-driven
//  - No voice logic in SwiftUI views
//  - All voices use the same TTS model
//
//  VERSION: 1.0.0
//

import Foundation

// MARK: - OpenAI Voice

/// Represents an OpenAI TTS voice with its characteristics
struct OpenAIVoice: Codable, Equatable, Identifiable {
    let id: String
    let voiceID: String
    let name: String
    let description: String
    let characteristics: VoiceCharacteristics
    let recommendedFor: [String]

    var previewText: String { VoicePreviewScript.primary }

    struct VoiceCharacteristics: Codable, Equatable {
        let gender: Gender
        let tone: Tone
        let style: Style

        enum Gender: String, Codable {
            case male
            case female
            case neutral
        }

        enum Tone: String, Codable {
            case warm
            case neutral
            case authoritative
            case soft
            case expressive
        }

        enum Style: String, Codable {
            case conversational
            case narrative
            case professional
            case friendly
            case dramatic
        }
    }
}

// MARK: - OpenAI Voice Registry

/// Central registry of OpenAI TTS voices
enum OpenAIVoiceRegistry {

    /// Version for cache invalidation
    static let version = "1.0.0"

    // MARK: - Voice Definitions

    /// Alloy - Balanced and versatile (DEFAULT)
    /// Great all-around voice for most narration needs.
    static let alloy = OpenAIVoice(
        id: "alloy",
        voiceID: "alloy",
        name: "Alloy",
        description: "Balanced and versatile. Great all-around voice for most narration needs.",
        characteristics: OpenAIVoice.VoiceCharacteristics(
            gender: .neutral,
            tone: .neutral,
            style: .narrative
        ),
        recommendedFor: ["General narration", "Balanced delivery", "Default choice"]
    )

    /// Echo - Clear and direct
    /// Professional tone ideal for business and educational content.
    static let echo = OpenAIVoice(
        id: "echo",
        voiceID: "echo",
        name: "Echo",
        description: "Clear and direct. Professional tone ideal for business content.",
        characteristics: OpenAIVoice.VoiceCharacteristics(
            gender: .male,
            tone: .authoritative,
            style: .professional
        ),
        recommendedFor: ["Business content", "Executive summaries", "Professional delivery"]
    )

    /// Fable - Expressive and dynamic
    /// Engaging voice perfect for storytelling and dramatic content.
    static let fable = OpenAIVoice(
        id: "fable",
        voiceID: "fable",
        name: "Fable",
        description: "Expressive and dynamic. Engaging voice perfect for storytelling.",
        characteristics: OpenAIVoice.VoiceCharacteristics(
            gender: .neutral,
            tone: .expressive,
            style: .dramatic
        ),
        recommendedFor: ["Storytelling", "Engaging content", "Narrative books"]
    )

    /// Onyx - Deep and resonant
    /// Authoritative voice suited for serious and impactful content.
    static let onyx = OpenAIVoice(
        id: "onyx",
        voiceID: "onyx",
        name: "Onyx",
        description: "Deep and resonant. Authoritative voice for serious content.",
        characteristics: OpenAIVoice.VoiceCharacteristics(
            gender: .male,
            tone: .authoritative,
            style: .professional
        ),
        recommendedFor: ["Authoritative content", "Leadership books", "Impactful delivery"]
    )

    /// Nova - Warm and friendly
    /// Approachable voice great for self-help and personal development.
    static let nova = OpenAIVoice(
        id: "nova",
        voiceID: "nova",
        name: "Nova",
        description: "Warm and friendly. Approachable voice for self-help content.",
        characteristics: OpenAIVoice.VoiceCharacteristics(
            gender: .female,
            tone: .warm,
            style: .friendly
        ),
        recommendedFor: ["Self-help books", "Personal development", "Warm delivery"]
    )

    /// Shimmer - Soft and soothing
    /// Gentle voice ideal for mindfulness and reflective content.
    static let shimmer = OpenAIVoice(
        id: "shimmer",
        voiceID: "shimmer",
        name: "Shimmer",
        description: "Soft and soothing. Gentle voice for reflective content.",
        characteristics: OpenAIVoice.VoiceCharacteristics(
            gender: .female,
            tone: .soft,
            style: .conversational
        ),
        recommendedFor: ["Mindfulness content", "Reflective material", "Calm delivery"]
    )

    // MARK: - Registry Access

    /// All available voices
    static let allVoices: [OpenAIVoice] = [
        alloy, echo, fable, onyx, nova, shimmer
    ]

    /// Default voice (Alloy)
    static let defaultVoice: OpenAIVoice = alloy

    /// Get voice by ID
    static func voice(byID id: String) -> OpenAIVoice? {
        allVoices.first { $0.id == id }
    }

    /// Get voice by voice ID (same as ID for OpenAI)
    static func voice(byVoiceID voiceID: String) -> OpenAIVoice? {
        allVoices.first { $0.voiceID == voiceID }
    }

    /// Check if a voice ID is valid
    static func isValidVoiceID(_ voiceID: String) -> Bool {
        allVoices.contains { $0.voiceID == voiceID }
    }

    /// Get recommended voice for reader profile
    static func recommendedVoice(for profile: ReaderProfile) -> OpenAIVoice {
        switch profile {
        case .executive:
            return echo // Professional, authoritative
        case .practitioner:
            return nova // Warm, instructional
        case .academic:
            return alloy // Balanced, clear
        case .skeptic:
            return fable // Engaging, dynamic
        }
    }

    /// Get all voices sorted by recommendation for a profile
    static func voicesSorted(for profile: ReaderProfile) -> [OpenAIVoice] {
        let recommended = recommendedVoice(for: profile)
        var sorted = allVoices.filter { $0.id != recommended.id }
        sorted.insert(recommended, at: 0)
        return sorted
    }
}

// MARK: - Voice Picker Copy Extensions

extension VoicePickerCopy {

    /// Editorial descriptor for OpenAI voices
    static func editorialDescriptor(for voice: OpenAIVoice) -> String {
        voice.description
    }

    /// Section header for OpenAI voices based on reader profile
    static func openAIRecommendedSectionHeader(for profile: ReaderProfile) -> String {
        switch profile {
        case .executive:
            return "Recommended: Professional Delivery"
        case .practitioner:
            return "Recommended: Warm and Instructional"
        case .academic:
            return "Recommended: Clear and Balanced"
        case .skeptic:
            return "Recommended: Engaging Narration"
        }
    }
}
