import Foundation

// MARK: - PDF Analysis Document
// Structured document model for PDF generation with JSON export support

struct PDFAnalysisDocument: Codable {

    // MARK: - Properties

    let book: BookMetadata
    var quickGlance: QuickGlanceSection?
    var sections: [PDFSection]
    var metadata: DocumentMetadata

    // MARK: - Nested Types

    struct BookMetadata: Codable {
        let title: String
        let author: String
        var provider: String?
        var isbn: String?
        var coverImageURL: String?
    }

    struct QuickGlanceSection: Codable {
        let coreMessage: String
        let keyPoints: [String]
        let readingTime: Int
    }

    struct PDFSection: Codable {
        var heading: String?
        var headingLevel: Int = 2  // 1 for H1 (#), 2 for H2 (##)
        var blocks: [PDFContentBlock]

        enum CodingKeys: String, CodingKey {
            case heading
            case headingLevel
            case blocks
        }

        init(heading: String? = nil, headingLevel: Int = 2, blocks: [PDFContentBlock]) {
            self.heading = heading
            self.headingLevel = headingLevel
            self.blocks = blocks
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            heading = try container.decodeIfPresent(String.self, forKey: .heading)
            headingLevel = try container.decodeIfPresent(Int.self, forKey: .headingLevel) ?? 2
            blocks = try container.decodeIfPresent([PDFContentBlock].self, forKey: .blocks) ?? []
        }
    }

    struct DocumentMetadata: Codable {
        let generatedAt: Date
        var model: String?
        var version: String = "1.0"
        var wordCount: Int?
        var estimatedReadingTime: Int?
    }

    // MARK: - Initialization

    init(
        book: BookMetadata,
        quickGlance: QuickGlanceSection? = nil,
        sections: [PDFSection] = [],
        metadata: DocumentMetadata = DocumentMetadata(generatedAt: Date())
    ) {
        self.book = book
        self.quickGlance = quickGlance
        self.sections = sections
        self.metadata = metadata
    }
}

// MARK: - Codable PDFContentBlock

extension PDFContentBlock: Codable {

    enum CodingKeys: String, CodingKey {
        case type
        case content
        case listItems
        case metadata
        case tableData
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        content = try container.decode(String.self, forKey: .content)
        listItems = try container.decodeIfPresent([String].self, forKey: .listItems)
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata)
        tableData = try container.decodeIfPresent([[String]].self, forKey: .tableData)

        switch typeString {
        case "paragraph": type = .paragraph
        case "heading1": type = .heading1
        case "heading2": type = .heading2
        case "heading3": type = .heading3
        case "heading4": type = .heading4
        case "blockquote": type = .blockquote
        case "insightNote": type = .insightNote
        case "actionBox": type = .actionBox
        case "keyTakeaways": type = .keyTakeaways
        case "foundationalNarrative": type = .foundationalNarrative
        case "exercise": type = .exercise
        case "flowchart": type = .flowchart
        case "quickGlance": type = .quickGlance
        case "bulletList": type = .bulletList
        case "numberedList": type = .numberedList
        case "divider": type = .divider
        case "table": type = .table
        case "visual": type = .visual
        case "premiumQuote": type = .premiumQuote
        case "authorSpotlight": type = .authorSpotlight
        case "premiumDivider": type = .premiumDivider
        case "premiumH1": type = .premiumH1
        case "premiumH2": type = .premiumH2
        case "alternativePerspective": type = .alternativePerspective
        case "researchInsight": type = .researchInsight
        case "conceptMap": type = .conceptMap
        case "processTimeline": type = .processTimeline
        case "example": type = .example
        case "exerciseReflection": type = .exerciseReflection
        default: type = .paragraph
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        let typeString: String
        switch type {
        case .paragraph: typeString = "paragraph"
        case .heading1: typeString = "heading1"
        case .heading2: typeString = "heading2"
        case .heading3: typeString = "heading3"
        case .heading4: typeString = "heading4"
        case .blockquote: typeString = "blockquote"
        case .insightNote: typeString = "insightNote"
        case .actionBox: typeString = "actionBox"
        case .keyTakeaways: typeString = "keyTakeaways"
        case .foundationalNarrative: typeString = "foundationalNarrative"
        case .exercise: typeString = "exercise"
        case .flowchart: typeString = "flowchart"
        case .quickGlance: typeString = "quickGlance"
        case .bulletList: typeString = "bulletList"
        case .numberedList: typeString = "numberedList"
        case .divider: typeString = "divider"
        case .table: typeString = "table"
        case .visual: typeString = "visual"
        // Premium block types
        case .premiumQuote: typeString = "premiumQuote"
        case .authorSpotlight: typeString = "authorSpotlight"
        case .premiumDivider: typeString = "premiumDivider"
        case .premiumH1: typeString = "premiumH1"
        case .premiumH2: typeString = "premiumH2"
        case .alternativePerspective: typeString = "alternativePerspective"
        case .researchInsight: typeString = "researchInsight"
        case .conceptMap: typeString = "conceptMap"
        case .processTimeline: typeString = "processTimeline"
        case .example: typeString = "example"
        case .exerciseReflection: typeString = "exerciseReflection"
        }

        try container.encode(typeString, forKey: .type)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(listItems, forKey: .listItems)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encodeIfPresent(tableData, forKey: .tableData)
    }
}

// MARK: - Parsing from Markdown

extension PDFAnalysisDocument {

