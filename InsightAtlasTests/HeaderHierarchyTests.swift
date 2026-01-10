import XCTest
@testable import InsightAtlas

/// Regression tests for header hierarchy preservation.
///
/// These tests ensure that header semantics (H1, H2, H3, H4) survive:
/// - JSON encoding and decoding
/// - Model transformations
/// - Export round-trips
///
/// Reference: InsightAtlas/Documentation/FormattingInvariants.md
final class HeaderHierarchyTests: XCTestCase {

    // MARK: - Constants

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    // MARK: - Test: H1 Preservation Round-Trip

    /// Invariant A.1: H1 headers must survive JSON round-trip without type degradation.
    func testH1PreservationRoundTrip() throws {
        // Given: A content block with heading1 type
        let h1Block = PDFContentBlock(
            type: .heading1,
            content: "PART I: Introduction"
        )

        // When: Encode to JSON and decode back
        let jsonData = try encoder.encode(h1Block)
        let decoded = try decoder.decode(PDFContentBlock.self, from: jsonData)

        // Then: Type must remain .heading1
        XCTAssertEqual(decoded.type, .heading1, "H1 type must be preserved after round-trip")
        XCTAssertEqual(decoded.content, "PART I: Introduction", "H1 content must be preserved")
    }

    // MARK: - Test: H2 Preservation Round-Trip

    /// Invariant A.1: H2 headers must survive JSON round-trip without type degradation.
    func testH2PreservationRoundTrip() throws {
        // Given: A content block with heading2 type
        let h2Block = PDFContentBlock(
            type: .heading2,
            content: "Chapter Overview"
        )

        // When: Encode to JSON and decode back
        let jsonData = try encoder.encode(h2Block)
        let decoded = try decoder.decode(PDFContentBlock.self, from: jsonData)

        // Then: Type must remain .heading2
        XCTAssertEqual(decoded.type, .heading2, "H2 type must be preserved after round-trip")
        XCTAssertEqual(decoded.content, "Chapter Overview", "H2 content must be preserved")
    }

    // MARK: - Test: H3 and H4 Preservation

    /// Invariant A.1: H3 and H4 headers must survive JSON round-trip.
    func testH3H4PreservationRoundTrip() throws {
        // Given: Content blocks with heading3 and heading4 types
        let h3Block = PDFContentBlock(type: .heading3, content: "Subsection")
        let h4Block = PDFContentBlock(type: .heading4, content: "Minor Point")

        // When: Encode and decode
        let h3Data = try encoder.encode(h3Block)
        let h4Data = try encoder.encode(h4Block)
        let decodedH3 = try decoder.decode(PDFContentBlock.self, from: h3Data)
        let decodedH4 = try decoder.decode(PDFContentBlock.self, from: h4Data)

        // Then: Types must be preserved
        XCTAssertEqual(decodedH3.type, .heading3, "H3 type must be preserved")
        XCTAssertEqual(decodedH4.type, .heading4, "H4 type must be preserved")
    }

    // MARK: - Test: Full Hierarchy Preservation

    /// Invariant A.1: A document with mixed header levels must preserve all levels after round-trip.
    func testFullHeaderHierarchyRoundTrip() throws {
        // Given: A document with all header levels
        let document = PDFAnalysisDocument(
            book: PDFAnalysisDocument.BookMetadata(title: "Test Book", author: "Test Author"),
            quickGlance: nil,
            sections: [
                PDFAnalysisDocument.PDFSection(
                    heading: "PART I: Foundations",
                    headingLevel: 1,
                    blocks: [
                        PDFContentBlock(type: .heading2, content: "Introduction"),
                        PDFContentBlock(type: .paragraph, content: "Opening paragraph."),
                        PDFContentBlock(type: .heading3, content: "Background"),
                        PDFContentBlock(type: .paragraph, content: "Background details."),
                        PDFContentBlock(type: .heading4, content: "Historical Note"),
                        PDFContentBlock(type: .paragraph, content: "Historical context.")
                    ]
                ),
                PDFAnalysisDocument.PDFSection(
                    heading: "Key Concepts",
                    headingLevel: 2,
                    blocks: [
                        PDFContentBlock(type: .paragraph, content: "Concept explanation.")
                    ]
                )
            ],
            metadata: PDFAnalysisDocument.DocumentMetadata(generatedAt: Date())
        )

        // When: Encode to JSON and decode back
        let jsonData = try document.toJSON()
        let decoded = try PDFAnalysisDocument.fromJSON(jsonData)

        // Then: Section heading levels must be preserved
        XCTAssertEqual(decoded.sections.count, 2, "Section count must match")
        XCTAssertEqual(decoded.sections[0].headingLevel, 1, "First section must be H1")
        XCTAssertEqual(decoded.sections[1].headingLevel, 2, "Second section must be H2")

        // And: Block types within sections must be preserved
        let firstSectionBlocks = decoded.sections[0].blocks
        XCTAssertEqual(firstSectionBlocks[0].type, .heading2, "First block must be H2")
        XCTAssertEqual(firstSectionBlocks[2].type, .heading3, "Third block must be H3")
        XCTAssertEqual(firstSectionBlocks[4].type, .heading4, "Fifth block must be H4")
    }

