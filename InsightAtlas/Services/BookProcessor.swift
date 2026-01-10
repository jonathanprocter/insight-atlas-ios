import Foundation
import PDFKit
import UniformTypeIdentifiers
import UIKit
import Compression
import os.log
#if canImport(ZIPFoundation)
import ZIPFoundation
#endif

private let bookLogger = Logger(subsystem: "com.insightatlas", category: "BookProcessor")

/// Service for processing book files (PDF and EPUB)
actor BookProcessor {

    // MARK: - Properties

    /// Text fixer for cleaning PDF extraction artifacts
    private let textFixer = PDFTextFixer(options: PDFTextFixer.Options.all, typographyMode: PDFTextFixer.TypographyMode.normalize)

    // MARK: - Public Interface

    struct ProcessedBook {
        let text: String
        let pageCount: Int
        let title: String?
        let author: String?
        let description: String?
        let coverImageData: Data?
    }

    /// Process a book file and extract text content
    func processBook(from url: URL) async throws -> ProcessedBook {
        let fileExtension = url.pathExtension.lowercased()

        switch fileExtension {
        case "pdf":
            return try await processPDF(from: url)
        case "epub":
            return try await processEPUB(from: url)
        default:
            throw BookProcessorError.unsupportedFormat(fileExtension)
        }
    }

    /// Process book from data with specified file type
    func processBook(from data: Data, fileType: FileType) async throws -> ProcessedBook {
        switch fileType {
        case .pdf:
            return try await processPDFData(data)
        case .epub:
            return try await processEPUBData(data)
        }
    }

    // MARK: - PDF Processing

    private func processPDF(from url: URL) async throws -> ProcessedBook {
        guard let document = PDFDocument(url: url) else {
            throw BookProcessorError.failedToLoad
        }

        return try await extractPDFContent(from: document)
    }

    private func processPDFData(_ data: Data) async throws -> ProcessedBook {
        guard let document = PDFDocument(data: data) else {
            throw BookProcessorError.failedToLoad
        }

        return try await extractPDFContent(from: document)
    }

    private func extractPDFContent(from document: PDFDocument) async throws -> ProcessedBook {
        bookLogger.info("Starting PDF extraction, page count: \(document.pageCount)")

        var textContent = ""
        let pageCount = document.pageCount
        var firstPagesText = "" // For author extraction fallback

        for pageIndex in 0..<pageCount {
            autoreleasepool {
                if let page = document.page(at: pageIndex),
                   let pageText = page.string {
                    // Capture first 5 pages for metadata extraction fallback
                    if pageIndex < 5 {
                        firstPagesText += pageText + "\n"
                    }
                    // Add form feed between pages to help identify page breaks
                    textContent += pageText + "\n\u{000C}\n"
                }
            }

            // Log progress every 50 pages
            if pageIndex > 0 && pageIndex % 50 == 0 {
                bookLogger.info("PDF extraction progress: \(pageIndex)/\(pageCount) pages")
            }
        }

        bookLogger.info("PDF raw text extracted: \(textContent.count) characters from \(pageCount) pages")

        guard !textContent.isEmpty else {
            bookLogger.error("No text content extracted from PDF")
            throw BookProcessorError.noTextContent
        }

        // Apply comprehensive text fixing for ligatures and encoding issues
        bookLogger.info("Starting PDF text fixing...")
        let fixedText = textFixer.fix(textContent)
        bookLogger.info("PDF text fixing complete: \(fixedText.count) characters")

        let sanitizedText = sanitizeSourceText(fixedText)
        bookLogger.info("PDF text sanitization complete: \(sanitizedText.count) characters")

        // Try to extract metadata from document attributes first
        let title = document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String
        var author = document.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String

        bookLogger.info("PDF metadata - Title: \(title ?? "none"), Author: \(author ?? "none")")

        // If no author in metadata, try to extract from first pages (title page parsing)
        if author == nil || author?.isEmpty == true {
            let extractedAuthor = extractAuthorFromTitlePages(firstPagesText)
            if let extracted = extractedAuthor, !extracted.isEmpty {
                author = extracted
                bookLogger.info("Author extracted from title page: \(extracted)")
            }
        }

        let coverImageData = renderPDFCoverImageData(from: document)

        bookLogger.info("PDF processing complete")

        return ProcessedBook(
            text: sanitizedText.trimmingCharacters(in: .whitespacesAndNewlines),
            pageCount: pageCount,
            title: title,
            author: author,
            description: nil,
            coverImageData: coverImageData
        )
    }

    // MARK: - Author Extraction from Title Pages

    /// Attempts to extract author name from the first few pages of a book
    /// Uses multiple heuristics to find author information
    private func extractAuthorFromTitlePages(_ text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Heuristic 1: Look for "by Author Name" pattern
        for line in lines {
            let lowercased = line.lowercased()
            if lowercased.hasPrefix("by ") {
                let authorCandidate = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                if isValidAuthorName(authorCandidate) {
                    return authorCandidate
                }
            }
        }

        // Heuristic 2: Look for "Author:" label
        for line in lines {
            let lowercased = line.lowercased()
            if lowercased.hasPrefix("author:") || lowercased.hasPrefix("written by:") {
                let authorCandidate = line.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                if isValidAuthorName(authorCandidate) {
                    return authorCandidate
                }
            }
        }

        // Heuristic 3: Look for common author patterns in early lines
        // Format: "FirstName LastName" on a line by itself (often on title page)
        let titlePageLines = lines.prefix(30) // Focus on first 30 non-empty lines
        for (index, line) in titlePageLines.enumerated() {
            // Skip very long lines (likely paragraphs)
            if line.count > 50 { continue }

            // Skip lines with common non-author patterns
            let lowercased = line.lowercased()
            if lowercased.contains("copyright") ||
               lowercased.contains("isbn") ||
               lowercased.contains("edition") ||
               lowercased.contains("published") ||
               lowercased.contains("press") ||
               lowercased.contains("chapter") ||
               lowercased.contains("contents") ||
               lowercased.contains("table of") ||
               lowercased.contains("foreword") ||
               lowercased.contains("introduction") ||
               lowercased.contains("preface") ||
               lowercased.contains("dedication") {
                continue
            }

            // Look for "Name, PhD" or "Name, MD" patterns
            if let commaIndex = line.firstIndex(of: ",") {
                let afterComma = String(line[line.index(after: commaIndex)...]).trimmingCharacters(in: .whitespaces).uppercased()
                let credentials = ["PHD", "PH.D", "MD", "M.D", "LCSW", "LMFT", "PSYD", "PSY.D", "MBA", "JD", "J.D", "DR", "DR."]
                for credential in credentials {
                    if afterComma.hasPrefix(credential) {
                        let namePart = String(line[..<commaIndex]).trimmingCharacters(in: .whitespaces)
                        if isValidAuthorName(namePart) {
                            return namePart
                        }
                    }
                }
            }

            // Check if line looks like a proper name (2-4 words, capitalized)
            // But exclude common book title patterns
            if index < 10 && isValidAuthorName(line) && looksLikeProperName(line) && !looksLikeBookTitle(line) {
                return line
            }
        }

        // Heuristic 4: Look for author in copyright notice
        for line in lines.prefix(100) {
            let lowercased = line.lowercased()
            if lowercased.contains("copyright") && lowercased.contains("©") {
                // Extract year and name pattern: "© 2020 Author Name" or "Copyright © 2020 by Author Name"
                let pattern = #"©\s*\d{4}\s*(?:by\s+)?([A-Z][a-zA-Z]+(?:\s+[A-Z][a-zA-Z]+)+)"#
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                   let range = Range(match.range(at: 1), in: line) {
                    let authorCandidate = String(line[range])
                    if isValidAuthorName(authorCandidate) {
                        return authorCandidate
                    }
                }
            }
        }

        return nil
    }

    /// Validates that a string looks like a plausible author name
    private func isValidAuthorName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)

        // Must be at least 3 characters
        if trimmed.count < 3 { return false }

        // Must not be too long (likely a title or sentence)
        if trimmed.count > 60 { return false }

        // Must not contain certain characters
        let invalidChars = CharacterSet(charactersIn: "@#$%^&*()+=[]{}|\\<>?/~`")
        if trimmed.rangeOfCharacter(from: invalidChars) != nil { return false }

        // Must contain at least one letter
        if trimmed.rangeOfCharacter(from: .letters) == nil { return false }

        // Should not start with numbers
        if let first = trimmed.first, first.isNumber { return false }

        return true
    }

    /// Checks if a line looks like a proper name (First Last format)
    private func looksLikeProperName(_ text: String) -> Bool {
        let words = text.split(separator: " ").map { String($0) }

        // Should be 2-5 words
        if words.count < 2 || words.count > 5 { return false }

        // Each word should be capitalized or a connector
        let connectors = Set(["de", "van", "von", "del", "la", "le", "da", "di", "and", "and", "Jr.", "Jr", "Sr.", "Sr", "III", "II", "IV"])
        for word in words {
            if connectors.contains(word) { continue }
            guard let first = word.first, first.isUppercase else { return false }
        }

        return true
    }

    /// Checks if a line looks like a book title rather than an author name
    private func looksLikeBookTitle(_ text: String) -> Bool {
        let lowercased = text.lowercased()

        // Common book title starters
        let titlePrefixes = ["the ", "a ", "an ", "how ", "why ", "what ", "when ", "where ", "who "]
        for prefix in titlePrefixes {
            if lowercased.hasPrefix(prefix) { return true }
        }

        // Common title patterns
        let titlePatterns = [
            "guide to", "art of", "power of", "science of", "way of",
            "secrets of", "rules of", "laws of", "principles of", "habits of",
            "introduction to", "essentials of", "basics of", "fundamentals of"
        ]
        for pattern in titlePatterns {
            if lowercased.contains(pattern) { return true }
        }

        // Contains subtitle indicator
        if text.contains(":") || text.contains(" - ") { return true }

        return false
    }

    // MARK: - EPUB Processing

    private func processEPUB(from url: URL) async throws -> ProcessedBook {
        let data = try Data(contentsOf: url)
        return try await processEPUBData(data)
    }

    private func processEPUBData(_ data: Data) async throws -> ProcessedBook {
        bookLogger.info("Starting EPUB processing, data size: \(data.count) bytes")

        // Create temporary file for EPUB processing
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("epub")

        do {
            try data.write(to: tempURL)
            bookLogger.info("EPUB written to temp file: \(tempURL.path)")
        } catch {
            bookLogger.error("Failed to write EPUB to temp file: \(error.localizedDescription)")
            throw error
        }

        defer { try? FileManager.default.removeItem(at: tempURL) }

        return try await extractEPUBContent(from: tempURL)
    }

    private func extractEPUBContent(from url: URL) async throws -> ProcessedBook {
        bookLogger.info("Extracting EPUB content from: \(url.lastPathComponent)")

        // EPUB is a ZIP archive containing XHTML files
        let fileManager = FileManager.default
        let extractionDir = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        do {
            try fileManager.createDirectory(at: extractionDir, withIntermediateDirectories: true)
            bookLogger.info("Created extraction directory: \(extractionDir.path)")
        } catch {
            bookLogger.error("Failed to create extraction directory: \(error.localizedDescription)")
            throw error
        }

        defer { try? fileManager.removeItem(at: extractionDir) }

        // Unzip EPUB
        do {
            try await unzipFile(at: url, to: extractionDir)
            bookLogger.info("EPUB unzipped successfully")
        } catch {
            bookLogger.error("Failed to unzip EPUB: \(error.localizedDescription)")
            throw error
        }

        // Find and parse content
        var textContent = ""
        var title: String?
        var author: String?
        var description: String?

        // Parse container.xml to find content.opf
        let containerPath = extractionDir
            .appendingPathComponent("META-INF")
            .appendingPathComponent("container.xml")

        var opfURL: URL?
        var opfDir: URL?

        if let containerData = try? Data(contentsOf: containerPath),
           let containerString = readString(from: containerData) {
            // Extract rootfile path
            if let rootfilePath = extractRootfilePath(from: containerString) {
                let safeOPFURL = safeResolvedURL(base: extractionDir, relativePath: rootfilePath)
                opfURL = safeOPFURL
                opfDir = safeOPFURL?.deletingLastPathComponent()
            }
        }

        // Fallback: search for .opf file if container.xml parsing failed
        if opfURL == nil {
            opfURL = findOPFFile(in: extractionDir)
            opfDir = opfURL?.deletingLastPathComponent()
        }

        var coverImageData: Data?
        if let opfURL = opfURL, let opfDir = opfDir,
           let opfData = try? Data(contentsOf: opfURL),
           let opfString = readString(from: opfData) {

            // Extract metadata
            title = extractMetadata(tag: "dc:title", from: opfString)
                 ?? extractMetadata(tag: "title", from: opfString)
            author = extractMetadata(tag: "dc:creator", from: opfString)
                  ?? extractMetadata(tag: "creator", from: opfString)
            description = extractMetadata(tag: "dc:description", from: opfString)
                       ?? extractMetadata(tag: "description", from: opfString)

            // Extract spine items (reading order)
            let spineItems = extractSpineItems(from: opfString)
            let manifest = extractManifest(from: opfString)
            coverImageData = extractCoverImageData(from: opfString, opfDir: opfDir, manifest: manifest)

            // Process spine items in order
            for itemId in spineItems {
                if let href = manifest[itemId] {
                    // Decode URL-encoded paths
                    let decodedHref = href.removingPercentEncoding ?? href
                    if let contentURL = safeResolvedURL(base: opfDir, relativePath: decodedHref),
                       let htmlString = readHTMLFile(at: contentURL) {
                        let plainText = stripHTML(from: htmlString)
                        if !plainText.isEmpty {
                            textContent += plainText + "\n\n"
                        }
                    }
                }
            }

            // Fallback: if spine processing yielded no content, try all XHTML/HTML files
            if textContent.isEmpty {
                textContent = extractAllHTMLContent(from: extractionDir)
            }
        } else {
            // Complete fallback: just extract all HTML content we can find
            textContent = extractAllHTMLContent(from: extractionDir)
        }

        guard !textContent.isEmpty else {
            bookLogger.error("No text content extracted from EPUB")
            throw BookProcessorError.noTextContent
        }

        bookLogger.info("Raw text extracted: \(textContent.count) characters")

        // Apply comprehensive text fixing for ligatures and encoding issues (same as PDF)
        bookLogger.info("Starting EPUB text fixing...")
        let fixedText = textFixer.fix(textContent)
        bookLogger.info("EPUB text fixing complete: \(fixedText.count) characters")

        let sanitizedText = sanitizeSourceText(fixedText)
        bookLogger.info("Text sanitization complete: \(sanitizedText.count) characters")

        // Estimate page count (assuming ~250 words per page)
        let wordCount = fixedText.split(separator: " ").count
        let estimatedPages = max(1, wordCount / 250)

        bookLogger.info("EPUB processing complete: \(wordCount) words, ~\(estimatedPages) pages")

        return ProcessedBook(
            text: sanitizedText.trimmingCharacters(in: .whitespacesAndNewlines),
            pageCount: estimatedPages,
            title: title,
            author: author,
            description: description,
            coverImageData: coverImageData
        )
    }

    // MARK: - Source Sanitization

    /// Remove prompt/instruction leaks appended to book text.
    /// This protects generation from ingesting system/user prompt transcripts.
    private func sanitizeSourceText(_ text: String) -> String {
        let markers = [
            "EXACT PROMPTS USED BY INSIGHT ATLAS",
            "SYSTEM MESSAGE",
            "USER PROMPT",
            "MODEL CONFIGURATION",
            "HOW THE PROMPTS WORK",
            "KEY DIFFERENCES",
            "UPDATED BRAND MANIFESTO",
            "UPDATED BRAND IDENTITY GUIDELINES",
            "UPDATED ABOUT PAGE",
            "INSIGHT ATLAS EXISTS FOR ONE PURPOSE",
            "INSIGHT ATLAS IS WHERE THOSE WHO BEAR THE WEIGHT OF UNDERSTANDING"
        ]

        let uppercased = text.uppercased()
        var earliestIndex: String.Index?
        for marker in markers {
            if let range = uppercased.range(of: marker) {
                if earliestIndex == nil || range.lowerBound < earliestIndex! {
                    earliestIndex = range.lowerBound
                }
            }
        }

        guard let cutIndex = earliestIndex else {
            return text
        }

        let prefix = String(text[..<cutIndex])
        return prefix.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Try reading data as string with multiple encodings
    private func readString(from data: Data) -> String? {
        // Try UTF-8 first
        if let string = String(data: data, encoding: .utf8) {
            return string
        }
        // Try other common encodings
        let encodings: [String.Encoding] = [.utf16, .utf16LittleEndian, .utf16BigEndian, .isoLatin1, .windowsCP1252, .ascii]
        for encoding in encodings {
            if let string = String(data: data, encoding: encoding) {
                return string
            }
        }
        return nil
    }

    /// Read HTML file with encoding detection
    private func readHTMLFile(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return readString(from: data)
    }

    /// Find .opf file by searching the extraction directory
    private func findOPFFile(in directory: URL) -> URL? {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        while let fileURL = enumerator.nextObject() as? URL {
            if fileURL.pathExtension.lowercased() == "opf" {
                return fileURL
            }
        }
        return nil
    }

    /// Extract text from all HTML/XHTML files as a fallback
    private func extractAllHTMLContent(from directory: URL) -> String {
        let fileManager = FileManager.default
        var textContent = ""

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return textContent
        }

        var htmlFiles: [URL] = []
        while let fileURL = enumerator.nextObject() as? URL {
            let ext = fileURL.pathExtension.lowercased()
            if ext == "xhtml" || ext == "html" || ext == "htm" {
                htmlFiles.append(fileURL)
            }
        }

        // Sort files by name for some order
        htmlFiles.sort { $0.lastPathComponent < $1.lastPathComponent }

        for fileURL in htmlFiles {
            if let htmlString = readHTMLFile(at: fileURL) {
                let plainText = stripHTML(from: htmlString)
                if !plainText.isEmpty {
                    textContent += plainText + "\n\n"
                }
            }
        }

        return textContent
    }

    // MARK: - Helpers

    private func unzipFile(at sourceURL: URL, to destinationURL: URL) async throws {
        #if canImport(ZIPFoundation)
        // Use the throwing initializer (non-deprecated)
        let archive: Archive
        do {
            archive = try Archive(url: sourceURL, accessMode: .read)
        } catch {
            throw BookProcessorError.extractionFailed
        }

        let fileManager = FileManager.default

        for entry in archive {
            guard let entryDestination = safeResolvedURL(base: destinationURL, relativePath: entry.path) else {
                throw BookProcessorError.invalidPath
            }

            if entry.type == .directory {
                try fileManager.createDirectory(
                    at: entryDestination,
                    withIntermediateDirectories: true
                )
            } else {
                let parentDir = entryDestination.deletingLastPathComponent()
                try fileManager.createDirectory(
                    at: parentDir,
                    withIntermediateDirectories: true
                )
                _ = try archive.extract(entry, to: entryDestination)
            }
        }
        #else
        throw BookProcessorError.extractionFailed
        #endif
    }

    private func extractRootfilePath(from containerXML: String) -> String? {
        // Simple regex to extract rootfile path
        let pattern = #"full-path="([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: containerXML,
                range: NSRange(containerXML.startIndex..., in: containerXML)
              ),
              let range = Range(match.range(at: 1), in: containerXML) else {
            return nil
        }
        return String(containerXML[range])
    }

    private func extractMetadata(tag: String, from opfString: String) -> String? {
        let pattern = "<\(tag)[^>]*>([^<]+)</\(tag)>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(
                in: opfString,
                range: NSRange(opfString.startIndex..., in: opfString)
              ),
              let range = Range(match.range(at: 1), in: opfString) else {
            return nil
        }
        return String(opfString[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractSpineItems(from opfString: String) -> [String] {
        var items: [String] = []
        let pattern = #"<itemref[^>]+idref="([^"]+)""#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return items
        }

        let matches = regex.matches(
            in: opfString,
            range: NSRange(opfString.startIndex..., in: opfString)
        )

        for match in matches {
            if let range = Range(match.range(at: 1), in: opfString) {
                items.append(String(opfString[range]))
            }
        }

        return items
    }

    private func extractManifest(from opfString: String) -> [String: String] {
        var manifest: [String: String] = [:]

        // Pattern to match <item> tags - we'll extract id and href separately
        let itemPattern = #"<item\s+([^>]+)/?\s*>"#

        guard let itemRegex = try? NSRegularExpression(pattern: itemPattern, options: .caseInsensitive) else {
            return manifest
        }

        let matches = itemRegex.matches(
            in: opfString,
            range: NSRange(opfString.startIndex..., in: opfString)
        )

        let idPattern = #"id\s*=\s*["']([^"']+)["']"#
        let hrefPattern = #"href\s*=\s*["']([^"']+)["']"#

        guard let idRegex = try? NSRegularExpression(pattern: idPattern, options: .caseInsensitive),
              let hrefRegex = try? NSRegularExpression(pattern: hrefPattern, options: .caseInsensitive) else {
            return manifest
        }

        for match in matches {
            if let attributesRange = Range(match.range(at: 1), in: opfString) {
                let attributes = String(opfString[attributesRange])
                let attrNSRange = NSRange(attributes.startIndex..., in: attributes)

                var itemId: String?
                var itemHref: String?

                if let idMatch = idRegex.firstMatch(in: attributes, range: attrNSRange),
                   let idRange = Range(idMatch.range(at: 1), in: attributes) {
                    itemId = String(attributes[idRange])
                }

                if let hrefMatch = hrefRegex.firstMatch(in: attributes, range: attrNSRange),
                   let hrefRange = Range(hrefMatch.range(at: 1), in: attributes) {
                    itemHref = String(attributes[hrefRange])
                }

                if let id = itemId, let href = itemHref {
                    manifest[id] = href
                }
            }
        }

        return manifest
    }

    private struct ManifestItem {
        let id: String
        let href: String
        let mediaType: String?
        let properties: String?
    }

    private func extractManifestItems(from opfString: String) -> [ManifestItem] {
        var items: [ManifestItem] = []
        let itemPattern = #"<item\s+([^>]+)/?\s*>"#

        guard let itemRegex = try? NSRegularExpression(pattern: itemPattern, options: .caseInsensitive) else {
            return items
        }

        let matches = itemRegex.matches(
            in: opfString,
            range: NSRange(opfString.startIndex..., in: opfString)
        )

        for match in matches {
            guard let attributesRange = Range(match.range(at: 1), in: opfString) else { continue }
            let attributes = String(opfString[attributesRange])
            let id = attributeValue("id", in: attributes)
            let href = attributeValue("href", in: attributes)
            guard let itemId = id, let itemHref = href else { continue }

            let mediaType = attributeValue("media-type", in: attributes)
            let properties = attributeValue("properties", in: attributes)
            items.append(ManifestItem(id: itemId, href: itemHref, mediaType: mediaType, properties: properties))
        }

        return items
    }

    private func attributeValue(_ name: String, in attributes: String) -> String? {
        let pattern = "\(name)\\s*=\\s*[\"']([^\"']+)[\"']"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(
                in: attributes,
                range: NSRange(attributes.startIndex..., in: attributes)
              ),
              let range = Range(match.range(at: 1), in: attributes) else {
            return nil
        }
        return String(attributes[range])
    }

    private func extractCoverImageData(from opfString: String, opfDir: URL, manifest: [String: String]) -> Data? {
        let items = extractManifestItems(from: opfString)

        if let coverId = extractCoverId(from: opfString),
           let href = manifest[coverId],
           let data = loadCoverImageData(href: href, opfDir: opfDir) {
            return data
        }

        if let coverItem = items.first(where: { $0.properties?.contains("cover-image") == true }),
           let data = loadCoverImageData(href: coverItem.href, opfDir: opfDir) {
            return data
        }

        if let coverItem = items.first(where: {
            ($0.mediaType?.hasPrefix("image/") == true) &&
            $0.href.lowercased().contains("cover")
        }), let data = loadCoverImageData(href: coverItem.href, opfDir: opfDir) {
            return data
        }

        if let coverItem = items.first(where: { $0.mediaType?.hasPrefix("image/") == true }),
           let data = loadCoverImageData(href: coverItem.href, opfDir: opfDir) {
            return data
        }

        return nil
    }

    private func extractCoverId(from opfString: String) -> String? {
        let pattern = #"<meta[^>]+name=["']cover["'][^>]+content=["']([^"']+)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(
                in: opfString,
                range: NSRange(opfString.startIndex..., in: opfString)
              ),
              let range = Range(match.range(at: 1), in: opfString) else {
            return nil
        }
        return String(opfString[range])
    }

    private func safeResolvedURL(base: URL, relativePath: String) -> URL? {
        let baseURL = base.standardizedFileURL
        let candidate = URL(fileURLWithPath: relativePath, relativeTo: baseURL).standardizedFileURL
        let basePath = baseURL.path.hasSuffix("/") ? baseURL.path : baseURL.path + "/"
        guard candidate.path.hasPrefix(basePath) else { return nil }
        return candidate
    }

    private func loadCoverImageData(href: String, opfDir: URL) -> Data? {
        let decodedHref = href.removingPercentEncoding ?? href
        guard let coverURL = safeResolvedURL(base: opfDir, relativePath: decodedHref) else {
            return nil
        }
        return try? Data(contentsOf: coverURL)
    }

    private func renderPDFCoverImageData(from document: PDFDocument) -> Data? {
        guard let page = document.page(at: 0) else { return nil }
        let pageRect = page.bounds(for: .mediaBox)
        let maxDimension: CGFloat = 600
        let scale = min(maxDimension / max(pageRect.width, pageRect.height), 1)
        let size = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            context.cgContext.saveGState()
            context.cgContext.translateBy(x: 0, y: size.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: context.cgContext)
            context.cgContext.restoreGState()
        }

        return image.jpegData(compressionQuality: 0.85)
    }

    private func stripHTML(from html: String) -> String {
        var result = html

        // Remove script and style tags with content
        let scriptPattern = #"<script[^>]*>[\s\S]*?</script>"#
        let stylePattern = #"<style[^>]*>[\s\S]*?</style>"#

        if let scriptRegex = try? NSRegularExpression(pattern: scriptPattern, options: .caseInsensitive) {
            result = scriptRegex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }

        if let styleRegex = try? NSRegularExpression(pattern: stylePattern, options: .caseInsensitive) {
            result = styleRegex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }

        // Replace block elements with newlines
        let blockElements = ["</p>", "</div>", "</h1>", "</h2>", "</h3>", "</h4>", "</h5>", "</h6>", "<br>", "<br/>", "<br />"]
        for element in blockElements {
            result = result.replacingOccurrences(of: element, with: "\n", options: .caseInsensitive)
        }

        // Remove all remaining HTML tags
        let tagPattern = #"<[^>]+>"#
        if let tagRegex = try? NSRegularExpression(pattern: tagPattern) {
            result = tagRegex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }

        // Decode HTML entities
        result = result
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
        result = decodeNumericHTMLEntities(result)

        // Clean up whitespace
        let whitespacePattern = #"\s+"#
        if let whitespaceRegex = try? NSRegularExpression(pattern: whitespacePattern) {
            result = whitespaceRegex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: " "
            )
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func decodeNumericHTMLEntities(_ text: String) -> String {
        let pattern = #"&#(x?[0-9A-Fa-f]+);"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }

        var result = text
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed()

        for match in matches {
            guard let range = Range(match.range(at: 1), in: text),
                  let fullRange = Range(match.range(at: 0), in: text) else {
                continue
            }
            let value = String(text[range])
            let scalar: UnicodeScalar?
            if value.lowercased().hasPrefix("x") {
                scalar = UnicodeScalar(Int(value.dropFirst(), radix: 16) ?? 0)
            } else {
                scalar = UnicodeScalar(Int(value, radix: 10) ?? 0)
            }
            if let scalar = scalar {
                result.replaceSubrange(fullRange, with: String(scalar))
            }
        }

        return result
    }
}

// MARK: - Errors

enum BookProcessorError: LocalizedError {
    case unsupportedFormat(String)
    case failedToLoad
    case noTextContent
    case extractionFailed
    case invalidPath

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let format):
            return "Unsupported file format: .\(format). Please use PDF or EPUB files."
        case .failedToLoad:
            return "Failed to load the book file."
        case .noTextContent:
            return "Could not extract text content from the book."
        case .extractionFailed:
            return "Failed to extract EPUB contents. Ensure ZIPFoundation is linked in the project."
        case .invalidPath:
            return "EPUB contains an invalid file path."
        }
    }
}
