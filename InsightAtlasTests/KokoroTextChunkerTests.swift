import XCTest
@testable import InsightAtlas

final class KokoroTextChunkerTests: XCTestCase {

    func testShortNarrationRemainsOneChunk() {
        let chunker = KokoroTextChunker(maximumCharacters: 200)
        let text = "A concise idea deserves a clear and natural explanation."

        XCTAssertEqual(chunker.chunks(for: text), [text])
    }

    func testWhitespaceOnlyNarrationProducesNoChunks() {
        let chunker = KokoroTextChunker(maximumCharacters: 200)

        XCTAssertTrue(chunker.chunks(for: "  \n\t  ").isEmpty)
    }

    func testLongNarrationSplitsNearSentenceBoundaries() {
        let chunker = KokoroTextChunker(maximumCharacters: 72)
        let text = "The first idea is deliberately brief. The second idea adds useful context. The third idea closes the reflection."
        let chunks = chunker.chunks(for: text)

        XCTAssertGreaterThan(chunks.count, 1)
        XCTAssertTrue(chunks.allSatisfy { $0.count <= 72 })
        XCTAssertEqual(normalized(chunks.joined(separator: " ")), normalized(text))
    }

    func testSingleOversizedSentenceSplitsWithoutDroppingWords() {
        let chunker = KokoroTextChunker(maximumCharacters: 40)
        let text = "Insight becomes durable when repeated deliberate practice turns a useful concept into an available response."
        let chunks = chunker.chunks(for: text)

        XCTAssertGreaterThan(chunks.count, 1)
        XCTAssertTrue(chunks.allSatisfy { $0.count <= 40 })
        XCTAssertEqual(normalized(chunks.joined(separator: " ")), normalized(text))
    }

    func testDefaultChunkingReducesSerialCallsForLongDanielNarration() {
        let sentence = "Daniel explains one complete idea at a time so the listening edition remains natural, accurate, and easy to follow."
        let text = Array(repeating: sentence, count: 36).joined(separator: " ")
        let legacy = KokoroTextChunker(maximumCharacters: 1_200).chunks(for: text)
        let optimized = KokoroTextChunker().chunks(for: text)

        XCTAssertLessThan(optimized.count, legacy.count)
        XCTAssertEqual(normalized(optimized.joined(separator: " ")), normalized(text))
    }

    private func normalized(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}
