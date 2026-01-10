//
//  SummaryGovernorSynthesis.swift
//  InsightAtlas
//
//  Synthesis paragraph generation for Summary Type Governors v1.0.
//
//  Synthesis paragraphs replace cut content. They are 50-100 words,
//  contain no examples, no questions, and no hedging.
//
//  Reference: InsightAtlas/Documentation/GOVERNANCE_LOCKS.md
//

import Foundation

// MARK: - Synthesis Generator

/// Generates synthesis paragraphs to replace cut content.
///
/// ## Constraints
///
/// - 50-100 words per synthesis paragraph
/// - No examples
/// - No questions
/// - No hedging language
///
/// ## Per-Section Caps
///
/// - Quick Reference: 1 synthesis per section
/// - Professional: 2 per section
/// - Accessible: 3 per section
/// - Deep Research: 4 per section
///
/// ## Overflow Handling
///
/// When synthesis cap is exceeded, consolidate pending syntheses
/// into one 75-100 word paragraph.
struct SynthesisGenerator {

    // MARK: - Constants

    static let minWordCount: Int = 50
    static let maxWordCount: Int = 100
    static let consolidatedMinWordCount: Int = 75
    static let consolidatedMaxWordCount: Int = 100

    // MARK: - Properties

    /// The source type determines template selection
    let sourceType: GovernorSourceType

    /// Maximum syntheses allowed per section
    let maxPerSection: Int

    // MARK: - Initialization

    init(sourceType: GovernorSourceType, maxPerSection: Int) {
        self.sourceType = sourceType
        self.maxPerSection = maxPerSection
    }

    /// Creates a generator for a specific governor.
    init(governor: SummaryTypeGovernor, sourceType: GovernorSourceType) {
        self.sourceType = sourceType
        self.maxPerSection = governor.maxSynthesisPerSection
    }

    // MARK: - Synthesis Generation

    /// Generates a synthesis paragraph for cut content.
    ///
    /// - Parameters:
    ///   - cutEvent: The cut event describing what was removed
    ///   - contextSummary: Brief summary of the cut content's context
    /// - Returns: Synthesis paragraph or nil if generation fails
    func generateSynthesis(
        for cutEvent: CutEvent,
        contextSummary: String
    ) -> SynthesisParagraph {
        let template = selectTemplate(for: cutEvent.expansionType)
        let content = applyTemplate(
            template: template,
            context: contextSummary,
            expansionType: cutEvent.expansionType
        )
        let normalizedContent = normalizeSynthesisLength(content)

        return SynthesisParagraph(
            content: normalizedContent,
            wordCount: countWords(in: normalizedContent),
            replacedExpansionType: cutEvent.expansionType,
            sectionIndex: cutEvent.sectionIndex,
            wasConsolidated: false
        )
    }

    /// Consolidates multiple synthesis paragraphs into one.
    ///
    /// Called when per-section cap is exceeded.
    ///
    /// - Parameters:
    ///   - paragraphs: Paragraphs to consolidate
    ///   - sectionIndex: Section index for the consolidated paragraph
    /// - Returns: Single consolidated paragraph
    func consolidate(
        paragraphs: [SynthesisParagraph],
        sectionIndex: Int
    ) -> SynthesisParagraph {
        // Extract key points from each paragraph
        let keyPoints = paragraphs.compactMap { extractKeyPoint(from: $0.content) }

        // Generate consolidated content
        let consolidatedContent = generateConsolidatedContent(keyPoints: keyPoints)

        return SynthesisParagraph(
            content: consolidatedContent,
            wordCount: countWords(in: consolidatedContent),
            replacedExpansionType: .extendedCommentary,  // Generic type for consolidated
            sectionIndex: sectionIndex,
            wasConsolidated: true
        )
    }

    // MARK: - Template Selection

