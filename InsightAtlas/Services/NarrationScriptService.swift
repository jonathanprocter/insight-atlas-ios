//
//  NarrationScriptService.swift
//  InsightAtlas
//
//  Turns a finished guide into a spoken-word narration script before it reaches
//  text-to-speech. The written guide is built for the eye — headings, citations,
//  and 30+ visual types a listener cannot see. This service asks MiniMax M2.7 to
//  rewrite that content into audio-first prose that describes every visual in
//  words, so the narration is exactly as informative as the page.
//
//  Design notes:
//    - Safe no-op: if the user is not signed into MiniMax, or the rewrite fails,
//      it returns the original guide content unchanged, preserving today's
//      behavior. Audio generation can never be blocked by this stage.
//    - Cached: the script is keyed by item id + a stable content hash and cached
//      on disk, so regenerating audio with a different voice or replaying does
//      not re-invoke the LLM.
//

import Foundation
import os.log

private let scriptLog = Logger(subsystem: "com.insightatlas", category: "NarrationScriptService")

actor NarrationScriptService {

    static let shared = NarrationScriptService()

    private let aiService = AIService()

    /// In-flight rewrites keyed by item + content hash. Concurrent narration
    /// requests (e.g. two providers, or auto-narrate racing a manual tap) share
    /// one MiniMax call instead of each paying for a separate rewrite.
    private var inFlight: [String: Task<String, Never>] = [:]

    /// Whether a MiniMax session exists to power the rewrite.
    private var isMiniMaxAvailable: Bool {
        KeychainService.shared.minimaxRefreshToken != nil ||
        KeychainService.shared.minimaxAccessToken != nil
    }

    /// Whether any generator can produce a script. MiniMax M2.7 is primary;
    /// OpenRouter backs it up. When neither is configured the service is a
    /// pass-through and narration uses the raw guide content.
    private var isRewriteAvailable: Bool {
        isMiniMaxAvailable || KeychainService.shared.hasOpenRouterApiKey
    }

    /// Return a spoken narration script for `guideContent`, generating it via
    /// MiniMax M2.7 (and caching) when possible. On any failure — or when MiniMax
    /// is unavailable — returns `guideContent` unchanged so the caller can fall
    /// back to the existing sanitize-and-speak path.
    func spokenScript(
        for itemId: UUID,
        guideContent: String,
        title: String? = nil,
        author: String? = nil,
        summaryType: SummaryType? = nil,
        fallbackContent: String? = nil,
        progress: (@Sendable (NarrationPreparationProgress) -> Void)? = nil
    ) async -> String {
        let trimmed = guideContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return guideContent }
        let safeFallback = fallbackContent ?? NarrationListeningEdition.prepare(
            trimmed,
            summaryType: summaryType
        )
        let targetWords = NarrationListeningEdition.maximumWords(for: summaryType)

        let cacheURL = Self.cacheURL(for: itemId, content: trimmed, targetWords: targetWords)

        // Reuse a previously generated script for identical content.
        if let cacheURL, let cached = try? String(contentsOf: cacheURL, encoding: .utf8),
           !cached.isEmpty {
            return cached
        }

        guard isRewriteAvailable else {
            scriptLog.info(
                "Neither MiniMax nor OpenRouter configured — narrating raw guide content for \(itemId.uuidString)"
            )
            return safeFallback
        }

        // Coalesce concurrent requests for the same item+content onto one call.
        let key = "\(itemId.uuidString)-\(Self.stableHash(trimmed))-\(targetWords)"
        if let existing = inFlight[key] {
            return await existing.value
        }

        let scriptGenerator = isMiniMaxAvailable ? AIProvider.minimax.displayName : "OpenRouter"
        let task = Task { [aiService] () -> String in
            do {
                try Task.checkCancellation()
                progress?(.generating(narrator: "Writing audio script · \(scriptGenerator)"))
                let start = Date()
                let script = try await Self.withRewriteDeadline {
                    try await aiService.generateNarrationScript(
                        from: trimmed,
                        title: title,
                        author: author,
                        targetWordCount: targetWords
                    )
                }
                let elapsed = Date().timeIntervalSince(start)
                print(String(
                    format: "[Timing] narration script: %.1fs (%d → %d chars) for %@",
                    elapsed, trimmed.count, script.count, itemId.uuidString
                ))
                return script
            } catch is CancellationError {
                return safeFallback
            } catch is NarrationScriptTimeout {
                scriptLog.error(
                    "Narration-script rewrite exceeded \(Self.rewriteDeadline, privacy: .public) — narrating raw guide content"
                )
                return safeFallback
            } catch {
                scriptLog.error(
                    "Narration-script rewrite failed [\(error.localizedDescription, privacy: .public)] — narrating raw guide content"
                )
                return safeFallback
            }
        }
        inFlight[key] = task
        // Clear on every exit path. Leaving a finished-or-abandoned task in the
        // map would make every later request for this guide await it forever,
        // turning one stalled rewrite into a permanent spinner that only an app
        // relaunch could clear.
        defer { inFlight[key] = nil }
        let result = await task.value

        // Cache only a genuine rewrite (not the raw-content fallback).
        if let cacheURL, result != safeFallback {
            try? result.write(to: cacheURL, atomically: true, encoding: .utf8)
        }
        return result
    }


    // MARK: - Deadline

    /// Longest the optional rewrite may delay audio.
    ///
    /// AIService allows 300s per request for guide generation, where a long
    /// wait is expected. Narration is different: this pass only improves how
    /// visuals are spoken, and audio cannot start until it returns. Inheriting
    /// the 300s budget meant a stalled rewrite blocked playback for five
    /// minutes with no visible progress before falling back.
    static let rewriteDeadline: Duration = .seconds(75)

    /// Run `work`, giving up after `rewriteDeadline` so a stalled rewrite
    /// cannot hold up synthesis.
    static func withRewriteDeadline<T: Sendable>(
        _ work: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T?.self) { group in
            group.addTask { try await work() }
            group.addTask {
                try await Task.sleep(for: rewriteDeadline)
                return nil
            }
            defer { group.cancelAll() }
            while let result = try await group.next() {
                if let result { return result }
                throw NarrationScriptTimeout()
            }
            throw NarrationScriptTimeout()
        }
    }

    // MARK: - Cache

    private static func cacheURL(for itemId: UUID, content: String, targetWords: Int) -> URL? {
        guard let caches = FileManager.default.urls(
            for: .cachesDirectory, in: .userDomainMask
        ).first else { return nil }
        let dir = caches.appendingPathComponent("narration-scripts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let hash = Self.stableHash(content)
        return dir.appendingPathComponent("\(itemId.uuidString)-\(hash)-\(targetWords).txt")
    }

    /// Stable (seed-independent) FNV-1a hash so cache keys survive app restarts,
    /// unlike Swift's randomized `Hasher`.
    private static func stableHash(_ string: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 16)
    }
}

/// The optional narration rewrite ran past its deadline; the caller narrates
/// the raw guide instead of waiting.
struct NarrationScriptTimeout: Error {}
