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
    /// OpenRouter: generous limit to accommodate various models.
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
            format: settings.preferredFormat,
            summaryType: settings.preferredSummaryType
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
        case .minimax:
            contextLimit = MiniMaxOAuthConfig.inputTokenLimit(
                mode: settings.preferredMode,
                summaryType: settings.preferredSummaryType
            )
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
            case .minimax:
                providerName = AIProvider.minimax.displayName
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
        targetWordCount: Int? = nil,
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
                summaryType: settings.preferredSummaryType,
                targetWordCount: targetWordCount,
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
                summaryType: settings.preferredSummaryType,
                targetWordCount: targetWordCount,
                apiKey: settings.openRouterApiKey ?? "",
                endpoint: openRouterEndpoint,
                model: OpenRouterConfig.resolvedModel,
                maxTokens: 16000,
                providerLabel: "OpenRouter",
                previousContent: previousContent,
                improvementHints: improvementHints,
                onChunk: onChunk,
                onStatus: onStatus,
                shouldTerminate: shouldTerminate
            )

        case .minimax:
            do {
                let token = try await MiniMaxOAuthService.shared.validAccessToken()
                return try await streamWithClaude(
                    text: bookText,
                    title: title,
                    author: author,
                    mode: settings.preferredMode,
                    tone: settings.preferredTone,
                    format: settings.preferredFormat,
                    summaryType: settings.preferredSummaryType,
                    targetWordCount: targetWordCount,
                    apiKey: token,
                    endpoint: MiniMaxOAuthConfig.inferenceURL,
                    model: MiniMaxOAuthConfig.defaultModel,
                    maxTokens: MiniMaxOAuthConfig.outputTokenLimit(
                        mode: settings.preferredMode,
                        summaryType: settings.preferredSummaryType
                    ),
                    useBearerAuth: true,
                    providerLabel: "MiniMax",
                    previousContent: previousContent,
                    improvementHints: improvementHints,
                    onChunk: onChunk,
                    onStatus: onStatus,
                    shouldTerminate: shouldTerminate
                )
            } catch {
                let openRouterKey = settings.openRouterApiKey ?? ""
                guard Self.shouldFallBackToOpenRouter(after: error),
                      shouldTerminate?() != true,
                      !openRouterKey.isEmpty else {
                    throw error
                }

                Self.logger.warning(
                    "\(AIProvider.minimax.displayName) generation failed, retrying on OpenRouter: \(error.localizedDescription, privacy: .public)"
                )

                // Discard whatever MiniMax streamed before failing so the
                // OpenRouter attempt does not append to a partial guide.
                onReset?()
                onStatus(GenerationStatus(
                    phase: .analyzing,
                    progress: 0.0,
                    wordCount: 0,
                    model: "OpenRouter (MiniMax fallback)"
                ))

                return try await streamWithCompatibleAPI(
                    text: bookText,
                    title: title,
                    author: author,
                    mode: settings.preferredMode,
                    tone: settings.preferredTone,
                    format: settings.preferredFormat,
                    summaryType: settings.preferredSummaryType,
                    targetWordCount: targetWordCount,
                    apiKey: openRouterKey,
                    endpoint: openRouterEndpoint,
                    model: OpenRouterConfig.resolvedModel,
                    maxTokens: 16000,
                    providerLabel: "OpenRouter",
                    previousContent: previousContent,
                    improvementHints: improvementHints,
                    onChunk: onChunk,
                    onStatus: onStatus,
                    shouldTerminate: shouldTerminate
                )
            }
        }
    }

    /// Whether a failed MiniMax attempt is worth retrying on OpenRouter.
    ///
    /// Availability failures (auth, network, rate limits, server errors) are
    /// retried. Failures that describe the *request* rather than the provider —
    /// oversized input, content policy — would fail identically on OpenRouter,
    /// so they surface immediately. User cancellation is never retried.
    static func shouldFallBackToOpenRouter(after error: Error) -> Bool {
        if error is CancellationError { return false }
        if let urlError = error as? URLError, urlError.code == .cancelled { return false }

        guard let serviceError = error as? AIServiceError else {
            // Unknown errors (including MiniMax OAuth failures) are treated as
            // availability problems.
            return true
        }

        switch serviceError {
        case .contentPolicyViolation, .inputTooLarge, .tokenEstimationWarning:
            return false
        case .missingApiKey, .invalidURL, .invalidResponse, .apiError,
             .apiErrorWithBody, .streamError, .networkError, .rateLimitExceeded:
            return true
        }
    }

    // MARK: - Audio Narration Script

    /// Rewrite a finished Insight Atlas guide (markdown with embedded `[VISUAL_*]`
    /// blocks) into a spoken-word narration script suitable for text-to-speech.
    ///
    /// The written guide is optimized for the eye — headings, citations, tables,
    /// and 30+ visual types that a listener cannot see. This pass, run on MiniMax
    /// M2.7, translates all of that into natural spoken prose so an audio listener
    /// loses no information: every visual is described in words, references are
    /// spoken naturally, and sentences are shaped for the ear. Requires a valid
    /// MiniMax session; callers should gate on `MiniMaxOAuthService.isSignedIn`.
    func generateNarrationScript(
        from guideContent: String,
        title: String?,
        author: String?,
        targetWordCount: Int,
        openRouterApiKey: String? = nil
    ) async throws -> String {
        let trimmed = guideContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AIServiceError.networkError(message: "No guide content to narrate.")
        }

        let bookLine = [
            title.map { "Book title: \($0)" },
            author.map { "Author: \($0)" }
        ].compactMap { $0 }.joined(separator: "\n")

        let userMessage = """
        \(bookLine.isEmpty ? "" : bookLine + "\n\n")Create a comprehensive spoken-word audio summary of the Insight Atlas guide below. \
        Target approximately \(targetWordCount) words and never exceed \(targetWordCount) words. \
        Return ONLY the narration text — no preamble, no headings, no markdown, no stage directions.

        ---GUIDE START---
        \(trimmed)
        ---GUIDE END---
        """

        let script: String
        do {
            let token = try await MiniMaxOAuthService.shared.validAccessToken()
            script = try await anthropicOneShot(
                endpoint: MiniMaxOAuthConfig.inferenceURL,
                apiKey: token,
                model: MiniMaxOAuthConfig.defaultModel,
                useBearerAuth: true,
                providerLabel: "MiniMax",
                system: Self.narrationScriptSystemPrompt,
                user: userMessage,
                maxTokens: min(8_192, max(2_048, targetWordCount * 2))
            )
        } catch {
            let openRouterKey = (openRouterApiKey ?? KeychainService.shared.openRouterApiKey) ?? ""
            guard Self.shouldFallBackToOpenRouter(after: error), !openRouterKey.isEmpty else {
                throw error
            }
            Self.logger.warning(
                "\(AIProvider.minimax.displayName) narration script failed, retrying on OpenRouter: \(error.localizedDescription, privacy: .public)"
            )
            script = try await openAIOneShot(
                apiKey: openRouterKey,
                system: Self.narrationScriptSystemPrompt,
                user: userMessage,
                maxTokens: min(8_192, max(2_048, targetWordCount * 2))
            )
        }

        let cleaned = script.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            throw AIServiceError.invalidResponse
        }
        return cleaned
    }

    /// System prompt for the narration-script rewrite. Teaches the model to speak
    /// every visual type Insight Atlas can emit so no information is lost in audio.
    private static let narrationScriptSystemPrompt: String = """
    You are a narration writer for Insight Atlas. You turn a written study guide into a script that will be read aloud by a text-to-speech voice. The listener CANNOT see the page, so anything visual must be spoken.

    NON-NEGOTIABLE GOALS
    1. Create a comprehensive but bounded audio summary. Preserve the central argument, every major section, the most useful examples, practical applications, and final takeaways. Compress repetition and minor detail so the requested word ceiling is never exceeded.
    2. Sound natural when spoken. Prefer shorter sentences, plain connectives, and spoken transitions ("Let's start with…", "The key point here is…", "That brings us to…"). Never leave a heading as a bare fragment — fold it into a spoken transition.
    3. Output plain spoken text only. No markdown, no "#", no "*", no bullet characters, no bracket tags, no emoji, no "Figure 1", no URLs.

    HANDLING CITATIONS AND REFERENCES
    - Speak references naturally ("as Yalom argues", "according to the author") or omit bare parenthetical citations and page numbers when they would only be noise to a listener. Never read raw citation syntax aloud.

    HANDLING VISUALS — THE MOST IMPORTANT RULE
    The guide contains visual blocks delimited by tags like [VISUAL_TYPE: Title] ... [/VISUAL_TYPE]. A listener cannot see these. For EACH visual block you must replace it with a spoken passage that: (a) names what it shows, (b) walks through every data point / node / row / stage in words, and (c) states the insight it conveys. Never read the raw payload, JSON, or tag. Describe these types as follows:

    - TIMELINE / GANTT: narrate events in order with their dates and what happened at each.
    - FLOWCHART / PROCESS / CYCLE: describe the sequence step by step ("first…, which leads to…, and finally…"); for a cycle, make clear it loops back to the start.
    - COMPARISON / MATRIX / TABLE: read it as prose — for each row, state how it differs across the columns; don't just list cells.
    - CONCEPT MAP / MINDMAP / NETWORK / HIERARCHY: name the central idea, then each branch/child and how it connects; for networks, describe the key relationships and their strength.
    - RADAR: name each dimension being assessed and what high vs low means.
    - BAR / LINE / AREA / STACKED / GROUPED CHART: state the categories and their values, and call out the highest, lowest, and any trend.
    - PIE / FUNNEL / TREEMAP: give the proportions or stage sizes and what dominates.
    - QUADRANT / SPECTRUM / SCATTER / BUBBLE: describe the two axes, then where each item sits and why that placement matters.
    - VENN: name each set, what is unique to each, and what they share in the overlap.
    - PYRAMID / ICEBERG / LADDER: describe the layers from base to top and what each level means.
    - FISHBONE: state the effect, then each cause category and its contributing items.
    - SWOT: narrate strengths, weaknesses, opportunities, and threats in turn.
    - SANKEY: describe what flows from where to where and the relative magnitudes.
    - HEATMAP: describe rows and columns and where intensity is highest and lowest.
    - JOURNEY MAP / STORYBOARD: narrate each stage or scene in order, including touchpoints and emotional tone.
    - INFOGRAPHIC / GAUGE: speak the headline statistics and highlights.
    Use the visual's title and surrounding text to keep the description in context. If a visual restates nearby prose, integrate it so you don't repeat yourself.

    Begin directly with the narration of the guide's content.
    """

    // MARK: - Closing Section (conclusion pass)

    /// Generate ONLY a closing section — a short synthesis plus a `[TAKEAWAYS]`
    /// block — for a guide body that ran out of word budget before concluding.
    /// Routed through the same provider the guide used, bounded to `maxWords`.
    func generateClosingSection(
        bodyContent: String,
        title: String,
        author: String,
        settings: UserSettings,
        maxWords: Int
    ) async throws -> String {
        let system = """
        You write the closing section of an Insight Atlas guide that will be appended after the body. \
        Output ONLY the closing section — no restating of earlier material.

        Produce, in this order:
        1. One short synthesis paragraph (3–5 sentences) that ties the guide's argument together.
        2. A takeaways block using EXACTLY these markers on their own lines:
        [TAKEAWAYS]
        - <takeaway 1>
        - <takeaway 2>
        - <takeaway 3>
        [/TAKEAWAYS]

        Rules: 3–5 takeaways, each one line. No markdown headings, no "#", no brand names. \
        Do not repeat sentences from the body. Stay under \(maxWords) words total. Begin directly with the synthesis paragraph.
        """
        let user = """
        Book: "\(title)" by \(author). Write the closing section for the guide body below.

        ---GUIDE BODY START---
        \(bodyContent)
        ---GUIDE BODY END---
        """
        let maxTokens = max(512, min(4000, maxWords * 3))
        let text = try await oneShotCompletion(
            system: system, user: user, settings: settings, maxTokens: maxTokens
        )
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Single-shot, non-guide completion routed to the configured provider.
    private func oneShotCompletion(
        system: String,
        user: String,
        settings: UserSettings,
        maxTokens: Int
    ) async throws -> String {
        switch settings.preferredProvider {
        case .claude:
            return try await anthropicOneShot(
                endpoint: claudeEndpoint,
                apiKey: settings.claudeApiKey ?? "",
                model: claudeModel,
                useBearerAuth: false,
                providerLabel: "Claude",
                system: system, user: user, maxTokens: maxTokens
            )
        case .minimax:
            do {
                let token = try await MiniMaxOAuthService.shared.validAccessToken()
                return try await anthropicOneShot(
                    endpoint: MiniMaxOAuthConfig.inferenceURL,
                    apiKey: token,
                    model: MiniMaxOAuthConfig.defaultModel,
                    useBearerAuth: true,
                    providerLabel: "MiniMax",
                    system: system, user: user, maxTokens: maxTokens
                )
            } catch {
                let openRouterKey = settings.openRouterApiKey ?? ""
                guard Self.shouldFallBackToOpenRouter(after: error), !openRouterKey.isEmpty else {
                    throw error
                }
                Self.logger.warning(
                    "\(AIProvider.minimax.displayName) one-shot failed, retrying on OpenRouter: \(error.localizedDescription, privacy: .public)"
                )
                return try await openAIOneShot(
                    apiKey: openRouterKey,
                    system: system, user: user, maxTokens: maxTokens
                )
            }
        case .openRouter:
            return try await openAIOneShot(
                apiKey: settings.openRouterApiKey ?? "",
                system: system, user: user, maxTokens: maxTokens
            )
        }
    }

    /// Anthropic Messages-format single-shot (Claude and MiniMax).
    private func anthropicOneShot(
        endpoint: String,
        apiKey: String,
        model: String,
        useBearerAuth: Bool,
        providerLabel: String,
        system: String,
        user: String,
        maxTokens: Int
    ) async throws -> String {
        guard !apiKey.isEmpty else { throw AIServiceError.missingApiKey(provider: providerLabel) }
        guard let url = URL(string: endpoint) else { throw AIServiceError.invalidURL(provider: providerLabel) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if useBearerAuth {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        } else {
            request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        }
        let body = ClaudeRequest(
            model: model, max_tokens: maxTokens, stream: true, system: system,
            messages: [ClaudeMessage(role: "user", content: user)]
        )
        request.httpBody = try JSONEncoder().encode(body)
        return try await performClaudeStream(
            request: request,
            providerLabel: providerLabel,
            onChunk: { _ in },
            onStatus: { _ in },
            shouldTerminate: nil
        )
    }

    /// OpenAI Chat-format single-shot (OpenRouter).
    private func openAIOneShot(
        apiKey: String,
        system: String,
        user: String,
        maxTokens: Int
    ) async throws -> String {
        guard !apiKey.isEmpty else { throw AIServiceError.missingApiKey(provider: "OpenRouter") }
        guard let url = URL(string: openRouterEndpoint) else { throw AIServiceError.invalidURL(provider: "OpenRouter") }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let requestBody: [String: Any] = [
            "model": OpenRouterConfig.resolvedModel,
            "max_tokens": maxTokens,
            "stream": true,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        return try await performCompatibleAPIStream(
            request: request, providerLabel: "OpenRouter",
            onChunk: { _ in }, onStatus: { _ in }, shouldTerminate: nil
        )
    }

    // MARK: - Claude Integration

    private func streamWithClaude(
        text: String,
        title: String,
        author: String,
        mode: GenerationMode,
        tone: ToneMode,
        format: OutputFormat,
        summaryType: SummaryType,
        targetWordCount: Int?,
        apiKey: String,
        endpoint: String? = nil,
        model: String? = nil,
        maxTokens: Int? = nil,
        useBearerAuth: Bool = false,
        providerLabel: String = "Claude",
        previousContent: String? = nil,
        improvementHints: String? = nil,
        onChunk: @escaping (String) -> Void,
        onStatus: @escaping (GenerationStatus) -> Void,
        shouldTerminate: (() -> Bool)? = nil
    ) async throws -> String {

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
            format: format,
            summaryType: summaryType,
            targetWordCount: targetWordCount
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

        guard let claudeURL = URL(string: endpoint ?? claudeEndpoint) else {
            throw AIServiceError.invalidURL(provider: providerLabel)
        }
        var request = URLRequest(url: claudeURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if useBearerAuth {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        } else {
            request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        }

        let requestBody = ClaudeRequest(
            model: model ?? claudeModel,
            max_tokens: maxTokens ?? maxTokensClaude,
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

                let event: ClaudeStreamEvent
                do {
                    event = try JSONDecoder().decode(ClaudeStreamEvent.self, from: jsonData)
                } catch {
                    Self.logger.error("\(providerLabel) stream: JSON decode failed - \(error.localizedDescription). Data: \(data.prefix(200))")
                    continue
                }

                if let streamError = Self.providerStreamError(from: event, providerLabel: providerLabel) {
                    asyncBytes.task.cancel()
                    throw streamError
                }

                // Not all events have delta text (e.g. message_start and
                // content_block_start), and MiniMax also emits thinking blocks.
                guard let text = event.delta?.text else { continue }

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
                        model: providerLabel
                    ))
                }
            }
        }

        let result = chunks.joined()
        guard !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIServiceError.invalidResponse
        }

        onStatus(GenerationStatus(
            phase: .complete,
            progress: 1.0,
            wordCount: wordCount,
            model: providerLabel
        ))

        return result
    }

    static func providerStreamError(
        from event: ClaudeStreamEvent,
        providerLabel: String
    ) -> AIServiceError? {
        guard event.type == "error" else { return nil }
        let detail = event.error?.message?.trimmingCharacters(in: .whitespacesAndNewlines)
        let message: String
        if let detail, !detail.isEmpty {
            message = "\(providerLabel): \(detail)"
        } else {
            message = "\(providerLabel) returned an unknown streaming error."
        }
        return .streamError(
            message: message
        )
    }

    // MARK: - OpenRouter Integration

    private func streamWithCompatibleAPI(
        text: String,
        title: String,
        author: String,
        mode: GenerationMode,
        tone: ToneMode,
        format: OutputFormat,
        summaryType: SummaryType,
        targetWordCount: Int?,
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
            format: format,
            summaryType: summaryType,
            targetWordCount: targetWordCount
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
