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
        var inFlowchart = false
        var flowchartContent: [String] = []
        var flowchartTitle: String?

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)

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
                currentBlocks.append(PDFContentBlock(
                    type: .keyTakeaways,
                    content: "",
                    listItems: items
                ))
                i += 1
                continue
            }
            if inTakeaways {
                takeawaysContent.append(line)
                i += 1
                continue
            }

            // Flowchart block
            if line.hasPrefix("[VISUAL_FLOWCHART") {
                inFlowchart = true
                flowchartContent = []
                // Extract title if present
                if let colonIndex = line.firstIndex(of: ":") {
                    let afterColon = line[line.index(after: colonIndex)...]
                    flowchartTitle = afterColon.replacingOccurrences(of: "]", with: "").trimmingCharacters(in: .whitespaces)
                } else {
                    flowchartTitle = "Visual Guide"
                }
                i += 1
                continue
            }
            if line.hasPrefix("[/VISUAL_FLOWCHART]") {
                inFlowchart = false
                let steps = parseFlowchartSteps(from: flowchartContent)
                currentBlocks.append(PDFContentBlock(
                    type: .flowchart,
                    content: "",
                    listItems: steps,
                    metadata: ["title": flowchartTitle ?? "Visual Guide"]
                ))
                i += 1
                continue
            }
            if inFlowchart {
                flowchartContent.append(line)
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

            // Divider
            if line == "---" || line == "***" || line == "___" {
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
            book: BookMetadata(title: title, author: author),
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

            if trimmed.lowercased().contains("core message") ||
               trimmed.lowercased().contains("core thesis") ||
               trimmed.lowercased().contains("one-sentence premise") {
                if let colonIndex = trimmed.firstIndex(of: ":") {
                    coreMessage = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                }
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("• ") {
                let cleanPoint = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !cleanPoint.isEmpty {
                    keyPoints.append(cleanPoint)
                }
            } else if trimmed.hasPrefix("-") || trimmed.hasPrefix("*") || trimmed.hasPrefix("•") {
                let cleanPoint = String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces)
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

        // Strip ASCII box drawing characters
        let boxChars = ["┌", "┐", "└", "┘", "├", "┤", "┬", "┴", "┼", "─", "│", "↓", "→", "←", "↑"]
        for char in boxChars {
            result = result.replacingOccurrences(of: char, with: "")
        }

        return result.trimmingCharacters(in: .whitespaces)
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
