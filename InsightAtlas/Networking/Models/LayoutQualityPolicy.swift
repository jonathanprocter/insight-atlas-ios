//
//  LayoutQualityPolicy.swift
//  InsightAtlas
//
//  Automatic regeneration thresholds and quality acceptance policy.
//
//  This policy layer decides when content should be regenerated based on
//  layout scores. It does NOT modify rendering logic - it only governs
//  the decision to accept or retry generation.
//
//  Reference: InsightAtlas/Documentation/FormattingInvariants.md
//

import Foundation

// MARK: - Quality Thresholds

/// Defines score thresholds for layout quality acceptance.
///
/// ## Threshold Levels
///
/// - `minimumAcceptable`: Below this triggers automatic regeneration
/// - `target`: Between minimum and target returns content with warnings
/// - `ideal`: At or above this is considered excellent quality
///
/// ## Policy Behavior
///
/// | Score Range           | Action                                    |
/// |-----------------------|-------------------------------------------|
/// | < minimumAcceptable   | Auto-regenerate (up to maxAttempts)       |
/// | ≥ minimum, < target   | Accept with warnings                      |
/// | ≥ target, < ideal     | Accept (good quality)                     |
/// | ≥ ideal               | Accept (excellent quality)                |
struct LayoutQualityThresholds: Codable {
    /// Below this score triggers automatic regeneration
    let minimumAcceptable: Double

    /// Target quality level - warnings issued below this
    let target: Double

    /// Ideal quality level - no improvements needed
    let ideal: Double

    /// Maximum regeneration attempts before accepting best result
    let maxRegenerationAttempts: Int

    // MARK: - Presets

    /// Default production thresholds
    static let `default` = LayoutQualityThresholds(
        minimumAcceptable: 0.85,
        target: 0.90,
        ideal: 0.95,
        maxRegenerationAttempts: 3
    )

    /// Stricter thresholds for premium content
    static let premium = LayoutQualityThresholds(
        minimumAcceptable: 0.90,
        target: 0.93,
        ideal: 0.97,
        maxRegenerationAttempts: 5
    )

    /// Relaxed thresholds for draft/preview content
    static let draft = LayoutQualityThresholds(
        minimumAcceptable: 0.70,
        target: 0.80,
        ideal: 0.90,
        maxRegenerationAttempts: 1
    )

    // MARK: - Validation

    /// Validates that thresholds are logically consistent
    var isValid: Bool {
        minimumAcceptable > 0 &&
        minimumAcceptable < target &&
        target < ideal &&
        ideal <= 1.0 &&
        maxRegenerationAttempts >= 0
    }
}

// MARK: - Quality Decision

/// The result of evaluating content against quality thresholds.
enum LayoutQualityDecision: Codable {
    /// Content meets ideal quality - no action needed
    case excellent(score: Double)

    /// Content meets target quality - acceptable
    case good(score: Double)

    /// Content meets minimum but has warnings
    case acceptableWithWarnings(score: Double, warnings: [String])

    /// Content below minimum - should regenerate
    case requiresRegeneration(score: Double, issues: [LayoutIssue])

    /// Regeneration limit reached - accept best available
    case acceptedAfterRetries(score: Double, attempts: Int, bestScore: Double)
}

// MARK: - Regeneration Policy

/// Policy engine for automatic content regeneration based on layout quality.
///
/// This policy does NOT modify content or rendering. It only:
/// 1. Evaluates layout scores against thresholds
/// 2. Decides whether to accept, warn, or regenerate
/// 3. Tracks regeneration attempts
/// 4. Provides constraint tightening suggestions
struct LayoutRegenerationPolicy: Codable {

    // MARK: - Properties

    /// Quality thresholds for this policy
    let thresholds: LayoutQualityThresholds

    /// Format to evaluate (pdf, docx, html, or overall)
    let targetFormat: TargetFormat

    /// Whether to use issue-based constraint tightening
    let useAdaptiveConstraints: Bool

    // MARK: - Types

    enum TargetFormat: String, Codable {
        case pdf
        case docx
        case html
        case overall
    }

    // MARK: - Initialization

    init(
        thresholds: LayoutQualityThresholds = .default,
        targetFormat: TargetFormat = .overall,
        useAdaptiveConstraints: Bool = true
    ) {
        self.thresholds = thresholds
        self.targetFormat = targetFormat
        self.useAdaptiveConstraints = useAdaptiveConstraints
    }

    // MARK: - Evaluation

    /// Evaluates a layout score and returns the quality decision.
    func evaluate(_ layoutScore: LayoutScore) -> LayoutQualityDecision {
        let score = scoreForFormat(layoutScore)

        if score >= thresholds.ideal {
            return .excellent(score: score)
        } else if score >= thresholds.target {
            return .good(score: score)
        } else if score >= thresholds.minimumAcceptable {
            let warnings = generateWarnings(from: layoutScore.issues)
            return .acceptableWithWarnings(score: score, warnings: warnings)
        } else {
            return .requiresRegeneration(score: score, issues: layoutScore.issues)
        }
    }

