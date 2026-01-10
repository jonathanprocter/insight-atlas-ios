//
//  VoicePickerCopy.swift
//  InsightAtlas
//
//  Editorial Micro-Copy for Voice Selection.
//
//  Provides consistent, editorial-quality copy for voice picker screens.
//  Voice selection should feel like an editorial decision, not a technical setting.
//
//  GOVERNANCE:
//  - All copy defined here, not scattered across views
//  - No marketing language
//  - Tone: calm, editorial, intentional
//  - Preview scripts are canonical and voice-neutral
//
//  VERSION: 1.0.0
//

import Foundation

// MARK: - Voice Picker Copy

/// Central repository for all voice picker micro-copy.
/// Ensures consistency across Settings and per-guide override screens.
enum VoicePickerCopy {

    // MARK: - Screen Titles

    /// Main voice picker screen title
    static let screenTitle = "Narration Voice"

    /// Per-guide override sheet title
    static let perGuideTitle = "Narration Voice for This Guide"

    /// Screen subtitle (muted, below title)
    static let screenSubtitle = "Choose how Insight Atlas sounds when read aloud."

    // MARK: - Section Headers

    /// Header for recommended voices section
    static let recommendedHeader = "Recommended for your reading style"

    /// Header for other voices section (collapsed by default)
    static let otherVoicesHeader = "Other voices"

    // MARK: - Helper Text

    /// Footer helper about playback speed
    static let playbackSpeedHelper = "Playback speed can be adjusted while listening."

    /// Per-guide override helper (required for user trust)
    static let perGuideHelper = "Changing the voice will regenerate audio for this guide only."

    // MARK: - Profile-Specific Section Headers

    /// Section header based on reader profile
    static func recommendedSectionHeader(for profile: ReaderProfile) -> String {
        switch profile {
        case .executive:
            return "Recommended for Executive Reading"
        case .practitioner:
            return "Recommended for Applied Learning"
        case .academic:
            return "Recommended for Long-Form Study"
        case .skeptic:
            return "Recommended for Audio-First Listening"
        }
    }

    // MARK: - Voice Editorial Descriptors

    /// One-line editorial descriptor for each voice.
    /// These describe how the voice feels, not marketing claims.
    static func editorialDescriptor(for voiceID: String) -> String {
        switch voiceID {
        case "adam":
            return "Clear, neutral delivery for focused listening and decision-making."
        case "matthew":
            return "Slightly warmer, still precise and composed."
        case "rachel":
            return "Warm and instructional — ideal for applying ideas in real situations."
        case "sarah":
            return "Reflective and calm, well-suited for thoughtful material."
        case "michael":
            return "Measured pace and precise diction for long-form study."
        case "daniel":
            return "Steady and neutral, suitable for dense analytical content."
        case "josh":
            return "Conversational and engaging without losing clarity."
        case "antoni":
            return "More expressive, best for active listening at higher speeds."
        default:
            return "A voice for narration."
        }
    }
}

// MARK: - Preview Script Copy

/// Canonical preview scripts for voice audition.
/// All voices use the same script — differences come from the voice itself.
enum VoicePreviewScript {

    /// Primary preview script (5-8 seconds)
    /// Used for all voice previews. Neutral, editorial tone.
    static let primary = """
        Insight Atlas helps you understand complex ideas clearly and thoughtfully. \
        We focus on meaning, context, and application — not just summaries.
        """

    /// Extended preview script (only if preview > 5 seconds)
    /// Appended to primary when longer preview is needed.
    static let extended = """
        When ideas are structured well, understanding becomes easier — and action more intentional.
        """

    /// Full preview script combining primary and extended
    static var full: String {
        "\(primary) \(extended)"
    }

    // MARK: - Preview Configuration

    /// Minimum preview duration in seconds
    static let minimumDuration: TimeInterval = 5.0

    /// Maximum preview duration in seconds
    static let maximumDuration: TimeInterval = 8.0

    /// Whether to use extended script (based on voice pacing)
    static func shouldUseExtended(estimatedDuration: TimeInterval) -> Bool {
        estimatedDuration > minimumDuration
    }
}

// MARK: - Voice Selection State Copy

/// Copy for voice selection states and feedback
enum VoiceSelectionCopy {

    /// Label shown when voice is currently selected
    static let selected = "Selected"

    /// Label shown when voice is recommended for profile
    static let recommended = "Recommended"

    /// Label shown during preview playback
    static let playing = "Playing preview..."

    /// Label shown when preview is loading
    static let loading = "Loading..."

    /// Accessibility label for play preview button
    static let playPreviewAccessibility = "Play voice preview"

    /// Accessibility label for stop preview button
    static let stopPreviewAccessibility = "Stop voice preview"

    // MARK: - Error States

    /// Shown when preview fails to load
    static let previewError = "Preview unavailable"

    /// Shown when voice is temporarily unavailable
    static let voiceUnavailable = "Voice temporarily unavailable"
}

// MARK: - Voice Grouping Labels

/// Editorial labels for voice groups.
/// Aligned with editorial intent, not demographics.
enum VoiceGroupLabel {

    /// Get the appropriate group label for a reader profile
    static func forProfile(_ profile: ReaderProfile) -> String {
        switch profile {
        case .executive:
            return "Executive Reading"
        case .practitioner:
            return "Applied Learning"
        case .academic:
            return "Long-Form Study"
        case .skeptic:
            return "Audio-First Listening"
        }
    }

    /// Description of what this group is optimized for
    static func description(for profile: ReaderProfile) -> String {
        switch profile {
        case .executive:
            return "Voices optimized for efficient comprehension and quick decision-making."
        case .practitioner:
            return "Voices that emphasize clarity when learning how to apply concepts."
        case .academic:
            return "Voices suited for extended listening and detailed analysis."
        case .skeptic:
            return "Voices designed for mobile listening and variable playback speeds."
        }
    }
}
