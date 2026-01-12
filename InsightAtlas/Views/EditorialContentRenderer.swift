//
//  EditorialContentRenderer.swift
//  InsightAtlas
//
//  SwiftUI renderer for editorial content blocks.
//  Parses markdown content into semantic blocks and renders with premium styling.
//

import SwiftUI

// MARK: - Editorial Content Renderer

/// Main view that parses and renders editorial content with premium styling
struct EditorialContentRenderer: View {
    let content: String
    let searchQuery: String
    let title: String
    let author: String

    @State private var blocks: [ParsedContentBlock] = []

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 24) {
            ForEach(blocks) { block in
                renderBlock(block)
                    .id(block.sectionIndex != nil ? "section_\(block.sectionIndex!)" : block.id.uuidString)
            }
        }
        .onAppear {
            blocks = ContentBlockParser.parse(content)
        }
        .onChange(of: content) { _, newContent in
            blocks = ContentBlockParser.parse(newContent)
        }
    }

    @ViewBuilder
    private func renderBlock(_ block: ParsedContentBlock) -> some View {
        switch block.type {
        case .quickGlance:
            QuickGlanceBlockView(content: block.content, metadata: block.metadata)

        case .insightNote:
            InsightNoteBlockView(content: block.content, title: block.title)

        case .actionBox:
            ActionBoxBlockView(items: block.listItems, title: block.title)

        case .keyTakeaways:
            KeyTakeawaysBlockView(items: block.listItems)

        case .foundationalNarrative:
            FoundationalNarrativeBlockView(content: block.content)

        case .exercise:
            ExerciseBlockView(content: block.content, steps: block.listItems, title: block.title, time: block.metadata["time"])

        case .premiumQuote:
            PremiumQuoteBlockView(quote: block.content, attribution: block.metadata["cite"])

        case .blockquote:
            BlockquoteBlockView(content: block.content, cite: block.metadata["cite"])

        case .authorSpotlight:
            AuthorSpotlightBlockView(content: block.content)

        case .alternativePerspective:
            AlternativePerspectiveBlockView(content: block.content, title: block.title)

        case .researchInsight:
            ResearchInsightBlockView(content: block.content, title: block.title)

        case .sectionHeader:
            SectionHeaderBlockView(text: block.content, level: 1)

        case .subsectionHeader:
            SectionHeaderBlockView(text: block.content, level: 2)

        case .minorHeader:
            SectionHeaderBlockView(text: block.content, level: 3)

        case .partHeader:
            PartHeaderBlockView(text: block.content)

        case .sectionDivider:
            PremiumDividerView()

        case .bulletList:
            BulletListBlockView(items: block.listItems)

        case .numberedList:
            NumberedListBlockView(items: block.listItems)

        case .paragraph:
            ParagraphBlockView(content: block.content, searchQuery: searchQuery)

        case .visual:
            VisualBlockView(url: block.metadata["url"], caption: block.metadata["caption"], visualType: block.metadata["type"])

        case .flowchart:
            FlowchartBlockView(steps: block.listItems, title: block.title)

        case .conceptMap:
            ConceptMapBlockView(central: block.metadata["central"] ?? "", related: block.listItems, title: block.title)

        case .processTimeline:
            ProcessTimelineBlockView(phases: block.listItems, title: block.title)

        case .table:
            TableBlockView(data: block.tableData)

        case .textDiagram:
            TextDiagramBlockView(content: block.content, title: block.title)
        }
    }
}

// MARK: - Parsed Content Block

enum ContentBlockType: String {
    case quickGlance
    case insightNote
    case actionBox
    case keyTakeaways
    case foundationalNarrative
    case exercise
    case premiumQuote
    case blockquote
    case authorSpotlight
    case alternativePerspective
    case researchInsight
    case sectionHeader
    case subsectionHeader
    case minorHeader
    case partHeader
    case sectionDivider
    case bulletList
    case numberedList
    case paragraph
    case visual
    case flowchart
    case conceptMap
    case processTimeline
    case table
    case textDiagram  // For ASCII/text-based diagrams with arrows
}

struct ParsedContentBlock: Identifiable {
    let id = UUID()
    let type: ContentBlockType
    let content: String
    let title: String?
    let listItems: [String]
    let tableData: [[String]]
    let metadata: [String: String]
    let sectionIndex: Int?  // For scrollable section anchors

