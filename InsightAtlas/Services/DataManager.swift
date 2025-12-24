import Foundation
import SwiftUI
import PDFKit
import UIKit
import ZIPFoundation

/// Manages persistent data storage for the app
@MainActor
class DataManager: ObservableObject {

    // MARK: - Published Properties

    @Published var libraryItems: [LibraryItem] = []
    @Published var userSettings: UserSettings = UserSettings()
    @Published var isLoading: Bool = false

    // MARK: - Private Properties

    private let libraryKey = "insight_atlas_library"
    private let settingsKey = "insight_atlas_settings"
    private let fileManager = FileManager.default

    // MARK: - Initialization

    init() {
        // Migrate API keys from UserDefaults to Keychain (one-time)
        KeychainService.shared.migrateFromUserDefaults()
        loadData()
    }

    // MARK: - Library Management

    /// Add a new item to the library
    func addLibraryItem(_ item: LibraryItem) {
        libraryItems.insert(item, at: 0)
        saveLibrary()
    }

    /// Update an existing library item
    func updateLibraryItem(_ item: LibraryItem) {
        if let index = libraryItems.firstIndex(where: { $0.id == item.id }) {
            var updatedItem = item
            updatedItem.updatedAt = Date()
            libraryItems[index] = updatedItem
            saveLibrary()
        }
    }

    /// Update a library item with new content
    func updateLibraryItem(_ item: LibraryItem, with newContent: String) {
        if let index = libraryItems.firstIndex(where: { $0.id == item.id }) {
            var updatedItem = libraryItems[index]
            updatedItem.summaryContent = newContent
            updatedItem.updatedAt = Date()
            libraryItems[index] = updatedItem
            saveLibrary()
        }
    }

    /// Delete a library item and its associated audio file
    func deleteLibraryItem(_ item: LibraryItem) {
        // Clean up associated audio file if it exists
        cleanupAudioFile(for: item)
        libraryItems.removeAll { $0.id == item.id }
        saveLibrary()
    }

    /// Delete multiple library items and their associated audio files
    func deleteLibraryItems(at offsets: IndexSet) {
        // Clean up audio files for items being deleted
        for index in offsets {
            if index < libraryItems.count {
                cleanupAudioFile(for: libraryItems[index])
            }
        }
        libraryItems.remove(atOffsets: offsets)
        saveLibrary()
    }

    /// Clean up audio file associated with a library item
    private func cleanupAudioFile(for item: LibraryItem) {
        guard let audioFileName = item.audioFileURL, !audioFileName.isEmpty else { return }

        // Audio files are stored in the documents directory
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let audioFileURL = documentsDir.appendingPathComponent(audioFileName)

        // Delete the audio file if it exists
        if fileManager.fileExists(atPath: audioFileURL.path) {
            do {
                try fileManager.removeItem(at: audioFileURL)
            } catch {
                // Log error but don't fail the deletion
                print("Warning: Failed to delete audio file \(audioFileName): \(error.localizedDescription)")
            }
        }
    }

    /// Get a specific library item by ID
    func getLibraryItem(id: UUID) -> LibraryItem? {
        return libraryItems.first { $0.id == id }
    }

    /// Save summary content to a library item with optional generation metadata
    func saveSummary(for itemId: UUID, content: String, metadata: GenerationMetadata? = nil) {
        if let index = libraryItems.firstIndex(where: { $0.id == itemId }) {
            libraryItems[index].summaryContent = content
            libraryItems[index].updatedAt = Date()

            // Apply governor metadata if available
            if let meta = metadata {
                libraryItems[index].summaryType = meta.summaryType
                libraryItems[index].governedWordCount = meta.governedWordCount
                libraryItems[index].cutPolicyActivated = meta.cutPolicyActivated
                libraryItems[index].cutEventCount = meta.cutEventCount

                // Apply audio metadata
                libraryItems[index].audioFileURL = meta.audioFileURL
                libraryItems[index].audioVoiceID = meta.audioVoiceID
                libraryItems[index].audioDuration = meta.audioDuration
                libraryItems[index].audioGenerationAttempted = true
            }

            saveLibrary()
        }
    }

    /// Update audio metadata for an existing library item (audio-only generation)
    func updateAudioMetadata(
        for itemId: UUID,
        audioFileURL: String,
        audioVoiceID: String,
        audioDuration: TimeInterval
    ) {
        if let index = libraryItems.firstIndex(where: { $0.id == itemId }) {
            libraryItems[index].audioFileURL = audioFileURL
            libraryItems[index].audioVoiceID = audioVoiceID
            libraryItems[index].audioDuration = audioDuration
            libraryItems[index].audioGenerationAttempted = true
            libraryItems[index].updatedAt = Date()
            saveLibrary()
        }
    }

    // MARK: - Settings Management

    /// Update user settings
    func updateSettings(_ settings: UserSettings) {
        userSettings = settings
        saveSettings()
    }

    /// Update Claude API key (stored securely in Keychain)
    func updateClaudeApiKey(_ key: String?) {
        KeychainService.shared.claudeApiKey = key
    }

    /// Update OpenAI API key (stored securely in Keychain)
    func updateOpenAIApiKey(_ key: String?) {
        KeychainService.shared.openaiApiKey = key
    }

    /// Check if API keys are configured (reads from Keychain)
    var hasValidApiKeys: Bool {
        switch userSettings.preferredProvider {
        case .claude:
            return KeychainService.shared.hasClaudeApiKey
        case .openai:
            return KeychainService.shared.hasOpenAIApiKey
        case .both:
            return KeychainService.shared.hasClaudeApiKey &&
                   KeychainService.shared.hasOpenAIApiKey
        }
    }

    // MARK: - Persistence

    private func loadData() {
        loadLibrary()
        loadSettings()
    }

    private func loadLibrary() {
        if let data = UserDefaults.standard.data(forKey: libraryKey),
           let items = try? JSONDecoder().decode([LibraryItem].self, from: data) {
            libraryItems = items.sorted { $0.updatedAt > $1.updatedAt }
        }
    }

