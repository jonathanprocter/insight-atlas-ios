import XCTest
@testable import InsightAtlas

/// Guards the guide renderer against markup reaching the reader as literal text.
final class EditorialHeadingParsingTests: XCTestCase {

    // MARK: - Markdown headings

    func testHeadingWithSpaceIsParsed() {
        let heading = ContentBlockParser.markdownHeading(in: "## The Core Argument")
        XCTAssertEqual(heading?.level, 2)
        XCTAssertEqual(heading?.text, "The Core Argument")
    }

    /// The original bug: without a space after the hashes the line fell through
    /// to the paragraph branch and the "##" rendered in the guide body.
    func testHeadingWithoutSpaceIsParsed() {
        let heading = ContentBlockParser.markdownHeading(in: "##The Core Argument")
        XCTAssertEqual(heading?.level, 2)
        XCTAssertEqual(heading?.text, "The Core Argument")
    }

    func testHeadingLevelsMapCorrectly() {
        XCTAssertEqual(ContentBlockParser.markdownHeading(in: "# Part One")?.level, 1)
        XCTAssertEqual(ContentBlockParser.markdownHeading(in: "## Section")?.level, 2)
        XCTAssertEqual(ContentBlockParser.markdownHeading(in: "### Minor")?.level, 3)
    }

    /// Levels beyond h3 collapse onto the minor-header style rather than being
    /// dropped, which would lose the text entirely.
    func testDeepHeadingsCollapseToMinor() {
        XCTAssertEqual(ContentBlockParser.markdownHeading(in: "##### Deep")?.level, 3)
        XCTAssertEqual(ContentBlockParser.markdownHeading(in: "##### Deep")?.text, "Deep")
    }

    func testBoldWrappersAreTrimmedFromHeadings() {
        XCTAssertEqual(
            ContentBlockParser.markdownHeading(in: "## **Emphasized Title**")?.text,
            "Emphasized Title"
        )
    }

    func testLeadingWhitespaceIsTolerated() {
        XCTAssertEqual(ContentBlockParser.markdownHeading(in: "   ## Indented")?.text, "Indented")
    }

    func testNonHeadingsAreRejected() {
        XCTAssertNil(ContentBlockParser.markdownHeading(in: "Just a paragraph."))
        XCTAssertNil(ContentBlockParser.markdownHeading(in: ""))
        // A bare hash run is a divider, not a heading, and has no title text.
        XCTAssertNil(ContentBlockParser.markdownHeading(in: "###"))
        XCTAssertNil(ContentBlockParser.markdownHeading(in: "#####  "))
        // Seven hashes is not a valid ATX heading.
        XCTAssertNil(ContentBlockParser.markdownHeading(in: "####### Too deep"))
    }

    func testHashInsideTextIsNotAHeading() {
        XCTAssertNil(ContentBlockParser.markdownHeading(in: "Issue #42 was resolved."))
    }

    // MARK: - Orphan editorial tags

    func testMidLineTagIsStripped() {
        XCTAssertEqual(
            ContentBlockParser.strippedOrphanEditorialTags(
                "Some prose [PREMIUM_H2] that leaked a tag."
            ),
            "Some prose that leaked a tag."
        )
    }

    func testUnclosedOpeningTagIsStripped() {
        XCTAssertEqual(
            ContentBlockParser.strippedOrphanEditorialTags("[PREMIUM_H2] Dangling header"),
            "Dangling header"
        )
    }

    func testClosingAndParameterizedTagsAreStripped() {
        XCTAssertEqual(
            ContentBlockParser.strippedOrphanEditorialTags("[/VISUAL_TIMELINE] done"),
            "done"
        )
        XCTAssertEqual(
            ContentBlockParser.strippedOrphanEditorialTags("[VISUAL_CHART: Growth] body"),
            "body"
        )
    }

    func testOrdinaryBracketsSurvive() {
        // Only uppercase tag-shaped brackets are markup; ordinary prose keeps its
        // brackets, including citation-style ones.
        XCTAssertEqual(
            ContentBlockParser.strippedOrphanEditorialTags("The author [sic] argues [1]."),
            "The author [sic] argues [1]."
        )
    }

    func testStrippingCollapsesLeftoverWhitespace() {
        XCTAssertEqual(
            ContentBlockParser.strippedOrphanEditorialTags("Before   [PREMIUM_H1]   after"),
            "Before after"
        )
    }
}