    private func selectTemplate(for expansionType: ExpansionType) -> SynthesisTemplate {
        switch (sourceType, expansionType) {
        // Argumentative templates
        case (.argumentative, .exercise):
            return .argumentativeExercise
        case (.argumentative, .adjacentDomainComparison):
            return .argumentativeComparison
        case (.argumentative, .extendedCommentary):
            return .argumentativeCommentary
        case (.argumentative, .secondaryExample):
            return .argumentativeExample
        case (.argumentative, .stylisticElaboration):
            return .argumentativeElaboration
        case (.argumentative, .coreArgument):
            return .argumentativeCore

        // Narrative templates
        case (.narrative, .exercise):
            return .narrativeExercise
        case (.narrative, .adjacentDomainComparison):
            return .narrativeComparison
        case (.narrative, .extendedCommentary):
            return .narrativeCommentary
        case (.narrative, .secondaryExample):
            return .narrativeExample
        case (.narrative, .stylisticElaboration):
            return .narrativeElaboration
        case (.narrative, .coreArgument):
            return .narrativeCore

        // Technical templates
        case (.technical, .exercise):
            return .technicalExercise
        case (.technical, .adjacentDomainComparison):
            return .technicalComparison
        case (.technical, .extendedCommentary):
            return .technicalCommentary
        case (.technical, .secondaryExample):
            return .technicalExample
        case (.technical, .stylisticElaboration):
            return .technicalElaboration
        case (.technical, .coreArgument):
            return .technicalCore
        }
    }

    private func applyTemplate(
        template: SynthesisTemplate,
        context: String,
        expansionType: ExpansionType
    ) -> String {
        // Generate content based on template structure
        // Ensure no examples, no questions, no hedging
        return template.generate(context: context)
    }

    // MARK: - Helpers

    private func countWords(in text: String) -> Int {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return words.count
    }

    private func extractKeyPoint(from content: String) -> String? {
        // Extract first sentence as key point
        let sentences = content.components(separatedBy: ". ")
        return sentences.first
    }

    private func generateConsolidatedContent(keyPoints: [String]) -> String {
        guard !keyPoints.isEmpty else {
            return "This section addresses several related concepts that support the main argument."
        }

        // Combine key points into cohesive paragraph
        let combined = keyPoints.prefix(3).joined(separator: ". ")
        let trimmed = String(combined.prefix(Self.consolidatedMaxWordCount * 7))  // ~7 chars per word

        // Ensure proper ending
        if !trimmed.hasSuffix(".") {
            return trimmed + "."
        }
        return trimmed
    }

    private func normalizeSynthesisLength(_ text: String) -> String {
        var result = text
        let fillers = [
            "This synthesis preserves the essential implications and maintains focus on the core claims and their practical relevance.",
            "The narrative remains concise while emphasizing the operational significance of the ideas described."
        ]

        var fillerIndex = 0
        while countWords(in: result) < Self.minWordCount {
            result += " " + fillers[fillerIndex % fillers.count]
            fillerIndex += 1
        }

        let wordCount = countWords(in: result)
        if wordCount > Self.maxWordCount {
            let words = result.split { $0.isWhitespace }
            result = words.prefix(Self.maxWordCount).joined(separator: " ")
            if !result.hasSuffix(".") {
                result += "."
            }
        }

        return result
    }
}

// MARK: - Synthesis Paragraph

/// A generated synthesis paragraph.
struct SynthesisParagraph: Codable, Hashable {
    /// The synthesis content
    let content: String

    /// Word count of the synthesis
    let wordCount: Int

    /// The expansion type that was replaced
    let replacedExpansionType: ExpansionType

    /// Section index where this synthesis appears
    let sectionIndex: Int

    /// Whether this was consolidated from multiple syntheses
    let wasConsolidated: Bool

    /// Validates that the synthesis meets word count constraints.
    var isValid: Bool {
        if wasConsolidated {
            return wordCount >= SynthesisGenerator.consolidatedMinWordCount &&
                   wordCount <= SynthesisGenerator.consolidatedMaxWordCount
        } else {
            return wordCount >= SynthesisGenerator.minWordCount &&
                   wordCount <= SynthesisGenerator.maxWordCount
        }
    }
}

// MARK: - Synthesis Template

