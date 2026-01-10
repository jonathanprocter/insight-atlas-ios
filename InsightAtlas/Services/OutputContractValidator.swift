//
//  OutputContractValidator.swift
//  InsightAtlas
//
//  Output Contract Validation Service.
//
//  Validates that normalized editorial content meets the Insight Atlas
//  output contract requirements:
//  - No markdown artifacts (**, *, #, >, etc.)
//  - All blocks have explicit types
//  - Parity across formats (PDF, DOCX, HTML)
//
//  EXTENDED (v1.1):
//  - Block integrity checks (sentence limits, no implicit frameworks)
//  - Visual density validation (zones, first-block rule)
//  - Narration readiness (clean text, isolated quotes)
//  - Profile consistency (deterministic output)
//
//  GOVERNANCE:
//  - This service validates but does NOT modify content
//  - Validation occurs AFTER semantic normalization
//  - If QA fails, generation halts
//  - Reports are for QA purposes only
//
//  VERSION: 1.1.0
//

import Foundation

// MARK: - Output Contract Validator

/// Validates editorial documents against the Insight Atlas output contract.
///
/// Usage:
/// ```swift
/// let validator = OutputContractValidator()
/// let report = validator.validate(document)
/// print(report.isValid ? "Contract satisfied" : report.issues)
/// ```
final class OutputContractValidator {

    // MARK: - Validation Report

    struct ValidationReport {
        let isValid: Bool
        let issues: [ValidationIssue]
        let blockCount: Int
        let typedBlockCount: Int
        let markdownArtifactCount: Int

        var summary: String {
            if isValid {
                return "Output contract satisfied: \(blockCount) blocks, all explicitly typed, no markdown artifacts"
            } else {
                return "Output contract violated: \(issues.count) issues found"
            }
        }
    }

    struct ValidationIssue: CustomStringConvertible {
        enum Severity: String {
            case error = "ERROR"
            case warning = "WARNING"
            case info = "INFO"
        }

        enum Category: String {
            // Original categories
            case markdownArtifact = "MARKDOWN_ARTIFACT"
            case missingType = "MISSING_TYPE"
            case emptyBlock = "EMPTY_BLOCK"
            case densityViolation = "DENSITY_VIOLATION"
            case structureViolation = "STRUCTURE_VIOLATION"

            // v1.1 Block Integrity categories
            case sentenceLimitExceeded = "SENTENCE_LIMIT_EXCEEDED"
            case implicitFramework = "IMPLICIT_FRAMEWORK"
            case mixedIntentBlock = "MIXED_INTENT_BLOCK"

            // v1.1 Visual Density categories
            case visualZoneViolation = "VISUAL_ZONE_VIOLATION"
            case visualFirstBlockViolation = "VISUAL_FIRST_BLOCK"
            case visualDensityExceeded = "VISUAL_DENSITY_EXCEEDED"

            // v1.1 Narration Readiness categories
            case uncleanNarrationText = "UNCLEAN_NARRATION_TEXT"
            case unisolatedQuote = "UNISOLATED_QUOTE"

            // v1.1 Profile Consistency categories
            case profileInconsistency = "PROFILE_INCONSISTENCY"
            case pacingViolation = "PACING_VIOLATION"
        }

        let severity: Severity
        let category: Category
        let message: String
        let blockIndex: Int?
        let blockType: EditorialBlockType?

        var description: String {
            var result = "[\(severity.rawValue)] \(category.rawValue): \(message)"
            if let index = blockIndex {
                result += " (block \(index)"
                if let type = blockType {
                    result += ", type: \(type.rawValue)"
                }
                result += ")"
            }
            return result
        }
    }

    // MARK: - Markdown Patterns to Detect

