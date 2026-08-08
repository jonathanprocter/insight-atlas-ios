import XCTest
@testable import InsightAtlas

/// Locks the behavior of `OutputQualityValidator.detectTruncation`, which guards
/// against shipping guides that were cut off mid-generation (Design QA #3/4/5).
final class ContentTruncationTests: XCTestCase {

    // MARK: - Positive cases (should detect truncation)

    func testDetectsDanglingAuthorInitial() {
        let content = """
        [FOUNDATIONAL_NARRATIVE]
        The work builds on decades of research.

        For a deeper treatment, see "A Liberated Mind" by Steven C.
        """
        XCTAssertNotNil(OutputQualityValidator.detectTruncation(in: content))
    }

    func testDetectsLeadInColonWithNoPayload() {
        let content = """
        Frank's PART method offers a compact protocol:
        """
        XCTAssertNotNil(OutputQualityValidator.detectTruncation(in: content))
    }

    func testDetectsMidSentenceEnding() {
        let content = """
        Internal conflict is not a malfunction but a signal that two parts of the
        """
        XCTAssertNotNil(OutputQualityValidator.detectTruncation(in: content))
    }

    func testDetectsTruncationBeforeTrailingClosingTag() {
        // A closing tag after the truncated prose must not mask the truncation.
        let content = """
        [AUTHOR_SPOTLIGHT]
        A landmark contribution came from Steven C.
        [/AUTHOR_SPOTLIGHT]
        """
        XCTAssertNotNil(OutputQualityValidator.detectTruncation(in: content))
    }

    // MARK: - Negative cases (should NOT flag well-formed output)

    func testCleanProseEndingIsNotFlagged() {
        let content = """
        The synthesis points toward a single, durable practice: noticing the pull
        of inertia and choosing one small action anyway.
        """
        XCTAssertNil(OutputQualityValidator.detectTruncation(in: content))
    }

    func testKnownAbbreviationIsNotFlagged() {
        let content = "She completed the program and earned her Ph.D."
        XCTAssertNil(OutputQualityValidator.detectTruncation(in: content))
    }

    func testTrailingListItemIsNotFlagged() {
        let content = """
        Key practices:

        - Name the part
        - Get curious about its fear
        - Choose a values-aligned action
        """
        XCTAssertNil(OutputQualityValidator.detectTruncation(in: content))
    }

    func testEndingOnStructuralTagIsNotFlagged() {
        let content = """
        The chapter closes with a call to steady, deliberate practice.

        [PREMIUM_DIVIDER]
        """
        XCTAssertNil(OutputQualityValidator.detectTruncation(in: content))
    }
}