    init(
        type: ContentBlockType,
        content: String = "",
        title: String? = nil,
        listItems: [String] = [],
        tableData: [[String]] = [],
        metadata: [String: String] = [:],
        sectionIndex: Int? = nil
    ) {
        self.type = type
        self.content = content
        self.title = title
        self.listItems = listItems
        self.tableData = tableData
        self.metadata = metadata
        self.sectionIndex = sectionIndex
    }
}

// MARK: - Content Block Parser

struct ContentBlockParser {

    static func parse(_ content: String) -> [ParsedContentBlock] {
        var blocks: [ParsedContentBlock] = []
        let lines = content.components(separatedBy: "\n")
        var i = 0

        // Section index counter for TOC navigation
        var currentSectionIndex = 0

        // Parsing state
        var inQuickGlance = false
        var quickGlanceContent: [String] = []
        var inInsightNote = false
        var insightNoteContent: [String] = []
        var inActionBox = false
        var actionBoxContent: [String] = []
        var actionBoxTitle: String?
        var inFoundationalNarrative = false
        var foundationalNarrativeContent: [String] = []
        var inExercise = false
        var exerciseContent: [String] = []
        var exerciseType: String?
        var inTakeaways = false
        var takeawaysContent: [String] = []
        var inPremiumQuote = false
        var premiumQuoteContent: [String] = []
        var inAuthorSpotlight = false
        var authorSpotlightContent: [String] = []
        var inAlternativePerspective = false
        var alternativePerspectiveContent: [String] = []
        var inResearchInsight = false
        var researchInsightContent: [String] = []
        var inVisual = false
        var visualTag: String?
        var visualTitle: String?
        var visualContent: [String] = []
        var inConceptMap = false
        var conceptMapContent: [String] = []
        var conceptMapTitle: String?
        var inProcessTimeline = false
        var processTimelineContent: [String] = []
        var processTimelineTitle: String?
        var currentParagraph: [String] = []

        func flushParagraph() {
            let text = currentParagraph.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                blocks.append(ParsedContentBlock(type: .paragraph, content: text))
            }
            currentParagraph = []
        }

        func flushOpenBlocks() {
            if inQuickGlance {
                inQuickGlance = false
                blocks.append(ParsedContentBlock(
                    type: .quickGlance,
                    content: quickGlanceContent.joined(separator: "\n")
                ))
                quickGlanceContent = []
            }
            if inInsightNote {
                inInsightNote = false
                blocks.append(ParsedContentBlock(
                    type: .insightNote,
                    content: insightNoteContent.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                ))
                insightNoteContent = []
            }
            if inActionBox {
                inActionBox = false
                blocks.append(ParsedContentBlock(
                    type: .actionBox,
                    title: actionBoxTitle ?? "Apply It",
                    listItems: parseListItems(actionBoxContent)
                ))
                actionBoxContent = []
                actionBoxTitle = nil
            }
            if inFoundationalNarrative {
                inFoundationalNarrative = false
                blocks.append(ParsedContentBlock(
                    type: .foundationalNarrative,
                    content: foundationalNarrativeContent.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                ))
                foundationalNarrativeContent = []
            }
            if inExercise {
                inExercise = false
                let (text, steps) = parseExerciseContent(exerciseContent)
                blocks.append(ParsedContentBlock(
                    type: .exercise,
                    content: text,
                    title: formatExerciseTitle(exerciseType),
                    listItems: steps,
                    metadata: ["time": "10-15 minutes"]
                ))
                exerciseContent = []
                exerciseType = nil
            }
            if inTakeaways {
                inTakeaways = false
                blocks.append(ParsedContentBlock(
                    type: .keyTakeaways,
                    listItems: parseListItems(takeawaysContent)
                ))
                takeawaysContent = []
            }
            if inPremiumQuote {
                inPremiumQuote = false
                let (quote, cite) = parsePremiumQuote(premiumQuoteContent)
                blocks.append(ParsedContentBlock(
                    type: .premiumQuote,
                    content: quote,
                    metadata: ["cite": cite]
                ))
                premiumQuoteContent = []
            }
            if inAuthorSpotlight {
                inAuthorSpotlight = false
                blocks.append(ParsedContentBlock(
                    type: .authorSpotlight,
                    content: authorSpotlightContent.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                ))
                authorSpotlightContent = []
            }
            if inAlternativePerspective {
                inAlternativePerspective = false
                blocks.append(ParsedContentBlock(
                    type: .alternativePerspective,
                    content: alternativePerspectiveContent.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                ))
                alternativePerspectiveContent = []
            }
            if inResearchInsight {
                inResearchInsight = false
                blocks.append(ParsedContentBlock(
                    type: .researchInsight,
                    content: researchInsightContent.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                ))
                researchInsightContent = []
            }
            if inVisual, let tag = visualTag {
                inVisual = false
                blocks.append(contentsOf: parseVisualBlocks(tag: tag, title: visualTitle, lines: visualContent))
                visualTag = nil
                visualTitle = nil
                visualContent = []
            }
            if inConceptMap {
                inConceptMap = false
                let (central, related) = parseConceptMap(conceptMapContent)
                blocks.append(ParsedContentBlock(
                    type: .conceptMap,
                    title: conceptMapTitle,
                    listItems: related,
                    metadata: ["central": central]
                ))
                conceptMapContent = []
                conceptMapTitle = nil
            }
            if inProcessTimeline {
                inProcessTimeline = false
                blocks.append(ParsedContentBlock(
                    type: .processTimeline,
                    title: processTimelineTitle,
                    listItems: parseTimelineItems(processTimelineContent)
                ))
                processTimelineContent = []
                processTimelineTitle = nil
            }
        }

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let upper = trimmed.uppercased()

