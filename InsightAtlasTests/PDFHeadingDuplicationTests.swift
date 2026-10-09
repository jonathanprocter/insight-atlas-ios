import XCTest
@testable import InsightAtlas

/// A shipped guide rendered "The One-Page Summary" three times in a row and
/// printed bare `[` / `]` lines as body paragraphs. Both come out of
/// `PDFAnalysisDocument.parse`, which has three separate sites that append a
/// `.premiumH2` block.
final class PDFHeadingDuplicationTests: XCTestCase {

    private func blocks(_ content: String) -> [PDFContentBlock] {
        PDFAnalysisDocument
            .parse(from: content, title: "T", author: "A")
            .sections
            .flatMap(\.blocks)
    }

    private func headings(_ content: String) -> [String] {
        blocks(content)
            .filter { $0.type == .premiumH2 || $0.type == .heading2 }
            .map(\.content)
    }

    /// Diagnostic: print what each plausible authoring shape produces, so the
    /// duplicating path is identified from output rather than guessed at.
    func testReportHeadingShapes() {
        let shapes: [(String, String)] = [
            ("inline", "[PREMIUM_H2]The One-Page Summary[/PREMIUM_H2]\n\nBody text here."),
            ("multiline", "[PREMIUM_H2]\nThe One-Page Summary\n[/PREMIUM_H2]\n\nBody text here."),
            ("unterminated", "[PREMIUM_H2]The One-Page Summary\n\nBody text here."),
            ("inline+markdown", "[PREMIUM_H2]The One-Page Summary[/PREMIUM_H2]\n## The One-Page Summary\n\nBody."),
            ("markdown only", "## The One-Page Summary\n\nBody text here.")
        ]
        for (name, content) in shapes {
            let all = blocks(content).map { "\($0.type):\($0.content.prefix(28))" }
            print("[HeadingShape] \(name): \(headings(content)) | blocks=\(all)")
        }
    }

    /// Whatever the authoring shape, one heading must render once.
    func testHeadingIsNotDuplicated() {
        for content in [
            "[PREMIUM_H2]The One-Page Summary[/PREMIUM_H2]\n\nBody text here.",
            "[PREMIUM_H2]\nThe One-Page Summary\n[/PREMIUM_H2]\n\nBody text here."
        ] {
            XCTAssertEqual(
                headings(content), ["The One-Page Summary"],
                "duplicated for content: \(content.debugDescription)"
            )
        }
    }

    /// Bracket-only lines are tag debris, never body copy.
    func testOrphanedBracketLinesAreNotRenderedAsParagraphs() {
        let content = "[\n]\n\nPersuasion Skills Black Book sits in a specific tradition."
        let paragraphs = blocks(content)
            .filter { $0.type == .paragraph }
            .map { $0.content.trimmingCharacters(in: .whitespacesAndNewlines) }

        XCTAssertFalse(paragraphs.contains("["), "a bare [ was rendered as a paragraph")
        XCTAssertFalse(paragraphs.contains("]"), "a bare ] was rendered as a paragraph")
        XCTAssertTrue(
            paragraphs.contains(where: { $0.hasPrefix("Persuasion Skills Black Book") }),
            "real body copy must survive"
        )
    }
}
