//
//  ReaderLayoutPresets.swift
//  InsightAtlas
//
//  Declarative layout presets keyed by reader profile.
//
//  These presets define GENERATION constraints, not rendering behavior.
//  They influence what content is generated, not how it is displayed.
//
//  Reference: InsightAtlas/Documentation/FormattingInvariants.md
//

import Foundation

// MARK: - Reader Layout Preset

/// Declarative layout constraints for a specific reader profile.
///
/// ## Important: Generation vs Rendering
///
/// These presets affect **generation** constraints only:
/// - What content is produced by the LLM
/// - How much text vs visuals to include
/// - Paragraph length targets
///
/// They do NOT affect **rendering**:
/// - Font sizes remain constant
/// - Colors remain constant
/// - Spacing rules remain constant
///
/// ## Interaction with Layout Scoring
///
/// Layout scoring evaluates the generated content against universal
/// formatting invariants. Presets help generate content that is more
/// likely to score well for a given reader profile, but the scoring
/// rubric itself does not change based on preset.
///
/// For example:
/// - An "executive" preset generates shorter paragraphs
/// - Shorter paragraphs have better readability scores in general
/// - The executive guide is more likely to score well on paragraph metrics
struct ReaderLayoutPreset: Codable, Identifiable {

    // MARK: - Identity

    /// Unique identifier for this preset
    let id: String

    /// Human-readable name
    let displayName: String

    /// Description of the target reader
    let description: String

    // MARK: - Text Constraints

    /// Maximum recommended paragraph word count
    let maxParagraphLength: Int

    /// Minimum paragraph word count (to avoid fragmentation)
    let minParagraphLength: Int

    /// Whether to allow dense text blocks (multiple long paragraphs)
    let allowDenseText: Bool

    /// Target reading level (Flesch-Kincaid grade level)
    let targetReadingLevel: ClosedRange<Int>

    // MARK: - Visual Constraints

    /// Maximum visuals per section
    let maxVisualsPerSection: Int

    /// Whether to prefer diagrams over tables
    let preferDiagrams: Bool

    /// Minimum text word count between consecutive visuals
    let minTextBetweenVisuals: Int

    /// Preferred visual complexity (1-5, where 5 is most complex)
    let preferredVisualComplexity: Int

    // MARK: - Structure Constraints

    /// Maximum section nesting depth
    let maxSectionDepth: Int

    /// Whether to include executive summary
    let includeExecutiveSummary: Bool

    /// Whether to include detailed appendices
    let includeDetailedAppendices: Bool

    /// Target total word count range
    let targetWordCount: ClosedRange<Int>

    // MARK: - Quality Thresholds

    /// Layout quality thresholds for this profile
    let qualityThresholds: LayoutQualityThresholds
}

// MARK: - Standard Presets

extension ReaderLayoutPreset {

    /// Executive reader: busy professionals who need quick insights
    ///
    /// Characteristics:
    /// - Short, punchy paragraphs
    /// - Limited visuals (one key visual per section)
    /// - Strong executive summary
    /// - Lower word count overall
    static let executive = ReaderLayoutPreset(
        id: "executive",
        displayName: "Executive",
        description: "Busy professionals seeking quick, actionable insights",
        maxParagraphLength: 100,
        minParagraphLength: 30,
        allowDenseText: false,
        targetReadingLevel: 10...14,
        maxVisualsPerSection: 1,
        preferDiagrams: false,
        minTextBetweenVisuals: 50,
        preferredVisualComplexity: 2,
        maxSectionDepth: 2,
        includeExecutiveSummary: true,
        includeDetailedAppendices: false,
        targetWordCount: 3000...5000,
        qualityThresholds: LayoutQualityThresholds(
            minimumAcceptable: 0.88,
            target: 0.92,
            ideal: 0.96,
            maxRegenerationAttempts: 3
        )
    )

