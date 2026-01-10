//
//  VisualDensityScoring.swift
//  InsightAtlas
//
//  Visual density scoring component for layout quality evaluation.
//
//  This component evaluates visual placement quality WITHOUT modifying
//  any rendering logic. It only analyzes document structure and returns
//  scores and issues for integration with LayoutScore.
//
//  Reference: InsightAtlas/Documentation/FormattingInvariants.md
//

import Foundation

// MARK: - Visual Density Analyzer

/// Analyzes visual density and placement quality in a document.
///
/// ## Purpose
///
/// This analyzer evaluates how well visuals are integrated with text content.
/// It does NOT modify rendering - it only measures quality.
///
/// ## Scoring Components
///
/// The analyzer produces scores for:
/// - Visual-to-text ratio
/// - Visual placement (after explanatory text)
/// - Visual clustering (consecutive visuals without text)
/// - Visual sizing appropriateness
///
/// ## Integration with LayoutScore
///
/// Results from this analyzer are integrated into:
/// - `layoutScore.issues` - Specific visual density issues
/// - `layoutScore.overall` - Contributes to overall score calculation
struct VisualDensityAnalyzer {

    // MARK: - Configuration

    /// Configuration for visual density analysis
    let config: VisualDensityConfig

    // MARK: - Initialization

    init(config: VisualDensityConfig = .default) {
        self.config = config
    }

    // MARK: - Analysis

    /// Analyzes visual density in a document and returns a detailed result.
    func analyze(sections: [AnalyzableSection]) -> VisualDensityResult {
        var issues: [LayoutIssue] = []
        var metrics = VisualDensityMetrics()

        // Track consecutive visual patterns
        var previousBlockWasVisual = false
        var consecutiveVisualCount = 0
        var wordsSinceLastVisual = 0

        for (sectionIndex, section) in sections.enumerated() {
            let sectionId = "section-\(sectionIndex + 1)"

            // Count visuals in section
            let visualCount = section.visualCount
            metrics.totalVisuals += visualCount

            // Check for too many visuals in section
            if visualCount > config.maxVisualsPerSection {
                issues.append(LayoutIssue(
                    type: "visual_density",
                    section: sectionId,
                    severity: "warning",
                    suggestion: "Section has \(visualCount) visuals. Consider reducing to \(config.maxVisualsPerSection) or fewer for better readability."
                ))
            }

            // Analyze blocks within section
            for block in section.blocks {
                if block.isVisual {
                    metrics.totalVisuals += 1

                    // Check for consecutive visuals
                    if previousBlockWasVisual {
                        consecutiveVisualCount += 1
                        if consecutiveVisualCount >= config.maxConsecutiveVisuals {
                            issues.append(LayoutIssue(
                                type: "consecutive_visuals",
                                section: sectionId,
                                severity: "warning",
                                suggestion: "Found \(consecutiveVisualCount + 1) consecutive visuals. Add explanatory text between visuals."
                            ))
                        }
                    } else {
                        consecutiveVisualCount = 1
                    }

                    // Check for insufficient text before visual
                    if wordsSinceLastVisual < config.minTextBeforeVisual && metrics.totalVisuals > 1 {
                        issues.append(LayoutIssue(
                            type: "visual_density",
                            section: sectionId,
                            severity: "info",
                            suggestion: "Only \(wordsSinceLastVisual) words before this visual. Consider adding more context."
                        ))
                    }

                    // Check visual size (for PDF)
                    if let sizeCategory = block.visualSizeCategory {
                        if sizeCategory == .oversized {
                            issues.append(LayoutIssue(
                                type: "visual_size",
                                section: sectionId,
                                severity: "warning",
                                suggestion: "Visual may be too large for PDF export. Consider a more compact representation."
                            ))
                            metrics.oversizedVisuals += 1
                        }
                    }

                    // Reward: Visual placed after explanatory text
                    if wordsSinceLastVisual >= config.idealTextBeforeVisual {
                        metrics.wellPlacedVisuals += 1
                    }

                    previousBlockWasVisual = true
                    wordsSinceLastVisual = 0
                } else {
                    // Text block
                    wordsSinceLastVisual += block.wordCount
                    metrics.totalWords += block.wordCount
                    previousBlockWasVisual = false
                    consecutiveVisualCount = 0
                }
            }
        }

        // Calculate visual-to-text ratio
        if metrics.totalWords > 0 {
            metrics.visualsPerThousandWords = Double(metrics.totalVisuals) / (Double(metrics.totalWords) / 1000.0)
        }

        // Check overall visual density
        if metrics.visualsPerThousandWords > config.maxVisualsPerThousandWords {
            issues.append(LayoutIssue(
                type: "visual_density",
                section: "document",
                severity: "warning",
                suggestion: "Document has \(String(format: "%.1f", metrics.visualsPerThousandWords)) visuals per 1000 words. Consider reducing visual count for better balance."
            ))
        } else if metrics.visualsPerThousandWords < config.minVisualsPerThousandWords && metrics.totalVisuals > 0 {
            issues.append(LayoutIssue(
                type: "visual_density",
                section: "document",
                severity: "info",
                suggestion: "Document has few visuals relative to text. Consider adding more visual explanations."
            ))
        }

        // Calculate score
        let score = calculateScore(metrics: metrics, issueCount: issues.count)

        return VisualDensityResult(
            score: score,
            metrics: metrics,
            issues: issues
        )
    }

