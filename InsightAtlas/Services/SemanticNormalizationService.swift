//
//  SemanticNormalizationService.swift
//  InsightAtlas
//
//  Semantic Editorial Normalization Layer.
//
//  This service transforms raw AI-generated content into explicitly typed
//  editorial blocks before rendering. It enforces the Insight Atlas editorial
//  grammar and eliminates markdown-as-structure patterns.
//
//  IMPORTANT: This service operates BEFORE content reaches renderers.
//  It does NOT modify:
//  - SwiftUI rendering code
//  - PDF/DOCX/HTML export pipelines
//  - Typography tokens or spacing constants
//  - Layout scoring logic
//
//  GOVERNANCE:
//  - All fixes occur at the semantic level
//  - Markdown is stripped except for inline emphasis
//  - Structure is made explicit through block types
//  - One conceptual move per block
//

import Foundation

// MARK: - Semantic Normalization Service

/// Transforms raw generated content into normalized editorial blocks.
///
/// Usage:
/// ```swift
/// let normalizer = SemanticNormalizationService()
/// let document = normalizer.normalize(
///     content: rawMarkdown,
///     title: "Book Title",
///     author: "Author Name"
/// )
/// ```
final class SemanticNormalizationService {

    // MARK: - Pacing Configuration

    /// Active pacing configuration (profile-driven or base)
    private var pacing: ReaderProfilePacing

    /// Current reader profile for tracking
    private var activeProfile: ReaderProfile?

    /// Whether audio-first mode is active
    private var isAudioMode: Bool = false

    // MARK: - Computed Calibration Constants (Profile-Driven)

    /// Minimum items required for a framework block
    private var minimumFrameworkItems: Int { pacing.minimumFrameworkItems }

    /// Maximum insight notes per editorial section
    private var maxInsightNotesPerSection: Int { pacing.maxInsightNotesPerSection }

    /// Maximum blocks before requiring a section divider
    private var maxBlocksBeforeDivider: Int { pacing.maxBlocksBeforeDivider }

    /// Dense prose threshold triggering split (words)
    private var denseProseThreshold: Int { pacing.denseProseThreshold }

    /// Maximum sentences per paragraph block
    private var maxSentencesPerBlock: Int { pacing.maxSentencesPerBlock }

    /// Whether to prefer short clause structures
    private var preferShortClauses: Bool { pacing.preferShortClauses }

    // MARK: - Initialization

    /// Initialize with default (practitioner) pacing
    init() {
        self.pacing = ReaderProfilePacing.baseValues
        self.activeProfile = nil
    }

    /// Initialize with specific reader profile pacing
    /// - Parameters:
    ///   - profile: Reader profile to use for pacing
    ///   - isAudioMode: Whether audio-first pacing should be applied
    init(profile: ReaderProfile, isAudioMode: Bool = false) {
        self.activeProfile = profile
        self.isAudioMode = isAudioMode
        self.pacing = AudioFirstPacing.shouldUseAudioPacing(for: profile, isAudioMode: isAudioMode)
    }

    /// Update pacing configuration for a new profile
    /// - Parameters:
    ///   - profile: New reader profile
    ///   - isAudioMode: Whether audio-first pacing should be applied
    func configure(for profile: ReaderProfile, isAudioMode: Bool = false) {
        self.activeProfile = profile
        self.isAudioMode = isAudioMode
        self.pacing = AudioFirstPacing.shouldUseAudioPacing(for: profile, isAudioMode: isAudioMode)
    }

    // MARK: - Public Methods

    /// Normalize raw content into an editorial document with profile-specific pacing
    ///
    /// - Parameters:
    ///   - content: Raw markdown content from AI generation
    ///   - title: Document title
    ///   - author: Document author
    ///   - profile: Reader profile for pacing (optional, uses current configuration if nil)
    ///   - isAudioMode: Whether to use audio-first pacing overrides
    /// - Returns: Normalized editorial document with explicit block types
    func normalize(
        content: String,
        title: String,
        author: String,
        profile: ReaderProfile? = nil,
        isAudioMode: Bool = false
    ) -> EditorialDocument {
        // Apply profile pacing if specified
        if let profile = profile {
            configure(for: profile, isAudioMode: isAudioMode)
        } else if isAudioMode, let profile = activeProfile {
            configure(for: profile, isAudioMode: true)
        }

        return normalizeContent(content: content, title: title, author: author)
    }

    /// Internal normalization implementation
    private func normalizeContent(content: String, title: String, author: String) -> EditorialDocument {
        var blocks: [EditorialBlock] = []
        let lines = content.components(separatedBy: .newlines)

        var currentParagraph: [String] = []
        var i = 0

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)

            // Skip empty lines but flush paragraph buffer
            if line.isEmpty {
                if !currentParagraph.isEmpty {
                    blocks.append(contentsOf: flushParagraphBuffer(&currentParagraph))
                }
                i += 1
                continue
            }

            // MARK: - Explicit Block Tags (Highest Priority)

            // [INSIGHT_NOTE] ... [/INSIGHT_NOTE]
            if line.hasPrefix("[INSIGHT_NOTE]") || line.hasPrefix("[INSIGHT_ATLAS_NOTE]") {
                if !currentParagraph.isEmpty {
                    blocks.append(contentsOf: flushParagraphBuffer(&currentParagraph))
                }
                let (block, newIndex) = parseInsightNote(lines: lines, startIndex: i)
                if let block = block {
                    blocks.append(block)
                }
                i = newIndex
                continue
            }

