import Foundation
import os.log

/// Service for generating Insight Atlas guides using AI providers
actor AIService {

    // MARK: - Logging

    private static let logger = Logger(subsystem: "com.insightatlas", category: "AIService")

    // MARK: - Properties

    private let claudeEndpoint = "https://api.anthropic.com/v1/messages"
    private let openaiEndpoint = "https://api.openai.com/v1/chat/completions"

    private let claudeModel = "claude-sonnet-4-20250514"  // Sonnet 4: 64K output, excellent quality
    private let openaiModel = "gpt-4.1-2025-04-14"  // Latest GPT-4.1 with 1M context

    private let maxTokensClaude = 64000  // Claude Sonnet 4 max output tokens
    private let maxTokensOpenAI = 32768  // GPT-4.1 max output tokens

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
    /// Claude Opus 4: 200K context, we reserve 20K for output (max_tokens)
    private let claudeContextLimit = 180_000
    /// OpenAI GPT-4.1: 1M context, we reserve 32K for output
    private let openaiContextLimit = 500_000

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

        // For tandem mode (.both), use OpenAI's limit since GPT-4.1 analyzes the full book first
        let contextLimit: Int
        switch settings.preferredProvider {
        case .openai, .both:
            contextLimit = openaiContextLimit
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
            case .openai:
                providerName = "OpenAI"
            case .claude:
                providerName = "Claude"
            case .both:
                providerName = "GPT-4.1"  // GPT handles the full book in tandem mode
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
        let hasClaudeKey = !(settings.claudeApiKey ?? "").isEmpty
        let hasOpenAIKey = !(settings.openaiApiKey ?? "").isEmpty

        // Pre-flight validation: check input size before making API call
        // Skip for continuation/improvement requests which use smaller input
        if previousContent == nil {
            var validationSettings = settings
            if settings.preferredProvider == .both {
                if hasClaudeKey && !hasOpenAIKey {
                    validationSettings.preferredProvider = .claude
                } else if hasOpenAIKey && !hasClaudeKey {
                    validationSettings.preferredProvider = .openai
                }
            }
            try validateInputSize(
                bookText: bookText,
                title: title,
                author: author,
                settings: validationSettings
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
            // Dual Provider Mode (Optimized): GPT-4.1 analyzes full book (1M context), Claude synthesizes premium prose.
            // This leverages GPT's massive context for comprehensive analysis and Claude's superior prose quality.

            guard hasClaudeKey || hasOpenAIKey else {
                throw AIServiceError.missingApiKey(provider: "Claude or OpenAI")
            }

            // If only one key available, use single-provider mode
            if !hasOpenAIKey {
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
            }

            if !hasClaudeKey {
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

            // PHASE 1: GPT-4.1 Deep Analysis (leverages 1M context window)
            // GPT analyzes the ENTIRE book and extracts:
            // - Author metadata from title/copyright pages
            // - Book structure and chapter organization
            // - Core thesis and key arguments
            // - Notable quotes with locations
            // - Key concepts and frameworks
            onStatus(GenerationStatus(
                phase: .analyzing,
                progress: 0.05,
                wordCount: 0,
                model: "GPT-4.1 (Phase 1/2 - Deep Analysis)"
            ))

            let gptAnalysis: String
            do {
                gptAnalysis = try await performGPTAnalysis(
                    bookText: bookText,
                    title: title,
                    author: author,
                    apiKey: settings.openaiApiKey ?? "",
                    onStatus: { status in
                        var adjusted = status
                        adjusted.model = "GPT-4.1 (Phase 1/2 - Analysis)"
                        adjusted.progress = status.progress * 0.25  // First 25% is analysis
                        onStatus(adjusted)
                    },
                    shouldTerminate: shouldTerminate
                )
            } catch {
                Self.logger.error("Tandem mode Phase 1 (GPT-4.1 Analysis) failed: \(error.localizedDescription)")
                throw AIServiceError.tandemModePhaseFailure(phase: "GPT-4.1 Analysis", underlyingError: error)
            }

            if shouldTerminate?() == true {
                return gptAnalysis
            }

            Self.logger.info("GPT-4.1 analysis complete: \(gptAnalysis.count) characters")

            // PHASE 2: Claude Premium Synthesis (superior prose quality)
            // Claude receives GPT's comprehensive analysis + condensed book text
            // and generates the final premium editorial guide
            onStatus(GenerationStatus(
                phase: .writing,
                progress: 0.30,
                wordCount: 0,
                model: "Claude (Phase 2/2 - Premium Synthesis)"
            ))

            let finalResult: String
            do {
                finalResult = try await streamWithClaudeUsingAnalysis(
                    bookText: bookText,
                    title: title,
                    author: author,
                    gptAnalysis: gptAnalysis,
                    mode: settings.preferredMode,
                    tone: settings.preferredTone,
                    format: settings.preferredFormat,
                    apiKey: settings.claudeApiKey ?? "",
                    onChunk: onChunk,
                    onStatus: { status in
                        var adjusted = status
                        adjusted.model = "Claude (Phase 2/2 - Synthesis)"
                        adjusted.progress = 0.30 + (status.progress * 0.70)  // Last 70% is synthesis
                        onStatus(adjusted)
                    },
                    shouldTerminate: shouldTerminate
                )
            } catch {
                Self.logger.error("Tandem mode Phase 2 (Claude Synthesis) failed: \(error.localizedDescription)")
                throw AIServiceError.tandemModePhaseFailure(phase: "Claude Synthesis", underlyingError: error)
            }

            return finalResult
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
                return fullText
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
                    let delay = calculateRetryDelay(attempt: attempt)
                    let delaySeconds = Int(delay / 1_000_000_000)
                    onStatus(GenerationStatus(
                        phase: .analyzing,
                        progress: 0.0,
                        wordCount: 0,
                        model: "OpenAI (retrying in \(delaySeconds)s - attempt \(attempt)/\(maxRetryAttempts))"
                    ))

                    // Check for cancellation before sleeping
                    try Task.checkCancellation()
                    try await Task.sleep(nanoseconds: delay)
                    // Check for cancellation after waking
                    try Task.checkCancellation()
                }
            } catch is CancellationError {
                Self.logger.info("OpenAI streaming cancelled during retry")
                return fullText
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

    // MARK: - Tandem Mode: GPT Analysis Phase

    /// Phase 1 of tandem mode: GPT-4.1 performs deep analysis of the book
    /// Leverages GPT's 1M context window to analyze the entire book
    private func performGPTAnalysis(
        bookText: String,
        title: String,
        author: String,
        apiKey: String,
        onStatus: @escaping (GenerationStatus) -> Void,
        shouldTerminate: (() -> Bool)? = nil
    ) async throws -> String {

        guard !apiKey.isEmpty else {
            throw AIServiceError.missingApiKey(provider: "OpenAI")
        }

        onStatus(GenerationStatus(
            phase: .analyzing,
            progress: 0.0,
            wordCount: 0,
            model: "GPT-4.1 (Deep Analysis)"
        ))

        let analysisPrompt = """
        You are an expert book analyst preparing a comprehensive analysis for a guide writer.
        Your analysis will be used by another AI to create a reader's guide.

        CRITICAL: Start by extracting exact metadata from the document.

        Analyze this book thoroughly and provide:

        ## METADATA (EXTRACT FROM DOCUMENT - DO NOT SKIP)
        **Author Name:** [Extract the EXACT author name from title page, copyright page, or "About the Author" section. If "\(author)" shows as "Unknown", you MUST find the real author name in the document.]
        **Publication Year:** [Extract from copyright page, e.g., "Copyright © 2023"]
        **Publisher:** [Extract from copyright page if available]
        **Full Title:** [Include subtitle if present]

        ## BOOK STRUCTURE
        - List all chapters/sections with their titles and page ranges (if identifiable)
        - Identify the book's organizational pattern (chronological, thematic, problem-solution, etc.)
        - Note any unique structural elements (case studies, exercises, frameworks)

        ## CORE THESIS & ARGUMENTS
        - State the book's central thesis in 2-3 sentences (this should be quotable)
        - List the 5-7 main arguments or key points the author makes
        - Identify the primary evidence or support for each argument

        ## KEY CONCEPTS & FRAMEWORKS
        - List and briefly explain all major concepts, models, or frameworks introduced
        - Note any proprietary terminology the author uses (use their exact names)
        - Identify relationships between concepts

        ## NOTABLE QUOTES & PASSAGES
        - Extract 8-12 of the most impactful quotes (with chapter/section location if possible)
        - Note any recurring phrases or mantras the author emphasizes
        - Include the quote text exactly as written

        ## AUTHOR'S PERSPECTIVE
        - Identify the author's background/credentials as presented in the book
        - Note their philosophical or methodological approach
        - Identify any biases or limitations acknowledged

        ## TARGET AUDIENCE & APPLICATIONS
        - Who is this book written for?
        - What problems does it solve?
        - What are the practical applications?

        ## THEMATIC PATTERNS
        - Identify recurring themes throughout the book
        - Note any narrative arcs or progression of ideas
        - Identify the emotional journey the reader is taken on

        ## CRITICAL INSIGHTS
        - What makes this book unique or valuable?
        - What are its strongest contributions?
        - Any notable weaknesses or gaps?

        Be thorough and specific. Include chapter references or section locations where possible.
        The METADATA section is CRITICAL - the guide writer needs accurate author and publication info.
        """

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
            "stream": false,  // Non-streaming for analysis phase
            "messages": [
                ["role": "system", "content": analysisPrompt],
                ["role": "user", "content": """
                    Please analyze the following book:

                    Title: \(title)
                    Author: \(author)

                    ---BOOK CONTENT START---
                    \(bookText)
                    ---BOOK CONTENT END---

                    Provide your comprehensive analysis following the structure outlined.
                    """]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        // Non-streaming request for analysis
        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIServiceError.apiErrorWithBody(statusCode: httpResponse.statusCode, body: errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIServiceError.invalidResponse
        }

        Self.logger.info("GPT Analysis complete: \(content.count) characters")

        onStatus(GenerationStatus(
            phase: .analyzing,
            progress: 1.0,
            wordCount: content.split(separator: " ").count,
            model: "GPT-4.1 (Analysis Complete)"
        ))

        return content
    }

    // MARK: - Tandem Mode: Claude Synthesis Phase

    /// Phase 2 of tandem mode: Claude synthesizes the guide using GPT's analysis
    /// Receives condensed book content + comprehensive GPT analysis
    private func streamWithClaudeUsingAnalysis(
        bookText: String,
        title: String,
        author: String,
        gptAnalysis: String,
        mode: GenerationMode,
        tone: ToneMode,
        format: OutputFormat,
        apiKey: String,
        onChunk: @escaping (String) -> Void,
        onStatus: @escaping (GenerationStatus) -> Void,
        shouldTerminate: (() -> Bool)? = nil
    ) async throws -> String {

        guard !apiKey.isEmpty else {
            throw AIServiceError.missingApiKey(provider: "Claude")
        }

        onStatus(GenerationStatus(
            phase: .writing,
            progress: 0.0,
            wordCount: 0,
            model: "Claude (Synthesis)"
        ))

        // Generate the standard system prompt for guide creation
        let baseSystemPrompt = InsightAtlasPromptGenerator.generatePrompt(
            title: title,
            author: author,
            mode: mode,
            tone: tone,
            format: format
        )

        // Enhance with analysis context
        let systemPrompt = """
        \(baseSystemPrompt)

        IMPORTANT: You have been provided with a comprehensive analysis of this book performed by GPT-4.1.
        Use this analysis to inform and enrich your guide. The analysis includes:
        - Detailed chapter structure and organization
        - Core thesis and arguments with supporting evidence
        - Key concepts, frameworks, and terminology
        - Notable quotes and passages
        - Author perspective and methodology
        - Target audience and applications
        - Thematic patterns and critical insights

        Integrate these insights throughout your guide. Reference specific concepts and quotes from the analysis.
        Create a guide that demonstrates deep understanding of the book's content and structure.
        """

        // Condense book text to fit within Claude's context while keeping key parts
        // Claude's total context is 200K. We need: input tokens + max_tokens (output) <= 200K
        // So available input = 200K - 64K (max_tokens) = 136K tokens
        // Reserve space for: system prompt + GPT analysis + user message wrapper + safety margin
        let totalContextLimit = 200_000  // Claude's actual context window
        let availableForInput = totalContextLimit - maxTokensClaude  // 200K - 64K = 136K
        let systemPromptTokens = estimateTokenCount(for: systemPrompt)
        let gptAnalysisTokens = estimateTokenCount(for: gptAnalysis)
        let messageOverhead = 2000  // Buffer for user message wrapper text
        let safetyMargin = 5000  // Extra safety margin

        let maxBookTokens = max(0, availableForInput - systemPromptTokens - gptAnalysisTokens - messageOverhead - safetyMargin)
        Self.logger.info("Claude synthesis budget: \(maxBookTokens) tokens for book (available: \(availableForInput), prompt: \(systemPromptTokens), analysis: \(gptAnalysisTokens))")

        let condensedBook = condenseBookText(bookText, maxTokens: maxBookTokens)

        let userMessage = """
        Create a comprehensive Insight Atlas guide for this book.

        ## GPT-4.1 BOOK ANALYSIS
        The following comprehensive analysis was performed by GPT-4.1 with access to the COMPLETE book:

        \(gptAnalysis)

        ## BOOK CONTENT
        Title: \(title)
        Author: \(author)

        \(condensedBook)

        ---

        CRITICAL INSTRUCTIONS:

        1. **METADATA FIRST**: Check the GPT analysis for the METADATA section. If it contains an author name different from "\(author)" (especially if "\(author)" is "Unknown"), USE THE AUTHOR NAME FROM THE ANALYSIS throughout your guide.

        2. **QUICK GLANCE**: Use the extracted author name and publication year in the Quick Glance header. Extract SPECIFIC key insights from the "Core Thesis & Arguments" and "Key Concepts" sections of the analysis.

        3. **QUOTES**: The analysis includes notable quotes with locations - incorporate these with proper attribution.

        4. **STRUCTURE**: Follow the book structure identified in the analysis to organize your synthesis thematically.

        5. **TERMINOLOGY**: Use the author's actual terminology and framework names as documented in the "Key Concepts & Frameworks" section.

        Create a complete Insight Atlas guide that demonstrates deep understanding of the book's content and structure.
        """

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

        return try await performClaudeStream(
            request: request,
            onChunk: onChunk,
            onStatus: onStatus,
            shouldTerminate: shouldTerminate
        )
    }

    /// Condenses book text to fit within token limits while preserving key content
    private func condenseBookText(_ text: String, maxTokens: Int) -> String {
        guard maxTokens > 0 else {
            return ""
        }
        let currentTokens = estimateTokenCount(for: text)

        if currentTokens <= maxTokens {
            return text
        }

        // Need to condense - keep beginning, important middle sections, and end
        let targetChars = maxTokens * 4  // ~4 chars per token

        // Strategy: Keep first 40%, sample middle 30%, keep last 30%
        let firstPortion = Int(Double(targetChars) * 0.4)
        let lastPortion = Int(Double(targetChars) * 0.3)
        let middlePortion = targetChars - firstPortion - lastPortion

        let textLength = text.count

        // Get first portion
        let firstEndIndex = text.index(text.startIndex, offsetBy: min(firstPortion, textLength))
        let firstPart = String(text[text.startIndex..<firstEndIndex])

        // Get last portion
        let lastStartOffset = max(0, textLength - lastPortion)
        let lastStartIndex = text.index(text.startIndex, offsetBy: lastStartOffset)
        let lastPart = String(text[lastStartIndex..<text.endIndex])

        // Sample from middle
        let middleStart = firstPortion
        let middleEnd = textLength - lastPortion
        var middlePart = ""

        if middleEnd > middleStart && middlePortion > 0 {
            // Sample evenly from the middle section
            let middleRange = middleEnd - middleStart
            let sampleSize = min(middlePortion, middleRange)
            let sampleStart = middleStart + (middleRange - sampleSize) / 2

            let sampleStartIndex = text.index(text.startIndex, offsetBy: sampleStart)
            let sampleEndIndex = text.index(sampleStartIndex, offsetBy: sampleSize)
            middlePart = String(text[sampleStartIndex..<sampleEndIndex])
        }

        let condensedText = """
        \(firstPart)

        [...content condensed for context limits - GPT analysis above contains full book analysis...]

        \(middlePart)

        [...additional content condensed...]

        \(lastPart)
        """

        Self.logger.info("Condensed book from \(textLength) to \(condensedText.count) characters for Claude")

        return condensedText
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
    case tandemModePhaseFailure(phase: String, underlyingError: Error)
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
            let suggestion = provider == "Claude"
                ? "Try a shorter book, or contact support for extended context options."
                : "Try a shorter book or switch to Claude for larger context."
            return "This book is too large for \(provider) (~\(formatted) tokens, limit: \(limitFormatted)). \(suggestion)"
        case .contentPolicyViolation(let message, let provider):
            return "\(provider) content policy violation: \(message)"
        case .rateLimitExceeded(let retryAfter, let provider):
            if let retryAfter = retryAfter {
                return "\(provider) rate limit exceeded. Please wait \(Int(retryAfter)) seconds before retrying."
            }
            return "\(provider) rate limit exceeded. Please try again in a few minutes."
        case .tandemModePhaseFailure(let phase, let error):
            return "Tandem mode failed during \(phase): \(error.localizedDescription)"
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
        case .tandemModePhaseFailure(let phase, _):
            return "Try switching to single-provider mode (Claude or OpenAI only) instead of tandem mode. The \(phase) phase encountered an error."
        case .tokenEstimationWarning:
            return "Consider using a smaller excerpt or switching to GPT-4.1 (1M context) if using Claude."
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