            // Check for block end markers
            if upper.hasPrefix("[/") {
                flushOpenBlocks()
                i += 1
                continue
            }

            // Check for block start markers
            if upper.hasPrefix("[QUICK_GLANCE]") {
                flushParagraph()
                flushOpenBlocks()
                inQuickGlance = true
                i += 1
                continue
            }

            if upper.hasPrefix("[INSIGHT_NOTE]") {
                flushParagraph()
                flushOpenBlocks()
                inInsightNote = true
                i += 1
                continue
            }

            if upper.hasPrefix("[ACTION_BOX") {
                flushParagraph()
                flushOpenBlocks()
                inActionBox = true
                if let colonIndex = trimmed.firstIndex(of: ":") {
                    let titleStart = trimmed.index(after: colonIndex)
                    let titleEnd = trimmed.firstIndex(of: "]") ?? trimmed.endIndex
                    actionBoxTitle = String(trimmed[titleStart..<titleEnd]).trimmingCharacters(in: .whitespaces)
                }
                i += 1
                continue
            }

            if upper.hasPrefix("[FOUNDATIONAL_NARRATIVE]") {
                flushParagraph()
                flushOpenBlocks()
                inFoundationalNarrative = true
                i += 1
                continue
            }

            if upper.hasPrefix("[EXERCISE_") {
                flushParagraph()
                flushOpenBlocks()
                inExercise = true
                // Extract exercise type
                if let start = trimmed.range(of: "[EXERCISE_")?.upperBound,
                   let end = trimmed.firstIndex(of: "]") {
                    exerciseType = String(trimmed[start..<end])
                }
                i += 1
                continue
            }

            if upper.hasPrefix("[TAKEAWAYS]") {
                flushParagraph()
                flushOpenBlocks()
                inTakeaways = true
                i += 1
                continue
            }

            if upper.hasPrefix("[PREMIUM_QUOTE]") {
                flushParagraph()
                flushOpenBlocks()
                inPremiumQuote = true
                i += 1
                continue
            }

            if upper.hasPrefix("[AUTHOR_SPOTLIGHT]") {
                flushParagraph()
                flushOpenBlocks()
                inAuthorSpotlight = true
                i += 1
                continue
            }

            if upper.hasPrefix("[ALTERNATIVE_PERSPECTIVE]") {
                flushParagraph()
                flushOpenBlocks()
                inAlternativePerspective = true
                i += 1
                continue
            }

            if upper.hasPrefix("[RESEARCH_INSIGHT]") {
                flushParagraph()
                flushOpenBlocks()
                inResearchInsight = true
                i += 1
                continue
            }

