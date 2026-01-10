//
//  SummaryGovernorEngine.swift
//  InsightAtlas
//
//  Budget calculation and enforcement engine for Summary Type Governors v1.0.
//
//  This engine implements all budget calculations and enforcement logic.
//  It is deterministic: identical input + governor = identical output.
//
//  Reference: InsightAtlas/Documentation/GOVERNANCE_LOCKS.md
//

import Foundation

// MARK: - Summary Governor Engine

/// Engine for calculating and enforcing summary type governor constraints.
///
/// ## Determinism Guarantee
///
/// This engine is fully deterministic:
/// - No randomness
/// - No timestamp-based logic (timestamps are for logging only)
/// - Identical input + governor = identical output
///
/// ## Streaming Support
///
/// The engine supports streaming generation by persisting `GovernorState`
/// across chunks. Call `processChunk(_:state:)` for each streaming chunk.
struct SummaryGovernorEngine {

    // MARK: - Constants

    /// Words per minute for audio narration calculation
    static let wordsPerMinute: Float = 150.0

    /// Maximum chapters before merge is required
    static let maxChaptersBeforeMerge: Int = 50

    /// Minimum words per chapter after overflow adjustment
    static let minimumAdjustedChapterWords: Int = 100

    // MARK: - Properties

    /// The governor configuration
    let governor: SummaryTypeGovernor

    // MARK: - Initialization

    init(governor: SummaryTypeGovernor) {
        self.governor = governor
    }

    // MARK: - Budget Calculation

    /// Calculates the total word budget for a source.
    ///
    /// Formula:
    /// 1. If sourceWordCount < minSourceLengthForScaling: use baseWordCount
    /// 2. Otherwise: baseWordCount + min(sourceWordCount * scalingFactor, maxScaledAddition)
    /// 3. Cap at min(result, maxWordCeiling, sourceWordCount * 0.80)
    ///
    /// - Parameter sourceWordCount: Word count of source after removing front/back matter
    /// - Returns: Total word budget for the summary
    func calculateTotalBudget(sourceWordCount: Int) -> Int {
        let scaledAddition: Int
        if sourceWordCount >= governor.minSourceLengthForScaling {
            let rawScaled = Int(Float(sourceWordCount) * governor.sourceScalingFactor)
            scaledAddition = min(rawScaled, governor.maxScaledAddition)
        } else {
            scaledAddition = 0
        }

        let basePlusScaled = governor.baseWordCount + scaledAddition
        let shortSourceCap = Int(Float(sourceWordCount) * 0.80)
        let minimumBudget = governor.baseWordCount
        let cappedBySource = max(shortSourceCap, minimumBudget)

        return min(basePlusScaled, governor.maxWordCeiling, cappedBySource)
    }

    /// Calculates the effective budget including visual equivalents.
    ///
    /// - Parameters:
    ///   - wordCount: Current word count
    ///   - visualCount: Current visual count
    /// - Returns: Effective budget consumption
    func calculateEffectiveBudget(wordCount: Int, visualCount: Int) -> Int {
        wordCount + (visualCount * governor.visualBudget.wordsPerVisualEquivalent)
    }

    /// Calculates audio duration in minutes.
    ///
    /// - Parameter wordCount: Word count to convert
    /// - Returns: Audio duration in minutes
    func calculateAudioMinutes(wordCount: Int) -> Float {
        Float(wordCount) / Self.wordsPerMinute
    }

    /// Checks if audio duration is within tolerance.
    ///
    /// Tolerance: 10% above maxAudioMinutes
    ///
    /// - Parameter wordCount: Word count to check
    /// - Returns: True if within tolerance
    func isAudioDurationValid(wordCount: Int) -> Bool {
        let minutes = calculateAudioMinutes(wordCount: wordCount)
        let maxWithTolerance = Float(governor.maxAudioMinutes) * 1.10
        return minutes <= maxWithTolerance
    }

    // MARK: - Section Budget Calculation

    /// Calculates word budgets for each section type.
    ///
    /// - Parameter totalBudget: Total word budget
    /// - Returns: Tuple of (intro, chapterPool, conclusion) word counts
    func calculateSectionBudgets(totalBudget: Int) -> (intro: Int, chapterPool: Int, conclusion: Int) {
        let intro = Int(Float(totalBudget) * governor.sectionBudget.introPercent)
        let chapterPool = Int(Float(totalBudget) * governor.sectionBudget.chapterPoolPercent)
        let conclusion = Int(Float(totalBudget) * governor.sectionBudget.conclusionPercent)
        return (intro, chapterPool, conclusion)
    }