    private let markdownPatterns: [(pattern: String, description: String)] = [
        ("\\*\\*[^*]+\\*\\*", "Bold markers (**)"),
        ("__[^_]+__", "Bold markers (__)"),
        ("(?<!\\*)\\*[^*]+\\*(?!\\*)", "Italic markers (*)"),
        ("_[^_]+_", "Italic markers (_)"),
        ("^#+\\s", "Heading markers (#)"),
        ("^>\\s", "Blockquote markers (>)"),
        ("^\\s*[-*+]\\s", "Unprocessed list markers"),
        ("^\\s*\\d+\\.\\s", "Unprocessed numbered list"),
        ("`[^`]+`", "Inline code markers"),
        ("```", "Code fence markers (```)"),
        ("~~~", "Code fence markers"),
        ("\\[([^\\]]+)\\]\\(([^)]+)\\)", "Markdown links"),
        ("^---+$|^\\*\\*\\*+$|^___+$", "Horizontal rules"),
    ]

    // MARK: - Public Methods

    /// Validate an editorial document against the output contract
    ///
    /// - Parameter document: The normalized editorial document
    /// - Returns: Validation report with issues and statistics
    func validate(_ document: EditorialDocument) -> ValidationReport {
        var issues: [ValidationIssue] = []
        var markdownArtifactCount = 0

        // Validate each block
        for (index, block) in document.blocks.enumerated() {
            // Check for markdown artifacts in body
            let bodyArtifacts = findMarkdownArtifacts(in: block.body)
            for artifact in bodyArtifacts {
                issues.append(ValidationIssue(
                    severity: .error,
                    category: .markdownArtifact,
                    message: "Found \(artifact.description) in block body",
                    blockIndex: index,
                    blockType: block.type
                ))
                markdownArtifactCount += 1
            }

            // Check for markdown artifacts in title
            if let title = block.title {
                let titleArtifacts = findMarkdownArtifacts(in: title)
                for artifact in titleArtifacts {
                    issues.append(ValidationIssue(
                        severity: .error,
                        category: .markdownArtifact,
                        message: "Found \(artifact.description) in block title",
                        blockIndex: index,
                        blockType: block.type
                    ))
                    markdownArtifactCount += 1
                }
            }

            // Check for markdown artifacts in list items
            if let listItems = block.listItems {
                for (itemIndex, item) in listItems.enumerated() {
                    let itemArtifacts = findMarkdownArtifacts(in: item)
                    for artifact in itemArtifacts {
                        issues.append(ValidationIssue(
                            severity: .error,
                            category: .markdownArtifact,
                            message: "Found \(artifact.description) in list item \(itemIndex + 1)",
                            blockIndex: index,
                            blockType: block.type
                        ))
                        markdownArtifactCount += 1
                    }
                }
            }

            // Check for empty blocks (excluding dividers)
            if block.type != .sectionDivider {
                if block.body.isEmpty && (block.title ?? "").isEmpty && (block.listItems ?? []).isEmpty {
                    issues.append(ValidationIssue(
                        severity: .warning,
                        category: .emptyBlock,
                        message: "Block has no content",
                        blockIndex: index,
                        blockType: block.type
                    ))
                }
            }
        }

        // Check overall structure
        if document.blocks.isEmpty {
            issues.append(ValidationIssue(
                severity: .error,
                category: .structureViolation,
                message: "Document has no blocks",
                blockIndex: nil,
                blockType: nil
            ))
        }

        // Check for excessive visual density
        let visualBlocks = document.blocks.filter { isVisualBlock($0.type) }
        let totalBlocks = document.blocks.count
        if totalBlocks > 0 {
            let visualRatio = Double(visualBlocks.count) / Double(totalBlocks)
            if visualRatio > 0.3 {
                issues.append(ValidationIssue(
                    severity: .warning,
                    category: .densityViolation,
                    message: "Visual block ratio (\(Int(visualRatio * 100))%) exceeds recommended 30%",
                    blockIndex: nil,
                    blockType: nil
                ))
            }
        }

        let isValid = !issues.contains { $0.severity == .error }

        return ValidationReport(
            isValid: isValid,
            issues: issues,
            blockCount: document.blocks.count,
            typedBlockCount: document.blocks.count, // All blocks are typed by construction
            markdownArtifactCount: markdownArtifactCount
        )
    }