    /// Academic reader: researchers and scholars who want depth
    ///
    /// Characteristics:
    /// - Longer, more detailed paragraphs
    /// - Dense text is acceptable
    /// - Detailed citations and appendices
    /// - Higher word count
    static let academic = ReaderLayoutPreset(
        id: "academic",
        displayName: "Academic",
        description: "Researchers and scholars seeking comprehensive analysis",
        maxParagraphLength: 180,
        minParagraphLength: 50,
        allowDenseText: true,
        targetReadingLevel: 14...18,
        maxVisualsPerSection: 2,
        preferDiagrams: false,
        minTextBetweenVisuals: 100,
        preferredVisualComplexity: 4,
        maxSectionDepth: 4,
        includeExecutiveSummary: true,
        includeDetailedAppendices: true,
        targetWordCount: 8000...15000,
        qualityThresholds: LayoutQualityThresholds(
            minimumAcceptable: 0.82,
            target: 0.88,
            ideal: 0.93,
            maxRegenerationAttempts: 4
        )
    )

    /// Practitioner reader: professionals applying concepts in their work
    ///
    /// Characteristics:
    /// - Action-oriented content
    /// - More visuals (diagrams, flowcharts)
    /// - Practical examples prominent
    /// - Moderate word count
    static let practitioner = ReaderLayoutPreset(
        id: "practitioner",
        displayName: "Practitioner",
        description: "Professionals seeking practical application guidance",
        maxParagraphLength: 120,
        minParagraphLength: 40,
        allowDenseText: false,
        targetReadingLevel: 11...14,
        maxVisualsPerSection: 3,
        preferDiagrams: true,
        minTextBetweenVisuals: 80,
        preferredVisualComplexity: 3,
        maxSectionDepth: 3,
        includeExecutiveSummary: true,
        includeDetailedAppendices: true,
        targetWordCount: 5000...8000,
        qualityThresholds: LayoutQualityThresholds(
            minimumAcceptable: 0.85,
            target: 0.90,
            ideal: 0.95,
            maxRegenerationAttempts: 3
        )
    )

    /// Skeptic reader: critical thinkers who question claims
    ///
    /// Characteristics:
    /// - Balanced presentation of evidence
    /// - Counter-arguments included
    /// - Source citations emphasized
    /// - Moderate visuals
    static let skeptic = ReaderLayoutPreset(
        id: "skeptic",
        displayName: "Skeptic",
        description: "Critical thinkers who value balanced, evidence-based analysis",
        maxParagraphLength: 150,
        minParagraphLength: 50,
        allowDenseText: true,
        targetReadingLevel: 12...16,
        maxVisualsPerSection: 2,
        preferDiagrams: false,
        minTextBetweenVisuals: 100,
        preferredVisualComplexity: 3,
        maxSectionDepth: 3,
        includeExecutiveSummary: true,
        includeDetailedAppendices: true,
        targetWordCount: 6000...10000,
        qualityThresholds: LayoutQualityThresholds(
            minimumAcceptable: 0.84,
            target: 0.89,
            ideal: 0.94,
            maxRegenerationAttempts: 3
        )
    )

    /// Returns the preset for a given ReaderProfile enum value.
    static func preset(for profile: ReaderProfile) -> ReaderLayoutPreset {
        switch profile {
        case .executive: return .executive
        case .academic: return .academic
        case .practitioner: return .practitioner
        case .skeptic: return .skeptic
        }
    }

    /// All available presets
    static let allPresets: [ReaderLayoutPreset] = [
        .executive,
        .academic,
        .practitioner,
        .skeptic
    ]
}

// MARK: - Preset Validation

extension ReaderLayoutPreset {

    /// Validates that the preset constraints are internally consistent.
    var isValid: Bool {
        // Paragraph constraints
        guard minParagraphLength < maxParagraphLength else { return false }
        guard maxParagraphLength > 0 else { return false }

        // Visual constraints
        guard maxVisualsPerSection >= 0 else { return false }
        guard minTextBetweenVisuals >= 0 else { return false }
        guard (1...5).contains(preferredVisualComplexity) else { return false }

        // Structure constraints
        guard maxSectionDepth > 0 else { return false }
        guard targetWordCount.lowerBound < targetWordCount.upperBound else { return false }

        // Quality thresholds
        guard qualityThresholds.isValid else { return false }

        return true
    }

    /// Returns warnings for potentially problematic constraint combinations.
    var warnings: [String] {
        var warnings: [String] = []

        // Warn about dense text with short paragraphs
        if allowDenseText && maxParagraphLength < 100 {
            warnings.append("Dense text enabled but max paragraph length is short")
        }

        // Warn about many visuals with high complexity
        if maxVisualsPerSection > 2 && preferredVisualComplexity > 3 {
            warnings.append("High visual count with high complexity may overwhelm readers")
        }

        // Warn about executive preset with high word count
        if id == "executive" && targetWordCount.lowerBound > 5000 {
            warnings.append("Executive preset should have lower word count target")
        }

        return warnings
    }
}