    /// Calculates per-chapter budget with overflow protection.
    ///
    /// If minPerChapter * chapterCount > chapterPoolWords:
    /// - Adjust min to chapterPoolWords / chapterCount
    /// - If adjustedMin < 100: trigger fallback to treatAsMonolith
    ///
    /// - Parameters:
    ///   - chapterCount: Number of chapters detected
    ///   - chapterPoolWords: Total words available for chapters
    /// - Returns: Result with per-chapter budget or fallback indicator
    func calculateChapterBudget(
        chapterCount: Int,
        chapterPoolWords: Int
    ) -> ChapterBudgetResult {
        guard chapterCount > 0 else {
            return .fallback(reason: "No chapters detected")
        }

        let minTotal = governor.sectionBudget.minPerChapter * chapterCount

        if minTotal > chapterPoolWords {
            let adjustedMin = chapterPoolWords / chapterCount
            if adjustedMin < Self.minimumAdjustedChapterWords {
                return .fallback(reason: "Adjusted minimum (\(adjustedMin)) below threshold (\(Self.minimumAdjustedChapterWords))")
            }
            return .adjusted(
                minPerChapter: adjustedMin,
                maxPerChapter: min(governor.sectionBudget.maxPerChapter, chapterPoolWords / chapterCount + 50)
            )
        }

        return .normal(
            minPerChapter: governor.sectionBudget.minPerChapter,
            maxPerChapter: governor.sectionBudget.maxPerChapter
        )
    }

    // MARK: - Budget Utilization

    /// Calculates current budget utilization.
    ///
    /// - Parameters:
    ///   - state: Current governor state
    ///   - totalBudget: Total word budget
    /// - Returns: Utilization ratio (0.0 to 1.0+)
    func calculateUtilization(state: GovernorState, totalBudget: Int) -> Float {
        let effective = calculateEffectiveBudget(
            wordCount: state.currentWordCount,
            visualCount: state.visualCount
        )
        return Float(effective) / Float(totalBudget)
    }

    /// Determines if cut policy should be activated.
    ///
    /// - Parameters:
    ///   - state: Current governor state
    ///   - totalBudget: Total word budget
    /// - Returns: True if utilization >= triggerThreshold
    func shouldActivateCutPolicy(state: GovernorState, totalBudget: Int) -> Bool {
        let utilization = calculateUtilization(state: state, totalBudget: totalBudget)
        return utilization >= governor.cutPolicy.triggerThreshold
    }

    /// Determines if hard limit is exceeded.
    ///
    /// - Parameters:
    ///   - state: Current governor state
    ///   - totalBudget: Total word budget
    /// - Returns: True if utilization > hardLimitThreshold (1.0)
    func isHardLimitExceeded(state: GovernorState, totalBudget: Int) -> Bool {
        let utilization = calculateUtilization(state: state, totalBudget: totalBudget)
        return utilization > governor.cutPolicy.hardLimitThreshold
    }

    // MARK: - Cut Policy Execution

    /// Determines the next expansion type to cut based on cut order.
    ///
    /// - Parameter state: Current governor state
    /// - Returns: Next expansion type to cut, or nil if all cuttable types exhausted
    func nextExpansionToCut(state: GovernorState) -> ExpansionType? {
        for expansionType in governor.cutPolicy.cutOrder {
            let usageCount = state.expansionUsageCounts[expansionType] ?? 0
            if usageCount > 0 {
                return expansionType
            }
        }
        return nil
    }

    /// Processes a cut decision for an expansion.
    ///
    /// - Parameters:
    ///   - expansionType: Type of expansion to cut
    ///   - originalWordCount: Word count of content being cut
    ///   - sectionIndex: Section where cut occurs
    ///   - chunkIndex: Chunk within section
    ///   - state: Current governor state
    ///   - totalBudget: Total word budget
    /// - Returns: Cut event describing the action taken
    func processCut(
        expansionType: ExpansionType,
        originalWordCount: Int,
        sectionIndex: Int,
        chunkIndex: Int,
        state: GovernorState,
        totalBudget: Int
    ) -> CutEvent {
        let replacementWordCount: Int
        switch governor.cutPolicy.replacementStrategy {
        case .synthesize:
            // Synthesis paragraphs are 50-100 words, use 75 as average
            replacementWordCount = 75
        case .omit:
            replacementWordCount = 0
        }

        return CutEvent(
            expansionType: expansionType,
            originalWordCount: originalWordCount,
            replacementWordCount: replacementWordCount,
            reason: "Budget utilization exceeded trigger threshold",
            sectionIndex: sectionIndex,
            chunkIndex: chunkIndex,
            budgetUtilization: calculateUtilization(state: state, totalBudget: totalBudget),
            timestamp: Date(),
            wasConsolidated: false
        )
    }

