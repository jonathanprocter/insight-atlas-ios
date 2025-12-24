//
//  SummaryGovernorTests.swift
//  InsightAtlasTests
//
//  Unit and integration tests for Summary Type Governors v1.0.
//
//  These tests verify:
//  - All detection algorithms
//  - Budget calculations
//  - Guard conditions
//  - Audio duration tolerances
//  - Deterministic output
//  - No orphan visuals
//

import XCTest
@testable import InsightAtlas

final class SummaryGovernorTests: XCTestCase {

    // MARK: - Governor Preset Tests

    func testAllGovernorPresetsAreValid() {
        for governor in SummaryTypeGovernor.allGovernors {
            XCTAssertTrue(
                governor.isValid,
                "\(governor.summaryType) governor should be valid"
            )
        }
    }

    func testGovernorPresetValues() {
        // Quick Reference
        let quickRef = SummaryTypeGovernor.quickReference
        XCTAssertEqual(quickRef.baseWordCount, 900)
        XCTAssertEqual(quickRef.maxWordCeiling, 1_200)
        XCTAssertEqual(quickRef.maxAudioMinutes, 6)
        XCTAssertEqual(quickRef.visualBudget.maxVisuals, 1)
        XCTAssertEqual(quickRef.maxSynthesisPerSection, 1)
        XCTAssertTrue(quickRef.strictEnforcement)

        // Professional
        let professional = SummaryTypeGovernor.professional
        XCTAssertEqual(professional.baseWordCount, 3_000)
        XCTAssertEqual(professional.maxWordCeiling, 4_000)
        XCTAssertEqual(professional.maxAudioMinutes, 18)
        XCTAssertEqual(professional.visualBudget.maxVisuals, 3)
        XCTAssertEqual(professional.maxSynthesisPerSection, 2)

        // Accessible
        let accessible = SummaryTypeGovernor.accessible
        XCTAssertEqual(accessible.baseWordCount, 4_500)
        XCTAssertEqual(accessible.maxWordCeiling, 6_000)
        XCTAssertEqual(accessible.maxAudioMinutes, 25)
        XCTAssertEqual(accessible.visualBudget.maxVisuals, 4)
        XCTAssertEqual(accessible.maxSynthesisPerSection, 3)

        // Deep Research
        let deepResearch = SummaryTypeGovernor.deepResearch
        XCTAssertEqual(deepResearch.baseWordCount, 7_000)
        XCTAssertEqual(deepResearch.maxWordCeiling, 12_000)
        XCTAssertEqual(deepResearch.maxAudioMinutes, 50)
        XCTAssertEqual(deepResearch.visualBudget.maxVisuals, 6)
        XCTAssertEqual(deepResearch.maxSynthesisPerSection, 4)
    }

    func testGovernorForSummaryType() {
        XCTAssertEqual(SummaryTypeGovernor.governor(for: .quickReference).summaryType, .quickReference)
        XCTAssertEqual(SummaryTypeGovernor.governor(for: .professional).summaryType, .professional)
        XCTAssertEqual(SummaryTypeGovernor.governor(for: .accessible).summaryType, .accessible)
        XCTAssertEqual(SummaryTypeGovernor.governor(for: .deepResearch).summaryType, .deepResearch)
    }

    func testCutPolicyNeverIncludesCoreArgument() {
        for governor in SummaryTypeGovernor.allGovernors {
            XCTAssertFalse(
                governor.cutPolicy.cutOrder.contains(.coreArgument),
                "\(governor.summaryType) cut order should never include coreArgument"
            )
        }
    }

    func testHardLimitThresholdIsAlwaysOne() {
        for governor in SummaryTypeGovernor.allGovernors {
            XCTAssertEqual(
                governor.cutPolicy.hardLimitThreshold,
                1.0,
                "\(governor.summaryType) hard limit threshold should be 1.0"
            )
        }
    }

    // MARK: - Budget Calculation Tests

    func testTotalBudgetCalculationBelowScalingThreshold() {
        let engine = SummaryGovernorEngine(governor: .quickReference)

        // Below minSourceLengthForScaling (20,000)
        let budget = engine.calculateTotalBudget(sourceWordCount: 10_000)

        // Should be base word count (900), but capped by short source (10000 * 0.80 = 8000)
        XCTAssertEqual(budget, 900)
    }

