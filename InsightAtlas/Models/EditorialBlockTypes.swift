//
//  EditorialBlockTypes.swift
//  InsightAtlas
//
//  Canonical editorial block types for semantic content structure.
//
//  IMPORTANT: This module defines the authoritative editorial grammar.
//  All content must be normalized into these explicit block types before rendering.
//
//  These types represent MEANING, not styling. Renderers interpret them
//  according to their target format (SwiftUI, PDF, HTML, DOCX).
//
//  CONSTRAINTS:
//  - Do NOT add visual/styling information here
//  - Do NOT encode markdown syntax
//  - Each block type has ONE semantic purpose
//

import Foundation

// MARK: - Editorial Block Type

/// Canonical editorial block types defining semantic meaning.
/// Each type represents a distinct editorial function in the Insight Atlas grammar.
enum EditorialBlockType: String, Codable, CaseIterable {

    // MARK: - Structural Blocks

    /// Major document division (PART I, PART II)
    case partHeader = "part_header"

    /// Section heading within a part
    case sectionHeader = "section_header"

    /// Subsection heading (H3 level)
    case subsectionHeader = "subsection_header"

    /// Minor heading (H4 level)
    case minorHeader = "minor_header"

    /// Visual separator between content sections
    case sectionDivider = "section_divider"

    /// Transitional text between major sections
    case stageHeader = "stage_header"

    // MARK: - Narrative Blocks

    /// Standard body paragraph - explanatory prose
    case paragraph = "paragraph"

    /// Origin story and cultural context for the book
    case foundationalNarrative = "foundational_narrative"

    /// Author background and credentials
    case authorSpotlight = "author_spotlight"

    // MARK: - Summary Blocks

    /// Ultra-condensed one-page summary
    case quickGlance = "quick_glance"

    /// Numbered key takeaways from content
    case keyTakeaways = "key_takeaways"

    // MARK: - Insight Blocks

    /// Core insight connection with practical implications
    case insightNote = "insight_note"

    /// Contrasting viewpoint or nuanced perspective
    case alternativePerspective = "alternative_perspective"

    /// Research-backed insight with citations
    case researchInsight = "research_insight"

    // MARK: - Quote Blocks

    /// Premium formatted quote with attribution
    case premiumQuote = "premium_quote"

    /// Standard blockquote
    case blockquote = "blockquote"

    // MARK: - Framework Blocks

    /// Conceptual framework with grouped elements
    case framework = "framework"

    /// Decision tree with branching logic
    case decisionTree = "decision_tree"

    /// Linear process flow diagram
    case processFlow = "process_flow"

    /// Before/after comparison layout
    case comparisonBeforeAfter = "comparison_before_after"

    /// Concept map with relationships
    case conceptMap = "concept_map"

    // MARK: - Action Blocks

    /// Practical application steps
    case applyIt = "apply_it"

    /// Numbered action steps with timeframes
    case actionBox = "action_box"

    /// Interactive exercise with prompts
    case exercise = "exercise"

    // MARK: - List Blocks

    /// Unordered bullet list
    case bulletList = "bullet_list"

    /// Ordered numbered list
    case numberedList = "numbered_list"

    // MARK: - Table Blocks

    /// Data table with rows and columns
    case table = "table"

    // MARK: - Visual Blocks

    /// AI-generated or referenced visual
    case visual = "visual"

    // MARK: - Properties

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .partHeader: return "Part Header"
        case .sectionHeader: return "Section Header"
        case .subsectionHeader: return "Subsection Header"
        case .minorHeader: return "Minor Header"
        case .sectionDivider: return "Section Divider"
        case .stageHeader: return "Stage Header"
        case .paragraph: return "Paragraph"
        case .foundationalNarrative: return "Foundational Narrative"
        case .authorSpotlight: return "Author Spotlight"
        case .quickGlance: return "Quick Glance"
        case .keyTakeaways: return "Key Takeaways"
        case .insightNote: return "Insight Note"
        case .alternativePerspective: return "Alternative Perspective"
        case .researchInsight: return "Research Insight"
        case .premiumQuote: return "Premium Quote"
        case .blockquote: return "Blockquote"
        case .framework: return "Framework"
        case .decisionTree: return "Decision Tree"
        case .processFlow: return "Process Flow"
        case .comparisonBeforeAfter: return "Before/After Comparison"
        case .conceptMap: return "Concept Map"
        case .applyIt: return "Apply It"
        case .actionBox: return "Action Box"
        case .exercise: return "Exercise"
        case .bulletList: return "Bullet List"
        case .numberedList: return "Numbered List"
        case .table: return "Table"
        case .visual: return "Visual"
        }
    }

    /// Whether this block type should receive a visual
    var supportsVisual: Bool {
        switch self {
        case .framework, .decisionTree, .processFlow, .comparisonBeforeAfter, .conceptMap:
            return true
        case .premiumQuote:
            return true  // Quote card visual
        case .insightNote, .researchInsight:
            return true  // Commentary card visual
        default:
            return false
        }
    }

    /// The appropriate visual type for this block
    var recommendedVisualType: GuideVisualType? {
        switch self {
        case .decisionTree: return .flowDiagram
        case .processFlow: return .timeline
        case .framework: return .conceptMap
        case .comparisonBeforeAfter: return .comparisonMatrix
        case .conceptMap: return .conceptMap
        default: return nil
        }
    }

    /// Whether this block contains structured content (not prose)
    var isStructured: Bool {
        switch self {
        case .framework, .decisionTree, .processFlow, .comparisonBeforeAfter,
             .conceptMap, .actionBox, .exercise, .keyTakeaways, .quickGlance,
             .bulletList, .numberedList, .table:
            return true
        default:
            return false
        }
    }
}