    // MARK: - Validation

    /// Validates the current state against all governor constraints.
    ///
    /// - Parameters:
    ///   - state: Current governor state
    ///   - sourceWordCount: Source document word count
    ///   - cutEvents: Cut events that occurred during generation
    ///   - sectionDetectionEvent: Section detection event
    /// - Returns: Validation result with any violations
    func validate(
        state: GovernorState,
        sourceWordCount: Int,
        cutEvents: [CutEvent],
        sectionDetectionEvent: SectionDetectionEvent?
    ) -> GovernorValidationResult {
        let totalBudget = calculateTotalBudget(sourceWordCount: sourceWordCount)
        var violations: [BudgetViolation] = []
        var warnings: [String] = []

        // Check total word count
        let effectiveBudget = calculateEffectiveBudget(
            wordCount: state.currentWordCount,
            visualCount: state.visualCount
        )
        if effectiveBudget > totalBudget {
            violations.append(.totalWordCountExceeded(
                current: effectiveBudget,
                limit: totalBudget
            ))
        }

        // Check visual count
        if state.visualCount > governor.visualBudget.maxVisuals {
            violations.append(.visualCountExceeded(
                current: state.visualCount,
                limit: governor.visualBudget.maxVisuals
            ))
        }

        // Check audio duration
        let audioMinutes = calculateAudioMinutes(wordCount: state.currentWordCount)
        if !isAudioDurationValid(wordCount: state.currentWordCount) {
            violations.append(.audioMinutesExceeded(
                current: audioMinutes,
                limit: governor.maxAudioMinutes
            ))
        }

        // Check synthesis limits per section
        for (sectionIndex, count) in state.synthesisCountPerSection {
            if count > governor.maxSynthesisPerSection {
                violations.append(.synthesisLimitExceeded(
                    section: sectionIndex,
                    current: count,
                    limit: governor.maxSynthesisPerSection
                ))
            }
        }

        // Add warnings for near-limit conditions
        let utilization = calculateUtilization(state: state, totalBudget: totalBudget)
        if utilization > 0.95 && utilization <= 1.0 {
            warnings.append("Budget utilization at \(Int(utilization * 100))% - near limit")
        }

        return GovernorValidationResult(
            isValid: violations.isEmpty,
            violations: violations,
            warnings: warnings,
            budgetUtilization: utilization,
            effectiveBudget: totalBudget,
            cutEvents: cutEvents,
            sectionDetectionEvent: sectionDetectionEvent
        )
    }

    // MARK: - Enforcement

    /// Enforces governor constraints, potentially halting generation.
    ///
    /// When `strictEnforcement` is true:
    /// - Generation halts on violation
    /// - Output is discarded
    /// - Error is thrown
    ///
    /// When `strictEnforcement` is false:
    /// - Warning is logged
    /// - Validation flag is attached
    /// - Output is returned
    ///
    /// - Parameters:
    ///   - validationResult: Result of validation
    /// - Returns: Enforcement action to take
    func enforce(validationResult: GovernorValidationResult) -> EnforcementAction {
        if validationResult.isValid {
            return .accept
        }

        if governor.strictEnforcement {
            return .halt(violations: validationResult.violations)
        } else {
            return .acceptWithFlag(
                violations: validationResult.violations,
                warnings: validationResult.warnings
            )
        }
    }
}

// MARK: - Chapter Budget Result

/// Result of chapter budget calculation.
enum ChapterBudgetResult {
    /// Normal budget within constraints
    case normal(minPerChapter: Int, maxPerChapter: Int)

    /// Adjusted budget due to overflow
    case adjusted(minPerChapter: Int, maxPerChapter: Int)

    /// Fallback to monolith treatment
    case fallback(reason: String)

    var minPerChapter: Int? {
        switch self {
        case .normal(let min, _), .adjusted(let min, _):
            return min
        case .fallback:
            return nil
        }
    }

    var maxPerChapter: Int? {
        switch self {
        case .normal(_, let max), .adjusted(_, let max):
            return max
        case .fallback:
            return nil
        }
    }