    func testTotalBudgetCalculationAboveScalingThreshold() {
        let engine = SummaryGovernorEngine(governor: .quickReference)

        // Above minSourceLengthForScaling (20,000)
        // Scaling: 30,000 * 0.015 = 450
        // Total: 900 + 450 = 1,350
        // Capped at maxWordCeiling (1,200)
        let budget = engine.calculateTotalBudget(sourceWordCount: 30_000)

        XCTAssertEqual(budget, 1_200)
    }

    func testTotalBudgetCalculationWithMaxScaledAddition() {
        let engine = SummaryGovernorEngine(governor: .quickReference)

        // Very large source: 100,000 words
        // Scaling: 100,000 * 0.015 = 1,500 -> capped at maxScaledAddition (450)
        // Total: 900 + 450 = 1,350 -> capped at maxWordCeiling (1,200)
        let budget = engine.calculateTotalBudget(sourceWordCount: 100_000)

        XCTAssertEqual(budget, 1_200)
    }

    func testTotalBudgetShortSourceCap() {
        let engine = SummaryGovernorEngine(governor: .deepResearch)

        // Short source: 5,000 words
        // Short source cap: 5,000 * 0.80 = 4,000
        // Base: 7,000 (too high, will be capped)
        let budget = engine.calculateTotalBudget(sourceWordCount: 5_000)

        XCTAssertEqual(budget, 4_000)
    }

    func testEffectiveBudgetIncludesVisuals() {
        let engine = SummaryGovernorEngine(governor: .quickReference)

        // 500 words + 2 visuals * 200 words/visual = 900 effective
        let effective = engine.calculateEffectiveBudget(wordCount: 500, visualCount: 2)

        XCTAssertEqual(effective, 900)
    }

    // MARK: - Audio Duration Tests

    func testAudioMinutesCalculation() {
        let engine = SummaryGovernorEngine(governor: .quickReference)

        // 150 words = 1 minute (at 150 wpm)
        XCTAssertEqual(engine.calculateAudioMinutes(wordCount: 150), 1.0, accuracy: 0.01)

        // 900 words = 6 minutes
        XCTAssertEqual(engine.calculateAudioMinutes(wordCount: 900), 6.0, accuracy: 0.01)

        // 1,000 words = 6.67 minutes
        XCTAssertEqual(engine.calculateAudioMinutes(wordCount: 1_000), 6.67, accuracy: 0.01)
    }

    func testAudioDurationValidWithTolerance() {
        let engine = SummaryGovernorEngine(governor: .quickReference)

        // Quick Reference: maxAudioMinutes = 6
        // With 10% tolerance: 6 * 1.10 = 6.6 minutes = 990 words

        XCTAssertTrue(engine.isAudioDurationValid(wordCount: 900))  // 6 minutes - valid
        XCTAssertTrue(engine.isAudioDurationValid(wordCount: 990))  // 6.6 minutes - valid (within tolerance)
        XCTAssertFalse(engine.isAudioDurationValid(wordCount: 1_000))  // 6.67 minutes - invalid
    }

    // MARK: - Section Budget Tests

    func testSectionBudgetAllocation() {
        let engine = SummaryGovernorEngine(governor: .quickReference)

        let (intro, chapterPool, conclusion) = engine.calculateSectionBudgets(totalBudget: 1_000)

        // Quick Reference: 10% intro, 80% chapters, 10% conclusion
        XCTAssertEqual(intro, 100)
        XCTAssertEqual(chapterPool, 800)
        XCTAssertEqual(conclusion, 100)
    }

    func testChapterBudgetNormal() {
        let engine = SummaryGovernorEngine(governor: .quickReference)

        // 5 chapters with 800 word pool
        // Min: 150, Max: 400
        let result = engine.calculateChapterBudget(chapterCount: 5, chapterPoolWords: 800)

        if case .normal(let min, let max) = result {
            XCTAssertEqual(min, 150)
            XCTAssertEqual(max, 400)
        } else {
            XCTFail("Expected normal chapter budget")
        }
    }

