//
//  VisualSelectionService.swift
//  InsightAtlas
//
//  Visual Selection by Meaning.
//
//  This service determines appropriate visual types based on semantic block types.
//  Visuals are selected by MEANING, not for decoration.
//
//  IMPORTANT: This service does NOT:
//  - Generate visuals
//  - Modify rendering code
//  - Apply visual styles
//
//  It only determines WHAT visual is appropriate for a given block type.
//
//  VISUAL SELECTION RULES:
//  - decision_tree → branching diagram
//  - process_flow → linear flow
//  - framework → grouped conceptual diagram
//  - comparison_before_after → side-by-side layout
//  - premium_quote → quote card
//  - insight_note / research_insight → commentary card
//
//  DO NOT generate visuals for:
//  - Explanatory prose (paragraph)
//  - Narrative reflection (foundational_narrative)
//  - Commentary text (blockquote)
//

import Foundation

// MARK: - Visual Selection Service

/// Determines appropriate visual types based on semantic meaning.
///
/// CALIBRATION (Canonical HTML Reference):
/// The canonical HTML demonstrates deliberate visual absence:
/// - author-spotlight: NO visual (biographical text)
/// - foundational-narrative: NO visual (prose rhythm, reflective)
/// - insight-note: NO visual (commentary pause)
/// - premium-quote: NO visual (cognitive isolation for emphasis)
/// - apply-it: NO visual (action prompt, not diagram)
/// - key-takeaways: NO visual (list structure is sufficient)
/// - framework: CONDITIONAL visual (only with complex relationships)
/// - process-flow: CONDITIONAL visual (only for 3+ steps)
///
/// Visuals clarify thinking models; they do not decorate sections.
final class VisualSelectionService {

    // MARK: - Calibration Constants

    /// Minimum steps required for a process flow to warrant visualization
    private let minimumProcessStepsForVisual = 3

    /// Minimum framework items to warrant a concept map
    private let minimumFrameworkItemsForVisual = 3

    /// Minimum word count for insight blocks to potentially receive visuals
    private let minimumInsightWordsForVisual = 250

    // MARK: - Visual Selection Result

    struct VisualSelection {
        let shouldHaveVisual: Bool
        let visualType: GuideVisualType?
        let visualCategory: VisualCategory
        let rationale: String
    }

    enum VisualCategory {
        case none
        case diagram
        case card
        case comparison
        case timeline
    }

    // MARK: - Public Methods

