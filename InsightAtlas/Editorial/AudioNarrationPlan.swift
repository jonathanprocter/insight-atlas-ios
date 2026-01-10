//
//  AudioNarrationPlan.swift
//  InsightAtlas
//
//  Audio Narration Planning Service.
//
//  Maps semantic editorial blocks to audio narration behaviors.
//  Audio narration respects block boundaries, intent, and cognitive pacing.
//
//  GOVERNANCE:
//  - Audio consumes semantic blocks, NOT raw prose
//  - No audio logic exists in SwiftUI views
//  - Narration is generated AFTER normalization
//  - Cached audio is reused when text hash + profile match
//
//  VERSION: 1.0.0
//

import Foundation
import CryptoKit

// MARK: - Audio Narration Behavior

/// Defines how a block type should be narrated
enum AudioNarrationBehavior: String, Codable {
    /// Standard narration at normal pace
    case normal

    /// Slower pace with pause before and after
    case emphatic

    /// Segmented narration for grouped elements
    case segmented

    /// Step-paced narration (numbered items)
    case stepPaced

    /// Instructional tone with clear diction
    case instructional

    /// Silent - no narration (dividers, visuals)
    case silent

    /// Quote style - pause, quote, pause
    case quoted
}

// MARK: - Audio Pause Marker

/// Markers for pauses in narration
struct AudioPauseMarker: Codable, Equatable {
    enum PauseType: String, Codable {
        case breath      // 0.3s - natural breathing pause
        case short       // 0.5s - between sentences
        case medium      // 1.0s - between paragraphs
        case long        // 1.5s - between sections
        case dramatic    // 2.0s - before/after quotes
        case chapterEnd  // 3.0s - end of major section
    }

    let type: PauseType
    let position: PausePosition

    enum PausePosition: String, Codable {
        case before
        case after
        case both
    }

    /// Duration in seconds
    var duration: TimeInterval {
        switch type {
        case .breath: return 0.3
        case .short: return 0.5
        case .medium: return 1.0
        case .long: return 1.5
        case .dramatic: return 2.0
        case .chapterEnd: return 3.0
        }
    }
}

// MARK: - Audio Emphasis Marker

/// Markers for emphasis in narration
struct AudioEmphasisMarker: Codable, Equatable {
    enum EmphasisType: String, Codable {
        case slower      // Reduce pace by 15%
        case clearer     // More deliberate articulation
        case louder      // Slight volume increase
        case deeper      // Lower pitch for authority
        case questioning // Rising inflection
    }

    let type: EmphasisType
    let range: Range<Int>? // Character range, nil = entire block

    // Codable conformance for Range
    enum CodingKeys: String, CodingKey {
        case type, rangeStart, rangeEnd
    }

    init(type: EmphasisType, range: Range<Int>? = nil) {
        self.type = type
        self.range = range
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(EmphasisType.self, forKey: .type)
        if let start = try container.decodeIfPresent(Int.self, forKey: .rangeStart),
           let end = try container.decodeIfPresent(Int.self, forKey: .rangeEnd) {
            range = start..<end
        } else {
            range = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        if let range = range {
            try container.encode(range.lowerBound, forKey: .rangeStart)
            try container.encode(range.upperBound, forKey: .rangeEnd)
        }
    }
}

// MARK: - Audio Block Plan

/// Narration plan for a single editorial block
struct AudioBlockPlan: Identifiable, Codable {
    let id: UUID
    let blockId: UUID
    let blockType: EditorialBlockType
    let behavior: AudioNarrationBehavior
    let text: String
    let pauseMarkers: [AudioPauseMarker]
    let emphasisMarkers: [AudioEmphasisMarker]
    let narrationHint: String?

    /// Profile-specific pause duration multiplier (applied at plan generation)
    /// Defaults to 1.0 for backward compatibility
    let pauseMultiplier: Double

    /// Profile-specific pace adjustment (-0.2 to +0.2)
    /// Defaults to 0.0 for backward compatibility
    let paceAdjustment: Double

    init(
        id: UUID = UUID(),
        blockId: UUID,
        blockType: EditorialBlockType,
        behavior: AudioNarrationBehavior,
        text: String,
        pauseMarkers: [AudioPauseMarker],
        emphasisMarkers: [AudioEmphasisMarker],
        narrationHint: String?,
        pauseMultiplier: Double = 1.0,
        paceAdjustment: Double = 0.0
    ) {
        self.id = id
        self.blockId = blockId
        self.blockType = blockType
        self.behavior = behavior
        self.text = text
        self.pauseMarkers = pauseMarkers
        self.emphasisMarkers = emphasisMarkers
        self.narrationHint = narrationHint
        self.pauseMultiplier = pauseMultiplier
        self.paceAdjustment = paceAdjustment
    }

