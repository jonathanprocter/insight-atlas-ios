//
//  SummaryTypeGovernor.swift
//  InsightAtlas
//
//  Summary Type Governors v1.0 (2025-06-13)
//
//  This specification governs how much content is allowed, not how content
//  is expressed. It does NOT modify rendering, visual semantics, or audio
//  semantics.
//
//  Reference: InsightAtlas/Documentation/GOVERNANCE_LOCKS.md
//

import Foundation

// MARK: - Summary Type

/// The type of summary being generated, each with distinct budget constraints.
enum SummaryType: String, Codable, CaseIterable, Hashable {
    case quickReference
    case professional
    case accessible
    case deepResearch

    /// Human-readable display name for UI
    var displayName: String {
        switch self {
        case .quickReference:
            return "Quick Reference"
        case .professional:
            return "Professional"
        case .accessible:
            return "Comprehensive"
        case .deepResearch:
            return "Deep Research"
        }
    }
}

// MARK: - Source Type

/// Classification of the source document's primary mode of discourse.
///
/// Detection is run once per source and cached. See `SourceTypeDetector`.
enum GovernorSourceType: String, Codable, CaseIterable, Hashable {
    case argumentative
    case narrative
    case technical
}

// MARK: - Expansion Type

/// Classification of content blocks by their editorial function.
///
/// Used to determine cut order when budget thresholds are exceeded.
/// Detection uses first-match-wins ordering.
enum ExpansionType: String, Codable, CaseIterable, Hashable {
    case exercise
    case adjacentDomainComparison
    case extendedCommentary
    case secondaryExample
    case stylisticElaboration
    case coreArgument  // Never cut

    /// Returns true if this expansion type should never be cut.
    var isProtected: Bool {
        self == .coreArgument
    }
}

// MARK: - Replacement Type

/// Strategy for handling cut content.
enum ReplacementType: String, Codable, CaseIterable, Hashable {
    /// Replace cut content with a synthesis paragraph
    case synthesize
    /// Remove cut content entirely
    case omit
}

// MARK: - Fallback Strategy

/// Strategy when chapter/section detection fails or yields edge cases.
enum FallbackStrategy: String, Codable, CaseIterable, Hashable {
    /// Treat entire document as single section
    case treatAsMonolith
    /// Attempt to infer section boundaries from content
    case inferSections
}

// MARK: - Section Budget

/// Budget allocation for structural sections of the summary.
struct SectionBudget: Codable, Hashable {
    /// Percentage of total budget allocated to introduction
    let introPercent: Float

    /// Percentage of total budget allocated to chapter pool
    let chapterPoolPercent: Float

    /// Percentage of total budget allocated to conclusion
    let conclusionPercent: Float

    /// Minimum word count per chapter
    let minPerChapter: Int

    /// Maximum word count per chapter
    let maxPerChapter: Int

    /// Strategy when chapter detection fails
    let fallbackStrategy: FallbackStrategy

    // MARK: - Validation

    /// Validates that the section budget is internally consistent.
    var isValid: Bool {
        let totalPercent = introPercent + chapterPoolPercent + conclusionPercent
        let percentValid = abs(totalPercent - 1.0) < 0.001
        let chapterRangeValid = minPerChapter > 0 && minPerChapter < maxPerChapter
        return percentValid && chapterRangeValid
    }
}

// MARK: - Cut Policy

/// Policy for cutting content when budget thresholds are exceeded.
struct CutPolicy: Codable, Hashable {
    /// Budget utilization percentage that triggers cut evaluation (e.g., 0.85)
    let triggerThreshold: Float

    /// Hard limit threshold - always 1.0
    let hardLimitThreshold: Float

    /// Order in which expansion types are cut (first in list = cut first)
    let cutOrder: [ExpansionType]

    /// Strategy for replacing cut content
    let replacementStrategy: ReplacementType

    // MARK: - Validation

    /// Validates that the cut policy is internally consistent.
    var isValid: Bool {
        guard triggerThreshold > 0 && triggerThreshold < 1.0 else { return false }
        guard hardLimitThreshold == 1.0 else { return false }
        guard !cutOrder.isEmpty else { return false }
        guard !cutOrder.contains(.coreArgument) else { return false }
        return true
    }
}