    /// Determine appropriate visual for an editorial block
    ///
    /// - Parameter block: The editorial block to analyze
    /// - Returns: Visual selection with type and rationale
    func selectVisual(for block: EditorialBlock) -> VisualSelection {
        switch block.type {

        // MARK: - Diagram Visuals

        case .decisionTree:
            return VisualSelection(
                shouldHaveVisual: true,
                visualType: .flowDiagram,
                visualCategory: .diagram,
                rationale: "Decision trees require branching diagram visualization to show conditional logic paths"
            )

        case .processFlow:
            // CALIBRATION: Only visualize process flows with 3+ steps
            // Canonical HTML shows "Regulate → Relate → Reason" (3 steps) warrants visualization
            let stepCount = block.steps?.count ?? 0
            let shouldVisualize = stepCount >= minimumProcessStepsForVisual
            return VisualSelection(
                shouldHaveVisual: shouldVisualize,
                visualType: shouldVisualize ? .timeline : nil,
                visualCategory: shouldVisualize ? .timeline : .none,
                rationale: shouldVisualize
                    ? "Process flow with \(stepCount) steps benefits from timeline visualization"
                    : "Process flow with fewer than \(minimumProcessStepsForVisual) steps uses text format"
            )

        case .framework:
            // CALIBRATION: Only visualize frameworks with 3+ grouped concepts
            // Canonical HTML shows "The Tree of Regulation" (brainstem/limbic/cortex = 3 items)
            let itemCount = block.listItems?.count ?? 0
            let shouldVisualize = itemCount >= minimumFrameworkItemsForVisual
            return VisualSelection(
                shouldHaveVisual: shouldVisualize,
                visualType: shouldVisualize ? .conceptMap : nil,
                visualCategory: shouldVisualize ? .diagram : .none,
                rationale: shouldVisualize
                    ? "Framework with \(itemCount) elements benefits from concept map"
                    : "Framework with fewer than \(minimumFrameworkItemsForVisual) elements uses list format"
            )

        case .conceptMap:
            return VisualSelection(
                shouldHaveVisual: true,
                visualType: .conceptMap,
                visualCategory: .diagram,
                rationale: "Concept maps require visual representation of interconnected ideas"
            )

        // MARK: - Comparison Visuals

        case .comparisonBeforeAfter:
            return VisualSelection(
                shouldHaveVisual: true,
                visualType: .comparisonMatrix,
                visualCategory: .comparison,
                rationale: "Before/after comparisons need side-by-side layout to show contrast"
            )

        // MARK: - Card Visuals (Calibrated)

        case .premiumQuote:
            // CALIBRATION: Canonical HTML isolates quotes for cognitive emphasis
            // NO visual - the quote itself is the visual unit
            // Surrounding visual absence creates reflection space
            return VisualSelection(
                shouldHaveVisual: false,
                visualType: nil,
                visualCategory: .none,
                rationale: "Premium quotes are isolated for cognitive emphasis; visual would compete for attention"
            )

        case .insightNote:
            // CALIBRATION: Canonical HTML uses insight notes sparingly without visuals
            // They serve as reflective pauses, not visualization opportunities
            return VisualSelection(
                shouldHaveVisual: false,
                visualType: nil,
                visualCategory: .none,
                rationale: "Insight notes are commentary pauses; visuals would disrupt reflection"
            )

        case .researchInsight:
            // CALIBRATION: Only visualize research insights with substantial data
            // Word count must exceed threshold to warrant visualization
            let wordCount = block.body.split(separator: " ").count
            let shouldVisualize = wordCount > minimumInsightWordsForVisual
            return VisualSelection(
                shouldHaveVisual: shouldVisualize,
                visualType: shouldVisualize ? .barChart : nil,
                visualCategory: shouldVisualize ? .card : .none,
                rationale: shouldVisualize
                    ? "Research insight with data warrants visualization"
                    : "Research insight uses text format for readability"
            )

        // MARK: - No Visual Required

        case .paragraph:
            return noVisualSelection(reason: "Explanatory prose does not require visualization")

        case .foundationalNarrative:
            return noVisualSelection(reason: "Narrative reflection is inherently textual")

        case .authorSpotlight:
            return noVisualSelection(reason: "Author information is biographical, not conceptual")

        case .blockquote:
            return noVisualSelection(reason: "Standard blockquotes use text formatting only")

        case .partHeader, .sectionHeader, .subsectionHeader, .minorHeader:
            return noVisualSelection(reason: "Headers are structural, not content blocks")

        case .sectionDivider, .stageHeader:
            return noVisualSelection(reason: "Dividers are formatting elements")

        case .quickGlance:
            return noVisualSelection(reason: "Quick glance is a summary format with inherent structure")

        case .keyTakeaways:
            return noVisualSelection(reason: "Takeaways use numbered list format")

        case .alternativePerspective:
            return noVisualSelection(reason: "Alternative perspectives are commentary text")

        case .applyIt, .actionBox:
            return noVisualSelection(reason: "Action items use step format, not visualization")

        case .exercise:
            return noVisualSelection(reason: "Exercises are interactive text, not visual")

        case .bulletList, .numberedList:
            return noVisualSelection(reason: "Lists use text formatting")

        case .table:
            return noVisualSelection(reason: "Tables have inherent visual structure")

        case .visual:
            return noVisualSelection(reason: "Already a visual block")
        }
    }

    /// Select visuals for an entire document
    ///
    /// - Parameter document: The editorial document
    /// - Returns: Map of block IDs to visual selections
    func selectVisuals(for document: EditorialDocument) -> [UUID: VisualSelection] {
        var selections: [UUID: VisualSelection] = [:]

        for block in document.blocks {
            let selection = selectVisual(for: block)
            selections[block.id] = selection
        }

        // Apply density rules - don't over-visualize
        return applyDensityRules(selections, document: document)
    }

    // MARK: - Private Methods

    private func noVisualSelection(reason: String) -> VisualSelection {
        VisualSelection(
            shouldHaveVisual: false,
            visualType: nil,
            visualCategory: .none,
            rationale: reason
        )
    }