            // [ACTION_BOX] ... [/ACTION_BOX]
            if line.hasPrefix("[ACTION_BOX]") {
                if !currentParagraph.isEmpty {
                    blocks.append(contentsOf: flushParagraphBuffer(&currentParagraph))
                }
                let (block, newIndex) = parseActionBox(lines: lines, startIndex: i)
                if let block = block {
                    blocks.append(block)
                }
                i = newIndex
                continue
            }

            // [FOUNDATIONAL_NARRATIVE] ... [/FOUNDATIONAL_NARRATIVE]
            if line.hasPrefix("[FOUNDATIONAL_NARRATIVE]") {
                if !currentParagraph.isEmpty {
                    blocks.append(contentsOf: flushParagraphBuffer(&currentParagraph))
                }
                let (block, newIndex) = parseFoundationalNarrative(lines: lines, startIndex: i)
                if let block = block {
                    blocks.append(block)
                }
                i = newIndex
                continue
            }

            // [EXERCISE_*] ... [/EXERCISE_*]
            if line.hasPrefix("[EXERCISE_") {
                if !currentParagraph.isEmpty {
                    blocks.append(contentsOf: flushParagraphBuffer(&currentParagraph))
                }
                let (block, newIndex) = parseExercise(lines: lines, startIndex: i)
                if let block = block {
                    blocks.append(block)
                }
                i = newIndex
                continue
            }

            // [TAKEAWAYS] ... [/TAKEAWAYS]
            if line.hasPrefix("[TAKEAWAYS]") {
                if !currentParagraph.isEmpty {
                    blocks.append(contentsOf: flushParagraphBuffer(&currentParagraph))
                }
                let (block, newIndex) = parseTakeaways(lines: lines, startIndex: i)
                if let block = block {
                    blocks.append(block)
                }
                i = newIndex
                continue
            }

            // [VISUAL_FLOWCHART] ... [/VISUAL_FLOWCHART]
            if line.hasPrefix("[VISUAL_FLOWCHART]") {
                if !currentParagraph.isEmpty {
                    blocks.append(contentsOf: flushParagraphBuffer(&currentParagraph))
                }
                let (block, newIndex) = parseFlowchart(lines: lines, startIndex: i)
                if let block = block {
                    blocks.append(block)
                }
                i = newIndex
                continue
            }

            // [QUICK_GLANCE] ... [/QUICK_GLANCE]
            if line.hasPrefix("[QUICK_GLANCE]") {
                if !currentParagraph.isEmpty {
                    blocks.append(contentsOf: flushParagraphBuffer(&currentParagraph))
                }
                let (block, newIndex) = parseQuickGlance(lines: lines, startIndex: i)
                if let block = block {
                    blocks.append(block)
                }
                i = newIndex
                continue
            }

            // [AUTHOR_SPOTLIGHT] ... [/AUTHOR_SPOTLIGHT]
            if line.hasPrefix("[AUTHOR_SPOTLIGHT]") {
                if !currentParagraph.isEmpty {
                    blocks.append(contentsOf: flushParagraphBuffer(&currentParagraph))
                }
                let (block, newIndex) = parseAuthorSpotlight(lines: lines, startIndex: i)
                if let block = block {
                    blocks.append(block)
                }
                i = newIndex
                continue
            }

            // [PREMIUM_QUOTE] ... [/PREMIUM_QUOTE]
            if line.hasPrefix("[PREMIUM_QUOTE]") {
                if !currentParagraph.isEmpty {
                    blocks.append(contentsOf: flushParagraphBuffer(&currentParagraph))
                }
                let (block, newIndex) = parsePremiumQuote(lines: lines, startIndex: i)
                if let block = block {
                    blocks.append(block)
                }
                i = newIndex
                continue
            }

            // [RESEARCH_INSIGHT] ... [/RESEARCH_INSIGHT]
            if line.hasPrefix("[RESEARCH_INSIGHT]") {
                if !currentParagraph.isEmpty {
                    blocks.append(contentsOf: flushParagraphBuffer(&currentParagraph))
                }
                let (block, newIndex) = parseResearchInsight(lines: lines, startIndex: i)
                if let block = block {
                    blocks.append(block)
                }
                i = newIndex
                continue
            }

            // [ALTERNATIVE_PERSPECTIVE] ... [/ALTERNATIVE_PERSPECTIVE]
            if line.hasPrefix("[ALTERNATIVE_PERSPECTIVE]") {
                if !currentParagraph.isEmpty {
                    blocks.append(contentsOf: flushParagraphBuffer(&currentParagraph))
                }
                let (block, newIndex) = parseAlternativePerspective(lines: lines, startIndex: i)
                if let block = block {
                    blocks.append(block)
                }
                i = newIndex
                continue
            }

            // [FRAMEWORK] ... [/FRAMEWORK]
            if line.hasPrefix("[FRAMEWORK]") {
                if !currentParagraph.isEmpty {
                    blocks.append(contentsOf: flushParagraphBuffer(&currentParagraph))
                }
                let (block, newIndex) = parseFramework(lines: lines, startIndex: i)
                if let block = block {
                    blocks.append(block)
                }
                i = newIndex
                continue
            }

            // [DECISION_TREE] ... [/DECISION_TREE]
            if line.hasPrefix("[DECISION_TREE]") {
                if !currentParagraph.isEmpty {
                    blocks.append(contentsOf: flushParagraphBuffer(&currentParagraph))
                }
                let (block, newIndex) = parseDecisionTree(lines: lines, startIndex: i)
                if let block = block {
                    blocks.append(block)
                }
                i = newIndex
                continue
            }

