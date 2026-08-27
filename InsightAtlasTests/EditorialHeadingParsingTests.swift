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

    // MARK: - Malformed generation recovery

    func testAdjacentEditorialTagsAreSeparatedWithoutLosingProse() {
        let source = """
        [INSIGHT_NOTE]Basu's agreement frame exploits *liking*. **Go Deeper:** Read Influence.[/INSIGHT_NOTE][PREMIUM_H1]The Author's Lens[/PREMIUM_H1][FOUNDATIONAL_NARRATIVE]Rintu Basu came to NLP through an unlikely door.[/FOUNDATIONAL_NARRATIVE]
        """

        let canonical = EditorialMarkupCanonicalizer.canonicalize(source)

        XCTAssertTrue(canonical.contains("[/INSIGHT_NOTE]\n[PREMIUM_H1]"))
        XCTAssertTrue(canonical.contains("[/PREMIUM_H1]\n[FOUNDATIONAL_NARRATIVE]"))
        XCTAssertTrue(canonical.contains("Basu's agreement frame exploits *liking*."))
        XCTAssertTrue(canonical.contains("Rintu Basu came to NLP through an unlikely door."))
    }

    func testUnclosedPremiumHeadingStopsBeforeNextEditorialBlock() {
        let source = """
        [PREMIUM_H1]
        The Author's Lens
        [FOUNDATIONAL_NARRATIVE]
        Rintu Basu came to NLP through an unlikely door.
        [/FOUNDATIONAL_NARRATIVE]
        """

        let blocks = ContentBlockParser.parse(source)
        let header = blocks.first(where: { $0.type == .sectionHeader })
        let narrative = blocks.first(where: { $0.type == .foundationalNarrative })

        XCTAssertEqual(header?.content, "The Author's Lens")
        XCTAssertEqual(narrative?.content, "Rintu Basu came to NLP through an unlikely door.")
        XCTAssertFalse(header?.content.contains("FOUNDATIONAL_NARRATIVE") ?? true)
    }

    func testThematicSynthesisJSONBecomesReadableEditorialContent() {
        let source = """
        {
          "title": "Persuasion Skills",
          "themes": [
            {
              "name": "Reciprocity",
              "summary": "Genuine exchange builds durable influence.",
              "applications": ["Name the shared benefit", "Invite a clear response"]
            }
          ]
        }
        """

        let adapted = GuideReaderContentAdapter.prepare(source)
        let visible = ContentBlockParser.parse(adapted)
            .flatMap { block in [block.content] + block.listItems }
            .map(PresentationTextSanitizer.inlinePlainText)
            .joined(separator: "\n")

        for semantic in ["Persuasion Skills", "Reciprocity", "Genuine exchange", "Name the shared benefit"] {
            XCTAssertTrue(visible.contains(semantic), "reader lost thematic JSON value: \(semantic)")
        }
        for leaked in ["{", "}", "\"themes\"", "\"summary\""] {
            XCTAssertFalse(visible.contains(leaked), "reader leaked JSON syntax: \(leaked)")
        }
    }

    func testReportedGuideFixtureContainsNoVisibleControlSyntaxAfterParsing() {
        let source = """
        [INSIGHT_NOTE]The agreement frame exploits *liking*; the redefine pattern creates a *commitment and consistency* loop. **Go Deeper:** \"Influence\" by Robert Cialdini.[/INSIGHT_NOTE][PREMIUM_H1]The Author's Lens[/PREMIUM_H1][FOUNDATIONAL_NARRATIVE]Rintu Basu came to NLP through an unlikely door.[/FOUNDATIONAL_NARRATIVE]
        """

        let visible = ContentBlockParser.parse(source)
            .map(\.content)
            .map(PresentationTextSanitizer.inlinePlainText)
            .joined(separator: "\n")

        for leaked in ["[INSIGHT_NOTE]", "[/INSIGHT_NOTE]", "[PREMIUM_H1]", "[FOUNDATIONAL_NARRATIVE]", "*liking*", "**Go Deeper:**"] {
            XCTAssertFalse(visible.contains(leaked), "reader leaked control syntax: \(leaked)")
        }
        for semantic in ["liking", "commitment and consistency", "Go Deeper", "The Author's Lens", "Rintu Basu"] {
            XCTAssertTrue(visible.contains(semantic), "reader lost semantic text: \(semantic)")
        }
    }
}
