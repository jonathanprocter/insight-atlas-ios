import Foundation
import os.log

/// OpenRouter is an OpenAI-compatible gateway to many models (Anthropic,
/// Google, Meta, …) behind a single API key and billing account.
enum OpenRouterConfig {
    static let endpoint = "https://openrouter.ai/api/v1/chat/completions"

    /// UserDefaults key backing the user-selected OpenRouter model slug.
    static let modelStorageKey = "insight_atlas_openrouter_model"

    static let defaultModel = "anthropic/claude-opus-4.1"

    /// Suggested model slugs offered in Settings; users may type any valid slug.
    static let candidateModels = [
        "anthropic/claude-opus-4.1",
        "anthropic/claude-sonnet-4",
        "anthropic/claude-3.5-sonnet",
        "google/gemini-2.0-flash-001",
        "meta-llama/llama-3.3-70b-instruct"
    ]

    /// The model slug to send: a non-empty user override, otherwise the default.
    static var resolvedModel: String {
        let stored = UserDefaults.standard.string(forKey: modelStorageKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let stored, !stored.isEmpty { return stored }
        return defaultModel
    }
}

/// Service for generating Insight Atlas guides using AI providers
actor AIService {

    // MARK: - Logging

    private static let logger = Logger(subsystem: "com.insightatlas", category: "AIService")

    // MARK: - Properties

    private let claudeEndpoint = "https://api.anthropic.com/v1/messages"
    private let openRouterEndpoint = OpenRouterConfig.endpoint

    private let claudeModel = "claude-sonnet-4-20250514"  // Sonnet 4: 64K output, excellent quality

    private let maxTokensClaude = 64000  // Claude Sonnet 4 max output tokens

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

    /// Base delay for exponential backoff (in seconds)
    private let baseRetryDelay: Double = 2.0

    /// Maximum delay for exponential backoff (in seconds)
    private let maxRetryDelay: Double = 30.0

    /// Calculate retry delay using exponential backoff
    /// - Parameter attempt: Current attempt number (1-based)
    /// - Returns: Delay in nanoseconds
    private func calculateRetryDelay(attempt: Int) -> UInt64 {
        let exponentialDelay = baseRetryDelay * pow(2.0, Double(attempt - 1))
        let clampedDelay = min(exponentialDelay, maxRetryDelay)
        return UInt64(clampedDelay * 1_000_000_000) // Convert to nanoseconds
    }

    /// Context window limits (approximate, leaving room for output)
    /// Claude Sonnet 4: 200K context, we reserve 20K for output (max_tokens)
    private let claudeContextLimit = 180_000
    /// OpenRouter: generous limit to accommodate various models
    private let openRouterContextLimit = 500_000

    // MARK: - Token Estimation

    /// Estimates token count for text using an improved heuristic.
    /// Accounts for code blocks (higher token density) and non-English text.
    /// This is a conservative estimate (actual may be lower).
    func estimateTokenCount(for text: String) -> Int {
        // Improved heuristic based on content type
        var charPerToken: Double = 4.0

        // Adjust for code blocks (higher token density)
        if text.contains("```") || text.contains("    ") {
            charPerToken = 3.0
        }

        // Adjust for non-English text (varies by language)
        // CJK languages use fewer chars per token
        let nonAsciiRatio = Double(text.unicodeScalars.filter { !$0.isASCII }.count) / max(Double(text.count), 1.0)
        if nonAsciiRatio > 0.3 {
            charPerToken = 2.5 // CJK languages use fewer chars per token
        }

        let estimatedTokens = Int(Double(text.count) / charPerToken)
        return max(1, estimatedTokens)
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

        let contextLimit: Int
        switch settings.preferredProvider {
        case .openRouter:
            contextLimit = openRouterContextLimit
        case .claude:
            contextLimit = claudeContextLimit
        }

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
            let providerName: String
            switch settings.preferredProvider {
            case .claude:
                providerName = "Claude"
            case .openRouter:
                providerName = "OpenRouter"
            }
            throw AIServiceError.inputTooLarge(
                estimatedTokens: estimate.totalInputTokens,
                limit: estimate.contextLimit,
                provider: providerName
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

        case .openRouter:
            return try await streamWithCompatibleAPI(
                text: bookText,
                title: title,
                author: author,
                mode: settings.preferredMode,
                tone: settings.preferredTone,
                format: settings.preferredFormat,
                apiKey: settings.openRouterApiKey ?? "",
                endpoint: openRouterEndpoint,
                model: OpenRouterConfig.resolvedModel,
                maxTokens: 16000,  // safe across OpenRouter models (e.g. gpt-4o caps at 16384)
                providerLabel: "OpenRouter",
                previousContent: previousContent,
                improvementHints: improvementHints,
                onChunk: onChunk,
                onStatus: onStatus,
                shouldTerminate: shouldTerminate
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
                let bookContext: String
                if text.isEmpty {
                    bookContext = ""
                } else {
                    bookContext = """

                    ---BOOK TEXT START---
                    \(text)
                    ---BOOK TEXT END---
                    """
                }
                // Improvement iteration: ask to enhance the existing content
                userMessage = """
                I previously generated the following Insight Atlas guide for "\(title)" by \(author), but it didn't meet quality requirements.

                \(hints)

                \(bookContext)

                Revise the guide below into a SINGLE, complete, deduplicated guide that fixes these issues. Build on the existing content and rewrite/expand sections IN PLACE — do not append a second version of anything.

                HARD RULES (critical):
                - Output exactly ONE pass through the material. Every section heading appears EXACTLY ONCE.
                - Do NOT produce both a summary/overview version and a detailed/expanded version of the same section. The Quick Glance is the ONLY summary permitted; after it, each concept is covered exactly once.
                - When you expand or improve a section, REPLACE the original text — never leave the original section AND an expanded copy.
                - Do not restate the Executive Synthesis, Story Behind the Ideas, Periodic Table, Poker Game, Takeaways, or Conclusion more than once.
                - Preserve all block markers and the overall structure.

                ---PREVIOUS GUIDE START---
                \(previous)
                ---PREVIOUS GUIDE END---

                Return the full revised guide — complete, non-repeating, each section exactly once — from Quick Glance through Conclusion.
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
        var accumulatedChunks: [String] = []

        for attempt in 1...maxRetryAttempts {
            if shouldTerminate?() == true {
                return accumulatedChunks.joined()
            }
            do {
                accumulatedChunks = []
                let trackingOnChunk: (String) -> Void = { chunk in
                    accumulatedChunks.append(chunk)
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
                    return accumulatedChunks.joined()
                }
                if !accumulatedChunks.isEmpty {
                    return accumulatedChunks.joined()
                }
                lastError = error
                if attempt < maxRetryAttempts {
                    let delay = calculateRetryDelay(attempt: attempt)
                    let delaySeconds = Int(delay / 1_000_000_000)
                    onStatus(GenerationStatus(
                        phase: .analyzing,
                        progress: 0.0,
                        wordCount: 0,
                        model: "Claude (retrying in \(delaySeconds)s - attempt \(attempt)/\(maxRetryAttempts))"
                    ))

                    // Check for cancellation before sleeping
                    try Task.checkCancellation()
                    try await Task.sleep(nanoseconds: delay)
                    // Check for cancellation after waking
                    try Task.checkCancellation()
                }
            } catch is CancellationError {
                Self.logger.info("Claude streaming cancelled during retry")
                return accumulatedChunks.joined()
            } catch {
                if shouldTerminate?() == true {
                    return accumulatedChunks.joined()
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

        var chunks: [String] = []
        var wordCount = 0
        var lastCharWasWhitespace = true
        var lastPhaseUpdate = 0

        for try await line in asyncBytes.lines {
            if shouldTerminate?() == true {
                asyncBytes.task.cancel()
                return chunks.joined()
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
                        return chunks.joined()
                    }

                    chunks.append(text)
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

        return chunks.joined()
    }

    // MARK: - OpenRouter Integration

    private func streamWithCompatibleAPI(
        text: String,
        title: String,
        author: String,
        mode: GenerationMode,
        tone: ToneMode,
        format: OutputFormat,
        apiKey: String,
        endpoint: String? = nil,
        model: String? = nil,
        maxTokens: Int? = nil,
        providerLabel: String = "OpenRouter",
        previousContent: String? = nil,
        improvementHints: String? = nil,
        onChunk: @escaping (String) -> Void,
        onStatus: @escaping (GenerationStatus) -> Void,
        shouldTerminate: (() -> Bool)? = nil
    ) async throws -> String {

        let resolvedEndpoint = endpoint ?? openRouterEndpoint
        let resolvedModel = model ?? OpenRouterConfig.resolvedModel
        let resolvedMaxTokens = maxTokens ?? 16_000

        guard !apiKey.isEmpty else {
            throw AIServiceError.missingApiKey(provider: providerLabel)
        }

        let isIteration = previousContent != nil && improvementHints != nil

        onStatus(GenerationStatus(
            phase: isIteration ? .addingInsights : .analyzing,
            progress: 0.0,
            wordCount: 0,
            model: isIteration ? "\(providerLabel) (Improving)" : providerLabel
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
                let bookContext: String
                if text.isEmpty {
                    bookContext = ""
                } else {
                    bookContext = """

                    ---BOOK TEXT START---
                    \(text)
                    ---BOOK TEXT END---
                    """
                }
                // Improvement iteration: ask to enhance the existing content
                userMessage = """
                I previously generated the following Insight Atlas guide for "\(title)" by \(author), but it didn't meet quality requirements.

                \(hints)

                \(bookContext)

                Revise the guide below into a SINGLE, complete, deduplicated guide that fixes these issues. Build on the existing content and rewrite/expand sections IN PLACE — do not append a second version of anything.

                HARD RULES (critical):
                - Output exactly ONE pass through the material. Every section heading appears EXACTLY ONCE.
                - Do NOT produce both a summary/overview version and a detailed/expanded version of the same section. The Quick Glance is the ONLY summary permitted; after it, each concept is covered exactly once.
                - When you expand or improve a section, REPLACE the original text — never leave the original section AND an expanded copy.
                - Do not restate the Executive Synthesis, Story Behind the Ideas, Periodic Table, Poker Game, Takeaways, or Conclusion more than once.
                - Preserve all block markers and the overall structure.

                ---PREVIOUS GUIDE START---
                \(previous)
                ---PREVIOUS GUIDE END---

                Return the full revised guide — complete, non-repeating, each section exactly once — from Quick Glance through Conclusion.
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

        guard let requestURL = URL(string: resolvedEndpoint) else {
            throw AIServiceError.invalidURL(provider: providerLabel)
        }
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let requestBody: [String: Any] = [
            "model": resolvedModel,
            "max_tokens": resolvedMaxTokens,
            "stream": true,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userMessage]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        // Attempt streaming with retry logic for transient network errors
        var lastError: Error?
        var accumulatedChunks: [String] = []

        for attempt in 1...maxRetryAttempts {
            if shouldTerminate?() == true {
                return accumulatedChunks.joined()
            }
            do {
                accumulatedChunks = []
                let trackingOnChunk: (String) -> Void = { chunk in
                    accumulatedChunks.append(chunk)
                    onChunk(chunk)
                }
                let streamed = try await performCompatibleAPIStream(
                    request: request,
                    providerLabel: providerLabel,
                    onChunk: trackingOnChunk,
                    onStatus: onStatus,
                    shouldTerminate: shouldTerminate
                )
                return streamed
            } catch let error as URLError where isRetryableError(error) {
                if shouldTerminate?() == true {
                    return accumulatedChunks.joined()
                }
                if !accumulatedChunks.isEmpty {
                    return accumulatedChunks.joined()
                }
                lastError = error
                if attempt < maxRetryAttempts {
                    let delay = calculateRetryDelay(attempt: attempt)
                    let delaySeconds = Int(delay / 1_000_000_000)
                    onStatus(GenerationStatus(
                        phase: .analyzing,
                        progress: 0.0,
                        wordCount: 0,
                        model: "\(providerLabel) (retrying in \(delaySeconds)s - attempt \(attempt)/\(maxRetryAttempts))"
                    ))

                    // Check for cancellation before sleeping
                    try Task.checkCancellation()
                    try await Task.sleep(nanoseconds: delay)
                    // Check for cancellation after waking
                    try Task.checkCancellation()
                }
            } catch is CancellationError {
                Self.logger.info("\(providerLabel) streaming cancelled during retry")
                return accumulatedChunks.joined()
            } catch {
                if shouldTerminate?() == true {
                    return accumulatedChunks.joined()
                }
                throw error
            }
        }

        throw lastError ?? AIServiceError.networkError(message: "Failed after \(maxRetryAttempts) attempts")
    }

    /// Performs the actual OpenRouter-compatible streaming request
    private func performCompatibleAPIStream(
        request: URLRequest,
        providerLabel: String,
        onChunk: @escaping (String) -> Void,
        onStatus: @escaping (GenerationStatus) -> Void,
        shouldTerminate: (() -> Bool)? = nil
    ) async throws -> String {

        let (asyncBytes, response) = try await urlSession.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            // Drain the error payload so the provider's actual reason (e.g.
            // insufficient_quota vs rate_limit_exceeded) reaches the user
            // instead of a bare status code.
            var errorBody = ""
            for try await line in asyncBytes.lines {
                errorBody += line
                if errorBody.count > 2000 { break }
            }
            throw AIServiceError.apiErrorWithBody(statusCode: httpResponse.statusCode, body: errorBody)
        }

        var chunks: [String] = []
        var wordCount = 0
        var lastCharWasWhitespace = true
        var lastPhaseUpdate = 0

        for try await line in asyncBytes.lines {
            if shouldTerminate?() == true {
                asyncBytes.task.cancel()
                return chunks.joined()
            }
            if line.hasPrefix("data: ") {
                let data = String(line.dropFirst(6))

                if data == "[DONE]" { continue }

                guard let jsonData = data.data(using: .utf8) else {
                    Self.logger.warning("\(providerLabel) stream: Failed to convert line to UTF-8 data: \(data.prefix(100))")
                    continue
                }

                do {
                    guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                        Self.logger.warning("\(providerLabel) stream: Response is not a dictionary")
                        continue
                    }

                    // Check for error responses embedded in a 200 stream event
                    if let error = json["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        Self.logger.error("\(providerLabel) stream: API error - \(message)")
                        asyncBytes.task.cancel()
                        throw AIServiceError.streamError(message: message)
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
                        return chunks.joined()
                    }

                    chunks.append(content)
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
                            model: providerLabel
                        ))
                    }
                } catch {
                    Self.logger.error("\(providerLabel) stream: JSON parse failed - \(error.localizedDescription). Data: \(data.prefix(200))")
                    // Continue processing - don't fail the entire stream for one bad event
                }
            }
        }

        onStatus(GenerationStatus(
            phase: .complete,
            progress: 1.0,
            wordCount: wordCount,
            model: providerLabel
        ))

        return chunks.joined()
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

    // NEW: More specific error types for better user feedback
    case contentPolicyViolation(message: String, provider: String)
    case rateLimitExceeded(retryAfter: TimeInterval?, provider: String)
    case tokenEstimationWarning(estimated: Int, limit: Int, utilizationPercent: Double)

    var errorDescription: String? {
        switch self {
        case .missingApiKey(let provider):
            return "\(provider) API key is missing. Please add it in Settings."
        case .invalidURL(let provider):
            return "\(provider) API endpoint URL is invalid."
        case .invalidResponse:
            return "Received an invalid response from the API."
        case .apiError(let statusCode):
            if statusCode == 429 {
                return "API error 429 (rate limit / quota). If this persists, your provider account may be out of credits or rate limited."
            }
            return "API error with status code: \(statusCode)"
        case .apiErrorWithBody(let statusCode, let body):
            // Parse the error body to extract meaningful message
            var detail = String(body.prefix(200))
            if let data = body.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                detail = message
            }
            if statusCode == 429 {
                let hint = detail.lowercased().contains("quota")
                    ? " Your provider account appears to be out of credits."
                    : " You're being rate limited; wait a moment and try again."
                return "API error (429): \(detail)\(hint)"
            }
            return "API error (\(statusCode)): \(detail)"
        case .streamError(let message):
            return "Stream error: \(message)"
        case .networkError(let message):
            return "Network error: \(message). Please check your internet connection and try again."
        case .inputTooLarge(let estimatedTokens, let limit, let provider):
            let formatted = NumberFormatter.localizedString(from: NSNumber(value: estimatedTokens), number: .decimal)
            let limitFormatted = NumberFormatter.localizedString(from: NSNumber(value: limit), number: .decimal)
            let suggestion = provider == "Claude"
                ? "Try a shorter book, or contact support for extended context options."
                : "Try a shorter book or switch to Claude."
            return "This book is too large for \(provider) (~\(formatted) tokens, limit: \(limitFormatted)). \(suggestion)"
        case .contentPolicyViolation(let message, let provider):
            return "\(provider) content policy violation: \(message)"
        case .rateLimitExceeded(let retryAfter, let provider):
            if let retryAfter = retryAfter {
                return "\(provider) rate limit exceeded. Please wait \(Int(retryAfter)) seconds before retrying."
            }
            return "\(provider) rate limit exceeded. Please try again in a few minutes."
        case .tokenEstimationWarning(let estimated, let limit, let percent):
            return "Warning: Input size is \(String(format: "%.1f", percent))% of context limit (\(estimated)/\(limit) tokens). Generation may be slow or fail."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .contentPolicyViolation:
            return "Please review the book content for potentially sensitive material and try a different book."
        case .rateLimitExceeded:
            return "Wait a few minutes before trying again, or check your API plan limits."
        case .tokenEstimationWarning:
            return "Consider using a smaller excerpt or switching providers."
        case .missingApiKey:
            return "Go to Settings and add your API key."
        case .networkError:
            return "Check your internet connection and try again."
        default:
            return nil
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