    /// Determines if regeneration should occur based on current attempt count.
    func shouldRegenerate(
        layoutScore: LayoutScore,
        attemptNumber: Int,
        bestScoreSoFar: Double
    ) -> RegenerationDecision {
        let score = scoreForFormat(layoutScore)

        // Already meets threshold
        if score >= thresholds.minimumAcceptable {
            return .accept(reason: "Score \(String(format: "%.2f", score)) meets minimum threshold")
        }

        // Max attempts reached
        if attemptNumber >= thresholds.maxRegenerationAttempts {
            return .acceptBest(
                reason: "Max attempts (\(thresholds.maxRegenerationAttempts)) reached",
                bestScore: max(score, bestScoreSoFar)
            )
        }

        // Generate tightened constraints for retry
        let constraints = useAdaptiveConstraints
            ? generateTightenedConstraints(from: layoutScore.issues)
            : []

        return .regenerate(
            attemptNumber: attemptNumber + 1,
            tightenedConstraints: constraints
        )
    }

    // MARK: - Private Helpers

    private func scoreForFormat(_ layoutScore: LayoutScore) -> Double {
        switch targetFormat {
        case .pdf: return layoutScore.pdf
        case .docx: return layoutScore.docx
        case .html: return layoutScore.html
        case .overall: return layoutScore.overall
        }
    }

    private func generateWarnings(from issues: [LayoutIssue]) -> [String] {
        issues
            .filter { $0.severity == "warning" || $0.severity == "info" }
            .map { "\($0.type): \($0.suggestion)" }
    }

    /// Generates constraint adjustments based on detected issues.
    ///
    /// This does NOT modify rendering. It returns metadata that can be
    /// passed to the generation backend to produce better content.
    private func generateTightenedConstraints(from issues: [LayoutIssue]) -> [RegenerationConstraint] {
        var constraints: [RegenerationConstraint] = []

        for issue in issues {
            switch issue.type {
            case "visual_density":
                constraints.append(.reduceVisualDensity)
            case "paragraph_length":
                constraints.append(.shortenParagraphs)
            case "orphaned_header":
                constraints.append(.ensureHeaderContentProximity)
            case "page_break":
                constraints.append(.improvePageBreakPlacement)
            case "spacing":
                constraints.append(.adjustSpacing)
            case "consecutive_visuals":
                constraints.append(.addTextBetweenVisuals)
            default:
                break
            }
        }

        return Array(Set(constraints))
    }
}

// MARK: - Regeneration Decision

/// The decision returned by the regeneration policy.
enum RegenerationDecision: Codable {
    /// Accept the current content
    case accept(reason: String)

    /// Accept the best content seen so far (max retries reached)
    case acceptBest(reason: String, bestScore: Double)

    /// Regenerate with tightened constraints
    case regenerate(attemptNumber: Int, tightenedConstraints: [RegenerationConstraint])
}

// MARK: - Regeneration Constraints

/// Constraints that can be applied to tighten content generation.
///
/// These are passed to the backend generation service as hints.
/// They do NOT modify rendering logic.
enum RegenerationConstraint: String, Codable, Hashable {
    /// Reduce the number of visuals per section
    case reduceVisualDensity

    /// Shorten paragraph lengths
    case shortenParagraphs

    /// Ensure headers have immediate content
    case ensureHeaderContentProximity

    /// Improve page break placement
    case improvePageBreakPlacement

    /// Adjust spacing between elements
    case adjustSpacing

    /// Add explanatory text between consecutive visuals
    case addTextBetweenVisuals

    /// Prefer simpler visual types
    case preferSimplerVisuals

    /// Reduce section depth
    case reduceSectionDepth
}

// MARK: - Regeneration Tracker

/// Tracks regeneration attempts and scores for a single generation session.
struct RegenerationTracker: Codable {
    /// All attempts made during this session
    private(set) var attempts: [RegenerationAttempt] = []

    /// The policy being used
    let policy: LayoutRegenerationPolicy

    // MARK: - Types

    struct RegenerationAttempt: Codable {
        let attemptNumber: Int
        let score: Double
        let decision: RegenerationDecision
        let constraintsApplied: [RegenerationConstraint]
        let timestamp: Date
    }

    // MARK: - Initialization

    init(policy: LayoutRegenerationPolicy = LayoutRegenerationPolicy()) {
        self.policy = policy
    }

    // MARK: - Tracking

    /// Records an attempt and returns the next decision.
    mutating func recordAttempt(
        layoutScore: LayoutScore,
        constraintsApplied: [RegenerationConstraint]
    ) -> RegenerationDecision {
        let attemptNumber = attempts.count + 1
        let bestSoFar = attempts.map { $0.score }.max() ?? 0

        let decision = policy.shouldRegenerate(
            layoutScore: layoutScore,
            attemptNumber: attemptNumber,
            bestScoreSoFar: bestSoFar
        )

        let attempt = RegenerationAttempt(
            attemptNumber: attemptNumber,
            score: policy.targetFormat == .overall ? layoutScore.overall : layoutScore.pdf,
            decision: decision,
            constraintsApplied: constraintsApplied,
            timestamp: Date()
        )

        attempts.append(attempt)

        return decision
    }

    /// Returns the best score achieved across all attempts.
    var bestScore: Double {
        attempts.map { $0.score }.max() ?? 0
    }

    /// Returns the number of attempts made.
    var attemptCount: Int {
        attempts.count
    }

    /// Returns true if regeneration limit has been reached.
    var isExhausted: Bool {
        attempts.count >= policy.thresholds.maxRegenerationAttempts
    }
}
