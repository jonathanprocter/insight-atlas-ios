import XCTest
@testable import InsightAtlas

/// Regression: `sanitizeGeneratedContent` used to drop every `[VISUAL_*]`
/// wrapper, leaving chart payloads as raw prose in the reader.
@MainActor
final class VisualSanitizePreservationTests: XCTestCase {

    func testPreservesVisualTableWrappers() {
        let raw = """
        [PREMIUM_H2]Frameworks[/PREMIUM_H2]
        [VISUAL_TABLE: Comparison]
        Dimension | A | B
        Focus | Thought | Story
        [/VISUAL_TABLE]
        Closing sentence that ends cleanly.
        """
        let sanitized = BackgroundGenerationCoordinator.shared.sanitizeGeneratedContent(raw)
        XCTAssertTrue(sanitized.contains("[VISUAL_TABLE: Comparison]"), sanitized)
        XCTAssertTrue(sanitized.contains("[/VISUAL_TABLE]"), sanitized)
        XCTAssertTrue(sanitized.contains("Dimension | A | B"), sanitized)

        let blocks = ContentBlockParser.parse(sanitized)
        XCTAssertTrue(
            blocks.contains { $0.type == .visual || $0.type == .table },
            "Expected a visual or table block, got: \(blocks.map(\.type))"
        )
    }

    func testPreservesVisualSpectrumAndNetwork() {
        let raw = """
        [VISUAL_SPECTRUM: Poles]
        Left pole → Right pole
        Item A | 0.2
        [/VISUAL_SPECTRUM]
        [VISUAL_NETWORK: Graph]
        Node: a | Alpha
        Node: b | Beta
        Link: a → b
        [/VISUAL_NETWORK]
        """
        let sanitized = BackgroundGenerationCoordinator.shared.sanitizeGeneratedContent(raw)
        XCTAssertTrue(sanitized.contains("[VISUAL_SPECTRUM: Poles]"))
        XCTAssertTrue(sanitized.contains("[VISUAL_NETWORK: Graph]"))
        XCTAssertTrue(sanitized.contains("Link: a → b"))
    }

    func testStillDropsUnknownBareTags() {
        let raw = """
        [UNKNOWN_JUNK]
        body
        [/UNKNOWN_JUNK]
        """
        let sanitized = BackgroundGenerationCoordinator.shared.sanitizeGeneratedContent(raw)
        XCTAssertFalse(sanitized.contains("[UNKNOWN_JUNK]"))
        XCTAssertFalse(sanitized.contains("[/UNKNOWN_JUNK]"))
        XCTAssertTrue(sanitized.contains("body"))
    }

    func testNetworkParserAcceptsUnicodeArrow() {
        let visual = InsightVisualParser.parse(
            tag: "VISUAL_NETWORK",
            title: "Graph",
            lines: [
                "Node: a | Alpha",
                "Node: b | Beta",
                "Link: a → b"
            ]
        )
        guard case .network(let data) = visual?.payload else {
            return XCTFail("Expected network payload, got \(String(describing: visual?.payload))")
        }
        XCTAssertEqual(data.connections.count, 1)
        XCTAssertEqual(data.connections.first?.from, "a")
        XCTAssertEqual(data.connections.first?.to, "b")
    }
}