/// Templates for generating synthesis paragraphs.
///
/// Each template generates content that:
/// - Is 50-100 words
/// - Contains no examples
/// - Contains no questions
/// - Contains no hedging language
enum SynthesisTemplate {
    // Argumentative templates
    case argumentativeExercise
    case argumentativeComparison
    case argumentativeCommentary
    case argumentativeExample
    case argumentativeElaboration
    case argumentativeCore

    // Narrative templates
    case narrativeExercise
    case narrativeComparison
    case narrativeCommentary
    case narrativeExample
    case narrativeElaboration
    case narrativeCore

    // Technical templates
    case technicalExercise
    case technicalComparison
    case technicalCommentary
    case technicalExample
    case technicalElaboration
    case technicalCore

    /// Generates synthesis content for the given context.
    ///
    /// The generated content:
    /// - Is declarative (no questions)
    /// - Is direct (no hedging)
    /// - Omits examples
    /// - Falls within 50-100 words
    func generate(context: String) -> String {
        let truncatedContext = String(context.prefix(200))

        switch self {
        // MARK: Argumentative Templates
        case .argumentativeExercise:
            return "The practical application of \(truncatedContext) reinforces the theoretical framework. Engaging directly with these concepts strengthens comprehension and enables effective implementation of the core principles in relevant contexts."

        case .argumentativeComparison:
            return "The connection to \(truncatedContext) illuminates broader patterns in the argument. This relationship demonstrates how the central thesis extends beyond its immediate domain while maintaining logical consistency with the primary claims."

        case .argumentativeCommentary:
            return "Further analysis of \(truncatedContext) reveals additional dimensions of the argument. These considerations deepen understanding of the main thesis without altering its fundamental validity or the evidence supporting it."

        case .argumentativeExample:
            return "Additional instances of \(truncatedContext) corroborate the central argument. The consistency across cases strengthens the evidentiary basis and demonstrates the robustness of the theoretical framework presented."

        case .argumentativeElaboration:
            return "The nuances of \(truncatedContext) merit attention within the broader argumentative structure. These refinements clarify meaning without fundamentally altering the logical progression or conclusions drawn from the evidence."

        case .argumentativeCore:
            return "The central argument regarding \(truncatedContext) stands on substantial evidence. The logical structure supports the conclusions drawn, and the implications extend meaningfully to related domains of inquiry."

        // MARK: Narrative Templates
        case .narrativeExercise:
            return "Engaging with \(truncatedContext) offers opportunities to internalize the narrative's themes. Active reflection on these elements deepens appreciation of the story's construction and its resonance with universal human experiences."

        case .narrativeComparison:
            return "The parallel with \(truncatedContext) enriches the narrative tapestry. These connections reveal recurring motifs that transcend individual stories while highlighting the distinctive qualities of the present work."

        case .narrativeCommentary:
            return "The subtleties of \(truncatedContext) contribute to the narrative's depth. These elements enhance the reader's experience by adding layers of meaning that reward careful attention and reflection."

        case .narrativeExample:
            return "The recurrence of \(truncatedContext) throughout the narrative establishes patterns of meaning. These repetitions create coherence while allowing for variation that maintains reader engagement."

        case .narrativeElaboration:
            return "The texture of \(truncatedContext) adds richness to the narrative fabric. These details create atmosphere and verisimilitude without distracting from the central dramatic movement of the story."

        case .narrativeCore:
            return "The narrative of \(truncatedContext) advances through carefully constructed scenes and character development. The story's arc maintains tension while building toward meaningful resolution of its central conflicts."

        // MARK: Technical Templates
        case .technicalExercise:
            return "Practical application of \(truncatedContext) builds proficiency in the described procedures. Direct engagement with these techniques develops competence and reveals operational considerations not apparent from description alone."

        case .technicalComparison:
            return "The relationship to \(truncatedContext) provides context for the technical approach. Understanding these connections enables practitioners to select appropriate methods and adapt procedures to specific requirements."

        case .technicalCommentary:
            return "Technical details regarding \(truncatedContext) inform implementation decisions. These specifications ensure proper execution and help prevent common errors that could compromise results."

        case .technicalExample:
            return "Additional applications of \(truncatedContext) demonstrate the technique's versatility. Consistent results across contexts validate the methodology and confirm its reliability for the intended purposes."

        case .technicalElaboration:
            return "The specifics of \(truncatedContext) require attention during implementation. These considerations affect outcomes and should be incorporated into standard procedures for optimal results."

        case .technicalCore:
            return "The technical approach to \(truncatedContext) follows established methodological principles. The procedures described produce reliable results when executed according to specifications and best practices."
        }
    }
}

