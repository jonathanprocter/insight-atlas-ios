import XCTest
@testable import InsightAtlas

/// Adversarial inputs for the content parsers. Generation feeds these arbitrary
/// model output, so any input that traps is a crash in front of the user.
final class ParserRobustnessTests: XCTestCase {

    private var adversarialInputs: [String] {
        [
            "",
            " ",
            "\n\n\n",
            "[",
            "]",
            "[]",
            "[INSIGHT_NOTE",
            "[/",
            "[INSIGHT_NOTE][/INSIGHT_NOTE]",
            "|",
            "||",
            "|||",
            "---",
            "1",
            "1.",
            "...",
            "。",
            "🙂",
            "e\u{0301}",                       // combining accent
            "a\u{200B}b",                      // zero-width space
            "\u{FEFF}leading BOM",
            String(repeating: "|", count: 500),
            String(repeating: "#", count: 100),
            String(repeating: "[", count: 100),
            "Ends mid-emoji 🙂",
            "Ends mid-word advers",
            "Brené Brown — “curly” ‘quotes’",
            "[VISUAL_SPECTRUM: T]\n→\n[/VISUAL_SPECTRUM]",
            "[VISUAL_TABLE: T]\n|\n|\n[/VISUAL_TABLE]",
            "[ACTION_BOX: T]\n7\n[/ACTION_BOX]",
            "Left → Right",
            "→",
            "3.5 times",
            "a | b",
            "| a | b |\n|---|---|",
            String(repeating: "word ", count: 20_000)
        ]
    }

    /// The block parser must survive anything without trapping.
    func testContentBlockParserSurvivesAdversarialInput() {
        for input in adversarialInputs {
            _ = ContentBlockParser.parse(input)
        }
    }

    /// Truncation repair does the most string-index arithmetic, so it is the
    /// likeliest place for an out-of-bounds trap.
    func testTruncationRepairSurvivesAdversarialInput() {
        for input in adversarialInputs {
            _ = ManuscriptPreflight.repairTruncatedTail(input)
        }
    }

    func testClosingTagBalancerSurvivesAdversarialInput() {
        for input in adversarialInputs {
            _ = ManuscriptPreflight.closingTagsNeeded(for: input)
        }
    }

    func testHelpersSurviveAdversarialInput() {
        for input in adversarialInputs {
            _ = ContentBlockParser.markdownHeading(in: input)
            _ = ContentBlockParser.strippedOrphanEditorialTags(input)
            _ = ContentBlockParser.isBracketResidueLine(input)
            _ = ContentBlockParser.isTableRow(input)
            _ = ContentBlockParser.isTableSeparatorRow(input)
            _ = ContentBlockParser.isBareListNumber(input)
            _ = ContentBlockParser.strippedListMarker(input)
        }
    }

    func testVisualParserSurvivesAdversarialInput() {
        for input in adversarialInputs {
            let lines = input.components(separatedBy: .newlines)
            _ = InsightVisualParser.parseSpectrum(lines)
            for tag in ["VISUAL_SPECTRUM", "VISUAL_TABLE", "VISUAL_QUADRANT", "VISUAL_GANTT"] {
                _ = InsightVisualParser.parse(tag: tag, title: nil, lines: lines)
            }
        }
    }

    /// Repair must be idempotent: running it twice cannot keep eating content.
    func testTruncationRepairIsIdempotent() {
        for input in adversarialInputs {
            let once = ManuscriptPreflight.repairTruncatedTail(input)
            let twice = ManuscriptPreflight.repairTruncatedTail(once)
            XCTAssertEqual(once, twice, "repair is not stable for: \(input.prefix(40))")
        }
    }
}