// MARK: - Editorial Block

/// A single editorial block with semantic type and content.
/// This is the canonical unit of content in the Insight Atlas editorial system.
struct EditorialBlock: Identifiable, Codable {
    let id: UUID
    let type: EditorialBlockType
    let title: String?
    let body: String
    let attribution: EditorialAttribution?
    let intent: String?
    let metadata: EditorialBlockMetadata?

    // Structured content for specific block types
    let listItems: [String]?
    let tableData: [[String]]?
    let steps: [EditorialStep]?
    let branches: [EditorialBranch]?

    init(
        id: UUID = UUID(),
        type: EditorialBlockType,
        title: String? = nil,
        body: String,
        attribution: EditorialAttribution? = nil,
        intent: String? = nil,
        metadata: EditorialBlockMetadata? = nil,
        listItems: [String]? = nil,
        tableData: [[String]]? = nil,
        steps: [EditorialStep]? = nil,
        branches: [EditorialBranch]? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.attribution = attribution
        self.intent = intent
        self.metadata = metadata
        self.listItems = listItems
        self.tableData = tableData
        self.steps = steps
        self.branches = branches
    }
}

// MARK: - Supporting Types

/// Attribution for quotes, research, and author content
struct EditorialAttribution: Codable {
    let source: String?
    let author: String?
    let publication: String?
    let year: String?
    let url: String?
}

/// Metadata for editorial blocks
struct EditorialBlockMetadata: Codable {
    let estimatedReadTime: String?
    let difficulty: String?
    let category: String?
    let tags: [String]?
    let visualURL: URL?
    let visualType: GuideVisualType?
}

/// Step in a process flow or action sequence
struct EditorialStep: Identifiable, Codable {
    let id: UUID
    let number: Int
    let instruction: String
    let outcome: String?
    let timeframe: String?

    init(
        id: UUID = UUID(),
        number: Int,
        instruction: String,
        outcome: String? = nil,
        timeframe: String? = nil
    ) {
        self.id = id
        self.number = number
        self.instruction = instruction
        self.outcome = outcome
        self.timeframe = timeframe
    }
}

/// Branch in a decision tree
struct EditorialBranch: Identifiable, Codable {
    let id: UUID
    let condition: String
    let outcome: String
    let children: [EditorialBranch]?

    init(
        id: UUID = UUID(),
        condition: String,
        outcome: String,
        children: [EditorialBranch]? = nil
    ) {
        self.id = id
        self.condition = condition
        self.outcome = outcome
        self.children = children
    }
}

// MARK: - Editorial Document

/// A complete editorial document with normalized blocks
struct EditorialDocument: Identifiable, Codable {
    let id: UUID
    let title: String
    let author: String
    let blocks: [EditorialBlock]
    let generatedAt: Date
    let version: String

    init(
        id: UUID = UUID(),
        title: String,
        author: String,
        blocks: [EditorialBlock],
        generatedAt: Date = Date(),
        version: String = "editorial-v1.0"
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.blocks = blocks
        self.generatedAt = generatedAt
        self.version = version
    }

    /// Extract blocks of a specific type
    func blocks(ofType type: EditorialBlockType) -> [EditorialBlock] {
        blocks.filter { $0.type == type }
    }

    /// Check if document has any blocks of a type
    func hasBlocks(ofType type: EditorialBlockType) -> Bool {
        blocks.contains { $0.type == type }
    }
}

// MARK: - Pattern Recognition Constants

/// Patterns that indicate specific editorial block types in raw content
enum EditorialPatternMarker {

    /// Patterns indicating "Why It Matters" → insight_note
    static let whyItMattersPatterns = [
        "why it matters",
        "why this matters",
        "the significance",
        "this is important because"
    ]

    /// Patterns indicating "In Practice" → apply_it
    static let inPracticePatterns = [
        "in practice",
        "how to apply",
        "putting it into action",
        "practical application",
        "try this"
    ]

    /// Patterns indicating real-world application → foundational_narrative
    static let realWorldPatterns = [
        "real-world application",
        "real-world example",
        "in the real world",
        "for example"
    ]

    /// Patterns indicating conceptual framework → framework
    static let frameworkPatterns = [
        "key concepts",
        "core framework",
        "the framework",
        "conceptual model",
        "the model"
    ]

    /// Patterns indicating decision point → decision_tree
    static let decisionPatterns = [
        "decision point",
        "if you",
        "when you",
        "choose between",
        "either...or"
    ]

    /// Patterns indicating before/after → comparison_before_after
    static let beforeAfterPatterns = [
        "before:",
        "after:",
        "instead of",
        "rather than",
        "compare",
        "contrast"
    ]

    /// Patterns indicating research insight → research_insight
    static let researchPatterns = [
        "research shows",
        "studies indicate",
        "according to research",
        "evidence suggests",
        "data shows"
    ]

    /// Patterns indicating alternative perspective → alternative_perspective
    static let alternativePatterns = [
        "on the other hand",
        "however",
        "alternatively",
        "a different view",
        "critics argue"
    ]
}