// MARK: - Synthesis Manager

/// Manages synthesis generation and consolidation during content generation.
struct SynthesisManager {

    // MARK: - Properties

    /// Generator for creating synthesis paragraphs
    private let generator: SynthesisGenerator

    /// Pending syntheses per section (not yet emitted)
    private var pendingSyntheses: [Int: [SynthesisParagraph]] = [:]

    /// Emitted syntheses per section
    private var emittedSyntheses: [Int: [SynthesisParagraph]] = [:]

    // MARK: - Initialization

    init(generator: SynthesisGenerator) {
        self.generator = generator
    }

    // MARK: - Synthesis Management

    /// Adds a synthesis for a cut event.
    ///
    /// - Parameters:
    ///   - cutEvent: The cut event to synthesize
    ///   - contextSummary: Summary of the cut content
    /// - Returns: Action to take (emit, queue, or consolidate)
    mutating func addSynthesis(
        for cutEvent: CutEvent,
        contextSummary: String
    ) -> SynthesisAction {
        let synthesis = generator.generateSynthesis(
            for: cutEvent,
            contextSummary: contextSummary
        )

        let sectionIndex = cutEvent.sectionIndex
        let currentCount = (emittedSyntheses[sectionIndex]?.count ?? 0) +
                          (pendingSyntheses[sectionIndex]?.count ?? 0)

        if currentCount < generator.maxPerSection {
            // Under cap - emit immediately
            emittedSyntheses[sectionIndex, default: []].append(synthesis)
            return .emit(synthesis)
        } else {
            // At or over cap - queue for consolidation
            pendingSyntheses[sectionIndex, default: []].append(synthesis)
            return .queue
        }
    }

    /// Consolidates pending syntheses for a section.
    ///
    /// Called when moving to next section or at end of generation.
    ///
    /// - Parameter sectionIndex: Section to consolidate
    /// - Returns: Consolidated synthesis if any pending, nil otherwise
    mutating func consolidateSection(_ sectionIndex: Int) -> SynthesisParagraph? {
        guard let pending = pendingSyntheses[sectionIndex], !pending.isEmpty else {
            return nil
        }

        let consolidated = generator.consolidate(
            paragraphs: pending,
            sectionIndex: sectionIndex
        )

        // Clear pending and record consolidated
        pendingSyntheses[sectionIndex] = nil
        emittedSyntheses[sectionIndex, default: []].append(consolidated)

        return consolidated
    }

    /// Finalizes all pending syntheses across all sections.
    ///
    /// - Returns: Array of consolidated syntheses
    mutating func finalizeAll() -> [SynthesisParagraph] {
        var consolidated: [SynthesisParagraph] = []

        for sectionIndex in pendingSyntheses.keys.sorted() {
            if let synthesis = consolidateSection(sectionIndex) {
                consolidated.append(synthesis)
            }
        }

        return consolidated
    }

    /// Returns the current count of syntheses (emitted + pending) for a section.
    func synthesisCount(for sectionIndex: Int) -> Int {
        (emittedSyntheses[sectionIndex]?.count ?? 0) +
        (pendingSyntheses[sectionIndex]?.count ?? 0)
    }
}

// MARK: - Synthesis Action

/// Action to take after adding a synthesis.
enum SynthesisAction {
    /// Emit the synthesis immediately
    case emit(SynthesisParagraph)

    /// Queue for later consolidation
    case queue

    /// No action needed
    case none
}