    var isFallback: Bool {
        if case .fallback = self {
            return true
        }
        return false
    }
}

// MARK: - Enforcement Action

/// Action to take based on enforcement result.
enum EnforcementAction {
    /// Accept the content
    case accept

    /// Halt generation and discard output
    case halt(violations: [BudgetViolation])

    /// Accept with validation flag attached
    case acceptWithFlag(violations: [BudgetViolation], warnings: [String])
}

// MARK: - Streaming Support

extension SummaryGovernorEngine {

    /// Processes a streaming chunk and updates state.
    ///
    /// - Parameters:
    ///   - chunk: The content chunk to process
    ///   - state: Current governor state (mutated in place)
    ///   - totalBudget: Total word budget
    /// - Returns: Processing result with any required actions
    mutating func processChunk(
        _ chunk: ContentChunk,
        state: inout GovernorState,
        totalBudget: Int
    ) -> ChunkProcessingResult {
        // Update word count
        state.currentWordCount += chunk.wordCount

        // Update section if changed
        if chunk.sectionIndex != state.currentSectionIndex {
            state.currentSectionIndex = chunk.sectionIndex
            while state.sectionWordCounts.count <= chunk.sectionIndex {
                state.sectionWordCounts.append(0)
            }
        }
        if state.sectionWordCounts.count > chunk.sectionIndex {
            state.sectionWordCounts[chunk.sectionIndex] += chunk.wordCount
        }

        // Update expansion usage
        if let expansionType = chunk.expansionType {
            state.expansionUsageCounts[expansionType, default: 0] += 1
        }

        // Update visual count
        state.visualCount += chunk.visualCount

        // Check if cut policy should activate
        var cutEvents: [CutEvent] = []
        if !state.cutPolicyActivated && shouldActivateCutPolicy(state: state, totalBudget: totalBudget) {
            state.cutPolicyActivated = true
        }

        // If cut policy is active, evaluate for cuts
        if state.cutPolicyActivated {
            if let expansionType = chunk.expansionType,
               !expansionType.isProtected,
               governor.cutPolicy.cutOrder.contains(expansionType) {
                let cutEvent = processCut(
                    expansionType: expansionType,
                    originalWordCount: chunk.wordCount,
                    sectionIndex: chunk.sectionIndex,
                    chunkIndex: chunk.chunkIndex,
                    state: state,
                    totalBudget: totalBudget
                )
                cutEvents.append(cutEvent)
            }
        }

        // Check for hard limit violation
        if isHardLimitExceeded(state: state, totalBudget: totalBudget) {
            return .hardLimitExceeded(
                utilization: calculateUtilization(state: state, totalBudget: totalBudget)
            )
        }

        return .continue(cutEvents: cutEvents)
    }
}

// MARK: - Content Chunk

/// A chunk of content being processed during streaming generation.
struct ContentChunk: Codable {
    /// Word count of this chunk
    let wordCount: Int

    /// Section index (0-based)
    let sectionIndex: Int

    /// Chunk index within section
    let chunkIndex: Int

    /// Expansion type of this chunk, if applicable
    let expansionType: ExpansionType?

    /// Number of visuals in this chunk
    let visualCount: Int

    /// Parent expansion ID for visual linking
    let parentExpansionId: String?
}

// MARK: - Chunk Processing Result

/// Result of processing a streaming chunk.
enum ChunkProcessingResult {
    /// Continue processing
    case `continue`(cutEvents: [CutEvent])

    /// Hard limit exceeded - must stop
    case hardLimitExceeded(utilization: Float)

    var shouldStop: Bool {
        if case .hardLimitExceeded = self {
            return true
        }
        return false
    }
}

// MARK: - Ambiguity Logging

/// Logs ambiguity encountered during processing.
///
/// Per spec: "If behavior is unclear:
/// 1. Log ambiguity with context
/// 2. Apply most conservative interpretation (less content)
/// 3. Flag output for review
/// 4. Continue generation unless strictEnforcement violated"
struct AmbiguityLog: Codable {
    /// Description of the ambiguity
    let description: String

    /// Context in which ambiguity occurred
    let context: String

    /// Conservative action taken
    let actionTaken: String

    /// Timestamp for logging
    let timestamp: Date

    /// Creates an ambiguity log entry.
    static func log(
        description: String,
        context: String,
        actionTaken: String
    ) -> AmbiguityLog {
        AmbiguityLog(
            description: description,
            context: context,
            actionTaken: actionTaken,
            timestamp: Date()
        )
    }
}
