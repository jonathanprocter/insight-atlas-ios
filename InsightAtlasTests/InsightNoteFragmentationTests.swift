import XCTest
@testable import InsightAtlas

/// Synthetic exercise of the insight-note fragmentation path. Real "-5" notes are
/// body + GO DEEPER footer, so the split path never fired in production; this
/// forces it on a 4-fat-section note so the planner/partition/floor/label logic
/// runs in a controlled build. Draw-path measure==draw is by construction — the
/// fragment drawer is `drawInsightNoteCard` (unchanged) with a fixed 30pt header
/// slot, so a continuation label cannot change fragment height.
final class InsightNoteFragmentationTests: XCTestCase {

    /// ~7 wrapped lines at content width → comfortably above the 120pt floor.
    private func fatSection(_ lead: String) -> String {
        lead + " " + String(repeating: "This clause adds measurable vertical height so the section clears the content floor when wrapped at the page inset width. ", count: 4)
    }

    func testFourSectionNoteSplitsIntoTwoFloorWorthyFragments() {
        let renderer = PDFContentBlockRenderer()
        let width = PDFStyleConfiguration.PageLayout.contentWidth
        let content = fatSection("The core connection establishes the through-line.")
            + " Key Distinction: " + fatSection("The distinction that sharpens the idea.")
            + " Practical Implication: " + fatSection("What the reader should actually do.")
            + " Go Deeper: \"A Real Book\" by A. Author — " + fatSection("why this source extends the point.")

        // Budget chosen to force two groups of two sections.
        let budget: CGFloat = 420
        let frags = renderer.planInsightNoteFragments(content: content, title: "Insight Atlas Note", maxWidth: width, firstBudget: budget, pageBudget: budget)

        XCTAssertNotNil(frags, "A 4-fat-section note must be splittable")
        guard let frags else { return }
        XCTAssertGreaterThanOrEqual(frags.count, 2, "Must produce at least two fragments")

        // Check 4 — continuation identity.
        XCTAssertFalse(frags[0].headerLabel.contains("CONTINUED"), "Fragment 1 keeps the base label")
        for f in frags.dropFirst() {
            XCTAssertTrue(f.headerLabel.contains("(CONTINUED)"), "Continuations carry (CONTINUED)")
        }

        // Check 1/2 — every fragment has positive planned height.
        for f in frags { XCTAssertGreaterThan(f.plannedHeight, 0) }

        // Check 5 — section-atomic + no loss: each populated section appears in
        // exactly one fragment, none duplicated or dropped.
        XCTAssertEqual(frags.filter { !$0.core.isEmpty }.count, 1)
        XCTAssertEqual(frags.filter { $0.keyDistinction != nil }.count, 1)
        XCTAssertEqual(frags.filter { $0.practicalImplication != nil }.count, 1)
        XCTAssertEqual(frags.filter { $0.goDeeper != nil }.count, 1)
    }

    func testBodyPlusSmallFooterRefusesToSplit() {
        // The real-world shape: a long body + a short GO DEEPER footer. The footer
        // is below the floor, so the planner must push the whole note rather than
        // orphan a runt footer card.
        let renderer = PDFContentBlockRenderer()
        let width = PDFStyleConfiguration.PageLayout.contentWidth
        let content = fatSection("A corroborating body that is long on its own.")
            + " Go Deeper: \"Book\" by Author — a short pointer."
        let frags = renderer.planInsightNoteFragments(content: content, title: "Insight Atlas Note", maxWidth: width, firstBudget: 270, pageBudget: 270)
        XCTAssertNil(frags, "body + small footer must push whole, never orphan the footer")
    }

    func testKeyChallengeIsGatedOutOfPlanner() {
        // Check 3 (gate side): a KEY CHALLENGE never reaches the planner.
        let renderer = PDFContentBlockRenderer()
        let challenge = "Key Challenge: " + fatSection("this complicates the claim.")
        XCTAssertFalse(renderer.insightNoteIsSplittable(content: challenge, title: "Insight Atlas Note"),
                       "KEY CHALLENGE must be gated out of the fragment planner")
    }
}