    /// Parse markdown content into a structured PDF document
    static func parse(from content: String, title: String, author: String) -> PDFAnalysisDocument {
        var content = content

        // Authors: the AI emits a machine-readable byline (e.g.
        // "[[AUTHORS: Mark Changizi and Tim Barber]]") as the single source of
        // truth for the cover. It reflects the full authorship the model found
        // while reading the whole book, overriding the weaker mechanical
        // extraction (which often catches only the first author). Strip the tag
        // so it never renders as body text; fall back to the passed-in author.
        var resolvedAuthor = author
        if let tagRange = content.range(of: #"\[\[AUTHORS:[^\]]*\]\]"#, options: .regularExpression) {
            let value = content[tagRange]
                .replacingOccurrences(of: "[[AUTHORS:", with: "")
                .replacingOccurrences(of: "]]", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let lowered = value.lowercased()
            if !value.isEmpty, lowered != "unknown", lowered != "unknown author" {
                resolvedAuthor = value
            }
            content.removeSubrange(tagRange)
            content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var quickGlance: QuickGlanceSection?
        var sections: [PDFSection] = []
        var currentSection: PDFSection?
        var currentBlocks: [PDFContentBlock] = []

        let lines = content.components(separatedBy: "\n")
        var i = 0

        // Block parsing state
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
        var inVisual = false
        var visualTag: String?
        var visualTitle: String?
        var visualContent: [String] = []
        var inPremiumQuote = false
        var premiumQuoteContent: [String] = []
        var inAuthorSpotlight = false
        var authorSpotlightContent: [String] = []
        var inPremiumH1 = false
        var premiumH1Content: [String] = []
        var inPremiumH2 = false
        var premiumH2Content: [String] = []
        var inAlternativePerspective = false
        var alternativePerspectiveContent: [String] = []
        var inResearchInsight = false
        var researchInsightContent: [String] = []
        var inConceptMap = false
        var conceptMapContent: [String] = []
        var conceptMapTitle: String?
        var inProcessTimeline = false
        var processTimelineContent: [String] = []
        var processTimelineTitle: String?

        func isNewBlockStart(_ line: String) -> Bool {
            if line.hasPrefix("[/") {
                return false
            }
            if line.hasPrefix("#") {
                return true
            }
            let upper = line.uppercased()
            return upper.hasPrefix("[QUICK_GLANCE]") ||
                upper.hasPrefix("[INSIGHT_NOTE]") ||
                upper.hasPrefix("[ACTION_BOX") ||
                upper.hasPrefix("[FOUNDATIONAL_NARRATIVE]") ||
                upper.hasPrefix("[EXERCISE_") ||
                upper.hasPrefix("[TAKEAWAYS]") ||
                upper.hasPrefix("[VISUAL_") ||
                upper.hasPrefix("[PREMIUM_QUOTE]") ||
                upper.hasPrefix("[AUTHOR_SPOTLIGHT]") ||
                upper.hasPrefix("[PREMIUM_H1]") ||
                upper.hasPrefix("[PREMIUM_H2]") ||
                upper.hasPrefix("[ALTERNATIVE_PERSPECTIVE]") ||
                upper.hasPrefix("[RESEARCH_INSIGHT]") ||
                upper.hasPrefix("[CONCEPT_MAP") ||
                upper.hasPrefix("[PROCESS_TIMELINE") ||
                upper.hasPrefix("[PREMIUM_DIVIDER]")
        }

        func inlineTagContent(_ line: String, tag: String) -> (content: String, title: String?)? {
            let openPrefix = "[\(tag)"
            let closeTag = "[/\(tag)]"
            guard let openRange = line.range(of: openPrefix),
                  let closeRange = line.range(of: closeTag) else {
                return nil
            }
            guard let openEnd = line[openRange.lowerBound...].firstIndex(of: "]") else {
                return nil
            }
            let header = line[line.index(after: openRange.lowerBound)..<openEnd]
            var title: String?
            if let colonIndex = header.firstIndex(of: ":") {
                title = String(header[header.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            }
            let contentRange = line.index(after: openEnd)..<closeRange.lowerBound
            let content = String(line[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (content: content, title: title)
        }

        func inlineExerciseContent(_ line: String) -> (type: String?, content: String)? {
            guard let openStart = line.range(of: "[EXERCISE_"),
                  let openEnd = line[openStart.lowerBound...].firstIndex(of: "]"),
                  let closeRange = line.range(of: "[/EXERCISE_") else {
                return nil
            }
            let typeStart = line.index(openStart.lowerBound, offsetBy: "[EXERCISE_".count)
            let type = String(line[typeStart..<openEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
            let contentRange = line.index(after: openEnd)..<closeRange.lowerBound
            let content = String(line[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (type: type.isEmpty ? nil : type, content: content)
        }

        func flushOpenBlock() {
            if inQuickGlance {
                inQuickGlance = false
                let totalWordCount = content.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
                quickGlance = parseQuickGlanceSection(from: quickGlanceContent, totalWordCount: totalWordCount)
                quickGlanceContent = []
            }
            if inInsightNote {
                inInsightNote = false
                let noteContent = insightNoteContent
                    .map { stripMarkdownFromLine($0) }
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                currentBlocks.append(PDFContentBlock(
                    type: .insightNote,
                    content: noteContent,
                    metadata: ["title": "Insight Atlas Note"]
                ))
                insightNoteContent = []
            }
            if inActionBox {
                inActionBox = false
                let steps = parseListItems(from: actionBoxContent)
                currentBlocks.append(PDFContentBlock(
                    type: .actionBox,
                    content: "",
                    listItems: steps,
                    metadata: ["title": actionBoxTitle ?? "Apply It"]
                ))
                actionBoxContent = []
                actionBoxTitle = nil
            }
            if inFoundationalNarrative {
                inFoundationalNarrative = false
                let narrativeContent = foundationalNarrativeContent
                    .map { stripMarkdownFromLine($0) }
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                currentBlocks.append(PDFContentBlock(
                    type: .foundationalNarrative,
                    content: narrativeContent,
                    metadata: ["title": "The Story Behind the Ideas"]
                ))
                foundationalNarrativeContent = []
            }
            if inExercise {
                inExercise = false
                let (exerciseText, steps) = parseExerciseContent(from: exerciseContent)
                currentBlocks.append(PDFContentBlock(
                    type: .exercise,
                    content: exerciseText,
                    listItems: steps,
                    metadata: ["title": formatExerciseTitle(exerciseType), "time": "10-15 minutes"]
                ))
                exerciseContent = []
                exerciseType = nil
            }
            if inTakeaways {
                inTakeaways = false
                let items = parseListItems(from: takeawaysContent)
                if items.isEmpty {
                    let fallbackText = takeawaysContent
                        .map { stripMarkdownFromLine($0) }
                        .joined(separator: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !fallbackText.isEmpty {
                        currentBlocks.append(PDFContentBlock(
                            type: .paragraph,
                            content: fallbackText
                        ))
                    }
                } else {
                    currentBlocks.append(PDFContentBlock(
                        type: .keyTakeaways,
                        content: "",
                        listItems: items
                    ))
                }
                takeawaysContent = []
            }
            if inVisual {
                inVisual = false
                if let tag = visualTag {
                    let blocks = parseVisualBlocks(tag: tag, title: visualTitle, lines: visualContent)
                    currentBlocks.append(contentsOf: blocks)
                }
                visualTag = nil
                visualTitle = nil
                visualContent = []
            }
            if inPremiumQuote {
                inPremiumQuote = false
                let parsedQuote = parsePremiumQuote(from: premiumQuoteContent)
                currentBlocks.append(PDFContentBlock(
                    type: .premiumQuote,
                    content: parsedQuote.text,
                    metadata: parsedQuote.cite.isEmpty ? nil : ["cite": parsedQuote.cite]
                ))
                premiumQuoteContent = []
            }
            if inAuthorSpotlight {
                inAuthorSpotlight = false
                let contentText = authorSpotlightContent
                    .map { stripMarkdownFromLine($0) }
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                currentBlocks.append(PDFContentBlock(
                    type: .authorSpotlight,
                    content: contentText
                ))
                authorSpotlightContent = []
            }
            if inPremiumH1 {
                inPremiumH1 = false
                let titleText = premiumH1Content
                    .map { stripMarkdownFromLine($0) }
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                if !titleText.isEmpty {
                    currentBlocks.append(PDFContentBlock(type: .premiumH1, content: titleText))
                }
                premiumH1Content = []
            }
            if inPremiumH2 {
                inPremiumH2 = false
                let titleText = premiumH2Content
                    .map { stripMarkdownFromLine($0) }
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                if !titleText.isEmpty {
                    currentBlocks.append(PDFContentBlock(type: .premiumH2, content: titleText))
                }
                premiumH2Content = []
            }
            if inAlternativePerspective {
                inAlternativePerspective = false
                let contentText = alternativePerspectiveContent
                    .map { stripMarkdownFromLine($0) }
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                currentBlocks.append(PDFContentBlock(
                    type: .alternativePerspective,
                    content: contentText
                ))
                alternativePerspectiveContent = []
            }
            if inResearchInsight {
                inResearchInsight = false
                let contentText = researchInsightContent
                    .map { stripMarkdownFromLine($0) }
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                currentBlocks.append(PDFContentBlock(
                    type: .researchInsight,
                    content: contentText
                ))
                researchInsightContent = []
            }
            if inConceptMap {
                inConceptMap = false
                let parsedMap = parseConceptMap(from: conceptMapContent)
                var metadata: [String: String] = ["title": conceptMapTitle ?? "Concept Map"]
                if !parsedMap.central.isEmpty {
                    metadata["central"] = parsedMap.central
                }
                currentBlocks.append(PDFContentBlock(
                    type: .conceptMap,
                    content: "",
                    listItems: parsedMap.related,
                    metadata: metadata
                ))
                conceptMapContent = []
                conceptMapTitle = nil
            }
            if inProcessTimeline {
                inProcessTimeline = false
                let items = parseProcessTimelineItems(from: processTimelineContent)
                currentBlocks.append(PDFContentBlock(
                    type: .processTimeline,
                    content: "",
                    listItems: items,
                    metadata: ["title": processTimelineTitle ?? "Process Timeline"]
                ))
                processTimelineContent = []
                processTimelineTitle = nil
            }
        }

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)

            if let inline = inlineTagContent(line, tag: "PREMIUM_H1") {
                currentBlocks.append(PDFContentBlock(type: .premiumH1, content: stripMarkdownFromLine(inline.content)))
                i += 1
                continue
            }
            if let inline = inlineTagContent(line, tag: "PREMIUM_H2") {
                currentBlocks.append(PDFContentBlock(type: .premiumH2, content: stripMarkdownFromLine(inline.content)))
                i += 1
                continue
            }
            if let inline = inlineTagContent(line, tag: "INSIGHT_NOTE") {
                let noteContent = inline.content
                    .split(separator: "\n")
                    .map { stripMarkdownFromLine(String($0)) }
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                currentBlocks.append(PDFContentBlock(
                    type: .insightNote,
                    content: noteContent,
                    metadata: ["title": "Insight Atlas Note"]
                ))
                i += 1
                continue
            }
            if let inline = inlineTagContent(line, tag: "ACTION_BOX") {
                let steps = parseListItems(from: inline.content.components(separatedBy: "\n"))
                currentBlocks.append(PDFContentBlock(
                    type: .actionBox,
                    content: "",
                    listItems: steps,
                    metadata: ["title": inline.title ?? "Apply It"]
                ))
                i += 1
                continue
            }
            if let inline = inlineTagContent(line, tag: "TAKEAWAYS") {
                let items = parseListItems(from: inline.content.components(separatedBy: "\n"))
                if items.isEmpty {
                    currentBlocks.append(PDFContentBlock(type: .paragraph, content: stripMarkdownFromLine(inline.content)))
                } else {
                    currentBlocks.append(PDFContentBlock(type: .keyTakeaways, content: "", listItems: items))
                }
                i += 1
                continue
            }
            if let inline = inlineTagContent(line, tag: "PREMIUM_QUOTE") {
                let parsed = parsePremiumQuote(from: inline.content.components(separatedBy: "\n"))
                currentBlocks.append(PDFContentBlock(
                    type: .premiumQuote,
                    content: parsed.text,
                    metadata: parsed.cite.isEmpty ? nil : ["cite": parsed.cite]
                ))
                i += 1
                continue
            }
            if let inline = inlineTagContent(line, tag: "AUTHOR_SPOTLIGHT") {
                currentBlocks.append(PDFContentBlock(
                    type: .authorSpotlight,
                    content: stripMarkdownFromLine(inline.content)
                ))
                i += 1
                continue
            }
            if let inline = inlineTagContent(line, tag: "ALTERNATIVE_PERSPECTIVE") {
                currentBlocks.append(PDFContentBlock(
                    type: .alternativePerspective,
                    content: stripMarkdownFromLine(inline.content)
                ))
                i += 1
                continue
            }
            if let inline = inlineTagContent(line, tag: "RESEARCH_INSIGHT") {
                currentBlocks.append(PDFContentBlock(
                    type: .researchInsight,
                    content: stripMarkdownFromLine(inline.content)
                ))
                i += 1
                continue
            }
            if let inline = inlineTagContent(line, tag: "FOUNDATIONAL_NARRATIVE") {
                currentBlocks.append(PDFContentBlock(
                    type: .foundationalNarrative,
                    content: stripMarkdownFromLine(inline.content),
                    metadata: ["title": "The Story Behind the Ideas"]
                ))
                i += 1
                continue
            }
            if let inline = inlineExerciseContent(line) {
                let (exerciseText, steps) = parseExerciseContent(from: inline.content.components(separatedBy: "\n"))
                currentBlocks.append(PDFContentBlock(
                    type: .exercise,
                    content: exerciseText,
                    listItems: steps,
                    metadata: ["title": formatExerciseTitle(inline.type), "time": "10-15 minutes"]
                ))
                i += 1
                continue
            }

            if isNewBlockStart(line) && (
                inQuickGlance || inInsightNote || inActionBox || inFoundationalNarrative || inExercise ||
                inTakeaways || inVisual || inPremiumQuote || inAuthorSpotlight || inPremiumH1 || inPremiumH2 ||
                inAlternativePerspective || inResearchInsight || inConceptMap || inProcessTimeline
            ) {
                flushOpenBlock()
            }

            if inTakeaways && isNewBlockStart(line) {
                inTakeaways = false
                let items = parseListItems(from: takeawaysContent)
                if items.isEmpty {
                    let fallbackText = takeawaysContent
                        .map { stripMarkdownFromLine($0) }
                        .joined(separator: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !fallbackText.isEmpty {
                        currentBlocks.append(PDFContentBlock(
                            type: .paragraph,
                            content: fallbackText
                        ))
                    }
                } else {
                    currentBlocks.append(PDFContentBlock(
                        type: .keyTakeaways,
                        content: "",
                        listItems: items
                    ))
                }
                takeawaysContent = []
            }

            // Quick Glance block
            if line.hasPrefix("[QUICK_GLANCE]") {
                inQuickGlance = true
                quickGlanceContent = []
                i += 1
                continue
            }
            if line.hasPrefix("[/QUICK_GLANCE]") {
                inQuickGlance = false
                let totalWordCount = content.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
                quickGlance = parseQuickGlanceSection(from: quickGlanceContent, totalWordCount: totalWordCount)
                i += 1
                continue
            }
            if inQuickGlance {
                quickGlanceContent.append(line)
                i += 1
                continue
            }

            // Insight Note block
            if line.hasPrefix("[INSIGHT_NOTE]") {
                inInsightNote = true
                insightNoteContent = []
                i += 1
                continue
            }
            if line.hasPrefix("[/INSIGHT_NOTE]") {
                inInsightNote = false
                let noteContent = insightNoteContent
                    .map { stripMarkdownFromLine($0) }
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                currentBlocks.append(PDFContentBlock(
                    type: .insightNote,
                    content: noteContent,
                    metadata: ["title": "Insight Atlas Note"]
                ))
                i += 1
                continue
            }
            if inInsightNote {
                insightNoteContent.append(line)
                i += 1
                continue
            }

            // Action Box block
            if line.hasPrefix("[ACTION_BOX") {
                inActionBox = true
                actionBoxContent = []
                // Extract title if present
                if let colonIndex = line.firstIndex(of: ":") {
                    let afterColon = line[line.index(after: colonIndex)...]
                    actionBoxTitle = afterColon.replacingOccurrences(of: "]", with: "").trimmingCharacters(in: .whitespaces)
                } else {
                    actionBoxTitle = "Apply It"
                }
                i += 1
                continue
            }
            if line.hasPrefix("[/ACTION_BOX]") {
                inActionBox = false
                let steps = parseListItems(from: actionBoxContent)
                currentBlocks.append(PDFContentBlock(
                    type: .actionBox,
                    content: "",
                    listItems: steps,
                    metadata: ["title": actionBoxTitle ?? "Apply It"]
                ))
                i += 1
                continue
            }
            if inActionBox {
                actionBoxContent.append(line)
                i += 1
                continue
            }

            // Foundational Narrative block
            if line.hasPrefix("[FOUNDATIONAL_NARRATIVE]") {
                inFoundationalNarrative = true
                foundationalNarrativeContent = []
                i += 1
                continue
            }
            if line.hasPrefix("[/FOUNDATIONAL_NARRATIVE]") {
                inFoundationalNarrative = false
                let narrativeContent = foundationalNarrativeContent
                    .map { stripMarkdownFromLine($0) }
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                currentBlocks.append(PDFContentBlock(
                    type: .foundationalNarrative,
                    content: narrativeContent,
                    metadata: ["title": "The Story Behind the Ideas"]
                ))
                i += 1
                continue
            }
            if inFoundationalNarrative {
                foundationalNarrativeContent.append(line)
                i += 1
                continue
            }

            // Exercise block
            if line.hasPrefix("[EXERCISE_") {
                inExercise = true
                exerciseContent = []
                // Extract exercise type
                if let underscoreIndex = line.firstIndex(of: "_"),
                   let bracketIndex = line.firstIndex(of: "]") {
                    let typeStart = line.index(after: underscoreIndex)
                    exerciseType = String(line[typeStart..<bracketIndex])
                }
                i += 1
                continue
            }
            if line.hasPrefix("[/EXERCISE_") {
                inExercise = false
                let (exerciseText, steps) = parseExerciseContent(from: exerciseContent)
                currentBlocks.append(PDFContentBlock(
                    type: .exercise,
                    content: exerciseText,
                    listItems: steps,
                    metadata: ["title": formatExerciseTitle(exerciseType), "time": "10-15 minutes"]
                ))
                i += 1
                continue
            }
            if inExercise {
                exerciseContent.append(line)
                i += 1
                continue
            }

            // Takeaways block
            if line.hasPrefix("[TAKEAWAYS]") {
                inTakeaways = true
                takeawaysContent = []
                i += 1
                continue
            }
            if line.hasPrefix("[/TAKEAWAYS]") {
                inTakeaways = false
                let items = parseListItems(from: takeawaysContent)
                if items.isEmpty {
                    let fallbackText = takeawaysContent
                        .map { stripMarkdownFromLine($0) }
                        .joined(separator: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !fallbackText.isEmpty {
                        currentBlocks.append(PDFContentBlock(
                            type: .paragraph,
                            content: fallbackText
                        ))
                    }
                } else {
                    currentBlocks.append(PDFContentBlock(
                        type: .keyTakeaways,
                        content: "",
                        listItems: items
                    ))
                }
                i += 1
                continue
            }
            if inTakeaways {
                takeawaysContent.append(line)
                i += 1
                continue
            }

            // Visual blocks (all VISUAL_* tags)
            if line.hasPrefix("[VISUAL_") {
                inVisual = true
                visualContent = []
                let parsed = parseVisualTagAndTitle(from: line)
                visualTag = parsed.tag
                visualTitle = parsed.title
                i += 1
                continue
            }
            if line.hasPrefix("[/VISUAL_") {
                inVisual = false
                if let tag = visualTag {
                    let blocks = parseVisualBlocks(tag: tag, title: visualTitle, lines: visualContent)
                    currentBlocks.append(contentsOf: blocks)
                }
                visualTag = nil
                visualTitle = nil
                visualContent = []
                i += 1
                continue
            }
            if inVisual {
                visualContent.append(line)
                i += 1
                continue
            }

            // Premium Quote block
            if line.hasPrefix("[PREMIUM_QUOTE]") {
                inPremiumQuote = true
                premiumQuoteContent = []
                i += 1
                continue
            }
            if line.hasPrefix("[/PREMIUM_QUOTE]") {
                inPremiumQuote = false
                let parsedQuote = parsePremiumQuote(from: premiumQuoteContent)
                currentBlocks.append(PDFContentBlock(
                    type: .premiumQuote,
                    content: parsedQuote.text,
                    metadata: parsedQuote.cite.isEmpty ? nil : ["cite": parsedQuote.cite]
                ))
                i += 1
                continue
            }
            if inPremiumQuote {
                premiumQuoteContent.append(line)
                i += 1
                continue
            }

            // Author Spotlight block
            if line.hasPrefix("[AUTHOR_SPOTLIGHT]") {
                inAuthorSpotlight = true
                authorSpotlightContent = []
                i += 1
                continue
            }
            if line.hasPrefix("[/AUTHOR_SPOTLIGHT]") {
                inAuthorSpotlight = false
                let contentText = authorSpotlightContent
                    .map { stripMarkdownFromLine($0) }
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                currentBlocks.append(PDFContentBlock(
                    type: .authorSpotlight,
                    content: contentText
                ))
                i += 1
                continue
            }
            if inAuthorSpotlight {
                authorSpotlightContent.append(line)
                i += 1
                continue
            }

            // Premium Divider (single marker)
            if line.hasPrefix("[PREMIUM_DIVIDER]") {
                currentBlocks.append(PDFContentBlock(type: .premiumDivider, content: ""))
                i += 1
                continue
            }
            if line.hasPrefix("[/PREMIUM_DIVIDER]") {
                i += 1
                continue
            }

            // Premium H1 block
            if line.hasPrefix("[PREMIUM_H1]") {
                inPremiumH1 = true
                premiumH1Content = []
                i += 1
                continue
            }
            if line.hasPrefix("[/PREMIUM_H1]") {
                inPremiumH1 = false
                let titleText = premiumH1Content
                    .map { stripMarkdownFromLine($0) }
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                if !titleText.isEmpty {
                    currentBlocks.append(PDFContentBlock(type: .premiumH1, content: titleText))
                }
                i += 1
                continue
            }
            if inPremiumH1 {
                premiumH1Content.append(line)
                i += 1
                continue
            }

            // Premium H2 block
            if line.hasPrefix("[PREMIUM_H2]") {
                inPremiumH2 = true
                premiumH2Content = []
                i += 1
                continue
            }
            if line.hasPrefix("[/PREMIUM_H2]") {
                inPremiumH2 = false
                let titleText = premiumH2Content
                    .map { stripMarkdownFromLine($0) }
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                if !titleText.isEmpty {
                    currentBlocks.append(PDFContentBlock(type: .premiumH2, content: titleText))
                }
                i += 1
                continue
            }
            if inPremiumH2 {
                premiumH2Content.append(line)
                i += 1
                continue
            }

            // Alternative Perspective block
            if line.hasPrefix("[ALTERNATIVE_PERSPECTIVE]") {
                inAlternativePerspective = true
                alternativePerspectiveContent = []
                i += 1
                continue
            }
            if line.hasPrefix("[/ALTERNATIVE_PERSPECTIVE]") {
                inAlternativePerspective = false
                let contentText = alternativePerspectiveContent
                    .map { stripMarkdownFromLine($0) }
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                currentBlocks.append(PDFContentBlock(
                    type: .alternativePerspective,
                    content: contentText
                ))
                i += 1
                continue
            }
            if inAlternativePerspective {
                alternativePerspectiveContent.append(line)
                i += 1
                continue
            }

            // Research Insight block
            if line.hasPrefix("[RESEARCH_INSIGHT]") {
                inResearchInsight = true
                researchInsightContent = []
                i += 1
                continue
            }
            if line.hasPrefix("[/RESEARCH_INSIGHT]") {
                inResearchInsight = false
                let contentText = researchInsightContent
                    .map { stripMarkdownFromLine($0) }
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                currentBlocks.append(PDFContentBlock(
                    type: .researchInsight,
                    content: contentText
                ))
                i += 1
                continue
            }
            if inResearchInsight {
                researchInsightContent.append(line)
                i += 1
                continue
            }

            // Concept Map block
            if line.hasPrefix("[CONCEPT_MAP") {
                inConceptMap = true
                conceptMapContent = []
                if let colonIndex = line.firstIndex(of: ":") {
                    let afterColon = line[line.index(after: colonIndex)...]
                    conceptMapTitle = afterColon.replacingOccurrences(of: "]", with: "").trimmingCharacters(in: .whitespaces)
                } else {
                    conceptMapTitle = "Concept Map"
                }
                i += 1
                continue
            }
            if line.hasPrefix("[/CONCEPT_MAP]") {
                inConceptMap = false
                let parsedMap = parseConceptMap(from: conceptMapContent)
                var metadata: [String: String] = ["title": conceptMapTitle ?? "Concept Map"]
                if !parsedMap.central.isEmpty {
                    metadata["central"] = parsedMap.central
                }
                currentBlocks.append(PDFContentBlock(
                    type: .conceptMap,
                    content: "",
                    listItems: parsedMap.related,
                    metadata: metadata
                ))
                i += 1
                continue
            }
            if inConceptMap {
                conceptMapContent.append(line)
                i += 1
                continue
            }

            // Process Timeline block
            if line.hasPrefix("[PROCESS_TIMELINE") {
                inProcessTimeline = true
                processTimelineContent = []
                if let colonIndex = line.firstIndex(of: ":") {
                    let afterColon = line[line.index(after: colonIndex)...]
                    processTimelineTitle = afterColon.replacingOccurrences(of: "]", with: "").trimmingCharacters(in: .whitespaces)
                } else {
                    processTimelineTitle = "Process Timeline"
                }
                i += 1
                continue
            }
            if line.hasPrefix("[/PROCESS_TIMELINE]") {
                inProcessTimeline = false
                let items = parseProcessTimelineItems(from: processTimelineContent)
                currentBlocks.append(PDFContentBlock(
                    type: .processTimeline,
                    content: "",
                    listItems: items,
                    metadata: ["title": processTimelineTitle ?? "Process Timeline"]
                ))
                i += 1
                continue
            }
            if inProcessTimeline {
                processTimelineContent.append(line)
                i += 1
                continue
            }

            // Skip other block markers
            if line.hasPrefix("[") && line.contains("]") && !line.contains("](") {
                i += 1
                continue
            }

            // Top-level headers (# heading) - strip the # and use as section heading with H1 level
            if line.hasPrefix("# ") && !line.hasPrefix("## ") {
                // Save current section if exists
                if let current = currentSection {
                    var updatedSection = current
                    updatedSection.blocks = currentBlocks
                    sections.append(updatedSection)
                }

                let heading = stripMarkdownFromLine(String(line.dropFirst(2)))
                currentSection = PDFSection(heading: heading, headingLevel: 1, blocks: [])
                currentBlocks = []
                i += 1
                continue
            }

            // Section headers (## heading) - H2 level
            if line.hasPrefix("## ") {
                // Save current section if exists
                if let current = currentSection {
                    var updatedSection = current
                    updatedSection.blocks = currentBlocks
                    sections.append(updatedSection)
                }

                let heading = stripMarkdownFromLine(String(line.dropFirst(3)))
                currentSection = PDFSection(heading: heading, headingLevel: 2, blocks: [])
                currentBlocks = []
                i += 1
                continue
            }

            // Subheadings
            if line.hasPrefix("### ") {
                currentBlocks.append(PDFContentBlock(
                    type: .heading3,
                    content: stripMarkdownFromLine(String(line.dropFirst(4)))
                ))
                i += 1
                continue
            }

            if line.hasPrefix("#### ") {
                currentBlocks.append(PDFContentBlock(
                    type: .heading4,
                    content: stripMarkdownFromLine(String(line.dropFirst(5)))
                ))
                i += 1
                continue
            }

            // Blockquote
            if line.hasPrefix(">") {
                var quoteLines: [String] = []
                while i < lines.count && lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                    let quoteLine = String(lines[i].trimmingCharacters(in: .whitespaces).dropFirst()).trimmingCharacters(in: .whitespaces)
                    quoteLines.append(stripMarkdownFromLine(quoteLine))
                    i += 1
                }
                currentBlocks.append(PDFContentBlock(
                    type: .blockquote,
                    content: quoteLines.joined(separator: " ")
                ))
                continue
            }

            // Bullet list
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                var listItems: [String] = []
                while i < lines.count {
                    let listLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if listLine.hasPrefix("- ") || listLine.hasPrefix("* ") {
                        listItems.append(stripMarkdownFromLine(String(listLine.dropFirst(2))))
                        i += 1
                    } else if listLine.isEmpty {
                        i += 1
                        break
                    } else {
                        break
                    }
                }
                if !listItems.isEmpty {
                    currentBlocks.append(PDFContentBlock(
                        type: .bulletList,
                        content: "",
                        listItems: listItems
                    ))
                }
                continue
            }

            // Numbered list
            if line.range(of: "^\\d+\\.\\s+", options: .regularExpression) != nil {
                var listItems: [String] = []
                while i < lines.count {
                    let listLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if listLine.range(of: "^\\d+\\.\\s+", options: .regularExpression) != nil {
                        let text = listLine.replacingOccurrences(of: "^\\d+\\.\\s+", with: "", options: .regularExpression)
                        listItems.append(stripMarkdownFromLine(text))
                        i += 1
                    } else if listLine.isEmpty {
                        i += 1
                        break
                    } else {
                        break
                    }
                }
                if !listItems.isEmpty {
                    currentBlocks.append(PDFContentBlock(
                        type: .numberedList,
                        content: "",
                        listItems: listItems
                    ))
                }
                continue
            }

            // Divider (including heavy rule lines like "═══" / "━━━")
            if line == "---" || line == "***" || line == "___" || isHorizontalRule(line) {
                currentBlocks.append(PDFContentBlock(type: .divider, content: ""))
                i += 1
                continue
            }

            // Markdown table parsing
            if line.hasPrefix("|") && line.hasSuffix("|") {
                var tableRows: [[String]] = []

                // Parse table rows
                while i < lines.count {
                    let tableLine = lines[i].trimmingCharacters(in: .whitespaces)

                    // Check if still a table row
                    if tableLine.hasPrefix("|") && tableLine.hasSuffix("|") {
                        // Skip separator rows (|---|---|)
                        if tableLine.contains("---") || isTableSeparator(tableLine) {
                            i += 1
                            continue
                        }

                        // Parse cells
                        let cells = tableLine
                            .dropFirst()
                            .dropLast()
                            .components(separatedBy: "|")
                            .map { stripMarkdownFromLine($0.trimmingCharacters(in: .whitespaces)) }
                            .filter { !$0.isEmpty || tableRows.isEmpty } // Keep structure for first row

                        if !cells.isEmpty {
                            tableRows.append(cells)
                        }
                        i += 1
                    } else {
                        break
                    }
                }

                if !tableRows.isEmpty {
                    currentBlocks.append(PDFContentBlock(
                        type: .table,
                        content: "",
                        tableData: tableRows
                    ))
                }
                continue
            }

            if let implicit = parseImplicitVisualBlocks(from: lines, startIndex: i) {
                currentBlocks.append(contentsOf: implicit.blocks)
                i += implicit.consumed
                continue
            }

            // Regular paragraph - strip any remaining markdown syntax
            if !line.isEmpty && !line.hasPrefix("|") && !line.contains("┌") && !line.contains("│") && !line.contains("└") && !line.contains("↓") {
                let cleanedLine = stripMarkdownFromLine(line)
                if !cleanedLine.isEmpty {
                    currentBlocks.append(PDFContentBlock(
                        type: .paragraph,
                        content: cleanedLine
                    ))
                }
            }

            i += 1
        }

        flushOpenBlock()

        // Save final section
        if let current = currentSection {
            var updatedSection = current
            updatedSection.blocks = currentBlocks
            sections.append(updatedSection)
        } else if !currentBlocks.isEmpty {
            sections.append(PDFSection(heading: nil, blocks: currentBlocks))
        }

        // Calculate metadata
        let wordCount = content.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        let readingTime = max(1, wordCount / 250)

        return PDFAnalysisDocument(
            book: BookMetadata(title: title, author: resolvedAuthor),
            quickGlance: quickGlance,
            sections: sections,
            metadata: DocumentMetadata(
                generatedAt: Date(),
                wordCount: wordCount,
                estimatedReadingTime: readingTime
            )
        )
    }

    // MARK: - Private Parsing Helpers

    private static func parseQuickGlanceSection(from lines: [String], totalWordCount: Int) -> QuickGlanceSection {
        var coreMessage = ""
        var keyPoints: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") {
                continue
            }
            let cleaned = stripInlineMarkdown(trimmed)

            let lower = cleaned.lowercased()
            if lower.contains("core message") ||
               lower.contains("core thesis") ||
               lower.contains("one-sentence premise") {
                if let colonIndex = cleaned.firstIndex(of: ":") {
                    coreMessage = String(cleaned[cleaned.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                }
            } else if cleaned.hasPrefix("- ") || cleaned.hasPrefix("* ") || cleaned.hasPrefix("• ") {
                let cleanPoint = String(cleaned.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !cleanPoint.isEmpty {
                    keyPoints.append(cleanPoint)
                }
            } else if cleaned.hasPrefix("-") || cleaned.hasPrefix("*") || cleaned.hasPrefix("•") {
                let cleanPoint = String(cleaned.dropFirst(1)).trimmingCharacters(in: .whitespaces)
                if !cleanPoint.isEmpty {
                    keyPoints.append(cleanPoint)
                }
            } else if let range = cleaned.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                let cleanPoint = String(cleaned[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !cleanPoint.isEmpty {
                    keyPoints.append(cleanPoint)
                }
            }
        }

        let readingTime = max(1, totalWordCount / 250)

        return QuickGlanceSection(
            coreMessage: coreMessage.isEmpty ? "Key insights from this analysis." : coreMessage,
            keyPoints: keyPoints.isEmpty ? ["Key insight from the analysis"] : keyPoints,
            readingTime: readingTime
        )
    }

    private static func stripInlineMarkdown(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(
            of: #"(?m)^\s{0,3}#{1,6}\s+"#,
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(of: "**", with: "")
        result = result.replacingOccurrences(of: "__", with: "")
        result = result.replacingOccurrences(of: "*", with: "")
        result = result.replacingOccurrences(of: "_", with: "")
        result = result.replacingOccurrences(
            of: #"\[([^\]]+)\]\([^)]+\)"#,
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"`([^`]+)`"#,
            with: "$1",
            options: .regularExpression
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseImplicitVisualBlocks(
        from lines: [String],
        startIndex: Int
    ) -> (blocks: [PDFContentBlock], consumed: Int)? {
        // A "Central:"-anchored radial map is emitted as blank-line-separated
        // paragraphs, so detect it before the contiguous scan below (which
        // stops at the first blank line).
        if let central = parseCentralConceptMap(from: lines, startIndex: startIndex) {
            return central
        }

        let maxScan = min(startIndex + 8, lines.count)
        var candidateLines: [String] = []

        var index = startIndex
        while index < maxScan {
            let rawLine = lines[index]
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { break }
            if trimmed.hasPrefix("[") && trimmed.contains("]") { break }
            if trimmed.hasPrefix("#") { break }
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") { break }
            if trimmed.range(of: #"^\d+\.\s+"#, options: .regularExpression) != nil { break }
            candidateLines.append(rawLine)
            index += 1
        }

        guard !candidateLines.isEmpty else { return nil }

        if let stepVisual = parseImplicitSteps(from: candidateLines) {
            return (blocks: stepVisual.blocks, consumed: stepVisual.consumed)
        }

        let combined = candidateLines
            .map { stripInlineMarkdown($0) }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Arrow-delimited process flow ("A → B → C"); detected before the
        // paragraph path strips the arrows and leaves meaningless spacing.
        if let arrowFlow = parseArrowFlow(from: combined) {
            return (blocks: pdfBlocks(for: arrowFlow), consumed: candidateLines.count)
        }

        if let quadrant = parseQuadrant(from: combined) {
            return (blocks: pdfBlocks(for: quadrant.visual), consumed: candidateLines.count)
        }

        if let barChart = parseGroupedBarChart(from: combined) {
            return (blocks: pdfBlocks(for: barChart.visual), consumed: candidateLines.count)
        }

        if let concept = parseConceptMap(from: combined) {
            return (blocks: pdfBlocks(for: concept.visual), consumed: candidateLines.count)
        }

        return nil
    }

    /// Builds a flowchart from an arrow-delimited line such as
    /// "Activities → Engagement → Ownership → Results".
    private static func parseArrowFlow(from text: String) -> InsightVisual? {
        let normalized = text
            .replacingOccurrences(of: "->", with: "→")
            .replacingOccurrences(of: "=>", with: "→")
            .replacingOccurrences(of: "⟶", with: "→")
        // Require at least two arrows (three nodes) to distinguish a flow from prose.
        guard normalized.components(separatedBy: "→").count >= 3 else { return nil }
        let nodes = normalized
            .components(separatedBy: "→")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0.count <= 40 }
        guard nodes.count >= 3 else { return nil }
        return InsightVisual(type: .flowchart, title: "Process Flow", payload: .flowchart(FlowchartData(nodes: nodes)))
    }

    /// Builds a concept map from a "Central: <topic>" line followed by short
    /// branch lines, tolerating single blank lines between entries.
    private static func parseCentralConceptMap(
        from lines: [String],
        startIndex: Int
    ) -> (blocks: [PDFContentBlock], consumed: Int)? {
        let first = lines[startIndex].trimmingCharacters(in: .whitespaces)
        guard let centerRange = first.range(
            of: #"^(central|center)\s*:\s*"#,
            options: [.regularExpression, .caseInsensitive]
        ) else {
            return nil
        }
        let center = String(first[centerRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        guard !center.isEmpty else { return nil }

        var branches: [String] = []
        var index = startIndex + 1
        var consumed = 1
        var blanksSkipped = 0

        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                blanksSkipped += 1
                if blanksSkipped > 1 { break }   // two blank lines end the block
                index += 1
                consumed += 1
                continue
            }
            // Structural boundaries end the map.
            if trimmed.hasPrefix("[") || trimmed.hasPrefix("#") { break }
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") { break }
            if trimmed.range(of: #"^\d+\.\s+"#, options: .regularExpression) != nil { break }
            if trimmed.count > 80 { break }   // long line = prose, not a branch
            blanksSkipped = 0
            branches.append(stripInlineMarkdown(trimmed))
            index += 1
            consumed += 1
            if branches.count >= 8 { break }
        }

        guard branches.count >= 2 else { return nil }
        let data = ConceptMapData(center: center, branches: branches)
        let visual = InsightVisual(type: .conceptMap, title: "Concept Map", payload: .conceptMap(data))
        return (blocks: pdfBlocks(for: visual), consumed: consumed)
    }

    private static func parseImplicitSteps(
        from lines: [String]
    ) -> (blocks: [PDFContentBlock], consumed: Int)? {
        var stepLines: [String] = []
        var index = 0
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { break }
            if !isStepLine(trimmed) { break }
            stepLines.append(stripInlineMarkdown(trimmed))
            index += 1
        }

        guard stepLines.count >= 4 else { return nil }

        let isTimeline = stepLines.contains { line in
            let lower = line.lowercased()
            return lower.contains("childhood")
                || lower.contains("adolescence")
                || lower.contains("adult")
                || lower.contains("future")
                || lower.contains("past")
                || lower.contains("present")
                || lower.contains("earlier")
                || lower.contains("later")
        }

        if isTimeline {
            let events = stepLines.enumerated().map { index, step in
                TimelineData.Event(date: "Stage \(index + 1)", title: step, description: nil)
            }
            let visual = InsightVisual(type: .timeline, title: "Process Timeline", payload: .timeline(TimelineData(events: events)))
            return (blocks: pdfBlocks(for: visual), consumed: stepLines.count)
        }

        let visual = InsightVisual(type: .flowchart, title: "Process Flow", payload: .flowchart(FlowchartData(nodes: stepLines)))
        return (blocks: pdfBlocks(for: visual), consumed: stepLines.count)
    }

    private static func isStepLine(_ line: String) -> Bool {
        if line.count > 60 { return false }
        if line.hasSuffix(".") || line.hasSuffix("?") || line.hasSuffix("!") { return false }
        if line.contains(":") { return false }
        if line.hasPrefix("[") { return false }
        if line.hasPrefix("#") { return false }
        return true
    }

    private static func parseQuadrant(from text: String) -> (title: String, visual: InsightVisual)? {
        let segments = extractLabeledSegments(from: text)
        guard segments.count >= 4 else { return nil }
        // Require an explicit axes marker ("A × B" / "A vs B") so we don't
        // greedily treat any four-label list as a 2×2 matrix. The axes and
        // title are derived from the content rather than hardcoded.
        guard let axes = extractAxisPair(from: text) else { return nil }

        let quadrants = segments.prefix(4).map { segment in
            QuadrantData.Quadrant(name: segment.label, items: [segment.body].filter { !$0.isEmpty })
        }
        let data = QuadrantData(axesX: axes.second, axesY: axes.first, quadrants: Array(quadrants))
        let title = "\(axes.first) × \(axes.second)"
        let visual = InsightVisual(type: .quadrant, title: title, payload: .quadrant(data))
        return (title: title, visual: visual)
    }

    /// Extracts an axes pair from an inline marker such as "Authenticity × Boundaries"
    /// or "Cost vs Value". Returns the two axis names in written order.
    private static func extractAxisPair(from text: String) -> (first: String, second: String)? {
        guard let regex = axisPairRegex else { return nil }
        let nsText = text as NSString
        guard let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) else {
            return nil
        }
        let first = nsText.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
        let second = nsText.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespaces)
        guard !first.isEmpty, !second.isEmpty else { return nil }
        return (first, second)
    }

    private static func parseGroupedBarChart(from text: String) -> (title: String, visual: InsightVisual)? {
        let segments = extractLabeledSegments(from: text)
        guard segments.count >= 2 else { return nil }
        let parsedSegments = segments.compactMap { segment -> (String, [(String, Double)])? in
            let metrics = parsePercentMetrics(from: segment.body)
            guard !metrics.isEmpty else { return nil }
            return (segment.label, metrics)
        }
        guard parsedSegments.count >= 2 else { return nil }

        let metricLabels = parsedSegments.first?.1.map { $0.0 } ?? []
        guard !metricLabels.isEmpty else { return nil }

        var series: [[Double]] = Array(repeating: [], count: metricLabels.count)
        for (_, metrics) in parsedSegments {
            let values = metricLabels.map { label in
                metrics.first(where: { $0.0.caseInsensitiveCompare(label) == .orderedSame })?.1 ?? 0
            }
            for (index, value) in values.enumerated() {
                series[index].append(value)
            }
        }

        let labels = parsedSegments.map { $0.0 }
        let data = GroupedBarChartData(labels: labels, series: series, seriesLabels: metricLabels)
        let title = metricLabels.count == 2 ? "\(metricLabels[0]) vs \(metricLabels[1])" : "Comparison"
        let visual = InsightVisual(type: .barChartGrouped, title: title, payload: .barChartGrouped(data))
        return (title: title, visual: visual)
    }

    private static func parseConceptMap(from text: String) -> (title: String, visual: InsightVisual)? {
        let segments = extractLabeledSegments(from: text)
        guard segments.count >= 3 else { return nil }
        guard let centralSegment = segments.first(where: { $0.label.lowercased() == "central" || $0.label.lowercased() == "center" }) else {
            return nil
        }
        let branches = segments.filter { $0.label.lowercased() != "central" && $0.label.lowercased() != "center" }.map { segment in
            segment.body.isEmpty ? segment.label : "\(segment.label) — \(segment.body)"
        }
        guard !centralSegment.body.isEmpty else { return nil }
        let data = ConceptMapData(center: centralSegment.body, branches: branches)
        let visual = InsightVisual(type: .conceptMap, title: "Concept Map", payload: .conceptMap(data))
        return (title: "Concept Map", visual: visual)
    }

    private static let labeledSegmentsRegex = try? NSRegularExpression(pattern: #"([A-Z][A-Za-z0-9'’&/,\-\s]{2,60}):"#, options: [])
    private static let percentMetricsRegex = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)%\s*([A-Za-z][A-Za-z\s\-]*)"#, options: [])
    private static let axisPairRegex = try? NSRegularExpression(pattern: #"([A-Za-z][A-Za-z]{1,24})\s*(?:×|✕|vs\.?|versus)\s*([A-Za-z][A-Za-z]{1,24})"#, options: [.caseInsensitive])

    private static func extractLabeledSegments(from text: String) -> [(label: String, body: String)] {
        guard let regex = labeledSegmentsRegex else {
            return []
        }
        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        guard matches.count >= 2 else { return [] }

        var segments: [(String, String)] = []
        for (index, match) in matches.enumerated() {
            let labelRange = match.range(at: 1)
            let label = nsText.substring(with: labelRange).trimmingCharacters(in: .whitespaces)
            let start = match.range(at: 0).location + match.range(at: 0).length
            let end = (index + 1 < matches.count) ? matches[index + 1].range(at: 0).location : nsText.length
            let body = nsText.substring(with: NSRange(location: start, length: max(0, end - start)))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            segments.append((label, body))
        }
        return segments
    }

    private static func parsePercentMetrics(from text: String) -> [(String, Double)] {
        guard let regex = percentMetricsRegex else {
            return []
        }
        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        return matches.compactMap { match in
            let valueString = nsText.substring(with: match.range(at: 1))
            let label = nsText.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespaces)
            guard let value = Double(valueString) else { return nil }
            let cleanedLabel = label.isEmpty ? "Value" : label.capitalized
            return (cleanedLabel, value)
        }
    }

    private static func parseListItems(from lines: [String]) -> [String] {
        var items: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Check for "- " or "* " with space first
            if trimmed.hasPrefix("- ") {
                items.append(stripMarkdownFromLine(String(trimmed.dropFirst(2))))
            } else if trimmed.hasPrefix("-") {
                // Handle "-text" without space - only drop 1 character
                items.append(stripMarkdownFromLine(String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces)))
            } else if trimmed.hasPrefix("* ") {
                items.append(stripMarkdownFromLine(String(trimmed.dropFirst(2))))
            } else if trimmed.hasPrefix("*") {
                items.append(stripMarkdownFromLine(String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces)))
            } else if trimmed.hasPrefix("• ") {
                items.append(stripMarkdownFromLine(String(trimmed.dropFirst(2))))
            } else if trimmed.hasPrefix("•") {
                items.append(stripMarkdownFromLine(String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces)))
            } else if trimmed.range(of: "^\\d+\\.\\s+", options: .regularExpression) != nil {
                let text = trimmed.replacingOccurrences(of: "^\\d+\\.\\s+", with: "", options: .regularExpression)
                items.append(stripMarkdownFromLine(text))
            } else if trimmed.range(of: "^\\d+\\.", options: .regularExpression) != nil {
                // Handle "1.text" without space
                let text = trimmed.replacingOccurrences(of: "^\\d+\\.", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
                items.append(stripMarkdownFromLine(text))
            }
        }
        return items
    }

    private static func parseExerciseContent(from lines: [String]) -> (String, [String]) {
        var text = ""
        var steps: [String] = []

        for line in lines {
            var trimmed = line.trimmingCharacters(in: .whitespaces)

            // Strip markdown headers from line
            trimmed = stripMarkdownFromLine(trimmed)

            // Check for "- " or "* " with space first
            if trimmed.hasPrefix("- ") {
                steps.append(stripMarkdownFromLine(String(trimmed.dropFirst(2))))
            } else if trimmed.hasPrefix("-") {
                // Handle "-text" without space
                steps.append(stripMarkdownFromLine(String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces)))
            } else if trimmed.hasPrefix("* ") {
                steps.append(stripMarkdownFromLine(String(trimmed.dropFirst(2))))
            } else if trimmed.hasPrefix("*") {
                steps.append(stripMarkdownFromLine(String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces)))
            } else if trimmed.hasPrefix("• ") {
                steps.append(stripMarkdownFromLine(String(trimmed.dropFirst(2))))
            } else if trimmed.hasPrefix("•") {
                steps.append(stripMarkdownFromLine(String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces)))
            } else if trimmed.range(of: "^\\d+\\.\\s+", options: .regularExpression) != nil {
                let stepText = trimmed.replacingOccurrences(of: "^\\d+\\.\\s+", with: "", options: .regularExpression)
                steps.append(stripMarkdownFromLine(stepText))
            } else if trimmed.range(of: "^\\d+\\.", options: .regularExpression) != nil {
                // Handle "1.text" without space
                let stepText = trimmed.replacingOccurrences(of: "^\\d+\\.", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
                steps.append(stripMarkdownFromLine(stepText))
            } else if !trimmed.isEmpty {
                text += (text.isEmpty ? "" : " ") + trimmed
            }
        }

        return (stripMarkdownFromLine(text), steps)
    }

    /// Strip markdown syntax from a single line of text
    /// NOTE: Does NOT strip bold/italic markers - those are preserved for styled rendering by parseInlineMarkdown
    private static func stripMarkdownFromLine(_ text: String) -> String {
        var result = text

        // Strip markdown headers (# Header, ## Header, ### Header, etc.)
        if let headerRegex = try? NSRegularExpression(pattern: "^#{1,6}\\s+", options: []) {
            result = headerRegex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }

        // NOTE: Bold (**text**) and Italic (*text*) are NOT stripped here
        // They are preserved so parseInlineMarkdown in PDFContentBlockRenderer can render them with styling

        // Strip inline code backticks (`code`)
        if let codeRegex = try? NSRegularExpression(pattern: "`([^`]+)`", options: []) {
            result = codeRegex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1"
            )
        }

        // Strip markdown links [text](url) -> text
        if let linkRegex = try? NSRegularExpression(pattern: "\\[([^\\]]+)\\]\\([^)]+\\)", options: []) {
            result = linkRegex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1"
            )
        }

        // Strip markdown images ![alt](url) -> alt
        if let imageRegex = try? NSRegularExpression(pattern: "!\\[([^\\]]*)\\]\\([^)]+\\)", options: []) {
            result = imageRegex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1"
            )
        }

        // Strip strikethrough (~~text~~)
        if let strikeRegex = try? NSRegularExpression(pattern: "~~(.+?)~~", options: []) {
            result = strikeRegex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1"
            )
        }

        // Strip blockquote markers (> at start)
        if let quoteRegex = try? NSRegularExpression(pattern: "^>\\s*", options: []) {
            result = quoteRegex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }

        // Strip stray internal section markers that leaked mid-paragraph,
        // e.g. "[QUICK_GLANCE]" or "[/INSIGHT_NOTE]". Real markers at the start
        // of a line are consumed earlier; this catches inline remnants only.
        if let markerRegex = try? NSRegularExpression(pattern: #"\[/?[A-Z][A-Z0-9_]{3,}\]"#, options: []) {
            result = markerRegex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }

        // Strip ASCII/heavy box-drawing and rule characters. Directional arrows
        // (→ ← ↑ ↓) are intentionally NOT stripped: multi-step flows are already
        // extracted into flow visuals upstream, so any arrow remaining here is a
        // semantic connector in prose (e.g. "Identify dispute → Express offer").
        // Deleting it left a mangled double space; keeping it preserves meaning.
        let boxChars = ["┌", "┐", "└", "┘", "├", "┤", "┬", "┴", "┼", "─", "│",
                        "═", "━", "▬", "⎯"]
        for char in boxChars {
            result = result.replacingOccurrences(of: char, with: "")
        }

        // Collapse any runs of whitespace left by earlier substitutions.
        result = result.replacingOccurrences(
            of: "[ \\t]{2,}",
            with: " ",
            options: .regularExpression
        )

        return result.trimmingCharacters(in: .whitespaces)
    }

    /// A line consisting solely of repeated rule characters, e.g. "═══" or "━━━".
    private static func isHorizontalRule(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else { return false }
        let ruleChars: Set<Character> = ["═", "━", "─", "▬", "⎯", "=", "-", "_", "*"]
        return trimmed.allSatisfy { ruleChars.contains($0) }
    }

    /// Check if a table line is a separator row (|---|---|)
    private static func isTableSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if !trimmed.hasPrefix("|") || !trimmed.hasSuffix("|") {
            return false
        }
        let inner = String(trimmed.dropFirst().dropLast())
        let cells = inner.components(separatedBy: "|")
        return cells.allSatisfy { cell in
            let cleaned = cell.trimmingCharacters(in: .whitespaces)
            return cleaned.isEmpty || cleaned.allSatisfy { $0 == "-" || $0 == ":" }
        }
    }

    private static func parseFlowchartSteps(from lines: [String]) -> [String] {
        var steps: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && trimmed != "↓" && !trimmed.contains("─") && !trimmed.contains("│") {
                steps.append(trimmed)
            }
        }
        return steps
    }

    private static func parseVisualTagAndTitle(from line: String) -> (tag: String, title: String?) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let inner = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        let parts = inner.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
        let tag = parts.first ?? inner
        let title = parts.count > 1 ? parts[1] : nil
        return (tag, title)
    }