    /// Estimated duration in seconds (rough calculation)
    /// Applies profile-specific pause and pace adjustments
    var estimatedDuration: TimeInterval {
        guard behavior != .silent else { return 0 }

        // Average speaking rate: ~150 words per minute
        let wordCount = Double(text.split(separator: " ").count)
        let baseDuration = (wordCount / 150.0) * 60.0

        // Apply profile pace adjustment (positive = faster, negative = slower)
        // Pace adjustment affects speaking rate: +0.1 means 10% faster
        let paceMultiplier = 1.0 / (1.0 + paceAdjustment)
        let adjustedBaseDuration = baseDuration * paceMultiplier

        // Add pause durations with profile multiplier applied
        let pauseDuration = pauseMarkers.reduce(0.0) { $0 + ($1.duration * pauseMultiplier) }

        // Adjust for behavior
        let behaviorMultiplier: Double
        switch behavior {
        case .emphatic: behaviorMultiplier = 1.2
        case .stepPaced: behaviorMultiplier = 1.15
        case .quoted: behaviorMultiplier = 1.1
        case .instructional: behaviorMultiplier = 1.1
        default: behaviorMultiplier = 1.0
        }

        return (adjustedBaseDuration * behaviorMultiplier) + pauseDuration
    }

    /// Content hash for caching
    var contentHash: String {
        let data = Data((text + blockType.rawValue + behavior.rawValue).utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Audio Narration Plan

/// Complete narration plan for an editorial document
struct AudioNarrationPlan: Identifiable, Codable {
    let id: UUID
    let documentId: UUID
    let documentTitle: String
    let profile: ReaderProfile
    let blocks: [AudioBlockPlan]
    let generatedAt: Date
    let version: String

    /// Total estimated duration in seconds
    var totalDuration: TimeInterval {
        blocks.reduce(0) { $0 + $1.estimatedDuration }
    }

    /// Total estimated duration formatted as string
    var formattedDuration: String {
        let minutes = Int(totalDuration) / 60
        let seconds = Int(totalDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Content hash for the entire plan (for cache validation)
    var planHash: String {
        let combined = blocks.map { $0.contentHash }.joined() + profile.rawValue
        let data = Data(combined.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    init(
        id: UUID = UUID(),
        documentId: UUID,
        documentTitle: String,
        profile: ReaderProfile,
        blocks: [AudioBlockPlan],
        generatedAt: Date = Date(),
        version: String = "audio-v1.0"
    ) {
        self.id = id
        self.documentId = documentId
        self.documentTitle = documentTitle
        self.profile = profile
        self.blocks = blocks
        self.generatedAt = generatedAt
        self.version = version
    }
}

// MARK: - Audio Narration Service

/// Service that generates narration plans from editorial documents.
/// Consumes semantic blocks after normalization.
final class AudioNarrationService {

    // MARK: - Audio Profile Configuration

    /// Profile-specific audio pacing adjustments
    struct AudioProfileConfig {
        let pauseMultiplier: Double      // Multiplier for pause durations
        let paceAdjustment: Double       // Speaking rate adjustment (-0.2 to +0.2)
        let emphasisLevel: Double        // How much to emphasize (0.5 to 1.5)

        static let standard = AudioProfileConfig(
            pauseMultiplier: 1.0,
            paceAdjustment: 0.0,
            emphasisLevel: 1.0
        )

        static let executive = AudioProfileConfig(
            pauseMultiplier: 0.8,         // Shorter pauses
            paceAdjustment: 0.1,          // Slightly faster
            emphasisLevel: 0.9            // Less dramatic emphasis
        )

        static let academic = AudioProfileConfig(
            pauseMultiplier: 1.3,         // Longer pauses
            paceAdjustment: -0.1,         // Slightly slower
            emphasisLevel: 1.2            // More emphasis
        )

        static let audioFirst = AudioProfileConfig(
            pauseMultiplier: 0.9,         // Slightly shorter pauses
            paceAdjustment: 0.05,         // Slightly faster
            emphasisLevel: 1.1            // Clear emphasis
        )
    }

    // MARK: - Block Type to Behavior Mapping

    /// Canonical mapping of block types to audio behaviors
    /// STRICT: These rules define how each block type should be narrated
    private static let behaviorMapping: [EditorialBlockType: AudioNarrationBehavior] = [
        // Narrative blocks - normal narration
        .foundationalNarrative: .normal,
        .paragraph: .normal,
        .authorSpotlight: .normal,

        // Insight blocks - emphatic narration (slower, pauses)
        .insightNote: .emphatic,
        .researchInsight: .emphatic,
        .alternativePerspective: .emphatic,

        // Framework blocks - segmented narration
        .framework: .segmented,
        .conceptMap: .segmented,

        // Process blocks - step-paced narration
        .processFlow: .stepPaced,
        .decisionTree: .stepPaced,

        // Quote blocks - quoted style (pause → quote → pause)
        .premiumQuote: .quoted,
        .blockquote: .quoted,

        // Action blocks - instructional tone
        .applyIt: .instructional,
        .actionBox: .instructional,
        .exercise: .instructional,

        // List blocks - segmented
        .bulletList: .segmented,
        .numberedList: .stepPaced,
        .keyTakeaways: .stepPaced,

        // Summary blocks - normal with emphasis
        .quickGlance: .emphatic,

        // Structural blocks - silent
        .sectionDivider: .silent,
        .partHeader: .emphatic,
        .sectionHeader: .emphatic,
        .subsectionHeader: .normal,
        .minorHeader: .normal,
        .stageHeader: .normal,

        // Visual/table blocks - silent or minimal
        .visual: .silent,
        .table: .silent,
        .comparisonBeforeAfter: .segmented
    ]

    // MARK: - Public Methods

    /// Generate an audio narration plan from an editorial document
    ///
    /// - Parameters:
    ///   - document: Normalized editorial document
    ///   - profile: Reader profile for pacing adjustments
    /// - Returns: Complete narration plan
    func generatePlan(
        for document: EditorialDocument,
        profile: ReaderProfile
    ) -> AudioNarrationPlan {
        let blockPlans = document.blocks.compactMap { block in
            generateBlockPlan(for: block, profile: profile)
        }

        return AudioNarrationPlan(
            documentId: document.id,
            documentTitle: document.title,
            profile: profile,
            blocks: blockPlans
        )
    }

    /// Generate narration plan for a single block
    ///
    /// Applies profile-specific pacing multipliers from `AudioProfileConfig`
    /// to the generated block plan.
    private func generateBlockPlan(
        for block: EditorialBlock,
        profile: ReaderProfile
    ) -> AudioBlockPlan {
        let behavior = Self.behaviorMapping[block.type] ?? .normal
        let text = extractNarratableText(from: block)
        let pauseMarkers = generatePauseMarkers(for: block, behavior: behavior, profile: profile)
        let emphasisMarkers = generateEmphasisMarkers(for: block, behavior: behavior)
        let hint = generateNarrationHint(for: block)

        // Get profile-specific pacing configuration
        let config = audioConfig(for: profile)

        return AudioBlockPlan(
            id: UUID(),
            blockId: block.id,
            blockType: block.type,
            behavior: behavior,
            text: text,
            pauseMarkers: pauseMarkers,
            emphasisMarkers: emphasisMarkers,
            narrationHint: hint,
            pauseMultiplier: config.pauseMultiplier,
            paceAdjustment: config.paceAdjustment
        )
    }

    // MARK: - Private Methods

    /// Extract narratable text from a block
    private func extractNarratableText(from block: EditorialBlock) -> String {
        var parts: [String] = []

        // Add title if present (for certain block types)
        if let title = block.title, shouldNarrateTitle(for: block.type) {
            parts.append(title)
        }

        // Add body text
        if !block.body.isEmpty {
            parts.append(block.body)
        }

        // Add list items for list-based blocks
        if let items = block.listItems {
            for (index, item) in items.enumerated() {
                if block.type == .numberedList || block.type == .keyTakeaways || block.type == .processFlow {
                    parts.append("\(index + 1). \(item)")
                } else {
                    parts.append(item)
                }
            }
        }

        // Add steps for process flows
        if let steps = block.steps {
            for step in steps {
                parts.append("Step \(step.number): \(step.instruction)")
                if let outcome = step.outcome {
                    parts.append(outcome)
                }
            }
        }

        return parts.joined(separator: " ")
    }

    /// Determine if title should be narrated for a block type
    private func shouldNarrateTitle(for type: EditorialBlockType) -> Bool {
        switch type {
        case .framework, .processFlow, .decisionTree, .actionBox, .exercise,
             .partHeader, .sectionHeader, .subsectionHeader:
            return true
        default:
            return false
        }
    }

    /// Generate pause markers based on block type and behavior
    ///
    /// Note: Profile-specific pause multipliers are now applied in `AudioBlockPlan.estimatedDuration`
    /// rather than at marker generation time, preserving canonical pause types.
    private func generatePauseMarkers(
        for block: EditorialBlock,
        behavior: AudioNarrationBehavior,
        profile: ReaderProfile
    ) -> [AudioPauseMarker] {
        var markers: [AudioPauseMarker] = []
        // Profile pacing is now applied via pauseMultiplier in AudioBlockPlan

        switch behavior {
        case .emphatic:
            // Pause before and after emphatic content
            markers.append(AudioPauseMarker(type: .medium, position: .before))
            markers.append(AudioPauseMarker(type: .medium, position: .after))

        case .quoted:
            // Dramatic pause before and after quotes
            markers.append(AudioPauseMarker(type: .dramatic, position: .before))
            markers.append(AudioPauseMarker(type: .dramatic, position: .after))

        case .segmented:
            // Short pauses between segments
            markers.append(AudioPauseMarker(type: .short, position: .before))
            markers.append(AudioPauseMarker(type: .medium, position: .after))

        case .stepPaced:
            // Medium pauses to separate steps
            markers.append(AudioPauseMarker(type: .short, position: .before))
            markers.append(AudioPauseMarker(type: .long, position: .after))

        case .instructional:
            // Clear pauses for instructions
            markers.append(AudioPauseMarker(type: .short, position: .before))
            markers.append(AudioPauseMarker(type: .medium, position: .after))

        case .normal:
            // Standard paragraph pauses
            markers.append(AudioPauseMarker(type: .short, position: .after))

        case .silent:
            // No markers for silent blocks
            break
        }

        // Add section-level pauses for headers
        if block.type == .partHeader {
            markers.append(AudioPauseMarker(type: .chapterEnd, position: .before))
        } else if block.type == .sectionHeader {
            markers.append(AudioPauseMarker(type: .long, position: .before))
        }

        return markers
    }

    /// Generate emphasis markers for a block
    private func generateEmphasisMarkers(
        for block: EditorialBlock,
        behavior: AudioNarrationBehavior
    ) -> [AudioEmphasisMarker] {
        var markers: [AudioEmphasisMarker] = []

        switch behavior {
        case .emphatic:
            markers.append(AudioEmphasisMarker(type: .slower))

        case .quoted:
            markers.append(AudioEmphasisMarker(type: .deeper))

        case .instructional:
            markers.append(AudioEmphasisMarker(type: .clearer))

        case .stepPaced:
            markers.append(AudioEmphasisMarker(type: .clearer))

        default:
            break
        }

        // Add emphasis for headers
        if block.type == .partHeader || block.type == .sectionHeader {
            markers.append(AudioEmphasisMarker(type: .louder))
        }

        return markers
    }

    /// Generate a narration hint for special handling
    private func generateNarrationHint(for block: EditorialBlock) -> String? {
        switch block.type {
        case .premiumQuote:
            if let attribution = block.attribution?.author {
                return "Quote by \(attribution)"
            }
            return "Direct quote"

        case .researchInsight:
            return "Research finding - cite source"

        case .exercise:
            return "Interactive exercise - pause for reflection"

        case .decisionTree:
            return "Decision point - enumerate options clearly"

        case .framework:
            return "Conceptual framework - group related items"

        default:
            return nil
        }
    }

    /// Get audio configuration for a profile
    private func audioConfig(for profile: ReaderProfile) -> AudioProfileConfig {
        switch profile {
        case .executive:
            return .executive
        case .academic:
            return .academic
        case .practitioner:
            return .standard
        case .skeptic:
            return .standard
        }
    }
}

// MARK: - Audio Cache Key

/// Cache key for audio narration segments
struct AudioCacheKey: Hashable, Codable {
    let textHash: String
    let profile: ReaderProfile
    let behavior: AudioNarrationBehavior

    init(blockPlan: AudioBlockPlan, profile: ReaderProfile) {
        self.textHash = blockPlan.contentHash
        self.profile = profile
        self.behavior = blockPlan.behavior
    }
}