    /// Quick check if a document is valid (no errors)
    func isValid(_ document: EditorialDocument) -> Bool {
        return validate(document).isValid
    }

    // MARK: - Extended Validation (v1.1)

    /// Validate with profile-specific pacing rules
    ///
    /// - Parameters:
    ///   - document: The normalized editorial document
    ///   - profile: Reader profile for pacing validation
    ///   - visualSelections: Optional visual selections to validate
    /// - Returns: Comprehensive validation report
    func validateWithProfile(
        _ document: EditorialDocument,
        profile: ReaderProfile,
        visualSelections: [UUID: VisualSelectionService.VisualSelection]? = nil
    ) -> ValidationReport {
        var issues = validate(document).issues
        let pacing = ReaderProfilePacingRegistry.pacing(for: profile)

        // Block Integrity Checks
        issues.append(contentsOf: validateBlockIntegrity(document, pacing: pacing))

        // Visual Density Checks
        issues.append(contentsOf: validateVisualDensity(document, visualSelections: visualSelections))

        // Narration Readiness Checks
        issues.append(contentsOf: validateNarrationReadiness(document))

        // Profile Consistency Checks
        issues.append(contentsOf: validateProfileConsistency(document, profile: profile, pacing: pacing))

        let isValid = !issues.contains { $0.severity == .error }
        let markdownCount = issues.filter { $0.category == .markdownArtifact }.count

        return ValidationReport(
            isValid: isValid,
            issues: issues,
            blockCount: document.blocks.count,
            typedBlockCount: document.blocks.count,
            markdownArtifactCount: markdownCount
        )
    }

    // MARK: - Block Integrity Validation

    /// Validate block integrity against profile pacing
    private func validateBlockIntegrity(
        _ document: EditorialDocument,
        pacing: ReaderProfilePacing
    ) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        for (index, block) in document.blocks.enumerated() {
            // Check sentence count for paragraph blocks
            if block.type == .paragraph {
                let sentenceCount = countSentences(in: block.body)
                if sentenceCount > pacing.maxSentencesPerBlock {
                    issues.append(ValidationIssue(
                        severity: .warning,
                        category: .sentenceLimitExceeded,
                        message: "Block has \(sentenceCount) sentences (max: \(pacing.maxSentencesPerBlock) for profile)",
                        blockIndex: index,
                        blockType: block.type
                    ))
                }
            }

            // Check for implicit frameworks in paragraphs
            if block.type == .paragraph {
                if containsImplicitFramework(block.body) {
                    issues.append(ValidationIssue(
                        severity: .warning,
                        category: .implicitFramework,
                        message: "Paragraph contains framework-like structure that should be explicit",
                        blockIndex: index,
                        blockType: block.type
                    ))
                }
            }

            // Check for mixed-intent blocks
            if hasMixedIntent(block) {
                issues.append(ValidationIssue(
                    severity: .warning,
                    category: .mixedIntentBlock,
                    message: "Block appears to contain multiple conceptual moves",
                    blockIndex: index,
                    blockType: block.type
                ))
            }
        }

