import Foundation
import os.log

/// Service for generating Insight Atlas guides using AI providers
actor AIService {

    // MARK: - Logging

    private static let logger = Logger(subsystem: "com.insightatlas", category: "AIService")

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

    /// Context window limits (approximate, leaving room for output)
    /// Claude Sonnet: ~200K context, we reserve 64K for output
    private let claudeContextLimit = 120_000
    /// OpenAI GPT-4o: ~128K context, we reserve 16K for output
    private let openaiContextLimit = 100_000

    // MARK: - Token Estimation

    /// Estimates token count for text using a simple heuristic.
    /// Approximately 4 characters per token for English text.
    /// This is a conservative estimate (actual may be lower).
    func estimateTokenCount(for text: String) -> Int {
        // Simple heuristic: ~4 chars per token for English
        // More conservative than the actual ~3.5-4 ratio to avoid surprises
        return max(1, text.count / 4)
    }

    /// Estimates total input tokens for a generation request.
    /// Includes system prompt, user message, and book text.
    func estimateInputTokens(
        bookText: String,
        title: String,
        author: String,
        settings: UserSettings
    ) -> TokenEstimate {
        let systemPrompt = InsightAtlasPromptGenerator.generatePrompt(
            title: title,
            author: author,
            mode: settings.preferredMode,
            tone: settings.preferredTone,
            format: settings.preferredFormat
        )

        let userMessage = InsightAtlasPromptGenerator.generateUserMessage(
            title: title,
            author: author,
            bookText: bookText,
            format: settings.preferredFormat
        )

        let systemTokens = estimateTokenCount(for: systemPrompt)
        let userTokens = estimateTokenCount(for: userMessage)
        let totalTokens = systemTokens + userTokens

        let contextLimit = settings.preferredProvider == .openai ? openaiContextLimit : claudeContextLimit

        return TokenEstimate(
            systemPromptTokens: systemTokens,
            userMessageTokens: userTokens,
            totalInputTokens: totalTokens,
            contextLimit: contextLimit,
            exceedsLimit: totalTokens > contextLimit,
            utilizationPercent: Double(totalTokens) / Double(contextLimit) * 100
        )
    }

    /// Validates that the input will fit within context limits.
    /// Throws if the input is too large for the selected provider.
    func validateInputSize(
        bookText: String,
        title: String,
        author: String,
        settings: UserSettings
    ) throws {
        let estimate = estimateInputTokens(
            bookText: bookText,
            title: title,
            author: author,
            settings: settings
        )

        if estimate.exceedsLimit {
            throw AIServiceError.inputTooLarge(
                estimatedTokens: estimate.totalInputTokens,
                limit: estimate.contextLimit,
                provider: settings.preferredProvider == .openai ? "OpenAI" : "Claude"
            )
        }

        // Warn if utilization is very high (>80%)
        if estimate.utilizationPercent > 80 {
            Self.logger.warning("High context utilization: \(String(format: "%.1f", estimate.utilizationPercent))% for \(title)")
        }
    }

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
        onReset: (() -> Void)? = nil,
        shouldTerminate: (() -> Bool)? = nil
    ) async throws -> String {

        // Pre-flight validation: check input size before making API call
        // Skip for continuation/improvement requests which use smaller input
        if previousContent == nil {
            try validateInputSize(
                bookText: bookText,
                title: title,
                author: author,
                settings: settings
            )
        }

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
                onStatus: onStatus,
                shouldTerminate: shouldTerminate
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
                onStatus: onStatus,
                shouldTerminate: shouldTerminate
            )

        case .both:
            // Primary on Claude, fallback to OpenAI only if Claude fails.
            do {
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
                    onStatus: onStatus,
                    shouldTerminate: shouldTerminate
                )
            } catch {
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
                    onStatus: onStatus,
                    shouldTerminate: shouldTerminate
                )
            }
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
        onStatus: @escaping (GenerationStatus) -> Void,
        shouldTerminate: (() -> Bool)? = nil
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
        if let previous = previousContent {
            if let hints = improvementHints {
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
                // Resume continuation: continue from the last sentence without repeating
                userMessage = """
                Continue the following Insight Atlas guide for "\(title)" by \(author) from exactly where it left off.
                Do NOT repeat prior content. Preserve the existing structure and block markers.
                Continue after the last sentence and complete any remaining sections.

                ---PREVIOUS GUIDE START---
                \(previous)
                ---PREVIOUS GUIDE END---
                """
            }
        } else {
            userMessage = InsightAtlasPromptGenerator.generateUserMessage(
                title: title,
                author: author,
                bookText: text,
                format: format
            )
        }

        guard let claudeURL = URL(string: claudeEndpoint) else {
            throw AIServiceError.invalidURL(provider: "Claude")
        }
        var request = URLRequest(url: claudeURL)
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
            if shouldTerminate?() == true {
                return fullText
            }
            do {
                fullText = ""
                let trackingOnChunk: (String) -> Void = { chunk in
                    fullText += chunk
                    onChunk(chunk)
                }
                let streamed = try await performClaudeStream(
                    request: request,
                    onChunk: trackingOnChunk,
                    onStatus: onStatus,
                    shouldTerminate: shouldTerminate
                )
                return streamed
            } catch let error as URLError where isRetryableError(error) {
                if shouldTerminate?() == true {
                    return fullText
                }
                if !fullText.isEmpty {
                    return fullText
                }
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
                if shouldTerminate?() == true {
                    return fullText
                }
                throw error
            }
        }

        throw lastError ?? AIServiceError.networkError(message: "Failed after \(maxRetryAttempts) attempts")
    }

    /// Performs the actual Claude streaming request
    private func performClaudeStream(
        request: URLRequest,
        onChunk: @escaping (String) -> Void,
        onStatus: @escaping (GenerationStatus) -> Void,
        shouldTerminate: (() -> Bool)? = nil
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
        var lastCharWasWhitespace = true
        var lastPhaseUpdate = 0

        for try await line in asyncBytes.lines {
            if shouldTerminate?() == true {
                asyncBytes.task.cancel()
                return fullText
            }
            if line.hasPrefix("data: ") {
                let data = String(line.dropFirst(6))

                if data == "[DONE]" { continue }

                guard let jsonData = data.data(using: .utf8) else {
                    Self.logger.warning("Claude stream: Failed to convert line to UTF-8 data: \(data.prefix(100))")
                    continue
                }

                do {
                    let event = try JSONDecoder().decode(ClaudeStreamEvent.self, from: jsonData)

                    // Handle different event types
                    guard let text = event.delta?.text else {
                        // Not all events have delta text (e.g., message_start, content_block_start)
                        // This is normal, not an error
                        continue
                    }

                    if shouldTerminate?() == true {
                        asyncBytes.task.cancel()
                        return fullText
                    }

                    fullText += text
                    onChunk(text)

                    updateWordCount(for: text, currentCount: &wordCount, lastCharWasWhitespace: &lastCharWasWhitespace)

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
                } catch {
                    // Log the decode error with context for debugging
                    Self.logger.error("Claude stream: JSON decode failed - \(error.localizedDescription). Data: \(data.prefix(200))")
                    // Continue processing - don't fail the entire stream for one bad event
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
        onStatus: @escaping (GenerationStatus) -> Void,
        shouldTerminate: (() -> Bool)? = nil
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
        if let previous = previousContent {
            if let hints = improvementHints {
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
                // Resume continuation: continue from the last sentence without repeating
                userMessage = """
                Continue the following Insight Atlas guide for "\(title)" by \(author) from exactly where it left off.
                Do NOT repeat prior content. Preserve the existing structure and block markers.
                Continue after the last sentence and complete any remaining sections.

                ---PREVIOUS GUIDE START---
                \(previous)
                ---PREVIOUS GUIDE END---
                """
            }
        } else {
            userMessage = InsightAtlasPromptGenerator.generateUserMessage(
                title: title,
                author: author,
                bookText: text,
                format: format
            )
        }

        guard let openaiURL = URL(string: openaiEndpoint) else {
            throw AIServiceError.invalidURL(provider: "OpenAI")
        }
        var request = URLRequest(url: openaiURL)
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
            if shouldTerminate?() == true {
                return fullText
            }
            do {
                fullText = ""
                let trackingOnChunk: (String) -> Void = { chunk in
                    fullText += chunk
                    onChunk(chunk)
                }
                let streamed = try await performOpenAIStream(
                    request: request,
                    onChunk: trackingOnChunk,
                    onStatus: onStatus,
                    shouldTerminate: shouldTerminate
                )
                return streamed
            } catch let error as URLError where isRetryableError(error) {
                if shouldTerminate?() == true {
                    return fullText
                }
                if !fullText.isEmpty {
                    return fullText
                }
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
                if shouldTerminate?() == true {
                    return fullText
                }
                throw error
            }
        }

        throw lastError ?? AIServiceError.networkError(message: "Failed after \(maxRetryAttempts) attempts")
    }

    /// Performs the actual OpenAI streaming request
    private func performOpenAIStream(
        request: URLRequest,
        onChunk: @escaping (String) -> Void,
        onStatus: @escaping (GenerationStatus) -> Void,
        shouldTerminate: (() -> Bool)? = nil
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
        var lastCharWasWhitespace = true
        var lastPhaseUpdate = 0

        for try await line in asyncBytes.lines {
            if shouldTerminate?() == true {
                asyncBytes.task.cancel()
                return fullText
            }
            if line.hasPrefix("data: ") {
                let data = String(line.dropFirst(6))

                if data == "[DONE]" { continue }

                guard let jsonData = data.data(using: .utf8) else {
                    Self.logger.warning("OpenAI stream: Failed to convert line to UTF-8 data: \(data.prefix(100))")
                    continue
                }

                do {
                    guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                        Self.logger.warning("OpenAI stream: Response is not a dictionary")
                        continue
                    }

                    // Check for error responses
                    if let error = json["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        Self.logger.error("OpenAI stream: API error - \(message)")
                        continue
                    }

                    guard let choices = json["choices"] as? [[String: Any]],
                          let delta = choices.first?["delta"] as? [String: Any] else {
                        // Some events don't have choices (e.g., stream start)
                        continue
                    }

                    // Content may be nil for role-only deltas
                    guard let content = delta["content"] as? String else {
                        continue
                    }

                    if shouldTerminate?() == true {
                        asyncBytes.task.cancel()
                        return fullText
                    }

                    fullText += content
                    onChunk(content)

                    updateWordCount(for: content, currentCount: &wordCount, lastCharWasWhitespace: &lastCharWasWhitespace)

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
                } catch {
                    Self.logger.error("OpenAI stream: JSON parse failed - \(error.localizedDescription). Data: \(data.prefix(200))")
                    // Continue processing - don't fail the entire stream for one bad event
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

    private func updateWordCount(for chunk: String, currentCount: inout Int, lastCharWasWhitespace: inout Bool) {
        for character in chunk {
            if character.isWhitespace {
                lastCharWasWhitespace = true
            } else if lastCharWasWhitespace {
                currentCount += 1
                lastCharWasWhitespace = false
            }
        }
    }

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
    case invalidURL(provider: String)
    case invalidResponse
    case apiError(statusCode: Int)
    case apiErrorWithBody(statusCode: Int, body: String)
    case streamError(message: String)
    case networkError(message: String)
    case inputTooLarge(estimatedTokens: Int, limit: Int, provider: String)

    var errorDescription: String? {
        switch self {
        case .missingApiKey(let provider):
            return "\(provider) API key is missing. Please add it in Settings."
        case .invalidURL(let provider):
            return "\(provider) API endpoint URL is invalid."
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
        case .inputTooLarge(let estimatedTokens, let limit, let provider):
            let formatted = NumberFormatter.localizedString(from: NSNumber(value: estimatedTokens), number: .decimal)
            let limitFormatted = NumberFormatter.localizedString(from: NSNumber(value: limit), number: .decimal)
            return "This book is too large for \(provider) (~\(formatted) tokens, limit: \(limitFormatted)). Try a shorter book or switch to Claude for larger context."
        }
    }
}

// MARK: - Token Estimation Models

/// Represents an estimate of token usage for an AI request
struct TokenEstimate {
    /// Estimated tokens in the system prompt
    let systemPromptTokens: Int

    /// Estimated tokens in the user message (includes book text)
    let userMessageTokens: Int

    /// Total estimated input tokens
    let totalInputTokens: Int

    /// Context window limit for the provider
    let contextLimit: Int

    /// Whether the input exceeds the context limit
    let exceedsLimit: Bool

    /// Percentage of context window being used (0-100+)
    let utilizationPercent: Double

    /// Formatted string describing the estimate
    var description: String {
        let formatted = NumberFormatter.localizedString(from: NSNumber(value: totalInputTokens), number: .decimal)
        return "~\(formatted) tokens (\(String(format: "%.0f", utilizationPercent))% of limit)"
    }
}