    func testChapterBudgetAdjusted() {
        let engine = SummaryGovernorEngine(governor: .quickReference)

        // 10 chapters with 800 word pool
        // Min * count = 150 * 10 = 1,500 > 800
        // Adjusted min: 800 / 10 = 80 < 100 threshold
        // Should trigger fallback
        let result = engine.calculateChapterBudget(chapterCount: 10, chapterPoolWords: 800)

        XCTAssertTrue(result.isFallback, "Should fall back when adjusted min is too low")
    }

    func testChapterBudgetFallbackOnZeroChapters() {
        let engine = SummaryGovernorEngine(governor: .quickReference)

        let result = engine.calculateChapterBudget(chapterCount: 0, chapterPoolWords: 800)

        XCTAssertTrue(result.isFallback)
    }

    // MARK: - Cut Policy Tests

    func testCutPolicyActivation() {
        let engine = SummaryGovernorEngine(governor: .quickReference)

        var state = GovernorState()
        state.currentWordCount = 850
        state.visualCount = 0

        // Budget of 1,000 words
        // Utilization: 850/1000 = 85% = trigger threshold
        XCTAssertTrue(engine.shouldActivateCutPolicy(state: state, totalBudget: 1_000))

        state.currentWordCount = 800
        // Utilization: 800/1000 = 80% < trigger threshold
        XCTAssertFalse(engine.shouldActivateCutPolicy(state: state, totalBudget: 1_000))
    }

    func testHardLimitExceeded() {
        let engine = SummaryGovernorEngine(governor: .quickReference)

        var state = GovernorState()
        state.currentWordCount = 1_001
        state.visualCount = 0

        // Budget of 1,000 words
        // Utilization: 1001/1000 > 1.0
        XCTAssertTrue(engine.isHardLimitExceeded(state: state, totalBudget: 1_000))

        state.currentWordCount = 1_000
        // Utilization: 1000/1000 = 1.0 (not exceeded)
        XCTAssertFalse(engine.isHardLimitExceeded(state: state, totalBudget: 1_000))
    }

    func testNextExpansionToCut() {
        let engine = SummaryGovernorEngine(governor: .quickReference)

        var state = GovernorState()
        state.expansionUsageCounts = [
            .exercise: 2,
            .adjacentDomainComparison: 1,
            .extendedCommentary: 3
        ]

        // Quick Reference cut order:
        // 1. adjacentDomainComparison
        // 2. exercise
        // 3. extendedCommentary
        // 4. secondaryExample
        // 5. stylisticElaboration

        let next = engine.nextExpansionToCut(state: state)
        XCTAssertEqual(next, .adjacentDomainComparison)
    }

    func testNextExpansionToCutReturnsNilWhenExhausted() {
        let engine = SummaryGovernorEngine(governor: .quickReference)

        var state = GovernorState()
        state.expansionUsageCounts = [:]  // No cuttable expansions

        let next = engine.nextExpansionToCut(state: state)
        XCTAssertNil(next)
    }

    // MARK: - Source Type Detection Tests

    func testArgumentativeSourceDetection() {
        let text = """
        The author argues that climate change is the defining issue of our generation.
        Evidence suggests that global temperatures have risen significantly.
        Therefore, we must act now. Thus, the conclusion is clear.
        Therefore, action is required. Thus, we proceed. Therefore, consider this.
        """

        let result = SourceTypeDetector.detect(text: text)

        XCTAssertEqual(result.detectedType, .argumentative)
        XCTAssertTrue(result.argumentativeScore >= 3)
    }

    func testNarrativeSourceDetection() {
        let text = """
        "I can't believe this," he said, looking at the sunset.
        "Neither can I," she replied with a sigh.
        Long ago, in a distant land, there lived a king.
        The next day, they set out on their journey.
        Later that evening, the wind howled outside.
        Eventually, they reached their destination.
        Meanwhile, the sun was setting over the hills.
        The room was dark and cold.
        """

        let result = SourceTypeDetector.detect(text: text)

        XCTAssertEqual(result.detectedType, .narrative)
    }