    // MARK: - Score Calculation

    /// Calculates the visual density score (0.0-1.0).
    private func calculateScore(metrics: VisualDensityMetrics, issueCount: Int) -> Double {
        var score = 1.0

        // Penalty for issues (capped)
        let issuePenalty = min(Double(issueCount) * 0.05, 0.3)
        score -= issuePenalty

        // Penalty for oversized visuals
        if metrics.totalVisuals > 0 {
            let oversizedRatio = Double(metrics.oversizedVisuals) / Double(metrics.totalVisuals)
            score -= oversizedRatio * 0.2
        }

        // Reward for well-placed visuals
        if metrics.totalVisuals > 0 {
            let wellPlacedRatio = Double(metrics.wellPlacedVisuals) / Double(metrics.totalVisuals)
            score += wellPlacedRatio * 0.1
        }

        // Penalty for extreme visual density
        if metrics.visualsPerThousandWords > config.maxVisualsPerThousandWords {
            let excess = metrics.visualsPerThousandWords - config.maxVisualsPerThousandWords
            score -= min(excess * 0.1, 0.2)
        }

        // Ensure score is in valid range
        return max(0.0, min(1.0, score))
    }
}

// MARK: - Configuration

/// Configuration for visual density analysis.
struct VisualDensityConfig: Codable {
    /// Maximum visuals allowed per section before warning
    let maxVisualsPerSection: Int

    /// Maximum consecutive visuals without text
    let maxConsecutiveVisuals: Int

    /// Minimum words expected before a visual
    let minTextBeforeVisual: Int

    /// Ideal words before a visual (for reward)
    let idealTextBeforeVisual: Int

    /// Maximum visuals per 1000 words
    let maxVisualsPerThousandWords: Double

    /// Minimum visuals per 1000 words (for info message)
    let minVisualsPerThousandWords: Double

    /// Maximum visual width as percentage of page width for PDF
    let maxVisualWidthPercent: Double

    // MARK: - Presets

    static let `default` = VisualDensityConfig(
        maxVisualsPerSection: 3,
        maxConsecutiveVisuals: 2,
        minTextBeforeVisual: 30,
        idealTextBeforeVisual: 80,
        maxVisualsPerThousandWords: 3.0,
        minVisualsPerThousandWords: 0.5,
        maxVisualWidthPercent: 0.9
    )

    static let executive = VisualDensityConfig(
        maxVisualsPerSection: 1,
        maxConsecutiveVisuals: 1,
        minTextBeforeVisual: 50,
        idealTextBeforeVisual: 100,
        maxVisualsPerThousandWords: 2.0,
        minVisualsPerThousandWords: 0.3,
        maxVisualWidthPercent: 0.8
    )

    static let academic = VisualDensityConfig(
        maxVisualsPerSection: 2,
        maxConsecutiveVisuals: 2,
        minTextBeforeVisual: 50,
        idealTextBeforeVisual: 120,
        maxVisualsPerThousandWords: 2.0,
        minVisualsPerThousandWords: 0.2,
        maxVisualWidthPercent: 0.85
    )

    static let practitioner = VisualDensityConfig(
        maxVisualsPerSection: 3,
        maxConsecutiveVisuals: 2,
        minTextBeforeVisual: 30,
        idealTextBeforeVisual: 80,
        maxVisualsPerThousandWords: 4.0,
        minVisualsPerThousandWords: 1.0,
        maxVisualWidthPercent: 0.9
    )

    /// Returns configuration for a reader profile
    static func config(for profile: ReaderProfile) -> VisualDensityConfig {
        switch profile {
        case .executive: return .executive
        case .academic: return .academic
        case .practitioner: return .practitioner
        case .skeptic: return .default
        }
    }
}

// MARK: - Result Types

/// Result of visual density analysis.
struct VisualDensityResult: Codable {
    /// Overall visual density score (0.0-1.0)
    let score: Double

    /// Detailed metrics
    let metrics: VisualDensityMetrics

    /// Issues detected
    let issues: [LayoutIssue]