        return issues
    }

    // MARK: - Visual Density Validation

    /// Validate visual density rules
    private func validateVisualDensity(
        _ document: EditorialDocument,
        visualSelections: [UUID: VisualSelectionService.VisualSelection]?
    ) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        // Check for visuals near quotes/insights (zone violation)
        for (index, block) in document.blocks.enumerated() {
            if block.type == .premiumQuote || block.type == .insightNote {
                // Check blocks within 2 positions
                let nearbyRange = max(0, index - 2)...min(document.blocks.count - 1, index + 2)
                for nearbyIndex in nearbyRange where nearbyIndex != index {
                    let nearbyBlock = document.blocks[nearbyIndex]
                    if let selections = visualSelections,
                       let selection = selections[nearbyBlock.id],
                       selection.shouldHaveVisual {
                        issues.append(ValidationIssue(
                            severity: .warning,
                            category: .visualZoneViolation,
                            message: "Visual near quote/insight at index \(nearbyIndex) violates reflection zone",
                            blockIndex: nearbyIndex,
                            blockType: nearbyBlock.type
                        ))
                    }
                }
            }
        }

        // Check for visual as first block in section
        var isFirstInSection = true
        for (index, block) in document.blocks.enumerated() {
            if block.type == .sectionHeader || block.type == .partHeader {
                isFirstInSection = true
                continue
            }

            if isFirstInSection {
                if let selections = visualSelections,
                   let selection = selections[block.id],
                   selection.shouldHaveVisual {
                    issues.append(ValidationIssue(
                        severity: .warning,
                        category: .visualFirstBlockViolation,
                        message: "Visual as first block in section violates grounding rule",
                        blockIndex: index,
                        blockType: block.type
                    ))
                }
                isFirstInSection = false
            }
        }

        return issues
    }

    // MARK: - Narration Readiness Validation

    /// Validate that blocks are ready for narration
    private func validateNarrationReadiness(_ document: EditorialDocument) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        for (index, block) in document.blocks.enumerated() {
            // Check for clean narration text (no special characters, etc.)
            if hasUncleanNarrationText(block.body) {
                issues.append(ValidationIssue(
                    severity: .warning,
                    category: .uncleanNarrationText,
                    message: "Block contains characters that may affect narration quality",
                    blockIndex: index,
                    blockType: block.type
                ))
            }

            // Check for isolated quotes
            if block.type == .premiumQuote {
                // Check if previous block is also commentary
                if index > 0 {
                    let prevBlock = document.blocks[index - 1]
                    if prevBlock.type == .insightNote || prevBlock.type == .researchInsight {
                        issues.append(ValidationIssue(
                            severity: .info,
                            category: .unisolatedQuote,
                            message: "Quote immediately follows commentary (may affect cognitive isolation)",
                            blockIndex: index,
                            blockType: block.type
                        ))
                    }
                }
            }
        }

        return issues
    }

    // MARK: - Profile Consistency Validation

    /// Validate profile consistency
    private func validateProfileConsistency(
        _ document: EditorialDocument,
        profile: ReaderProfile,
        pacing: ReaderProfilePacing
    ) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        // Check insight note density per section
        var currentSectionInsightNotes = 0
        for (index, block) in document.blocks.enumerated() {
            if block.type == .sectionHeader || block.type == .partHeader {
                currentSectionInsightNotes = 0
            }

            if block.type == .insightNote {
                currentSectionInsightNotes += 1
                if currentSectionInsightNotes > pacing.maxInsightNotesPerSection {
                    issues.append(ValidationIssue(
                        severity: .warning,
                        category: .pacingViolation,
                        message: "Section has \(currentSectionInsightNotes) insight notes (max: \(pacing.maxInsightNotesPerSection) for \(profile.rawValue) profile)",
                        blockIndex: index,
                        blockType: block.type
                    ))
                }
            }
        }

        // Check for framework item count consistency
        for (index, block) in document.blocks.enumerated() {
            if block.type == .framework {
                let itemCount = block.listItems?.count ?? 0
                if itemCount < pacing.minimumFrameworkItems {
                    issues.append(ValidationIssue(
                        severity: .warning,
                        category: .pacingViolation,
                        message: "Framework has \(itemCount) items (min: \(pacing.minimumFrameworkItems) for \(profile.rawValue) profile)",
                        blockIndex: index,
                        blockType: block.type
                    ))
                }
            }
        }

        return issues
    }

    // MARK: - Helper Methods

    /// Count sentences in text
    private func countSentences(in text: String) -> Int {
        let pattern = #"[.!?]+\s+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return 1
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.numberOfMatches(in: text, range: range) + 1
    }

    /// Check for implicit framework patterns in prose
    private func containsImplicitFramework(_ text: String) -> Bool {
        // Look for numbered inline lists or colon-separated items
        let patterns = [
            #"(?:first|1\)|one)[,:].*(?:second|2\)|two)[,:].*(?:third|3\)|three)"#,
            #":\s*\([a-z]\)"#,
            #"(?:a\)|b\)|c\))"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                if regex.firstMatch(in: text, range: range) != nil {
                    return true
                }
            }
        }
        return false
    }

    /// Check if block has mixed intent
    private func hasMixedIntent(_ block: EditorialBlock) -> Bool {
        let text = block.body.lowercased()

        // Check for multiple conceptual markers in one block
        let conceptualMarkers = [
            EditorialPatternMarker.whyItMattersPatterns,
            EditorialPatternMarker.inPracticePatterns,
            EditorialPatternMarker.researchPatterns
        ]

        var matchedCategories = 0
        for patterns in conceptualMarkers {
            if patterns.contains(where: { text.contains($0) }) {
                matchedCategories += 1
            }
        }

        return matchedCategories > 1
    }

    /// Check for unclean narration text
    private func hasUncleanNarrationText(_ text: String) -> Bool {
        // Check for characters that may cause narration issues
        let problematicPatterns = [
            #"[^\x00-\x7F]"#,  // Non-ASCII (may need specific handling)
            #"\s{3,}"#,       // Excessive whitespace
            #"[│┌┐└┘├┤┬┴┼]"#, // Box drawing characters
            #"[→←↑↓]"#        // Arrow characters
        ]

        for pattern in problematicPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                if regex.firstMatch(in: text, range: range) != nil {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Private Methods

    private func findMarkdownArtifacts(in text: String) -> [(pattern: String, description: String)] {
        var found: [(pattern: String, description: String)] = []

        for (pattern, description) in markdownPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                if regex.firstMatch(in: text, range: range) != nil {
                    found.append((pattern, description))
                }
            }
        }

        return found
    }

    private func isVisualBlock(_ type: EditorialBlockType) -> Bool {
        switch type {
        case .visual, .framework, .decisionTree, .processFlow, .comparisonBeforeAfter, .conceptMap:
            return true
        default:
            return false
        }
    }
}