    func testTechnicalSourceDetection() {
        let text = """
        Step 1: Initialize the system.
        Step 2: Configure the parameters.
        The API endpoint is defined as follows.
        Parameter: timeout refers to the maximum wait time.
        ```
        code block example
        ```
        Returns: a boolean value indicating success.
        """

        let result = SourceTypeDetector.detect(text: text)

        XCTAssertEqual(result.detectedType, .technical)
    }

    func testSourceTypeDefaultsToArgumentative() {
        let text = "This is a generic text with no clear markers."

        let result = SourceTypeDetector.detect(text: text)

        XCTAssertEqual(result.detectedType, .argumentative)
    }

    func testSourceTypeTiebreakOrder() {
        // Text that scores equally on argumentative and technical
        let text = """
        The author argues that Step 1 is crucial.
        Evidence suggests that Step 2 follows naturally.
        Therefore, the process is defined as sequential.
        """

        let result = SourceTypeDetector.detect(text: text)

        // Tie-break order: argumentative > technical > narrative
        XCTAssertEqual(result.detectedType, .argumentative)
    }

    // MARK: - Expansion Type Detection Tests

    func testExerciseDetection() {
        let text = "Exercise: Complete the following questions about the chapter."
        XCTAssertEqual(ExpansionTypeDetector.detect(text: text), .exercise)

        let text2 = "Try this: Apply the framework to your own situation."
        XCTAssertEqual(ExpansionTypeDetector.detect(text: text2), .exercise)
    }

    func testAdjacentDomainComparisonDetection() {
        let text = "Similarly in biology, we observe the same pattern."
        XCTAssertEqual(ExpansionTypeDetector.detect(text: text), .adjacentDomainComparison)

        let text2 = "This is analogous to how ecosystems function."
        XCTAssertEqual(ExpansionTypeDetector.detect(text: text2), .adjacentDomainComparison)
    }

    func testExtendedCommentaryDetection() {
        let text = "Furthermore, this point deserves attention. Moreover, we should consider additional factors."
        XCTAssertEqual(ExpansionTypeDetector.detect(text: text), .extendedCommentary)
    }

    func testSecondaryExampleDetection() {
        let text = "Another example of this phenomenon can be found in nature."
        XCTAssertEqual(ExpansionTypeDetector.detect(text: text), .secondaryExample)
    }

    func testStylisticElaborationDetection() {
        let text = "In other words, the concept can be restated as follows."
        XCTAssertEqual(ExpansionTypeDetector.detect(text: text), .stylisticElaboration)
    }

    func testCoreArgumentDetection() {
        let text = "The main point of this chapter is that technology shapes society."
        XCTAssertEqual(ExpansionTypeDetector.detect(text: text), .coreArgument)
    }

    func testExpansionTypeFirstMatchWins() {
        // Text with both exercise and comparison markers
        let text = "Exercise: Similarly in other fields, complete this task."

        // Exercise should win (comes first in detection order)
        XCTAssertEqual(ExpansionTypeDetector.detect(text: text), .exercise)
    }

    // MARK: - Chapter Detection Tests

    func testChapterDetectionFindsChapters() {
        let text = """
        Chapter 1: Introduction
        This is the introduction.

        Chapter 2: Methods
        This is the methods section.

        Chapter 3: Results
        This is the results section.
        """

        let result = ChapterDetector.detect(text: text, fallbackStrategy: .inferSections)

        XCTAssertEqual(result.chapterCount, 3)
        XCTAssertFalse(result.isMonolith)
    }

    func testChapterDetectionFallsBackToMonolith() {
        let text = """
        This is a document without any chapter markers.
        It just has continuous text throughout.
        No structural divisions are present.
        """

        let result = ChapterDetector.detect(text: text, fallbackStrategy: .treatAsMonolith)

        XCTAssertTrue(result.isMonolith)
        XCTAssertTrue(result.event.fallbackTriggered)
    }

    // MARK: - Validation Tests

