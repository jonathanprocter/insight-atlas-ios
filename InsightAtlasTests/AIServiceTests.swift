import XCTest
@testable import InsightAtlas

final class AIServiceTests: XCTestCase {

    var aiService: AIService!

    override func setUp() {
        super.setUp()
        aiService = AIService()
    }

    override func tearDown() {
        aiService = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testAIServiceInitialization() async {
        // AIService should initialize without errors
        XCTAssertNotNil(aiService, "AIService should be initialized")
    }

    // MARK: - API Key Validation Tests

    func testMissingClaudeApiKey() async {
        let settings = UserSettings(preferredProvider: .claude)
        // Clear any existing key
        KeychainService.shared.claudeApiKey = nil

        var receivedChunks: [String] = []
        var receivedStatuses: [GenerationStatus] = []

        do {
            _ = try await aiService.generateGuide(
                bookText: "Test content",
                title: "Test Title",
                author: "Test Author",
                settings: settings,
                onChunk: { chunk in receivedChunks.append(chunk) },
                onStatus: { status in receivedStatuses.append(status) }
            )
            XCTFail("Should throw an error for missing API key")
        } catch let error as AIServiceError {
            if case .missingApiKey(let provider) = error {
                XCTAssertEqual(provider, "Claude", "Error should indicate Claude provider")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testMissingOpenAIApiKey() async {
        let settings = UserSettings(preferredProvider: .openai)
        // Clear any existing key
        KeychainService.shared.openaiApiKey = nil

        var receivedChunks: [String] = []
        var receivedStatuses: [GenerationStatus] = []

        do {
            _ = try await aiService.generateGuide(
                bookText: "Test content",
                title: "Test Title",
                author: "Test Author",
                settings: settings,
                onChunk: { chunk in receivedChunks.append(chunk) },
                onStatus: { status in receivedStatuses.append(status) }
            )
            XCTFail("Should throw an error for missing API key")
        } catch let error as AIServiceError {
            if case .missingApiKey(let provider) = error {
                XCTAssertEqual(provider, "OpenAI", "Error should indicate OpenAI provider")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Error Handling Tests

    func testAIServiceErrorDescriptions() {
        let errors: [(AIServiceError, String)] = [
            (.missingApiKey(provider: "Claude"), "Claude"),
            (.invalidResponse, "Invalid response"),
            (.networkError(message: "Connection failed"), "Connection failed"),
        ]

        for (error, expectedSubstring) in errors {
            let description = error.localizedDescription
            XCTAssertTrue(
                description.lowercased().contains(expectedSubstring.lowercased()),
                "Error description '\(description)' should contain '\(expectedSubstring)'"
            )
        }
    }

    // MARK: - Status Tracking Tests

    func testGenerationPhaseDescriptions() {
        let phases: [GenerationPhase] = [
            .analyzing,
            .structuring,
            .writing,
            .addingInsights,
            .finalizing,
            .complete,
            .error
        ]

        for phase in phases {
            XCTAssertFalse(phase.rawValue.isEmpty, "Phase \(phase) should have a description")
        }
    }

    func testGenerationStatusCreation() {
        let status = GenerationStatus(
            phase: .analyzing,
            progress: 0.5,
            wordCount: 1000,
            model: "Claude"
        )

        XCTAssertEqual(status.phase, .analyzing)
        XCTAssertEqual(status.progress, 0.5)
        XCTAssertEqual(status.wordCount, 1000)
        XCTAssertEqual(status.model, "Claude")
        XCTAssertNil(status.error)
    }

    func testGenerationStatusWithError() {
        var status = GenerationStatus(
            phase: .error,
            progress: 0.0,
            wordCount: 0,
            model: "Claude"
        )
        status.error = "Network timeout"

        XCTAssertEqual(status.phase, .error)
        XCTAssertEqual(status.error, "Network timeout")
    }

    // MARK: - Provider Selection Tests

    func testProviderDisplayNames() {
        XCTAssertEqual(AIProvider.claude.displayName, "Claude")
        XCTAssertEqual(AIProvider.openai.displayName, "OpenAI")
        XCTAssertEqual(AIProvider.both.displayName, "Both")
    }

    func testAllProvidersEnumerated() {
        let allProviders = AIProvider.allCases
        XCTAssertEqual(allProviders.count, 3, "Should have 3 providers")
        XCTAssertTrue(allProviders.contains(.claude))
        XCTAssertTrue(allProviders.contains(.openai))
        XCTAssertTrue(allProviders.contains(.both))
    }

    // MARK: - Request Model Tests

    func testClaudeRequestEncoding() throws {
        let request = ClaudeRequest(
            model: "claude-sonnet-4-5-20250929",
            max_tokens: 64000,
            stream: true,
            system: "You are a helpful assistant.",
            messages: [
                ClaudeMessage(role: "user", content: "Hello")
            ]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["model"] as? String, "claude-sonnet-4-5-20250929")
        XCTAssertEqual(json?["max_tokens"] as? Int, 64000)
        XCTAssertEqual(json?["stream"] as? Bool, true)
        XCTAssertEqual(json?["system"] as? String, "You are a helpful assistant.")
    }

    func testClaudeMessageEncoding() throws {
        let message = ClaudeMessage(role: "user", content: "Test message")

        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        let decoded = try JSONDecoder().decode(ClaudeMessage.self, from: data)

        XCTAssertEqual(decoded.role, "user")
        XCTAssertEqual(decoded.content, "Test message")
    }

    func testClaudeStreamEventDecoding() throws {
        let json = """
        {
            "type": "content_block_delta",
            "delta": {
                "text": "Hello world"
            }
        }
        """

        let data = json.data(using: .utf8)!
        let event = try JSONDecoder().decode(ClaudeStreamEvent.self, from: data)

        XCTAssertEqual(event.type, "content_block_delta")
        XCTAssertEqual(event.delta?.text, "Hello world")
    }

    func testClaudeStreamEventWithoutDelta() throws {
        let json = """
        {
            "type": "message_start"
        }
        """

        let data = json.data(using: .utf8)!
        let event = try JSONDecoder().decode(ClaudeStreamEvent.self, from: data)

        XCTAssertEqual(event.type, "message_start")
        XCTAssertNil(event.delta)
    }
}

// MARK: - AIServiceError Extension for Testing

extension AIServiceError: Equatable {
    public static func == (lhs: AIServiceError, rhs: AIServiceError) -> Bool {
        switch (lhs, rhs) {
        case (.missingApiKey(let l), .missingApiKey(let r)):
            return l == r
        case (.invalidResponse, .invalidResponse):
            return true
        case (.networkError(let l), .networkError(let r)):
            return l == r
        case (.apiErrorWithBody(let lCode, let lBody), .apiErrorWithBody(let rCode, let rBody)):
            return lCode == rCode && lBody == rBody
        default:
            return false
        }
    }
}
