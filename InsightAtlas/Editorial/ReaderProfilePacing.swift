//
//  ReaderProfilePacing.swift
//  InsightAtlas
//
//  Reader Profile Pacing Configuration.
//
//  Defines pacing overrides for different reader profiles.
//  These overrides affect ONLY normalization-time heuristics,
//  never rendering or export logic.
//
//  GOVERNANCE:
//  - Overrides are applied at normalization time
//  - Renderers receive the same block types regardless of profile
//  - Same meaning, different pacing
//  - All changes are versioned and reversible
//
//  VERSION: 1.0.0
//

import Foundation

// MARK: - Reader Profile Pacing Configuration

/// Pacing configuration for a specific reader profile.
/// Overrides only the constants that differ from base values.
struct ReaderProfilePacing: Codable, Equatable {

    // MARK: - Version

    /// Configuration version for tracking changes
    static let version = "1.0.0"

    // MARK: - Base Values (Canonical Reference)

    /// Base pacing values derived from canonical HTML reference
    static let baseValues = ReaderProfilePacing(
        denseProseThreshold: 150,
        maxSentencesPerBlock: 3,
        maxInsightNotesPerSection: 1,
        maxBlocksBeforeDivider: 6,
        preferShortClauses: false,
        minimumFrameworkItems: 3
    )

    // MARK: - Properties

    /// Word count threshold for triggering dense prose splitting
    let denseProseThreshold: Int

    /// Maximum sentences allowed per paragraph block
    let maxSentencesPerBlock: Int

    /// Maximum insight notes allowed per editorial section
    let maxInsightNotesPerSection: Int

    /// Target number of blocks before a section divider is expected
    let maxBlocksBeforeDivider: Int

    /// Whether to prefer shorter clause structures (for audio readability)
    let preferShortClauses: Bool

    /// Minimum items required for framework block (vs demote to list)
    let minimumFrameworkItems: Int

    // MARK: - Initialization

    init(
        denseProseThreshold: Int,
        maxSentencesPerBlock: Int,
        maxInsightNotesPerSection: Int,
        maxBlocksBeforeDivider: Int,
        preferShortClauses: Bool,
        minimumFrameworkItems: Int
    ) {
        self.denseProseThreshold = denseProseThreshold
        self.maxSentencesPerBlock = maxSentencesPerBlock
        self.maxInsightNotesPerSection = maxInsightNotesPerSection
        self.maxBlocksBeforeDivider = maxBlocksBeforeDivider
        self.preferShortClauses = preferShortClauses
        self.minimumFrameworkItems = minimumFrameworkItems
    }
}

// MARK: - Profile Pacing Registry

/// Registry of pacing configurations for each reader profile.
/// Provides access to profile-specific overrides.
enum ReaderProfilePacingRegistry {

    /// Get pacing configuration for a reader profile
    /// - Parameter profile: The reader profile
    /// - Returns: Pacing configuration with profile-specific overrides
    static func pacing(for profile: ReaderProfile) -> ReaderProfilePacing {
        switch profile {
        case .executive:
            return executivePacing
        case .practitioner:
            return practitionerPacing
        case .academic:
            return academicPacing
        case .skeptic:
            return skepticPacing
        }
    }

    // MARK: - Profile Configurations

    /// Executive profile: Concise, high-signal, fast-paced
    /// - Lower prose threshold (split earlier)
    /// - Fewer sentences per block
    /// - Faster cognitive pacing
    private static let executivePacing = ReaderProfilePacing(
        denseProseThreshold: 120,       // Split prose earlier
        maxSentencesPerBlock: 2,        // Shorter blocks
        maxInsightNotesPerSection: 1,   // Same
        maxBlocksBeforeDivider: 5,      // Tighter sections
        preferShortClauses: true,       // Concise language
        minimumFrameworkItems: 3        // Same
    )

    /// Practitioner profile: Balanced, actionable, practical
    /// - Standard prose threshold
    /// - Standard sentence count
    /// - Balanced pacing (DEFAULT)
    private static let practitionerPacing = ReaderProfilePacing(
        denseProseThreshold: 150,       // Standard (base)
        maxSentencesPerBlock: 3,        // Standard (base)
        maxInsightNotesPerSection: 1,   // Standard (base)
        maxBlocksBeforeDivider: 6,      // Standard (base)
        preferShortClauses: false,      // Standard (base)
        minimumFrameworkItems: 3        // Standard (base)
    )