    /// Apply density rules to prevent over-visualization
    ///
    /// CALIBRATION (Canonical HTML Reference):
    /// - Quotes and insight notes suppress nearby visuals (creates reflection space)
    /// - Visuals appear after narrative grounding (not at section start)
    /// - Not every framework/process receives a visual
    private func applyDensityRules(
        _ selections: [UUID: VisualSelection],
        document: EditorialDocument
    ) -> [UUID: VisualSelection] {
        var result = selections

        // CALIBRATION Rule 1: Quotes and insight notes create visual-free zones
        // Suppress visuals within 2 blocks of premium quotes or insight notes
        for (index, block) in document.blocks.enumerated() {
            if block.type == .premiumQuote || block.type == .insightNote {
                // Suppress visuals in nearby blocks (reflection space)
                let suppressionRange = max(0, index - 2)...min(document.blocks.count - 1, index + 2)
                for suppressIndex in suppressionRange {
                    let nearbyBlock = document.blocks[suppressIndex]
                    if let selection = result[nearbyBlock.id], selection.shouldHaveVisual {
                        result[nearbyBlock.id] = VisualSelection(
                            shouldHaveVisual: false,
                            visualType: nil,
                            visualCategory: .none,
                            rationale: "Proximity rule: Visual suppressed near quote/insight for reflection space"
                        )
                    }
                }
            }
        }

        // CALIBRATION Rule 2: Visuals appear after narrative grounding
        // First block in section should not be a visual
        var isFirstInSection = true
        for block in document.blocks {
            if block.type == .sectionHeader || block.type == .partHeader {
                isFirstInSection = true
                continue
            }

            if isFirstInSection {
                if let selection = result[block.id], selection.shouldHaveVisual {
                    result[block.id] = VisualSelection(
                        shouldHaveVisual: false,
                        visualType: nil,
                        visualCategory: .none,
                        rationale: "Grounding rule: Visual suppressed at section start; narrative first"
                    )
                }
                isFirstInSection = false
            }
        }

        // Rule 3: No more than one visual per section
        var lastVisualSectionIndex: Int? = nil
        var currentSectionIndex = 0

        for (index, block) in document.blocks.enumerated() {
            // Track section boundaries
            if block.type == .sectionHeader || block.type == .partHeader {
                currentSectionIndex += 1
                lastVisualSectionIndex = nil
            }

            // Check if this block has a visual
            if let selection = result[block.id], selection.shouldHaveVisual {
                if let lastIndex = lastVisualSectionIndex {
                    // Already have a visual in this section - reduce density
                    if index - lastIndex < 5 { // Within 5 blocks
                        result[block.id] = VisualSelection(
                            shouldHaveVisual: false,
                            visualType: nil,
                            visualCategory: .none,
                            rationale: "Density rule: Too close to previous visual in section"
                        )
                    } else {
                        lastVisualSectionIndex = index
                    }
                } else {
                    lastVisualSectionIndex = index
                }
            }
        }

        // Rule 4: Maximum 3 visuals per 1000 words
        let totalWords = document.blocks
            .map { $0.body.split(separator: " ").count }
            .reduce(0, +)

        let maxVisuals = max(3, totalWords / 1000 * 3)
        var visualCount = 0

        for block in document.blocks {
            if let selection = result[block.id], selection.shouldHaveVisual {
                visualCount += 1
                if visualCount > maxVisuals {
                    result[block.id] = VisualSelection(
                        shouldHaveVisual: false,
                        visualType: nil,
                        visualCategory: .none,
                        rationale: "Density rule: Maximum visual count exceeded"
                    )
                }
            }
        }

        return result
    }
}

// MARK: - Visual Type Descriptions

extension GuideVisualType {
    /// Description of when this visual type should be used
    var usageGuidelines: String {
        switch self {
        case .timeline:
            return "Use for sequential processes, historical progressions, or step-by-step workflows"
        case .flowDiagram:
            return "Use for decision trees, conditional logic, or branching processes"
        case .comparisonMatrix:
            return "Use for before/after comparisons, feature comparisons, or contrasting concepts"
        case .barChart:
            return "Use for quantitative comparisons, statistics, or research data"
        case .quadrant:
            return "Use for 2x2 matrices, priority grids, or dual-axis classifications"
        case .conceptMap:
            return "Use for interconnected concepts, relationship diagrams, or framework visualizations"
        }
    }

    /// Whether this visual type reduces cognitive load for complex content
    var reducesCognitiveLoad: Bool {
        switch self {
        case .conceptMap, .flowDiagram, .comparisonMatrix:
            return true
        case .timeline, .barChart, .quadrant:
            return true
        }
    }
}
