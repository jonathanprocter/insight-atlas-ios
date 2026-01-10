import Foundation
import os.log

/// A comprehensive PDF text fixer that repairs broken ligatures, encoding issues,
/// and common OCR artifacts from PDF text extraction.
///
/// Features:
/// - Configurable options via OptionSet
/// - Chunked processing for large documents
/// - Input validation with size limits and timeout
/// - Pattern frequency logging and analytics
/// - Diff/preview mode for reviewing changes
/// - French ligature support (oe, ae)
/// - External JSON configuration file support
/// - Thread-safe regex caching
public final class PDFTextFixer: @unchecked Sendable {

    // MARK: - Configuration

    public struct Options: OptionSet, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let fixLigatures = Options(rawValue: 1 << 0)
        public static let normalizeTypography = Options(rawValue: 1 << 1)
        public static let removeMarkdownArtifacts = Options(rawValue: 1 << 2)
        public static let cleanupSpacing = Options(rawValue: 1 << 3)
        public static let fixPageBreakArtifacts = Options(rawValue: 1 << 4)
        public static let fixFrenchLigatures = Options(rawValue: 1 << 5)

        public static let all: Options = [
            .fixLigatures,
            .normalizeTypography,
            .removeMarkdownArtifacts,
            .cleanupSpacing,
            .fixPageBreakArtifacts,
            .fixFrenchLigatures
        ]
        public static let standard: Options = [.fixLigatures, .cleanupSpacing]
    }

    public enum TypographyMode: Sendable {
        case preserve      // Keep em dashes, curly quotes
        case normalize     // Convert to ASCII equivalents
    }

    /// Processing limits for safety
    public struct ProcessingLimits: Sendable {
        public var maxInputLength: Int
        public var timeoutSeconds: TimeInterval
        public var chunkSize: Int

        public static let `default` = ProcessingLimits(
            maxInputLength: 10_000_000,  // 10MB
            timeoutSeconds: 60.0,
            chunkSize: 100_000  // 100KB chunks
        )

        public static let strict = ProcessingLimits(
            maxInputLength: 1_000_000,   // 1MB
            timeoutSeconds: 30.0,
            chunkSize: 50_000   // 50KB chunks
        )

        public init(maxInputLength: Int, timeoutSeconds: TimeInterval, chunkSize: Int) {
            self.maxInputLength = maxInputLength
            self.timeoutSeconds = timeoutSeconds
            self.chunkSize = chunkSize
        }
    }

    /// Result of a fix operation with analytics
    public struct FixResult: Sendable {
        public let fixedText: String
        public let originalText: String
        public let changeCount: Int
        public let patternHits: [String: Int]
        public let processingTime: TimeInterval
        public let wasChunked: Bool
        public let chunkCount: Int

        /// Get a summary of changes made
        public var summary: String {
            if changeCount == 0 {
                return "No changes made"
            }
            var parts: [String] = []
            parts.append("\(changeCount) total fixes")
            if !patternHits.isEmpty {
                let topPatterns = patternHits.sorted { $0.value > $1.value }.prefix(5)
                let patternSummary = topPatterns.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
                parts.append("Top patterns: \(patternSummary)")
            }
            parts.append(String(format: "Processing time: %.2fms", processingTime * 1000))
            if wasChunked {
                parts.append("Processed in \(chunkCount) chunks")
            }
            return parts.joined(separator: " | ")
        }
    }

    /// Preview of changes (for diff mode)
    public struct ChangePreview: Sendable {
        public struct Change: Sendable {
            public let original: String
            public let replacement: String
            public let category: String
            public let count: Int
        }

        public let changes: [Change]
        public let totalChangeCount: Int

        public var isEmpty: Bool { changes.isEmpty }
    }

    public enum FixerError: Error, LocalizedError {
        case inputTooLarge(size: Int, limit: Int)
        case timeout(elapsed: TimeInterval, limit: TimeInterval)
        case invalidInput(reason: String)

        public var errorDescription: String? {
            switch self {
            case .inputTooLarge(let size, let limit):
                return "Input text too large: \(size) bytes exceeds limit of \(limit) bytes"
            case .timeout(let elapsed, let limit):
                return String(format: "Processing timeout: %.1fs exceeded limit of %.1fs", elapsed, limit)
            case .invalidInput(let reason):
                return "Invalid input: \(reason)"
            }
        }
    }

    // MARK: - Properties

    public var options: Options
    public var typographyMode: TypographyMode
    public var limits: ProcessingLimits

    /// Custom patterns that can be added at runtime for domain-specific fixes
    public var customPatterns: [(pattern: String, replacement: String)] = []

    /// Enable logging of pattern hits (for analytics)
    public var enableLogging: Bool = false

    /// Logger for pattern analytics (lazy to avoid initialization issues)
    private static var logger: Logger {
        Logger(subsystem: "com.insightatlas", category: "PDFTextFixer")
    }

    /// Terms that should never be modified (Wi-Fi, Hi-Fi, etc.)
    private var preserveTerms: [String] = [
        "Wi-Fi", "wi-fi", "WiFi", "wifi",
        "Hi-Fi", "hi-fi", "HiFi", "hifi",
        "Sci-Fi", "sci-fi", "SciFi", "scifi",
        "Lo-Fi", "lo-fi", "LoFi", "lofi",
        "FIFO", "fifo",
        "LIFO", "lifo",
    ]

    // MARK: - Pattern Storage

    /// All pattern categories loaded from configuration or defaults
    private var patternCategories: [PatternCategory] = []

    private struct PatternCategory {
        let name: String
        let patterns: [(String, String)]
    }

    // MARK: - Cached Regex Patterns with LRU Eviction

    private static let maxCachedPatterns = 500  // Limit cache size to prevent memory growth
    private static var compiledPatterns: [String: NSRegularExpression] = [:]
    private static var patternAccessOrder: [String] = []  // Track access order for LRU eviction
    private static var patternLock: NSLock = {
        let lock = NSLock()
        lock.name = "com.insightatlas.PDFTextFixer.patternLock"
        return lock
    }()

    // MARK: - Pattern Hit Tracking

    private var patternHitCounts: [String: Int] = [:]
    private let hitCountLock = NSLock()

    // MARK: - Initialization

    public init(
        options: Options = .all,
        typographyMode: TypographyMode = .normalize,
        limits: ProcessingLimits = .default
    ) {
        self.options = options
        self.typographyMode = typographyMode
        self.limits = limits
        loadDefaultPatterns()
        // Note: loadPatternsFromConfiguration() is called lazily on first use
    }

    // MARK: - Main Entry Point

    /// Fix all PDF text extraction issues based on configured options
    /// Returns just the fixed text (simple API)
    public func fix(_ text: String) -> String {
        do {
            let result = try fixWithResult(text)
            return result.fixedText
        } catch {
            if enableLogging {
                Self.logger.error("PDFTextFixer error: \(error.localizedDescription)")
            }
            return text  // Return original on error
        }
    }

    /// Fix with full result including analytics
    public func fixWithResult(_ text: String) throws -> FixResult {
        // Lazy load configuration on first use
        loadPatternsFromConfiguration()

        let startTime = Date()

        // Input validation
        guard !text.isEmpty else {
            return FixResult(
                fixedText: "",
                originalText: "",
                changeCount: 0,
                patternHits: [:],
                processingTime: 0,
                wasChunked: false,
                chunkCount: 0
            )
        }

        let inputSize = text.utf8.count
        guard inputSize <= limits.maxInputLength else {
            throw FixerError.inputTooLarge(size: inputSize, limit: limits.maxInputLength)
        }

        // Reset hit counts
        hitCountLock.lock()
        patternHitCounts = [:]
        hitCountLock.unlock()

        // Determine if chunked processing is needed
        let shouldChunk = inputSize > limits.chunkSize
        var result: String
        var chunkCount = 1

        if shouldChunk {
            (result, chunkCount) = try processInChunks(text, startTime: startTime)
        } else {
            result = try processText(text, startTime: startTime)
        }

        let processingTime = Date().timeIntervalSince(startTime)

        // Get final hit counts
        hitCountLock.lock()
        let hits = patternHitCounts
        hitCountLock.unlock()

        let changeCount = hits.values.reduce(0, +)

        // Log if enabled
        if enableLogging && changeCount > 0 {
            Self.logger.info("PDFTextFixer: \(changeCount) fixes applied in \(String(format: "%.2f", processingTime * 1000))ms")
            for (pattern, count) in hits.sorted(by: { $0.value > $1.value }).prefix(10) {
                Self.logger.debug("  Pattern '\(pattern)': \(count) hits")
            }
        }

        return FixResult(
            fixedText: result,
            originalText: text,
            changeCount: changeCount,
            patternHits: hits,
            processingTime: processingTime,
            wasChunked: shouldChunk,
            chunkCount: chunkCount
        )
    }

    /// Preview changes without applying them (diff mode)
    public func previewChanges(_ text: String) -> ChangePreview {
        var changes: [ChangePreview.Change] = []
        var categoryCounts: [String: [String: Int]] = [:]

        // Check each pattern category
        for category in patternCategories {
            for (pattern, replacement) in category.patterns {
                let count = countOccurrences(of: pattern, in: text)
                if count > 0 {
                    if categoryCounts[category.name] == nil {
                        categoryCounts[category.name] = [:]
                    }
                    categoryCounts[category.name]!["\(pattern) -> \(replacement)"] = count
                }
            }
        }

        // Convert to Change objects
        for (categoryName, patterns) in categoryCounts {
            for (patternDesc, count) in patterns {
                let parts = patternDesc.components(separatedBy: " -> ")
                if parts.count == 2 {
                    changes.append(ChangePreview.Change(
                        original: parts[0],
                        replacement: parts[1],
                        category: categoryName,
                        count: count
                    ))
                }
            }
        }

        // Sort by count descending
        changes.sort { $0.count > $1.count }

        return ChangePreview(
            changes: changes,
            totalChangeCount: changes.reduce(0) { $0 + $1.count }
        )
    }

    // MARK: - Chunked Processing

    private func processInChunks(_ text: String, startTime: Date) throws -> (String, Int) {
        var result = ""
        var offset = text.startIndex
        var chunkCount = 0

        while offset < text.endIndex {
            // Check timeout
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > limits.timeoutSeconds {
                throw FixerError.timeout(elapsed: elapsed, limit: limits.timeoutSeconds)
            }

            // Calculate chunk end (try to break at paragraph boundaries)
            var chunkEnd = text.index(offset, offsetBy: limits.chunkSize, limitedBy: text.endIndex) ?? text.endIndex

            // If not at end, try to find a good break point
            if chunkEnd < text.endIndex {
                // Look for paragraph break
                if let paragraphBreak = text[offset..<chunkEnd].range(of: "\n\n", options: .backwards) {
                    chunkEnd = paragraphBreak.upperBound
                } else if let lineBreak = text[offset..<chunkEnd].range(of: "\n", options: .backwards) {
                    chunkEnd = lineBreak.upperBound
                }
            }

            let chunk = String(text[offset..<chunkEnd])
            let processedChunk = try processText(chunk, startTime: startTime)
            result += processedChunk

            offset = chunkEnd
            chunkCount += 1
        }

        return (result, chunkCount)
    }

    private func processText(_ text: String, startTime: Date) throws -> String {
        var result = text

        // Check timeout periodically
        func checkTimeout() throws {
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > limits.timeoutSeconds {
                throw FixerError.timeout(elapsed: elapsed, limit: limits.timeoutSeconds)
            }
        }

        // Order matters! Process in this sequence:
        if options.contains(.normalizeTypography) && typographyMode == .normalize {
            result = normalizeTypography(result)
            try checkTimeout()
        }

        if options.contains(.fixLigatures) {
            result = fixLigatures(result)
            try checkTimeout()
        }

        if options.contains(.fixFrenchLigatures) {
            result = fixFrenchLigatures(result)
            try checkTimeout()
        }

        if options.contains(.fixPageBreakArtifacts) {
            result = fixPageBreakArtifacts(result)
            try checkTimeout()
        }

        if options.contains(.removeMarkdownArtifacts) {
            result = removeMarkdownArtifacts(result)
            try checkTimeout()
        }

        if options.contains(.cleanupSpacing) {
            result = cleanupSpacing(result)
        }

        // Apply any custom patterns
        if !customPatterns.isEmpty {
            result = applyCustomPatterns(result)
        }

        return result
    }

    // MARK: - Pattern Loading

    private func loadDefaultPatterns() {
        patternCategories = [
            PatternCategory(name: "FFI", patterns: ffiPatterns),
            PatternCategory(name: "FFL", patterns: fflPatterns),
            PatternCategory(name: "FF", patterns: ffPatterns),
            PatternCategory(name: "FL", patterns: flPatterns),
            PatternCategory(name: "FI", patterns: fiPatterns),
            PatternCategory(name: "FT", patterns: ftPatterns),
            PatternCategory(name: "GG", patterns: ggPatterns),
            PatternCategory(name: "SingleF", patterns: singleFPatterns),
            PatternCategory(name: "TH", patterns: thPatterns),
            PatternCategory(name: "QU", patterns: quPatterns),
        ]
    }

    /// Thread-safe flag to track if configuration has been loaded
    private var configurationLoaded = false
    private let configurationLock = NSLock()

    private func loadPatternsFromConfiguration() {
        // Thread-safe check-and-set using a lock
        configurationLock.lock()
        defer { configurationLock.unlock() }

        // Double-check after acquiring lock to prevent race condition
        guard !configurationLoaded else { return }
        configurationLoaded = true

        // Try to load from bundled JSON file
        guard let url = Bundle.main.url(forResource: "PDFTextFixerPatterns", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return
        }

        do {
            let config = try JSONDecoder().decode(PatternConfiguration.self, from: data)

            // Add custom patterns from config - check for duplicates
            if let customPatterns = config.customPatterns {
                let existingPatterns = Set(self.customPatterns.map { "\($0.0) -> \($0.1)" })
                for pattern in customPatterns {
                    let key = "\(pattern.find) -> \(pattern.replace)"
                    if !existingPatterns.contains(key) {
                        self.customPatterns.append((pattern.find, pattern.replace))
                    }
                }
            }

            // Add preserve terms from config - check for duplicates
            if let additionalPreserveTerms = config.preserveTerms {
                let existingTerms = Set(self.preserveTerms)
                for term in additionalPreserveTerms {
                    if !existingTerms.contains(term) {
                        self.preserveTerms.append(term)
                    }
                }
            }

            // Disable specific patterns if configured
            if let disabled = config.disabledPatterns {
                for categoryIndex in patternCategories.indices {
                    patternCategories[categoryIndex] = PatternCategory(
                        name: patternCategories[categoryIndex].name,
                        patterns: patternCategories[categoryIndex].patterns.filter { pattern in
                            !disabled.contains("\(pattern.0) -> \(pattern.1)")
                        }
                    )
                }
            }

            if enableLogging {
                Self.logger.info("Loaded pattern configuration from PDFTextFixerPatterns.json")
            }
        } catch {
            if enableLogging {
                Self.logger.warning("Failed to parse PDFTextFixerPatterns.json: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Configuration File Structure

    private struct PatternConfiguration: Codable {
        let customPatterns: [CustomPattern]?
        let preserveTerms: [String]?
        let disabledPatterns: [String]?
    }

    private struct CustomPattern: Codable {
        let find: String
        let replace: String
        let category: String?
    }

    // MARK: - Typography Normalization

    /// Character mapping table for single-pass normalization
    /// Using a static dictionary for O(1) lookups per character
    private static let typographyReplacements: [Character: String] = [
        // Dashes
        "\u{2014}": "-",  // em dash —
        "\u{2013}": "-",  // en dash –
        "\u{2010}": "-",  // hyphen ‐
        "\u{2011}": "-",  // non-breaking hyphen ‑
        "\u{2212}": "-",  // minus sign −
        // Double quotes
        "\u{201C}": "\"", // " left double curly
        "\u{201D}": "\"", // " right double curly
        "\u{201E}": "\"", // „ low double curly
        "\u{00AB}": "\"", // « guillemet left
        "\u{00BB}": "\"", // » guillemet right
        // Single quotes
        "\u{2018}": "'",  // ' left single curly
        "\u{2019}": "'",  // ' right single curly
        "\u{201A}": "'",  // ‚ low single curly
        "\u{2039}": "'",  // ‹ single guillemet left
        "\u{203A}": "'",  // › single guillemet right
        "\u{0060}": "'",  // ` backtick to apostrophe
        "\u{00B4}": "'",  // ´ acute accent
        // Ellipsis - handled separately
        // Spaces
        "\u{00A0}": " ",  // non-breaking space
        "\u{2007}": " ",  // figure space
        "\u{2008}": " ",  // punctuation space
        "\u{2009}": " ",  // thin space
        "\u{200A}": " ",  // hair space
        "\u{200B}": "",   // zero-width space (remove)
        "\u{FEFF}": "",   // BOM/zero-width no-break
        // Encoding artifacts
        "\u{00AD}": "",   // soft hyphen (remove)
        "￾": "",          // replacement character
        "\u{FFFD}": "",   // replacement character
        // Other
        "•": "-",  // bullet to hyphen
        "·": "-",  // middle dot
        "×": "x",  // multiplication sign
        "÷": "/",  // division sign
    ]

    /// Optimized single-pass typography normalization
    /// O(n) instead of O(n*m) where m is the number of replacement patterns
    func normalizeTypography(_ text: String) -> String {
        // Fast path: check if any normalization is needed
        var needsNormalization = false
        for char in text {
            if Self.typographyReplacements[char] != nil || char == "…" {
                needsNormalization = true
                break
            }
        }

        guard needsNormalization else { return text }

        // Single pass through the string
        var result = ""
        result.reserveCapacity(text.count)

        for char in text {
            if let replacement = Self.typographyReplacements[char] {
                result += replacement
            } else if char == "…" {
                // Ellipsis handled specially (one char to three)
                result += "..."
            } else {
                result.append(char)
            }
        }

        return result
    }

    // MARK: - Symbol-Based Ligature Fixes

    func fixSymbolLigatures(_ text: String) -> String {
        var result = text
        result = applyPatternWithTracking("#", "fi", to: result, category: "Symbol")
        result = applyPatternWithTracking("$", "fi", to: result, category: "Symbol")
        result = applyPatternWithTracking("%", "fl", to: result, category: "Symbol")
        return result
    }

    // MARK: - Main Ligature Fix Entry Point

    func fixLigatures(_ text: String) -> String {
        var result = text

        // Step 0: Preserve known terms that should NOT be modified
        var preserved: [String: String] = [:]
        for (i, term) in preserveTerms.enumerated() {
            let placeholder = "{{PRESERVE_\(i)}}"
            if result.contains(term) {
                preserved[placeholder] = term
                result = result.replacingOccurrences(of: term, with: placeholder)
            }
        }

        // Step 1: Symbol replacements
        result = fixSymbolLigatures(result)

        // Step 2: Space-broken ligatures (ORDER MATTERS - longer sequences first!)
        for category in patternCategories {
            result = applyPatterns(category.patterns, to: result, categoryName: category.name)
        }

        // Step 3: Stray ligature characters at line endings
        result = fixStrayLigatureChars(result)

        // Step 4: Restore preserved terms
        for (placeholder, original) in preserved {
            result = result.replacingOccurrences(of: placeholder, with: original)
        }

        return result
    }

    // MARK: - French Ligature Support

    func fixFrenchLigatures(_ text: String) -> String {
        var result = text

        // Fix broken œ ligature
        let oePatterns: [(String, String)] = [
            ("c ur", "cœur"),
            ("c urs", "cœurs"),
            (" uvre", "œuvre"),
            (" uvres", "œuvres"),
            ("b uf", "bœuf"),
            ("b ufs", "bœufs"),
            ("s ur", "sœur"),
            ("s urs", "sœurs"),
            ("n ud", "nœud"),
            ("n uds", "nœuds"),
            ("v u", "vœu"),
            ("v ux", "vœux"),
            ("man uvre", "manœuvre"),
            ("man uvres", "manœuvres"),
            ("hors-d' uvre", "hors-d'œuvre"),
        ]

        result = applyPatterns(oePatterns, to: result, categoryName: "French-OE")

        // Fix broken æ ligature
        let aePatterns: [(String, String)] = [
            (" sthétique", "æsthétique"),
            (" sthetique", "æsthetique"),
            ("encyclop die", "encyclopædie"),
            ("pr raphael", "præraphael"),
        ]

        result = applyPatterns(aePatterns, to: result, categoryName: "French-AE")

        return result
    }

    // MARK: - Page Break Artifacts

    func fixPageBreakArtifacts(_ text: String) -> String {
        var result = text

        // Form feed followed by orphaned word continuation
        let pageBreakPatterns: [(String, String)] = [
            ("\u{000C}\\s*is\\s+", "\u{000C}This "),
            ("\u{000C}\\s*at\\s+", "\u{000C}That "),
            ("\u{000C}\\s*e\\s+", "\u{000C}The "),
            ("\u{000C}\\s*ere\\s+", "\u{000C}There "),
            ("\u{000C}\\s*ese\\s+", "\u{000C}These "),
            ("\u{000C}\\s*ey\\s+", "\u{000C}They "),
            ("\u{000C}\\s*en\\s+", "\u{000C}Then "),
            ("\u{000C}\\s*us\\s+", "\u{000C}Thus "),
        ]

        for (pattern, replacement) in pageBreakPatterns {
            if let regex = getOrCreateRegex(pattern) {
                let originalCount = result.count
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: replacement
                )
                if result.count != originalCount {
                    recordPatternHit(pattern, category: "PageBreak")
                }
            }
        }

        return result
    }

    // MARK: - Markdown Artifact Removal

    func removeMarkdownArtifacts(_ text: String) -> String {
        var result = text

        // Bold markers: **text** → text
        if let boldRegex = getOrCreateRegex("\\*\\*([^*]+)\\*\\*") {
            result = boldRegex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1"
            )
        }

        // Italic markers: *text* → text (but not **)
        if let italicRegex = getOrCreateRegex("(?<!\\*)\\*([^*]+)\\*(?!\\*)") {
            result = italicRegex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1"
            )
        }

        // Underline markers: __text__ → text
        if let underlineRegex = getOrCreateRegex("__([^_]+)__") {
            result = underlineRegex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1"
            )
        }

        // Strikethrough: ~~text~~ → text
        if let strikeRegex = getOrCreateRegex("~~([^~]+)~~") {
            result = strikeRegex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1"
            )
        }

        // Orphaned asterisks at line start
        if let orphanRegex = getOrCreateRegex("^\\s*\\*\\s+([A-Z])") {
            result = orphanRegex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1"
            )
        }

        return result
    }

    // MARK: - Spacing Cleanup

    func cleanupSpacing(_ text: String) -> String {
        var result = text

        // Multiple spaces → single space
        if let multiSpaceRegex = getOrCreateRegex(" {2,}") {
            result = multiSpaceRegex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: " "
            )
        }

        // Space before punctuation
        result = result.replacingOccurrences(of: " .", with: ".")
        result = result.replacingOccurrences(of: " ,", with: ",")
        result = result.replacingOccurrences(of: " ;", with: ";")
        result = result.replacingOccurrences(of: " :", with: ":")
        result = result.replacingOccurrences(of: " !", with: "!")
        result = result.replacingOccurrences(of: " ?", with: "?")
        result = result.replacingOccurrences(of: " )", with: ")")
        result = result.replacingOccurrences(of: "( ", with: "(")

        // Multiple newlines → double newline (paragraph break)
        if let multiNewlineRegex = getOrCreateRegex("\\n{3,}") {
            result = multiNewlineRegex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "\n\n"
            )
        }

        // Trim whitespace from line ends
        if let trailingSpaceRegex = try? NSRegularExpression(pattern: " +$", options: .anchorsMatchLines) {
            result = trailingSpaceRegex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }

        return result
    }

    // MARK: - Stray Ligature Characters

    func fixStrayLigatureChars(_ text: String) -> String {
        var result = text

        let strayPatterns = ["ffi", "ffl", "ff", "fi", "fl", "ft", "Th", "th", "gg", "q", "t", "f"]

        for fragment in strayPatterns {
            // Match fragment alone on a line (with optional whitespace)
            if let regex = getOrCreateRegex("^\\s*\(NSRegularExpression.escapedPattern(for: fragment))\\s*$") {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: ""
                )
            }
        }

        // Also handle fragments at end of lines followed by newline
        for fragment in strayPatterns {
            if let regex = getOrCreateRegex("(?<=\\s)\(NSRegularExpression.escapedPattern(for: fragment))\\s*\\n") {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: "\n"
                )
            }
        }

        return result
    }

    // MARK: - TH Patterns

    func fixTHPatterns(_ text: String) -> String {
        var result = text

        let thPatterns: [(String, String)] = [
            ("Th is", "This"),
            ("Th at", "That"),
            ("Th e", "The"),
            ("Th en", "Then"),
            ("Th ere", "There"),
            ("Th ey", "They"),
            ("Th us", "Thus"),
            ("Th rough", "Through"),
            ("Th ink", "Think"),
            ("Th ought", "Thought"),
            ("Th erapy", "Therapy"),
            ("Th erapist", "Therapist"),
            ("Th eory", "Theory"),
        ]

        result = applyPatterns(thPatterns, to: result, categoryName: "TH")

        // Page break patterns
        let pageBreakPatterns: [(String, String)] = [
            ("\u{000C} is ", "\u{000C}This "),
            ("\u{000C} at ", "\u{000C}That "),
            ("\u{000C} e ", "\u{000C}The "),
            ("\u{000C} ere ", "\u{000C}There "),
            ("\u{000C} ese ", "\u{000C}These "),
            ("\u{000C} ey ", "\u{000C}They "),
            ("\u{000C} en ", "\u{000C}Then "),
            ("\u{000C} us ", "\u{000C}Thus "),
        ]

        result = applyPatterns(pageBreakPatterns, to: result, categoryName: "TH-PageBreak")

        // Context-sensitive patterns after punctuation
        let contextPatterns: [(String, String)] = [
            (". is is", ". This is"),
            (". is was", ". This was"),
            (". is can", ". This can"),
            (". is will", ". This will"),
            (". is means", ". This means"),
            (". is allows", ". This allows"),
            (". is creates", ". This creates"),
            (". is requires", ". This requires"),
            (". e ", ". The "),
            (". ere is", ". There is"),
            (". ere are", ". There are"),
            (". ey ", ". They "),
        ]

        result = applyPatterns(contextPatterns, to: result, categoryName: "TH-Context")

        return result
    }

    // MARK: - Helper Methods

    private func applyPatterns(_ patterns: [(String, String)], to text: String, categoryName: String) -> String {
        var result = text
        for (pattern, replacement) in patterns {
            result = applyPatternWithTracking(pattern, replacement, to: result, category: categoryName)
        }
        return result
    }

    private func applyPatternWithTracking(_ pattern: String, _ replacement: String, to text: String, category: String) -> String {
        let regexPattern = regexPattern(for: pattern)
        guard let regex = getOrCreateRegex(regexPattern) else { return text }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, options: [], range: range)
        if !matches.isEmpty {
            recordPatternHit("\(pattern)->\(replacement)", category: category, count: matches.count)
        }

        let template = NSRegularExpression.escapedTemplate(for: replacement)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: template)
    }

    private func applyCustomPatterns(_ text: String) -> String {
        var result = text
        for (pattern, replacement) in customPatterns {
            result = applyPatternWithTracking(pattern, replacement, to: result, category: "Custom")
        }
        return result
    }

    private func countOccurrences(of pattern: String, in text: String) -> Int {
        let regexPattern = regexPattern(for: pattern)
        guard let regex = getOrCreateRegex(regexPattern) else { return 0 }
        let range = NSRange(text.startIndex..., in: text)
        return regex.numberOfMatches(in: text, options: [], range: range)
    }

    private func regexPattern(for pattern: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: pattern)
        let trimmed = pattern.drop(while: { $0 == " " })
        var regex = escaped
        if let first = trimmed.first, first.isLetter {
            regex = "(?<![A-Za-z])" + regex
        }
        if let last = pattern.last, last.isLetter {
            regex += "(?![A-Za-z])"
        }
        return regex
    }

    private func recordPatternHit(_ pattern: String, category: String, count: Int = 1) {
        hitCountLock.lock()
        let key = "[\(category)] \(pattern)"
        patternHitCounts[key, default: 0] += count
        hitCountLock.unlock()
    }

    private func getOrCreateRegex(_ pattern: String) -> NSRegularExpression? {
        Self.patternLock.lock()
        defer { Self.patternLock.unlock() }

        if let cached = Self.compiledPatterns[pattern] {
            // Update LRU access order - move to end (most recently used)
            if let index = Self.patternAccessOrder.firstIndex(of: pattern) {
                Self.patternAccessOrder.remove(at: index)
            }
            Self.patternAccessOrder.append(pattern)
            return cached
        }

        // Create new regex
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }

        // Evict oldest patterns if cache is full (LRU eviction)
        while Self.compiledPatterns.count >= Self.maxCachedPatterns && !Self.patternAccessOrder.isEmpty {
            let oldestPattern = Self.patternAccessOrder.removeFirst()
            Self.compiledPatterns.removeValue(forKey: oldestPattern)
        }

        // Add new pattern to cache
        Self.compiledPatterns[pattern] = regex
        Self.patternAccessOrder.append(pattern)

        return regex
    }

    // MARK: - Default Pattern Definitions

    private var ffiPatterns: [(String, String)] {
        [
            ("di  cult", "difficult"),
            ("di cult", "difficult"),
            ("di  culty", "difficulty"),
            ("di  culties", "difficulties"),
            ("e  cient", "efficient"),
            ("e  ciency", "efficiency"),
            ("e  ciently", "efficiently"),
            ("ine  cient", "inefficient"),
            ("su  cient", "sufficient"),
            ("su  ciency", "sufficiency"),
            ("su  ciently", "sufficiently"),
            ("insu  cient", "insufficient"),
            ("o  cial", "official"),
            ("o  cially", "officially"),
            ("uno  cial", "unofficial"),
            ("o  ce", "office"),
            ("o  ces", "offices"),
            ("o  cer", "officer"),
            ("a  liate", "affiliate"),
            ("a  liated", "affiliated"),
            ("a  liation", "affiliation"),
            ("a  rm", "affirm"),
            ("a  rms", "affirms"),
            ("a  rmed", "affirmed"),
            ("a  rming", "affirming"),
            ("a  rmation", "affirmation"),
            ("a  rmations", "affirmations"),
            ("a  rmative", "affirmative"),
            ("co  n", "coffin"),
            ("tra  c", "traffic"),
            ("tra  cking", "trafficking"),
            ("gru  ", "gruff"),
            ("sti  ", "stiff"),
            ("sti  ness", "stiffness"),
            ("sti  en", "stiffen"),
            ("sti  ened", "stiffened"),
            ("sni  ", "sniff"),
            ("sni  ed", "sniffed"),
            ("sni  ing", "sniffing"),
            ("whi  ", "whiff"),
        ]
    }

    private var fflPatterns: [(String, String)] {
        [
            ("ba  e", "baffle"),
            ("ba  ed", "baffled"),
            ("ba  ing", "baffling"),
            ("mu  e", "muffle"),
            ("mu  ed", "muffled"),
            ("mu  er", "muffler"),
            ("mu  ing", "muffling"),
            ("ra  e", "raffle"),
            ("ru  e", "ruffle"),
            ("ru  ed", "ruffled"),
            ("scu  e", "scuffle"),
            ("shu  e", "shuffle"),
            ("shu  ed", "shuffled"),
            ("shu  ing", "shuffling"),
            ("sni  e", "sniffle"),
            ("sni  ed", "sniffled"),
            ("sni  ing", "sniffling"),
            ("wa  e", "waffle"),
            ("wa  es", "waffles"),
        ]
    }

    private var ffPatterns: [(String, String)] {
        [
            ("e ect", "effect"),
            ("e ects", "effects"),
            ("e ective", "effective"),
            ("e ectively", "effectively"),
            ("e ectiveness", "effectiveness"),
            ("ine ective", "ineffective"),
            ("a ect", "affect"),
            ("a ects", "affects"),
            ("a ected", "affected"),
            ("a ecting", "affecting"),
            ("a ection", "affection"),
            ("a ectionate", "affectionate"),
            ("o er", "offer"),
            ("o ers", "offers"),
            ("o ered", "offered"),
            ("o ering", "offering"),
            ("o erings", "offerings"),
            ("su er", "suffer"),
            ("su ers", "suffers"),
            ("su ered", "suffered"),
            ("su ering", "suffering"),
            ("su erings", "sufferings"),
            ("di er", "differ"),
            ("di ers", "differs"),
            ("di ered", "differed"),
            ("di ering", "differing"),
            ("di erent", "different"),
            ("di erently", "differently"),
            ("di erence", "difference"),
            ("di erences", "differences"),
            ("di erential", "differential"),
            ("di erentially", "differentially"),
            ("di erentiate", "differentiate"),
            ("di erentiated", "differentiated"),
            ("di erentiation", "differentiation"),
            ("undi erentiated", "undifferentiated"),
            ("indi erent", "indifferent"),
            ("indi erence", "indifference"),
            ("e ort", "effort"),
            ("e orts", "efforts"),
            ("e ortful", "effortful"),
            ("e ortless", "effortless"),
            ("e ortlessly", "effortlessly"),
            ("sta ", "staff"),
            ("sta s", "staffs"),
            ("sta ed", "staffed"),
            ("sta ing", "staffing"),
            ("stu ", "stuff"),
            ("stu s", "stuffs"),
            ("stu ed", "stuffed"),
            ("stu ing", "stuffing"),
            ("o spring", "offspring"),
            ("o set", "offset"),
            ("o sets", "offsets"),
            ("o shore", "offshore"),
            ("o site", "offsite"),
            ("bu ", "buff"),
            ("bu er", "buffer"),
            ("bu ers", "buffers"),
            ("blu ", "bluff"),
            ("blu ing", "bluffing"),
            ("cu ", "cuff"),
            ("cu s", "cuffs"),
            ("cu ed", "cuffed"),
            ("hu ", "huff"),
            ("pu ", "puff"),
            ("pu y", "puffy"),
            ("pu ed", "puffed"),
            ("cli ", "cliff"),
            ("cli s", "cliffs"),
            ("sti ", "stiff"),
            ("sti ly", "stiffly"),
            ("sti ness", "stiffness"),
            ("sca old", "scaffold"),
            ("sca olding", "scaffolding"),
            ("a ord", "afford"),
            ("a ords", "affords"),
            ("a orded", "afforded"),
            ("a ordable", "affordable"),
            ("a ordance", "affordance"),
            ("a ordances", "affordances"),
            ("co ee", "coffee"),
            ("to ee", "toffee"),
            ("da odil", "daffodil"),
            ("da odils", "daffodils"),
        ]
    }

    private var flPatterns: [(String, String)] {
        [
            ("Re ection", "Reflection"),
            ("re ect", "reflect"),
            ("re ects", "reflects"),
            ("re ected", "reflected"),
            ("re ecting", "reflecting"),
            ("re ection", "reflection"),
            ("re ections", "reflections"),
            ("re ective", "reflective"),
            ("re exive", "reflexive"),
            ("re exivity", "reflexivity"),
            ("re ex", "reflex"),
            ("in uence", "influence"),
            ("in uences", "influences"),
            ("in uenced", "influenced"),
            ("in uencing", "influencing"),
            ("in uential", "influential"),
            ("in ux", "influx"),
            ("con ict", "conflict"),
            ("con icts", "conflicts"),
            ("con icted", "conflicted"),
            ("con icting", "conflicting"),
            ("in exible", "inflexible"),
            (" exible", "flexible"),
            (" exibility", "flexibility"),
            (" exibly", "flexibly"),
            (" ex", "flex"),
            (" ow", "flow"),
            (" ows", "flows"),
            (" owed", "flowed"),
            (" owing", "flowing"),
            ("over ow", "overflow"),
            ("work ow", "workflow"),
            ("out ow", "outflow"),
            ("in ow", "inflow"),
            (" oor", "floor"),
            (" oors", "floors"),
            (" ood", "flood"),
            (" oods", "floods"),
            (" ooded", "flooded"),
            (" ooding", "flooding"),
            (" y", "fly"),
            (" ying", "flying"),
            (" ight", "flight"),
            (" ights", "flights"),
            (" atten", "flatten"),
            (" attened", "flattened"),
            (" aw", "flaw"),
            (" aws", "flaws"),
            (" awed", "flawed"),
            (" awless", "flawless"),
            (" ame", "flame"),
            (" ames", "flames"),
            (" aming", "flaming"),
            (" ash", "flash"),
            (" ashes", "flashes"),
            (" ashed", "flashed"),
            (" ashing", "flashing"),
            (" esh", "flesh"),
            (" eshy", "fleshy"),
            (" inch", "flinch"),
            (" inched", "flinched"),
            (" ourish", "flourish"),
            (" ourishes", "flourishes"),
            (" ourishing", "flourishing"),
            (" utter", "flutter"),
            (" utters", "flutters"),
            (" uttering", "fluttering"),
            (" uctuate", "fluctuate"),
            (" uctuates", "fluctuates"),
            (" uctuation", "fluctuation"),
            (" uctuations", "fluctuations"),
            ("in ame", "inflame"),
            ("in amed", "inflamed"),
            ("in ammation", "inflammation"),
            ("in ate", "inflate"),
            ("in ated", "inflated"),
            ("in ation", "inflation"),
            ("de ect", "deflect"),
            ("de ected", "deflected"),
            ("de ection", "deflection"),
            (" uid", "fluid"),
            (" uids", "fluids"),
            (" uidity", "fluidity"),
            (" uent", "fluent"),
            (" uency", "fluency"),
            (" uently", "fluently"),
        ]
    }

    private var fiPatterns: [(String, String)] {
        [
            ("sel ng", "selfing"),
            ("Sel ng", "Selfing"),
            ("sel sh", "selfish"),
            ("sel shness", "selfishness"),
            ("sel shly", "selfishly"),
            ("unsel sh", "unselfish"),
            ("sel -", "self-"),
            ("speci c", "specific"),
            ("speci cs", "specifics"),
            ("speci cally", "specifically"),
            ("speci city", "specificity"),
            ("speci ed", "specified"),
            ("speci es", "specifies"),
            ("speci cation", "specification"),
            ("speci cations", "specifications"),
            ("unspeci ed", "unspecified"),
            ("scienti c", "scientific"),
            ("scienti cally", "scientifically"),
            ("signi cant", "significant"),
            ("signi cantly", "significantly"),
            ("signi cance", "significance"),
            ("insigni cant", "insignificant"),
            ("de ne", "define"),
            ("de nes", "defines"),
            ("de ned", "defined"),
            ("de ning", "defining"),
            ("de nition", "definition"),
            ("de nitions", "definitions"),
            ("de nite", "definite"),
            ("de nitely", "definitely"),
            ("de nitive", "definitive"),
            ("de nitively", "definitively"),
            ("unde ned", "undefined"),
            ("rede ne", "redefine"),
            ("rede ned", "redefined"),
            ("bene t", "benefit"),
            ("bene ts", "benefits"),
            ("bene ted", "benefited"),
            ("bene ting", "benefiting"),
            ("bene cial", "beneficial"),
            ("bene ciary", "beneficiary"),
            (" nd", "find"),
            (" nds", "finds"),
            (" nding", "finding"),
            (" ndings", "findings"),
            (" nder", "finder"),
            (" nal", "final"),
            (" nals", "finals"),
            (" nally", "finally"),
            (" nalize", "finalize"),
            (" nalized", "finalized"),
            (" nality", "finality"),
            (" ne", "fine"),
            (" ner", "finer"),
            (" nest", "finest"),
            (" nely", "finely"),
            ("re ne", "refine"),
            ("re ned", "refined"),
            ("re ning", "refining"),
            ("re nement", "refinement"),
            (" nish", "finish"),
            (" nishes", "finishes"),
            (" nished", "finished"),
            (" nishing", "finishing"),
            ("un nished", "unfinished"),
            (" nite", "finite"),
            ("in nite", "infinite"),
            ("in nitely", "infinitely"),
            ("in nity", "infinity"),
            (" nger", "finger"),
            (" ngers", "fingers"),
            (" ngertip", "fingertip"),
            (" re", "fire"),
            (" res", "fires"),
            (" red", "fired"),
            (" ring", "firing"),
            (" rm", "firm"),
            (" rms", "firms"),
            (" rmly", "firmly"),
            (" rmness", "firmness"),
            ("con rm", "confirm"),
            ("con rms", "confirms"),
            ("con rmed", "confirmed"),
            ("con rming", "confirming"),
            ("con rmation", "confirmation"),
            (" rst", "first"),
            (" rstly", "firstly"),
            (" sh", "fish"),
            (" shes", "fishes"),
            (" shing", "fishing"),
            (" sherman", "fisherman"),
            (" shy", "fishy"),
            (" t", "fit"),
            (" ts", "fits"),
            (" tted", "fitted"),
            (" tting", "fitting"),
            (" tness", "fitness"),
            ("out t", "outfit"),
            ("pro t", "profit"),
            ("pro ts", "profits"),
            ("pro table", "profitable"),
            ("nonpro t", "nonprofit"),
            (" x", "fix"),
            (" xes", "fixes"),
            (" xed", "fixed"),
            (" xing", "fixing"),
            (" xation", "fixation"),
            ("pre x", "prefix"),
            ("su  x", "suffix"),
            ("a  x", "affix"),
            (" gure", "figure"),
            (" gures", "figures"),
            (" gured", "figured"),
            (" guring", "figuring"),
            (" gurative", "figurative"),
            ("con gure", "configure"),
            ("con gured", "configured"),
            ("con guration", "configuration"),
            (" ll", "fill"),
            (" lls", "fills"),
            (" lled", "filled"),
            (" lling", "filling"),
            ("ful ll", "fulfill"),
            ("ful lled", "fulfilled"),
            ("ful lling", "fulfilling"),
            ("ful llment", "fulfillment"),
            (" lm", "film"),
            (" lms", "films"),
            (" lmed", "filmed"),
            (" lming", "filming"),
            (" lter", "filter"),
            (" lters", "filters"),
            (" ltered", "filtered"),
            (" ltering", "filtering"),
            (" eld", "field"),
            (" elds", "fields"),
            ("identi ed", "identified"),
            ("identi es", "identifies"),
            ("identi cation", "identification"),
            ("identi able", "identifiable"),
            ("clari ed", "clarified"),
            ("clari es", "clarifies"),
            ("clari cation", "clarification"),
            ("modi ed", "modified"),
            ("modi es", "modifies"),
            ("modi cation", "modification"),
            ("veri ed", "verified"),
            ("veri es", "verifies"),
            ("veri cation", "verification"),
            ("magni ed", "magnified"),
            ("magni cent", "magnificent"),
            ("magni cence", "magnificence"),
            ("certi ed", "certified"),
            ("certi cate", "certificate"),
            ("certi cation", "certification"),
            ("justi ed", "justified"),
            ("justi cation", "justification"),
            ("sacri ce", "sacrifice"),
            ("sacri ces", "sacrifices"),
            ("sacri ced", "sacrificed"),
            ("sacri cing", "sacrificing"),
            ("of ce", "office"),
            ("of ces", "offices"),
            ("of cer", "officer"),
            ("of cers", "officers"),
            ("pro ciency", "proficiency"),
            ("pro cient", "proficient"),
            ("arti cial", "artificial"),
            ("arti cially", "artificially"),
            ("super cial", "superficial"),
            ("super cially", "superficially"),
            ("suf cient", "sufficient"),
            ("insuf cient", "insufficient"),
            ("ef cient", "efficient"),
            ("inef cient", "inefficient"),
            ("ef ciency", "efficiency"),
            ("inef ciency", "inefficiency"),
            ("de cit", "deficit"),
            ("de cits", "deficits"),
        ]
    }

    private var ftPatterns: [(String, String)] {
        [
            ("o en", "often"),
            ("a er", "after"),
            ("a erward", "afterward"),
            ("a erwards", "afterwards"),
            ("a ernoon", "afternoon"),
            ("a ernoons", "afternoons"),
            ("a ermath", "aftermath"),
            ("a erthought", "afterthought"),
            ("herea er", "hereafter"),
            ("wherea er", "whereafter"),
            ("therea er", "thereafter"),
            ("so ", "soft"),
            ("so ly", "softly"),
            ("so ness", "softness"),
            ("so en", "soften"),
            ("so ened", "softened"),
            ("so ening", "softening"),
            ("so ware", "software"),
            ("Microso ", "Microsoft"),
            ("le ", "left"),
            ("le over", "leftover"),
            ("le overs", "leftovers"),
            ("shi ", "shift"),
            ("shi s", "shifts"),
            ("shi ed", "shifted"),
            ("shi ing", "shifting"),
            ("dri ", "drift"),
            ("dri s", "drifts"),
            ("dri ed", "drifted"),
            ("dri ing", "drifting"),
            ("gi ", "gift"),
            ("gi s", "gifts"),
            ("gi ed", "gifted"),
            ("li ", "lift"),
            ("li s", "lifts"),
            ("li ed", "lifted"),
            ("li ing", "lifting"),
            ("upli ", "uplift"),
            ("upli ing", "uplifting"),
            ("swi ", "swift"),
            ("swi ly", "swiftly"),
            ("swi ness", "swiftness"),
            ("cra ", "craft"),
            ("cra s", "crafts"),
            ("cra ed", "crafted"),
            ("cra ing", "crafting"),
            ("cra y", "crafty"),
            ("aircra ", "aircraft"),
            ("spacecra ", "spacecraft"),
            ("dra ", "draft"),
            ("dra s", "drafts"),
            ("dra ed", "drafted"),
            ("dra ing", "drafting"),
            ("the ", "theft"),
            ("the s", "thefts"),
            ("lo ", "loft"),
            ("lo y", "lofty"),
            ("ra ", "raft"),
            ("ra s", "rafts"),
        ]
    }

    private var ggPatterns: [(String, String)] {
        [
            ("stru le", "struggle"),
            ("stru les", "struggles"),
            ("stru led", "struggled"),
            ("stru ling", "struggling"),
            ("tri er", "trigger"),
            ("tri ers", "triggers"),
            ("tri ered", "triggered"),
            ("tri ering", "triggering"),
            ("bi er", "bigger"),
            ("bi est", "biggest"),
            ("su est", "suggest"),
            ("su ests", "suggests"),
            ("su ested", "suggested"),
            ("su esting", "suggesting"),
            ("su estion", "suggestion"),
            ("su estions", "suggestions"),
            ("sta er", "stagger"),
            ("sta ered", "staggered"),
            ("sta ering", "staggering"),
            ("da er", "dagger"),
            ("da ers", "daggers"),
            ("lo ing", "logging"),
            ("jo ing", "jogging"),
            ("fo y", "foggy"),
            ("bo y", "boggy"),
            ("mu y", "muggy"),
            ("sna y", "snaggy"),
            ("sha y", "shaggy"),
            ("e s", "eggs"),
            ("e shell", "eggshell"),
            ("smu le", "smuggle"),
            ("smu led", "smuggled"),
            ("smu ler", "smuggler"),
            ("smu ling", "smuggling"),
            ("gi le", "giggle"),
            ("gi led", "giggled"),
            ("gi ling", "giggling"),
            ("wi le", "wiggle"),
            ("wi led", "wiggled"),
            ("wi ling", "wiggling"),
            ("ji le", "jiggle"),
            ("ji led", "jiggled"),
            ("ji ling", "jiggling"),
            ("to le", "toggle"),
            ("to led", "toggled"),
            ("to ling", "toggling"),
            ("go les", "goggles"),
            ("ba age", "baggage"),
            ("la ed", "lagged"),
            ("la ing", "lagging"),
            ("dra ed", "dragged"),
            ("dra ing", "dragging"),
        ]
    }

    private var singleFPatterns: [(String, String)] {
        [
            ("sel ", "self"),
            ("mysel ", "myself"),
            ("yoursel ", "yourself"),
            ("himsel ", "himself"),
            ("hersel ", "herself"),
            ("itsel ", "itself"),
            ("oursel ", "ourself"),
            ("themsel ", "themself"),
            ("onesel ", "oneself"),
            ("belie ", "belief"),
            ("belie s", "beliefs"),
            ("disbelie ", "disbelief"),
            ("relie ", "relief"),
            ("grie ", "grief"),
            ("chie ", "chief"),
            ("chie s", "chiefs"),
            ("chie ly", "chiefly"),
            ("mischie ", "mischief"),
            ("brie ", "brief"),
            ("brie y", "briefly"),
            ("brie ng", "briefing"),
            ("brie ngs", "briefings"),
            ("debrie ", "debrief"),
            ("debrie ng", "debriefing"),
            ("proo ", "proof"),
            ("proo s", "proofs"),
            ("disproo ", "disproof"),
            ("waterproo ", "waterproof"),
            ("bulletproo ", "bulletproof"),
            ("foolproo ", "foolproof"),
            ("roo ", "roof"),
            ("roo s", "roofs"),
            ("roo ng", "roofing"),
            ("roo top", "rooftop"),
            ("hoo ", "hoof"),
            ("hoo s", "hoofs"),
            ("lea ", "leaf"),
            ("lea y", "leafy"),
            ("hal ", "half"),
            ("hal way", "halfway"),
            ("hal time", "halftime"),
            ("lie ", "life"),
            ("lie s", "lifes"),
            ("wi e", "wife"),
            ("sae ", "safe"),
            ("sae ty", "safety"),
            ("shel ", "shelf"),
            ("wol ", "wolf"),
            (" o Verbal", " of Verbal"),
            (" o the ", " of the "),
        ]
    }

    private var thPatterns: [(String, String)] {
        [
            ("Th is", "This"),
            ("Th at", "That"),
            ("Th e", "The"),
            ("Th en", "Then"),
            ("Th ere", "There"),
            ("Th ey", "They"),
            ("Th us", "Thus"),
            ("Th rough", "Through"),
            ("Th ink", "Think"),
            ("Th ought", "Thought"),
            ("Th erapy", "Therapy"),
            ("Th erapist", "Therapist"),
            ("Th eory", "Theory"),
        ]
    }

    private var quPatterns: [(String, String)] {
        [
            (" uestion", "question"),
            (" uestions", "questions"),
            (" uestioned", "questioned"),
            (" uestioning", "questioning"),
            (" uestionnaire", "questionnaire"),
            ("un uestionable", "unquestionable"),
            ("un uestionably", "unquestionably"),
            ("re uire", "require"),
            ("re uires", "requires"),
            ("re uired", "required"),
            ("re uiring", "requiring"),
            ("re uirement", "requirement"),
            ("re uirements", "requirements"),
            ("fre uent", "frequent"),
            ("fre uently", "frequently"),
            ("fre uency", "frequency"),
            ("infre uent", "infrequent"),
            ("infre uently", "infrequently"),
            ("conse uence", "consequence"),
            ("conse uences", "consequences"),
            ("conse uent", "consequent"),
            ("conse uently", "consequently"),
            ("inconse uential", "inconsequential"),
            ("uni ue", "unique"),
            ("uni uely", "uniquely"),
            ("uni ueness", "uniqueness"),
            ("techni ue", "technique"),
            ("techni ues", "techniques"),
            ("ade uate", "adequate"),
            ("ade uately", "adequately"),
            ("inade uate", "inadequate"),
            ("inade uately", "inadequately"),
            ("e ual", "equal"),
            ("e uals", "equals"),
            ("e ually", "equally"),
            ("e uality", "equality"),
            ("une ual", "unequal"),
            ("ine uality", "inequality"),
            ("e uivalent", "equivalent"),
            ("e uivalence", "equivalence"),
            ("se uence", "sequence"),
            ("se uences", "sequences"),
            ("se uential", "sequential"),
            ("se uentially", "sequentially"),
            ("subse uent", "subsequent"),
            ("subse uently", "subsequently"),
            ("elo uent", "eloquent"),
            ("elo uently", "eloquently"),
            ("elo uence", "eloquence"),
            (" uality", "quality"),
            (" ualities", "qualities"),
            (" ualitative", "qualitative"),
            (" ualify", "qualify"),
            (" ualified", "qualified"),
            (" ualification", "qualification"),
            ("dis ualify", "disqualify"),
            ("dis ualified", "disqualified"),
            (" uantity", "quantity"),
            (" uantities", "quantities"),
            (" uantitative", "quantitative"),
            (" uantify", "quantify"),
            (" uantified", "quantified"),
            (" uote", "quote"),
            (" uotes", "quotes"),
            (" uoted", "quoted"),
            (" uoting", "quoting"),
            (" uotation", "quotation"),
            (" uiet", "quiet"),
            (" uietly", "quietly"),
            (" uietness", "quietness"),
            (" uick", "quick"),
            (" uickly", "quickly"),
            (" uicker", "quicker"),
            (" uickest", "quickest"),
            ("ac uire", "acquire"),
            ("ac uires", "acquires"),
            ("ac uired", "acquired"),
            ("ac uiring", "acquiring"),
            ("ac uisition", "acquisition"),
            ("in uire", "inquire"),
            ("in uires", "inquires"),
            ("in uired", "inquired"),
            ("in uiring", "inquiring"),
            ("in uiry", "inquiry"),
            ("in uiries", "inquiries"),
            ("s uare", "square"),
            ("s uares", "squares"),
            ("s uared", "squared"),
            ("s ueeze", "squeeze"),
            ("s ueezes", "squeezes"),
            ("s ueezed", "squeezed"),
            ("s ueezing", "squeezing"),
        ]
    }

    private var frenchPatterns: [(String, String)] {
        [
            ("c ur", "cœur"),
            ("c urs", "cœurs"),
            (" uvre", "œuvre"),
            (" uvres", "œuvres"),
            ("b uf", "bœuf"),
            ("b ufs", "bœufs"),
            ("s ur", "sœur"),
            ("s urs", "sœurs"),
            ("n ud", "nœud"),
            ("n uds", "nœuds"),
            ("v u", "vœu"),
            ("v ux", "vœux"),
            ("man uvre", "manœuvre"),
            ("man uvres", "manœuvres"),
        ]
    }
}

// MARK: - Convenience Extensions

extension PDFTextFixer {

    /// Create a fixer optimized for academic/psychology texts
    public static var academic: PDFTextFixer {
        let fixer = PDFTextFixer(options: .all, typographyMode: .normalize)
        fixer.enableLogging = true
        fixer.customPatterns = [
            ("psychologi cal", "psychological"),
            ("behavi oral", "behavioral"),
            ("cogni tive", "cognitive"),
            ("thera peutic", "therapeutic"),
        ]
        return fixer
    }

    /// Create a fixer with minimal changes (ligatures only)
    public static var minimal: PDFTextFixer {
        PDFTextFixer(options: .standard, typographyMode: .preserve)
    }

    /// Create a fixer with French language support
    public static var french: PDFTextFixer {
        var options = Options.all
        options.insert(.fixFrenchLigatures)
        return PDFTextFixer(options: options, typographyMode: .normalize)
    }
}