    /// Academic profile: Thorough, nuanced, comprehensive
    /// - Higher prose threshold (allow longer passages)
    /// - More sentences per block
    /// - Slower, more deliberate pacing
    private static let academicPacing = ReaderProfilePacing(
        denseProseThreshold: 220,       // Allow longer prose
        maxSentencesPerBlock: 4,        // Longer blocks acceptable
        maxInsightNotesPerSection: 2,   // Allow more commentary
        maxBlocksBeforeDivider: 8,      // Longer sections
        preferShortClauses: false,      // Natural language
        minimumFrameworkItems: 2        // Include smaller frameworks
    )

    /// Skeptic profile: Evidence-focused, rigorous, questioning
    /// - Standard prose threshold
    /// - Standard blocks with emphasis on structure
    private static let skepticPacing = ReaderProfilePacing(
        denseProseThreshold: 150,       // Standard
        maxSentencesPerBlock: 3,        // Standard
        maxInsightNotesPerSection: 1,   // Limited commentary
        maxBlocksBeforeDivider: 6,      // Standard
        preferShortClauses: false,      // Natural language
        minimumFrameworkItems: 3        // Require full frameworks
    )
}

// MARK: - Audio-First Profile Extension

/// Extended pacing configuration for audio-first consumption.
/// Extends the base ReaderProfile enum with audio-specific behavior.
struct AudioFirstPacing {

    /// Base pacing values optimized for audio narration
    static let pacing = ReaderProfilePacing(
        denseProseThreshold: 100,       // Split very early for natural pauses
        maxSentencesPerBlock: 2,        // Short blocks for breath points
        maxInsightNotesPerSection: 1,   // Limit cognitive load
        maxBlocksBeforeDivider: 5,      // Frequent breaks
        preferShortClauses: true,       // Essential for audio flow
        minimumFrameworkItems: 3        // Standard
    )

    /// Whether to use audio-first pacing (can be profile override)
    static func shouldUseAudioPacing(for profile: ReaderProfile, isAudioMode: Bool) -> ReaderProfilePacing {
        if isAudioMode {
            return pacing
        }
        return ReaderProfilePacingRegistry.pacing(for: profile)
    }
}

// MARK: - Pacing Comparison

extension ReaderProfilePacing {

    /// Compare this pacing to base values and return differences
    func differences(from base: ReaderProfilePacing = ReaderProfilePacing.baseValues) -> [String: String] {
        var diff: [String: String] = [:]

        if denseProseThreshold != base.denseProseThreshold {
            diff["denseProseThreshold"] = "\(base.denseProseThreshold) → \(denseProseThreshold)"
        }
        if maxSentencesPerBlock != base.maxSentencesPerBlock {
            diff["maxSentencesPerBlock"] = "\(base.maxSentencesPerBlock) → \(maxSentencesPerBlock)"
        }
        if maxInsightNotesPerSection != base.maxInsightNotesPerSection {
            diff["maxInsightNotesPerSection"] = "\(base.maxInsightNotesPerSection) → \(maxInsightNotesPerSection)"
        }
        if maxBlocksBeforeDivider != base.maxBlocksBeforeDivider {
            diff["maxBlocksBeforeDivider"] = "\(base.maxBlocksBeforeDivider) → \(maxBlocksBeforeDivider)"
        }
        if preferShortClauses != base.preferShortClauses {
            diff["preferShortClauses"] = "\(base.preferShortClauses) → \(preferShortClauses)"
        }
        if minimumFrameworkItems != base.minimumFrameworkItems {
            diff["minimumFrameworkItems"] = "\(base.minimumFrameworkItems) → \(minimumFrameworkItems)"
        }

        return diff
    }

    /// Debug description showing differences from base
    var debugDescription: String {
        let diffs = differences()
        if diffs.isEmpty {
            return "ReaderProfilePacing: [base values]"
        }
        let changes = diffs.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        return "ReaderProfilePacing: [\(changes)]"
    }
}