    private static func parseVisualBlocks(tag: String, title: String?, lines: [String]) -> [PDFContentBlock] {
        let canonicalTag = canonicalizeVisualTag(tag)
        guard let visual = InsightVisualParser.parse(tag: canonicalTag, title: title, lines: lines) else {
            return []
        }
        return pdfBlocks(for: visual)
    }

    /// Deterministic cache key for a visual's pre-rendered image. Content-sensitive
    /// so distinct visuals get distinct images and identical ones are reused.
    static func visualCacheURL(for visual: InsightVisual) -> URL {
        let raw = visual.type.rawValue + "|" + (visual.title ?? "") + "|" + String(describing: visual.payload)
        var hash: UInt64 = 5381
        for byte in raw.utf8 { hash = (hash &* 33) ^ UInt64(byte) }   // djb2
        return URL(string: "insightvisual://\(String(hash, radix: 16))")!
    }

    /// Extracts every explicit `[VISUAL_*]` block from raw guide content as
    /// InsightVisual values, so they can be rasterized on the main actor before
    /// the (non-isolated) PDF layout pass runs.
    static func extractVisuals(from content: String) -> [InsightVisual] {
        var visuals: [InsightVisual] = []
        let lines = content.components(separatedBy: .newlines)
        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("[VISUAL_") else { i += 1; continue }

            let parsed = parseVisualTagAndTitle(from: line)
            var body: [String] = []
            i += 1
            while i < lines.count {
                let inner = lines[i].trimmingCharacters(in: .whitespaces)
                if inner.hasPrefix("[/VISUAL_") { break }
                body.append(lines[i])
                i += 1
            }
            if let visual = InsightVisualParser.parse(
                tag: canonicalizeVisualTag(parsed.tag),
                title: parsed.title,
                lines: body
            ) {
                visuals.append(visual)
            }
            i += 1
        }
        return visuals
    }

    private static func canonicalizeVisualTag(_ tag: String) -> String {
        switch tag {
        case "VISUAL_TABLE", "VISUAL_COMPARISON", "VISUAL_COMPARISON_TABLE":
            return "VISUAL_COMPARISON_MATRIX"
        case "VISUAL_FLOW_DIAGRAM":
            return "VISUAL_FLOWCHART"
        case "PROCESS_TIMELINE":
            return "VISUAL_TIMELINE"
        case "HIERARCHY_DIAGRAM":
            return "VISUAL_HIERARCHY"
        case "VISUAL_CONCEPT_MAP":
            return "VISUAL_CONCEPT_MAP"
        default:
            return tag
        }
    }

    private static func pdfBlocks(for visual: InsightVisual) -> [PDFContentBlock] {
        var blocks: [PDFContentBlock] = []
        let title = visual.title?.trimmingCharacters(in: .whitespacesAndNewlines)

        // If a pre-rendered image of this visual is cached (produced on the main
        // actor by PDFVisualPrerenderer before export), embed it directly. This
        // reuses the shared SwiftUI card views so every visual type renders in the
        // PDF. Uncached visuals fall through to the text/table representation below.
        let cacheURL = visualCacheURL(for: visual)
        if VisualAssetCache.shared.cachedImage(for: cacheURL) != nil {
            return [PDFContentBlock(type: .visual, content: title ?? "", visualURL: cacheURL)]
        }

        func addHeadingIfNeeded(useInlineTitle: Bool) {
            if !useInlineTitle, let title, !title.isEmpty {
                blocks.append(PDFContentBlock(type: .heading4, content: title))
            }
        }

        func formatNumber(_ value: Double) -> String {
            if value.rounded() == value {
                return String(Int(value))
            }
            return String(format: "%.2f", value)
        }

        switch visual.payload {
        case .timeline(let data):
            let phases = data.events.map { event in
                if event.date.isEmpty { return event.title }
                return "\(event.date): \(event.title)"
            }
            blocks.append(PDFContentBlock(
                type: .processTimeline,
                content: "",
                listItems: phases,
                metadata: ["title": title ?? "Timeline"]
            ))

        case .flowchart(let data):
            blocks.append(PDFContentBlock(
                type: .flowchart,
                content: "",
                listItems: data.nodes,
                metadata: ["title": title ?? "Process Flow"]
            ))

        case .comparison(let data):
            addHeadingIfNeeded(useInlineTitle: false)
            let header = data.columns
            let table = header.isEmpty ? data.rows : [header] + data.rows
            blocks.append(PDFContentBlock(type: .table, content: "", tableData: table))

        case .table(let data):
            addHeadingIfNeeded(useInlineTitle: false)
            let header = data.columns
            let table = header.isEmpty ? data.rows : [header] + data.rows
            blocks.append(PDFContentBlock(type: .table, content: "", tableData: table))

        case .conceptMap(let data):
            blocks.append(PDFContentBlock(
                type: .conceptMap,
                content: "",
                listItems: data.branches,
                metadata: ["central": data.center, "title": title ?? "Concept Map"]
            ))

        case .radar(let data):
            addHeadingIfNeeded(useInlineTitle: false)
            blocks.append(PDFContentBlock(type: .bulletList, content: "", listItems: data.dimensions))

        case .hierarchy(let data):
            addHeadingIfNeeded(useInlineTitle: false)
            blocks.append(PDFContentBlock(type: .paragraph, content: data.root))
            blocks.append(PDFContentBlock(type: .bulletList, content: "", listItems: data.children))

        case .network(let data):
            addHeadingIfNeeded(useInlineTitle: false)
            let nodeRows = data.nodes.map { node in
                [node.id, node.label, node.type ?? ""]
            }
            blocks.append(PDFContentBlock(type: .table, content: "", tableData: [["ID", "Label", "Type"]] + nodeRows))
            let connectionRows = data.connections.map { connection in
                [connection.from, connection.to, connection.type ?? ""]
            }
            blocks.append(PDFContentBlock(type: .table, content: "", tableData: [["From", "To", "Type"]] + connectionRows))

        case .barChart(let data):
            addHeadingIfNeeded(useInlineTitle: false)
            let rows = zip(data.labels, data.values).map { [$0, formatNumber($1)] }
            blocks.append(PDFContentBlock(type: .table, content: "", tableData: [["Label", "Value"]] + rows))

        case .quadrant(let data):
            addHeadingIfNeeded(useInlineTitle: false)
            let rows = data.quadrants.map { quadrant in
                [quadrant.name, quadrant.items.joined(separator: " • ")]
            }
            blocks.append(PDFContentBlock(type: .table, content: "", tableData: [["Quadrant", "Items"]] + rows))

        case .pieChart(let data):
            addHeadingIfNeeded(useInlineTitle: false)
            let total = data.segments.map { $0.value }.reduce(0, +)
            let rows = data.segments.map { segment in
                let percent = total > 0 ? (segment.value / total) * 100 : 0
                return [segment.label, "\(formatNumber(percent))%"]
            }
            blocks.append(PDFContentBlock(type: .table, content: "", tableData: [["Segment", "Share"]] + rows))

        case .lineChart(let data):
            addHeadingIfNeeded(useInlineTitle: false)
            let rows = zip(data.labels, data.values).map { [$0, formatNumber($1)] }
            blocks.append(PDFContentBlock(type: .table, content: "", tableData: [["Point", "Value"]] + rows))

        case .areaChart(let data):
            addHeadingIfNeeded(useInlineTitle: false)
            let rows = zip(data.labels, data.values).map { [$0, formatNumber($1)] }
            blocks.append(PDFContentBlock(type: .table, content: "", tableData: [["Point", "Value"]] + rows))

        case .scatterPlot(let data):
            addHeadingIfNeeded(useInlineTitle: false)
            let rows = data.points.map { point in
                [formatNumber(point.x), formatNumber(point.y), point.label ?? ""]
            }
            blocks.append(PDFContentBlock(type: .table, content: "", tableData: [["X", "Y", "Label"]] + rows))

        case .vennDiagram(let data):
            addHeadingIfNeeded(useInlineTitle: false)
            let rows = data.sets.map { set in
                [set.label, set.items.joined(separator: " • ")]
            }
            blocks.append(PDFContentBlock(type: .table, content: "", tableData: [["Set", "Items"]] + rows))
            if !data.intersection.isEmpty {
                blocks.append(PDFContentBlock(type: .paragraph, content: "Intersection: \(data.intersection.joined(separator: ", "))"))
            }

        case .ganttChart(let data):
            addHeadingIfNeeded(useInlineTitle: false)
            let rows = data.tasks.map { task in
                [task.name, formatNumber(task.start), formatNumber(task.duration), task.status ?? ""]
            }
            blocks.append(PDFContentBlock(type: .table, content: "", tableData: [["Task", "Start", "Duration", "Status"]] + rows))

        case .funnelDiagram(let data):
            addHeadingIfNeeded(useInlineTitle: false)
            let rows = data.stages.map { stage in
                [stage.label, formatNumber(stage.value)]
            }
            blocks.append(PDFContentBlock(type: .table, content: "", tableData: [["Stage", "Value"]] + rows))

        case .pyramidDiagram(let data):
            addHeadingIfNeeded(useInlineTitle: false)
            let items = data.levels.map { level in
                if let description = level.description, !description.isEmpty {
                    return "\(level.label): \(description)"
                }
                return level.label
            }
            blocks.append(PDFContentBlock(type: .bulletList, content: "", listItems: items))

        case .cycleDiagram(let data):
            addHeadingIfNeeded(useInlineTitle: false)
            blocks.append(PDFContentBlock(type: .bulletList, content: "", listItems: data.stages))

        case .fishboneDiagram(let data):
            addHeadingIfNeeded(useInlineTitle: false)
            blocks.append(PDFContentBlock(type: .paragraph, content: "Effect: \(data.effect)"))
            let items = data.causes.map { cause in
                "\(cause.category): \(cause.items.joined(separator: ", "))"
            }
            blocks.append(PDFContentBlock(type: .bulletList, content: "", listItems: items))

        case .swotMatrix(let data):
            addHeadingIfNeeded(useInlineTitle: false)
            let rows = [
                [data.strengths.joined(separator: " • "), data.weaknesses.joined(separator: " • ")],
                [data.opportunities.joined(separator: " • "), data.threats.joined(separator: " • ")]
            ]
            blocks.append(PDFContentBlock(type: .table, content: "", tableData: [["Strengths", "Weaknesses"]] + rows))

        case .sankeyDiagram(let data):
            addHeadingIfNeeded(useInlineTitle: false)
            let rows = data.flows.map { flow in
                [flow.from, flow.to, formatNumber(flow.value)]
            }
            blocks.append(PDFContentBlock(type: .table, content: "", tableData: [["From", "To", "Value"]] + rows))

        case .treemap(let data):
            addHeadingIfNeeded(useInlineTitle: false)
            let rows = data.items.map { item in
                [item.label, formatNumber(item.value)]
            }
            blocks.append(PDFContentBlock(type: .table, content: "", tableData: [["Label", "Value"]] + rows))

        case .heatmap(let data):
            addHeadingIfNeeded(useInlineTitle: false)
            var table: [[String]] = []
            table.append([""] + data.cols)
            for (rowIndex, row) in data.rows.enumerated() {
                let values = rowIndex < data.values.count ? data.values[rowIndex] : []
                let rowValues = values.prefix(data.cols.count).map { formatNumber($0) }
                table.append([row] + rowValues)
            }
            blocks.append(PDFContentBlock(type: .table, content: "", tableData: table))

        case .bubbleChart(let data):
            addHeadingIfNeeded(useInlineTitle: false)
            let rows = data.bubbles.map { bubble in
                [bubble.label, formatNumber(bubble.x), formatNumber(bubble.y), formatNumber(bubble.size)]
            }
            blocks.append(PDFContentBlock(type: .table, content: "", tableData: [["Label", "X", "Y", "Size"]] + rows))

        case .infographic(let data):
            addHeadingIfNeeded(useInlineTitle: false)
            let rows = data.stats.map { stat in
                [stat.label, stat.value]
            }
            blocks.append(PDFContentBlock(type: .table, content: "", tableData: [["Stat", "Value"]] + rows))
            if !data.highlights.isEmpty {
                blocks.append(PDFContentBlock(type: .bulletList, content: "", listItems: data.highlights))
            }

        case .storyboard(let data):
            addHeadingIfNeeded(useInlineTitle: false)
            let rows = data.scenes.map { scene in
                [scene.title, scene.description]
            }
            blocks.append(PDFContentBlock(type: .table, content: "", tableData: [["Scene", "Description"]] + rows))

        case .journeyMap(let data):
            addHeadingIfNeeded(useInlineTitle: false)
            let rows = data.stages.map { stage in
                let emotion = stage.emotion?.capitalized ?? ""
                return [stage.name, stage.touchpoints.joined(separator: " • "), emotion]
            }
            blocks.append(PDFContentBlock(type: .table, content: "", tableData: [["Stage", "Touchpoints", "Emotion"]] + rows))

        case .barChartStacked(let data):
            addHeadingIfNeeded(useInlineTitle: false)
            var table: [[String]] = []
            table.append([""] + data.seriesLabels)
            for (index, label) in data.labels.enumerated() {
                let values = data.series.map { series in
                    series.indices.contains(index) ? formatNumber(series[index]) : ""
                }
                table.append([label] + values)
            }
            blocks.append(PDFContentBlock(type: .table, content: "", tableData: table))

        case .barChartGrouped(let data):
            addHeadingIfNeeded(useInlineTitle: false)
            var table: [[String]] = []
            table.append([""] + data.seriesLabels)
            for (index, label) in data.labels.enumerated() {
                let values = data.series.map { series in
                    series.indices.contains(index) ? formatNumber(series[index]) : ""
                }
                table.append([label] + values)
            }
            blocks.append(PDFContentBlock(type: .table, content: "", tableData: table))

        case .generic(let data):
            addHeadingIfNeeded(useInlineTitle: false)
            blocks.append(PDFContentBlock(type: .paragraph, content: data))
        }

        return blocks
    }

    private static func parsePremiumQuote(from lines: [String]) -> (text: String, cite: String) {
        var quoteLines: [String] = []
        var attribution = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if trimmed.hasPrefix("—") || trimmed.hasPrefix("-") {
                attribution = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            } else {
                quoteLines.append(stripMarkdownFromLine(trimmed))
            }
        }

        return (quoteLines.joined(separator: " "), attribution)
    }

    private static func parseConceptMap(from lines: [String]) -> (central: String, related: [String]) {
        var central = ""
        var related: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if central.isEmpty {
                if trimmed.lowercased().hasPrefix("central:") ||
                    trimmed.lowercased().hasPrefix("main:") ||
                    trimmed.lowercased().hasPrefix("core:") {
                    if let colonIndex = trimmed.firstIndex(of: ":") {
                        central = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                        continue
                    }
                }
                central = stripMarkdownFromLine(trimmed)
                continue
            }

            var entry = trimmed
            if entry.hasPrefix("→") || entry.hasPrefix("-") || entry.hasPrefix("•") || entry.hasPrefix("*") {
                entry = String(entry.dropFirst()).trimmingCharacters(in: .whitespaces)
            }

            if let colonIndex = entry.firstIndex(of: ":") {
                let concept = String(entry[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let relationship = String(entry[entry.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                if relationship.isEmpty {
                    related.append(stripMarkdownFromLine(concept))
                } else {
                    related.append(stripMarkdownFromLine("\(concept) — \(relationship)"))
                }
            } else {
                related.append(stripMarkdownFromLine(entry))
            }
        }

        return (central, related)
    }

    private static func parseProcessTimelineItems(from lines: [String]) -> [String] {
        let listItems = parseListItems(from: lines)
        if !listItems.isEmpty {
            return listItems
        }

        var items: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && trimmed != "↓" && !trimmed.contains("─") && !trimmed.contains("│") {
                items.append(stripMarkdownFromLine(trimmed))
            }
        }
        return items
    }

    private static func formatExerciseTitle(_ type: String?) -> String {
        guard let type = type else { return "Exercise" }
        let formatted = type
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
        return formatted + " Exercise"
    }
}

// MARK: - Conversion from ParsedAnalysisContent

extension PDFAnalysisDocument {

    /// Convert from the existing ParsedAnalysisContent type used in AnalysisDetailView
    static func from(parsedContent: ParsedAnalysisContent, title: String, author: String) -> PDFAnalysisDocument {
        var quickGlance: QuickGlanceSection?

        if let qg = parsedContent.quickGlance {
            quickGlance = QuickGlanceSection(
                coreMessage: qg.coreMessage,
                keyPoints: qg.keyPoints,
                readingTime: qg.readingTime
            )
        }

        let sections = parsedContent.sections.map { section -> PDFSection in
            let blocks = section.blocks.map { block -> PDFContentBlock in
                convertAnalysisBlock(block)
            }
            return PDFSection(heading: section.heading, blocks: blocks)
        }

        return PDFAnalysisDocument(
            book: BookMetadata(title: title, author: author),
            quickGlance: quickGlance,
            sections: sections,
            metadata: DocumentMetadata(generatedAt: Date())
        )
    }

    private static func convertAnalysisBlock(_ block: AnalysisContentBlock) -> PDFContentBlock {
        let type: PDFContentBlock.BlockType

        switch block.type {
        case .paragraph: type = .paragraph
        case .heading1: type = .heading1
        case .heading2: type = .heading2
        case .heading3: type = .heading3
        case .heading4: type = .heading4
        case .blockquote: type = .blockquote
        case .insightNote: type = .insightNote
        case .actionBox: type = .actionBox
        case .keyTakeaways: type = .keyTakeaways
        case .foundationalNarrative: type = .foundationalNarrative
        case .exercise: type = .exercise
        case .flowchart: type = .flowchart
        case .bulletList: type = .bulletList
        case .numberedList: type = .numberedList
        case .visual: type = .visual
        case .alternativePerspective: type = .alternativePerspective
        case .researchInsight: type = .researchInsight
        case .conceptMap: type = .conceptMap
        case .processTimeline: type = .processTimeline
        case .insightVisual: type = .paragraph
        // Premium block types
        case .premiumQuote: type = .premiumQuote
        case .authorSpotlight: type = .authorSpotlight
        case .premiumDivider: type = .premiumDivider
        case .premiumH1: type = .premiumH1
        case .premiumH2: type = .premiumH2
        }

        return PDFContentBlock(
            type: type,
            content: block.content,
            listItems: block.listItems,
            metadata: block.metadata,
            visualURL: block.visual?.imageURL,
            visualType: block.visual?.type
        )
    }
}

// MARK: - JSON Export

extension PDFAnalysisDocument {

    /// Export document to JSON data
    func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    /// Export document to JSON string
    func toJSONString() throws -> String {
        let data = try toJSON()
        guard let string = String(data: data, encoding: .utf8) else {
            throw PDFDocumentError.encodingFailed
        }
        return string
    }

    /// Import document from JSON data
    static func fromJSON(_ data: Data) throws -> PDFAnalysisDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PDFAnalysisDocument.self, from: data)
    }

    /// Import document from JSON string
    static func fromJSONString(_ string: String) throws -> PDFAnalysisDocument {
        guard let data = string.data(using: .utf8) else {
            throw PDFDocumentError.decodingFailed
        }
        return try fromJSON(data)
    }

    enum PDFDocumentError: Error, LocalizedError {
        case encodingFailed
        case decodingFailed

        var errorDescription: String? {
            switch self {
            case .encodingFailed: return "Failed to encode document to JSON"
            case .decodingFailed: return "Failed to decode document from JSON"
            }
        }
    }
}