// MARK: - Preset Application

/// Result of applying a preset to generation constraints.
struct PresetApplicationResult: Codable {
    /// The preset that was applied
    let preset: ReaderLayoutPreset

    /// Generation constraints derived from the preset
    let generationConstraints: GenerationConstraints

    /// Any warnings generated during application
    let warnings: [String]

    /// Timestamp of application
    let appliedAt: Date
}

/// Generation constraints derived from a reader preset.
///
/// These are passed to the backend generation service.
/// They do NOT modify rendering behavior.
struct GenerationConstraints: Codable {
    /// Target paragraph word count range
    let paragraphWordCount: ClosedRange<Int>

    /// Maximum visuals to generate per section
    let maxVisualsPerSection: Int

    /// Minimum words between visuals
    let minTextBetweenVisuals: Int

    /// Preferred visual types (ordered by preference)
    let preferredVisualTypes: [GuideVisualType]

    /// Maximum section depth to generate
    let maxSectionDepth: Int

    /// Target total word count
    let targetWordCount: ClosedRange<Int>

    /// Whether to include executive summary
    let includeExecutiveSummary: Bool

    /// Whether to include appendices
    let includeAppendices: Bool

    /// Quality thresholds for regeneration decisions
    let qualityThresholds: LayoutQualityThresholds

    /// Creates constraints from a reader preset.
    init(from preset: ReaderLayoutPreset) {
        self.paragraphWordCount = preset.minParagraphLength...preset.maxParagraphLength
        self.maxVisualsPerSection = preset.maxVisualsPerSection
        self.minTextBetweenVisuals = preset.minTextBetweenVisuals
        self.maxSectionDepth = preset.maxSectionDepth
        self.targetWordCount = preset.targetWordCount
        self.includeExecutiveSummary = preset.includeExecutiveSummary
        self.includeAppendices = preset.includeDetailedAppendices
        self.qualityThresholds = preset.qualityThresholds

        // Determine preferred visual types based on preset
        if preset.preferDiagrams {
            self.preferredVisualTypes = [.flowDiagram, .conceptMap, .timeline, .quadrant, .comparisonMatrix, .barChart]
        } else {
            self.preferredVisualTypes = [.comparisonMatrix, .barChart, .timeline, .flowDiagram, .conceptMap, .quadrant]
        }
    }
}

// MARK: - Documentation

/*
 ## Reader Layout Presets Documentation

 ### How Presets Interact with Layout Scoring

 1. **Presets guide generation**: They tell the LLM what kind of content to produce
 2. **Scoring evaluates output**: The layout scoring rubric measures the result
 3. **Thresholds trigger regeneration**: If scores are low, content is regenerated

 The scoring rubric (defined in LayoutScore.swift) does NOT change based on
 preset. All documents are scored against the same invariants.

 However, presets include profile-specific quality thresholds:
 - Executive: Higher minimum (0.88) because short content should be tight
 - Academic: Lower minimum (0.82) because dense text has more room for issues
 - Practitioner: Standard minimum (0.85) with emphasis on visual placement
 - Skeptic: Slightly lower (0.84) to allow for detailed counter-arguments

 ### Example Workflow

 1. User selects "Executive" reader profile
 2. System loads `ReaderLayoutPreset.executive`
 3. `GenerationConstraints` are created from the preset
 4. Backend receives constraints and generates content accordingly
 5. Generated content is scored by `LayoutScore`
 6. If score < 0.88, `LayoutRegenerationPolicy` triggers retry
 7. Retry uses tightened constraints based on detected issues
 8. Process repeats up to 3 times (per executive preset)
 9. Best result is returned with quality decision

 ### Adding New Presets

 To add a new reader profile:

 1. Add case to `ReaderProfile` enum in GenerateGuideRequest.swift
 2. Create static preset in this file
 3. Add case to `preset(for:)` method
 4. Add to `allPresets` array
 5. Document characteristics in the preset's doc comment

 Presets should be:
 - Internally consistent (use `isValid` to verify)
 - Distinct from existing presets (serve different reader needs)
 - Documented with clear use cases
 */