            // [PROCESS_FLOW] ... [/PROCESS_FLOW]
            if line.hasPrefix("[PROCESS_FLOW]") {
                if !currentParagraph.isEmpty {
                    blocks.append(contentsOf: flushParagraphBuffer(&currentParagraph))
                }
                let (block, newIndex) = parseProcessFlow(lines: lines, startIndex: i)
                if let block = block {
                    blocks.append(block)
                }
                i = newIndex
                continue
            }

            // [COMPARISON] ... [/COMPARISON]
            if line.hasPrefix("[COMPARISON]") {
                if !currentParagraph.isEmpty {
                    blocks.append(contentsOf: flushParagraphBuffer(&currentParagraph))
                }
                let (block, newIndex) = parseComparison(lines: lines, startIndex: i)
                if let block = block {
                    blocks.append(block)
                }
                i = newIndex
                continue
            }

            // [APPLY_IT] ... [/APPLY_IT]
            if line.hasPrefix("[APPLY_IT]") {
                if !currentParagraph.isEmpty {
                    blocks.append(contentsOf: flushParagraphBuffer(&currentParagraph))
                }
                let (block, newIndex) = parseApplyIt(lines: lines, startIndex: i)
                if let block = block {
                    blocks.append(block)
                }
                i = newIndex
                continue
            }

            // MARK: - Heading Detection

            // H1 - Part Header
            if line.hasPrefix("# ") {
                if !currentParagraph.isEmpty {
                    blocks.append(contentsOf: flushParagraphBuffer(&currentParagraph))
                }
                let headingText = stripMarkdown(String(line.dropFirst(2)))
                blocks.append(EditorialBlock(
                    type: .partHeader,
                    title: headingText,
                    body: ""
                ))
                i += 1
                continue
            }

            // H2 - Section Header
            if line.hasPrefix("## ") {
                if !currentParagraph.isEmpty {
                    blocks.append(contentsOf: flushParagraphBuffer(&currentParagraph))
                }
                let headingText = stripMarkdown(String(line.dropFirst(3)))
                blocks.append(EditorialBlock(
                    type: .sectionHeader,
                    title: headingText,
                    body: ""
                ))
                i += 1
                continue
            }

            // H3 - Subsection Header
            if line.hasPrefix("### ") {
                if !currentParagraph.isEmpty {
                    blocks.append(contentsOf: flushParagraphBuffer(&currentParagraph))
                }
                let headingText = stripMarkdown(String(line.dropFirst(4)))
                blocks.append(EditorialBlock(
                    type: .subsectionHeader,
                    title: headingText,
                    body: ""
                ))
                i += 1
                continue
            }

            // H4 - Minor Header
            if line.hasPrefix("#### ") {
                if !currentParagraph.isEmpty {
                    blocks.append(contentsOf: flushParagraphBuffer(&currentParagraph))
                }
                let headingText = stripMarkdown(String(line.dropFirst(5)))
                blocks.append(EditorialBlock(
                    type: .minorHeader,
                    title: headingText,
                    body: ""
                ))
                i += 1
                continue
            }

            // MARK: - Divider Detection

            if line == "---" || line == "***" || line == "___" {
                if !currentParagraph.isEmpty {
                    blocks.append(contentsOf: flushParagraphBuffer(&currentParagraph))
                }
                blocks.append(EditorialBlock(
                    type: .sectionDivider,
                    body: ""
                ))
                i += 1
                continue
            }

            // MARK: - Blockquote Detection

            if line.hasPrefix("> ") {
                if !currentParagraph.isEmpty {
                    blocks.append(contentsOf: flushParagraphBuffer(&currentParagraph))
                }

                var quoteLines: [String] = []
                while i < lines.count {
                    let quoteLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if quoteLine.hasPrefix("> ") {
                        quoteLines.append(stripMarkdown(String(quoteLine.dropFirst(2))))
                        i += 1
                    } else {
                        break
                    }
                }

                blocks.append(EditorialBlock(
                    type: .blockquote,
                    body: quoteLines.joined(separator: " ")
                ))
                continue
            }

            // MARK: - List Detection

            // Bullet list
            if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
                if !currentParagraph.isEmpty {
                    blocks.append(contentsOf: flushParagraphBuffer(&currentParagraph))
                }

                var listItems: [String] = []
                while i < lines.count {
                    let listLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if listLine.hasPrefix("- ") || listLine.hasPrefix("* ") || listLine.hasPrefix("• ") {
                        let item = stripMarkdown(String(listLine.dropFirst(2)))
                        listItems.append(item)
                        i += 1
                    } else {
                        break
                    }
                }