    private func saveLibrary() {
        if let data = try? JSONEncoder().encode(libraryItems) {
            UserDefaults.standard.set(data, forKey: libraryKey)
        }
    }

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let settings = try? JSONDecoder().decode(UserSettings.self, from: data) {
            userSettings = settings
        }
    }

    func saveSettings() {
        if let data = try? JSONEncoder().encode(userSettings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }

    // MARK: - Export

    /// Export progress tracking for async operations
    enum ExportProgress {
        case preparing
        case converting(percent: Double)
        case writing
        case complete
    }

    /// Async export with progress reporting
    /// Note: Yields between phases to allow UI updates during long exports
    func exportGuideAsync(
        _ item: LibraryItem,
        format: ExportFormat,
        progress: ((ExportProgress) -> Void)? = nil
    ) async throws -> URL {
        progress?(.preparing)

        // Yield to allow UI to update before heavy processing
        await Task.yield()

        progress?(.converting(percent: 0.5))
        let url = try exportGuide(item, format: format)

        progress?(.complete)
        return url
    }

    /// Export a guide to a file with comprehensive error handling
    func exportGuide(_ item: LibraryItem, format: ExportFormat) throws -> URL {
        guard let content = item.summaryContent, !content.isEmpty else {
            throw DataManagerError.noContent
        }

        // Generate clean, readable filename in Title Case with proper formatting
        let sanitizedTitle = sanitizeFilename(item.title)
        let fileName = "\(sanitizedTitle) - Insight Atlas Guide"
        let tempDir = fileManager.temporaryDirectory

        do {
            switch format {
            case .markdown:
                let fileURL = tempDir.appendingPathComponent("\(fileName).md")
                do {
                    try content.write(to: fileURL, atomically: true, encoding: .utf8)
                } catch {
                    throw DataManagerError.fileWriteFailed(path: fileURL.path)
                }
                return fileURL

            case .plainText:
                let plainContent = stripMarkdown(from: content)
                let fileURL = tempDir.appendingPathComponent("\(fileName).txt")
                do {
                    try plainContent.write(to: fileURL, atomically: true, encoding: .utf8)
                } catch {
                    throw DataManagerError.fileWriteFailed(path: fileURL.path)
                }
                return fileURL

            case .html:
                let htmlContent = convertToHTML(content, title: item.title, author: item.author)
                guard !htmlContent.isEmpty else {
                    throw DataManagerError.htmlConversionFailed(reason: "Generated HTML content is empty")
                }
                let fileURL = tempDir.appendingPathComponent("\(fileName).html")
                do {
                    try htmlContent.write(to: fileURL, atomically: true, encoding: .utf8)
                } catch {
                    throw DataManagerError.fileWriteFailed(path: fileURL.path)
                }
                return fileURL

            case .pdf:
                let pdfURL = tempDir.appendingPathComponent("\(fileName).pdf")
                do {
                    try generatePDF(content: content, title: item.title, author: item.author, to: pdfURL)
                } catch let error as DataManagerError {
                    throw error
                } catch {
                    throw DataManagerError.pdfGenerationFailed(reason: error.localizedDescription)
                }
                return pdfURL

            case .docx:
                let docxURL = tempDir.appendingPathComponent("\(fileName).docx")
                do {
                    try generateDOCX(content: content, title: item.title, author: item.author, to: docxURL)
                } catch let error as DataManagerError {
                    throw error
                } catch {
                    throw DataManagerError.docxGenerationFailed(reason: error.localizedDescription)
                }
                return docxURL
            }
        } catch let error as DataManagerError {
            throw error
        } catch {
            throw DataManagerError.exportFailed(reason: error.localizedDescription)
        }
    }

    private func stripMarkdown(from content: String) -> String {
        var result = content

        // Remove all block markers using regex
        result = result.replacingOccurrences(of: "\\[/?[A-Z_]+:?[^\\]]*\\]", with: "", options: .regularExpression)

        // Remove headers
        result = result.replacingOccurrences(of: "#{1,6}\\s+", with: "", options: .regularExpression)

        // Remove bold/italic
        result = result.replacingOccurrences(of: "\\*{1,2}([^*]+)\\*{1,2}", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "_{1,2}([^_]+)_{1,2}", with: "$1", options: .regularExpression)

        // Remove links
        result = result.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^)]+\\)", with: "$1", options: .regularExpression)

        // Remove code blocks
        result = result.replacingOccurrences(of: "```[^`]*```", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "`([^`]+)`", with: "$1", options: .regularExpression)

        // Remove box drawing characters
        result = result.replacingOccurrences(of: "┌", with: "")
        result = result.replacingOccurrences(of: "├", with: "")
        result = result.replacingOccurrences(of: "└", with: "")
        result = result.replacingOccurrences(of: "│", with: "")
        result = result.replacingOccurrences(of: "─", with: "")
        result = result.replacingOccurrences(of: "┐", with: "")
        result = result.replacingOccurrences(of: "┤", with: "")
        result = result.replacingOccurrences(of: "┘", with: "")
        result = result.replacingOccurrences(of: "↓", with: "")
        result = result.replacingOccurrences(of: "→", with: "")
        result = result.replacingOccurrences(of: "←", with: "")
        result = result.replacingOccurrences(of: "↑", with: "")

        // Remove double-line box drawing dividers (═══)
        result = result.replacingOccurrences(of: "═", with: "")

        // Clean up any resulting multiple blank lines
        result = result.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)

        return result
    }

    // MARK: - Filename Helpers

    /// Sanitize filename to be clean and readable with proper Title Case
    /// Follows the format: [Book Title] - Insight Atlas Guide
    private func sanitizeFilename(_ title: String) -> String {
        // Remove invalid filename characters
        var sanitized = title

        // Characters not allowed in filenames
        let invalidChars = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        sanitized = sanitized.components(separatedBy: invalidChars).joined(separator: "")

        // Trim whitespace and normalize multiple spaces to single space
        sanitized = sanitized.trimmingCharacters(in: .whitespaces)
        sanitized = sanitized.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        // Ensure the title is not empty
        if sanitized.isEmpty {
            sanitized = "Untitled"
        }

        return sanitized
    }

    // MARK: - HTML Conversion Helpers

    /// Calculate dynamic reading time based on word count
    private func calculateReadingTime(from content: String) -> Int {
        let wordsPerMinute = 225.0
        let wordCount = Double(content.split(whereSeparator: { $0.isWhitespace }).count)
        return max(1, Int(ceil(wordCount / wordsPerMinute)))
    }

    /// Get the Insight Atlas logo as a base64-encoded data URL for HTML embedding
    private func getLogoBase64() -> String? {
        guard let logoImage = UIImage(named: "Logo"),
              let pngData = logoImage.pngData() else {
            return nil
        }
        let base64 = pngData.base64EncodedString()
        return "data:image/png;base64,\(base64)"
    }

    /// Get the Insight Atlas logo UIImage for PDF rendering
    private func getLogoImage() -> UIImage? {
        return UIImage(named: "Logo")
    }

    private func detectBlockStart(_ line: String) -> String? {
        let blockStarts: [(String, String)] = [
            ("[QUICK_GLANCE]", "quick-glance"),
            ("[INSIGHT_NOTE]", "insight-note"),
            ("[ALTERNATIVE_PERSPECTIVE]", "alternative-perspective"),
            ("[RESEARCH_INSIGHT]", "research-insight"),
            ("[ACTION_BOX", "action-box"),
            ("[QUOTE]", "quote"),
            ("[VISUAL_FLOWCHART", "visual-flowchart"),
            ("[VISUAL_TABLE", "visual-table"),
            ("[PROCESS_TIMELINE]", "process-timeline"),
            ("[CONCEPT_MAP]", "concept-map"),
            ("[EXERCISE_", "exercise"),
            ("[FOUNDATIONAL_NARRATIVE]", "foundational-narrative"),
            ("[STRUCTURE_MAP]", "structure-map"),
            ("[TAKEAWAYS]", "takeaways"),
            // Premium block types
            ("[PREMIUM_QUOTE]", "premium-quote"),
            ("[AUTHOR_SPOTLIGHT]", "author-spotlight"),
            ("[PREMIUM_DIVIDER]", "premium-divider"),
            ("[PREMIUM_H1]", "premium-h1"),
            ("[PREMIUM_H2]", "premium-h2")
        ]
        for (marker, type) in blockStarts {
            if line.hasPrefix(marker) {
                return type
            }
        }
        return nil
    }

    private func detectBlockEnd(_ line: String) -> Bool {
        let endMarkers = ["[/QUICK_GLANCE]", "[/INSIGHT_NOTE]", "[/ACTION_BOX]", "[/QUOTE]",
                          "[/VISUAL_FLOWCHART]", "[/VISUAL_TABLE]", "[/EXERCISE_",
                          "[/FOUNDATIONAL_NARRATIVE]", "[/STRUCTURE_MAP]", "[/TAKEAWAYS]",
                          "[/PROCESS_TIMELINE]", "[/CONCEPT_MAP]",
                          // Premium block end markers
                          "[/PREMIUM_QUOTE]", "[/AUTHOR_SPOTLIGHT]", "[/PREMIUM_DIVIDER]",
                          "[/PREMIUM_H1]", "[/PREMIUM_H2]",
                          // Additional note box types
                          "[/ALTERNATIVE_PERSPECTIVE]", "[/RESEARCH_INSIGHT]"]
        return endMarkers.contains { line.hasPrefix($0) }
    }

    /// Validation result for markdown content
    struct MarkdownValidationResult {
        let isValid: Bool
        let unclosedBlocks: [String]
        let unmatchedEndMarkers: [String]
        let warnings: [String]
    }

    /// Validates markdown content for proper block marker matching
    func validateMarkdown(_ content: String) -> MarkdownValidationResult {
        var openBlocks: [(type: String, line: Int)] = []
        var unmatchedEndMarkers: [String] = []
        var warnings: [String] = []

        let lines = content.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lineNumber = index + 1

            if let blockType = detectBlockStart(trimmed) {
                openBlocks.append((type: blockType, line: lineNumber))
            }

            if detectBlockEnd(trimmed) {
                if openBlocks.isEmpty {
                    unmatchedEndMarkers.append("Line \(lineNumber): \(trimmed)")
                } else {
                    openBlocks.removeLast()
                }
            }
        }

        let unclosedBlocks = openBlocks.map { "'\($0.type)' opened at line \($0.line)" }

        if !unclosedBlocks.isEmpty {
            warnings.append("Found \(unclosedBlocks.count) unclosed block(s)")
        }
        if !unmatchedEndMarkers.isEmpty {
            warnings.append("Found \(unmatchedEndMarkers.count) unmatched end marker(s)")
        }

        return MarkdownValidationResult(
            isValid: unclosedBlocks.isEmpty && unmatchedEndMarkers.isEmpty,
            unclosedBlocks: unclosedBlocks,
            unmatchedEndMarkers: unmatchedEndMarkers,
            warnings: warnings
        )
    }

    private func renderSpecialBlock(type: String, content: [String], fullContent: String = "") -> String {
        let processedContent = content
            .filter { !$0.isEmpty }
            .map { convertInlineMarkdown($0) }

        let headers: [String: (icon: String, title: String)] = [
            "quick-glance": ("👁", "QUICK GLANCE"),
            "insight-note": ("💡", "INSIGHT ATLAS NOTE"),
            "alternative-perspective": ("⚖️", "ALTERNATIVE PERSPECTIVE"),
            "research-insight": ("🔬", "RESEARCH INSIGHT"),
            "action-box": ("✓", "APPLY IT"),
            "visual-flowchart": ("📊", "VISUAL GUIDE"),
            "visual-table": ("📋", "REFERENCE TABLE"),
            "process-timeline": ("⟶", "PROCESS TIMELINE"),
            "concept-map": ("🗺️", "CONCEPT MAP"),
            "exercise": ("✏️", "EXERCISE"),
            "foundational-narrative": ("📖", "THE STORY BEHIND THE IDEAS"),
            "structure-map": ("🗺️", "STRUCTURE MAP"),
            "takeaways": ("⭐", "KEY TAKEAWAYS")
        ]

        if type == "quote" {
            return "<blockquote>\(processedContent.joined(separator: "<br>"))</blockquote>"
        }

        // Handle premium block types with special rendering
        if type == "premium-quote" {
            return renderPremiumQuoteHTML(content: content)
        }
        if type == "author-spotlight" {
            return renderAuthorSpotlightHTML(content: content)
        }
        if type == "premium-divider" {
            return renderPremiumDividerHTML()
        }
        if type == "premium-h1" {
            let title = content.first ?? ""
            return renderPremiumH1HTML(title: title)
        }
        if type == "premium-h2" {
            let title = content.first ?? ""
            return renderPremiumH2HTML(title: title)
        }

        // Handle INSIGHT_NOTE with structured formatting
        if type == "insight-note" {
            return renderInsightNoteHTML(content: content)
        }

        let header = headers[type] ?? ("", type.uppercased())
        var contentHTML: String

        if type == "visual-flowchart" {
            // For flowcharts, render as styled steps with arrows
            contentHTML = renderFlowchartContent(processedContent)
        } else if type == "process-timeline" {
            // For process timeline, render as numbered timeline steps
            contentHTML = renderProcessTimelineContent(processedContent)
        } else if type == "concept-map" {
            // For concept maps, render central concept with related nodes
            contentHTML = renderConceptMapContent(content.joined(separator: "\n"))
        } else if type == "structure-map" {
            // For structure maps, check if content contains table format
            let hasTable = content.contains { $0.hasPrefix("|") }
            if hasTable {
                contentHTML = renderStructureMapContent(content)
            } else {
                contentHTML = renderBlockContent(content)
            }
        } else if type == "visual-table" {
            // For tables within blocks, render as styled table
            contentHTML = renderBlockTableContent(processedContent)
        } else if type == "quick-glance" {
            // For Quick Glance, add dynamic reading time badge
            let readingTime = calculateReadingTime(from: fullContent)
            let badge = "<div class=\"reading-time-badge\">\(readingTime) min read</div>"
            contentHTML = badge + renderBlockContent(content)
            // Remove any hardcoded "Read time:" lines (both converted HTML and raw markdown versions)
            contentHTML = contentHTML.replacingOccurrences(of: "<p><em>Read time: \\d+ minutes?</em></p>", with: "", options: .regularExpression)
            contentHTML = contentHTML.replacingOccurrences(of: "<p>\\*Read time: \\d+ minutes?\\*</p>", with: "", options: .regularExpression)
        } else {
            // For other blocks, render as formatted paragraphs/lists
            contentHTML = renderBlockContent(content)
        }

        return """
        <div class="\(type)">
            <div class="block-header">\(header.icon) \(header.title)</div>
            <div class="block-content">\(contentHTML)</div>
        </div>
        """
    }

    // MARK: - Premium Block HTML Renderers

    /// Render premium quote with coral border and decorative quotation mark
    private func renderPremiumQuoteHTML(content: [String]) -> String {
        // Parse content: first lines are the quote, last line starting with "—" or "-" is attribution
        var quoteLines: [String] = []
        var attribution: String? = nil
        var source: String? = nil

        for line in content {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("—") || trimmed.hasPrefix("-") {
                // This is attribution
                let attrText = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                // Check if there's a source in parentheses or after comma
                if let parenRange = attrText.range(of: "(") {
                    attribution = String(attrText[..<parenRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    source = String(attrText[parenRange.lowerBound...]).replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
                } else if let commaRange = attrText.range(of: ",") {
                    attribution = String(attrText[..<commaRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    source = String(attrText[commaRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                } else {
                    attribution = attrText
                }
            } else if !trimmed.isEmpty {
                quoteLines.append(convertInlineMarkdown(trimmed))
            }
        }

        let quoteText = quoteLines.joined(separator: "<br>")
        var attributionHTML = ""
        if let attr = attribution {
            attributionHTML = "<cite>\(attr)"
            if let src = source {
                attributionHTML += "<span class=\"premium-quote-source\">\(src)</span>"
            }
            attributionHTML += "</cite>"
        }

        return """
        <div class="premium-quote">
            <div class="premium-quote-mark">"</div>
            <blockquote>
                <p>\(quoteText)</p>
                \(attributionHTML)
            </blockquote>
        </div>
        """
    }

    /// Render author spotlight with double gold border
    private func renderAuthorSpotlightHTML(content: [String]) -> String {
        // Parse content: look for author name and description
        var authorName: String? = nil
        var descriptionLines: [String] = []

        for line in content {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            // First non-empty line is typically the author name
            if authorName == nil {
                authorName = trimmed
            } else {
                descriptionLines.append(convertInlineMarkdown(trimmed))
            }
        }

        let description = descriptionLines.joined(separator: "<br>")

        return """
        <div class="author-spotlight">
            <div class="author-spotlight-header">
                <span class="author-spotlight-icon">📖</span>
                <span class="author-spotlight-label">ABOUT THE AUTHOR</span>
            </div>
            <h3 class="author-spotlight-name">\(authorName ?? "")</h3>
            <p class="author-spotlight-bio">\(description)</p>
        </div>
        """
    }

    /// Render premium section divider with diamond ornaments
    private func renderPremiumDividerHTML() -> String {
        return """
        <div class="premium-divider">
            <span class="premium-divider-line"></span>
            <span class="premium-divider-diamond">◆</span>
            <span class="premium-divider-diamond-outline">◇</span>
            <span class="premium-divider-diamond">◆</span>
            <span class="premium-divider-line"></span>
        </div>
        """
    }

    /// Render premium H1 header with diamond ornaments
    private func renderPremiumH1HTML(title: String) -> String {
        return """
        <div class="premium-h1">
            <div class="premium-h1-ornaments">
                <span class="diamond-filled">◆</span>
                <span class="diamond-outline">◇</span>
                <span class="diamond-filled">◆</span>
            </div>
            <h1>\(convertInlineMarkdown(title.uppercased()))</h1>
            <div class="premium-h1-ornaments">
                <span class="diamond-filled">◆</span>
                <span class="diamond-outline">◇</span>
                <span class="diamond-filled">◆</span>
            </div>
        </div>
        """
    }

    /// Render premium H2 header with gold bar
    private func renderPremiumH2HTML(title: String) -> String {
        return """
        <div class="premium-h2">
            <span class="premium-h2-bar"></span>
            <h2>\(convertInlineMarkdown(title))</h2>
        </div>
        """
    }

    /// Render INSIGHT ATLAS NOTE with structured formatting for Key Distinction, Practical Implication, Go Deeper
    private func renderInsightNoteHTML(content: [String]) -> String {
        var coreConnection: [String] = []
        var keyDistinction: String? = nil
        var practicalImplication: String? = nil
        var goDeeper: String? = nil

        // Join content to handle multi-line parsing
        let fullContent = content.joined(separator: "\n")

        // Parse structured sections using regex patterns
        // Pattern for **Key Distinction:** or Key Distinction:
        let keyDistinctionPattern = #"\*{0,2}Key Distinction:?\*{0,2}\s*(.+?)(?=\*{0,2}Practical Implication|\*{0,2}Go Deeper|$)"#
        let practicalImplicationPattern = #"\*{0,2}Practical Implication:?\*{0,2}\s*(.+?)(?=\*{0,2}Go Deeper|$)"#
        let goDeepPattern = #"\*{0,2}Go Deeper:?\*{0,2}\s*(.+?)$"#

        // Extract Key Distinction
        if let keyMatch = fullContent.range(of: keyDistinctionPattern, options: [.regularExpression, .caseInsensitive]) {
            var matched = String(fullContent[keyMatch])
            // Clean up the prefix
            matched = matched.replacingOccurrences(of: #"^\*{0,2}Key Distinction:?\*{0,2}\s*"#, with: "", options: .regularExpression)
            keyDistinction = matched.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Extract Practical Implication
        if let practicalMatch = fullContent.range(of: practicalImplicationPattern, options: [.regularExpression, .caseInsensitive]) {
            var matched = String(fullContent[practicalMatch])
            matched = matched.replacingOccurrences(of: #"^\*{0,2}Practical Implication:?\*{0,2}\s*"#, with: "", options: .regularExpression)
            practicalImplication = matched.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Extract Go Deeper
        if let goMatch = fullContent.range(of: goDeepPattern, options: [.regularExpression, .caseInsensitive]) {
            var matched = String(fullContent[goMatch])
            matched = matched.replacingOccurrences(of: #"^\*{0,2}Go Deeper:?\*{0,2}\s*"#, with: "", options: .regularExpression)
            goDeeper = matched.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Extract core connection (everything before the first structured section)
        var coreText = fullContent
        if let keyRange = fullContent.range(of: #"\*{0,2}Key Distinction"#, options: [.regularExpression, .caseInsensitive]) {
            coreText = String(fullContent[..<keyRange.lowerBound])
        }
        coreConnection = [coreText.trimmingCharacters(in: .whitespacesAndNewlines)]

        // Build HTML output with proper structure
        var html = """
        <div class="insight-note">
            <div class="block-header">💡 INSIGHT ATLAS NOTE</div>
            <div class="block-content">
        """

        // Core connection paragraph
        if !coreConnection.isEmpty && !coreConnection[0].isEmpty {
            html += "<p class=\"core-connection\">\(convertInlineMarkdown(coreConnection[0]))</p>"
        }

        // Key Distinction section
        if let key = keyDistinction, !key.isEmpty {
            html += """
            <div class="insight-section key-distinction">
                <span class="insight-label">Key Distinction:</span>
                <span class="insight-text">\(convertInlineMarkdown(key))</span>
            </div>
            """
        }

        // Practical Implication section
        if let practical = practicalImplication, !practical.isEmpty {
            html += """
            <div class="insight-section practical-implication">
                <span class="insight-label">Practical Implication:</span>
                <span class="insight-text">\(convertInlineMarkdown(practical))</span>
            </div>
            """
        }

        // Go Deeper section
        if let deeper = goDeeper, !deeper.isEmpty {
            html += """
            <div class="insight-section go-deeper">
                <span class="insight-label">Go Deeper:</span>
                <span class="insight-text">\(convertInlineMarkdown(deeper))</span>
            </div>
            """
        }

        html += """
            </div>
        </div>
        """

        return html
    }

    private func renderStructureMapContent(_ lines: [String]) -> String {
        var tableHTML = "<table class=\"styled-table\"><tbody>"
        var hasHeaderRow = false

        for line in lines {
            // Skip header markers like "## Structure Map..."
            if line.hasPrefix("##") || line.hasPrefix("#") {
                continue
            }

            if line.hasPrefix("|") {
                let cells = line.dropFirst().dropLast()
                    .components(separatedBy: "|")
                    .map { $0.trimmingCharacters(in: .whitespaces) }

                // Skip separator rows
                if cells.allSatisfy({ $0.contains("---") || $0.contains("-") && $0.count < 5 }) {
                    continue
                }

                // First row becomes header
                if !hasHeaderRow {
                    tableHTML += "<thead><tr>"
                    for cell in cells {
                        tableHTML += "<th>\(convertInlineMarkdown(cell))</th>"
                    }
                    tableHTML += "</tr></thead>"
                    hasHeaderRow = true
                } else {
                    tableHTML += "<tr>"
                    for cell in cells {
                        tableHTML += "<td>\(convertInlineMarkdown(cell))</td>"
                    }
                    tableHTML += "</tr>"
                }
            }
        }

        tableHTML += "</tbody></table>"
        return tableHTML
    }

    private func renderFlowchartContent(_ lines: [String]) -> String {
        var steps: [String] = []
        for line in lines {
            let cleaned = line.trimmingCharacters(in: .whitespaces)
            if !cleaned.isEmpty && cleaned != "vs." {
                steps.append("<div class=\"flow-step\">\(cleaned)</div>")
            } else if cleaned == "vs." {
                steps.append("<div class=\"flow-separator\">vs.</div>")
            }
        }
        return "<div class=\"flow-container\">\(steps.joined(separator: "\n<div class=\"flow-arrow\">↓</div>\n"))</div>"
    }

    private func renderProcessTimelineContent(_ lines: [String]) -> String {
        var timelineHTML = "<div class=\"timeline-container\">"
        var stepNumber = 1

        for line in lines {
            let cleaned = line.trimmingCharacters(in: .whitespaces)
            if cleaned.isEmpty { continue }

            // Check if line has a time/phase marker (e.g., "Phase 1:", "Step 1:", "1.", "1)")
            var phase = ""
            var description = cleaned

            // Parse numbered formats: "1. Description" or "1) Description"
            if cleaned.range(of: #"^(\d+[\.\)])\s*(.+)$"#, options: .regularExpression) != nil {
                let components = cleaned.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
                if let num = components.first {
                    phase = "Step \(num)"
                    if let colonIndex = cleaned.firstIndex(where: { $0 == "." || $0 == ")" }) {
                        description = String(cleaned[cleaned.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                    }
                }
            }
            // Parse "Phase X:" or "Step X:" format
            else if let colonIndex = cleaned.firstIndex(of: ":") {
                let prefix = String(cleaned[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                if prefix.lowercased().hasPrefix("phase") || prefix.lowercased().hasPrefix("step") || prefix.lowercased().hasPrefix("stage") {
                    phase = prefix
                    description = String(cleaned[cleaned.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                }
            }

            // Default phase label if none detected
            if phase.isEmpty {
                phase = "Step \(stepNumber)"
            }

            timelineHTML += """
            <div class="timeline-step">
                <div class="timeline-marker">\(stepNumber)</div>
                <div class="timeline-content">
                    <div class="timeline-phase">\(phase)</div>
                    <div class="timeline-description">\(convertInlineMarkdown(description))</div>
                </div>
            </div>
            """
            stepNumber += 1
        }

        timelineHTML += "</div>"
        return timelineHTML
    }

    private func renderConceptMapContent(_ content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        var conceptsHTML = "<div class=\"concept-map-container\">"

        var centralConcept = ""
        var relatedConcepts: [(concept: String, relationship: String)] = []

        for line in lines {
            let cleaned = line.trimmingCharacters(in: .whitespaces)
            if cleaned.isEmpty { continue }

            // Detect central concept (usually first line or marked with "Central:" or similar)
            if centralConcept.isEmpty {
                if cleaned.lowercased().hasPrefix("central:") || cleaned.lowercased().hasPrefix("main:") || cleaned.lowercased().hasPrefix("core:") {
                    centralConcept = String(cleaned.dropFirst(cleaned.firstIndex(of: ":")!.utf16Offset(in: cleaned) + 1)).trimmingCharacters(in: .whitespaces)
                } else {
                    centralConcept = cleaned
                }
                continue
            }

            // Parse related concepts with relationships
            // Format: "→ Concept: relationship" or "- Concept (relationship)" or just "- Concept"
            var concept = cleaned
            var relationship = "relates to"

            // Remove leading markers
            if concept.hasPrefix("→") || concept.hasPrefix("-") || concept.hasPrefix("•") || concept.hasPrefix("*") {
                concept = String(concept.dropFirst()).trimmingCharacters(in: .whitespaces)
            }

            // Parse "Concept: relationship" format
            if let colonIndex = concept.firstIndex(of: ":") {
                let beforeColon = String(concept[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let afterColon = String(concept[concept.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                concept = beforeColon
                relationship = afterColon
            }
            // Parse "Concept (relationship)" format
            else if let parenStart = concept.firstIndex(of: "("), let parenEnd = concept.firstIndex(of: ")") {
                relationship = String(concept[concept.index(after: parenStart)..<parenEnd]).trimmingCharacters(in: .whitespaces)
                concept = String(concept[..<parenStart]).trimmingCharacters(in: .whitespaces)
            }

            relatedConcepts.append((concept: concept, relationship: relationship))
        }

        // Build the visual concept map
        conceptsHTML += """
        <div class="concept-central">
            <div class="concept-node central">\(convertInlineMarkdown(centralConcept))</div>
        </div>
        <div class="concept-connections">
        """

        for (index, item) in relatedConcepts.enumerated() {
            let position = index % 4 // Cycle through positions
            let positionClass = ["top-left", "top-right", "bottom-left", "bottom-right"][position]
            conceptsHTML += """
            <div class="concept-branch \(positionClass)">
                <div class="concept-line"></div>
                <div class="concept-relationship">\(item.relationship)</div>
                <div class="concept-node related">\(convertInlineMarkdown(item.concept))</div>
            </div>
            """
        }

        conceptsHTML += "</div></div>"
        return conceptsHTML
    }

    private func renderBlockTableContent(_ lines: [String]) -> String {
        var tableHTML = "<table class=\"styled-table\"><tbody>"
        for line in lines {
            if line.hasPrefix("|") {
                let cells = line.dropFirst().dropLast()
                    .components(separatedBy: "|")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                if !cells.allSatisfy({ $0.contains("---") || $0.contains("-") && $0.count < 5 }) {
                    tableHTML += "<tr>"
                    for cell in cells {
                        tableHTML += "<td>\(convertInlineMarkdown(cell))</td>"
                    }
                    tableHTML += "</tr>"
                }
            } else if !line.isEmpty {
                tableHTML += "<tr><td colspan=\"100%\">\(convertInlineMarkdown(line))</td></tr>"
            }
        }
        tableHTML += "</tbody></table>"
        return tableHTML
    }

    private func renderBlockContent(_ lines: [String]) -> String {
        var html: [String] = []
        var inList = false
        var listType = "" // "ul" or "ol"
        var currentParagraph: [String] = []
        var currentListItem: [String] = [] // Track multi-line list item content
        var inTable = false
        var tableRows: [[String]] = []

        // Helper to flush accumulated paragraph text
        func flushParagraph() {
            if !currentParagraph.isEmpty {
                let combinedText = currentParagraph.joined(separator: " ")
                html.append("<p>\(convertInlineMarkdown(combinedText))</p>")
                currentParagraph = []
            }
        }

        // Helper to flush the current list item
        func flushListItem() {
            if !currentListItem.isEmpty {
                let combinedText = currentListItem.joined(separator: " ")
                html.append("<li>\(convertInlineMarkdown(combinedText))</li>")
                currentListItem = []
            }
        }

        // Helper to close list properly
        func closeList() {
            if inList {
                flushListItem()
                html.append("</\(listType)>")
                inList = false
                listType = ""
            }
        }

        // Helper to flush table
        func flushTable() {
            if inTable && !tableRows.isEmpty {
                html.append(renderTable(rows: tableRows))
                tableRows = []
                inTable = false
            }
        }

        for line in lines {
            // Skip redundant headers inside blocks
            if line.hasPrefix("##") || line.hasPrefix("INSIGHT ATLAS NOTE") ||
               line.hasPrefix("APPLY IT") || line.hasPrefix("Quick Glance") {
                continue
            }

            // Handle table rows
            if line.hasPrefix("|") && line.hasSuffix("|") {
                flushParagraph()
                closeList()
                // Check if it's a separator row (skip it)
                if line.contains("---") || line.contains("|-") {
                    continue
                }
                let cells = line.dropFirst().dropLast()
                    .components(separatedBy: "|")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                inTable = true
                tableRows.append(cells)
                continue
            } else if inTable {
                // End of table
                flushTable()
            }

            // Handle unordered list items - with space after marker
            if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
                flushParagraph()
                flushListItem()
                if !inList || listType != "ul" {
                    closeList()
                    html.append("<ul>")
                    inList = true
                    listType = "ul"
                }
                let text = String(line.dropFirst(2))
                currentListItem.append(text)
            }
            // Handle unordered list items - without space after marker
            else if line.hasPrefix("-") || line.hasPrefix("*") || line.hasPrefix("•") {
                flushParagraph()
                flushListItem()
                if !inList || listType != "ul" {
                    closeList()
                    html.append("<ul>")
                    inList = true
                    listType = "ul"
                }
                let text = String(line.dropFirst(1)).trimmingCharacters(in: .whitespaces)
                currentListItem.append(text)
            }
            // Handle ordered list items - with space
            else if let _ = line.range(of: "^\\d+\\.\\s+", options: .regularExpression) {
                flushParagraph()
                flushListItem()
                if !inList || listType != "ol" {
                    closeList()
                    html.append("<ol>")
                    inList = true
                    listType = "ol"
                }
                let text = line.replacingOccurrences(of: "^\\d+\\.\\s+", with: "", options: .regularExpression)
                currentListItem.append(text)
            }
            // Handle ordered list items - without space (e.g., "1.Item")
            else if let _ = line.range(of: "^\\d+\\.", options: .regularExpression) {
                flushParagraph()
                flushListItem()
                if !inList || listType != "ol" {
                    closeList()
                    html.append("<ol>")
                    inList = true
                    listType = "ol"
                }
                let text = line.replacingOccurrences(of: "^\\d+\\.", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
                currentListItem.append(text)
            }
            // Regular text - check if it's a continuation of a list item
            else if inList && !line.isEmpty {
                // This is a continuation of the current list item
                currentListItem.append(line)
            }
            // Empty line handling
            else if line.isEmpty {
                // Empty lines inside a list just flush the current item but keep list open
                // Don't close the list on empty lines - let subsequent non-list content close it
                if inList {
                    flushListItem()
                    // Keep list open - it will be closed when we hit non-list content
                } else if !currentParagraph.isEmpty {
                    // Empty line outside list - flush current paragraph
                    flushParagraph()
                }
            }
            // Regular text outside of list
            else {
                closeList()
                // Check if this looks like a continuation of the previous line
                // A line is a continuation if:
                // - It starts with lowercase OR
                // - The previous line doesn't end with sentence-ending punctuation OR
                // - The line starts with common continuations (name, etc.)
                let startsWithLowercase = line.first?.isLowercase == true
                let previousEndsWithPunctuation = currentParagraph.last?.last.map { ".!?:".contains($0) } ?? false
                let isContinuation = startsWithLowercase ||
                    (!currentParagraph.isEmpty && !previousEndsWithPunctuation)

                if isContinuation && !currentParagraph.isEmpty {
                    // Continuation of previous paragraph
                    currentParagraph.append(line)
                } else {
                    // New paragraph
                    flushParagraph()
                    currentParagraph.append(line)
                }
            }
        }

        // Flush any remaining content
        flushParagraph()
        closeList()
        flushTable()

        return html.joined(separator: "\n")
    }

    private func closeListIfNeeded(_ htmlLines: inout [String], _ inList: inout Bool, _ listType: inout String) {
        if inList && !listType.isEmpty {
            htmlLines.append("</\(listType)>")
            inList = false
            listType = ""
        }
    }

    /// Escapes HTML special characters to prevent XSS attacks
    private func escapeHTML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private func convertInlineMarkdown(_ text: String) -> String {
        // First escape HTML to prevent XSS, then apply markdown formatting
        var result = escapeHTML(text)

        // Convert bold (must come before italic)
        // Use a more robust pattern that handles multi-word bold text
        result = result.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*",
                                              with: "<strong>$1</strong>",
                                              options: .regularExpression)

        // Convert italic (non-greedy to handle multiple italics on same line)
        result = result.replacingOccurrences(of: "\\*(.+?)\\*",
                                              with: "<em>$1</em>",
                                              options: .regularExpression)
        result = result.replacingOccurrences(of: "_(.+?)_",
                                              with: "<em>$1</em>",
                                              options: .regularExpression)

        // Convert inline code
        result = result.replacingOccurrences(of: "`([^`]+)`",
                                              with: "<code>$1</code>",
                                              options: .regularExpression)

        // Convert links - validate URL to prevent javascript: injection
        result = result.replacingOccurrences(of: "\\[([^\\]]+)\\]\\(([^)]+)\\)",
                                              with: "<a href=\"$2\">$1</a>",
                                              options: .regularExpression)

        // Remove any javascript: URLs that might have been injected
        result = result.replacingOccurrences(of: "href=\"javascript:[^\"]*\"",
                                              with: "href=\"#\"",
                                              options: [.regularExpression, .caseInsensitive])

        return result
    }

    private func renderTable(rows: [[String]]) -> String {
        guard !rows.isEmpty else { return "" }

        var html = "<table class=\"styled-table\">"

        // First row is header
        if let headerRow = rows.first {
            html += "<thead><tr>"
            for cell in headerRow {
                html += "<th>\(convertInlineMarkdown(cell))</th>"
            }
            html += "</tr></thead>"
        }

        // Remaining rows are body
        if rows.count > 1 {
            html += "<tbody>"
            for (index, row) in rows.dropFirst().enumerated() {
                let rowClass = index % 2 == 0 ? "even-row" : "odd-row"
                html += "<tr class=\"\(rowClass)\">"
                for cell in row {
                    html += "<td>\(convertInlineMarkdown(cell))</td>"
                }
                html += "</tr>"
            }
            html += "</tbody>"
        }

        html += "</table>"
        return html
    }

    private func convertToHTML(_ markdown: String, title: String, author: String) -> String {
        // Parse markdown line by line for proper conversion
        let lines = markdown.components(separatedBy: "\n")
        var htmlLines: [String] = []
        var inList = false
        var listType = "" // "ul" or "ol"
        var currentListItem: [String] = [] // Track multi-line list item content
        var inBlockquote = false
        var inCodeBlock = false
        var inSpecialBlock = false
        var specialBlockType = ""
        var specialBlockContent: [String] = []
        var inTable = false
        var tableRows: [[String]] = []
        var tocEntries: [(text: String, level: Int, id: String)] = [] // For Table of Contents
        var headingCounter = 0

        // Helper to flush current list item
        func flushListItem() {
            if !currentListItem.isEmpty {
                let combinedText = currentListItem.joined(separator: " ")
                htmlLines.append("<li>\(convertInlineMarkdown(combinedText))</li>")
                currentListItem = []
            }
        }

        // Helper to close list with proper flushing
        func closeListWithFlush() {
            if inList {
                flushListItem()
                htmlLines.append("</\(listType)>")
                inList = false
                listType = ""
            }
        }

        for line in lines {
            var processedLine = line

            // Remove box drawing characters
            for char in ["┌", "├", "└", "│", "─", "┐", "┤", "┘", "↓", "→", "←", "↑"] {
                processedLine = processedLine.replacingOccurrences(of: char, with: "")
            }

            let trimmed = processedLine.trimmingCharacters(in: .whitespaces)

            // Skip empty lines in special blocks
            if inSpecialBlock && trimmed.isEmpty {
                specialBlockContent.append("")
                continue
            }

            // Handle code blocks (```)
            if trimmed.hasPrefix("```") {
                inCodeBlock = !inCodeBlock
                continue
            }
            if inCodeBlock {
                continue // Skip code block content
            }

            // Handle special block markers
            if let blockStart = detectBlockStart(trimmed) {
                closeListWithFlush()
                inSpecialBlock = true
                specialBlockType = blockStart
                specialBlockContent = []
                continue
            }

            if detectBlockEnd(trimmed) {
                if inSpecialBlock {
                    let blockHTML = renderSpecialBlock(type: specialBlockType, content: specialBlockContent, fullContent: markdown)
                    htmlLines.append(blockHTML)
                }
                inSpecialBlock = false
                specialBlockType = ""
                specialBlockContent = []
                continue
            }

            if inSpecialBlock {
                specialBlockContent.append(trimmed)
                continue
            }

            // Skip horizontal rules and convert ═══ dividers to premium dividers
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                closeListWithFlush()
                htmlLines.append("<hr class=\"section-divider\">")
                continue
            }

            // Convert ═══ dividers to premium diamond ornament dividers
            // Catch any line that's primarily ═ characters (box drawing dividers)
            if trimmed.contains("═══") || trimmed.hasPrefix("═") ||
               (trimmed.count > 3 && trimmed.filter({ $0 == "═" }).count > trimmed.count / 2) {
                closeListWithFlush()
                htmlLines.append("<div class=\"premium-ornament-divider\"><span class=\"ornament\">◇ ◆ ◇</span></div>")
                continue
            }

            // Skip duplicate title headers that match the document title
            if trimmed.hasPrefix("# ") {
                let headerText = String(trimmed.dropFirst(2))
                if headerText.uppercased() == title.uppercased() ||
                   headerText.uppercased().contains(title.uppercased()) {
                    continue
                }
            }

            // Handle table rows
            if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") {
                closeListWithFlush()
                // Check if it's a separator row
                if trimmed.contains("---") || trimmed.contains("|-") {
                    continue
                }
                let cells = trimmed.dropFirst().dropLast()
                    .components(separatedBy: "|")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                if !inTable {
                    inTable = true
                    tableRows = []
                }
                tableRows.append(cells)
                continue
            } else if inTable {
                // End of table
                htmlLines.append(renderTable(rows: tableRows))
                inTable = false
                tableRows = []
            }

            // Handle blockquotes
            if trimmed.hasPrefix(">") {
                closeListWithFlush()
                let quoteContent = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                if !inBlockquote {
                    htmlLines.append("<blockquote>")
                    inBlockquote = true
                }
                htmlLines.append(convertInlineMarkdown(quoteContent))
                continue
            } else if inBlockquote {
                htmlLines.append("</blockquote>")
                inBlockquote = false
            }

            // Handle headers with IDs for TOC navigation
            if trimmed.hasPrefix("######") {
                closeListWithFlush()
                let text = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                headingCounter += 1
                let headingId = "section-\(headingCounter)"
                tocEntries.append((text: text, level: 6, id: headingId))
                htmlLines.append("<h6 id=\"\(headingId)\">\(convertInlineMarkdown(text))</h6>")
                continue
            }
            if trimmed.hasPrefix("#####") {
                closeListWithFlush()
                let text = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                headingCounter += 1
                let headingId = "section-\(headingCounter)"
                tocEntries.append((text: text, level: 5, id: headingId))
                htmlLines.append("<h5 id=\"\(headingId)\">\(convertInlineMarkdown(text))</h5>")
                continue
            }
            if trimmed.hasPrefix("####") {
                closeListWithFlush()
                let text = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                headingCounter += 1
                let headingId = "section-\(headingCounter)"
                tocEntries.append((text: text, level: 4, id: headingId))
                htmlLines.append("<h4 id=\"\(headingId)\">\(convertInlineMarkdown(text))</h4>")
                continue
            }
            if trimmed.hasPrefix("###") {
                closeListWithFlush()
                let text = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                headingCounter += 1
                let headingId = "section-\(headingCounter)"
                tocEntries.append((text: text, level: 3, id: headingId))
                htmlLines.append("<h3 id=\"\(headingId)\">\(convertInlineMarkdown(text))</h3>")
                continue
            }
            if trimmed.hasPrefix("##") {
                closeListWithFlush()
                let text = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                headingCounter += 1
                let headingId = "section-\(headingCounter)"
                tocEntries.append((text: text, level: 2, id: headingId))

                // Check if this is a PART header (PART I, PART II, etc.) - also detect at H2 level
                if text.uppercased().hasPrefix("PART ") {
                    htmlLines.append("""
                    <div class="premium-part-header" id="\(headingId)">
                        <div class="part-ornament">◇ ◆ ◇</div>
                        <h1 class="part-title">\(convertInlineMarkdown(text))</h1>
                        <div class="part-ornament">◇ ◆ ◇</div>
                    </div>
                    """)
                } else {
                    // Apply premium h2 styling with gold bar
                    htmlLines.append("<h2 id=\"\(headingId)\" class=\"premium-h2\">\(convertInlineMarkdown(text))</h2>")
                }
                continue
            }
            if trimmed.hasPrefix("# ") {
                closeListWithFlush()
                let text = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                headingCounter += 1
                let headingId = "section-\(headingCounter)"
                tocEntries.append((text: text, level: 1, id: headingId))

                // Check if this is a PART header (PART I, PART II, etc.)
                if text.uppercased().hasPrefix("PART ") {
                    htmlLines.append("""
                    <div class="premium-part-header" id="\(headingId)">
                        <div class="part-ornament">◇ ◆ ◇</div>
                        <h1 class="part-title">\(convertInlineMarkdown(text))</h1>
                        <div class="part-ornament">◇ ◆ ◇</div>
                    </div>
                    """)
                } else {
                    htmlLines.append("<h1 id=\"\(headingId)\">\(convertInlineMarkdown(text))</h1>")
                }
                continue
            }

            // Handle unordered list items - with space after marker
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("• ") {
                // Flush previous list item if any
                flushListItem()
                // If we're in an ordered list, close it first
                if inList && listType == "ol" {
                    closeListWithFlush()
                }
                if !inList {
                    htmlLines.append("<ul>")
                    inList = true
                    listType = "ul"
                }
                let text = String(trimmed.dropFirst(2))
                currentListItem.append(text)
                continue
            }

            // Handle unordered list items - without space after marker
            if trimmed.hasPrefix("-") || trimmed.hasPrefix("*") || trimmed.hasPrefix("•") {
                // Flush previous list item if any
                flushListItem()
                // If we're in an ordered list, close it first
                if inList && listType == "ol" {
                    closeListWithFlush()
                }
                if !inList {
                    htmlLines.append("<ul>")
                    inList = true
                    listType = "ul"
                }
                let text = String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces)
                currentListItem.append(text)
                continue
            }

            // Handle numbered list items - with space
            if let _ = trimmed.range(of: "^\\d+\\.\\s+", options: .regularExpression) {
                // Flush previous list item if any
                flushListItem()
                // If we're in an unordered list, close it first
                if inList && listType == "ul" {
                    closeListWithFlush()
                }
                if !inList {
                    htmlLines.append("<ol>")
                    inList = true
                    listType = "ol"
                }
                let text = trimmed.replacingOccurrences(of: "^\\d+\\.\\s+", with: "", options: .regularExpression)
                currentListItem.append(text)
                continue
            }

            // Handle numbered list items - without space (e.g., "1.Item")
            if let _ = trimmed.range(of: "^\\d+\\.", options: .regularExpression) {
                // Flush previous list item if any
                flushListItem()
                // If we're in an unordered list, close it first
                if inList && listType == "ul" {
                    closeListWithFlush()
                }
                if !inList {
                    htmlLines.append("<ol>")
                    inList = true
                    listType = "ol"
                }
                let text = trimmed.replacingOccurrences(of: "^\\d+\\.", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
                currentListItem.append(text)
                continue
            }

            // Check if this is a continuation of a list item
            if inList && !trimmed.isEmpty && !currentListItem.isEmpty {
                // This line is a continuation of the current list item
                currentListItem.append(trimmed)
                continue
            }

            // Handle empty lines - flush current item but keep list open
            if trimmed.isEmpty {
                if inList {
                    flushListItem()
                }
                continue
            }

            // Close list if we hit non-list content (actual paragraph text)
            if inList {
                closeListWithFlush()
            }

            // Handle regular paragraphs
            let converted = convertInlineMarkdown(trimmed)
            htmlLines.append("<p>\(converted)</p>")
        }

        // Close any open elements
        closeListWithFlush()
        if inBlockquote {
            htmlLines.append("</blockquote>")
        }
        if inTable {
            htmlLines.append(renderTable(rows: tableRows))
        }

        // Handle unclosed special blocks gracefully
        if inSpecialBlock && !specialBlockContent.isEmpty {
            // Log warning for debugging (in debug builds)
            #if DEBUG
            print("⚠️ Warning: Unclosed block marker for '\(specialBlockType)' - rendering content as-is")
            #endif
            // Render the unclosed block anyway to prevent content loss
            let blockHTML = renderSpecialBlock(type: specialBlockType, content: specialBlockContent, fullContent: markdown)
            htmlLines.append(blockHTML)
        }

        let html = htmlLines.joined(separator: "\n")

        return generatePremiumHTML(content: html, title: title, author: author, fullContent: markdown, tocEntries: tocEntries)
    }

    /// Generate premium HTML with 2026 design system, dark mode, and print styles
    private func generatePremiumHTML(content: String, title: String, author: String, fullContent: String, tocEntries: [(text: String, level: Int, id: String)] = []) -> String {
        let readingTime = calculateReadingTime(from: fullContent)

        // Generate Table of Contents HTML
        let tocHTML = generateHTMLTableOfContents(entries: tocEntries, readingTime: readingTime)

        // Generate logo image tags with base64 data
        let logoImageTag: String
        let footerLogoTag: String
        if let logoBase64 = getLogoBase64() {
            logoImageTag = "<img src=\"\(logoBase64)\" alt=\"Insight Atlas\" class=\"header-logo\">"
            footerLogoTag = "<img src=\"\(logoBase64)\" alt=\"Insight Atlas\" class=\"footer-logo\">"
        } else {
            logoImageTag = "" // Gracefully handle missing logo
            footerLogoTag = ""
        }

        return """
        <!DOCTYPE html>
        <html lang="en" dir="auto">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <meta name="color-scheme" content="light dark">
            <meta name="description" content="Premium book summary by Insight Atlas - Where Understanding Illuminates the World">
            <title>\(escapeHTML(title)) - Insight Atlas Guide</title>

            <!-- Google Fonts: Variable + Display + Handwritten -->
            <link rel="preconnect" href="https://fonts.googleapis.com">
            <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
            <link href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:ital,wght@0,400;0,500;0,600;0,700;1,400;1,500&family=Inter:wght@300..800&family=Caveat:wght@400;600&display=swap" rel="stylesheet">

            <style>
                /* ═══ INSIGHT ATLAS - PREMIUM 2026 EDITION ═══ */

                :root {
                    /* Brand Colors */
                    --brand-sepia: #5C4A3D;
                    --brand-parchment: #F5F3ED;
                    --brand-ink: #3D3229;
                    --gold: #CBA135;
                    --burgundy: #582534;
                    --coral: #E76F51;

                    /* Primary Palette - Premium Gold */
                    --primary-gold: #C9A227;
                    --primary-gold-light: #DCBE5E;
                    --primary-gold-dark: #A88A1F;
                    --primary-gold-subtle: rgba(203, 161, 53, 0.08);

                    /* Secondary Palette */
                    --accent-burgundy: #6B3A4A;
                    --accent-coral: #D4735C;
                    --accent-coral-text: #B54D35;  /* WCAG AA compliant for text */
                    --accent-teal: #2A8B7F;
                    --accent-teal-text: #1F6B62;   /* WCAG AA compliant for text */
                    --accent-orange: #E89B5A;
                    --accent-orange-text: #9A5A25; /* WCAG AA compliant for text */
                    --primary-gold-text: #8B7318;  /* WCAG AA compliant for text */

                    /* Text Colors - Master Template 2026 Brown/Sepia */
                    --text-heading: #2D2520;
                    --text-body: #3D3229;
                    --text-muted: #5C5248;
                    --text-subtle: #7A7168;
                    --text-inverse: #FDFCFA;

                    /* Background Colors - Master Template 2026 */
                    --bg-primary: #FDFCFA;
                    --bg-secondary: #F5F3ED;
                    --bg-card: #FFFFFF;
                    --bg-cream: #FEFCE8;

                    /* Border Colors - Master Template 2026 */
                    --border-light: #E8E4DC;
                    --border-medium: #D4CFC5;

                    /* Fonts */
                    --font-display: 'Cormorant Garamond', Georgia, serif;
                    --font-ui: 'Inter', -apple-system, sans-serif;
                    --font-handwritten: 'Caveat', cursive;

                    /* Spacing */
                    --content-width: 780px;
                    --radius-lg: 14px;
                    --radius-xl: 18px;
                }

                /* ═══ DARK MODE - Master Template 2026 ═══ */
                @media (prefers-color-scheme: dark) {
                    :root {
                        --text-heading: #F5F3ED;
                        --text-body: #E8E4DC;
                        --text-muted: #B8B0A3;
                        --text-subtle: #8A8178;

                        --bg-primary: #1A1816;
                        --bg-secondary: #242120;
                        --bg-card: #2A2725;
                        --bg-cream: #2A2725;

                        --border-light: #3D3A38;
                        --border-medium: #4A4744;

                        --primary-gold: #DCBE5E;
                        --primary-gold-text: #DCBE5E;  /* Light enough for dark mode */
                        --primary-gold-subtle: rgba(220, 190, 94, 0.12);

                        /* Lighter accent colors for dark mode - already WCAG compliant on dark bg */
                        --accent-coral: #E8927E;
                        --accent-coral-text: #E8927E;
                        --accent-teal: #4ABFB0;
                        --accent-teal-text: #4ABFB0;
                        --accent-orange-text: #F0B07A;
                    }

                    /* Dark mode SVG icon adjustments */
                    .insight-note .block-header::before {
                        background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%23E8927E' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M9 18h6'/%3E%3Cpath d='M10 22h4'/%3E%3Cpath d='M12 2a7 7 0 0 1 7 7c0 2.38-1.19 4.47-3 5.74V17a1 1 0 0 1-1 1H9a1 1 0 0 1-1-1v-2.26C6.19 13.47 5 11.38 5 9a7 7 0 0 1 7-7z'/%3E%3C/svg%3E");
                    }
                    .alternative-perspective .block-header::before {
                        background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%234ABFB0' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M12 3v18'/%3E%3Cpath d='M3 7l3 9h6l3-9'/%3E%3Cpath d='M15 7l3 9h6'/%3E%3Ccircle cx='6' cy='16' r='2'/%3E%3Ccircle cx='18' cy='16' r='2'/%3E%3Cpath d='M3 7h18'/%3E%3C/svg%3E");
                    }
                    .research-insight .block-header::before {
                        background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%23C9B896' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M9 3h6v6l3 9H6l3-9V3z'/%3E%3Cpath d='M9 3h6'/%3E%3Cpath d='M8 18h8'/%3E%3Cpath d='M10 21h4'/%3E%3Ccircle cx='10' cy='13' r='1'/%3E%3Ccircle cx='14' cy='15' r='1'/%3E%3C/svg%3E");
                    }

                    /* Adjust research insight color for dark mode */
                    .research-insight {
                        border-left-color: #C9B896;
                    }
                    .research-insight .block-header {
                        color: #C9B896;
                    }
                    .research-insight .block-content .author-highlight,
                    .research-insight .block-content strong[data-author] {
                        color: #C9B896;
                    }
                }

                /* ═══ REDUCED MOTION ═══ */
                @media (prefers-reduced-motion: reduce) {
                    *, *::before, *::after {
                        animation-duration: 0.01ms !important;
                        transition-duration: 0.01ms !important;
                    }
                }

                /* ═══ RTL LANGUAGE SUPPORT ═══ */
                [dir="rtl"] {
                    text-align: right;
                }
                [dir="rtl"] .insight-note,
                [dir="rtl"] .alternative-perspective,
                [dir="rtl"] .research-insight,
                [dir="rtl"] .action-box,
                [dir="rtl"] .key-takeaways,
                [dir="rtl"] .premium-quote {
                    border-left: none;
                    border-right: 4px solid var(--accent-coral);
                    padding-left: 1.5rem;
                    padding-right: 2rem;
                }
                [dir="rtl"] .alternative-perspective {
                    border-right-color: var(--accent-teal);
                }
                [dir="rtl"] .research-insight {
                    border-right-color: #B89D78;
                }
                [dir="rtl"] ul, [dir="rtl"] ol {
                    padding-right: 1.5rem;
                    padding-left: 0;
                }
                [dir="rtl"] blockquote {
                    border-left: none;
                    border-right: 3px solid var(--primary-gold);
                    padding-left: 0;
                    padding-right: 1.5rem;
                }

                /* ═══ BASE STYLES ═══ */
                *, *::before, *::after { box-sizing: border-box; }

                html {
                    font-size: 17px;
                    scroll-behavior: smooth;
                    -webkit-font-smoothing: antialiased;
                }

                body {
                    font-family: var(--font-display);
                    max-width: var(--content-width);
                    margin: 0 auto;
                    padding: 48px 24px;
                    line-height: 1.75;
                    font-size: 1.125rem;
                    color: var(--text-body);
                    background: var(--bg-primary);
                }

                ::selection {
                    background: rgba(201, 162, 39, 0.25);
                    color: var(--text-heading);
                }

                /* ═══ TYPOGRAPHY ═══ */
                h1, h2, h3, h4, h5, h6 {
                    font-family: var(--font-display);
                    font-weight: 600;
                    color: var(--text-heading);
                    margin-top: 3rem;
                    margin-bottom: 1rem;
                    line-height: 1.2;
                }

                h1 { font-size: clamp(2.25rem, 6vw, 3rem); font-weight: 700; margin-top: 0; }
                h2 {
                    font-size: 1.875rem;
                    position: relative;
                    padding-bottom: 0.75rem;
                }
                h2::after {
                    content: '';
                    position: absolute;
                    bottom: 0;
                    left: 0;
                    width: 60px;
                    height: 2px;
                    background: linear-gradient(90deg, var(--primary-gold), var(--accent-orange));
                    border-radius: 9999px;
                }
                h3 { font-size: 1.5rem; }
                h4 { font-size: 1.25rem; font-weight: 500; }

                p { margin: 0 0 1.25rem 0; }
                strong { color: var(--text-heading); font-weight: 600; }

                /* ═══ PREMIUM COVER PAGE ═══ */
                .cover-page {
                    min-height: 100vh;
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    justify-content: center;
                    text-align: center;
                    padding: 3rem 2rem;
                    margin: -48px -24px 3rem -24px;
                    background: linear-gradient(135deg, var(--bg-primary) 0%, var(--bg-secondary) 100%);
                    position: relative;
                    border-bottom: 3px solid var(--primary-gold);
                }
                .cover-page::before {
                    content: '';
                    position: absolute;
                    top: 24px;
                    left: 24px;
                    right: 24px;
                    bottom: 24px;
                    border: 1px solid var(--primary-gold);
                    border-radius: 4px;
                    pointer-events: none;
                }
                .cover-page::after {
                    content: '';
                    position: absolute;
                    top: 28px;
                    left: 28px;
                    right: 28px;
                    bottom: 28px;
                    border: 1px solid rgba(201, 162, 39, 0.3);
                    border-radius: 2px;
                    pointer-events: none;
                }

                .cover-top-tagline {
                    font-family: var(--font-ui);
                    font-size: 0.7rem;
                    font-weight: 500;
                    letter-spacing: 0.25em;
                    color: var(--brand-sepia);
                    text-transform: uppercase;
                    margin-bottom: 0.75rem;
                }

                .cover-divider {
                    width: 80px;
                    height: 1px;
                    background: var(--primary-gold);
                    margin: 0 auto 3rem auto;
                }

                .cover-logo {
                    width: 180px;
                    height: auto;
                    margin-bottom: 3rem;
                    opacity: 0.95;
                }

                .cover-logo-placeholder {
                    font-size: 4rem;
                    color: var(--primary-gold);
                    margin-bottom: 3rem;
                    line-height: 1;
                }

                .cover-title {
                    font-family: var(--font-display);
                    font-size: clamp(2.5rem, 8vw, 4rem);
                    font-weight: 700;
                    color: var(--text-heading);
                    line-height: 1.1;
                    margin: 0 0 1.5rem 0;
                    max-width: 600px;
                }

                .cover-by {
                    font-family: var(--font-display);
                    font-size: 1rem;
                    font-style: italic;
                    color: var(--text-muted);
                    margin-bottom: 0.25rem;
                }

                .cover-author {
                    font-family: var(--font-display);
                    font-size: 1.5rem;
                    font-weight: 500;
                    color: var(--text-body);
                    margin-bottom: 2rem;
                }

                .cover-small-divider {
                    width: 50px;
                    height: 1px;
                    background: var(--primary-gold);
                    margin: 0 auto 3rem auto;
                }

                .cover-brand {
                    font-family: var(--font-display);
                    font-size: 1.75rem;
                    font-weight: 600;
                    color: var(--primary-gold);
                    margin-bottom: 0.5rem;
                }

                .cover-subtitle {
                    font-family: var(--font-ui);
                    font-size: 0.65rem;
                    font-weight: 500;
                    letter-spacing: 0.2em;
                    color: var(--text-muted);
                    text-transform: uppercase;
                }

                /* Corner decorations */
                .cover-corner {
                    position: absolute;
                    width: 16px;
                    height: 16px;
                    border-color: var(--primary-gold);
                    border-style: solid;
                }
                .cover-corner.top-left { top: 36px; left: 36px; border-width: 1px 0 0 1px; }
                .cover-corner.top-right { top: 36px; right: 36px; border-width: 1px 1px 0 0; }
                .cover-corner.bottom-left { bottom: 36px; left: 36px; border-width: 0 0 1px 1px; }
                .cover-corner.bottom-right { bottom: 36px; right: 36px; border-width: 0 1px 1px 0; }

                /* ═══ DOCUMENT HEADER (for content section) ═══ */
                .document-header {
                    text-align: center;
                    margin-bottom: 4rem;
                    padding-bottom: 2.5rem;
                    position: relative;
                }
                .header {
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    gap: 0.25rem;
                }
                .header .brand {
                    font-family: var(--font-ui);
                    font-size: 0.7rem;
                    font-weight: 700;
                    letter-spacing: 0.2em;
                    text-transform: uppercase;
                    color: var(--primary-gold);
                }
                .document-header::after {
                    content: '';
                    position: absolute;
                    bottom: 0;
                    left: 50%;
                    transform: translateX(-50%);
                    width: 100px;
                    height: 2px;
                    background: linear-gradient(90deg, transparent, var(--primary-gold), transparent);
                }

                .header-logo {
                    width: 120px;
                    height: auto;
                    margin-bottom: 1rem;
                    opacity: 0.9;
                }

                .footer-logo {
                    width: 80px;
                    height: auto;
                    margin-bottom: 0.75rem;
                    opacity: 0.7;
                }

                .brand-badge {
                    display: inline-flex;
                    font-family: var(--font-ui);
                    font-size: 0.7rem;
                    font-weight: 600;
                    letter-spacing: 0.15em;
                    color: var(--primary-gold);
                    text-transform: uppercase;
                    margin-bottom: 1rem;
                    padding: 0.5rem 1.5rem;
                    border: 1px solid var(--primary-gold);
                    border-radius: 2px;
                    background: transparent;
                }

                .document-header h1 {
                    font-size: clamp(2.25rem, 7vw, 3.75rem);
                    margin: 1rem 0;
                    line-height: 1.1;
                }

                .document-header .subtitle {
                    font-size: 1.25rem;
                    color: var(--text-muted);
                    font-style: italic;
                    margin-top: 0.5rem;
                }

                .document-header .author {
                    font-family: var(--font-ui);
                    font-size: 0.875rem;
                    color: var(--text-subtle);
                    margin-top: 1.25rem;
                }

                .document-header .tagline {
                    font-family: var(--font-handwritten);
                    font-size: 1.25rem;
                    color: var(--accent-coral-text);
                    margin-top: 1rem;
                    transform: rotate(-1deg);
                    display: inline-block;
                }

                /* ═══ READING TIME BADGE ═══ */
                .reading-time-badge {
                    display: inline-flex;
                    align-items: center;
                    gap: 0.5rem;
                    background: linear-gradient(135deg, var(--primary-gold) 0%, var(--accent-orange) 100%);
                    color: var(--text-inverse);
                    font-family: var(--font-ui);
                    font-size: 0.75rem;
                    font-weight: 600;
                    padding: 0.5rem 1rem;
                    border-radius: 9999px;
                    letter-spacing: 0.02em;
                    box-shadow: 0 0 20px rgba(201, 162, 39, 0.25);
                }
                .reading-time-badge::before { content: '⏱'; }

                /* ═══ TABLE OF CONTENTS ═══ */
                .table-of-contents {
                    background: var(--bg-card);
                    border: 1px solid var(--border-light);
                    border-radius: var(--radius-xl);
                    padding: 2rem;
                    margin: 2.5rem 0;
                    box-shadow: 0 4px 24px rgba(45, 37, 32, 0.06);
                }
                .toc-header {
                    display: flex;
                    align-items: center;
                    gap: 0.75rem;
                    margin-bottom: 1.5rem;
                    padding-bottom: 1rem;
                    border-bottom: 2px solid var(--primary-gold);
                }
                .toc-header h2 {
                    margin: 0;
                    font-size: 1.5rem;
                    flex-grow: 1;
                }
                .toc-header h2::after { display: none; }
                .toc-icon {
                    font-size: 1.5rem;
                }
                .toc-list {
                    list-style: none;
                    padding: 0;
                    margin: 0;
                    counter-reset: toc-counter;
                }
                .toc-list li {
                    margin: 0;
                    padding: 0.5rem 0;
                    border-bottom: 1px solid var(--border-light);
                }
                .toc-list li:last-child {
                    border-bottom: none;
                }
                .toc-list li a {
                    display: flex;
                    align-items: center;
                    color: var(--text-body);
                    text-decoration: none;
                    border-bottom: none;
                    transition: color 0.2s, padding-left 0.2s;
                }
                .toc-list li a:hover {
                    color: var(--primary-gold);
                    padding-left: 0.5rem;
                }
                .toc-section {
                    font-weight: 600;
                    font-family: var(--font-display);
                    font-size: 1.1rem;
                }
                .toc-section::before {
                    counter-increment: toc-counter;
                    content: counter(toc-counter) ".";
                    margin-right: 0.75rem;
                    color: var(--primary-gold);
                    font-weight: 700;
                    min-width: 1.5rem;
                }
                .toc-subsection {
                    padding-left: 2rem;
                    font-size: 0.95rem;
                    font-weight: 400;
                }
                .toc-subsection::before {
                    content: "—";
                    margin-right: 0.5rem;
                    color: var(--text-muted);
                }

                /* ═══ QUICK GLANCE ═══ */
                .quick-glance {
                    background: var(--bg-card);
                    backdrop-filter: blur(20px);
                    border: 1px solid rgba(201, 162, 39, 0.15);
                    border-radius: var(--radius-xl);
                    padding: 2rem;
                    margin: 2.5rem 0;
                    box-shadow: 0 4px 24px rgba(45, 37, 32, 0.06);
                    position: relative;
                    overflow: hidden;
                }
                .quick-glance::before {
                    content: '';
                    position: absolute;
                    top: 0;
                    left: 0;
                    right: 0;
                    height: 3px;
                    background: linear-gradient(90deg, var(--primary-gold), var(--accent-orange), var(--primary-gold));
                }

                .block-header {
                    display: flex;
                    align-items: center;
                    gap: 0.75rem;
                    font-family: var(--font-ui);
                    font-weight: 600;
                    font-size: 0.875rem;
                    letter-spacing: 0.06em;
                    text-transform: uppercase;
                    margin-bottom: 1.25rem;
                    padding-bottom: 1rem;
                    border-bottom: 1px solid var(--border-light);
                }
                .quick-glance .block-header { color: var(--primary-gold-dark); }
                .quick-glance .block-header::before { content: '📋'; font-size: 1.125rem; }

                /* ═══ INSIGHT NOTE ═══ */
                .insight-note {
                    background: linear-gradient(135deg, rgba(212, 115, 92, 0.08) 0%, rgba(232, 155, 90, 0.1) 100%);
                    border: 1px solid rgba(212, 115, 92, 0.25);
                    border-left: 4px solid var(--accent-coral);
                    border-radius: var(--radius-lg);
                    padding: 1.5rem 1.5rem 1.5rem 2rem;
                    margin: 2rem 0;
                }
                .insight-note .block-header {
                    color: var(--accent-coral-text);
                    padding-bottom: 0.75rem;
                    border-bottom: none;
                }
                .insight-note .block-header::before {
                    content: '';
                    display: inline-block;
                    width: 24px;
                    height: 24px;
                    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%23D4735C' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M9 18h6'/%3E%3Cpath d='M10 22h4'/%3E%3Cpath d='M12 2a7 7 0 0 1 7 7c0 2.38-1.19 4.47-3 5.74V17a1 1 0 0 1-1 1H9a1 1 0 0 1-1-1v-2.26C6.19 13.47 5 11.38 5 9a7 7 0 0 1 7-7z'/%3E%3C/svg%3E");
                    background-size: contain;
                    background-repeat: no-repeat;
                }
                .insight-note .block-content p:last-child { margin-bottom: 0; }
                /* Author name highlighting in Insight Note */
                .insight-note .block-content .author-highlight,
                .insight-note .block-content strong[data-author] {
                    color: var(--accent-coral-text);
                    font-weight: 600;
                    letter-spacing: 0.02em;
                }
                /* Structured Insight Note sections */
                .insight-note .core-connection {
                    margin-bottom: 1rem;
                    line-height: 1.7;
                }
                .insight-note .insight-section {
                    margin-top: 0.875rem;
                    padding: 0.75rem 1rem;
                    background: rgba(212, 115, 92, 0.05);
                    border-radius: var(--radius-md);
                    border-left: 3px solid var(--accent-coral);
                }
                .insight-note .insight-label {
                    display: block;
                    font-family: var(--font-ui);
                    font-size: 0.75rem;
                    font-weight: 700;
                    text-transform: uppercase;
                    letter-spacing: 0.08em;
                    color: var(--accent-coral-text);
                    margin-bottom: 0.375rem;
                }
                .insight-note .insight-text {
                    display: block;
                    font-size: 0.95rem;
                    line-height: 1.6;
                    color: var(--text-body);
                }
                .insight-note .go-deeper {
                    background: rgba(212, 115, 92, 0.08);
                    border-left-color: var(--accent-coral);
                }
                .insight-note .go-deeper .insight-text {
                    font-style: italic;
                }
                .insight-note .go-deeper .insight-text em {
                    font-style: normal;
                    font-weight: 600;
                    color: var(--accent-coral-text);
                }

                /* ═══ ALTERNATIVE PERSPECTIVE ═══ */
                .alternative-perspective {
                    background: linear-gradient(135deg, rgba(42, 139, 127, 0.08) 0%, rgba(42, 139, 127, 0.05) 100%);
                    border: 1px solid rgba(42, 139, 127, 0.25);
                    border-left: 4px solid var(--accent-teal);
                    border-radius: var(--radius-lg);
                    padding: 1.5rem 1.5rem 1.5rem 2rem;
                    margin: 2rem 0;
                }
                .alternative-perspective .block-header {
                    color: var(--accent-teal);
                    padding-bottom: 0.75rem;
                    border-bottom: none;
                }
                .alternative-perspective .block-header::before {
                    content: '';
                    display: inline-block;
                    width: 24px;
                    height: 24px;
                    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%232A8B7F' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M12 3v18'/%3E%3Cpath d='M3 7l3 9h6l3-9'/%3E%3Cpath d='M15 7l3 9h6'/%3E%3Ccircle cx='6' cy='16' r='2'/%3E%3Ccircle cx='18' cy='16' r='2'/%3E%3Cpath d='M3 7h18'/%3E%3C/svg%3E");
                    background-size: contain;
                    background-repeat: no-repeat;
                }
                .alternative-perspective .block-content p:last-child { margin-bottom: 0; }
                /* Author name highlighting in Alternative Perspective */
                .alternative-perspective .block-content .author-highlight,
                .alternative-perspective .block-content strong[data-author] {
                    color: var(--accent-teal);
                    font-weight: 600;
                    letter-spacing: 0.02em;
                }

                /* ═══ RESEARCH INSIGHT ═══ */
                .research-insight {
                    background: linear-gradient(135deg, rgba(184, 157, 120, 0.12) 0%, rgba(184, 157, 120, 0.06) 100%);
                    border: 1px solid rgba(184, 157, 120, 0.35);
                    border-left: 4px solid #B89D78;
                    border-radius: var(--radius-lg);
                    padding: 1.5rem 1.5rem 1.5rem 2rem;
                    margin: 2rem 0;
                }
                .research-insight .block-header {
                    color: #8B7355;
                    padding-bottom: 0.75rem;
                    border-bottom: none;
                }
                .research-insight .block-header::before {
                    content: '';
                    display: inline-block;
                    width: 24px;
                    height: 24px;
                    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%238B7355' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M9 3h6v6l3 9H6l3-9V3z'/%3E%3Cpath d='M9 3h6'/%3E%3Cpath d='M8 18h8'/%3E%3Cpath d='M10 21h4'/%3E%3Ccircle cx='10' cy='13' r='1'/%3E%3Ccircle cx='14' cy='15' r='1'/%3E%3C/svg%3E");
                    background-size: contain;
                    background-repeat: no-repeat;
                }
                .research-insight .block-content p:last-child { margin-bottom: 0; }
                /* Author name highlighting in Research Insight */
                .research-insight .block-content .author-highlight,
                .research-insight .block-content strong[data-author] {
                    color: #B89D78;
                    font-weight: 600;
                    letter-spacing: 0.02em;
                }

                /* ═══ ACTION BOX ═══ */
                .action-box {
                    background: rgba(42, 139, 127, 0.08);
                    border: 2px solid rgba(42, 139, 127, 0.25);
                    border-radius: var(--radius-xl);
                    padding: 1.5rem 2rem;
                    margin: 2rem 0;
                }
                .action-box .block-header {
                    color: var(--accent-teal);
                    border-bottom: 1px solid rgba(42, 139, 127, 0.25);
                }
                .action-box .block-header::before {
                    content: '✓';
                    font-weight: 700;
                    width: 22px;
                    height: 22px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    background: var(--accent-teal);
                    color: var(--text-inverse);
                    border-radius: 9999px;
                    font-size: 0.75rem;
                }
                .action-box ol {
                    counter-reset: action-counter;
                    list-style: none;
                    padding-left: 0;
                }
                .action-box ol li {
                    counter-increment: action-counter;
                    padding-left: 2.5rem;
                    position: relative;
                    margin-bottom: 1rem;
                }
                .action-box ol li::before {
                    content: counter(action-counter);
                    position: absolute;
                    left: 0;
                    top: 2px;
                    width: 26px;
                    height: 26px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    background: linear-gradient(135deg, var(--accent-teal) 0%, #3BA396 100%);
                    color: var(--text-inverse);
                    font-family: var(--font-ui);
                    font-weight: 600;
                    font-size: 0.875rem;
                    border-radius: 9999px;
                }

                /* ═══ EXERCISE ═══ */
                .exercise {
                    background: linear-gradient(135deg, rgba(42, 139, 127, 0.08) 0%, rgba(42, 139, 127, 0.04) 100%);
                    border: 2px solid rgba(42, 139, 127, 0.25);
                    border-radius: var(--radius-xl);
                    padding: 2rem;
                    margin: 2.5rem 0;
                    position: relative;
                }
                .exercise::before {
                    content: '✏️';
                    position: absolute;
                    top: -15px;
                    right: -15px;
                    font-size: 70px;
                    opacity: 0.06;
                    transform: rotate(15deg);
                }
                .exercise .block-header {
                    color: var(--accent-teal);
                    border-bottom: 1px solid rgba(42, 139, 127, 0.25);
                }
                .exercise .block-header::before { content: '✏️'; font-size: 1.125rem; }

                /* ═══ TAKEAWAYS ═══ */
                .takeaways {
                    background: linear-gradient(135deg, rgba(74, 155, 127, 0.1) 0%, rgba(74, 155, 127, 0.04) 100%);
                    border: 2px solid rgba(74, 155, 127, 0.3);
                    border-radius: var(--radius-xl);
                    padding: 2rem;
                    margin: 2.5rem 0;
                }
                .takeaways .block-header {
                    color: #4A9B7F;
                    border-bottom: 1px solid rgba(74, 155, 127, 0.25);
                }
                .takeaways .block-header::before { content: '🎯'; font-size: 1.125rem; }

                /* ═══ FOUNDATIONAL NARRATIVE ═══ */
                .foundational-narrative {
                    background: linear-gradient(135deg, var(--bg-secondary) 0%, var(--brand-parchment) 100%);
                    border-left: 4px solid var(--primary-gold);
                    border-radius: 0 var(--radius-xl) var(--radius-xl) 0;
                    padding: 1.5rem 2rem;
                    margin: 2rem 0;
                }
                .foundational-narrative .block-header {
                    color: var(--brand-sepia);
                    border-bottom: 1px solid var(--border-medium);
                }
                .foundational-narrative .block-header::before { content: '📖'; font-size: 1.125rem; }

                /* ═══ VISUAL FLOWCHART ═══ */
                .visual-flowchart {
                    background: linear-gradient(135deg, var(--primary-gold-subtle) 0%, rgba(232, 155, 90, 0.1) 100%);
                    border: 2px solid rgba(201, 162, 39, 0.25);
                    border-radius: var(--radius-xl);
                    padding: 2rem;
                    margin: 2.5rem 0;
                }
                .visual-flowchart .block-header {
                    color: var(--primary-gold-dark);
                    border-bottom: 1px solid rgba(201, 162, 39, 0.25);
                }
                .visual-flowchart .block-header::before { content: '📊'; font-size: 1.125rem; }

                .flow-container {
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    gap: 0.5rem;
                }
                .flow-step {
                    width: 100%;
                    max-width: 380px;
                    padding: 1rem 1.5rem;
                    background: var(--bg-card);
                    border: 2px solid rgba(201, 162, 39, 0.25);
                    border-radius: var(--radius-lg);
                    font-family: var(--font-ui);
                    font-weight: 500;
                    font-size: 1rem;
                    color: var(--text-heading);
                    text-align: center;
                    box-shadow: 0 2px 4px rgba(45, 37, 32, 0.04);
                }
                .flow-arrow {
                    color: var(--primary-gold);
                    font-size: 1.5rem;
                    font-weight: 700;
                }

                /* ═══ VISUAL TABLE ═══ */
                .visual-table {
                    background: linear-gradient(135deg, var(--bg-card) 0%, var(--bg-secondary) 100%);
                    border: 1px solid var(--border-medium);
                    border-radius: var(--radius-xl);
                    padding: 2rem;
                    margin: 2.5rem 0;
                }
                .visual-table .block-header {
                    color: var(--primary-gold-dark);
                    border-bottom: 1px solid var(--border-light);
                }
                .visual-table .block-header::before { content: '📋'; font-size: 1.125rem; }

                /* ═══ PROCESS TIMELINE ═══ */
                .process-timeline {
                    background: linear-gradient(135deg, var(--bg-secondary) 0%, var(--bg-card) 100%);
                    border: 1px solid var(--border-medium);
                    border-radius: var(--radius-xl);
                    padding: 2rem;
                    margin: 2.5rem 0;
                }
                .process-timeline .block-header {
                    color: var(--primary-gold-dark);
                    border-bottom: 1px solid var(--border-light);
                }
                .process-timeline .block-header::before { content: '⟶'; font-size: 1.125rem; }
                .timeline-container {
                    display: flex;
                    flex-direction: column;
                    gap: 1.5rem;
                    padding-top: 1rem;
                }
                .timeline-step {
                    display: flex;
                    align-items: flex-start;
                    gap: 1rem;
                }
                .timeline-number {
                    width: 36px;
                    height: 36px;
                    border-radius: 50%;
                    background: linear-gradient(135deg, var(--primary-gold) 0%, var(--accent-orange) 100%);
                    color: white;
                    font-family: var(--font-ui);
                    font-weight: 700;
                    font-size: 1rem;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    flex-shrink: 0;
                    box-shadow: 0 2px 6px rgba(201, 162, 39, 0.3);
                }
                .timeline-content {
                    flex: 1;
                    padding-top: 0.5rem;
                }
                .timeline-content p {
                    margin: 0;
                    font-family: var(--font-ui);
                    font-weight: 500;
                    color: var(--text-heading);
                }
                .timeline-connector {
                    width: 2px;
                    height: 24px;
                    background: linear-gradient(to bottom, var(--primary-gold), var(--primary-gold-light));
                    margin-left: 17px;
                }

                /* ═══ CONCEPT MAP ═══ */
                .concept-map {
                    background: linear-gradient(135deg, var(--bg-secondary) 0%, var(--bg-card) 100%);
                    border: 1px solid var(--border-medium);
                    border-radius: var(--radius-xl);
                    padding: 2rem;
                    margin: 2.5rem 0;
                }
                .concept-map .block-header {
                    color: var(--primary-gold-dark);
                    border-bottom: 1px solid var(--border-light);
                }
                .concept-map .block-header::before { content: '🗺️'; font-size: 1.125rem; }

                /* ═══ STRUCTURE MAP ═══ */
                .structure-map {
                    background: linear-gradient(135deg, var(--bg-card) 0%, var(--bg-secondary) 100%);
                    border: 1px solid var(--border-medium);
                    border-radius: var(--radius-xl);
                    padding: 2rem;
                    margin: 2.5rem 0;
                }
                .structure-map .block-header {
                    color: var(--primary-gold-dark);
                    border-bottom: 1px solid var(--border-light);
                }
                .structure-map .block-header::before { content: '🧭'; font-size: 1.125rem; }
                .concept-map-container {
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    gap: 1.5rem;
                    padding-top: 1rem;
                }
                .concept-central {
                    padding: 1.25rem 2rem;
                    background: linear-gradient(135deg, var(--primary-gold-subtle) 0%, rgba(232, 155, 90, 0.15) 100%);
                    border: 2px solid var(--primary-gold);
                    border-radius: 50px;
                    font-family: var(--font-display);
                    font-weight: 600;
                    font-size: 1.25rem;
                    color: var(--primary-gold-dark);
                    text-align: center;
                }
                .concept-related {
                    display: flex;
                    flex-wrap: wrap;
                    justify-content: center;
                    gap: 1rem;
                }
                .concept-node {
                    padding: 0.75rem 1.25rem;
                    background: var(--bg-card);
                    border: 1.5px solid var(--accent-teal);
                    border-radius: var(--radius-lg);
                    font-family: var(--font-ui);
                    font-size: 0.9rem;
                    color: var(--text-body);
                    position: relative;
                }
                .concept-node::before {
                    content: '';
                    position: absolute;
                    top: -12px;
                    left: 50%;
                    transform: translateX(-50%);
                    width: 1px;
                    height: 12px;
                    background: var(--primary-gold);
                }

                /* ═══ BLOCKQUOTE ═══ */
                blockquote {
                    position: relative;
                    margin: 2rem 0;
                    padding: 2rem;
                    padding-left: 2.5rem;
                    background: var(--bg-card);
                    border-left: 3px solid var(--primary-gold);
                    border-radius: 0 var(--radius-xl) var(--radius-xl) 0;
                    box-shadow: 0 2px 4px rgba(45, 37, 32, 0.04);
                }
                blockquote::before {
                    content: '"';
                    position: absolute;
                    top: 0.75rem;
                    left: 0.75rem;
                    font-family: var(--font-display);
                    font-size: 3rem;
                    color: rgba(201, 162, 39, 0.25);
                    line-height: 1;
                }
                blockquote p {
                    font-style: italic;
                    color: var(--text-muted);
                    font-size: 1.125rem;
                    margin: 0;
                }
                blockquote cite {
                    display: block;
                    margin-top: 1rem;
                    font-family: var(--font-handwritten);
                    font-size: 1.125rem;
                    font-style: normal;
                    color: var(--accent-coral-text);
                }
                blockquote cite::before { content: '— '; }

                /* ═══ TABLES ═══ */
                .styled-table {
                    width: 100%;
                    border-collapse: separate;
                    border-spacing: 0;
                    font-family: var(--font-ui);
                    font-size: 0.875rem;
                    border-radius: var(--radius-xl);
                    overflow: hidden;
                    box-shadow: 0 2px 8px rgba(45, 37, 32, 0.04);
                    margin: 1.5rem 0;
                }
                .styled-table thead th {
                    background: linear-gradient(135deg, var(--primary-gold) 0%, var(--accent-orange) 100%);
                    color: var(--text-inverse);
                    font-weight: 600;
                    padding: 1rem 1.25rem;
                    text-align: left;
                    letter-spacing: 0.02em;
                    white-space: nowrap;
                }
                .styled-table tbody td {
                    padding: 1rem 1.25rem;
                    background: var(--bg-card);
                    border-bottom: 1px solid var(--border-light);
                    vertical-align: top;
                }
                .styled-table tbody tr.odd-row td {
                    background: var(--bg-secondary);
                }
                .styled-table tbody tr:last-child td { border-bottom: none; }
                .styled-table tbody tr:hover td { background: var(--primary-gold-subtle); }

                /* Responsive table wrapper */
                @media (max-width: 640px) {
                    .styled-table {
                        display: block;
                        overflow-x: auto;
                        -webkit-overflow-scrolling: touch;
                    }
                    .styled-table thead th,
                    .styled-table tbody td {
                        padding: 0.75rem 1rem;
                        font-size: 0.8rem;
                    }
                }

                /* ═══ LISTS ═══ */
                ul, ol { padding-left: 1.5rem; margin: 1rem 0; }
                li { margin: 0.5rem 0; line-height: 1.5; }
                li::marker { color: var(--primary-gold); }

                /* ═══ SECTION DIVIDER ═══ */
                hr.section-divider {
                    border: none;
                    height: 2px;
                    background: linear-gradient(90deg, transparent, var(--primary-gold), transparent);
                    margin: 3rem 0;
                }

                .section-divider-ornament {
                    border: none;
                    text-align: center;
                    margin: 3rem 0;
                }
                .section-divider-ornament::before {
                    content: '◆ ◇ ◆';
                    font-size: 0.875rem;
                    color: var(--primary-gold);
                    letter-spacing: 0.5em;
                }

                /* Premium Ornament Divider (converted from ═══ markdown) */
                .premium-ornament-divider {
                    text-align: center;
                    margin: 2.5rem 0;
                    padding: 1rem 0;
                }
                .premium-ornament-divider .ornament {
                    font-size: 1rem;
                    color: var(--primary-gold);
                    letter-spacing: 0.75em;
                    opacity: 0.85;
                }

                /* ═══ PREMIUM QUOTE ═══ */
                .premium-quote {
                    position: relative;
                    margin: 2.5rem 0;
                    padding: 2rem 2rem 2rem 2.5rem;
                    background: var(--bg-card);
                    border-left: 4px solid var(--accent-coral);
                    border-radius: 0 var(--radius-xl) var(--radius-xl) 0;
                    box-shadow: 0 4px 16px rgba(45, 37, 32, 0.06);
                }
                .premium-quote-mark {
                    position: absolute;
                    top: -0.5rem;
                    right: 1.5rem;
                    font-family: var(--font-display);
                    font-size: 5rem;
                    font-weight: 700;
                    color: rgba(203, 161, 53, 0.2);
                    line-height: 1;
                    pointer-events: none;
                }
                .premium-quote blockquote {
                    margin: 0;
                    padding: 0;
                    border: none;
                    background: transparent;
                    box-shadow: none;
                }
                .premium-quote blockquote::before {
                    display: none;
                }
                .premium-quote blockquote p {
                    font-family: var(--font-display);
                    font-size: 1.25rem;
                    font-style: italic;
                    color: var(--text-body);
                    line-height: 1.6;
                    margin: 0 0 1rem 0;
                }
                .premium-quote blockquote cite {
                    display: block;
                    text-align: right;
                    font-family: var(--font-display);
                    font-size: 1rem;
                    font-style: normal;
                    font-weight: 600;
                    color: var(--accent-coral-text);
                    margin-top: 1rem;
                }
                .premium-quote blockquote cite::before {
                    content: '— ';
                }
                .premium-quote-source {
                    display: block;
                    font-weight: 400;
                    font-style: italic;
                    color: var(--text-muted);
                    font-size: 0.9rem;
                    margin-top: 0.25rem;
                }

                /* ═══ AUTHOR SPOTLIGHT ═══ */
                .author-spotlight {
                    position: relative;
                    margin: 3rem 0;
                    padding: 2rem;
                    background: var(--bg-card);
                    border: 2px solid var(--primary-gold);
                    border-radius: var(--radius-xl);
                    box-shadow: 0 4px 20px rgba(203, 161, 53, 0.1);
                }
                .author-spotlight::before {
                    content: '';
                    position: absolute;
                    top: 4px;
                    left: 4px;
                    right: 4px;
                    bottom: 4px;
                    border: 1px solid rgba(203, 161, 53, 0.4);
                    border-radius: calc(var(--radius-xl) - 4px);
                    pointer-events: none;
                }
                .author-spotlight-header {
                    display: flex;
                    align-items: center;
                    gap: 0.75rem;
                    margin-bottom: 1rem;
                    padding-bottom: 0.75rem;
                    border-bottom: 1px solid var(--border-light);
                }
                .author-spotlight-icon {
                    font-size: 1.25rem;
                }
                .author-spotlight-label {
                    font-family: var(--font-ui);
                    font-size: 0.7rem;
                    font-weight: 600;
                    letter-spacing: 0.15em;
                    color: var(--primary-gold);
                    text-transform: uppercase;
                }
                .author-spotlight-name {
                    font-family: var(--font-display);
                    font-size: 1.75rem;
                    font-weight: 600;
                    color: var(--accent-coral-text);
                    margin: 0 0 0.75rem 0;
                    padding: 0;
                }
                .author-spotlight-name::after {
                    display: none;
                }
                .author-spotlight-bio {
                    font-family: var(--font-display);
                    font-size: 1.05rem;
                    color: var(--text-body);
                    line-height: 1.7;
                    margin: 0;
                }

                /* ═══ PREMIUM DIVIDER ═══ */
                .premium-divider {
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    gap: 1rem;
                    margin: 3rem 0;
                    padding: 1rem 0;
                }
                .premium-divider-line {
                    flex: 1;
                    max-width: 120px;
                    height: 1px;
                    background: linear-gradient(90deg, transparent, var(--primary-gold));
                }
                .premium-divider-line:last-child {
                    background: linear-gradient(90deg, var(--primary-gold), transparent);
                }
                .premium-divider-diamond,
                .premium-divider-diamond-outline {
                    font-size: 0.75rem;
                    color: var(--primary-gold);
                    line-height: 1;
                }
                .premium-divider-diamond-outline {
                    font-size: 0.625rem;
                    opacity: 0.7;
                }

                /* ═══ PREMIUM H1 HEADER ═══ */
                .premium-h1 {
                    text-align: center;
                    margin: 4rem 0 3rem 0;
                }
                .premium-h1-ornaments {
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    gap: 0.5rem;
                    margin-bottom: 1rem;
                }
                .premium-h1-ornaments:last-child {
                    margin-bottom: 0;
                    margin-top: 1rem;
                }
                .premium-h1 .diamond-filled,
                .premium-h1 .diamond-outline {
                    font-size: 0.625rem;
                    color: var(--primary-gold);
                }
                .premium-h1 .diamond-outline {
                    font-size: 0.5rem;
                    opacity: 0.6;
                }
                .premium-h1 h1 {
                    font-family: var(--font-display);
                    font-size: 1.5rem;
                    font-weight: 700;
                    letter-spacing: 0.1em;
                    color: var(--primary-gold);
                    margin: 0;
                    padding: 0;
                }

                /* ═══ PREMIUM H2 HEADER ═══ */
                h2.premium-h2 {
                    display: flex;
                    align-items: center;
                    gap: 1rem;
                    margin: 3rem 0 1.5rem 0;
                    font-family: var(--font-display);
                    font-size: 1.5rem;
                    font-weight: 600;
                    color: var(--text-heading);
                    padding-left: 1.25rem;
                    position: relative;
                }
                h2.premium-h2::before {
                    content: '';
                    position: absolute;
                    left: 0;
                    top: 50%;
                    transform: translateY(-50%);
                    width: 4px;
                    height: 28px;
                    background: var(--primary-gold);
                    border-radius: 2px;
                }
                h2.premium-h2::after {
                    display: none;
                }
                .premium-h2-bar {
                    width: 4px;
                    height: 28px;
                    background: var(--primary-gold);
                    border-radius: 2px;
                    flex-shrink: 0;
                }
                .premium-h2 h2 {
                    font-family: var(--font-display);
                    font-size: 1.5rem;
                    font-weight: 600;
                    color: var(--text-heading);
                    margin: 0;
                    padding: 0;
                }
                .premium-h2 h2::after {
                    display: none;
                }

                /* Premium H2 with category label wrapper */
                .premium-h2-wrapper {
                    margin: 3rem 0 1.5rem 0;
                    padding-left: 1.25rem;
                    position: relative;
                }
                .premium-h2-wrapper::before {
                    content: '';
                    position: absolute;
                    left: 0;
                    top: 0;
                    bottom: 0;
                    width: 4px;
                    background: var(--primary-gold);
                    border-radius: 2px;
                }
                .premium-h2-wrapper .section-category {
                    display: block;
                    font-family: var(--font-ui);
                    font-size: 0.7rem;
                    font-weight: 600;
                    letter-spacing: 0.15em;
                    text-transform: uppercase;
                    color: var(--text-muted);
                    margin-bottom: 0.25rem;
                }
                .premium-h2-wrapper h2 {
                    font-family: var(--font-display);
                    font-size: 1.75rem;
                    font-weight: 600;
                    color: var(--text-heading);
                    margin: 0;
                    padding: 0;
                    line-height: 1.2;
                }
                .premium-h2-wrapper h2::after {
                    display: none;
                }

                /* ═══ PREMIUM PART HEADER ═══ */
                .premium-part-header {
                    text-align: center;
                    margin: 4rem 0 3rem 0;
                    padding: 2rem 0;
                }
                .premium-part-header .part-ornament {
                    font-size: 0.875rem;
                    color: var(--primary-gold);
                    letter-spacing: 0.5em;
                    margin: 1rem 0;
                }
                .premium-part-header .part-title {
                    font-family: var(--font-display);
                    font-size: 2rem;
                    font-weight: 700;
                    letter-spacing: 0.15em;
                    text-transform: uppercase;
                    color: var(--primary-gold);
                    margin: 0;
                    padding: 0;
                }

                /* ═══ LINKS ═══ */
                a {
                    color: var(--accent-burgundy);
                    text-decoration: none;
                    border-bottom: 1px solid rgba(107, 58, 74, 0.3);
                    transition: border-color 0.25s;
                }
                a:hover { border-bottom-color: var(--accent-burgundy); }

                /* ═══ CODE ═══ */
                code {
                    background: rgba(201, 162, 39, 0.15);
                    padding: 2px 6px;
                    border-radius: 4px;
                    font-family: 'SF Mono', Monaco, monospace;
                    font-size: 0.9em;
                }

                /* ═══ FOOTER ═══ */
                .document-footer {
                    text-align: center;
                    margin-top: 4rem;
                    padding-top: 2.5rem;
                    border-top: 1px solid var(--border-light);
                    font-family: var(--font-ui);
                    font-size: 0.875rem;
                    color: var(--text-subtle);
                }
                .document-footer .brand-footer {
                    font-weight: 600;
                    color: var(--brand-sepia);
                    letter-spacing: 0.06em;
                }
                .document-footer .tagline-footer {
                    font-family: var(--font-handwritten);
                    font-size: 1.125rem;
                    color: var(--text-muted);
                    margin-top: 0.5rem;
                }

                /* ═══ RESPONSIVE ═══ */
                @media (max-width: 640px) {
                    html { font-size: 16px; }
                    body { padding: 1.5rem 1rem; }
                    .document-header h1 { font-size: 2.25rem; }
                    .quick-glance, .insight-note, .action-box, .exercise,
                    .visual-flowchart, .takeaways, .foundational-narrative { padding: 1.25rem; }
                    .flow-step { max-width: 100%; }
                }

                /* ═══ PRINT STYLES ═══ */
                @media print {
                    body {
                        background: white;
                        color: black;
                        font-size: 11pt;
                        max-width: 100%;
                        padding: 0;
                    }
                    .cover-page {
                        min-height: auto;
                        page-break-after: always;
                        margin: 0;
                        padding: 2rem;
                        border: 1px solid #C9A227;
                        background: white;
                    }
                    .cover-page::before, .cover-page::after { display: none; }
                    .cover-corner { display: none; }
                    .document-header, .quick-glance, .insight-note, .action-box,
                    .exercise, .visual-flowchart, .takeaways, .foundational-narrative {
                        break-inside: avoid;
                        box-shadow: none;
                    }
                    .table-of-contents {
                        page-break-after: always;
                        box-shadow: none;
                    }
                    /* Print TOC with dotted leaders */
                    .toc-list li a {
                        display: flex;
                        justify-content: space-between;
                    }
                    .toc-list li a::after {
                        content: leader(dotted) target-counter(attr(href), page);
                        flex: 1;
                        text-align: right;
                        margin-left: 0.5rem;
                    }
                    a::after {
                        content: ' (' attr(href) ')';
                        font-size: 0.8em;
                        color: #666;
                    }
                    .toc-list a::after {
                        content: leader(dotted);
                    }
                    .flow-step { box-shadow: none; }
                    /* Dark mode SVG icons need color adjustment for print */
                    .insight-note .block-header::before,
                    .alternative-perspective .block-header::before,
                    .research-insight .block-header::before {
                        filter: brightness(0.8);
                    }
                }
            </style>
        </head>
        <body>
            <!-- Premium Cover Page -->
            <section class="cover-page">
                <div class="cover-corner top-left"></div>
                <div class="cover-corner top-right"></div>
                <div class="cover-corner bottom-left"></div>
                <div class="cover-corner bottom-right"></div>

                <p class="cover-top-tagline">Where Understanding Illuminates the World</p>
                <div class="cover-divider"></div>

                \(logoImageTag.isEmpty ? "<div class=\"cover-logo-placeholder\">◎</div>" : logoImageTag.replacingOccurrences(of: "header-logo", with: "cover-logo"))

                <h1 class="cover-title">\(title)</h1>
                <p class="cover-by">by</p>
                <p class="cover-author">\(author)</p>

                <div class="cover-small-divider"></div>

                <p class="cover-brand">Insight Atlas</p>
                <p class="cover-subtitle">A Comprehensive Analysis Guide</p>
            </section>

            <!-- Content Section Header -->
            <header class="document-header header">
                <span class="brand">Insight Atlas Guide</span>
                <span class="brand-badge">Insight Atlas Guide</span>
                <h1>\(title)</h1>
                <p class="author">Based on the work of <strong>\(author)</strong></p>
            </header>

            \(tocHTML)

            \(content)

            <hr class="section-divider-ornament">

            <footer class="document-footer">
                \(footerLogoTag)
                <p><span class="brand-footer">INSIGHT ATLAS</span></p>
                <p class="tagline-footer">Where Understanding Illuminates the World</p>
            </footer>
        </body>
        </html>
        """
    }

    /// Generate HTML Table of Contents from heading entries
    private func generateHTMLTableOfContents(entries: [(text: String, level: Int, id: String)], readingTime: Int) -> String {
        // Only include H2 and H3 entries (skip H1 which is typically just the title)
        let filteredEntries = entries.filter { $0.level >= 2 && $0.level <= 3 }

        guard !filteredEntries.isEmpty else { return "" }

        var tocItems = ""
        for entry in filteredEntries {
            let indent = entry.level == 3 ? "toc-subsection" : "toc-section"
            tocItems += """
            <li class="\(indent)"><a href="#\(entry.id)">\(entry.text)</a></li>

            """
        }

        return """
        <nav class="table-of-contents">
            <div class="toc-header">
                <span class="toc-icon">📑</span>
                <h2>Contents</h2>
                <span class="reading-time-badge">\(readingTime) min read</span>
            </div>
            <ol class="toc-list">
                \(tocItems)
            </ol>
        </nav>
        <hr class="section-divider">
        """
    }

    // MARK: - PDF Generation

    private func generatePDF(content: String, title: String, author: String, to url: URL) throws {
        // Use the new InsightAtlasPDFRenderer for premium PDF generation
        let pdfRenderer = InsightAtlasPDFRenderer()

        var options = InsightAtlasPDFRenderer.RenderOptions.default
        options.includeCoverPage = true
        options.includeTableOfContents = true
        options.includePageNumbers = true
        options.logoImage = getLogoImage()

        do {
            try pdfRenderer.generatePDF(
                from: content,
                title: title,
                author: author,
                to: url,
                options: options
            )
        } catch {
            // Fall back to legacy PDF generation if new renderer fails
            try generateLegacyPDF(content: content, title: title, author: author, to: url)
        }
    }

    /// Legacy PDF generation (fallback)
    private func generateLegacyPDF(content: String, title: String, author: String, to url: URL) throws {
        let pageWidth: CGFloat = 612  // US Letter width in points
        let pageHeight: CGFloat = 792 // US Letter height in points
        let margin: CGFloat = 72      // 1 inch margins

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let attributedContent = createAttributedString(from: content, title: title, author: author, pageWidth: pageWidth - margin * 2)

        let data = pdfRenderer.pdfData { context in
            // Draw premium cover page first
            context.beginPage()
            drawPDFCoverPage(context: context.cgContext, title: title, author: author, content: content, pageWidth: pageWidth, pageHeight: pageHeight)

            let textRect = CGRect(x: margin, y: margin, width: pageWidth - margin * 2, height: pageHeight - margin * 2)

            // Calculate text layout for content pages
            let framesetter = CTFramesetterCreateWithAttributedString(attributedContent)
            var currentPosition = 0
            var pageNumber = 1  // Start at 1 since cover page is page 0

            while currentPosition < attributedContent.length {
                context.beginPage()
                pageNumber += 1

                // Draw header on first content page (page 2)
                if pageNumber == 2 {
                    drawPDFHeader(context: context.cgContext, title: title, author: author, rect: textRect)
                }

                let headerOffset: CGFloat = pageNumber == 2 ? 190 : 0 // Includes logo height on first content page
                let contentRect = CGRect(x: textRect.origin.x,
                                        y: textRect.origin.y + headerOffset,
                                        width: textRect.width,
                                        height: textRect.height - headerOffset - 30) // Leave room for footer

                let path = CGPath(rect: contentRect, transform: nil)
                let frame = CTFramesetterCreateFrame(framesetter,
                                                     CFRangeMake(currentPosition, 0),
                                                     path,
                                                     nil)

                // Draw the text
                context.cgContext.textMatrix = .identity
                context.cgContext.translateBy(x: 0, y: pageHeight)
                context.cgContext.scaleBy(x: 1.0, y: -1.0)

                CTFrameDraw(frame, context.cgContext)

                // Get the range that was drawn
                let visibleRange = CTFrameGetVisibleStringRange(frame)
                currentPosition += visibleRange.length

                // Reset transform for footer
                context.cgContext.scaleBy(x: 1.0, y: -1.0)
                context.cgContext.translateBy(x: 0, y: -pageHeight)

                // Draw page footer (showing page number minus 1 so content starts at page 1)
                drawPDFFooter(context: context.cgContext, pageNumber: pageNumber - 1, pageWidth: pageWidth, pageHeight: pageHeight)
            }
        }

        try data.write(to: url)
    }

    private func drawPDFHeader(context: CGContext, title: String, author: String, rect: CGRect) {
        var yOffset: CGFloat = rect.origin.y

        // Draw logo if available
        if let logo = getLogoImage() {
            let logoHeight: CGFloat = 60
            let logoWidth = logoHeight * (logo.size.width / logo.size.height)
            let logoRect = CGRect(x: rect.origin.x, y: yOffset, width: logoWidth, height: logoHeight)
            logo.draw(in: logoRect)
            yOffset += logoHeight + 10
        }

        // Brand text
        let brandAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: UIColor.iaGold,
            .kern: 2
        ]
        let brandText = "INSIGHT ATLAS GUIDE"
        let brandString = NSAttributedString(string: brandText, attributes: brandAttributes)
        brandString.draw(at: CGPoint(x: rect.origin.x, y: yOffset))

        // Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .bold),
            .foregroundColor: UIColor.iaHeading
        ]
        let titleString = NSAttributedString(string: title, attributes: titleAttributes)
        titleString.draw(at: CGPoint(x: rect.origin.x, y: yOffset + 20))

        // Author
        let authorAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.italicSystemFont(ofSize: 14),
            .foregroundColor: UIColor.iaMuted
        ]
        let authorString = NSAttributedString(string: "by \(author)", attributes: authorAttributes)
        authorString.draw(at: CGPoint(x: rect.origin.x, y: yOffset + 55))

        // Gold divider line
        context.setStrokeColor(UIColor.iaGold.cgColor)
        context.setLineWidth(2)
        context.move(to: CGPoint(x: rect.origin.x, y: yOffset + 85))
        context.addLine(to: CGPoint(x: rect.origin.x + rect.width, y: yOffset + 85))
        context.strokePath()
    }

    private func drawPDFFooter(context: CGContext, pageNumber: Int, pageWidth: CGFloat, pageHeight: CGFloat) {
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.iaMuted
        ]

        let footerText = "Insight Atlas Guide • Page \(pageNumber)"
        let footerString = NSAttributedString(string: footerText, attributes: footerAttributes)
        let footerSize = footerString.size()

        footerString.draw(at: CGPoint(x: (pageWidth - footerSize.width) / 2, y: pageHeight - 50))
    }

    // MARK: - Premium Cover Page

    /// Extracts the Quick Glance content from the guide for the cover page
    private func extractQuickGlanceForCover(from content: String) -> [String] {
        var bullets: [String] = []
        let lines = content.components(separatedBy: .newlines)
        var inQuickGlance = false

        for line in lines {
            if line.hasPrefix("[QUICK_GLANCE]") {
                inQuickGlance = true
                continue
            }
            if line.hasPrefix("[/QUICK_GLANCE]") {
                break // Only use first Quick Glance block
            }
            if inQuickGlance {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                // Extract bullet points (lines starting with - or •)
                if trimmed.hasPrefix("-") || trimmed.hasPrefix("•") || trimmed.hasPrefix("*") {
                    var bulletText = trimmed
                    bulletText.removeFirst()
                    bulletText = bulletText.trimmingCharacters(in: .whitespaces)
                    // Strip markdown from bullet text
                    bulletText = stripMarkdownForPDF(bulletText)
                    if !bulletText.isEmpty && bullets.count < 5 {
                        bullets.append(bulletText)
                    }
                }
            }
        }

        return bullets
    }

    /// Draws decorative corner frames on the cover page
    private func drawCornerFrames(context: CGContext, pageWidth: CGFloat, pageHeight: CGFloat, margin: CGFloat) {
        let cornerLength: CGFloat = 40
        let cornerInset: CGFloat = margin - 20

        context.setStrokeColor(UIColor.iaGold.cgColor)
        context.setLineWidth(2)

        // Top-left corner
        context.move(to: CGPoint(x: cornerInset, y: cornerInset + cornerLength))
        context.addLine(to: CGPoint(x: cornerInset, y: cornerInset))
        context.addLine(to: CGPoint(x: cornerInset + cornerLength, y: cornerInset))

        // Top-right corner
        context.move(to: CGPoint(x: pageWidth - cornerInset - cornerLength, y: cornerInset))
        context.addLine(to: CGPoint(x: pageWidth - cornerInset, y: cornerInset))
        context.addLine(to: CGPoint(x: pageWidth - cornerInset, y: cornerInset + cornerLength))

        // Bottom-left corner
        context.move(to: CGPoint(x: cornerInset, y: pageHeight - cornerInset - cornerLength))
        context.addLine(to: CGPoint(x: cornerInset, y: pageHeight - cornerInset))
        context.addLine(to: CGPoint(x: cornerInset + cornerLength, y: pageHeight - cornerInset))

        // Bottom-right corner
        context.move(to: CGPoint(x: pageWidth - cornerInset - cornerLength, y: pageHeight - cornerInset))
        context.addLine(to: CGPoint(x: pageWidth - cornerInset, y: pageHeight - cornerInset))
        context.addLine(to: CGPoint(x: pageWidth - cornerInset, y: pageHeight - cornerInset - cornerLength))

        context.strokePath()
    }

    /// Draws the premium cover page for PDF exports
    private func drawPDFCoverPage(context: CGContext, title: String, author: String, content: String, pageWidth: CGFloat, pageHeight: CGFloat) {
        let margin: CGFloat = 72
        let centerX = pageWidth / 2

        // Draw decorative corner frames
        drawCornerFrames(context: context, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin)

        var yPosition: CGFloat = 120

        // Draw logo centered at top
        if let logo = getLogoImage() {
            let logoHeight: CGFloat = 80
            let logoWidth = logoHeight * (logo.size.width / logo.size.height)
            let logoRect = CGRect(x: centerX - logoWidth / 2, y: yPosition, width: logoWidth, height: logoHeight)
            logo.draw(in: logoRect)
            yPosition += logoHeight + 20
        }

        // Brand text - "INSIGHT ATLAS"
        let brandAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: UIColor.iaGold,
            .kern: 4
        ]
        let brandText = "INSIGHT ATLAS"
        let brandString = NSAttributedString(string: brandText, attributes: brandAttributes)
        let brandSize = brandString.size()
        brandString.draw(at: CGPoint(x: centerX - brandSize.width / 2, y: yPosition))
        yPosition += 40

        // Gold decorative line
        context.setStrokeColor(UIColor.iaGold.cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: margin + 80, y: yPosition))
        context.addLine(to: CGPoint(x: pageWidth - margin - 80, y: yPosition))
        context.strokePath()
        yPosition += 30

        // Main title - large, bold, centered
        let titleStyle = NSMutableParagraphStyle()
        titleStyle.alignment = .center
        titleStyle.lineSpacing = 8

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 36, weight: .bold),
            .foregroundColor: UIColor.iaHeading,
            .paragraphStyle: titleStyle
        ]

        let titleRect = CGRect(x: margin, y: yPosition, width: pageWidth - margin * 2, height: 120)
        let titleString = NSAttributedString(string: title.uppercased(), attributes: titleAttributes)
        titleString.draw(in: titleRect)
        yPosition += 100

        // Author line
        let authorStyle = NSMutableParagraphStyle()
        authorStyle.alignment = .center

        let authorAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.italicSystemFont(ofSize: 16),
            .foregroundColor: UIColor.iaMuted,
            .paragraphStyle: authorStyle
        ]
        let authorString = NSAttributedString(string: "Based on the work of \(author)", attributes: authorAttributes)
        let authorRect = CGRect(x: margin, y: yPosition, width: pageWidth - margin * 2, height: 30)
        authorString.draw(in: authorRect)
        yPosition += 50

        // Another decorative line
        context.setStrokeColor(UIColor.iaGold.cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: margin + 80, y: yPosition))
        context.addLine(to: CGPoint(x: pageWidth - margin - 80, y: yPosition))
        context.strokePath()
        yPosition += 40

        // "AT A GLANCE" card
        let quickGlanceBullets = extractQuickGlanceForCover(from: content)

        if !quickGlanceBullets.isEmpty {
            let cardMargin: CGFloat = 60
            let cardX = cardMargin
            let cardWidth = pageWidth - cardMargin * 2
            let cardY = yPosition

            // Calculate card height based on content
            let bulletLineHeight: CGFloat = 24
            let cardPadding: CGFloat = 20
            let headerHeight: CGFloat = 35
            let cardHeight = headerHeight + cardPadding * 2 + CGFloat(quickGlanceBullets.count) * bulletLineHeight + 10

            // Draw card background with subtle border
            let cardRect = CGRect(x: cardX, y: cardY, width: cardWidth, height: cardHeight)

            // Fill with light background
            context.setFillColor(UIColor.iaCard.cgColor)
            context.fill(cardRect)

            // Draw burgundy accent line at top of card
            context.setFillColor(UIColor.iaBurgundy.cgColor)
            context.fill(CGRect(x: cardX, y: cardY, width: cardWidth, height: 4))

            // Card header - "AT A GLANCE"
            let cardHeaderAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .bold),
                .foregroundColor: UIColor.iaBurgundy,
                .kern: 2
            ]
            let cardHeaderString = NSAttributedString(string: "AT A GLANCE", attributes: cardHeaderAttributes)
            cardHeaderString.draw(at: CGPoint(x: cardX + cardPadding, y: cardY + 12))

            // Draw bullet points
            let bulletAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Georgia", size: 11) ?? UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.iaBody
            ]

            let bulletSymbolAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.iaGold
            ]

            var bulletY = cardY + headerHeight + 8
            let bulletTextWidth = cardWidth - cardPadding * 2 - 25  // Available width for text

            for bullet in quickGlanceBullets {
                // Gold bullet symbol
                let bulletSymbol = NSAttributedString(string: "◆  ", attributes: bulletSymbolAttributes)
                bulletSymbol.draw(at: CGPoint(x: cardX + cardPadding, y: bulletY))

                // Bullet text with word wrapping instead of truncation
                let bulletParagraphStyle = NSMutableParagraphStyle()
                bulletParagraphStyle.lineBreakMode = .byWordWrapping

                var wrappedBulletAttributes = bulletAttributes
                wrappedBulletAttributes[.paragraphStyle] = bulletParagraphStyle

                let bulletTextString = NSAttributedString(string: bullet, attributes: wrappedBulletAttributes)
                let bulletTextRect = CGRect(x: cardX + cardPadding + 20, y: bulletY, width: bulletTextWidth, height: bulletLineHeight * 3)
                bulletTextString.draw(with: bulletTextRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)

                // Calculate actual height used and advance accordingly
                let boundingRect = bulletTextString.boundingRect(with: CGSize(width: bulletTextWidth, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, context: nil)
                bulletY += max(bulletLineHeight, boundingRect.height + 4)
            }

            yPosition = cardY + cardHeight + 30
        }

        // Tagline at bottom
        let taglineStyle = NSMutableParagraphStyle()
        taglineStyle.alignment = .center

        let taglineAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.italicSystemFont(ofSize: 12),
            .foregroundColor: UIColor.iaMuted,
            .paragraphStyle: taglineStyle
        ]
        let taglineString = NSAttributedString(string: "Where Understanding Illuminates the World", attributes: taglineAttributes)
        let taglineRect = CGRect(x: margin, y: pageHeight - 80, width: pageWidth - margin * 2, height: 30)
        taglineString.draw(in: taglineRect)

        // Small decorative element above tagline
        let diamondAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.iaGold
        ]
        let diamondStyle = NSMutableParagraphStyle()
        diamondStyle.alignment = .center
        var diamondAttrs = diamondAttributes
        diamondAttrs[.paragraphStyle] = diamondStyle
        let diamondString = NSAttributedString(string: "◆ ◇ ◆", attributes: diamondAttrs)
        let diamondRect = CGRect(x: margin, y: pageHeight - 100, width: pageWidth - margin * 2, height: 20)
        diamondString.draw(in: diamondRect)
    }

    /// Strips all markdown formatting from text for clean PDF output
    private func stripMarkdownForPDF(_ text: String) -> String {
        var result = text

        // Remove bold markers
        if let regex = try? NSRegularExpression(pattern: #"\*\*([^*]+)\*\*"#) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "$1")
        }

        // Remove italic markers (single asterisks around text)
        if let regex = try? NSRegularExpression(pattern: #"(?<!\*)\*([^*]+)\*(?!\*)"#) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "$1")
        }

        // Remove code backticks
        result = result.replacingOccurrences(of: "`", with: "")

        // Remove markdown links, keep text: [text](url) -> text
        if let regex = try? NSRegularExpression(pattern: #"\[([^\]]+)\]\([^)]+\)"#) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "$1")
        }

        return result
    }

    /// Checks if a line is a markdown table separator (like |---|---|)
    private func isTableSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("|") && trimmed.contains("-") && trimmed.rangeOfCharacter(from: .letters) == nil
    }

    /// Parses a markdown table line into cells
    private func parseTableRow(_ line: String) -> [String] {
        var cells = line.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespaces) }
        // Remove empty first/last cells from leading/trailing pipes
        if cells.first?.isEmpty == true { cells.removeFirst() }
        if cells.last?.isEmpty == true { cells.removeLast() }
        return cells
    }

    private func createAttributedString(from content: String, title: String, author: String, pageWidth: CGFloat) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // Default paragraph style
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        paragraphStyle.paragraphSpacing = 12

        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Georgia", size: 12) ?? UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.iaBody,
            .paragraphStyle: paragraphStyle
        ]

        let headingStyle = NSMutableParagraphStyle()
        headingStyle.paragraphSpacingBefore = 24
        headingStyle.paragraphSpacing = 8

        let partHeadingStyle = NSMutableParagraphStyle()
        partHeadingStyle.paragraphSpacingBefore = 32
        partHeadingStyle.paragraphSpacing = 12

        // Special block styles
        let blockHeaderStyle = NSMutableParagraphStyle()
        blockHeaderStyle.paragraphSpacingBefore = 16
        blockHeaderStyle.paragraphSpacing = 4

        let quickGlanceHeaderAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: UIColor.iaGold,
            .paragraphStyle: blockHeaderStyle
        ]

        let insightNoteHeaderAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: UIColor.iaCoral,
            .paragraphStyle: blockHeaderStyle
        ]

        let actionBoxHeaderAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: UIColor.iaBurgundy,
            .paragraphStyle: blockHeaderStyle
        ]

        let blockContentStyle = NSMutableParagraphStyle()
        blockContentStyle.lineSpacing = 4
        blockContentStyle.paragraphSpacing = 8
        blockContentStyle.firstLineHeadIndent = 12
        blockContentStyle.headIndent = 12

        let blockContentAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Georgia", size: 11) ?? UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.iaBody,
            .paragraphStyle: blockContentStyle
        ]

        // Divider style
        let dividerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.iaGold
        ]

        // Table cell style
        let tableCellStyle = NSMutableParagraphStyle()
        tableCellStyle.lineSpacing = 2
        tableCellStyle.paragraphSpacing = 4

        let tableHeaderAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: UIColor.iaHeading,
            .paragraphStyle: tableCellStyle
        ]

        let tableCellAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Georgia", size: 10) ?? UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.iaBody,
            .paragraphStyle: tableCellStyle
        ]

        // Parse content and build attributed string
        let lines = content.components(separatedBy: "\n")
        var inSpecialBlock = false
        var currentBlockType = ""
        var inTable = false

        for line in lines {
            // Handle special block opening markers
            if line.hasPrefix("[QUICK_GLANCE]") {
                inSpecialBlock = true
                currentBlockType = "QUICK_GLANCE"
                result.append(NSAttributedString(string: "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", attributes: [.foregroundColor: UIColor.iaGold]))
                result.append(NSAttributedString(string: "👁 QUICK GLANCE\n", attributes: quickGlanceHeaderAttributes))

                // Add dynamic reading time
                let readingTime = calculateReadingTime(from: content)
                result.append(NSAttributedString(string: "\(readingTime) min read\n\n", attributes: [
                    .font: UIFont.systemFont(ofSize: 9, weight: .medium),
                    .foregroundColor: UIColor.iaGold
                ]))
                continue
            }

            if line.hasPrefix("[INSIGHT_NOTE]") {
                inSpecialBlock = true
                currentBlockType = "INSIGHT_NOTE"
                result.append(NSAttributedString(string: "\n💡 INSIGHT ATLAS NOTE\n", attributes: insightNoteHeaderAttributes))
                continue
            }

            if line.hasPrefix("[ACTION_BOX") {
                inSpecialBlock = true
                currentBlockType = "ACTION_BOX"
                result.append(NSAttributedString(string: "\n✓ APPLY IT\n", attributes: actionBoxHeaderAttributes))
                continue
            }

            if line.hasPrefix("[FOUNDATIONAL_NARRATIVE]") {
                inSpecialBlock = true
                currentBlockType = "FOUNDATIONAL_NARRATIVE"
                result.append(NSAttributedString(string: "\n📖 THE STORY BEHIND THE IDEAS\n", attributes: quickGlanceHeaderAttributes))
                continue
            }

            if line.hasPrefix("[STRUCTURE_MAP]") {
                inSpecialBlock = true
                currentBlockType = "STRUCTURE_MAP"
                result.append(NSAttributedString(string: "\n🗺️ STRUCTURE MAP\n", attributes: quickGlanceHeaderAttributes))
                continue
            }

            if line.hasPrefix("[TAKEAWAYS]") {
                inSpecialBlock = true
                currentBlockType = "TAKEAWAYS"
                result.append(NSAttributedString(string: "\n⭐ KEY TAKEAWAYS\n", attributes: quickGlanceHeaderAttributes))
                continue
            }

            if line.hasPrefix("[VISUAL_FLOWCHART") {
                inSpecialBlock = true
                currentBlockType = "VISUAL_FLOWCHART"
                result.append(NSAttributedString(string: "\n📊 VISUAL GUIDE\n", attributes: quickGlanceHeaderAttributes))
                continue
            }

            if line.hasPrefix("[VISUAL_TABLE") {
                inSpecialBlock = true
                currentBlockType = "VISUAL_TABLE"
                result.append(NSAttributedString(string: "\n📋 REFERENCE TABLE\n", attributes: quickGlanceHeaderAttributes))
                continue
            }

            if line.hasPrefix("[EXERCISE_") || line.hasPrefix("[EXERCISE]") {
                inSpecialBlock = true
                currentBlockType = "EXERCISE"
                result.append(NSAttributedString(string: "\n✏️ EXERCISE\n", attributes: actionBoxHeaderAttributes))
                continue
            }

            if line.hasPrefix("[QUOTE]") {
                inSpecialBlock = true
                currentBlockType = "QUOTE"
                continue
            }

            // Handle special block closing markers
            if line.hasPrefix("[/QUICK_GLANCE]") || line.hasPrefix("[/INSIGHT_NOTE]") ||
               line.hasPrefix("[/ACTION_BOX]") || line.hasPrefix("[/QUOTE]") ||
               line.hasPrefix("[/FOUNDATIONAL_NARRATIVE]") || line.hasPrefix("[/STRUCTURE_MAP]") ||
               line.hasPrefix("[/TAKEAWAYS]") || line.hasPrefix("[/VISUAL_FLOWCHART]") ||
               line.hasPrefix("[/VISUAL_TABLE]") || line.hasPrefix("[/EXERCISE") {
                if currentBlockType == "QUICK_GLANCE" {
                    result.append(NSAttributedString(string: "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", attributes: [.foregroundColor: UIColor.iaGold]))
                }
                inSpecialBlock = false
                currentBlockType = ""
                inTable = false
                continue
            }

            // Skip any remaining block markers
            if line.hasPrefix("[") && line.contains("]") && !line.contains("](") {
                continue
            }

            // Skip box drawing characters but render cleaner version
            if line.contains("┌") || line.contains("├") || line.contains("└") ||
               line.contains("│") || line.contains("─") || line.contains("┐") ||
               line.contains("┤") || line.contains("┘") {
                // Clean the line of box characters for PDF
                var cleanLine = line
                for char in ["┌", "├", "└", "│", "─", "┐", "┤", "┘"] {
                    cleanLine = cleanLine.replacingOccurrences(of: char, with: "")
                }
                cleanLine = cleanLine.trimmingCharacters(in: .whitespaces)
                cleanLine = stripMarkdownForPDF(cleanLine)
                if !cleanLine.isEmpty && !cleanLine.contains("↓") {
                    result.append(NSAttributedString(string: "  \(cleanLine)\n", attributes: blockContentAttributes))
                }
                continue
            }

            // Skip arrow indicators (render as flow indicator)
            if line.trimmingCharacters(in: .whitespaces) == "↓" {
                result.append(NSAttributedString(string: "    ↓\n", attributes: [
                    .font: UIFont.systemFont(ofSize: 12),
                    .foregroundColor: UIColor.iaGold
                ]))
                continue
            }

            // Handle horizontal rules (---)
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine == "---" || trimmedLine == "***" || trimmedLine == "___" {
                result.append(NSAttributedString(string: "\n◆ ◇ ◆\n\n", attributes: dividerAttributes))
                continue
            }

            // Handle ═══ box drawing dividers - convert to premium ornament
            if trimmedLine.contains("═══") || (trimmedLine.count > 3 && trimmedLine.filter({ $0 == "═" }).count > trimmedLine.count / 2) {
                result.append(NSAttributedString(string: "\n◇ ◆ ◇\n\n", attributes: dividerAttributes))
                continue
            }

            // Handle markdown tables
            if trimmedLine.hasPrefix("|") && trimmedLine.contains("|") {
                // Check if this is a separator line
                if isTableSeparator(trimmedLine) {
                    continue // Skip separator lines
                }

                let cells = parseTableRow(trimmedLine)
                if !cells.isEmpty {
                    if !inTable {
                        // This is the header row
                        inTable = true
                        let headerText = cells.joined(separator: "  |  ")
                        result.append(NSAttributedString(string: "\(headerText)\n", attributes: tableHeaderAttributes))
                        result.append(NSAttributedString(string: "─────────────────────────────────────\n", attributes: dividerAttributes))
                    } else {
                        // Data row
                        let rowText = cells.joined(separator: "  |  ")
                        result.append(NSAttributedString(string: "\(stripMarkdownForPDF(rowText))\n", attributes: tableCellAttributes))
                    }
                }
                continue
            } else if inTable && !trimmedLine.isEmpty && !trimmedLine.hasPrefix("|") {
                // End of table
                inTable = false
                result.append(NSAttributedString(string: "\n", attributes: bodyAttributes))
            }

            // Content inside special blocks
            if inSpecialBlock {
                if !trimmedLine.isEmpty {
                    // Skip lines that are just ## headers inside blocks (often duplicates)
                    if trimmedLine.hasPrefix("## ") {
                        continue
                    }

                    // Handle quote blocks specially
                    if currentBlockType == "QUOTE" {
                        let quoteStyle = NSMutableParagraphStyle()
                        quoteStyle.firstLineHeadIndent = 20
                        quoteStyle.headIndent = 20
                        let quoteAttributes: [NSAttributedString.Key: Any] = [
                            .font: UIFont.italicSystemFont(ofSize: 12),
                            .foregroundColor: UIColor.iaMuted,
                            .paragraphStyle: quoteStyle
                        ]
                        let cleanText = stripMarkdownForPDF(trimmedLine)
                        result.append(NSAttributedString(string: "\"\(cleanText)\"\n", attributes: quoteAttributes))
                    }
                    // Handle list items in blocks
                    else if trimmedLine.hasPrefix("- ") || trimmedLine.hasPrefix("* ") {
                        let itemText = stripMarkdownForPDF(String(trimmedLine.dropFirst(2)))
                        result.append(NSAttributedString(string: "  • \(itemText)\n", attributes: blockContentAttributes))
                    }
                    // Handle numbered items in blocks
                    else if let _ = trimmedLine.range(of: "^\\d+\\.", options: .regularExpression) {
                        let cleanText = stripMarkdownForPDF(trimmedLine)
                        result.append(NSAttributedString(string: "  \(cleanText)\n", attributes: blockContentAttributes))
                    }
                    // Regular block content
                    else {
                        let cleanText = stripMarkdownForPDF(trimmedLine)
                        result.append(NSAttributedString(string: "  \(cleanText)\n", attributes: blockContentAttributes))
                    }
                }
                continue
            }

            // Handle # PART headers (main section dividers)
            if line.hasPrefix("# ") && !line.hasPrefix("## ") {
                let headerText = stripMarkdownForPDF(String(line.dropFirst(2)))
                let partAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                    .foregroundColor: UIColor.iaHeading,
                    .paragraphStyle: partHeadingStyle
                ]
                result.append(NSAttributedString(string: "\n", attributes: bodyAttributes))
                result.append(NSAttributedString(string: "◆ ◇ ◆\n\n", attributes: dividerAttributes))
                result.append(NSAttributedString(string: "\(headerText)\n", attributes: partAttributes))
                continue
            }

            // Headers
            if line.hasPrefix("## ") {
                let headerText = stripMarkdownForPDF(String(line.dropFirst(3)))
                let headerAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 18, weight: .bold),
                    .foregroundColor: UIColor.iaHeading,
                    .paragraphStyle: headingStyle
                ]
                result.append(NSAttributedString(string: "\n\(headerText)\n", attributes: headerAttributes))
                continue
            }

            if line.hasPrefix("### ") {
                let headerText = stripMarkdownForPDF(String(line.dropFirst(4)))
                let headerAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                    .foregroundColor: UIColor.iaHeading,
                    .paragraphStyle: headingStyle
                ]
                result.append(NSAttributedString(string: "\n\(headerText)\n", attributes: headerAttributes))
                continue
            }

            // List items
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                let itemText = stripMarkdownForPDF(String(line.dropFirst(2)))
                result.append(NSAttributedString(string: "• \(itemText)\n", attributes: bodyAttributes))
                continue
            }

            // Numbered list items
            if let _ = trimmedLine.range(of: "^\\d+\\.", options: .regularExpression) {
                let cleanText = stripMarkdownForPDF(trimmedLine)
                result.append(NSAttributedString(string: "\(cleanText)\n", attributes: bodyAttributes))
                continue
            }

            // Regular text
            if !trimmedLine.isEmpty {
                // Strip all markdown formatting
                let processedLine = stripMarkdownForPDF(line)
                result.append(NSAttributedString(string: processedLine + "\n", attributes: bodyAttributes))
            } else {
                result.append(NSAttributedString(string: "\n", attributes: bodyAttributes))
            }
        }

        return result
    }

    // MARK: - DOCX Generation

    private func generateDOCX(content: String, title: String, author: String, to url: URL) throws {
        // DOCX is a ZIP file with XML content
        // We'll create a minimal valid DOCX structure

        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Create directory structure
        let wordDir = tempDir.appendingPathComponent("word")
        let relsDir = tempDir.appendingPathComponent("_rels")
        let wordRelsDir = wordDir.appendingPathComponent("_rels")

        try fileManager.createDirectory(at: wordDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: relsDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: wordRelsDir, withIntermediateDirectories: true)

        // Create [Content_Types].xml
        let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
            <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
            <Default Extension="xml" ContentType="application/xml"/>
            <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
            <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
        </Types>
        """
        try contentTypes.write(to: tempDir.appendingPathComponent("[Content_Types].xml"), atomically: true, encoding: .utf8)

        // Create _rels/.rels
        let rels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
        """
        try rels.write(to: relsDir.appendingPathComponent(".rels"), atomically: true, encoding: .utf8)

        // Create word/_rels/document.xml.rels
        let documentRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        </Relationships>
        """
        try documentRels.write(to: wordRelsDir.appendingPathComponent("document.xml.rels"), atomically: true, encoding: .utf8)

        // Create word/styles.xml with Insight Atlas branding
        let styles = createDOCXStyles()
        try styles.write(to: wordDir.appendingPathComponent("styles.xml"), atomically: true, encoding: .utf8)

        // Create word/document.xml
        let document = createDOCXDocument(content: content, title: title, author: author)
        try document.write(to: wordDir.appendingPathComponent("document.xml"), atomically: true, encoding: .utf8)

        // Create ZIP archive
        try createZipArchive(from: tempDir, to: url)

        // Cleanup
        try? fileManager.removeItem(at: tempDir)
    }

    private func createDOCXStyles() -> String {
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:style w:type="paragraph" w:styleId="Title">
                <w:name w:val="Title"/>
                <w:pPr>
                    <w:spacing w:after="200"/>
                    <w:jc w:val="center"/>
                </w:pPr>
                <w:rPr>
                    <w:b/>
                    <w:sz w:val="56"/>
                    <w:color w:val="0F172A"/>
                </w:rPr>
            </w:style>
            <w:style w:type="paragraph" w:styleId="Heading1">
                <w:name w:val="Heading 1"/>
                <w:pPr>
                    <w:spacing w:before="400" w:after="200"/>
                    <w:pBdr>
                        <w:bottom w:val="single" w:sz="12" w:color="CBA135"/>
                    </w:pBdr>
                </w:pPr>
                <w:rPr>
                    <w:b/>
                    <w:sz w:val="36"/>
                    <w:color w:val="0F172A"/>
                </w:rPr>
            </w:style>
            <w:style w:type="paragraph" w:styleId="Heading2">
                <w:name w:val="Heading 2"/>
                <w:pPr>
                    <w:spacing w:before="300" w:after="100"/>
                </w:pPr>
                <w:rPr>
                    <w:b/>
                    <w:sz w:val="28"/>
                    <w:color w:val="0F172A"/>
                </w:rPr>
            </w:style>
            <w:style w:type="character" w:styleId="BurgundyText">
                <w:name w:val="Burgundy Text"/>
                <w:rPr>
                    <w:color w:val="582534"/>
                </w:rPr>
            </w:style>
            <w:style w:type="paragraph" w:styleId="Normal">
                <w:name w:val="Normal"/>
                <w:pPr>
                    <w:spacing w:after="200" w:line="360" w:lineRule="auto"/>
                </w:pPr>
                <w:rPr>
                    <w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/>
                    <w:sz w:val="24"/>
                    <w:color w:val="1E293B"/>
                </w:rPr>
            </w:style>
            <w:style w:type="paragraph" w:styleId="InsightNote">
                <w:name w:val="Insight Note"/>
                <w:pPr>
                    <w:spacing w:before="200" w:after="200"/>
                    <w:pBdr>
                        <w:left w:val="single" w:sz="24" w:color="2A8B7F"/>
                    </w:pBdr>
                    <w:ind w:left="400"/>
                    <w:shd w:val="clear" w:fill="FEFCE8"/>
                </w:pPr>
                <w:rPr>
                    <w:sz w:val="22"/>
                    <w:color w:val="1E293B"/>
                </w:rPr>
            </w:style>
            <w:style w:type="paragraph" w:styleId="ActionBox">
                <w:name w:val="Action Box"/>
                <w:pPr>
                    <w:spacing w:before="200" w:after="200"/>
                    <w:pBdr>
                        <w:top w:val="single" w:sz="12" w:color="CBA135"/>
                        <w:left w:val="single" w:sz="12" w:color="CBA135"/>
                        <w:bottom w:val="single" w:sz="12" w:color="CBA135"/>
                        <w:right w:val="single" w:sz="12" w:color="CBA135"/>
                    </w:pBdr>
                    <w:ind w:left="200" w:right="200"/>
                    <w:shd w:val="clear" w:fill="FEFCE8"/>
                </w:pPr>
                <w:rPr>
                    <w:sz w:val="24"/>
                    <w:color w:val="1E293B"/>
                </w:rPr>
            </w:style>
            <w:style w:type="paragraph" w:styleId="QuickGlance">
                <w:name w:val="Quick Glance"/>
                <w:pPr>
                    <w:spacing w:before="200" w:after="200"/>
                    <w:pBdr>
                        <w:top w:val="single" w:sz="12" w:color="CBA135"/>
                        <w:left w:val="single" w:sz="12" w:color="CBA135"/>
                        <w:bottom w:val="single" w:sz="12" w:color="CBA135"/>
                        <w:right w:val="single" w:sz="12" w:color="CBA135"/>
                    </w:pBdr>
                    <w:ind w:left="200" w:right="200"/>
                    <w:shd w:val="clear" w:fill="FEFCE8"/>
                </w:pPr>
                <w:rPr>
                    <w:sz w:val="24"/>
                    <w:color w:val="1E293B"/>
                </w:rPr>
            </w:style>
            <w:style w:type="paragraph" w:styleId="Exercise">
                <w:name w:val="Exercise"/>
                <w:pPr>
                    <w:spacing w:before="200" w:after="200"/>
                    <w:pBdr>
                        <w:top w:val="single" w:sz="12" w:color="2A8B7F"/>
                        <w:left w:val="single" w:sz="12" w:color="2A8B7F"/>
                        <w:bottom w:val="single" w:sz="12" w:color="2A8B7F"/>
                        <w:right w:val="single" w:sz="12" w:color="2A8B7F"/>
                    </w:pBdr>
                    <w:ind w:left="200" w:right="200"/>
                    <w:shd w:val="clear" w:fill="FEFCE8"/>
                </w:pPr>
                <w:rPr>
                    <w:sz w:val="24"/>
                    <w:color w:val="1E293B"/>
                </w:rPr>
            </w:style>
            <w:style w:type="paragraph" w:styleId="Flowchart">
                <w:name w:val="Flowchart"/>
                <w:pPr>
                    <w:spacing w:before="100" w:after="100"/>
                    <w:pBdr>
                        <w:top w:val="single" w:sz="8" w:color="CBA135"/>
                        <w:left w:val="single" w:sz="8" w:color="CBA135"/>
                        <w:bottom w:val="single" w:sz="8" w:color="CBA135"/>
                        <w:right w:val="single" w:sz="8" w:color="CBA135"/>
                    </w:pBdr>
                    <w:jc w:val="center"/>
                    <w:shd w:val="clear" w:fill="FEFCE8"/>
                </w:pPr>
                <w:rPr>
                    <w:sz w:val="22"/>
                    <w:color w:val="1E293B"/>
                </w:rPr>
            </w:style>
            <w:style w:type="paragraph" w:styleId="FlowchartArrow">
                <w:name w:val="Flowchart Arrow"/>
                <w:pPr>
                    <w:spacing w:before="50" w:after="50"/>
                    <w:jc w:val="center"/>
                </w:pPr>
                <w:rPr>
                    <w:sz w:val="28"/>
                    <w:color w:val="CBA135"/>
                </w:rPr>
            </w:style>
            <w:style w:type="paragraph" w:styleId="FoundationalNarrative">
                <w:name w:val="Foundational Narrative"/>
                <w:pPr>
                    <w:spacing w:before="200" w:after="200"/>
                    <w:pBdr>
                        <w:left w:val="single" w:sz="24" w:color="CBA135"/>
                    </w:pBdr>
                    <w:ind w:left="400"/>
                    <w:shd w:val="clear" w:fill="FEFCE8"/>
                </w:pPr>
                <w:rPr>
                    <w:i/>
                    <w:sz w:val="24"/>
                    <w:color w:val="1E293B"/>
                </w:rPr>
            </w:style>
            <w:style w:type="paragraph" w:styleId="Takeaways">
                <w:name w:val="Takeaways"/>
                <w:pPr>
                    <w:spacing w:before="200" w:after="200"/>
                    <w:pBdr>
                        <w:top w:val="single" w:sz="12" w:color="CBA135"/>
                        <w:left w:val="single" w:sz="12" w:color="CBA135"/>
                        <w:bottom w:val="single" w:sz="12" w:color="CBA135"/>
                        <w:right w:val="single" w:sz="12" w:color="CBA135"/>
                    </w:pBdr>
                    <w:ind w:left="200" w:right="200"/>
                    <w:shd w:val="clear" w:fill="FEFCE8"/>
                </w:pPr>
                <w:rPr>
                    <w:sz w:val="24"/>
                    <w:color w:val="1E293B"/>
                </w:rPr>
            </w:style>
            <w:style w:type="paragraph" w:styleId="BlockHeader">
                <w:name w:val="Block Header"/>
                <w:pPr>
                    <w:spacing w:after="100"/>
                </w:pPr>
                <w:rPr>
                    <w:b/>
                    <w:caps/>
                    <w:sz w:val="20"/>
                    <w:color w:val="64748B"/>
                    <w:spacing w:val="40"/>
                </w:rPr>
            </w:style>
            <!-- PREMIUM STYLES -->
            <w:style w:type="paragraph" w:styleId="PremiumQuote">
                <w:name w:val="Premium Quote"/>
                <w:pPr>
                    <w:spacing w:before="300" w:after="300"/>
                    <w:pBdr>
                        <w:left w:val="single" w:sz="24" w:color="D4735C"/>
                    </w:pBdr>
                    <w:ind w:left="400" w:right="200"/>
                    <w:shd w:val="clear" w:fill="FEFCE8"/>
                </w:pPr>
                <w:rPr>
                    <w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/>
                    <w:i/>
                    <w:sz w:val="26"/>
                    <w:color w:val="1E293B"/>
                </w:rPr>
            </w:style>
            <w:style w:type="paragraph" w:styleId="PremiumQuoteAttribution">
                <w:name w:val="Premium Quote Attribution"/>
                <w:pPr>
                    <w:spacing w:before="100" w:after="200"/>
                    <w:jc w:val="right"/>
                    <w:ind w:right="200"/>
                </w:pPr>
                <w:rPr>
                    <w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/>
                    <w:b/>
                    <w:sz w:val="22"/>
                    <w:color w:val="D4735C"/>
                </w:rPr>
            </w:style>
            <w:style w:type="paragraph" w:styleId="AuthorSpotlight">
                <w:name w:val="Author Spotlight"/>
                <w:pPr>
                    <w:spacing w:before="200" w:after="200"/>
                    <w:pBdr>
                        <w:top w:val="double" w:sz="12" w:color="CBA135"/>
                        <w:left w:val="double" w:sz="12" w:color="CBA135"/>
                        <w:bottom w:val="double" w:sz="12" w:color="CBA135"/>
                        <w:right w:val="double" w:sz="12" w:color="CBA135"/>
                    </w:pBdr>
                    <w:ind w:left="200" w:right="200"/>
                    <w:shd w:val="clear" w:fill="FEFCE8"/>
                </w:pPr>
                <w:rPr>
                    <w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/>
                    <w:sz w:val="24"/>
                    <w:color w:val="1E293B"/>
                </w:rPr>
            </w:style>
            <w:style w:type="paragraph" w:styleId="AuthorSpotlightName">
                <w:name w:val="Author Spotlight Name"/>
                <w:pPr>
                    <w:spacing w:before="100" w:after="100"/>
                </w:pPr>
                <w:rPr>
                    <w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/>
                    <w:b/>
                    <w:sz w:val="36"/>
                    <w:color w:val="D4735C"/>
                </w:rPr>
            </w:style>
            <w:style w:type="paragraph" w:styleId="PremiumDivider">
                <w:name w:val="Premium Divider"/>
                <w:pPr>
                    <w:spacing w:before="400" w:after="400"/>
                    <w:jc w:val="center"/>
                </w:pPr>
                <w:rPr>
                    <w:sz w:val="24"/>
                    <w:color w:val="CBA135"/>
                    <w:spacing w:val="100"/>
                </w:rPr>
            </w:style>
            <w:style w:type="paragraph" w:styleId="PremiumH1">
                <w:name w:val="Premium H1"/>
                <w:pPr>
                    <w:spacing w:before="500" w:after="300"/>
                    <w:jc w:val="center"/>
                </w:pPr>
                <w:rPr>
                    <w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/>
                    <w:b/>
                    <w:caps/>
                    <w:sz w:val="32"/>
                    <w:color w:val="CBA135"/>
                    <w:spacing w:val="60"/>
                </w:rPr>
            </w:style>
            <w:style w:type="paragraph" w:styleId="PremiumH1Ornament">
                <w:name w:val="Premium H1 Ornament"/>
                <w:pPr>
                    <w:spacing w:before="200" w:after="100"/>
                    <w:jc w:val="center"/>
                </w:pPr>
                <w:rPr>
                    <w:sz w:val="16"/>
                    <w:color w:val="CBA135"/>
                    <w:spacing w:val="80"/>
                </w:rPr>
            </w:style>
            <w:style w:type="paragraph" w:styleId="PremiumH2">
                <w:name w:val="Premium H2"/>
                <w:pPr>
                    <w:spacing w:before="400" w:after="200"/>
                    <w:pBdr>
                        <w:left w:val="single" w:sz="24" w:color="CBA135"/>
                    </w:pBdr>
                    <w:ind w:left="200"/>
                </w:pPr>
                <w:rPr>
                    <w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/>
                    <w:b/>
                    <w:sz w:val="32"/>
                    <w:color w:val="0F172A"/>
                </w:rPr>
            </w:style>
            <w:style w:type="paragraph" w:styleId="PartHeader">
                <w:name w:val="Part Header"/>
                <w:pPr>
                    <w:spacing w:before="600" w:after="400"/>
                    <w:jc w:val="center"/>
                    <w:pBdr>
                        <w:top w:val="single" w:sz="12" w:color="CBA135"/>
                        <w:bottom w:val="single" w:sz="12" w:color="CBA135"/>
                    </w:pBdr>
                </w:pPr>
                <w:rPr>
                    <w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/>
                    <w:b/>
                    <w:caps/>
                    <w:sz w:val="40"/>
                    <w:color w:val="0F172A"/>
                    <w:spacing w:val="60"/>
                </w:rPr>
            </w:style>
            <w:style w:type="paragraph" w:styleId="PartOrnament">
                <w:name w:val="Part Ornament"/>
                <w:pPr>
                    <w:spacing w:before="100" w:after="100"/>
                    <w:jc w:val="center"/>
                </w:pPr>
                <w:rPr>
                    <w:sz w:val="28"/>
                    <w:color w:val="CBA135"/>
                    <w:spacing w:val="80"/>
                </w:rPr>
            </w:style>
        </w:styles>
        """
    }

    private func createDOCXDocument(content: String, title: String, author: String) -> String {
        var paragraphs = ""
        var inTable = false
        var tableRows: [[String]] = []

        // ============================================
        // COVER PAGE - Premium branded design
        // ============================================

        // Top spacing to push content down
        for _ in 0..<4 {
            paragraphs += "<w:p><w:pPr><w:spacing w:after=\"0\"/></w:pPr></w:p>"
        }

        // Top tagline - "Where Understanding Illuminates the World"
        paragraphs += """
        <w:p>
            <w:pPr>
                <w:jc w:val="center"/>
                <w:spacing w:after="200"/>
            </w:pPr>
            <w:r>
                <w:rPr>
                    <w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/>
                    <w:sz w:val="18"/>
                    <w:color w:val="5C4A3D"/>
                    <w:spacing w:val="40"/>
                </w:rPr>
                <w:t>WHERE UNDERSTANDING ILLUMINATES THE WORLD</w:t>
            </w:r>
        </w:p>
        """

        // Decorative line under tagline
        paragraphs += """
        <w:p>
            <w:pPr>
                <w:jc w:val="center"/>
                <w:spacing w:after="600"/>
            </w:pPr>
            <w:r>
                <w:rPr>
                    <w:color w:val="CBA135"/>
                </w:rPr>
                <w:t>━━━━━━━━━━</w:t>
            </w:r>
        </w:p>
        """

        // Large spacing before title area
        for _ in 0..<6 {
            paragraphs += "<w:p><w:pPr><w:spacing w:after=\"0\"/></w:pPr></w:p>"
        }

        // Logo placeholder - decorative circle with "IA" monogram
        paragraphs += """
        <w:p>
            <w:pPr>
                <w:jc w:val="center"/>
                <w:spacing w:after="100"/>
            </w:pPr>
            <w:r>
                <w:rPr>
                    <w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/>
                    <w:b/>
                    <w:sz w:val="72"/>
                    <w:color w:val="CBA135"/>
                </w:rPr>
                <w:t>◎</w:t>
            </w:r>
        </w:p>
        """

        // Large spacing before title
        for _ in 0..<4 {
            paragraphs += "<w:p><w:pPr><w:spacing w:after=\"0\"/></w:pPr></w:p>"
        }

        // Book Title - Large, prominent
        paragraphs += """
        <w:p>
            <w:pPr>
                <w:jc w:val="center"/>
                <w:spacing w:after="200"/>
            </w:pPr>
            <w:r>
                <w:rPr>
                    <w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/>
                    <w:b/>
                    <w:sz w:val="56"/>
                    <w:color w:val="2D2520"/>
                </w:rPr>
                <w:t>\(escapeXML(title))</w:t>
            </w:r>
        </w:p>
        """

        // "by" label
        paragraphs += """
        <w:p>
            <w:pPr>
                <w:jc w:val="center"/>
                <w:spacing w:after="60"/>
            </w:pPr>
            <w:r>
                <w:rPr>
                    <w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/>
                    <w:i/>
                    <w:sz w:val="22"/>
                    <w:color w:val="5C5248"/>
                </w:rPr>
                <w:t>by</w:t>
            </w:r>
        </w:p>
        """

        // Author name
        paragraphs += """
        <w:p>
            <w:pPr>
                <w:jc w:val="center"/>
                <w:spacing w:after="200"/>
            </w:pPr>
            <w:r>
                <w:rPr>
                    <w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/>
                    <w:sz w:val="32"/>
                    <w:color w:val="3D3229"/>
                </w:rPr>
                <w:t>\(escapeXML(author))</w:t>
            </w:r>
        </w:p>
        """

        // Decorative line under author
        paragraphs += """
        <w:p>
            <w:pPr>
                <w:jc w:val="center"/>
                <w:spacing w:after="400"/>
            </w:pPr>
            <w:r>
                <w:rPr>
                    <w:color w:val="CBA135"/>
                </w:rPr>
                <w:t>━━━━━</w:t>
            </w:r>
        </w:p>
        """

        // Large spacing before bottom branding
        for _ in 0..<8 {
            paragraphs += "<w:p><w:pPr><w:spacing w:after=\"0\"/></w:pPr></w:p>"
        }

        // Brand name - "Insight Atlas"
        paragraphs += """
        <w:p>
            <w:pPr>
                <w:jc w:val="center"/>
                <w:spacing w:after="60"/>
            </w:pPr>
            <w:r>
                <w:rPr>
                    <w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/>
                    <w:b/>
                    <w:sz w:val="36"/>
                    <w:color w:val="CBA135"/>
                </w:rPr>
                <w:t>Insight Atlas</w:t>
            </w:r>
        </w:p>
        """

        // Subtitle - "A Comprehensive Analysis Guide"
        paragraphs += """
        <w:p>
            <w:pPr>
                <w:jc w:val="center"/>
                <w:spacing w:after="0"/>
            </w:pPr>
            <w:r>
                <w:rPr>
                    <w:rFonts w:ascii="Helvetica Neue" w:hAnsi="Helvetica Neue"/>
                    <w:sz w:val="16"/>
                    <w:color w:val="5C5248"/>
                    <w:spacing w:val="30"/>
                </w:rPr>
                <w:t>A COMPREHENSIVE ANALYSIS GUIDE</w:t>
            </w:r>
        </w:p>
        """

        // Page break after cover page
        paragraphs += """
        <w:p>
            <w:r>
                <w:br w:type="page"/>
            </w:r>
        </w:p>
        """

        // ============================================
        // CONTENT PAGES - Start after page break
        // ============================================

        // Content header - smaller branded header for content pages
        paragraphs += """
        <w:p>
            <w:pPr><w:jc w:val="center"/></w:pPr>
            <w:r>
                <w:rPr>
                    <w:sz w:val="18"/>
                    <w:color w:val="CBA135"/>
                    <w:spacing w:val="60"/>
                </w:rPr>
                <w:t>INSIGHT ATLAS GUIDE</w:t>
            </w:r>
        </w:p>
        """

        // Content title
        paragraphs += """
        <w:p>
            <w:pPr><w:pStyle w:val="Title"/></w:pPr>
            <w:r><w:t>\(escapeXML(title))</w:t></w:r>
        </w:p>
        """

        // Content author
        paragraphs += """
        <w:p>
            <w:pPr><w:jc w:val="center"/></w:pPr>
            <w:r>
                <w:rPr><w:i/><w:color w:val="4A5568"/></w:rPr>
                <w:t>by \(escapeXML(author))</w:t>
            </w:r>
        </w:p>
        """

        // Divider
        paragraphs += """
        <w:p>
            <w:pPr>
                <w:pBdr>
                    <w:bottom w:val="single" w:sz="12" w:color="CBA135"/>
                </w:pBdr>
            </w:pPr>
        </w:p>
        """

        // Parse content
        var inSpecialBlock = false
        var specialBlockType = ""
        var specialBlockContent = ""

        let lines = content.components(separatedBy: "\n")

        for line in lines {
            // Handle special blocks
            if line.hasPrefix("[QUICK_GLANCE]") {
                inSpecialBlock = true
                specialBlockType = "QuickGlance"
                specialBlockContent = ""
                paragraphs += createDOCXBlockHeader(icon: "📋", title: "QUICK GLANCE")
                continue
            }
            if line.hasPrefix("[INSIGHT_NOTE]") {
                inSpecialBlock = true
                specialBlockType = "InsightNote"
                specialBlockContent = ""
                paragraphs += createDOCXBlockHeader(icon: "💡", title: "INSIGHT ATLAS NOTE")
                continue
            }
            if line.hasPrefix("[ACTION_BOX") {
                inSpecialBlock = true
                specialBlockType = "ActionBox"
                specialBlockContent = ""
                paragraphs += createDOCXBlockHeader(icon: "✓", title: "APPLY IT")
                continue
            }
            if line.hasPrefix("[FOUNDATIONAL_NARRATIVE]") {
                inSpecialBlock = true
                specialBlockType = "FoundationalNarrative"
                specialBlockContent = ""
                // Add header for block
                paragraphs += createDOCXBlockHeader(icon: "📖", title: "THE STORY BEHIND THE IDEAS")
                continue
            }
            if line.hasPrefix("[TAKEAWAYS]") {
                inSpecialBlock = true
                specialBlockType = "Takeaways"
                specialBlockContent = ""
                paragraphs += createDOCXBlockHeader(icon: "⭐", title: "KEY TAKEAWAYS")
                continue
            }
            if line.hasPrefix("[VISUAL_FLOWCHART") {
                inSpecialBlock = true
                specialBlockType = "Flowchart"
                specialBlockContent = ""
                paragraphs += createDOCXBlockHeader(icon: "📊", title: "VISUAL GUIDE")
                continue
            }
            if line.hasPrefix("[EXERCISE_") {
                inSpecialBlock = true
                specialBlockType = "Exercise"
                specialBlockContent = ""
                paragraphs += createDOCXBlockHeader(icon: "✏️", title: "EXERCISE")
                continue
            }
            if line.hasPrefix("[STRUCTURE_MAP]") || line.hasPrefix("[VISUAL_TABLE") || line.hasPrefix("[QUOTE]") {
                inSpecialBlock = true
                specialBlockType = "Normal"
                specialBlockContent = ""
                continue
            }
            // Premium block types
            if line.hasPrefix("[PREMIUM_QUOTE]") {
                inSpecialBlock = true
                specialBlockType = "PremiumQuote"
                specialBlockContent = ""
                continue
            }
            if line.hasPrefix("[AUTHOR_SPOTLIGHT]") {
                inSpecialBlock = true
                specialBlockType = "AuthorSpotlight"
                specialBlockContent = ""
                paragraphs += createDOCXBlockHeader(icon: "📖", title: "ABOUT THE AUTHOR")
                continue
            }
            if line.hasPrefix("[PREMIUM_DIVIDER]") {
                paragraphs += createDOCXParagraph(text: "◆  ◇  ◆", style: "PremiumDivider")
                continue
            }
            if line.hasPrefix("[PREMIUM_H1]") {
                inSpecialBlock = true
                specialBlockType = "PremiumH1"
                specialBlockContent = ""
                paragraphs += createDOCXParagraph(text: "◆ ◇ ◆", style: "PremiumH1Ornament")
                continue
            }
            if line.hasPrefix("[PREMIUM_H2]") {
                inSpecialBlock = true
                specialBlockType = "PremiumH2"
                specialBlockContent = ""
                continue
            }

            if line.hasPrefix("[/QUICK_GLANCE]") || line.hasPrefix("[/INSIGHT_NOTE]") || line.hasPrefix("[/ACTION_BOX]") ||
               line.hasPrefix("[/FOUNDATIONAL_NARRATIVE]") || line.hasPrefix("[/STRUCTURE_MAP]") ||
               line.hasPrefix("[/TAKEAWAYS]") || line.hasPrefix("[/VISUAL_FLOWCHART]") ||
               line.hasPrefix("[/VISUAL_TABLE]") || line.hasPrefix("[/EXERCISE_") || line.hasPrefix("[/QUOTE]") ||
               // Premium block end markers
               line.hasPrefix("[/PREMIUM_QUOTE]") || line.hasPrefix("[/AUTHOR_SPOTLIGHT]") ||
               line.hasPrefix("[/PREMIUM_DIVIDER]") || line.hasPrefix("[/PREMIUM_H1]") || line.hasPrefix("[/PREMIUM_H2]") {
                if inSpecialBlock && !specialBlockContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Handle structured blocks specially
                    if specialBlockType == "InsightNote" {
                        paragraphs += createDOCXInsightNote(content: specialBlockContent)
                    } else if specialBlockType == "PremiumQuote" {
                        paragraphs += createDOCXPremiumQuote(content: specialBlockContent)
                    } else if specialBlockType == "AuthorSpotlight" {
                        paragraphs += createDOCXAuthorSpotlight(content: specialBlockContent)
                    } else if specialBlockType == "PremiumH1" {
                        paragraphs += createDOCXParagraph(text: specialBlockContent.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(), style: "PremiumH1")
                        paragraphs += createDOCXParagraph(text: "◆ ◇ ◆", style: "PremiumH1Ornament")
                    } else if specialBlockType == "PremiumH2" {
                        paragraphs += createDOCXParagraph(text: specialBlockContent.trimmingCharacters(in: .whitespacesAndNewlines), style: "PremiumH2")
                    } else {
                        paragraphs += createDOCXParagraph(text: specialBlockContent.trimmingCharacters(in: .whitespacesAndNewlines), style: specialBlockType)
                    }
                }
                inSpecialBlock = false
                specialBlockType = ""
                specialBlockContent = ""
                continue
            }

            // Skip other markers and box drawing
            if line.hasPrefix("[") && line.contains("]") && !line.contains("](") { continue }
            if line.contains("┌") || line.contains("│") || line.contains("└") || line.contains("─") || line.contains("↓") { continue }

            if inSpecialBlock {
                specialBlockContent += line + " "
                continue
            }

            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Handle table rows
            if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") {
                // Skip separator rows
                if trimmed.contains("---") || isTableSeparator(trimmed) {
                    continue
                }
                let cells = parseTableRow(trimmed)
                if !cells.isEmpty {
                    if !inTable {
                        inTable = true
                        tableRows = []
                    }
                    tableRows.append(cells)
                }
                continue
            } else if inTable {
                // End of table - render it
                paragraphs += createDOCXTable(rows: tableRows)
                inTable = false
                tableRows = []
            }

            // Headers
            if line.hasPrefix("## ") {
                let text = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                // Check if this is a PART header (PART I, PART II, etc.)
                if text.uppercased().hasPrefix("PART ") {
                    paragraphs += createDOCXParagraph(text: "◇ ◆ ◇", style: "PartOrnament")
                    paragraphs += createDOCXParagraph(text: text, style: "PartHeader")
                    paragraphs += createDOCXParagraph(text: "◇ ◆ ◇", style: "PartOrnament")
                } else {
                    paragraphs += createDOCXParagraph(text: text, style: "Heading1")
                }
                continue
            }
            if line.hasPrefix("# ") {
                let text = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                // Check if this is a PART header (PART I, PART II, etc.)
                if text.uppercased().hasPrefix("PART ") {
                    paragraphs += createDOCXParagraph(text: "◇ ◆ ◇", style: "PartOrnament")
                    paragraphs += createDOCXParagraph(text: text, style: "PartHeader")
                    paragraphs += createDOCXParagraph(text: "◇ ◆ ◇", style: "PartOrnament")
                } else {
                    paragraphs += createDOCXParagraph(text: text, style: "Heading1")
                }
                continue
            }
            if line.hasPrefix("### ") {
                paragraphs += createDOCXParagraph(text: String(line.dropFirst(4)), style: "Heading2")
                continue
            }

            // List items - with space after marker
            if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
                paragraphs += createDOCXParagraph(text: "• " + String(line.dropFirst(2)), style: "Normal")
                continue
            }

            // List items - without space after marker
            if line.hasPrefix("-") || line.hasPrefix("*") || line.hasPrefix("•") {
                let text = String(line.dropFirst(1)).trimmingCharacters(in: .whitespaces)
                paragraphs += createDOCXParagraph(text: "• " + text, style: "Normal")
                continue
            }

            // Numbered list items - with space
            if trimmed.range(of: "^\\d+\\.\\s+", options: .regularExpression) != nil {
                paragraphs += createDOCXParagraph(text: trimmed, style: "Normal")
                continue
            }

            // Numbered list items - without space (e.g., "1.Item")
            if trimmed.range(of: "^\\d+\\.", options: .regularExpression) != nil {
                let text = trimmed.replacingOccurrences(of: "^\\d+\\.", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
                let number = trimmed.prefix(while: { $0.isNumber || $0 == "." })
                paragraphs += createDOCXParagraph(text: "\(number) \(text)", style: "Normal")
                continue
            }

            // Regular paragraphs
            if !trimmed.isEmpty {
                paragraphs += createDOCXParagraph(text: trimmed, style: "Normal")
            }
        }

        // Handle any remaining table
        if inTable && !tableRows.isEmpty {
            paragraphs += createDOCXTable(rows: tableRows)
        }

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:body>
                \(paragraphs)
            </w:body>
        </w:document>
        """
    }

    /// Create a styled block header for DOCX special blocks
    private func createDOCXBlockHeader(icon: String, title: String) -> String {
        return """
        <w:p>
            <w:pPr><w:pStyle w:val="BlockHeader"/></w:pPr>
            <w:r><w:t>\(icon) \(title)</w:t></w:r>
        </w:p>
        """
    }

    /// Create a premium quote block for DOCX with coral border and attribution
    private func createDOCXPremiumQuote(content: String) -> String {
        // Parse content for quote text and attribution
        let lines = content.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        var quoteLines: [String] = []
        var attribution: String? = nil

        for line in lines {
            if line.hasPrefix("—") || line.hasPrefix("-") {
                attribution = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
            } else if !line.isEmpty {
                quoteLines.append(line)
            }
        }

        let quoteText = quoteLines.joined(separator: " ")

        var result = """
        <w:p>
            <w:pPr><w:pStyle w:val="PremiumQuote"/></w:pPr>
            <w:r>
                <w:rPr><w:sz w:val="72"/><w:color w:val="CBA13540"/></w:rPr>
                <w:t>"</w:t>
            </w:r>
            <w:r><w:t>\(escapeXML(quoteText))</w:t></w:r>
        </w:p>
        """

        if let attr = attribution {
            result += """
            <w:p>
                <w:pPr><w:pStyle w:val="PremiumQuoteAttribution"/></w:pPr>
                <w:r><w:t>— \(escapeXML(attr))</w:t></w:r>
            </w:p>
            """
        }

        return result
    }

    /// Create an author spotlight block for DOCX with double gold border
    private func createDOCXAuthorSpotlight(content: String) -> String {
        // Parse content for author name and bio
        let lines = content.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var authorName: String? = nil
        var bioLines: [String] = []

        for line in lines {
            if authorName == nil {
                authorName = line
            } else {
                bioLines.append(line)
            }
        }

        let bio = bioLines.joined(separator: " ")

        var result = ""

        if let name = authorName {
            result += """
            <w:p>
                <w:pPr><w:pStyle w:val="AuthorSpotlightName"/></w:pPr>
                <w:r><w:t>\(escapeXML(name))</w:t></w:r>
            </w:p>
            """
        }

        if !bio.isEmpty {
            result += """
            <w:p>
                <w:pPr><w:pStyle w:val="AuthorSpotlight"/></w:pPr>
                <w:r><w:t>\(escapeXML(bio))</w:t></w:r>
            </w:p>
            """
        }

        return result
    }

    /// Create a structured INSIGHT ATLAS NOTE block for DOCX with Key Distinction, Practical Implication, Go Deeper sections
    private func createDOCXInsightNote(content: String) -> String {
        var coreConnection = ""
        var keyDistinction: String?
        var practicalImplication: String?
        var goDeeper: String?

        // Normalize content
        let normalizedContent = content.replacingOccurrences(of: "\n", with: " ")

        // Extract Key Distinction
        if let keyStart = normalizedContent.range(of: "Key Distinction:", options: .caseInsensitive) {
            var keyText = String(normalizedContent[keyStart.upperBound...])
            if let practicalStart = keyText.range(of: "Practical Implication:", options: .caseInsensitive) {
                keyText = String(keyText[..<practicalStart.lowerBound])
            } else if let goStart = keyText.range(of: "Go Deeper:", options: .caseInsensitive) {
                keyText = String(keyText[..<goStart.lowerBound])
            }
            keyDistinction = keyText.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Extract Practical Implication
        if let practStart = normalizedContent.range(of: "Practical Implication:", options: .caseInsensitive) {
            var practText = String(normalizedContent[practStart.upperBound...])
            if let goStart = practText.range(of: "Go Deeper:", options: .caseInsensitive) {
                practText = String(practText[..<goStart.lowerBound])
            }
            practicalImplication = practText.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Extract Go Deeper
        if let goStart = normalizedContent.range(of: "Go Deeper:", options: .caseInsensitive) {
            let goText = String(normalizedContent[goStart.upperBound...])
            goDeeper = goText.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Extract core connection (everything before first structured section)
        var coreText = normalizedContent
        if let keyRange = normalizedContent.range(of: "Key Distinction", options: .caseInsensitive) {
            coreText = String(normalizedContent[..<keyRange.lowerBound])
        }
        coreConnection = coreText.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespacesAndNewlines)

        var result = ""

        // Core connection paragraph
        if !coreConnection.isEmpty {
            result += """
            <w:p>
                <w:pPr><w:pStyle w:val="InsightNote"/></w:pPr>
                <w:r><w:t>\(escapeXML(coreConnection))</w:t></w:r>
            </w:p>
            """
        }

        // Key Distinction section with coral/gold accent
        if let key = keyDistinction, !key.isEmpty {
            result += """
            <w:p>
                <w:pPr>
                    <w:pStyle w:val="InsightNote"/>
                    <w:pBdr>
                        <w:left w:val="single" w:sz="24" w:color="D4735C"/>
                    </w:pBdr>
                    <w:shd w:val="clear" w:fill="FEF3F0"/>
                </w:pPr>
                <w:r>
                    <w:rPr><w:b/><w:caps/><w:sz w:val="18"/><w:color w:val="D4735C"/></w:rPr>
                    <w:t>KEY DISTINCTION</w:t>
                </w:r>
            </w:p>
            <w:p>
                <w:pPr>
                    <w:pStyle w:val="InsightNote"/>
                    <w:pBdr>
                        <w:left w:val="single" w:sz="24" w:color="D4735C"/>
                    </w:pBdr>
                    <w:shd w:val="clear" w:fill="FEF3F0"/>
                </w:pPr>
                <w:r><w:t>\(escapeXML(key))</w:t></w:r>
            </w:p>
            """
        }

        // Practical Implication section with orange accent
        if let practical = practicalImplication, !practical.isEmpty {
            result += """
            <w:p>
                <w:pPr>
                    <w:pStyle w:val="InsightNote"/>
                    <w:pBdr>
                        <w:left w:val="single" w:sz="24" w:color="F59E0B"/>
                    </w:pBdr>
                    <w:shd w:val="clear" w:fill="FFFBEB"/>
                </w:pPr>
                <w:r>
                    <w:rPr><w:b/><w:caps/><w:sz w:val="18"/><w:color w:val="D97706"/></w:rPr>
                    <w:t>PRACTICAL IMPLICATION</w:t>
                </w:r>
            </w:p>
            <w:p>
                <w:pPr>
                    <w:pStyle w:val="InsightNote"/>
                    <w:pBdr>
                        <w:left w:val="single" w:sz="24" w:color="F59E0B"/>
                    </w:pBdr>
                    <w:shd w:val="clear" w:fill="FFFBEB"/>
                </w:pPr>
                <w:r><w:t>\(escapeXML(practical))</w:t></w:r>
            </w:p>
            """
        }

        // Go Deeper section with blue accent
        if let deeper = goDeeper, !deeper.isEmpty {
            result += """
            <w:p>
                <w:pPr>
                    <w:pStyle w:val="InsightNote"/>
                    <w:pBdr>
                        <w:left w:val="single" w:sz="24" w:color="3B82F6"/>
                    </w:pBdr>
                    <w:shd w:val="clear" w:fill="EFF6FF"/>
                </w:pPr>
                <w:r>
                    <w:rPr><w:b/><w:caps/><w:sz w:val="18"/><w:color w:val="2563EB"/></w:rPr>
                    <w:t>GO DEEPER</w:t>
                </w:r>
            </w:p>
            <w:p>
                <w:pPr>
                    <w:pStyle w:val="InsightNote"/>
                    <w:pBdr>
                        <w:left w:val="single" w:sz="24" w:color="3B82F6"/>
                    </w:pBdr>
                    <w:shd w:val="clear" w:fill="EFF6FF"/>
                </w:pPr>
                <w:r>
                    <w:rPr><w:i/></w:rPr>
                    <w:t>\(escapeXML(deeper))</w:t>
                </w:r>
            </w:p>
            """
        }

        return result
    }

    private func createDOCXParagraph(text: String, style: String) -> String {
        // Parse markdown formatting and convert to DOCX runs with proper styling
        let runs = parseMarkdownToDocxRuns(text)

        return """
        <w:p>
            <w:pPr><w:pStyle w:val="\(style)"/></w:pPr>
            \(runs)
        </w:p>
        """
    }

    /// Parse markdown bold/italic and convert to DOCX runs with proper formatting
    private func parseMarkdownToDocxRuns(_ text: String) -> String {
        var result = ""
        var currentIndex = text.startIndex
        let endIndex = text.endIndex

        while currentIndex < endIndex {
            // Check for bold (**text**)
            if text[currentIndex...].hasPrefix("**") {
                let afterOpening = text.index(currentIndex, offsetBy: 2)
                if let closingRange = text.range(of: "**", range: afterOpening..<endIndex) {
                    let boldText = String(text[afterOpening..<closingRange.lowerBound])
                    result += "<w:r><w:rPr><w:b/></w:rPr><w:t>\(escapeXML(boldText))</w:t></w:r>"
                    currentIndex = closingRange.upperBound
                    continue
                }
            }

            // Check for italic (*text*) - but not bold
            if text[currentIndex...].hasPrefix("*") && !text[currentIndex...].hasPrefix("**") {
                let afterOpening = text.index(after: currentIndex)
                if afterOpening < endIndex {
                    // Find closing * that isn't part of **
                    var searchIndex = afterOpening
                    while searchIndex < endIndex {
                        if text[searchIndex] == "*" {
                            // Check it's not part of **
                            let nextIndex = text.index(after: searchIndex)
                            if nextIndex >= endIndex || text[nextIndex] != "*" {
                                let italicText = String(text[afterOpening..<searchIndex])
                                result += "<w:r><w:rPr><w:i/></w:rPr><w:t>\(escapeXML(italicText))</w:t></w:r>"
                                currentIndex = text.index(after: searchIndex)
                                break
                            }
                        }
                        searchIndex = text.index(after: searchIndex)
                    }
                    if searchIndex >= endIndex {
                        // No closing found, treat as regular text
                        result += "<w:r><w:t>\(escapeXML(String(text[currentIndex])))</w:t></w:r>"
                        currentIndex = text.index(after: currentIndex)
                    }
                    continue
                }
            }

            // Regular text - collect until next formatting marker
            var regularText = ""
            while currentIndex < endIndex && !text[currentIndex...].hasPrefix("*") {
                regularText += String(text[currentIndex])
                currentIndex = text.index(after: currentIndex)
            }
            if !regularText.isEmpty {
                result += "<w:r><w:t>\(escapeXML(regularText))</w:t></w:r>"
            }
        }

        return result
    }

    /// Creates a DOCX-formatted table from parsed rows
    private func createDOCXTable(rows: [[String]]) -> String {
        guard !rows.isEmpty else { return "" }

        var tableXML = """
        <w:tbl>
            <w:tblPr>
                <w:tblStyle w:val="TableGrid"/>
                <w:tblW w:w="5000" w:type="pct"/>
                <w:tblBorders>
                    <w:top w:val="single" w:sz="4" w:color="CBA135"/>
                    <w:left w:val="single" w:sz="4" w:color="CBA135"/>
                    <w:bottom w:val="single" w:sz="4" w:color="CBA135"/>
                    <w:right w:val="single" w:sz="4" w:color="CBA135"/>
                    <w:insideH w:val="single" w:sz="4" w:color="E8E4DC"/>
                    <w:insideV w:val="single" w:sz="4" w:color="E8E4DC"/>
                </w:tblBorders>
            </w:tblPr>
        """

        for (rowIndex, row) in rows.enumerated() {
            tableXML += "<w:tr>"

            for cell in row {
                // Parse cell content for bold/italic formatting
                let cellRuns = parseMarkdownToDocxRuns(cell)

                if rowIndex == 0 {
                    // Header row with gold background - override runs with bold white text
                    let headerText = cell.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "*", with: "")
                    tableXML += """
                    <w:tc>
                        <w:tcPr>
                            <w:shd w:val="clear" w:fill="CBA135"/>
                        </w:tcPr>
                        <w:p>
                            <w:pPr>
                                <w:jc w:val="left"/>
                            </w:pPr>
                            <w:r>
                                <w:rPr>
                                    <w:b/>
                                    <w:color w:val="FFFFFF"/>
                                    <w:sz w:val="22"/>
                                </w:rPr>
                                <w:t>\(escapeXML(headerText))</w:t>
                            </w:r>
                        </w:p>
                    </w:tc>
                    """
                } else {
                    // Data row with alternating background - preserve formatting
                    let bgColor = rowIndex % 2 == 0 ? "FFFFFF" : "F5F3ED"
                    tableXML += """
                    <w:tc>
                        <w:tcPr>
                            <w:shd w:val="clear" w:fill="\(bgColor)"/>
                        </w:tcPr>
                        <w:p>
                            \(cellRuns)
                        </w:p>
                    </w:tc>
                    """
                }
            }

            tableXML += "</w:tr>"
        }

        tableXML += "</w:tbl>"

        // Add spacing after table
        tableXML += """
        <w:p>
            <w:pPr><w:spacing w:after="200"/></w:pPr>
        </w:p>
        """

        return tableXML
    }

    private func escapeXML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private func createZipArchive(from sourceDir: URL, to destinationURL: URL) throws {
        // Remove existing file if present
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        // Use ZIPFoundation to create proper DOCX archive
        do {
            try fileManager.zipItem(at: sourceDir, to: destinationURL, shouldKeepParent: false)
        } catch {
            // Fallback to NSFileCoordinator if ZIPFoundation fails
            let coordinator = NSFileCoordinator()
            var coordinatorError: NSError?

            coordinator.coordinate(readingItemAt: sourceDir, options: .forUploading, error: &coordinatorError) { zipURL in
                do {
                    try FileManager.default.copyItem(at: zipURL, to: destinationURL)
                } catch {
                    // If copy fails, try moving
                    try? FileManager.default.moveItem(at: zipURL, to: destinationURL)
                }
            }

            if let coordinatorError = coordinatorError {
                throw DataManagerError.zipArchiveFailed(reason: coordinatorError.localizedDescription)
            }
        }
    }
}

// MARK: - Types

enum ExportFormat: String, CaseIterable {
    case markdown = "Markdown (.md)"
    case plainText = "Plain Text (.txt)"
    case html = "HTML (.html)"
    case pdf = "PDF (.pdf)"
    case docx = "Word Document (.docx)"

    var fileExtension: String {
        switch self {
        case .markdown: return "md"
        case .plainText: return "txt"
        case .html: return "html"
        case .pdf: return "pdf"
        case .docx: return "docx"
        }
    }
}

enum DataManagerError: LocalizedError {
    case noContent
    case exportFailed(reason: String)
    case pdfGenerationFailed(reason: String)
    case docxGenerationFailed(reason: String)
    case htmlConversionFailed(reason: String)
    case fileWriteFailed(path: String)
    case zipArchiveFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .noContent:
            return "No content available to export. Please generate an analysis first."
        case .exportFailed(let reason):
            return "Failed to export the guide: \(reason)"
        case .pdfGenerationFailed(let reason):
            return "PDF generation failed: \(reason)"
        case .docxGenerationFailed(let reason):
            return "Word document generation failed: \(reason)"
        case .htmlConversionFailed(let reason):
            return "HTML conversion failed: \(reason)"
        case .fileWriteFailed(let path):
            return "Failed to write file to: \(path)"
        case .zipArchiveFailed(let reason):
            return "Failed to create document archive: \(reason)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noContent:
            return "Generate an analysis for this book before exporting."
        case .exportFailed:
            return "Try a different export format or check available storage."
        case .pdfGenerationFailed:
            return "Try exporting as HTML or Markdown instead."
        case .docxGenerationFailed:
            return "Try exporting as PDF or HTML instead."
        case .htmlConversionFailed:
            return "Try exporting as Markdown or plain text instead."
        case .fileWriteFailed:
            return "Check if you have sufficient storage space."
        case .zipArchiveFailed:
            return "Try restarting the app and exporting again."
        }
    }
}