    // MARK: - Test: Section Boundary Preservation

    /// Invariant A.2: PART (H1) and SECTION (H2) boundaries must be preserved.
    func testSectionBoundaryPreservation() throws {
        // Given: A document with clear PART and SECTION boundaries
        let document = PDFAnalysisDocument(
            book: PDFAnalysisDocument.BookMetadata(title: "Test", author: "Author"),
            sections: [
                PDFAnalysisDocument.PDFSection(heading: "PART I: Overview", headingLevel: 1, blocks: []),
                PDFAnalysisDocument.PDFSection(heading: "Section 1.1", headingLevel: 2, blocks: []),
                PDFAnalysisDocument.PDFSection(heading: "Section 1.2", headingLevel: 2, blocks: []),
                PDFAnalysisDocument.PDFSection(heading: "PART II: Details", headingLevel: 1, blocks: []),
                PDFAnalysisDocument.PDFSection(heading: "Section 2.1", headingLevel: 2, blocks: [])
            ],
            metadata: PDFAnalysisDocument.DocumentMetadata(generatedAt: Date())
        )

        // When: Round-trip through JSON
        let jsonData = try document.toJSON()
        let decoded = try PDFAnalysisDocument.fromJSON(jsonData)

        // Then: Count H1 and H2 sections
        let h1Sections = decoded.sections.filter { $0.headingLevel == 1 }
        let h2Sections = decoded.sections.filter { $0.headingLevel == 2 }

        XCTAssertEqual(h1Sections.count, 2, "Must have 2 PART (H1) sections")
        XCTAssertEqual(h2Sections.count, 3, "Must have 3 SECTION (H2) sections")

        // And: Order must be preserved
        XCTAssertEqual(decoded.sections[0].heading, "PART I: Overview")
        XCTAssertEqual(decoded.sections[1].heading, "Section 1.1")
        XCTAssertEqual(decoded.sections[2].heading, "Section 1.2")
        XCTAssertEqual(decoded.sections[3].heading, "PART II: Details")
        XCTAssertEqual(decoded.sections[4].heading, "Section 2.1")
    }

    // MARK: - Negative Test: What Breaks If Decoding Is Removed

    /// Negative test demonstrating what would break if heading1 decoding were removed.
    ///
    /// This test constructs raw JSON that represents a heading1 block, then verifies
    /// that the decoder correctly interprets it. If the "heading1" case were removed
    /// from the decoder, this test would fail because the block would fall through
    /// to the default case and become a paragraph.
    func testHeading1DecodingRequired() throws {
        // Given: Raw JSON representing a heading1 block
        let jsonString = """
        {
            "type": "heading1",
            "content": "PART I: Critical Section"
        }
        """
        let jsonData = jsonString.data(using: .utf8)!

        // When: Decode the JSON
        let decoded = try decoder.decode(PDFContentBlock.self, from: jsonData)

        // Then: Type MUST be heading1, not paragraph
        // If the "heading1" case is removed from init(from:), this assertion will fail
        XCTAssertEqual(decoded.type, .heading1,
            "CRITICAL: H1 decoded as \(decoded.type) instead of .heading1. " +
            "This indicates the heading1 case may be missing from the decoder."
        )

        // Additional assertion: content must be preserved
        XCTAssertEqual(decoded.content, "PART I: Critical Section",
            "Content must be preserved during decoding"
        )
    }

    // MARK: - Test: Unknown Type Falls Back to Paragraph

    /// Tests that unknown block types fall back to paragraph (defensive decoding).
    func testUnknownTypeFallsBackToParagraph() throws {
        // Given: JSON with an unknown type
        let jsonString = """
        {
            "type": "unknownFutureType",
            "content": "Some content"
        }
        """
        let jsonData = jsonString.data(using: .utf8)!

        // When: Decode the JSON
        let decoded = try decoder.decode(PDFContentBlock.self, from: jsonData)

        // Then: Should fall back to paragraph (defensive behavior)
        XCTAssertEqual(decoded.type, .paragraph,
            "Unknown types should fall back to paragraph"
        )
    }