    /// Whether the result is acceptable (score >= 0.7)
    var isAcceptable: Bool {
        score >= 0.7
    }

    /// Summary description
    var summary: String {
        if score >= 0.9 {
            return "Excellent visual integration"
        } else if score >= 0.8 {
            return "Good visual balance"
        } else if score >= 0.7 {
            return "Acceptable visual density"
        } else {
            return "Visual density needs improvement"
        }
    }
}

/// Metrics collected during visual density analysis.
struct VisualDensityMetrics: Codable {
    /// Total visuals in document
    var totalVisuals: Int = 0

    /// Total words in document
    var totalWords: Int = 0

    /// Visuals per 1000 words
    var visualsPerThousandWords: Double = 0

    /// Visuals that are well-placed (after sufficient text)
    var wellPlacedVisuals: Int = 0

    /// Visuals that are oversized for PDF
    var oversizedVisuals: Int = 0
}

// MARK: - Analyzable Types

/// Protocol for sections that can be analyzed for visual density.
protocol AnalyzableSection {
    var blocks: [AnalyzableBlock] { get }
    var visualCount: Int { get }
}

/// Protocol for blocks that can be analyzed.
protocol AnalyzableBlock {
    var isVisual: Bool { get }
    var wordCount: Int { get }
    var visualSizeCategory: VisualSizeCategory? { get }
}

/// Size category for visuals.
enum VisualSizeCategory: String, Codable {
    case small      // < 30% page width
    case medium     // 30-60% page width
    case large      // 60-90% page width
    case oversized  // > 90% page width
}

// MARK: - Integration with LayoutScore

extension VisualDensityAnalyzer {

    /// Creates layout issues from visual density analysis for integration with LayoutScore.
    ///
    /// This method returns issues that should be added to `LayoutScore.issues`.
    func generateLayoutIssues(sections: [AnalyzableSection]) -> [LayoutIssue] {
        let result = analyze(sections: sections)
        return result.issues
    }

    /// Calculates visual density contribution to overall layout score.
    ///
    /// This value should be weighted and combined with other score components.
    /// Suggested weight: 15-20% of overall score.
    func calculateScoreContribution(sections: [AnalyzableSection]) -> Double {
        let result = analyze(sections: sections)
        return result.score
    }
}

// MARK: - Adapter for PDFAnalysisDocument

/// Adapter to make PDFAnalysisDocument.PDFSection analyzable.
struct AnalyzablePDFSection: AnalyzableSection {
    let section: PDFAnalysisDocument.PDFSection

    var blocks: [AnalyzableBlock] {
        section.blocks.map { AnalyzablePDFBlock(block: $0) }
    }

    var visualCount: Int {
        section.blocks.filter { $0.type == .visual || $0.type == .flowchart }.count
    }
}

/// Adapter to make PDFContentBlock analyzable.
struct AnalyzablePDFBlock: AnalyzableBlock {
    let block: PDFContentBlock

    var isVisual: Bool {
        switch block.type {
        case .visual, .flowchart, .conceptMap, .processTimeline:
            return true
        default:
            return false
        }
    }

    var wordCount: Int {
        block.content.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    var visualSizeCategory: VisualSizeCategory? {
        guard isVisual else { return nil }
        // Default to medium for now - actual size would come from visual metadata
        return .medium
    }
}

// MARK: - Documentation

/*
 ## Visual Density Scoring Documentation

 ### Penalties

 1. **Consecutive Visuals** (warning, -0.05 per issue)
    - Trigger: 2+ visuals in a row without text
    - Why: Readers need context between visuals

 2. **Oversized Visuals** (warning, -0.20 * ratio)
    - Trigger: Visual > 90% of page width
    - Why: Oversized visuals cause PDF page break issues

 3. **Insufficient Text Before Visual** (info, -0.05 per issue)
    - Trigger: < 30 words before a visual
    - Why: Visuals need explanatory context

 4. **Excessive Visual Density** (warning, up to -0.20)
    - Trigger: > 3 visuals per 1000 words
    - Why: Too many visuals overwhelm readers

 ### Rewards

 1. **Well-Placed Visuals** (+0.10 * ratio)
    - Trigger: >= 80 words before visual
    - Why: Encourages proper contextual placement

 ### Score Ranges

 - 0.90-1.00: Excellent visual integration
 - 0.80-0.89: Good visual balance
 - 0.70-0.79: Acceptable, minor improvements possible
 - 0.60-0.69: Needs attention
 - Below 0.60: Significant visual density issues

 ### Integration Points

 This analyzer integrates with:
 - `LayoutScore.issues`: Add visual density issues
 - `LayoutScore.overall`: Visual density contributes ~15-20%
 - `LayoutRegenerationPolicy`: Triggers constraints like `reduceVisualDensity`
 */
