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
        // Create test settings
        var settings = UserSettings()
        settings.preferredProvider = .claude
        
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

    func testMissingOpenRouterApiKey() async {
        // Create test settings
        var settings = UserSettings()
        settings.preferredProvider = .openRouter

        // Clear any existing key
        KeychainService.shared.openRouterApiKey = nil

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
                XCTAssertEqual(provider, "OpenRouter", "Error should indicate OpenRouter provider")
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
        XCTAssertEqual(AIProvider.openRouter.displayName, "OpenRouter")
        XCTAssertEqual(AIProvider.minimax.displayName, "MiniMax M3")
    }

    func testAllProvidersEnumerated() {
        XCTAssertEqual(AIProvider.allCases, [.minimax, .claude, .openRouter])
    }

    func testMiniMaxUsesSupportedModelAndDeepResearchBudget() {
        XCTAssertEqual(MiniMaxOAuthConfig.defaultModel, "MiniMax-M3")
        // M3 shares max_tokens with its (heavy) reasoning, so every mode gets
        // the full 64k output allowance; the M2.x family keeps the smaller
        // standard budget.
        XCTAssertEqual(
            MiniMaxOAuthConfig.outputTokenLimit(
                mode: .standard, summaryType: .professional, model: "MiniMax-M3"
            ),
            64_000
        )
        XCTAssertEqual(
            MiniMaxOAuthConfig.outputTokenLimit(
                mode: .standard, summaryType: .professional, model: "MiniMax-M2.7"
            ),
            24_000
        )
        XCTAssertEqual(
            MiniMaxOAuthConfig.outputTokenLimit(
                mode: .deepResearch, summaryType: .deepResearch, model: "MiniMax-M2.7"
            ),
            64_000
        )
        XCTAssertEqual(
            MiniMaxOAuthConfig.inputTokenLimit(
                mode: .deepResearch,
                summaryType: .deepResearch,
                model: "MiniMax-M3"
            ),
            936_000
        )
        XCTAssertEqual(
            MiniMaxOAuthConfig.inputTokenLimit(
                mode: .deepResearch,
                summaryType: .deepResearch,
                model: "MiniMax-M2.7"
            ),
            140_800
        )
    }

    func testMiniMaxOffersM3AndLegacyModelsAsChoices() {
        XCTAssertEqual(MiniMaxOAuthConfig.candidateModels.first, "MiniMax-M3")
        XCTAssertTrue(MiniMaxOAuthConfig.candidateModels.contains("MiniMax-M2.7"))
    }

    func testMiniMaxResolvedModelHonorsUserOverride() {
        let defaults = UserDefaults.standard
        let key = MiniMaxOAuthConfig.modelStorageKey
        let original = defaults.string(forKey: key)
        defer {
            if let original { defaults.set(original, forKey: key) }
            else { defaults.removeObject(forKey: key) }
        }

        defaults.removeObject(forKey: key)
        XCTAssertEqual(MiniMaxOAuthConfig.resolvedModel, "MiniMax-M3")

        defaults.set("MiniMax-M2.7", forKey: key)
        XCTAssertEqual(MiniMaxOAuthConfig.resolvedModel, "MiniMax-M2.7")
        XCTAssertEqual(AIProvider.minimax.displayName, "MiniMax M2.7")

        // A blank override falls back to the default rather than sending "".
        defaults.set("   ", forKey: key)
        XCTAssertEqual(MiniMaxOAuthConfig.resolvedModel, "MiniMax-M3")
    }

    func testMiniMaxContextWindowIsModelAware() {
        XCTAssertEqual(MiniMaxOAuthConfig.contextWindowTokens(for: "MiniMax-M3"), 1_000_000)
        XCTAssertEqual(MiniMaxOAuthConfig.contextWindowTokens(for: "MiniMax-M2.7"), 204_800)
        XCTAssertEqual(MiniMaxOAuthConfig.contextWindowTokens(for: "MiniMax-M2"), 204_800)
    }

    func testMiniMaxTokenEstimateReservesDeepResearchOutputWindow() async {
        let settings = UserSettings(
            preferredProvider: .minimax,
            preferredMode: .deepResearch,
            preferredSummaryType: .deepResearch
        )
        let estimate = await aiService.estimateInputTokens(
            bookText: "A short source.",
            title: "Test",
            author: "Author",
            settings: settings
        )

        // M3 is the default model: 1,000,000-token window less the 64,000-token
        // Deep Research output reservation.
        XCTAssertEqual(estimate.contextLimit, 936_000)
    }

    func testDeepResearchPromptIncludesRequestedLengthContract() {
        let prompt = InsightAtlasPromptGenerator.generatePrompt(
            title: "Test",
            author: "Author",
            mode: .deepResearch,
            summaryType: .deepResearch,
            targetWordCount: 9_000
        )

        XCTAssertTrue(prompt.contains("Write approximately 9000 words"))
        XCTAssertTrue(prompt.contains("never exceed 15000 words"))
    }

    // MARK: - MiniMax -> OpenRouter Fallback Policy

    func testAvailabilityFailuresFallBackToOpenRouter() {
        let retryable: [AIServiceError] = [
            .missingApiKey(provider: "MiniMax"),
            .invalidURL(provider: "MiniMax"),
            .invalidResponse,
            .apiError(statusCode: 500),
            .apiErrorWithBody(statusCode: 502, body: "bad gateway"),
            .streamError(message: "stream closed"),
            .networkError(message: "offline"),
            .rateLimitExceeded(retryAfter: 30, provider: "MiniMax")
        ]

        for error in retryable {
            XCTAssertTrue(
                AIService.shouldFallBackToOpenRouter(after: error),
                "\(error) should fall back to OpenRouter"
            )
        }
    }

    func testRequestShapedFailuresDoNotFallBack() {
        let terminal: [AIServiceError] = [
            .contentPolicyViolation(message: "blocked", provider: "MiniMax"),
            .inputTooLarge(estimatedTokens: 900_000, limit: 200_000, provider: "MiniMax"),
            .tokenEstimationWarning(estimated: 190_000, limit: 200_000, utilizationPercent: 95)
        ]

        for error in terminal {
            XCTAssertFalse(
                AIService.shouldFallBackToOpenRouter(after: error),
                "\(error) would fail identically on OpenRouter and should surface"
            )
        }
    }

    func testCancellationNeverFallsBack() {
        XCTAssertFalse(AIService.shouldFallBackToOpenRouter(after: CancellationError()))
        XCTAssertFalse(
            AIService.shouldFallBackToOpenRouter(after: URLError(.cancelled))
        )
    }

    func testUnknownErrorsAreTreatedAsAvailabilityFailures() {
        struct OAuthFailure: Error {}
        XCTAssertTrue(AIService.shouldFallBackToOpenRouter(after: OAuthFailure()))
        XCTAssertTrue(
            AIService.shouldFallBackToOpenRouter(after: URLError(.timedOut))
        )
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

    func testProviderStreamErrorIsNotSwallowed() throws {
        let json = """
        {
            "type": "error",
            "error": {
                "type": "invalid_request_error",
                "message": "model is not supported"
            }
        }
        """

        let event = try JSONDecoder().decode(
            ClaudeStreamEvent.self,
            from: XCTUnwrap(json.data(using: .utf8))
        )
        let error = AIService.providerStreamError(from: event, providerLabel: "MiniMax")

        guard case .streamError(let message) = error else {
            return XCTFail("Expected a provider stream error")
        }
        XCTAssertTrue(message.contains("model is not supported"))
    }
}

// MARK: - AIServiceError Extension for Testing

extension AIServiceError: @retroactive Equatable {
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
