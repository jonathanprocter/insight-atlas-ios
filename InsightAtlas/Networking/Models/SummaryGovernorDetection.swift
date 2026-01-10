//
//  SummaryGovernorDetection.swift
//  InsightAtlas
//
//  Source type and expansion type detection for Summary Type Governors v1.0.
//
//  Detection is run once per source and cached. Results are deterministic.
//
//  Reference: InsightAtlas/Documentation/GOVERNANCE_LOCKS.md
//

import Foundation

// MARK: - Source Type Detector

/// Detects the primary source type of a document.
///
/// ## Detection Algorithm
///
/// Run once per source, cache result.
///
/// **Argumentative** (threshold >= 3):
/// - +2: "argues that" / "claims that"
/// - +1: "evidence suggests" / "research shows"
/// - +1: "therefore" / "thus" >= 5 times
///
/// **Narrative** (threshold >= 3):
/// - +2: dialogue markers
/// - +1: temporal markers >= 10
/// - +1: scene-setting language
///
/// **Technical** (threshold >= 3):
/// - +2: numbered steps
/// - +1: definition patterns
/// - +1: tables/code/specs
///
/// **Tie-break**: argumentative > technical > narrative
/// **Default**: argumentative
struct SourceTypeDetector {

    // MARK: - Detection Thresholds

    static let detectionThreshold: Int = 3
    static let temporalMarkerThreshold: Int = 10
    static let conjunctionThreshold: Int = 5

    // MARK: - Detection

    /// Detects the source type of a document.
    ///
    /// - Parameter text: Full text of the source document
    /// - Returns: Detected source type with scores
    static func detect(text: String) -> SourceTypeDetectionResult {
        let lowercaseText = text.lowercased()

        let argumentativeScore = calculateArgumentativeScore(text: lowercaseText)
        let narrativeScore = calculateNarrativeScore(text: lowercaseText)
        let technicalScore = calculateTechnicalScore(text: lowercaseText)

        let detectedType = resolveType(
            argumentative: argumentativeScore,
            narrative: narrativeScore,
            technical: technicalScore
        )

        return SourceTypeDetectionResult(
            detectedType: detectedType,
            argumentativeScore: argumentativeScore,
            narrativeScore: narrativeScore,
            technicalScore: technicalScore
        )
    }

    // MARK: - Argumentative Detection

    private static func calculateArgumentativeScore(text: String) -> Int {
        var score = 0

        // +2: "argues that" / "claims that"
        let strongArgumentPatterns = [
            "argues that",
            "claims that",
            "contends that",
            "asserts that",
            "maintains that"
        ]
        for pattern in strongArgumentPatterns {
            if text.contains(pattern) {
                score += 2
                break
            }
        }

        // +1: "evidence suggests" / "research shows"
        let evidencePatterns = [
            "evidence suggests",
            "research shows",
            "studies indicate",
            "data demonstrates",
            "findings reveal"
        ]
        for pattern in evidencePatterns {
            if text.contains(pattern) {
                score += 1
                break
            }
        }

        // +1: "therefore" / "thus" >= 5 times
        let conjunctionPatterns = ["therefore", "thus", "hence", "consequently"]
        var conjunctionCount = 0
        for pattern in conjunctionPatterns {
            conjunctionCount += countOccurrences(of: pattern, in: text)
        }
        if conjunctionCount >= conjunctionThreshold {
            score += 1
        }

        return score
    }

    // MARK: - Narrative Detection

    private static func calculateNarrativeScore(text: String) -> Int {
        var score = 0

        // +2: dialogue markers
        let dialogueMarkers = [
            "\" he said",
            "\" she said",
            "\" they said",
            "\"i said",
            "\" asked",
            "\" replied",
            "\" exclaimed"
        ]
        for marker in dialogueMarkers {
            if text.contains(marker) {
                score += 2
                break
            }
        }

        // +1: temporal markers >= 10
        let temporalMarkers = [
            "once upon",
            "long ago",
            "the next day",
            "later that",
            "years later",
            "in the beginning",
            "at first",
            "finally",
            "eventually",
            "meanwhile",
            "suddenly",
            "after that"
        ]
        var temporalCount = 0
        for marker in temporalMarkers {
            temporalCount += countOccurrences(of: marker, in: text)
        }
        if temporalCount >= temporalMarkerThreshold {
            score += 1
        }

        // +1: scene-setting language
        let scenePatterns = [
            "the room was",
            "the sun was",
            "it was a dark",
            "the wind",
            "outside the window",
            "in the distance"
        ]
        for pattern in scenePatterns {
            if text.contains(pattern) {
                score += 1
                break
            }
        }

        return score
    }

