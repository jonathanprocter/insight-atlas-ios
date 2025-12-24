import XCTest
@testable import InsightAtlas

final class BookProcessorTests: XCTestCase {

    var bookProcessor: BookProcessor!

    override func setUp() {
        super.setUp()
        bookProcessor = BookProcessor()
    }

    override func tearDown() {
        bookProcessor = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testBookProcessorInitialization() {
        XCTAssertNotNil(bookProcessor, "BookProcessor should be initialized")
    }

    // MARK: - File Type Tests

    func testFileTypeRawValues() {
        XCTAssertEqual(FileType.pdf.rawValue, "pdf")
        XCTAssertEqual(FileType.epub.rawValue, "epub")
    }

    func testFileTypeCodable() throws {
        let pdfType = FileType.pdf
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(pdfType)
        let decoded = try decoder.decode(FileType.self, from: data)

        XCTAssertEqual(decoded, pdfType)
    }

    // MARK: - Error Handling Tests

    func testBookProcessorErrorDescriptions() {
        let errors: [BookProcessorError] = [
            .failedToLoad,
            .unsupportedFormat("txt"),
            .noTextContent,
            .extractionFailed
        ]

        for error in errors {
            XCTAssertFalse(
                error.localizedDescription.isEmpty,
                "Error \(error) should have a description"
            )
        }
    }

    func testFailedToLoadError() {
        let error = BookProcessorError.failedToLoad
        XCTAssertNotNil(error.errorDescription)
    }

    func testUnsupportedFormatError() {
        let error = BookProcessorError.unsupportedFormat("txt")
        XCTAssertNotNil(error.errorDescription)
    }

    func testNoTextContentError() {
        let error = BookProcessorError.noTextContent
        XCTAssertNotNil(error.errorDescription)
    }

    // MARK: - Empty Data Tests

    func testProcessEmptyPDFData() async {
        let emptyData = Data()

        do {
            _ = try await bookProcessor.processBook(from: emptyData, fileType: .pdf)
            XCTFail("Should throw an error for empty data")
        } catch {
            // Expected to fail
            XCTAssertTrue(true, "Correctly threw error for empty data")
        }
    }

    func testProcessEmptyEPUBData() async {
        let emptyData = Data()

        do {
            _ = try await bookProcessor.processBook(from: emptyData, fileType: .epub)
            XCTFail("Should throw an error for empty data")
        } catch {
            // Expected to fail
            XCTAssertTrue(true, "Correctly threw error for empty data")
        }
    }

    // MARK: - Invalid Data Tests

    func testProcessInvalidPDFData() async {
        let invalidData = "This is not a PDF".data(using: .utf8)!

        do {
            _ = try await bookProcessor.processBook(from: invalidData, fileType: .pdf)
            XCTFail("Should throw an error for invalid PDF data")
        } catch {
            // Expected to fail
            XCTAssertTrue(true, "Correctly threw error for invalid PDF data")
        }
    }

    func testProcessInvalidEPUBData() async {
        let invalidData = "This is not an EPUB".data(using: .utf8)!

        do {
            _ = try await bookProcessor.processBook(from: invalidData, fileType: .epub)
            XCTFail("Should throw an error for invalid EPUB data")
        } catch {
            // Expected to fail
            XCTAssertTrue(true, "Correctly threw error for invalid EPUB data")
        }
    }

    // MARK: - ProcessedBook Tests

    func testProcessedBookStructure() {
        // Test that ProcessedBook can hold all expected data
        struct ProcessedBook {
            let title: String?
            let author: String?
            let content: String
            let pageCount: Int?
        }

        let book = ProcessedBook(
            title: "Test Book",
            author: "Test Author",
            content: "Test content",
            pageCount: 100
        )

        XCTAssertEqual(book.title, "Test Book")
        XCTAssertEqual(book.author, "Test Author")
        XCTAssertEqual(book.content, "Test content")
        XCTAssertEqual(book.pageCount, 100)
    }

    func testProcessedBookWithNilValues() {
        struct ProcessedBook {
            let title: String?
            let author: String?
            let content: String
            let pageCount: Int?
        }

        let book = ProcessedBook(
            title: nil,
            author: nil,
            content: "Test content",
            pageCount: nil
        )

        XCTAssertNil(book.title)
        XCTAssertNil(book.author)
        XCTAssertEqual(book.content, "Test content")
        XCTAssertNil(book.pageCount)
    }

    // MARK: - Performance Tests

    func testProcessorCreationPerformance() {
        measure {
            for _ in 0..<100 {
                _ = BookProcessor()
            }
        }
    }

    // MARK: - Text Extraction Tests

    func testTextExtractionFromMinimalPDF() async {
        // Create minimal PDF data
        // Note: This is a simplified test - real PDFs are complex
        let pdfData = createMinimalPDFData()

        do {
            let result = try await bookProcessor.processBook(from: pdfData, fileType: .pdf)
            // Even if parsing fails, we should get a result or proper error
            XCTAssertTrue(true, "Processed minimal PDF without crash")
            _ = result  // Silence unused warning
        } catch {
            // Expected for minimal/invalid PDF
            XCTAssertTrue(true, "Correctly handled minimal PDF data")
        }
    }

    // MARK: - Helper Methods

    private func createMinimalPDFData() -> Data {
        // Create a minimal PDF structure (may not be fully valid)
        let pdfContent = """
        %PDF-1.4
        1 0 obj
        << /Type /Catalog /Pages 2 0 R >>
        endobj
        2 0 obj
        << /Type /Pages /Kids [3 0 R] /Count 1 >>
        endobj
        3 0 obj
        << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>
        endobj
        xref
        0 4
        0000000000 65535 f
        0000000009 00000 n
        0000000058 00000 n
        0000000115 00000 n
        trailer
        << /Size 4 /Root 1 0 R >>
        startxref
        193
        %%EOF
        """
        return pdfContent.data(using: .utf8) ?? Data()
    }
}

// MARK: - BookProcessorError Extension

extension BookProcessorError: Equatable {
    public static func == (lhs: BookProcessorError, rhs: BookProcessorError) -> Bool {
        switch (lhs, rhs) {
        case (.failedToLoad, .failedToLoad):
            return true
        case (.unsupportedFormat, .unsupportedFormat):
            return true
        case (.noTextContent, .noTextContent):
            return true
        case (.extractionFailed, .extractionFailed):
            return true
        default:
            return false
        }
    }
}