            if upper.hasPrefix("[VISUAL_") {
                flushParagraph()
                flushOpenBlocks()
                inVisual = true
                let (tag, title) = parseVisualTagAndTitle(trimmed)
                visualTag = tag
                visualTitle = title
                i += 1
                continue
            }

            if upper.hasPrefix("[CONCEPT_MAP") {
                flushParagraph()
                flushOpenBlocks()
                inConceptMap = true
                if let colonIndex = trimmed.firstIndex(of: ":") {
                    let titleStart = trimmed.index(after: colonIndex)
                    let titleEnd = trimmed.firstIndex(of: "]") ?? trimmed.endIndex
                    conceptMapTitle = String(trimmed[titleStart..<titleEnd]).trimmingCharacters(in: .whitespaces)
                }
                i += 1
                continue
            }

            if upper.hasPrefix("[PROCESS_TIMELINE") {
                flushParagraph()
                flushOpenBlocks()
                inProcessTimeline = true
                if let colonIndex = trimmed.firstIndex(of: ":") {
                    let titleStart = trimmed.index(after: colonIndex)
                    let titleEnd = trimmed.firstIndex(of: "]") ?? trimmed.endIndex
                    processTimelineTitle = String(trimmed[titleStart..<titleEnd]).trimmingCharacters(in: .whitespaces)
                }
                i += 1
                continue
            }

            if upper.hasPrefix("[PREMIUM_DIVIDER]") {
                flushParagraph()
                flushOpenBlocks()
                blocks.append(ParsedContentBlock(type: .sectionDivider))
                i += 1
                continue
            }