    // MARK: - Technical Detection

    private static func calculateTechnicalScore(text: String) -> Int {
        var score = 0

        // +2: numbered steps
        let numberedStepPatterns = [
            "step 1",
            "step 2",
            "1. ",
            "2. ",
            "first, ",
            "second, ",
            "third, "
        ]
        var numberedStepCount = 0
        for pattern in numberedStepPatterns {
            if text.contains(pattern) {
                numberedStepCount += 1
            }
        }
        if numberedStepCount >= 2 {
            score += 2
        }

        // +1: definition patterns
        let definitionPatterns = [
            " is defined as ",
            " refers to ",
            " means that ",
            " is the process of ",
            " can be described as "
        ]
        for pattern in definitionPatterns {
            if text.contains(pattern) {
                score += 1
                break
            }
        }

        // +1: tables/code/specs
        let technicalIndicators = [
            "```",
            "| --- |",
            "specification",
            "parameter:",
            "returns:",
            "example:",
            "syntax:"
        ]
        for indicator in technicalIndicators {
            if text.contains(indicator) {
                score += 1
                break
            }
        }

        return score
    }

    // MARK: - Type Resolution

    private static func resolveType(
        argumentative: Int,
        narrative: Int,
        technical: Int
    ) -> GovernorSourceType {
        // Check if any meets threshold
        let argumentativeMeets = argumentative >= detectionThreshold
        let narrativeMeets = narrative >= detectionThreshold
        let technicalMeets = technical >= detectionThreshold

        // If none meet threshold, default to argumentative
        if !argumentativeMeets && !narrativeMeets && !technicalMeets {
            return .argumentative
        }

        // Tie-break: argumentative > technical > narrative
        if argumentativeMeets && argumentative >= technical && argumentative >= narrative {
            return .argumentative
        }
        if technicalMeets && technical >= narrative {
            return .technical
        }
        if narrativeMeets {
            return .narrative
        }

        // Fallback to highest score with tie-break order
        if argumentative >= technical && argumentative >= narrative {
            return .argumentative
        }
        if technical >= narrative {
            return .technical
        }
        return .narrative
    }

    // MARK: - Helpers

    private static func countOccurrences(of substring: String, in string: String) -> Int {
        var count = 0
        var searchRange = string.startIndex..<string.endIndex

        while let foundRange = string.range(of: substring, range: searchRange) {
            count += 1
            searchRange = foundRange.upperBound..<string.endIndex
        }

        return count
    }
}

// MARK: - Source Type Detection Result

/// Result of source type detection.
struct SourceTypeDetectionResult: Codable, Hashable {
    /// The detected source type
    let detectedType: GovernorSourceType

    /// Score for argumentative classification
    let argumentativeScore: Int

    /// Score for narrative classification
    let narrativeScore: Int

    /// Score for technical classification
    let technicalScore: Int

    /// Returns true if detection met threshold for the detected type.
    var metThreshold: Bool {
        switch detectedType {
        case .argumentative:
            return argumentativeScore >= SourceTypeDetector.detectionThreshold
        case .narrative:
            return narrativeScore >= SourceTypeDetector.detectionThreshold
        case .technical:
            return technicalScore >= SourceTypeDetector.detectionThreshold
        }
    }
}

// MARK: - Expansion Type Detector

/// Detects the expansion type of a content block.
///
/// ## Detection Algorithm
///
/// First match wins, in order:
/// 1. exercise
/// 2. adjacentDomainComparison
/// 3. extendedCommentary
/// 4. secondaryExample
/// 5. stylisticElaboration
/// 6. coreArgument (default - never cut)
struct ExpansionTypeDetector {

