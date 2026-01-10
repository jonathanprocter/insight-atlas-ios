//
//  SummaryGovernorPresets.swift
//  InsightAtlas
//
//  Authoritative governor instances for Summary Type Governors v1.0.
//
//  These values are FINAL and AUTHORITATIVE. Do NOT modify without
//  version increment and migration path.
//
//  Reference: InsightAtlas/Documentation/GOVERNANCE_LOCKS.md
//

import Foundation

// MARK: - Governor Presets

extension SummaryTypeGovernor {

    // MARK: - Quick Reference

    /// Quick Reference governor for brief, actionable summaries.
    ///
    /// Target: 900-1,200 words, ~6 minutes audio
    /// Use case: Busy professionals needing rapid comprehension
    static let quickReference = SummaryTypeGovernor(
        summaryType: .quickReference,
        baseWordCount: 900,
        sourceScalingFactor: 0.015,
        minSourceLengthForScaling: 20_000,
        maxScaledAddition: 450,
        maxWordCeiling: 1_800,
        maxAudioMinutes: 6,
        maxSynthesisPerSection: 1,
        sectionBudget: SectionBudget(
            introPercent: 0.10,
            chapterPoolPercent: 0.80,
            conclusionPercent: 0.10,
            minPerChapter: 150,
            maxPerChapter: 400,
            fallbackStrategy: .treatAsMonolith
        ),
        cutPolicy: CutPolicy(
            triggerThreshold: 0.85,
            hardLimitThreshold: 1.0,
            cutOrder: [
                .adjacentDomainComparison,
                .exercise,
                .extendedCommentary,
                .secondaryExample,
                .stylisticElaboration
            ],
            replacementStrategy: .synthesize
        ),
        visualBudget: VisualBudget(
            maxVisuals: 1,
            wordsPerVisualEquivalent: 200
        ),
        strictEnforcement: true
    )

    // MARK: - Professional

    /// Professional governor for comprehensive business summaries.
    ///
    /// Target: 3,000-4,000 words, ~18 minutes audio
    /// Use case: Knowledge workers needing thorough understanding
    static let professional = SummaryTypeGovernor(
        summaryType: .professional,
        baseWordCount: 3_000,
        sourceScalingFactor: 0.02,
        minSourceLengthForScaling: 20_000,
        maxScaledAddition: 1_500,
        maxWordCeiling: 6_000,
        maxAudioMinutes: 18,
        maxSynthesisPerSection: 2,
        sectionBudget: SectionBudget(
            introPercent: 0.10,
            chapterPoolPercent: 0.80,
            conclusionPercent: 0.10,
            minPerChapter: 250,
            maxPerChapter: 600,
            fallbackStrategy: .inferSections
        ),
        cutPolicy: CutPolicy(
            triggerThreshold: 0.85,
            hardLimitThreshold: 1.0,
            cutOrder: [
                .adjacentDomainComparison,
                .exercise,
                .extendedCommentary,
                .secondaryExample
            ],
            replacementStrategy: .synthesize
        ),
        visualBudget: VisualBudget(
            maxVisuals: 3,
            wordsPerVisualEquivalent: 200
        ),
        strictEnforcement: true
    )

    // MARK: - Accessible

    /// Accessible governor for reader-friendly, educational summaries.
    ///
    /// Target: 4,500-6,000 words, ~25 minutes audio
    /// Use case: General readers seeking accessible, engaging content
    static let accessible = SummaryTypeGovernor(
        summaryType: .accessible,
        baseWordCount: 4_500,
        sourceScalingFactor: 0.025,
        minSourceLengthForScaling: 20_000,
        maxScaledAddition: 2_000,
        maxWordCeiling: 9_000,
        maxAudioMinutes: 25,
        maxSynthesisPerSection: 3,
        sectionBudget: SectionBudget(
            introPercent: 0.12,
            chapterPoolPercent: 0.76,
            conclusionPercent: 0.12,
            minPerChapter: 300,
            maxPerChapter: 800,
            fallbackStrategy: .inferSections
        ),
        cutPolicy: CutPolicy(
            triggerThreshold: 0.90,
            hardLimitThreshold: 1.0,
            cutOrder: [
                .adjacentDomainComparison,
                .extendedCommentary,
                .exercise
            ],
            replacementStrategy: .synthesize
        ),
        visualBudget: VisualBudget(
            maxVisuals: 4,
            wordsPerVisualEquivalent: 200
        ),
        strictEnforcement: true
    )

