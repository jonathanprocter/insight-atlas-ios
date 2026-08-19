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
            String(repeating: "word ", count: 20_000),
            // A closing bracket BEFORE a colon: the title parser computes
            // titleStart after the colon and titleEnd at the bracket, then
            // builds a reversed range.
            "[ACTION_BOX] Notice this: the pattern repeats",
            "[CONCEPT_MAP] Central idea: the through-line",
            "[PROCESS_TIMELINE] Phase one: beginning",
            "[ACTION_BOX]: leading colon after the bracket",
            "[ACTION_BOX] no colon at all",
            "[CONCEPT_MAP]x:y"
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

extension ParserRobustnessTests {

    /// The reproduced crash: a bare tag followed by prose containing a colon.
    /// The title parser took the first ":" and the first "]" without ordering
    /// them, producing a reversed range that traps.
    func testBareTagFollowedByProseWithAColonDoesNotTrap() {
        for line in [
            "[ACTION_BOX] Notice this: the pattern repeats",
            "[CONCEPT_MAP] Central idea: the through-line",
            "[PROCESS_TIMELINE] Phase one: beginning",
            "[ACTION_BOX] a: b: c: many colons",
            "[CONCEPT_MAP]x:y"
        ] {
            _ = ContentBlockParser.parse(line)
        }
    }

    func testTagTitleOnlyReadsAColonInsideTheBrackets() {
        XCTAssertEqual(ContentBlockParser.tagTitle(in: "[ACTION_BOX: Steps]"), "Steps")
        XCTAssertEqual(ContentBlockParser.tagTitle(in: "[CONCEPT_MAP: A Title] body"), "A Title")
        // Colon outside the brackets is prose, not a title.
        XCTAssertNil(ContentBlockParser.tagTitle(in: "[ACTION_BOX] Notice this: the pattern"))
        XCTAssertNil(ContentBlockParser.tagTitle(in: "[ACTION_BOX]"))
        XCTAssertNil(ContentBlockParser.tagTitle(in: "[ACTION_BOX:]"))
        XCTAssertNil(ContentBlockParser.tagTitle(in: "no brackets: at all"))
    }

    /// A closing tag preceding its opening tag on one line also reversed a range.
    func testClosingTagBeforeOpeningTagDoesNotTrap() {
        for line in [
            "[/INSIGHT_NOTE] stray text [INSIGHT_NOTE]",
            "[/EXERCISE_PRACTICE] and [EXERCISE_PRACTICE: T]",
            "[/ACTION_BOX][ACTION_BOX]"
        ] {
            _ = ContentBlockParser.parse(line)
        }
    }
}