                blocks.append(EditorialBlock(
                    type: .bulletList,
                    body: "",
                    listItems: listItems
                ))
                continue
            }

            // Numbered list
            if let _ = line.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                if !currentParagraph.isEmpty {
                    blocks.append(contentsOf: flushParagraphBuffer(&currentParagraph))
                }

                var listItems: [String] = []
                while i < lines.count {
                    let listLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if let range = listLine.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                        let item = stripMarkdown(String(listLine[range.upperBound...]))
                        listItems.append(item)
                        i += 1
                    } else {
                        break
                    }
                }

                blocks.append(EditorialBlock(
                    type: .numberedList,
                    body: "",
                    listItems: listItems
                ))
                continue
            }

            // MARK: - Table Detection

            if line.hasPrefix("|") {
                if !currentParagraph.isEmpty {
                    blocks.append(contentsOf: flushParagraphBuffer(&currentParagraph))
                }

                var tableRows: [[String]] = []
                while i < lines.count {
                    let tableLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if tableLine.hasPrefix("|") {
                        // Skip separator rows
                        if tableLine.contains("---") || tableLine.contains("===") {
                            i += 1
                            continue
                        }

                        let cells = tableLine
                            .split(separator: "|")
                            .map { stripMarkdown(String($0).trimmingCharacters(in: .whitespaces)) }
                            .filter { !$0.isEmpty }

                        if !cells.isEmpty {
                            tableRows.append(cells)
                        }
                        i += 1
                    } else {
                        break
                    }
                }

                if !tableRows.isEmpty {
                    blocks.append(EditorialBlock(
                        type: .table,
                        body: "",
                        tableData: tableRows
                    ))
                }
                continue
            }

            // MARK: - Pattern-Based Block Detection

            let lowerLine = line.lowercased()

            // Check for "Why It Matters" pattern → insight_note
            if matchesPattern(lowerLine, patterns: EditorialPatternMarker.whyItMattersPatterns) &&
               isBoldHeader(line) {
                if !currentParagraph.isEmpty {
                    blocks.append(contentsOf: flushParagraphBuffer(&currentParagraph))
                }
                let (block, newIndex) = parsePatternBlock(
                    lines: lines,
                    startIndex: i,
                    type: .insightNote,
                    title: extractBoldText(line) ?? "Why It Matters"
                )
                if let block = block {
                    blocks.append(block)
                }
                i = newIndex
                continue
            }

            // Check for "In Practice" pattern → apply_it
            if matchesPattern(lowerLine, patterns: EditorialPatternMarker.inPracticePatterns) &&
               isBoldHeader(line) {
                if !currentParagraph.isEmpty {
                    blocks.append(contentsOf: flushParagraphBuffer(&currentParagraph))
                }
                let (block, newIndex) = parsePatternBlock(
                    lines: lines,
                    startIndex: i,
                    type: .applyIt,
                    title: extractBoldText(line) ?? "In Practice"
                )
                if let block = block {
                    blocks.append(block)
                }
                i = newIndex
                continue
            }

            // Check for research patterns → research_insight
            if matchesPattern(lowerLine, patterns: EditorialPatternMarker.researchPatterns) &&
               isBoldHeader(line) {
                if !currentParagraph.isEmpty {
                    blocks.append(contentsOf: flushParagraphBuffer(&currentParagraph))
                }
                let (block, newIndex) = parsePatternBlock(
                    lines: lines,
                    startIndex: i,
                    type: .researchInsight,
                    title: extractBoldText(line) ?? "Research Insight"
                )
                if let block = block {
                    blocks.append(block)
                }
                i = newIndex
                continue
            }

            // MARK: - Default: Accumulate as Paragraph

            // Skip ASCII art and diagram characters
            if !line.contains("┌") && !line.contains("│") && !line.contains("└") && !line.contains("↓") {
                let cleanedLine = stripMarkdown(line)
                if !cleanedLine.isEmpty {
                    currentParagraph.append(cleanedLine)
                }
            }

            i += 1
        }

        // Flush remaining paragraph
        if !currentParagraph.isEmpty {
            blocks.append(contentsOf: flushParagraphBuffer(&currentParagraph))
        }

        // CALIBRATION: Apply post-processing editorial pacing rules
        let calibratedBlocks = applyEditorialPacingRules(blocks)

        return EditorialDocument(
            title: title,
            author: author,
            blocks: calibratedBlocks
        )
    }

    // MARK: - Editorial Pacing Calibration

    /// Apply post-processing editorial pacing rules
    ///
    /// CALIBRATION (Canonical HTML Reference):
    /// - Maximum 1 insight note per section
    /// - Dividers should appear roughly every 6 blocks
    /// - Quotes should be isolated (no adjacent commentary)
    private func applyEditorialPacingRules(_ blocks: [EditorialBlock]) -> [EditorialBlock] {
        var result: [EditorialBlock] = []
        var insightNotesInSection = 0
        var blocksSinceLastDivider = 0
        var previousBlockType: EditorialBlockType?

        for block in blocks {
            // Reset section counters on section headers
            if block.type == .sectionHeader || block.type == .partHeader {
                insightNotesInSection = 0
                blocksSinceLastDivider = 0
            }

            // Track blocks since divider
            if block.type == .sectionDivider {
                blocksSinceLastDivider = 0
            } else {
                blocksSinceLastDivider += 1
            }

            // CALIBRATION: Limit insight notes per section
            if block.type == .insightNote {
                insightNotesInSection += 1
                if insightNotesInSection > maxInsightNotesPerSection {
                    // Demote excess insight notes to paragraph
                    result.append(EditorialBlock(
                        type: .paragraph,
                        title: nil,
                        body: block.body,
                        attribution: block.attribution,
                        intent: "Demoted from insight note (pacing rule: max 1 per section)",
                        metadata: block.metadata,
                        listItems: block.listItems,
                        tableData: block.tableData,
                        steps: block.steps,
                        branches: block.branches
                    ))
                    previousBlockType = .paragraph
                    continue
                }
            }

            // CALIBRATION: Ensure quotes are isolated
            // Premium quotes should not immediately follow insight notes or other commentary
            if block.type == .premiumQuote {
                if previousBlockType == .insightNote || previousBlockType == .researchInsight {
                    // Insert a paragraph break (conceptual spacing)
                    // The quote will still render, but we note the editorial concern
                }
            }

            result.append(block)
            previousBlockType = block.type
        }

        return result
    }

    // MARK: - Private Methods

    /// Flush paragraph buffer and apply semantic analysis
    private func flushParagraphBuffer(_ buffer: inout [String]) -> [EditorialBlock] {
        guard !buffer.isEmpty else { return [] }

        let fullText = buffer.joined(separator: " ")
        buffer.removeAll()

        // Apply conceptual density reduction
        return splitByConceptualMoves(fullText)
    }

    /// Split text by conceptual moves (principle, explanation, application, outcome)
    ///
    /// CALIBRATION (Profile-Driven):
    /// - Each block should contain ONE conceptual move
    /// - Maximum sentences per block driven by reader profile
    /// - Split on transitional markers and conceptual shifts
    /// - Dense prose threshold driven by reader profile
    private func splitByConceptualMoves(_ text: String) -> [EditorialBlock] {
        let wordCount = text.split(separator: " ").count

        // Short paragraphs pass through unchanged (profile-driven threshold)
        guard wordCount > denseProseThreshold else {
            return [EditorialBlock(type: .paragraph, body: text)]
        }

        // Split on sentence boundaries
        let sentences = splitIntoSentences(text)

        // Group into blocks based on profile pacing
        var blocks: [EditorialBlock] = []
        var currentGroup: [String] = []

        for sentence in sentences {
            currentGroup.append(sentence)

            // Flush at max sentences (profile-driven) or on transitional markers
            let shouldFlush = currentGroup.count >= maxSentencesPerBlock ||
                              containsTransitionalMarker(sentence) ||
                              (preferShortClauses && currentGroup.count >= 2)

            if shouldFlush {
                let body = currentGroup.joined(separator: " ")
                blocks.append(EditorialBlock(type: .paragraph, body: body))
                currentGroup.removeAll()
            }
        }

        // Flush remaining
        if !currentGroup.isEmpty {
            let body = currentGroup.joined(separator: " ")
            blocks.append(EditorialBlock(type: .paragraph, body: body))
        }

        return blocks.isEmpty ? [EditorialBlock(type: .paragraph, body: text)] : blocks
    }

    /// Split text into sentences, preserving meaning units
    private func splitIntoSentences(_ text: String) -> [String] {
        // Split on sentence-ending punctuation followed by space
        let pattern = #"(?<=[.!?])\s+(?=[A-Z])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [text]
        }

        let range = NSRange(text.startIndex..., in: text)
        var sentences: [String] = []
        var lastEnd = text.startIndex

        regex.enumerateMatches(in: text, range: range) { match, _, _ in
            if let matchRange = match?.range, let swiftRange = Range(matchRange, in: text) {
                let sentence = String(text[lastEnd..<swiftRange.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                if !sentence.isEmpty {
                    sentences.append(sentence)
                }
                lastEnd = swiftRange.upperBound
            }
        }

        // Add final sentence
        let remaining = String(text[lastEnd...]).trimmingCharacters(in: .whitespaces)
        if !remaining.isEmpty {
            sentences.append(remaining)
        }

        return sentences
    }

    /// Check for transitional markers that indicate conceptual shift
    private func containsTransitionalMarker(_ text: String) -> Bool {
        let markers = [
            "however,", "therefore,", "consequently,", "as a result,",
            "in contrast,", "meanwhile,", "furthermore,", "additionally,",
            "this means", "this suggests", "this is why", "the key is"
        ]
        let lower = text.lowercased()
        return markers.contains { lower.contains($0) }
    }

    /// Strip markdown formatting (bold, italic) but preserve text
    private func stripMarkdown(_ text: String) -> String {
        var result = text

        // Remove bold markers
        result = result.replacingOccurrences(of: "**", with: "")
        result = result.replacingOccurrences(of: "__", with: "")

        // Remove italic markers (but not mid-word underscores)
        result = result.replacingOccurrences(of: "*", with: "")

        // Remove inline code markers
        result = result.replacingOccurrences(of: "`", with: "")

        // Remove strikethrough
        result = result.replacingOccurrences(of: "~~", with: "")

        return result.trimmingCharacters(in: .whitespaces)
    }

    /// Check if a line is a bold header pattern like "**The Principle**"
    private func isBoldHeader(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("**") && trimmed.hasSuffix("**") && trimmed.count > 4
    }

    /// Extract text from bold markers
    private func extractBoldText(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("**") && trimmed.hasSuffix("**") {
            let content = String(trimmed.dropFirst(2).dropLast(2))
            return content.isEmpty ? nil : content
        }
        return nil
    }

    /// Check if text matches any of the given patterns
    private func matchesPattern(_ text: String, patterns: [String]) -> Bool {
        patterns.contains { text.contains($0) }
    }

    // MARK: - Block Parsers

    /// Parse insight note block
    private func parseInsightNote(lines: [String], startIndex: Int) -> (EditorialBlock?, Int) {
        var i = startIndex + 1
        var content: [String] = []

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[/INSIGHT") {
                break
            }
            content.append(stripMarkdown(line))
            i += 1
        }

        let body = content.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return (
            EditorialBlock(
                type: .insightNote,
                title: "Insight Atlas Note",
                body: body,
                intent: "Connect core concepts and provide deeper understanding"
            ),
            i + 1
        )
    }

    /// Parse action box block
    private func parseActionBox(lines: [String], startIndex: Int) -> (EditorialBlock?, Int) {
        var i = startIndex + 1
        var title = "Apply This"
        var steps: [String] = []

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[/ACTION_BOX]") {
                break
            }

            // Check for title
            if line.hasPrefix("**") && line.hasSuffix("**") {
                title = stripMarkdown(line)
            } else if line.hasPrefix("-") || line.hasPrefix("•") || line.hasPrefix("*") {
                steps.append(stripMarkdown(String(line.dropFirst(1)).trimmingCharacters(in: .whitespaces)))
            } else if let _ = line.range(of: #"^\d+\."#, options: .regularExpression) {
                let text = line.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
                steps.append(stripMarkdown(text))
            }
            i += 1
        }

        return (
            EditorialBlock(
                type: .actionBox,
                title: title,
                body: "",
                intent: "Provide concrete action steps",
                listItems: steps
            ),
            i + 1
        )
    }

    /// Parse foundational narrative block
    private func parseFoundationalNarrative(lines: [String], startIndex: Int) -> (EditorialBlock?, Int) {
        var i = startIndex + 1
        var content: [String] = []

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[/FOUNDATIONAL_NARRATIVE]") {
                break
            }
            content.append(stripMarkdown(line))
            i += 1
        }

        let body = content.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return (
            EditorialBlock(
                type: .foundationalNarrative,
                title: "The Story Behind the Ideas",
                body: body,
                intent: "Provide origin story and cultural context"
            ),
            i + 1
        )
    }

    /// Parse exercise block
    private func parseExercise(lines: [String], startIndex: Int) -> (EditorialBlock?, Int) {
        var i = startIndex + 1
        var title = "Exercise"
        var content: [String] = []
        var steps: [String] = []

        // Extract exercise type from opening tag
        let openingLine = lines[startIndex]
        if let range = openingLine.range(of: #"\[EXERCISE_(\w+)\]"#, options: .regularExpression) {
            let typeStr = String(openingLine[range]).replacingOccurrences(of: "[EXERCISE_", with: "").replacingOccurrences(of: "]", with: "")
            title = typeStr.capitalized.replacingOccurrences(of: "_", with: " ") + " Exercise"
        }

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[/EXERCISE_") {
                break
            }

            if line.hasPrefix("-") || line.hasPrefix("•") {
                steps.append(stripMarkdown(String(line.dropFirst(1)).trimmingCharacters(in: .whitespaces)))
            } else if let _ = line.range(of: #"^\d+\."#, options: .regularExpression) {
                let text = line.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
                steps.append(stripMarkdown(text))
            } else {
                content.append(stripMarkdown(line))
            }
            i += 1
        }

        return (
            EditorialBlock(
                type: .exercise,
                title: title,
                body: content.joined(separator: " ").trimmingCharacters(in: .whitespaces),
                intent: "Guide hands-on practice and reflection",
                listItems: steps.isEmpty ? nil : steps
            ),
            i + 1
        )
    }

    /// Parse takeaways block
    private func parseTakeaways(lines: [String], startIndex: Int) -> (EditorialBlock?, Int) {
        var i = startIndex + 1
        var items: [String] = []

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[/TAKEAWAYS]") {
                break
            }

            if line.hasPrefix("-") || line.hasPrefix("•") {
                items.append(stripMarkdown(String(line.dropFirst(1)).trimmingCharacters(in: .whitespaces)))
            } else if let _ = line.range(of: #"^\d+\."#, options: .regularExpression) {
                let text = line.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
                items.append(stripMarkdown(text))
            }
            i += 1
        }

        return (
            EditorialBlock(
                type: .keyTakeaways,
                title: "Key Takeaways",
                body: "",
                intent: "Summarize main learnings",
                listItems: items
            ),
            i + 1
        )
    }

    /// Parse flowchart block
    private func parseFlowchart(lines: [String], startIndex: Int) -> (EditorialBlock?, Int) {
        var i = startIndex + 1
        var title = "Process Flow"
        var steps: [EditorialStep] = []
        var stepNumber = 1

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[/VISUAL_FLOWCHART]") {
                break
            }

            // Extract title if present
            if line.hasPrefix("**") && line.hasSuffix("**") {
                title = stripMarkdown(line)
            } else if line.hasPrefix("-") || line.hasPrefix("•") || line.contains("→") {
                let text = stripMarkdown(line.replacingOccurrences(of: "→", with: ""))
                    .trimmingCharacters(in: CharacterSet(charactersIn: "-•").union(.whitespaces))
                if !text.isEmpty {
                    steps.append(EditorialStep(number: stepNumber, instruction: text))
                    stepNumber += 1
                }
            }
            i += 1
        }

        return (
            EditorialBlock(
                type: .processFlow,
                title: title,
                body: "",
                intent: "Visualize step-by-step process",
                steps: steps
            ),
            i + 1
        )
    }

    /// Parse quick glance block
    private func parseQuickGlance(lines: [String], startIndex: Int) -> (EditorialBlock?, Int) {
        var i = startIndex + 1
        var content: [String] = []
        var keyPoints: [String] = []

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[/QUICK_GLANCE]") {
                break
            }

            if line.hasPrefix("-") || line.hasPrefix("•") {
                keyPoints.append(stripMarkdown(String(line.dropFirst(1)).trimmingCharacters(in: .whitespaces)))
            } else {
                content.append(stripMarkdown(line))
            }
            i += 1
        }

        return (
            EditorialBlock(
                type: .quickGlance,
                title: "Quick Glance",
                body: content.joined(separator: " ").trimmingCharacters(in: .whitespaces),
                intent: "Provide ultra-condensed summary",
                listItems: keyPoints.isEmpty ? nil : keyPoints
            ),
            i + 1
        )
    }

    /// Parse author spotlight block
    private func parseAuthorSpotlight(lines: [String], startIndex: Int) -> (EditorialBlock?, Int) {
        var i = startIndex + 1
        var content: [String] = []
        var authorName: String?

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[/AUTHOR_SPOTLIGHT]") {
                break
            }

            // Look for author name in bold
            if line.hasPrefix("**") && line.hasSuffix("**") && authorName == nil {
                authorName = stripMarkdown(line)
            } else {
                content.append(stripMarkdown(line))
            }
            i += 1
        }

        return (
            EditorialBlock(
                type: .authorSpotlight,
                title: authorName ?? "About the Author",
                body: content.joined(separator: " ").trimmingCharacters(in: .whitespaces),
                attribution: authorName.map { EditorialAttribution(source: nil, author: $0, publication: nil, year: nil, url: nil) },
                intent: "Introduce author background and credentials"
            ),
            i + 1
        )
    }

    /// Parse premium quote block
    private func parsePremiumQuote(lines: [String], startIndex: Int) -> (EditorialBlock?, Int) {
        var i = startIndex + 1
        var quoteText: [String] = []
        var attribution: String?

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[/PREMIUM_QUOTE]") {
                break
            }

            // Check for attribution line (usually starts with "—" or "–")
            if line.hasPrefix("—") || line.hasPrefix("–") || line.hasPrefix("-") && line.count > 2 {
                attribution = stripMarkdown(String(line.dropFirst(1)).trimmingCharacters(in: .whitespaces))
            } else {
                quoteText.append(stripMarkdown(line))
            }
            i += 1
        }

        return (
            EditorialBlock(
                type: .premiumQuote,
                body: quoteText.joined(separator: " ").trimmingCharacters(in: .whitespaces),
                attribution: EditorialAttribution(source: attribution, author: attribution, publication: nil, year: nil, url: nil),
                intent: "Highlight significant quotation"
            ),
            i + 1
        )
    }

    /// Parse research insight block
    private func parseResearchInsight(lines: [String], startIndex: Int) -> (EditorialBlock?, Int) {
        var i = startIndex + 1
        var content: [String] = []
        var source: String?

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[/RESEARCH_INSIGHT]") {
                break
            }

            // Look for citation/source
            if line.lowercased().contains("source:") || line.lowercased().contains("study:") {
                source = stripMarkdown(line)
            } else {
                content.append(stripMarkdown(line))
            }
            i += 1
        }

        return (
            EditorialBlock(
                type: .researchInsight,
                title: "Research Insight",
                body: content.joined(separator: " ").trimmingCharacters(in: .whitespaces),
                attribution: source.map { EditorialAttribution(source: $0, author: nil, publication: nil, year: nil, url: nil) },
                intent: "Present research-backed evidence"
            ),
            i + 1
        )
    }

    /// Parse alternative perspective block
    private func parseAlternativePerspective(lines: [String], startIndex: Int) -> (EditorialBlock?, Int) {
        var i = startIndex + 1
        var content: [String] = []

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[/ALTERNATIVE_PERSPECTIVE]") {
                break
            }
            content.append(stripMarkdown(line))
            i += 1
        }

        return (
            EditorialBlock(
                type: .alternativePerspective,
                title: "Alternative Perspective",
                body: content.joined(separator: " ").trimmingCharacters(in: .whitespaces),
                intent: "Present contrasting viewpoint"
            ),
            i + 1
        )
    }

    /// Parse framework block
    ///
    /// CALIBRATION (Canonical HTML Reference):
    /// - Frameworks require 3+ related concepts (e.g., brainstem/limbic/cortex)
    /// - If fewer items exist, emit as bulletList instead (not a true framework)
    /// - Framework items should be grouped conceptual relationships
    private func parseFramework(lines: [String], startIndex: Int) -> (EditorialBlock?, Int) {
        var i = startIndex + 1
        var title = "Framework"
        var content: [String] = []
        var items: [String] = []

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[/FRAMEWORK]") {
                break
            }

            if line.hasPrefix("**") && line.hasSuffix("**") && title == "Framework" {
                title = stripMarkdown(line)
            } else if line.hasPrefix("-") || line.hasPrefix("•") {
                items.append(stripMarkdown(String(line.dropFirst(1)).trimmingCharacters(in: .whitespaces)))
            } else {
                content.append(stripMarkdown(line))
            }
            i += 1
        }

        // CALIBRATION: Framework requires minimum 3 related concepts
        // If fewer, demote to bulletList (preserves content, changes semantic type)
        let blockType: EditorialBlockType = items.count >= minimumFrameworkItems ? .framework : .bulletList
        let intent = items.count >= minimumFrameworkItems
            ? "Define conceptual framework with grouped relationships"
            : "List of related items (insufficient for framework structure)"

        return (
            EditorialBlock(
                type: blockType,
                title: blockType == .framework ? title : nil,
                body: content.joined(separator: " ").trimmingCharacters(in: .whitespaces),
                intent: intent,
                listItems: items.isEmpty ? nil : items
            ),
            i + 1
        )
    }

    /// Parse decision tree block
    private func parseDecisionTree(lines: [String], startIndex: Int) -> (EditorialBlock?, Int) {
        var i = startIndex + 1
        var title = "Decision Tree"
        var branches: [EditorialBranch] = []

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[/DECISION_TREE]") {
                break
            }

            if line.hasPrefix("**") && line.hasSuffix("**") && title == "Decision Tree" {
                title = stripMarkdown(line)
            } else if line.contains("→") || line.contains("->") {
                let parts = line.replacingOccurrences(of: "->", with: "→").split(separator: "→")
                if parts.count >= 2 {
                    let condition = stripMarkdown(String(parts[0]))
                    let outcome = stripMarkdown(String(parts[1]))
                    branches.append(EditorialBranch(condition: condition, outcome: outcome))
                }
            }
            i += 1
        }

        return (
            EditorialBlock(
                type: .decisionTree,
                title: title,
                body: "",
                intent: "Guide decision-making with branching logic",
                branches: branches
            ),
            i + 1
        )
    }

    /// Parse process flow block
    private func parseProcessFlow(lines: [String], startIndex: Int) -> (EditorialBlock?, Int) {
        var i = startIndex + 1
        var title = "Process Flow"
        var steps: [EditorialStep] = []
        var stepNumber = 1

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[/PROCESS_FLOW]") {
                break
            }

            if line.hasPrefix("**") && line.hasSuffix("**") && title == "Process Flow" {
                title = stripMarkdown(line)
            } else if let _ = line.range(of: #"^\d+\."#, options: .regularExpression) {
                let text = line.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
                steps.append(EditorialStep(number: stepNumber, instruction: stripMarkdown(text)))
                stepNumber += 1
            } else if line.hasPrefix("-") || line.hasPrefix("•") {
                let text = String(line.dropFirst(1)).trimmingCharacters(in: .whitespaces)
                steps.append(EditorialStep(number: stepNumber, instruction: stripMarkdown(text)))
                stepNumber += 1
            }
            i += 1
        }

        return (
            EditorialBlock(
                type: .processFlow,
                title: title,
                body: "",
                intent: "Define linear process sequence",
                steps: steps
            ),
            i + 1
        )
    }

    /// Parse comparison block
    private func parseComparison(lines: [String], startIndex: Int) -> (EditorialBlock?, Int) {
        var i = startIndex + 1
        var title = "Comparison"
        var tableData: [[String]] = []

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[/COMPARISON]") {
                break
            }

            if line.hasPrefix("**") && line.hasSuffix("**") && title == "Comparison" {
                title = stripMarkdown(line)
            } else if line.hasPrefix("|") {
                // Parse table row
                let cells = line
                    .split(separator: "|")
                    .map { stripMarkdown(String($0).trimmingCharacters(in: .whitespaces)) }
                    .filter { !$0.isEmpty && !$0.contains("---") }

                if !cells.isEmpty {
                    tableData.append(cells)
                }
            }
            i += 1
        }

        return (
            EditorialBlock(
                type: .comparisonBeforeAfter,
                title: title,
                body: "",
                intent: "Show before/after or contrast comparison",
                tableData: tableData.isEmpty ? nil : tableData
            ),
            i + 1
        )
    }

    /// Parse apply it block
    private func parseApplyIt(lines: [String], startIndex: Int) -> (EditorialBlock?, Int) {
        var i = startIndex + 1
        var content: [String] = []
        var steps: [String] = []

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[/APPLY_IT]") {
                break
            }

            if line.hasPrefix("-") || line.hasPrefix("•") || line.hasPrefix("*") {
                steps.append(stripMarkdown(String(line.dropFirst(1)).trimmingCharacters(in: .whitespaces)))
            } else if let _ = line.range(of: #"^\d+\."#, options: .regularExpression) {
                let text = line.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
                steps.append(stripMarkdown(text))
            } else {
                content.append(stripMarkdown(line))
            }
            i += 1
        }

        return (
            EditorialBlock(
                type: .applyIt,
                title: "Apply It",
                body: content.joined(separator: " ").trimmingCharacters(in: .whitespaces),
                intent: "Guide practical application",
                listItems: steps.isEmpty ? nil : steps
            ),
            i + 1
        )
    }

    /// Parse pattern-based block (for implicit patterns like "**Why It Matters**")
    private func parsePatternBlock(
        lines: [String],
        startIndex: Int,
        type: EditorialBlockType,
        title: String
    ) -> (EditorialBlock?, Int) {
        var i = startIndex + 1
        var content: [String] = []

        // Read until next heading, divider, or empty line followed by another structure
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)

            // Stop conditions
            if line.isEmpty && i + 1 < lines.count {
                let nextLine = lines[i + 1].trimmingCharacters(in: .whitespaces)
                if nextLine.hasPrefix("#") || nextLine.hasPrefix("[") || isBoldHeader(nextLine) ||
                   nextLine.hasPrefix("-") || nextLine.hasPrefix("*") || nextLine.hasPrefix("|") {
                    break
                }
            }

            if line.hasPrefix("#") || line.hasPrefix("[") || line == "---" || line == "***" {
                break
            }

            // Check for next bold header pattern
            if isBoldHeader(line) && i > startIndex {
                break
            }

            if !line.isEmpty {
                content.append(stripMarkdown(line))
            }
            i += 1
        }

        guard !content.isEmpty else {
            return (nil, startIndex + 1)
        }

        return (
            EditorialBlock(
                type: type,
                title: title,
                body: content.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            ),
            i
        )
    }
}
