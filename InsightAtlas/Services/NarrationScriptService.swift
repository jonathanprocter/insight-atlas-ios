//
//  NarrationScriptService.swift
//  InsightAtlas
//
//  Turns a finished guide into a spoken-word narration script before it reaches
//  text-to-speech. The written guide is built for the eye — headings, citations,
//  and 30+ visual types a listener cannot see. This service asks MiniMax to
//  rewrite that content into audio-first prose that describes every visual in
//  words, so the narration is exactly as informative as the page.
//
//  Design notes:
//    - When MiniMax/OpenRouter is configured and reachable, the rewrite runs on
//      the first-listen critical path (see NarrationPreparationPolicy) with a
//      hard deadline so a stalled network call cannot hang forever.
//    - Offline, unreachable, timed-out, or too-short rewrites fall back to the
//      deterministic listening edition immediately.
//    - Only genuine rewrites are cached. Transient failures use a short TTL
//      skip marker so retries do not re-pay the full deadline, without pinning
//      a guide to the plain edition forever.
//

import Foundation
import Network
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

    /// Whether any generator can produce a script. MiniMax is primary;
    /// OpenRouter backs it up. When neither is configured the service is a
    /// pass-through and narration uses the raw guide content.
    private var isRewriteAvailable: Bool {
        isMiniMaxAvailable || KeychainService.shared.hasOpenRouterApiKey
    }

    /// Return a spoken narration script for `guideContent`, generating it via
    /// MiniMax (and caching) when possible. On any failure — or when MiniMax
    /// is unavailable — returns the listening-edition fallback so the caller
    /// can speak immediately.
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

        // Reuse a previously generated genuine rewrite for identical content.
        // Reject empty files and accidental fallback caches (v2 hangover).
        if let cacheURL, let cached = try? String(contentsOf: cacheURL, encoding: .utf8),
           !cached.isEmpty, cached != safeFallback {
            return cached
        }

        guard isRewriteAvailable else {
            scriptLog.info(
                "Neither MiniMax nor OpenRouter configured — narrating raw guide content for \(itemId.uuidString)"
            )
            return safeFallback
        }

        // A recent timeout/network failure should not re-impose the full
        // rewrite deadline on every Listen tap. Skip markers expire so MiniMax
        // can try again later without pinning the plain edition forever.
        if Self.hasFreshSkipMarker(for: itemId, content: trimmed, targetWords: targetWords) {
            scriptLog.info(
                "Skipping narration rewrite — fresh failure marker for \(itemId.uuidString)"
            )
            return safeFallback
        }

        // Credentials present does not mean the network is. Waiting for
        // connectivity under AIService's session burned up to 75s offline.
        guard await Self.hasSatisfiedNetworkPath() else {
            scriptLog.info(
                "No network path — narrating listening edition for \(itemId.uuidString)"
            )
            Self.writeSkipMarker(for: itemId, content: trimmed, targetWords: targetWords)
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
                // Rewrite the already-bounded listening edition, not the full
                // guide. Sending the whole manuscript inflated tokens, latency,
                // and the number of serial Pocket chunks that followed.
                let script = try await Self.withRewriteDeadline {
                    try await aiService.generateNarrationScript(
                        from: safeFallback,
                        title: title,
                        author: author,
                        targetWordCount: targetWords
                    )
                }
                let clamped = NarrationListeningEdition.prepare(
                    script,
                    summaryType: summaryType
                )
                let elapsed = Date().timeIntervalSince(start)
                let scriptWords = script.split(whereSeparator: { $0.isWhitespace }).count
                print(String(
                    format: "[Timing] narration script: %.1fs (%d → %d chars, %d words, target %d) for %@",
                    elapsed, safeFallback.count, clamped.count, scriptWords, targetWords, itemId.uuidString
                ))
                // A model asked for 2,400 words sometimes returns a few hundred.
                // That was accepted verbatim and cached, so a 16-minute guide
                // narrated for 90 seconds and every retry replayed it. Too
                // short is a failed rewrite, not a valid one.
                guard scriptWords >= Self.minimumAcceptableWords(forTarget: targetWords) else {
                    scriptLog.error(
                        "Narration-script rewrite returned \(scriptWords, privacy: .public) words against a target of \(targetWords, privacy: .public) — narrating the full bounded edition instead"
                    )
                    return safeFallback
                }
                return clamped.isEmpty ? safeFallback : clamped
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

        if result == safeFallback {
            Self.writeSkipMarker(for: itemId, content: trimmed, targetWords: targetWords)
        } else if let cacheURL {
            // Cache only a genuine rewrite.
            try? result.write(to: cacheURL, atomically: true, encoding: .utf8)
            Self.clearSkipMarker(for: itemId, content: trimmed, targetWords: targetWords)
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

    /// How long a failed rewrite should short-circuit before MiniMax is tried
    /// again for the same guide content.
    static let skipMarkerTTL: TimeInterval = 30 * 60

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

    /// A rewrite shorter than this is treated as a failure. Models undershoot
    /// a long target routinely; they do not legitimately deliver a third of it.
    static func minimumAcceptableWords(forTarget target: Int) -> Int {
        max(120, Int(Double(target) * 0.55))
    }

    // MARK: - Connectivity

    /// One-shot path check so offline devices with stored MiniMax tokens do
    /// not sit on `waitsForConnectivity` until the rewrite deadline.
    static func hasSatisfiedNetworkPath() async -> Bool {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "com.insightatlas.narration-path")
            let lock = NSLock()
            var resumed = false
            func finish(_ value: Bool) {
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true
                monitor.cancel()
                continuation.resume(returning: value)
            }
            monitor.pathUpdateHandler = { path in
                finish(path.status == .satisfied)
            }
            monitor.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 0.4) {
                finish(false)
            }
        }
    }

    // MARK: - Cache

    /// Bumped when a cached script could be invalid.
    /// v3: ignores v2 files that may contain listening-edition fallbacks from
    /// the brief "always cache" window, and introduces TTL skip markers.
    private static let cacheVersion = "v3"

    private static func cacheURL(for itemId: UUID, content: String, targetWords: Int) -> URL? {
        guard let dir = scriptCacheDirectory() else { return nil }
        let hash = Self.stableHash(content)
        return dir.appendingPathComponent("\(itemId.uuidString)-\(hash)-\(targetWords)-\(cacheVersion).txt")
    }

    private static func skipMarkerURL(for itemId: UUID, content: String, targetWords: Int) -> URL? {
        guard let dir = scriptCacheDirectory() else { return nil }
        let hash = Self.stableHash(content)
        return dir.appendingPathComponent("\(itemId.uuidString)-\(hash)-\(targetWords)-\(cacheVersion).skip")
    }

    private static func scriptCacheDirectory() -> URL? {
        guard let caches = FileManager.default.urls(
            for: .cachesDirectory, in: .userDomainMask
        ).first else { return nil }
        let dir = caches.appendingPathComponent("narration-scripts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func writeSkipMarker(for itemId: UUID, content: String, targetWords: Int) {
        guard let url = skipMarkerURL(for: itemId, content: content, targetWords: targetWords) else { return }
        let stamp = String(Date().timeIntervalSince1970)
        try? stamp.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func clearSkipMarker(for itemId: UUID, content: String, targetWords: Int) {
        guard let url = skipMarkerURL(for: itemId, content: content, targetWords: targetWords) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private static func hasFreshSkipMarker(for itemId: UUID, content: String, targetWords: Int) -> Bool {
        guard let url = skipMarkerURL(for: itemId, content: content, targetWords: targetWords),
              let stamp = try? String(contentsOf: url, encoding: .utf8),
              let epoch = TimeInterval(stamp.trimmingCharacters(in: .whitespacesAndNewlines))
        else { return false }
        let age = Date().timeIntervalSince1970 - epoch
        if age < 0 || age > skipMarkerTTL {
            try? FileManager.default.removeItem(at: url)
            return false
        }
        return true
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
