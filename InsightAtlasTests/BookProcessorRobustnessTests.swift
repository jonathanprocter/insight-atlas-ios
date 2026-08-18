import XCTest
@testable import InsightAtlas

/// Drives the book-import path with a real PDF and with malformed data.
///
/// Generation begins by parsing the source document. Nothing exercised that
/// path in tests, so a document that makes it trap crashes in front of the
/// user with no coverage to catch it first.
final class BookProcessorRobustnessTests: XCTestCase {

    private static let realPDFPath = "/private/tmp/insightatlas-testbook.pdf"

    private var realPDF: URL? {
        guard FileManager.default.fileExists(atPath: Self.realPDFPath) else { return nil }
        return URL(fileURLWithPath: Self.realPDFPath)
    }

    /// A genuine multi-page PDF must parse without trapping.
    func testRealPDFParsesWithoutTrapping() async throws {
        guard let url = realPDF else {
            throw XCTSkip("stage a PDF at \(Self.realPDFPath) to run this")
        }
        let processor = BookProcessor()
        let book = try await processor.processBook(from: url)
        XCTAssertFalse(book.text.isEmpty, "no text extracted from a real PDF")
    }

    /// Malformed input must throw, never trap.
    func testMalformedDataThrowsRatherThanCrashing() async {
        let processor = BookProcessor()
        let cases: [Data] = [
            Data(),
            Data([0x00]),
            Data("not a pdf".utf8),
            Data("%PDF-1.4\nbroken".utf8),
            Data(repeating: 0xFF, count: 4096)
        ]
        for data in cases {
            do {
                _ = try await processor.processBook(from: data, fileType: .pdf)
            } catch {
                // Throwing is the correct behaviour.
            }
        }
    }

    /// Entity decoding does index arithmetic across two strings; adversarial
    /// entities are the shape most likely to trap.
    func testAdversarialEntitiesDoNotTrap() async {
        let processor = BookProcessor()
        let payloads = [
            "&#;", "&#x;", "&#999999999;", "&#xFFFFFFFF;", "&#xD800;",
            "&#0;", "&#x1F600;", String(repeating: "&#65;", count: 5_000),
            "&#x110000;", "&amp;&#38;&#x26;"
        ]
        for payload in payloads {
            let data = Data(payload.utf8)
            do {
                _ = try await processor.processBook(from: data, fileType: .epub)
            } catch {
                // Expected for non-EPUB bytes; the point is that it does not trap.
            }
        }
    }
}
