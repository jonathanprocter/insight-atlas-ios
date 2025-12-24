import Foundation

/// Service for generating Insight Atlas guides using AI providers
actor AIService {

    // MARK: - Properties

    private let claudeEndpoint = "https://api.anthropic.com/v1/messages"
    private let openaiEndpoint = "https://api.openai.com/v1/chat/completions"

    private let claudeModel = "claude-sonnet-4-5-20250929"
    private let openaiModel = "gpt-4o"

    private let maxTokensClaude = 64000
    private let maxTokensOpenAI = 16000

    /// Custom URLSession with extended timeouts for long-running AI generation
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        // Extended timeouts for streaming AI responses
        config.timeoutIntervalForRequest = 300  // 5 minutes for initial connection
        config.timeoutIntervalForResource = 600 // 10 minutes for entire streaming response
        config.waitsForConnectivity = true
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        return URLSession(configuration: config)
    }()

    /// Maximum number of retry attempts for transient network errors
    private let maxRetryAttempts = 3

    /// Delay between retry attempts (in seconds)
    private let retryDelay: UInt64 = 2_000_000_000 // 2 seconds in nanoseconds

    // MARK: - Public Interface

    /// Generate an Insight Atlas guide using the specified provider
    func generateGuide(
        bookText: String,
        title: String,
        author: String,
        settings: UserSettings,
        previousContent: String? = nil,
        improvementHints: String? = nil,
        onChunk: @escaping (String) -> Void,
        onStatus: @escaping (GenerationStatus) -> Void,
        onReset: (() -> Void)? = nil
    ) async throws -> String {

        switch settings.preferredProvider {
        case .claude:
            return try await streamWithClaude(
                text: bookText,
                title: title,
                author: author,
                mode: settings.preferredMode,
                tone: settings.preferredTone,
                format: settings.preferredFormat,
                apiKey: settings.claudeApiKey ?? "",
                previousContent: previousContent,
                improvementHints: improvementHints,
                onChunk: onChunk,
                onStatus: onStatus
            )

        case .openai:
            return try await streamWithOpenAI(
                text: bookText,
                title: title,
                author: author,
                mode: settings.preferredMode,
                tone: settings.preferredTone,
                format: settings.preferredFormat,
                apiKey: settings.openaiApiKey ?? "",
                previousContent: previousContent,
                improvementHints: improvementHints,
                onChunk: onChunk,
                onStatus: onStatus
            )

        case .both:
            // Generate with both and combine (primary: Claude, secondary: OpenAI for verification)
            let claudeResult = try await streamWithClaude(
                text: bookText,
                title: title,
                author: author,
                mode: settings.preferredMode,
                tone: settings.preferredTone,
                format: settings.preferredFormat,
                apiKey: settings.claudeApiKey ?? "",
                previousContent: previousContent,
                improvementHints: improvementHints,
                onChunk: onChunk,
                onStatus: onStatus
            )

            let refinementHints = buildRefinementHints(baseHints: improvementHints)
            onStatus(GenerationStatus(
                phase: .addingInsights,
                progress: 0.0,
                wordCount: 0,
                model: "OpenAI (Refining)"
            ))
            onReset?()

            return try await streamWithOpenAI(
                text: bookText,
                title: title,
                author: author,
                mode: settings.preferredMode,
                tone: settings.preferredTone,
                format: settings.preferredFormat,
                apiKey: settings.openaiApiKey ?? "",
                previousContent: claudeResult,
                improvementHints: refinementHints,
                onChunk: onChunk,
                onStatus: onStatus
            )
        }
    }

    // MARK: - Claude Integration

    private func streamWithClaude(
        text: String,
        title: String,
        author: String,
        mode: GenerationMode,
        tone: ToneMode,
        format: OutputFormat,
        apiKey: String,
        previousContent: String? = nil,
        improvementHints: String? = nil,
        onChunk: @escaping (String) -> Void,
        onStatus: @escaping (GenerationStatus) -> Void
    ) async throws -> String {

        guard !apiKey.isEmpty else {
            throw AIServiceError.missingApiKey(provider: "Claude")
        }

        let isIteration = previousContent != nil && improvementHints != nil

        onStatus(GenerationStatus(
            phase: isIteration ? .addingInsights : .analyzing,
            progress: 0.0,
            wordCount: 0,
            model: isIteration ? "Claude (Improving)" : "Claude"
        ))

        let systemPrompt = InsightAtlasPromptGenerator.generatePrompt(
            title: title,
            author: author,
            mode: mode,
            tone: tone,
            format: format
        )

        // Build the user message - either fresh generation or improvement iteration
        var userMessage: String
        if let previous = previousContent, let hints = improvementHints {
            // Improvement iteration: ask to enhance the existing content
            userMessage = """
            I previously generated the following Insight Atlas guide for "\(title)" by \(author), but it didn't meet quality requirements.

            \(hints)

            Please improve and expand the following guide to address these issues. Maintain all existing good content while adding the missing sections and improving quality. Do NOT start from scratch - build upon and enhance this existing content:

            ---PREVIOUS GUIDE START---
            \(previous)
            ---PREVIOUS GUIDE END---

            Generate an improved, complete guide that addresses all the missing elements while preserving the valuable insights already present.
            """
        } else {
            userMessage = InsightAtlasPromptGenerator.generateUserMessage(
                title: title,
                author: author,
                bookText: text
            )
        }

        var request = URLRequest(url: URL(string: claudeEndpoint)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let requestBody = ClaudeRequest(
            model: claudeModel,
            max_tokens: maxTokensClaude,
            stream: true,
            system: systemPrompt,
            messages: [
                ClaudeMessage(role: "user", content: userMessage)
            ]
        )

        request.httpBody = try JSONEncoder().encode(requestBody)

        // Attempt streaming with retry logic for transient network errors
        var lastError: Error?
        var fullText = ""

        for attempt in 1...maxRetryAttempts {
            do {
                fullText = try await performClaudeStream(
                    request: request,
                    onChunk: onChunk,
                    onStatus: onStatus
                )
                return fullText
            } catch let error as URLError where isRetryableError(error) {
                lastError = error
                if attempt < maxRetryAttempts {
                    onStatus(GenerationStatus(
                        phase: .analyzing,
                        progress: 0.0,
                        wordCount: 0,
                        model: "Claude (retry \(attempt)/\(maxRetryAttempts))"
                    ))
                    try await Task.sleep(nanoseconds: retryDelay * UInt64(attempt))
                }
            } catch {
                throw error
            }
        }

        throw lastError ?? AIServiceError.networkError(message: "Failed after \(maxRetryAttempts) attempts")
    }

    /// Performs the actual Claude streaming request
    private func performClaudeStream(
        request: URLRequest,
        onChunk: @escaping (String) -> Void,
        onStatus: @escaping (GenerationStatus) -> Void
    ) async throws -> String {

        let (asyncBytes, response) = try await urlSession.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            // Read error response body for better debugging
            var errorBody = ""
            for try await line in asyncBytes.lines {
                errorBody += line
                if errorBody.count > 1000 { break }
            }
            throw AIServiceError.apiErrorWithBody(statusCode: httpResponse.statusCode, body: errorBody)
        }

        var fullText = ""
        var wordCount = 0
        var lastPhaseUpdate = 0

        for try await line in asyncBytes.lines {
            if line.hasPrefix("data: ") {
                let data = String(line.dropFirst(6))

                if data == "[DONE]" { continue }

                if let jsonData = data.data(using: .utf8),
                   let event = try? JSONDecoder().decode(ClaudeStreamEvent.self, from: jsonData),
                   let text = event.delta?.text {

                    fullText += text
                    onChunk(text)

                    wordCount = fullText.split(separator: " ").count

                    if wordCount > lastPhaseUpdate + 1000 {
                        lastPhaseUpdate = wordCount
                        let phase = determinePhase(wordCount: wordCount)
                        let progress = min(Double(wordCount) / 15000.0, 0.95)

                        onStatus(GenerationStatus(
                            phase: phase,
                            progress: progress,
                            wordCount: wordCount,
                            model: "Claude"
                        ))
                    }
                }
            }
        }

        onStatus(GenerationStatus(
            phase: .complete,
            progress: 1.0,
            wordCount: wordCount,
            model: "Claude"
        ))

        return fullText
    }

    // MARK: - OpenAI Integration

    private func streamWithOpenAI(
        text: String,
        title: String,
        author: String,
        mode: GenerationMode,
        tone: ToneMode,
        format: OutputFormat,
        apiKey: String,
        previousContent: String? = nil,
        improvementHints: String? = nil,
        onChunk: @escaping (String) -> Void,
        onStatus: @escaping (GenerationStatus) -> Void
    ) async throws -> String {

        guard !apiKey.isEmpty else {
            throw AIServiceError.missingApiKey(provider: "OpenAI")
        }

        let isIteration = previousContent != nil && improvementHints != nil

        onStatus(GenerationStatus(
            phase: isIteration ? .addingInsights : .analyzing,
            progress: 0.0,
            wordCount: 0,
            model: isIteration ? "OpenAI (Improving)" : "OpenAI"
        ))

        let systemPrompt = InsightAtlasPromptGenerator.generatePrompt(
            title: title,
            author: author,
            mode: mode,
            tone: tone,
            format: format
        )

        // Build the user message - either fresh generation or improvement iteration
        var userMessage: String
        if let previous = previousContent, let hints = improvementHints {
            // Improvement iteration: ask to enhance the existing content
            userMessage = """
            I previously generated the following Insight Atlas guide for "\(title)" by \(author), but it didn't meet quality requirements.

            \(hints)

            Please improve and expand the following guide to address these issues. Maintain all existing good content while adding the missing sections and improving quality. Do NOT start from scratch - build upon and enhance this existing content:

            ---PREVIOUS GUIDE START---
            \(previous)
            ---PREVIOUS GUIDE END---

            Generate an improved, complete guide that addresses all the missing elements while preserving the valuable insights already present.
            """
        } else {
            userMessage = InsightAtlasPromptGenerator.generateUserMessage(
                title: title,
                author: author,
                bookText: text
            )
        }

        var request = URLRequest(url: URL(string: openaiEndpoint)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let requestBody: [String: Any] = [
            "model": openaiModel,
            "max_tokens": maxTokensOpenAI,
            "stream": true,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userMessage]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        // Attempt streaming with retry logic for transient network errors
        var lastError: Error?
        var fullText = ""

        for attempt in 1...maxRetryAttempts {
            do {
                fullText = try await performOpenAIStream(
                    request: request,
                    onChunk: onChunk,
                    onStatus: onStatus
                )
                return fullText
            } catch let error as URLError where isRetryableError(error) {
                lastError = error
                if attempt < maxRetryAttempts {
                    onStatus(GenerationStatus(
                        phase: .analyzing,
                        progress: 0.0,
                        wordCount: 0,
                        model: "OpenAI (retry \(attempt)/\(maxRetryAttempts))"
                    ))
                    try await Task.sleep(nanoseconds: retryDelay * UInt64(attempt))
                }
            } catch {
                throw error
            }
        }

        throw lastError ?? AIServiceError.networkError(message: "Failed after \(maxRetryAttempts) attempts")
    }

    /// Performs the actual OpenAI streaming request
    private func performOpenAIStream(
        request: URLRequest,
        onChunk: @escaping (String) -> Void,
        onStatus: @escaping (GenerationStatus) -> Void
    ) async throws -> String {

        let (asyncBytes, response) = try await urlSession.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw AIServiceError.apiError(statusCode: httpResponse.statusCode)
        }

        var fullText = ""
        var wordCount = 0
        var lastPhaseUpdate = 0

        for try await line in asyncBytes.lines {
            if line.hasPrefix("data: ") {
                let data = String(line.dropFirst(6))

                if data == "[DONE]" { continue }

                if let jsonData = data.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let delta = choices.first?["delta"] as? [String: Any],
                   let content = delta["content"] as? String {

                    fullText += content
                    onChunk(content)

                    wordCount = fullText.split(separator: " ").count

                    if wordCount > lastPhaseUpdate + 1000 {
                        lastPhaseUpdate = wordCount
                        let phase = determinePhase(wordCount: wordCount)
                        let progress = min(Double(wordCount) / 15000.0, 0.95)

                        onStatus(GenerationStatus(
                            phase: phase,
                            progress: progress,
                            wordCount: wordCount,
                            model: "OpenAI"
                        ))
                    }
                }
            }
        }

        onStatus(GenerationStatus(
            phase: .complete,
            progress: 1.0,
            wordCount: wordCount,
            model: "OpenAI"
        ))

        return fullText
    }

    // MARK: - Helpers

    private func buildRefinementHints(baseHints: String?) -> String {
        let formattingHints = """
        Refine formatting and structural consistency:
        - Ensure all block markers are properly opened/closed
        - Keep headings and visual tags in the correct order
        - Preserve all substantive content while improving clarity
        - Fix any malformed Markdown/HTML tags
        """
        if let base = baseHints, !base.isEmpty {
            return base + "\n\n" + formattingHints
        }
        return formattingHints
    }

    private func determinePhase(wordCount: Int) -> GenerationPhase {
        switch wordCount {
        case 0..<2000:
            return .structuring
        case 2000..<5000:
            return .writing
        case 5000..<10000:
            return .addingInsights
        default:
            return .finalizing
        }
    }

    /// Determines if a URLError is retryable (transient network issues)
    private func isRetryableError(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut,                     // Request timed out
             .networkConnectionLost,         // Network connection was lost
             .notConnectedToInternet,        // No internet connection
             .cannotConnectToHost,           // Cannot connect to host
             .cannotFindHost,                // DNS lookup failed
             .dnsLookupFailed,               // DNS lookup failed
             .internationalRoamingOff,       // International roaming is off
             .dataNotAllowed,                // Cellular data not allowed
             .secureConnectionFailed:        // SSL/TLS handshake failed
            return true
        default:
            return false
        }
    }
}

// MARK: - Errors

enum AIServiceError: LocalizedError {
    case missingApiKey(provider: String)
    case invalidResponse
    case apiError(statusCode: Int)
    case apiErrorWithBody(statusCode: Int, body: String)
    case streamError(message: String)
    case networkError(message: String)

    var errorDescription: String? {
        switch self {
        case .missingApiKey(let provider):
            return "\(provider) API key is missing. Please add it in Settings."
        case .invalidResponse:
            return "Received an invalid response from the API."
        case .apiError(let statusCode):
            return "API error with status code: \(statusCode)"
        case .apiErrorWithBody(let statusCode, let body):
            // Parse the error body to extract meaningful message
            if let data = body.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                return "API error (\(statusCode)): \(message)"
            }
            return "API error (\(statusCode)): \(body.prefix(200))"
        case .streamError(let message):
            return "Stream error: \(message)"
        case .networkError(let message):
            return "Network error: \(message). Please check your internet connection and try again."
        }
    }
}
