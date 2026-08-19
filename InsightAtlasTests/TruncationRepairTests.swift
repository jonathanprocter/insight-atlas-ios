import XCTest
@testable import InsightAtlas

/// Guides shipped ending mid-word — "...rather than treat each advers".
/// Truncation was detected but nothing repaired the fragment, and the
/// conclusion pass appended onto the broken tail rather than mending it.
final class TruncationRepairTests: XCTestCase {

    func testMidWordTailIsTrimmedToTheLastCompleteSentence() {
        let content = """
        Surgeons work under irreducible uncertainty. Gawande argues that they \
        must learn to dwell there permanently rather than treat each advers
        """
        let repaired = ManuscriptPreflight.repairTruncatedTail(content)
        XCTAssertFalse(repaired.hasSuffix("advers"), "the fragment survived")
        XCTAssertTrue(repaired.hasSuffix("."), "should end on a complete sentence")
        XCTAssertTrue(repaired.contains("irreducible uncertainty"), "real content was lost")
    }

    /// A partial tag renders literally: no branch matches it and orphan-tag
    /// stripping needs a closing bracket.
    func testPartialTrailingTagIsRemoved() {
        let repaired = ManuscriptPreflight.repairTruncatedTail(
            "The argument concludes here. [INSIGHT_NO"
        )
        XCTAssertFalse(repaired.contains("[INSIGHT_NO"), "a partial tag reached the output")
        XCTAssertTrue(repaired.contains("concludes here."))
    }

    /// Cutting inside a block must not leave it unclosed for the parser.
    func testCutInsideABlockClosesIt() {
        let content = """
        [INSIGHT_NOTE]
        Wolf shows that reading rewires the brain. The deep-reading circuit is not innate but built, and it can be lost when advers
        """
        let repaired = ManuscriptPreflight.repairTruncatedTail(content)
        XCTAssertTrue(repaired.contains("[/INSIGHT_NOTE]"), "block left unclosed after the cut")
        XCTAssertFalse(repaired.contains("advers\n"), "fragment retained")
    }

    func testAlreadyCompleteContentIsUntouched() {
        let content = "A complete thought that ends properly."
        XCTAssertEqual(ManuscriptPreflight.repairTruncatedTail(content), content)
    }

    func testContentEndingInAClosingTagIsUntouched() {
        let content = "[INSIGHT_NOTE]\nA finished note.\n[/INSIGHT_NOTE]"
        XCTAssertEqual(ManuscriptPreflight.repairTruncatedTail(content), content)
    }

    /// A trim that would discard most of the content indicates the tail is not
    /// a fragment; better to keep everything than delete real material.
    func testRefusesToDiscardLargeAmountsOfContent() {
        let content = "Short. " + String(repeating: "an unpunctuated clause that runs on ", count: 20)
        let repaired = ManuscriptPreflight.repairTruncatedTail(content)
        XCTAssertGreaterThan(repaired.count, content.count / 2, "too much content was discarded")
    }

    func testQuestionAndExclamationCountAsTerminators() {
        XCTAssertTrue(
            ManuscriptPreflight.repairTruncatedTail("What does it mean? Consider the advers").hasSuffix("?")
        )
        XCTAssertTrue(
            ManuscriptPreflight.repairTruncatedTail("It matters! And then the advers").hasSuffix("!")
        )
    }

    func testClosingTagsNeededTracksNesting() {
        XCTAssertEqual(ManuscriptPreflight.closingTagsNeeded(for: "[INSIGHT_NOTE]\nbody"), "\n[/INSIGHT_NOTE]")
        XCTAssertEqual(ManuscriptPreflight.closingTagsNeeded(for: "[INSIGHT_NOTE]\nbody\n[/INSIGHT_NOTE]"), "")
        // A titled opener still counts as open.
        XCTAssertEqual(ManuscriptPreflight.closingTagsNeeded(for: "[ACTION_BOX: Steps]\nfirst"), "\n[/ACTION_BOX]")
    }
}

extension TruncationRepairTests {

    /// Bullets routinely carry no full stop. Trimming them dropped the final
    /// takeaway from every guide ending in a list.
    func testTrailingBulletIsNotTrimmed() {
        let content = """
        The six processes map onto their counterparts.

        - Experiential avoidance becomes acceptance
        - Cognitive fusion becomes defusion
        - Values confusion becomes values clarification
        """
        let repaired = ManuscriptPreflight.repairTruncatedTail(content)
        XCTAssertTrue(
            repaired.contains("values clarification"),
            "the final bullet was trimmed away"
        )
    }

    func testTrailingNumberedItemIsNotTrimmed() {
        let content = "Steps to follow.\n\n1. Notice the critic\n2. Locate it in the body"
        let repaired = ManuscriptPreflight.repairTruncatedTail(content)
        XCTAssertTrue(repaired.contains("Locate it in the body"), "the final step was trimmed")
    }

    func testTrailingHeadingIsNotTrimmed() {
        let content = "Some prose ends here.\n\n## A Closing Section"
        let repaired = ManuscriptPreflight.repairTruncatedTail(content)
        XCTAssertTrue(repaired.contains("A Closing Section"), "the trailing heading was trimmed")
    }

    /// The genuine fragment case must still be repaired when there is a sentence
    /// boundary to fall back to.
    func testGenuineFragmentAfterAListIsStillTrimmed() {
        let content = "- A complete bullet.\n\nAnd then prose that stops mid advers"
        let repaired = ManuscriptPreflight.repairTruncatedTail(content)
        XCTAssertFalse(repaired.hasSuffix("advers"), "a real fragment survived")
        XCTAssertTrue(repaired.contains("A complete bullet"), "the bullet was lost")
    }

    /// With no sentence terminator anywhere there is no safe boundary, so the
    /// content is returned untouched rather than guessing where to cut.
    func testFragmentWithNoSentenceBoundaryIsLeftAlone() {
        let content = "prose with no terminator at all that just stops mid advers"
        XCTAssertEqual(ManuscriptPreflight.repairTruncatedTail(content), content)
    }
}