// MARK: - Visual Budget

/// Budget constraints for visual elements.
struct VisualBudget: Codable, Hashable {
    /// Maximum number of visuals allowed in the summary
    let maxVisuals: Int

    /// Word count equivalent per visual for budget calculation
    let wordsPerVisualEquivalent: Int

    // MARK: - Validation

    /// Validates that the visual budget is internally consistent.
    var isValid: Bool {
        maxVisuals >= 0 && wordsPerVisualEquivalent > 0
    }
}

// MARK: - Summary Type Governor

/// Complete governor configuration for a summary type.
///
/// ## Important: Generation vs Rendering
///
/// This governor affects **generation** constraints only:
/// - Word count budgets
/// - Section allocation
/// - Cut policies
/// - Visual limits
///
/// It does NOT affect **rendering**:
/// - Font sizes remain constant
/// - Colors remain constant
/// - Spacing rules remain constant
///
/// ## Strict Enforcement
///
/// When `strictEnforcement` is true:
/// - Generation halts on budget violation
/// - Output is discarded
/// - Error is returned
///
/// When `strictEnforcement` is false:
/// - Warning is logged
/// - Validation flag is attached
/// - Output is returned
struct SummaryTypeGovernor: Codable, Hashable, Identifiable {

    // MARK: - Identity

    var id: SummaryType { summaryType }

    /// The summary type this governor applies to
    let summaryType: SummaryType

    // MARK: - Word Count Budget

    /// Base word count before source scaling
    let baseWordCount: Int

    /// Scaling factor applied to source length (e.g., 0.015 = 1.5%)
    let sourceScalingFactor: Float

    /// Minimum source word count before scaling applies
    let minSourceLengthForScaling: Int

    /// Maximum words that can be added via scaling
    let maxScaledAddition: Int

    /// Absolute maximum word count ceiling
    let maxWordCeiling: Int

    /// Maximum audio duration in minutes (at 150 words/minute)
    let maxAudioMinutes: Int

    /// Maximum synthesis paragraphs per section
    let maxSynthesisPerSection: Int

    // MARK: - Budgets and Policies

    /// Section budget allocation
    let sectionBudget: SectionBudget

    /// Cut policy for budget enforcement
    let cutPolicy: CutPolicy

    /// Visual budget constraints
    let visualBudget: VisualBudget

    /// Whether to strictly enforce budget violations
    let strictEnforcement: Bool

    // MARK: - Validation

    /// Validates that the governor is internally consistent.
    var isValid: Bool {
        guard baseWordCount > 0 else { return false }
        guard sourceScalingFactor >= 0 else { return false }
        guard minSourceLengthForScaling >= 0 else { return false }
        guard maxScaledAddition >= 0 else { return false }
        guard maxWordCeiling >= baseWordCount else { return false }
        guard maxAudioMinutes > 0 else { return false }
        guard maxSynthesisPerSection >= 0 else { return false }
        guard sectionBudget.isValid else { return false }
        guard cutPolicy.isValid else { return false }
        guard visualBudget.isValid else { return false }
        return true
    }
}

// MARK: - Governor State

/// Runtime state for tracking governor enforcement during generation.
///
/// This state must be persisted across streaming chunks to ensure
/// deterministic enforcement.
struct GovernorState: Codable {
    /// Current total word count
    var currentWordCount: Int

    /// Current section index (0-based)
    var currentSectionIndex: Int

    /// Word counts per section
    var sectionWordCounts: [Int]

    /// Usage counts per expansion type
    var expansionUsageCounts: [ExpansionType: Int]

    /// Current visual count
    var visualCount: Int

    /// Whether cut policy has been activated
    var cutPolicyActivated: Bool

    /// Synthesis count per section (section index -> count)
    var synthesisCountPerSection: [Int: Int]

    /// Pending consolidation events per section
    var pendingConsolidation: [Int: [CutEvent]]

    // MARK: - Initialization