            // Handle PREMIUM_H1 (inline or block)
            if upper.hasPrefix("[PREMIUM_H1]") {
                flushParagraph()
                flushOpenBlocks()
                let thisSectionIndex = currentSectionIndex
                currentSectionIndex += 1
                // Check if it's inline (same line has closing tag)
                if let closeRange = trimmed.range(of: "[/PREMIUM_H1]", options: .caseInsensitive) {
                    let startIndex = trimmed.index(trimmed.startIndex, offsetBy: 12) // "[PREMIUM_H1]".count
                    let headerText = String(trimmed[startIndex..<closeRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    if headerText.uppercased().hasPrefix("PART ") {
                        blocks.append(ParsedContentBlock(type: .partHeader, content: headerText, sectionIndex: thisSectionIndex))
                    } else {
                        blocks.append(ParsedContentBlock(type: .sectionHeader, content: headerText, sectionIndex: thisSectionIndex))
                    }
                } else {
                    // Multi-line - collect until closing tag
                    var headerLines: [String] = []
                    i += 1
                    while i < lines.count {
                        let nextLine = lines[i].trimmingCharacters(in: .whitespaces)
                        if nextLine.uppercased().contains("[/PREMIUM_H1]") {
                            break
                        }
                        headerLines.append(nextLine)
                        i += 1
                    }
                    let headerText = headerLines.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                    if headerText.uppercased().hasPrefix("PART ") {
                        blocks.append(ParsedContentBlock(type: .partHeader, content: headerText, sectionIndex: thisSectionIndex))
                    } else {
                        blocks.append(ParsedContentBlock(type: .sectionHeader, content: headerText, sectionIndex: thisSectionIndex))
                    }
                }
                i += 1
                continue
            }

            // Handle PREMIUM_H2 (inline or block)
            if upper.hasPrefix("[PREMIUM_H2]") {
                flushParagraph()
                flushOpenBlocks()
                let thisSectionIndex = currentSectionIndex
                currentSectionIndex += 1
                // Check if it's inline (same line has closing tag)
                if let closeRange = trimmed.range(of: "[/PREMIUM_H2]", options: .caseInsensitive) {
                    let startIndex = trimmed.index(trimmed.startIndex, offsetBy: 12) // "[PREMIUM_H2]".count
                    let headerText = String(trimmed[startIndex..<closeRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    blocks.append(ParsedContentBlock(type: .subsectionHeader, content: headerText, sectionIndex: thisSectionIndex))
                } else {
                    // Multi-line - collect until closing tag
                    var headerLines: [String] = []
                    i += 1
                    while i < lines.count {
                        let nextLine = lines[i].trimmingCharacters(in: .whitespaces)
                        if nextLine.uppercased().contains("[/PREMIUM_H2]") {
                            break
                        }
                        headerLines.append(nextLine)
                        i += 1
                    }
                    let headerText = headerLines.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                    blocks.append(ParsedContentBlock(type: .subsectionHeader, content: headerText, sectionIndex: thisSectionIndex))
                }
                i += 1
                continue
            }

            // Handle content within blocks
            if inQuickGlance { quickGlanceContent.append(line); i += 1; continue }
            if inInsightNote { insightNoteContent.append(line); i += 1; continue }
            if inActionBox { actionBoxContent.append(line); i += 1; continue }
            if inFoundationalNarrative { foundationalNarrativeContent.append(line); i += 1; continue }
            if inExercise { exerciseContent.append(line); i += 1; continue }
            if inTakeaways { takeawaysContent.append(line); i += 1; continue }
            if inPremiumQuote { premiumQuoteContent.append(line); i += 1; continue }
            if inAuthorSpotlight { authorSpotlightContent.append(line); i += 1; continue }
            if inAlternativePerspective { alternativePerspectiveContent.append(line); i += 1; continue }
            if inResearchInsight { researchInsightContent.append(line); i += 1; continue }
            if inVisual { visualContent.append(line); i += 1; continue }
            if inConceptMap { conceptMapContent.append(line); i += 1; continue }
            if inProcessTimeline { processTimelineContent.append(line); i += 1; continue }

            // Handle headers
            if trimmed.hasPrefix("# ") {
                flushParagraph()
                let thisSectionIndex = currentSectionIndex
                currentSectionIndex += 1
                let headerText = String(trimmed.dropFirst(2))
                if headerText.uppercased().hasPrefix("PART ") {
                    blocks.append(ParsedContentBlock(type: .partHeader, content: headerText, sectionIndex: thisSectionIndex))
                } else {
                    blocks.append(ParsedContentBlock(type: .sectionHeader, content: headerText, sectionIndex: thisSectionIndex))
                }
                i += 1
                continue
            }

            if trimmed.hasPrefix("## ") {
                flushParagraph()
                let thisSectionIndex = currentSectionIndex
                currentSectionIndex += 1
                blocks.append(ParsedContentBlock(type: .subsectionHeader, content: String(trimmed.dropFirst(3)), sectionIndex: thisSectionIndex))
                i += 1
                continue
            }

            if trimmed.hasPrefix("### ") {
                flushParagraph()
                blocks.append(ParsedContentBlock(type: .minorHeader, content: String(trimmed.dropFirst(4))))
                i += 1
                continue
            }

            // Handle blockquotes
            if trimmed.hasPrefix("> ") {
                flushParagraph()
                var quoteLines: [String] = [String(trimmed.dropFirst(2))]
                i += 1
                while i < lines.count {
                    let nextLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if nextLine.hasPrefix("> ") {
                        quoteLines.append(String(nextLine.dropFirst(2)))
                        i += 1
                    } else {
                        break
                    }
                }
                let quoteText = quoteLines.joined(separator: " ")
                // Check for attribution
                var cite: String?
                if quoteText.contains("—") {
                    let parts = quoteText.components(separatedBy: "—")
                    if parts.count >= 2 {
                        cite = parts.last?.trimmingCharacters(in: .whitespaces)
                    }
                }
                blocks.append(ParsedContentBlock(
                    type: .blockquote,
                    content: quoteText,
                    metadata: cite != nil ? ["cite": cite!] : [:]
                ))
                continue
            }

            // Handle lists
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                flushParagraph()
                var listItems: [String] = [String(trimmed.dropFirst(2))]
                i += 1
                while i < lines.count {
                    let nextLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if nextLine.hasPrefix("- ") || nextLine.hasPrefix("* ") {
                        listItems.append(String(nextLine.dropFirst(2)))
                        i += 1
                    } else {
                        break
                    }
                }
                blocks.append(ParsedContentBlock(type: .bulletList, listItems: listItems))
                continue
            }

            // Handle numbered lists
            if let match = trimmed.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
                flushParagraph()
                var listItems: [String] = [String(trimmed[match.upperBound...])]
                i += 1
                while i < lines.count {
                    let nextLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if let nextMatch = nextLine.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
                        listItems.append(String(nextLine[nextMatch.upperBound...]))
                        i += 1
                    } else {
                        break
                    }
                }
                blocks.append(ParsedContentBlock(type: .numberedList, listItems: listItems))
                continue
            }

            // Handle horizontal rules and decorative dividers
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushParagraph()
                blocks.append(ParsedContentBlock(type: .sectionDivider))
                i += 1
                continue
            }

