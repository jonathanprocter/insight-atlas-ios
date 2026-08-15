import XCTest
@testable import InsightAtlas

/// Guards the guide renderer against markup reaching the reader as literal text.
final class EditorialHeadingParsingTests: XCTestCase {

    // MARK: - Markdown headings

    func testHeadingWithSpaceIsParsed() {
        let heading = EditorialContentRenderer.markdownHeading(in: "## The Core Argument")
        XCTAssertEqual(heading?.level, 2)
        XCTAssertEqual(heading?.text, "The Core Argument")
    }

    /// The original bug: without a space after the hashes the line fell through
    /// to the paragraph branch and the "##" rendered in the guide body.
    func testHeadingWithoutSpaceIsParsed() {
        let heading = EditorialContentRenderer.markdownHeading(in: "##The Core Argument")
        XCTAssertEqual(heading?.level, 2)
        XCTAssertEqual(heading?.text, "The Core Argument")
    }

    func testHeadingLevelsMapCorrectly() {
        XCTAssertEqual(EditorialContentRenderer.markdownHeading(in: "# Part One")?.level, 1)
        XCTAssertEqual(EditorialContentRenderer.markdownHeading(in: "## Section")?.level, 2)
        XCTAssertEqual(EditorialContentRenderer.markdownHeading(in: "### Minor")?.level, 3)
    }

    /// Levels beyond h3 collapse onto the minor-header style rather than being
    /// dropped, which would lose the text entirely.
    func testDeepHeadingsCollapseToMinor() {
        XCTAssertEqual(EditorialContentRenderer.markdownHeading(in: "##### Deep")?.level, 3)
        XCTAssertEqual(EditorialContentRenderer.markdownHeading(in: "##### Deep")?.text, "Deep")
    }

    func testBoldWrappersAreTrimmedFromHeadings() {
        XCTAssertEqual(
            EditorialContentRenderer.markdownHeading(in: "## **Emphasized Title**")?.text,
            "Emphasized Title"
        )
    }

    func testLeadingWhitespaceIsTolerated() {
        XCTAssertEqual(EditorialContentRenderer.markdownHeading(in: "   ## Indented")?.text, "Indented")
    }

    func testNonHeadingsAreRejected() {
        XCTAssertNil(EditorialContentRenderer.markdownHeading(in: "Just a paragraph."))
        XCTAssertNil(EditorialContentRenderer.markdownHeading(in: ""))
        // A bare hash run is a divider, not a heading, and has no title text.
        XCTAssertNil(EditorialContentRenderer.markdownHeading(in: "###"))
        XCTAssertNil(EditorialContentRenderer.markdownHeading(in: "#####  "))
        // Seven hashes is not a valid ATX heading.
        XCTAssertNil(EditorialContentRenderer.markdownHeading(in: "####### Too deep"))
    }

    func testHashInsideTextIsNotAHeading() {
        XCTAssertNil(EditorialContentRenderer.markdownHeading(in: "Issue #42 was resolved."))
    }

    // MARK: - Orphan editorial tags

    func testMidLineTagIsStripped() {
        XCTAssertEqual(
            EditorialContentRenderer.strippedOrphanEditorialTags(
                "Some prose [PREMIUM_H2] that leaked a tag."
            ),
            "Some prose that leaked a tag."
        )
    }

    func testUnclosedOpeningTagIsStripped() {
        XCTAssertEqual(
            EditorialContentRenderer.strippedOrphanEditorialTags("[PREMIUM_H2] Dangling header"),
            "Dangling header"
        )
    }

    func testClosingAndParameterizedTagsAreStripped() {
        XCTAssertEqual(
            EditorialContentRenderer.strippedOrphanEditorialTags("[/VISUAL_TIMELINE] done"),
            "done"
        )
        XCTAssertEqual(
            EditorialContentRenderer.strippedOrphanEditorialTags("[VISUAL_CHART: Growth] body"),
            "body"
        )
    }

    func testOrdinaryBracketsSurvive() {
        // Only uppercase tag-shaped brackets are markup; ordinary prose keeps its
        // brackets, including citation-style ones.
        XCTAssertEqual(
            EditorialContentRenderer.strippedOrphanEditorialTags("The author [sic] argues [1]."),
            "The author [sic] argues [1]."
        )
    }

    func testStrippingCollapsesLeftoverWhitespace() {
        XCTAssertEqual(
            EditorialContentRenderer.strippedOrphanEditorialTags("Before   [PREMIUM_H1]   after"),
            "Before after"
        )
    }
}