    // MARK: - Detection

    /// Detects the expansion type of a content block.
    ///
    /// - Parameter text: Text of the content block
    /// - Returns: Detected expansion type
    static func detect(text: String) -> ExpansionType {
        let lowercaseText = text.lowercased()

        // 1. Exercise
        if isExercise(text: lowercaseText) {
            return .exercise
        }

        // 2. Adjacent domain comparison
        if isAdjacentDomainComparison(text: lowercaseText) {
            return .adjacentDomainComparison
        }

        // 3. Extended commentary
        if isExtendedCommentary(text: lowercaseText) {
            return .extendedCommentary
        }

        // 4. Secondary example
        if isSecondaryExample(text: lowercaseText) {
            return .secondaryExample
        }

        // 5. Stylistic elaboration
        if isStylisticElaboration(text: lowercaseText) {
            return .stylisticElaboration
        }

        // 6. Core argument (default - never cut)
        return .coreArgument
    }

    // MARK: - Exercise Detection

    private static func isExercise(text: String) -> Bool {
        let exerciseIndicators = [
            "exercise:",
            "try this:",
            "practice:",
            "your turn:",
            "activity:",
            "worksheet",
            "complete the following",
            "fill in the blank",
            "answer the question"
        ]

        for indicator in exerciseIndicators {
            if text.contains(indicator) {
                return true
            }
        }
        return false
    }

    // MARK: - Adjacent Domain Comparison Detection

    private static func isAdjacentDomainComparison(text: String) -> Bool {
        let comparisonIndicators = [
            "similarly in",
            "just like in",
            "analogous to",
            "comparable to",
            "much like",
            "reminds us of",
            "parallel to",
            "in another field",
            "in a different domain",
            "cross-pollination"
        ]

        for indicator in comparisonIndicators {
            if text.contains(indicator) {
                return true
            }
        }
        return false
    }

    // MARK: - Extended Commentary Detection

    private static func isExtendedCommentary(text: String) -> Bool {
        let commentaryIndicators = [
            "furthermore",
            "moreover",
            "in addition",
            "it's worth noting",
            "interestingly",
            "notably",
            "as an aside",
            "on a related note",
            "to elaborate",
            "expanding on this"
        ]

        var matchCount = 0
        for indicator in commentaryIndicators {
            if text.contains(indicator) {
                matchCount += 1
            }
        }

        // Extended commentary typically has multiple commentary markers
        return matchCount >= 2
    }

    // MARK: - Secondary Example Detection

    private static func isSecondaryExample(text: String) -> Bool {
        let secondaryExampleIndicators = [
            "another example",
            "a second example",
            "for instance",
            "consider also",
            "similarly,",
            "likewise,",
            "take another case",
            "here's another",
            "additional example"
        ]

        for indicator in secondaryExampleIndicators {
            if text.contains(indicator) {
                return true
            }
        }
        return false
    }

    // MARK: - Stylistic Elaboration Detection

    private static func isStylisticElaboration(text: String) -> Bool {
        let stylisticIndicators = [
            "in other words",
            "put simply",
            "to put it another way",
            "that is to say",
            "essentially",
            "in essence",
            "simply put",
            "restated"
        ]

        for indicator in stylisticIndicators {
            if text.contains(indicator) {
                return true
            }
        }
        return false
    }
}

// MARK: - Chapter Detection

/// Detects chapters/sections in a source document.
///
/// ## Algorithm
///
/// 1. Detect chapters in document order
/// 2. If none detected → treatAsMonolith
/// 3. If >= 50 detected → merge adjacent small sections until < 50
/// 4. Emit exactly one SectionDetectionEvent per source
struct ChapterDetector {

    // MARK: - Constants

    static let maxChaptersBeforeMerge: Int = 50

    // MARK: - Detection