            // Handle ═══ style dividers (skip them as decorative)
            if trimmed.contains("═") && trimmed.filter({ $0 == "═" }).count > 5 {
                flushParagraph()
                // Check if this is part of a "PART X:" header block
                // Look ahead to see if there's a PART header
                var foundPartHeader = false
                var partHeaderText = ""
                var linesToSkip = 0

                for j in (i+1)..<min(i+5, lines.count) {
                    let nextLine = lines[j].trimmingCharacters(in: .whitespaces)
                    if nextLine.uppercased().hasPrefix("PART ") {
                        foundPartHeader = true
                        partHeaderText = nextLine
                        linesToSkip = j - i
                        // Skip past any trailing ═══ lines
                        for k in (j+1)..<min(j+5, lines.count) {
                            let afterLine = lines[k].trimmingCharacters(in: .whitespaces)
                            if afterLine.contains("═") && afterLine.filter({ $0 == "═" }).count > 5 {
                                linesToSkip = k - i
                            } else if !afterLine.isEmpty {
                                break
                            }
                        }
                        break
                    } else if nextLine.isEmpty || (nextLine.contains("═") && nextLine.filter({ $0 == "═" }).count > 5) {
                        continue
                    } else {
                        break
                    }
                }

                if foundPartHeader {
                    let thisSectionIndex = currentSectionIndex
                    currentSectionIndex += 1
                    blocks.append(ParsedContentBlock(type: .partHeader, content: partHeaderText, sectionIndex: thisSectionIndex))
                    i += linesToSkip + 1
                } else {
                    blocks.append(ParsedContentBlock(type: .sectionDivider))
                    i += 1
                }
                continue
            }