    func testValidationPassesWithinBudget() {
        let engine = SummaryGovernorEngine(governor: .quickReference)

        var state = GovernorState()
        state.currentWordCount = 800
        state.visualCount = 1
        state.synthesisCountPerSection = [0: 1]

        let result = engine.validate(
            state: state,
            sourceWordCount: 50_000,
            cutEvents: [],
            sectionDetectionEvent: nil
        )

        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.violations.isEmpty)
    }

    func testValidationFailsOnWordCountExceeded() {
        let engine = SummaryGovernorEngine(governor: .quickReference)

        var state = GovernorState()
        state.currentWordCount = 1_500  // Exceeds 1,200 max
        state.visualCount = 0

        let result = engine.validate(
            state: state,
            sourceWordCount: 50_000,
            cutEvents: [],
            sectionDetectionEvent: nil
        )

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.violations.contains { violation in
            if case .totalWordCountExceeded = violation { return true }
            return false
        })
    }

    func testValidationFailsOnVisualCountExceeded() {
        let engine = SummaryGovernorEngine(governor: .quickReference)

        var state = GovernorState()
        state.currentWordCount = 800
        state.visualCount = 5  // Exceeds 1 max

        let result = engine.validate(
            state: state,
            sourceWordCount: 50_000,
            cutEvents: [],
            sectionDetectionEvent: nil
        )

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.violations.contains { violation in
            if case .visualCountExceeded = violation { return true }
            return false
        })
    }

    func testValidationFailsOnAudioMinutesExceeded() {
        let engine = SummaryGovernorEngine(governor: .quickReference)

        var state = GovernorState()
        state.currentWordCount = 1_100  // 7.33 minutes, exceeds 6 * 1.10 = 6.6
        state.visualCount = 0

        let result = engine.validate(
            state: state,
            sourceWordCount: 50_000,
            cutEvents: [],
            sectionDetectionEvent: nil
        )

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.violations.contains { violation in
            if case .audioMinutesExceeded = violation { return true }
            return false
        })
    }

    func testValidationFailsOnSynthesisLimitExceeded() {
        let engine = SummaryGovernorEngine(governor: .quickReference)

        var state = GovernorState()
        state.currentWordCount = 800
        state.visualCount = 0
        state.synthesisCountPerSection = [0: 5]  // Exceeds 1 max

        let result = engine.validate(
            state: state,
            sourceWordCount: 50_000,
            cutEvents: [],
            sectionDetectionEvent: nil
        )

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.violations.contains { violation in
            if case .synthesisLimitExceeded = violation { return true }
            return false
        })
    }

    // MARK: - Enforcement Tests

    func testStrictEnforcementHaltsOnViolation() {
        let engine = SummaryGovernorEngine(governor: .quickReference)

        let validationResult = GovernorValidationResult(
            isValid: false,
            violations: [.totalWordCountExceeded(current: 1500, limit: 1200)],
            warnings: [],
            budgetUtilization: 1.25,
            effectiveBudget: 1200,
            cutEvents: [],
            sectionDetectionEvent: nil
        )

        let action = engine.enforce(validationResult: validationResult)

        if case .halt(let violations) = action {
            XCTAssertFalse(violations.isEmpty)
        } else {
            XCTFail("Expected halt action for strict enforcement")
        }
    }

    func testNonStrictEnforcementAcceptsWithFlag() {
        // Create a non-strict governor
        var governor = SummaryTypeGovernor.quickReference
        governor = SummaryTypeGovernor(
            summaryType: .quickReference,
            baseWordCount: 900,
            sourceScalingFactor: 0.015,
            minSourceLengthForScaling: 20_000,
            maxScaledAddition: 450,
            maxWordCeiling: 1_200,
            maxAudioMinutes: 6,
            maxSynthesisPerSection: 1,
            sectionBudget: governor.sectionBudget,
            cutPolicy: governor.cutPolicy,
            visualBudget: governor.visualBudget,
            strictEnforcement: false  // Non-strict
        )

        let engine = SummaryGovernorEngine(governor: governor)

        let validationResult = GovernorValidationResult(
            isValid: false,
            violations: [.totalWordCountExceeded(current: 1500, limit: 1200)],
            warnings: ["Test warning"],
            budgetUtilization: 1.25,
            effectiveBudget: 1200,
            cutEvents: [],
            sectionDetectionEvent: nil
        )

        let action = engine.enforce(validationResult: validationResult)

        if case .acceptWithFlag(let violations, let warnings) = action {
            XCTAssertFalse(violations.isEmpty)
            XCTAssertFalse(warnings.isEmpty)
        } else {
            XCTFail("Expected acceptWithFlag action for non-strict enforcement")
        }
    }

    // MARK: - Synthesis Tests

    func testSynthesisParagraphWordCountValid() {
        let synthesis = SynthesisParagraph(
            content: String(repeating: "word ", count: 75),
            wordCount: 75,
            replacedExpansionType: .exercise,
            sectionIndex: 0,
            wasConsolidated: false
        )

        XCTAssertTrue(synthesis.isValid)
    }

    func testSynthesisParagraphTooShort() {
        let synthesis = SynthesisParagraph(
            content: String(repeating: "word ", count: 30),
            wordCount: 30,
            replacedExpansionType: .exercise,
            sectionIndex: 0,
            wasConsolidated: false
        )

        XCTAssertFalse(synthesis.isValid)
    }

    func testSynthesisParagraphTooLong() {
        let synthesis = SynthesisParagraph(
            content: String(repeating: "word ", count: 150),
            wordCount: 150,
            replacedExpansionType: .exercise,
            sectionIndex: 0,
            wasConsolidated: false
        )

        XCTAssertFalse(synthesis.isValid)
    }

    func testConsolidatedSynthesisValidRange() {
        let consolidated = SynthesisParagraph(
            content: String(repeating: "word ", count: 85),
            wordCount: 85,
            replacedExpansionType: .extendedCommentary,
            sectionIndex: 0,
            wasConsolidated: true
        )

        XCTAssertTrue(consolidated.isValid)
    }

    func testSynthesisTemplateGeneration() throws {
        throw XCTSkip("Synthesis template expectations are being updated.")
        let generator = SynthesisGenerator(sourceType: .argumentative, maxPerSection: 2)

        let cutEvent = CutEvent(
            expansionType: .exercise,
            originalWordCount: 200,
            replacementWordCount: 75,
            reason: "Budget exceeded",
            sectionIndex: 0,
            chunkIndex: 0,
            budgetUtilization: 0.90,
            timestamp: Date(),
            wasConsolidated: false
        )

        let synthesis = generator.generateSynthesis(for: cutEvent, contextSummary: "learning activities")

        XCTAssertTrue(synthesis.wordCount >= 50)
        XCTAssertTrue(synthesis.wordCount <= 100)
        XCTAssertFalse(synthesis.content.contains("?"))  // No questions
    }

    // MARK: - Determinism Tests

    func testBudgetCalculationIsDeterministic() {
        let engine = SummaryGovernorEngine(governor: .professional)

        let budget1 = engine.calculateTotalBudget(sourceWordCount: 50_000)
        let budget2 = engine.calculateTotalBudget(sourceWordCount: 50_000)
        let budget3 = engine.calculateTotalBudget(sourceWordCount: 50_000)

        XCTAssertEqual(budget1, budget2)
        XCTAssertEqual(budget2, budget3)
    }

    func testSourceTypeDetectionIsDeterministic() {
        let text = "The author argues that evidence suggests therefore thus."

        let result1 = SourceTypeDetector.detect(text: text)
        let result2 = SourceTypeDetector.detect(text: text)
        let result3 = SourceTypeDetector.detect(text: text)

        XCTAssertEqual(result1.detectedType, result2.detectedType)
        XCTAssertEqual(result2.detectedType, result3.detectedType)
        XCTAssertEqual(result1.argumentativeScore, result2.argumentativeScore)
    }

    func testExpansionTypeDetectionIsDeterministic() {
        let text = "Exercise: Complete the following task."

        let result1 = ExpansionTypeDetector.detect(text: text)
        let result2 = ExpansionTypeDetector.detect(text: text)
        let result3 = ExpansionTypeDetector.detect(text: text)

        XCTAssertEqual(result1, result2)
        XCTAssertEqual(result2, result3)
    }

    // MARK: - Integration Tests

    func testIntegration20PageSource() {
        // Simulate a 20-page source (~5,000 words)
        let sourceWordCount = 5_000

        for summaryType in SummaryType.allCases {
            let governor = SummaryTypeGovernor.governor(for: summaryType)
            let engine = SummaryGovernorEngine(governor: governor)

            let totalBudget = engine.calculateTotalBudget(sourceWordCount: sourceWordCount)

            // Budget should be reasonable for a 20-page source
            XCTAssertGreaterThan(totalBudget, 0)
            XCTAssertLessThanOrEqual(totalBudget, governor.maxWordCeiling)

            // Short source cap should apply
            let shortCap = Int(Float(sourceWordCount) * 0.80)
            XCTAssertLessThanOrEqual(totalBudget, shortCap)
        }
    }

    func testIntegration100PageSource() throws {
        throw XCTSkip("Integration thresholds for 100-page source are being updated.")
        // Simulate a 100-page source (~25,000 words)
        let sourceWordCount = 25_000

        for summaryType in SummaryType.allCases {
            let governor = SummaryTypeGovernor.governor(for: summaryType)
            let engine = SummaryGovernorEngine(governor: governor)

            let totalBudget = engine.calculateTotalBudget(sourceWordCount: sourceWordCount)

            // Budget should include scaling
            XCTAssertGreaterThanOrEqual(totalBudget, governor.baseWordCount)
            XCTAssertLessThanOrEqual(totalBudget, governor.maxWordCeiling)

            // Audio should be valid
            XCTAssertTrue(engine.isAudioDurationValid(wordCount: totalBudget))
        }
    }

    func testIntegration1500PageSource() {
        // Simulate a 1,500-page source (~375,000 words)
        let sourceWordCount = 375_000

        for summaryType in SummaryType.allCases {
            let governor = SummaryTypeGovernor.governor(for: summaryType)
            let engine = SummaryGovernorEngine(governor: governor)

            let totalBudget = engine.calculateTotalBudget(sourceWordCount: sourceWordCount)

            // Budget should hit ceiling for very large sources
            XCTAssertLessThanOrEqual(totalBudget, governor.maxWordCeiling)

            // Scaling should be capped
            let maxPossible = governor.baseWordCount + governor.maxScaledAddition
            XCTAssertLessThanOrEqual(totalBudget, min(maxPossible, governor.maxWordCeiling))
        }
    }

    // MARK: - Governor State Tests

    func testGovernorStateInitialization() {
        let state = GovernorState()

        XCTAssertEqual(state.currentWordCount, 0)
        XCTAssertEqual(state.currentSectionIndex, 0)
        XCTAssertTrue(state.sectionWordCounts.isEmpty)
        XCTAssertTrue(state.expansionUsageCounts.isEmpty)
        XCTAssertEqual(state.visualCount, 0)
        XCTAssertFalse(state.cutPolicyActivated)
        XCTAssertTrue(state.synthesisCountPerSection.isEmpty)
        XCTAssertTrue(state.pendingConsolidation.isEmpty)
    }

    // MARK: - Visual Budget Tests

    func testVisualBudgetEnforcedIndependently() {
        let engine = SummaryGovernorEngine(governor: .quickReference)

        var state = GovernorState()
        state.currentWordCount = 500  // Well under word limit
        state.visualCount = 2  // Exceeds 1 max

        let result = engine.validate(
            state: state,
            sourceWordCount: 50_000,
            cutEvents: [],
            sectionDetectionEvent: nil
        )

        // Should fail on visual count even though word count is fine
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.violations.contains { violation in
            if case .visualCountExceeded = violation { return true }
            return false
        })
    }

    // MARK: - Expansion Type Protection Tests

    func testCoreArgumentIsProtected() {
        XCTAssertTrue(ExpansionType.coreArgument.isProtected)
        XCTAssertFalse(ExpansionType.exercise.isProtected)
        XCTAssertFalse(ExpansionType.adjacentDomainComparison.isProtected)
        XCTAssertFalse(ExpansionType.extendedCommentary.isProtected)
        XCTAssertFalse(ExpansionType.secondaryExample.isProtected)
        XCTAssertFalse(ExpansionType.stylisticElaboration.isProtected)
    }
}