    /// Detects chapters in a source document.
    ///
    /// - Parameters:
    ///   - text: Full text of the source document
    ///   - fallbackStrategy: Strategy to use if detection fails
    /// - Returns: Detection result with chapter boundaries
    static func detect(
        text: String,
        fallbackStrategy: FallbackStrategy
    ) -> ChapterDetectionResult {
        let chapters = findChapterBoundaries(text: text)

        // No chapters detected
        if chapters.isEmpty {
            return ChapterDetectionResult(
                chapters: [],
                event: SectionDetectionEvent(
                    strategy: .treatAsMonolith,
                    sectionsDetected: 0,
                    fallbackTriggered: true,
                    reason: "No chapter markers detected",
                    timestamp: Date()
                )
            )
        }

        // Too many chapters - merge
        var mergedChapters = chapters
        if chapters.count >= maxChaptersBeforeMerge {
            mergedChapters = mergeAdjacentSmallChapters(chapters: chapters)
        }

        let fallbackTriggered = chapters.isEmpty || chapters.count >= maxChaptersBeforeMerge

        return ChapterDetectionResult(
            chapters: mergedChapters,
            event: SectionDetectionEvent(
                strategy: fallbackTriggered ? fallbackStrategy : .inferSections,
                sectionsDetected: mergedChapters.count,
                fallbackTriggered: fallbackTriggered,
                reason: fallbackTriggered ? "Chapter count adjusted (\(chapters.count) -> \(mergedChapters.count))" : nil,
                timestamp: Date()
            )
        )
    }

    // MARK: - Chapter Boundary Detection

    private static func findChapterBoundaries(text: String) -> [ChapterBoundary] {
        var boundaries: [ChapterBoundary] = []
        let lines = text.components(separatedBy: .newlines)

        let chapterPatterns = [
            "^chapter\\s+\\d+",
            "^part\\s+\\d+",
            "^section\\s+\\d+",
            "^\\d+\\.\\s+[A-Z]",  // Numbered sections like "1. Introduction"
            "^[IVXLC]+\\.\\s+"    // Roman numeral sections
        ]

        var currentPosition = 0
        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces).lowercased()

            for pattern in chapterPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   regex.firstMatch(in: trimmedLine, options: [], range: NSRange(trimmedLine.startIndex..., in: trimmedLine)) != nil {
                    boundaries.append(ChapterBoundary(
                        title: line.trimmingCharacters(in: .whitespaces),
                        lineIndex: index,
                        characterPosition: currentPosition
                    ))
                    break
                }
            }

            currentPosition += line.count + 1  // +1 for newline
        }

        return boundaries
    }

    // MARK: - Chapter Merging

    private static func mergeAdjacentSmallChapters(chapters: [ChapterBoundary]) -> [ChapterBoundary] {
        guard chapters.count >= maxChaptersBeforeMerge else { return chapters }

        var merged = chapters

        // Calculate average chapter size
        let totalSize = chapters.last?.characterPosition ?? 0
        let averageSize = totalSize / chapters.count

        // Merge chapters that are less than 50% of average
        let threshold = averageSize / 2
        var i = 0

        while merged.count >= maxChaptersBeforeMerge && i < merged.count - 1 {
            let currentSize: Int
            if i + 1 < merged.count {
                currentSize = merged[i + 1].characterPosition - merged[i].characterPosition
            } else {
                currentSize = totalSize - merged[i].characterPosition
            }

            if currentSize < threshold {
                // Merge with next chapter
                merged.remove(at: i + 1)
            } else {
                i += 1
            }
        }

        return merged
    }
}

// MARK: - Chapter Boundary

/// Represents a detected chapter boundary.
struct ChapterBoundary: Codable, Hashable {
    /// Title of the chapter
    let title: String

    /// Line index in source document (0-based)
    let lineIndex: Int

    /// Character position in source document
    let characterPosition: Int
}

// MARK: - Chapter Detection Result

/// Result of chapter detection.
struct ChapterDetectionResult: Codable {
    /// Detected chapter boundaries
    let chapters: [ChapterBoundary]

    /// Section detection event for observability
    let event: SectionDetectionEvent

    /// Number of chapters detected
    var chapterCount: Int {
        chapters.count
    }

    /// Whether detection fell back to monolith treatment
    var isMonolith: Bool {
        chapters.isEmpty
    }
}
