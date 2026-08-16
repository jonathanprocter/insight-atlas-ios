import XCTest
@testable import InsightAtlas

/// Two reported rendering faults: a numbered sequence whose steps came apart,
/// and an accented author name rendered as "BRENé Brown".
final class ListAndCitationRenderingTests: XCTestCase {

    // MARK: - Bare list numbers

    func testBareNumberDetection() {
        XCTAssertTrue(ContentBlockParser.isBareListNumber("7"))
        XCTAssertTrue(ContentBlockParser.isBareListNumber("7."))
        XCTAssertTrue(ContentBlockParser.isBareListNumber("7)"))
        XCTAssertTrue(ContentBlockParser.isBareListNumber("  12.  "))
        XCTAssertFalse(ContentBlockParser.isBareListNumber("7. Notice the Critic"))
        XCTAssertFalse(ContentBlockParser.isBareListNumber("Seven"))
        XCTAssertFalse(ContentBlockParser.isBareListNumber(""))
    }

    func testMarkerStripping() {
        XCTAssertEqual(ContentBlockParser.strippedListMarker("- Notice"), "Notice")
        XCTAssertEqual(ContentBlockParser.strippedListMarker("* Notice"), "Notice")
        XCTAssertEqual(ContentBlockParser.strippedListMarker("3. Notice"), "Notice")
        XCTAssertEqual(ContentBlockParser.strippedListMarker("3) Notice"), "Notice")
        // No space after the period, which the old regex required.
        XCTAssertEqual(ContentBlockParser.strippedListMarker("3.Notice"), "Notice")
        XCTAssertEqual(ContentBlockParser.strippedListMarker("Plain text"), "Plain text")
    }

    /// A decimal in prose is not a list marker.
    func testDecimalsInProseAreNotStripped() {
        XCTAssertEqual(
            ContentBlockParser.strippedListMarker("Roughly 3.5 times higher"),
            "Roughly 3.5 times higher"
        )
    }

    // MARK: - The reported sequence

    /// Numbers on their own lines must rejoin their text, and a "---" separator
    /// must not become a phantom step -- the item that rendered as "—-".
    func testNumberedSequenceWithSplitNumbersAndSeparator() {
        let content = """
        [ACTION_BOX: The Unblending Sequence]
        1
        Notice the Critic's voice and write down exactly what it is saying.
        2
        Locate the Critic as an image, voice, or body sensation.
        ---
        3
        Notice the Criticized Child.
        [/ACTION_BOX]
        """

        let blocks = ContentBlockParser.parse(content)
        guard let box = blocks.first(where: { $0.type == .actionBox }) else {
            return XCTFail("expected an action box, got \(blocks.map(\.type))")
        }

        XCTAssertEqual(box.listItems.count, 3, "separator must not become a step")
        XCTAssertEqual(box.listItems.first, "Notice the Critic's voice and write down exactly what it is saying.")
        XCTAssertEqual(box.listItems.last, "Notice the Criticized Child.")
        XCTAssertFalse(
            box.listItems.contains { ContentBlockParser.isBareListNumber($0) },
            "a bare number reached the reader as a step"
        )
        XCTAssertFalse(
            box.listItems.contains { $0.allSatisfy { c in c == "-" || c == "—" } },
            "a dash rendered as a step"
        )
    }

    func testConventionalNumberedListStillParses() {
        let content = """
        [ACTION_BOX: Steps]
        1. First step
        2. Second step
        [/ACTION_BOX]
        """
        let box = ContentBlockParser.parse(content).first { $0.type == .actionBox }
        XCTAssertEqual(box?.listItems, ["First step", "Second step"])
    }

    // MARK: - Accented author names

    /// "Brené Brown" used to render as "BRENé Brown": the ASCII-only author
    /// class stopped at the accent, so only "Bren" was uppercased.
    func testAccentedAuthorNameIsNotSplit() {
        let rendered = String(
            parseMarkdownBold("\"Daring Greatly\" by Brené Brown changed the field.").characters
        )
        XCTAssertFalse(rendered.contains("BRENé"), "the author name was split at the accent")
        XCTAssertTrue(
            rendered.contains("BRENÉ BROWN"),
            "expected the full name uppercased, got: \(rendered)"
        )
    }

    func testUnaccentedAuthorNamesStillRender() {
        let rendered = String(
            parseMarkdownBold("\"Thinking, Fast and Slow\" by Daniel Kahneman is seminal.").characters
        )
        XCTAssertTrue(rendered.contains("DANIEL KAHNEMAN"), "got: \(rendered)")
    }

    func testOtherDiacriticsSurvive() {
        let rendered = String(
            parseMarkdownBold("\"Being and Time\" by Martin Heidegger endures.").characters
        )
        XCTAssertTrue(rendered.contains("MARTIN HEIDEGGER"), "got: \(rendered)")
    }
}
