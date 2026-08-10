//
//  OnDeviceInsightService.swift
//  InsightAtlas
//
//  SPIKE / PROTOTYPE — on-device Apple Intelligence (Foundation Models).
//
//  Purpose: probe the *ceiling* of the on-device model for the lightweight,
//  bounded tasks it is actually good at — a TL;DR, themes, tags, and an
//  instant offline preview — rather than the 15,000-word premium guide, which
//  the 4,096-token context window makes impractical.
//
//  This service is intentionally decoupled from `LibraryItem`: it takes plain
//  strings so it can be exercised from a preview card, a unit test, or a
//  RunCodeSnippet spike without dragging in the whole data model.
//
//  Availability: Foundation Models requires iOS 26+ AND Apple Intelligence to
//  be enabled on an eligible device. The app targets iOS 17, so everything here
//  is gated behind `#if canImport(FoundationModels)` + `@available(iOS 26, *)`.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Public, framework-agnostic surface

/// A structured, on-device preview of a book/guide — the kind of small,
/// bounded artifact the on-device model can produce reliably.
struct OnDeviceInsightPreview: Sendable, Equatable {
    var headline: String
    var tldr: String
    var themes: [String]
    var tags: [String]
    var estimatedReadingMinutes: Int
}

/// Why the on-device model can't be used right now. Mirrors
/// `SystemLanguageModel.Availability` but without leaking the framework type to
/// callers that may be compiled for older SDKs.
enum OnDeviceInsightStatus: Equatable {
    case available
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case unsupportedOSVersion   // Built/running below iOS 26 or SDK lacks the framework
    case unknownUnavailable

    var userMessage: String {
        switch self {
        case .available:
            return "On-device model ready."
        case .deviceNotEligible:
            return "This device doesn't support Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in Settings to use offline previews."
        case .modelNotReady:
            return "The on-device model is still downloading. Try again shortly."
        case .unsupportedOSVersion:
            return "Offline previews require iOS 26 or later."
        case .unknownUnavailable:
            return "The on-device model is currently unavailable."
        }
    }
}

enum OnDeviceInsightError: Error, LocalizedError {
    case unavailable(OnDeviceInsightStatus)
    case emptyInput
    case contextWindowExhausted
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let status): return status.userMessage
        case .emptyInput: return "There's no text to summarize yet."
        case .contextWindowExhausted:
            return "The passage is too long for the on-device model even after trimming."
        case .generationFailed(let detail): return detail
        }
    }
}

// MARK: - Service

struct OnDeviceInsightService {

    /// The on-device model's fixed context window (tokens). Confirmed 4,096 and,
    /// per Apple, not expected to change. Shared across instructions + prompt +
    /// schema + output — so we must trim input to leave headroom for the answer.
    static let contextWindowTokens = 4_096

    /// Conservative characters-per-token estimate for English (Apple cites
    /// ~3–4 chars/token). We use 3.0 to *under*-estimate our budget and stay safe.
    private static let charsPerToken = 3.0

    /// Tokens we reserve for instructions + schema + the generated answer.
    /// Leaves roughly 2,900 tokens (~8,700 chars) for the source passage.
    private static let reservedTokens = 1_200

    /// Max input characters we'll feed in a single session before trimming.
    static var maxInputCharacters: Int {
        Int(Double(contextWindowTokens - reservedTokens) * charsPerToken)
    }

    // MARK: Availability

