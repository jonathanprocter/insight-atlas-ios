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