    // MARK: - Deep Research

    /// Deep Research governor for comprehensive academic/research summaries.
    ///
    /// Target: 7,000-12,000 words, ~50 minutes audio
    /// Use case: Researchers and scholars needing exhaustive analysis
    static let deepResearch = SummaryTypeGovernor(
        summaryType: .deepResearch,
        baseWordCount: 10_000,
        sourceScalingFactor: 0.04,
        minSourceLengthForScaling: 25_000,
        maxScaledAddition: 8_000,
        maxWordCeiling: 22_000,
        maxAudioMinutes: 80,
        maxSynthesisPerSection: 6,
        sectionBudget: SectionBudget(
            introPercent: 0.08,
            chapterPoolPercent: 0.84,
            conclusionPercent: 0.08,
            minPerChapter: 400,
            maxPerChapter: 1_200,
            fallbackStrategy: .inferSections
        ),
        cutPolicy: CutPolicy(
            triggerThreshold: 0.92,
            hardLimitThreshold: 1.0,
            cutOrder: [
                .adjacentDomainComparison,
                .extendedCommentary
            ],
            replacementStrategy: .synthesize
        ),
        visualBudget: VisualBudget(
            maxVisuals: 6,
            wordsPerVisualEquivalent: 200
        ),
        strictEnforcement: true
    )

    // MARK: - Preset Access

    /// Returns the governor for a given summary type.
    static func governor(for summaryType: SummaryType) -> SummaryTypeGovernor {
        switch summaryType {
        case .quickReference: return .quickReference
        case .professional: return .professional
        case .accessible: return .accessible
        case .deepResearch: return .deepResearch
        }
    }

    /// All available governor presets.
    static let allGovernors: [SummaryTypeGovernor] = [
        .quickReference,
        .professional,
        .accessible,
        .deepResearch
    ]
}

// MARK: - Preset Comparison Table

/*
 ## Governor Comparison Table

 | Property                | Quick Ref | Professional | Accessible | Deep Research |
 |-------------------------|-----------|--------------|------------|---------------|
 | Base Words              | 900       | 3,000        | 4,500      | 7,000         |
 | Max Words               | 1,200     | 4,000        | 6,000      | 12,000        |
 | Max Audio (min)         | 6         | 18           | 25         | 50            |
 | Max Visuals             | 1         | 3            | 4          | 6             |
 | Cut Trigger             | 85%       | 85%          | 90%        | 92%           |
 | Max Synthesis/Section   | 1         | 2            | 3          | 4             |
 | Min/Chapter             | 150       | 250          | 300        | 400           |
 | Max/Chapter             | 400       | 600          | 800        | 1,200         |
 | Fallback Strategy       | Monolith  | Infer        | Infer      | Infer         |
 | Scaling Factor          | 1.5%      | 2.0%         | 2.5%       | 3.0%          |
 | Max Scaled Addition     | 450       | 1,500        | 2,000      | 5,000         |
 | Strict Enforcement      | Yes       | Yes          | Yes        | Yes           |

 ## Cut Order by Governor

 Quick Reference:
 1. adjacentDomainComparison
 2. exercise
 3. extendedCommentary
 4. secondaryExample
 5. stylisticElaboration

 Professional:
 1. adjacentDomainComparison
 2. exercise
 3. extendedCommentary
 4. secondaryExample

 Accessible:
 1. adjacentDomainComparison
 2. extendedCommentary
 3. exercise

 Deep Research:
 1. adjacentDomainComparison
 2. extendedCommentary

 Note: `coreArgument` is NEVER in cut order - it is protected.
 */