// MARK: - Format Parity Checker

/// Validates parity across export formats.
///
/// Ensures the same editorial document produces equivalent content
/// across PDF, DOCX, and HTML exports.
final class FormatParityChecker {

    struct ParityReport {
        let format: String
        let blockCount: Int
        let preservedTypes: Set<EditorialBlockType>
        let lostTypes: Set<EditorialBlockType>

        var hasFullParity: Bool {
            return lostTypes.isEmpty
        }
    }

    /// Check which block types are supported by a format
    func checkParity(document: EditorialDocument, format: String) -> ParityReport {
        // All Insight Atlas block types should map to renderable output
        // This checks which types have rendering support

        let allTypes = Set(document.blocks.map { $0.type })

        // Define which types each format supports
        // PDF and HTML support all types; DOCX has documented limitations
        let supportedTypes: Set<EditorialBlockType>

        switch format.lowercased() {
        case "pdf":
            // PDF supports all block types through PDFContentBlockRenderer
            supportedTypes = Set(EditorialBlockType.allCases)

        case "docx":
            // GOVERNANCE LOCK: DOCX format has intentional limitations.
            // Complex visual block types cannot be rendered with full fidelity
            // in Word documents. This is by design—PDF is the recommended
            // format for complete visual representation.
            //
            // Excluded types:
            // - .conceptMap: Requires complex SVG/diagram rendering
            // - .decisionTree: Requires branching visual layout
            //
            // Users should be directed to PDF export for full fidelity.
            supportedTypes = Set(EditorialBlockType.allCases).subtracting([
                .conceptMap, .decisionTree
            ])

        case "html":
            // HTML supports all types
            supportedTypes = Set(EditorialBlockType.allCases)

        default:
            supportedTypes = Set(EditorialBlockType.allCases)
        }

        let preservedTypes = allTypes.intersection(supportedTypes)
        let lostTypes = allTypes.subtracting(supportedTypes)

        return ParityReport(
            format: format,
            blockCount: document.blocks.count,
            preservedTypes: preservedTypes,
            lostTypes: lostTypes
        )
    }
}