            // Handle tables
            if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") {
                flushParagraph()
                var tableLines: [String] = [trimmed]
                i += 1
                while i < lines.count {
                    let nextLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if nextLine.hasPrefix("|") {
                        tableLines.append(nextLine)
                        i += 1
                    } else {
                        break
                    }
                }
                blocks.append(ParsedContentBlock(type: .table, tableData: parseTable(tableLines)))
                continue
            }

            // Handle empty lines
            if trimmed.isEmpty {
                flushParagraph()
                i += 1
                continue
            }

            // Detect text-based diagrams (lines with multiple arrows)
            let arrowCount = trimmed.filter { $0 == "→" || $0 == "↓" || $0 == "←" || $0 == "↑" }.count
            if arrowCount >= 2 {
                flushParagraph()
                // Collect consecutive lines that are part of the diagram
                var diagramLines: [String] = [line]
                i += 1
                while i < lines.count {
                    let nextLine = lines[i]
                    let nextTrimmed = nextLine.trimmingCharacters(in: .whitespaces)
                    let nextArrowCount = nextTrimmed.filter { $0 == "→" || $0 == "↓" || $0 == "←" || $0 == "↑" }.count
                    // Continue if it has arrows or is a continuation of the diagram
                    if nextArrowCount >= 1 || (nextTrimmed.contains("│") || nextTrimmed.contains("─") || nextTrimmed.contains("┌") || nextTrimmed.contains("└")) {
                        diagramLines.append(nextLine)
                        i += 1
                    } else {
                        break
                    }
                }
                blocks.append(ParsedContentBlock(
                    type: .textDiagram,
                    content: diagramLines.joined(separator: "\n")
                ))
                continue
            }

            // Regular paragraph content
            currentParagraph.append(trimmed)
            i += 1
        }

        flushParagraph()
        flushOpenBlocks()

        return blocks
    }

    // MARK: - Helper Functions

    private static func parseListItems(_ lines: [String]) -> [String] {
        lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { return nil }

            // Remove list markers
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                return String(trimmed.dropFirst(2))
            }
            if let match = trimmed.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
                return String(trimmed[match.upperBound...])
            }
            return trimmed
        }
    }

    private static func parseExerciseContent(_ lines: [String]) -> (String, [String]) {
        var description: [String] = []
        var steps: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                steps.append(String(trimmed.dropFirst(2)))
            } else if let match = trimmed.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
                steps.append(String(trimmed[match.upperBound...]))
            } else if !trimmed.isEmpty {
                description.append(trimmed)
            }
        }

        return (description.joined(separator: " "), steps)
    }

    private static func formatExerciseTitle(_ type: String?) -> String {
        guard let type = type else { return "Exercise" }

        let formatted = type
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "]", with: "")
            .capitalized

        return formatted.isEmpty ? "Exercise" : formatted
    }

    private static func parsePremiumQuote(_ lines: [String]) -> (String, String) {
        let combined = lines.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)

        // Look for attribution marker
        if let dashIndex = combined.lastIndex(of: "—") {
            let quote = String(combined[..<dashIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            let cite = String(combined[combined.index(after: dashIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (quote, cite)
        }

        return (combined, "")
    }

    private static func parseVisualTagAndTitle(_ line: String) -> (String, String?) {
        var tag = ""
        var title: String?

        if let start = line.range(of: "[VISUAL_")?.upperBound,
           let end = line.firstIndex(of: "]") {
            let tagContent = String(line[start..<end])
            if let colonIndex = tagContent.firstIndex(of: ":") {
                tag = String(tagContent[..<colonIndex])
                title = String(tagContent[tagContent.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            } else {
                tag = tagContent
            }
        }

        return (tag, title)
    }

    private static func parseVisualBlocks(tag: String, title: String?, lines: [String]) -> [ParsedContentBlock] {
        var blocks: [ParsedContentBlock] = []

        // Check for URL in lines
        var url: String?
        var caption: String?
        var steps: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("http") || trimmed.hasPrefix("![") {
                // Extract URL from markdown image syntax if present
                if let match = trimmed.range(of: #"\((https?://[^)]+)\)"#, options: .regularExpression) {
                    url = String(trimmed[match]).dropFirst().dropLast().description
                } else {
                    url = trimmed
                }
            } else if trimmed.hasPrefix("Caption:") {
                caption = String(trimmed.dropFirst("Caption:".count)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                steps.append(String(trimmed.dropFirst(2)))
            } else if let match = trimmed.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
                steps.append(String(trimmed[match.upperBound...]))
            }
        }

        let tagUpper = tag.uppercased()

        if tagUpper.contains("FLOWCHART") {
            blocks.append(ParsedContentBlock(
                type: .flowchart,
                title: title,
                listItems: steps
            ))
        } else if tagUpper.contains("CONCEPT") {
            blocks.append(ParsedContentBlock(
                type: .conceptMap,
                title: title,
                listItems: steps
            ))
        } else if tagUpper.contains("TIMELINE") || tagUpper.contains("PROCESS") {
            blocks.append(ParsedContentBlock(
                type: .processTimeline,
                title: title,
                listItems: steps
            ))
        } else {
            // Generic visual
            blocks.append(ParsedContentBlock(
                type: .visual,
                title: title,
                metadata: [
                    "url": url ?? "",
                    "caption": caption ?? title ?? "",
                    "type": tag
                ]
            ))
        }

        return blocks
    }

    private static func parseConceptMap(_ lines: [String]) -> (String, [String]) {
        var central = ""
        var related: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("central:") {
                central = String(trimmed.dropFirst("central:".count)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                related.append(String(trimmed.dropFirst(2)))
            }
        }

        if central.isEmpty && !related.isEmpty {
            central = related.removeFirst()
        }

        return (central, related)
    }

    private static func parseTimelineItems(_ lines: [String]) -> [String] {
        lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { return nil }
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                return String(trimmed.dropFirst(2))
            }
            if let match = trimmed.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
                return String(trimmed[match.upperBound...])
            }
            return trimmed
        }
    }

    private static func parseTable(_ lines: [String]) -> [[String]] {
        lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Skip separator rows
            if trimmed.contains("---") || trimmed.contains("===") { return nil }

            let cells = trimmed
                .trimmingCharacters(in: CharacterSet(charactersIn: "|"))
                .components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }

            return cells.isEmpty ? nil : cells
        }
    }
}