    // MARK: - Test: Markdown Parsing Preserves Header Levels

    /// Tests that markdown parsing correctly identifies header levels.
    func testMarkdownParsingPreservesHeaderLevels() {
        // Given: Markdown content with multiple header levels
        let markdown = """
        # PART I: Introduction

        This is an introduction paragraph.

        ## Overview

        An overview paragraph.

        ### Details

        Some details here.

        #### Minor Note

        A minor note.
        """

        // When: Parse the markdown into a document
        let document = PDFAnalysisDocument.parse(
            from: markdown,
            title: "Test",
            author: "Author"
        )

        // Then: Verify sections were created with correct heading levels
        XCTAssertFalse(document.sections.isEmpty, "Should have parsed sections")

        // Find the PART I section (should be H1)
        let partSection = document.sections.first { $0.heading?.contains("PART I") == true }
        XCTAssertNotNil(partSection, "Should find PART I section")
        XCTAssertEqual(partSection?.headingLevel, 1, "PART I should be H1 level")

        // Find the Overview section (should be H2)
        let overviewSection = document.sections.first { $0.heading == "Overview" }
        XCTAssertNotNil(overviewSection, "Should find Overview section")
        XCTAssertEqual(overviewSection?.headingLevel, 2, "Overview should be H2 level")
    }

    // MARK: - Test: All BlockTypes Have Encode/Decode Parity

    /// Invariant E.1: Every BlockType must encode and decode symmetrically.
    func testAllBlockTypesEncodeDecodeParity() throws {
        // Given: A list of all block types with sample content
        let testCases: [(PDFContentBlock.BlockType, String)] = [
            (.paragraph, "Test paragraph"),
            (.heading1, "Test H1"),
            (.heading2, "Test H2"),
            (.heading3, "Test H3"),
            (.heading4, "Test H4"),
            (.blockquote, "Test quote"),
            (.insightNote, "Test insight"),
            (.actionBox, "Test action"),
            (.keyTakeaways, "Test takeaways"),
            (.foundationalNarrative, "Test narrative"),
            (.exercise, "Test exercise"),
            (.flowchart, "Test flowchart"),
            (.quickGlance, "Test quick glance"),
            (.bulletList, "Test bullet"),
            (.numberedList, "Test numbered"),
            (.divider, ""),
            (.table, "Test table")
        ]

        for (blockType, content) in testCases {
            // When: Create, encode, and decode a block
            let original = PDFContentBlock(type: blockType, content: content)
            let data = try encoder.encode(original)
            let decoded = try decoder.decode(PDFContentBlock.self, from: data)

            // Then: Type must be preserved
            XCTAssertEqual(decoded.type, blockType,
                "BlockType \(blockType) failed encode/decode parity"
            )
            XCTAssertEqual(decoded.content, content,
                "Content for \(blockType) not preserved"
            )
        }
    }

    // MARK: - Test: HeadingLevel Default Value

    /// Tests that PDFSection.headingLevel defaults to 2 when not specified.
    func testHeadingLevelDefaultValue() throws {
        // Given: JSON representing a section without explicit headingLevel
        let jsonString = """
        {
            "heading": "Test Section",
            "blocks": []
        }
        """
        let jsonData = jsonString.data(using: .utf8)!

        // When: Decode the section
        let decoded = try decoder.decode(PDFAnalysisDocument.PDFSection.self, from: jsonData)

        // Then: headingLevel should default to 2
        XCTAssertEqual(decoded.headingLevel, 2,
            "Default headingLevel should be 2 for sections"
        )
    }

    // MARK: - Performance Test

    /// Performance test for header hierarchy round-trip.
    func testHeaderHierarchyRoundTripPerformance() throws {
        // Create a large document with many sections
        var sections: [PDFAnalysisDocument.PDFSection] = []
        for i in 1...10 {
            sections.append(PDFAnalysisDocument.PDFSection(
                heading: "PART \(i)",
                headingLevel: 1,
                blocks: (1...5).map { j in
                    PDFContentBlock(type: .heading2, content: "Section \(i).\(j)")
                }
            ))
        }

        let document = PDFAnalysisDocument(
            book: PDFAnalysisDocument.BookMetadata(title: "Large Doc", author: "Author"),
            sections: sections,
            metadata: PDFAnalysisDocument.DocumentMetadata(generatedAt: Date())
        )

        measure {
            do {
                let data = try document.toJSON()
                _ = try PDFAnalysisDocument.fromJSON(data)
            } catch {
                XCTFail("Performance test failed with error: \(error)")
            }
        }
    }
}

// MARK: - PDFContentBlock.BlockType Equatable

extension PDFContentBlock.BlockType: Equatable {}