    /// Reports whether the on-device model can be used right now. Safe to call
    /// on any OS/SDK — returns `.unsupportedOSVersion` when the framework or OS
    /// isn't present.
    func status() -> OnDeviceInsightStatus {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(.deviceNotEligible):
                return .deviceNotEligible
            case .unavailable(.appleIntelligenceNotEnabled):
                return .appleIntelligenceNotEnabled
            case .unavailable(.modelNotReady):
                return .modelNotReady
            case .unavailable:
                return .unknownUnavailable
            }
        } else {
            return .unsupportedOSVersion
        }
        #else
        return .unsupportedOSVersion
        #endif
    }

    // MARK: Generation

    /// Produces a structured offline preview from a guide's title/author/body.
    ///
    /// Strategy that respects the 4,096-token ceiling:
    ///  1. Trim the body to `maxInputCharacters` (we preview from the leading
    ///     portion — typically the executive summary / opening).
    ///  2. Run guided generation in a fresh session.
    ///  3. If the window still overflows, halve the input and retry in a *new*
    ///     session (Apple's prescribed recovery — a fresh window each time).
    func generatePreview(
        title: String,
        author: String,
        body: String
    ) async throws -> OnDeviceInsightPreview {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty else { throw OnDeviceInsightError.emptyInput }

        let status = status()
        guard status == .available else { throw OnDeviceInsightError.unavailable(status) }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            return try await runGuidedGeneration(title: title, author: author, body: trimmedBody)
        } else {
            throw OnDeviceInsightError.unavailable(.unsupportedOSVersion)
        }
        #else
        throw OnDeviceInsightError.unavailable(.unsupportedOSVersion)
        #endif
    }
}

// MARK: - Foundation Models implementation (iOS 26+)

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
extension OnDeviceInsightService {

    /// The guided-generation schema. Descriptions are deliberately terse —
    /// every character here spends context-window tokens.
    @Generable(description: "A concise offline preview of a long book analysis.")
    struct GeneratedPreview {
        @Guide(description: "A punchy one-line hook, at most 12 words.")
        var headline: String

        @Guide(description: "A plain-language summary of the core idea, 2–3 sentences.")
        var tldr: String

        @Guide(description: "3–5 core themes, each 1–3 words.")
        var themes: [String]

        @Guide(description: "3–6 lowercase topical tags for search and filtering.")
        var tags: [String]

        @Guide(description: "Estimated reading time, in minutes, for the full guide.", .range(1...240))
        var estimatedReadingMinutes: Int
    }

    private static let instructions = """
    You summarize long-form book analyses for a reading app. Be accurate and \
    concise. Never invent facts that aren't supported by the passage. Prefer \
    plain language over jargon.
    """

    func runGuidedGeneration(
        title: String,
        author: String,
        body: String
    ) async throws -> OnDeviceInsightPreview {
        // Cap output so the answer is guaranteed room inside the shared window.
        let options = GenerationOptions(maximumResponseTokens: 512)

        var inputBudget = Self.maxInputCharacters
        var attempt = 0
        let maxAttempts = 3

        while attempt < maxAttempts {
            attempt += 1
            let passage = String(body.prefix(inputBudget))

            // Fresh session per attempt → fresh 4,096-token window.
            let session = LanguageModelSession(instructions: Self.instructions)

            let prompt = """
            Title: \(title)
            Author: \(author)

            Passage:
            \(passage)

            Produce the preview from the passage above.
            """

            do {
                let response = try await session.respond(
                    to: prompt,
                    generating: GeneratedPreview.self,
                    options: options
                )
                let g = response.content
                return OnDeviceInsightPreview(
                    headline: g.headline,
                    tldr: g.tldr,
                    themes: g.themes,
                    tags: g.tags,
                    estimatedReadingMinutes: g.estimatedReadingMinutes
                )
            } catch let error as LanguageModelSession.GenerationError {
                switch error {
                case .exceededContextWindowSize:
                    // Halve the passage and try again in a new window.
                    inputBudget /= 2
                    if inputBudget < 500 {
                        throw OnDeviceInsightError.contextWindowExhausted
                    }
                    continue
                default:
                    throw OnDeviceInsightError.generationFailed(
                        error.failureReason ?? "\(error)"
                    )
                }
            }
        }
        throw OnDeviceInsightError.contextWindowExhausted
    }
}
#endif