    /// Creates initial state for a new generation.
    init() {
        self.currentWordCount = 0
        self.currentSectionIndex = 0
        self.sectionWordCounts = []
        self.expansionUsageCounts = [:]
        self.visualCount = 0
        self.cutPolicyActivated = false
        self.synthesisCountPerSection = [:]
        self.pendingConsolidation = [:]
    }

    /// Creates state from existing values (for streaming resumption).
    init(
        currentWordCount: Int,
        currentSectionIndex: Int,
        sectionWordCounts: [Int],
        expansionUsageCounts: [ExpansionType: Int],
        visualCount: Int,
        cutPolicyActivated: Bool,
        synthesisCountPerSection: [Int: Int],
        pendingConsolidation: [Int: [CutEvent]]
    ) {
        self.currentWordCount = currentWordCount
        self.currentSectionIndex = currentSectionIndex
        self.sectionWordCounts = sectionWordCounts
        self.expansionUsageCounts = expansionUsageCounts
        self.visualCount = visualCount
        self.cutPolicyActivated = cutPolicyActivated
        self.synthesisCountPerSection = synthesisCountPerSection
        self.pendingConsolidation = pendingConsolidation
    }
}

// MARK: - Cut Event

/// Record of a content cut during generation.
///
/// Used for observability and debugging.
struct CutEvent: Codable, Hashable {
    /// The type of expansion that was cut
    let expansionType: ExpansionType

    /// Original word count of the cut content
    let originalWordCount: Int

    /// Word count of the replacement (synthesis or 0 for omit)
    let replacementWordCount: Int

    /// Reason for the cut
    let reason: String

    /// Section index where the cut occurred
    let sectionIndex: Int

    /// Chunk index within the section
    let chunkIndex: Int

    /// Budget utilization at time of cut (0.0 to 1.0+)
    let budgetUtilization: Float

    /// Timestamp of the cut (for logging only, not used in logic)
    let timestamp: Date

    /// Whether this cut was consolidated with others
    let wasConsolidated: Bool
}

// MARK: - Section Detection Event

/// Record of section detection for a source document.
///
/// Exactly one event is emitted per source.
struct SectionDetectionEvent: Codable, Hashable {
    /// Strategy used for section detection
    let strategy: FallbackStrategy

    /// Number of sections detected
    let sectionsDetected: Int

    /// Whether fallback was triggered
    let fallbackTriggered: Bool

    /// Reason for fallback (if triggered)
    let reason: String?

    /// Timestamp of detection
    let timestamp: Date
}

// MARK: - Budget Violation

/// Represents a budget violation during generation.
enum BudgetViolation: Codable, Hashable {
    case totalWordCountExceeded(current: Int, limit: Int)
    case sectionWordCountExceeded(section: Int, current: Int, limit: Int)
    case visualCountExceeded(current: Int, limit: Int)
    case audioMinutesExceeded(current: Float, limit: Int)
    case synthesisLimitExceeded(section: Int, current: Int, limit: Int)

    var description: String {
        switch self {
        case .totalWordCountExceeded(let current, let limit):
            return "Total word count exceeded: \(current) > \(limit)"
        case .sectionWordCountExceeded(let section, let current, let limit):
            return "Section \(section) word count exceeded: \(current) > \(limit)"
        case .visualCountExceeded(let current, let limit):
            return "Visual count exceeded: \(current) > \(limit)"
        case .audioMinutesExceeded(let current, let limit):
            return "Audio minutes exceeded: \(String(format: "%.1f", current)) > \(limit)"
        case .synthesisLimitExceeded(let section, let current, let limit):
            return "Section \(section) synthesis limit exceeded: \(current) > \(limit)"
        }
    }
}

// MARK: - Governor Validation Result

/// Result of validating content against a governor.
struct GovernorValidationResult: Codable {
    /// Whether the content passes all governor constraints
    let isValid: Bool

    /// List of violations (empty if valid)
    let violations: [BudgetViolation]

    /// Warnings that don't cause failure
    let warnings: [String]

    /// Current budget utilization (0.0 to 1.0+)
    let budgetUtilization: Float

    /// Effective word budget used for validation
    let effectiveBudget: Int

    /// Cut events that occurred during generation
    let cutEvents: [CutEvent]

    /// Section detection event
    let sectionDetectionEvent: SectionDetectionEvent?
}
