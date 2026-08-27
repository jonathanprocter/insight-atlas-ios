//
//  KokoroNarrationService.swift
//  InsightAtlas
//
//  Liam-only narration orchestration on top of `KokoroTTSClient`.
//
//  Responsibilities:
//  - Split summaries longer than the Kokoro 5,000-character request ceiling at
//    paragraph → sentence → whitespace boundaries (never truncates text).
//  - Synthesize each chunk sequentially (the backend serves one request at a
//    time), then assemble the parts into a single playable asset with
//    AVFoundation before the narration is considered `ready`.
//  - Save the completed audio into app-controlled Documents storage using the
//    app's existing `audio_<itemId>.<ext>` naming so playback, cleanup, and the
//    persisted relative filename all keep working.
//  - Preserve any existing valid audio until a replacement fully completes;
//    stage temporary parts and promote the final file atomically.
//  - Prevent duplicate concurrent narration jobs for the same summary.
//
//  The voice is never selectable — `KokoroTTSClient` always requests `am_liam`.
//

import Foundation
import AVFoundation
import os.log

private let logger = Logger(subsystem: "com.insightatlas", category: "KokoroNarration")

// MARK: - Narration Asset

/// The completed, persisted narration for a summary.
struct NarrationAsset {
    /// File name relative to the Documents directory (e.g. `audio_<uuid>.m4a`).
    let relativeFileName: String
    /// Always `am_liam`.
    let voiceID: String
    /// Duration of the assembled audio in seconds.
    let duration: TimeInterval
}

// MARK: - Narration Service Error

enum NarrationServiceError: LocalizedError {
    case alreadyInProgress
    case noConfiguredProvider
    case missingToken
    case emptyText
    case documentsDirectoryUnavailable
    case invalidAudio
    case assemblyFailed
    case network(String)
    case underlying(KokoroTTSError)

    var errorDescription: String? {
        switch self {
        case .alreadyInProgress:
            return "Narration is already being generated for this guide."
        case .noConfiguredProvider:
            return "Download the Kokoro on-device voice model in Settings → Audio & Narration before listening."
        case .missingToken:
            return "Add your Liam narration token in Settings → Audio & Narration."
        case .emptyText:
            return "There is no summary text to narrate."
        case .documentsDirectoryUnavailable:
            return "The app's Documents directory is unavailable."
        case .invalidAudio:
            return "The generated narration was not playable. Retry or choose another installed Kokoro voice."
        case .assemblyFailed:
            return "Failed to assemble the narration audio segments."
        case let .network(detail):
            return "Network error during narration: \(detail)"
        case let .underlying(error):
            return error.errorDescription
        }
    }
}

// MARK: - Narration Diagnostics

/// Result of the Settings → Audio "Test Liam narration" self-test. Each stage
/// is checked independently so the first failing stage pinpoints the cause.
struct NarrationDiagnostics: Sendable {
    var tokenPresent: Bool = false
    var healthOK: Bool = false
    var healthDetail: String = "Not run"
    var singleChunkOK: Bool = false
    var singleChunkDetail: String = "Not run"
    var assemblyOK: Bool = false
    var assemblyDetail: String = "Not run"

    var allPassed: Bool { tokenPresent && healthOK && singleChunkOK && assemblyOK }
}

// MARK: - Kokoro Narration Service

/// Serializes narration work and owns duplicate-job prevention.
///
/// This is an `actor` so its in-flight bookkeeping and the network/file
/// pipeline run off the main thread; only `DataManager` mutations hop to the
/// main actor.
actor KokoroNarrationService {

    static let shared = KokoroNarrationService()

    /// Kept safely below `KokoroTTSClient.maximumCharactersPerRequest` (5,000)
    /// so trimming/normalization inside the client can never push a chunk over.
    private static let maxChunkCharacters = 4_500

    /// The permanent, only voice.
    static let voice = KokoroTTSClient.voice

    private let client: KokoroTTSClient
    private var inFlight: Set<UUID> = []

    init(client: KokoroTTSClient = KokoroTTSClient()) {
        self.client = client
    }

    /// Whether a bearer token has been provisioned into the Keychain.
    nonisolated var isTokenConfigured: Bool {
        KokoroTTSClient.currentAPIKey() != nil
    }

    // MARK: - Pure synthesis (no persistence)

    /// Synthesize `text` into one completed asset saved under
    /// `Documents/audio_<itemId>.<ext>` and return its descriptor.
    ///
    /// Does not touch `DataManager`. Used both by the generation coordinator
    /// (the library item does not exist yet) and by `regenerate(...)`.
    /// Any existing audio for `itemId` is preserved until the new file is
    /// promoted atomically.
    func synthesizeAsset(text: String, itemId: UUID) async throws -> NarrationAsset {
        guard KokoroTTSClient.currentAPIKey() != nil else {
            throw NarrationServiceError.missingToken
        }

        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw NarrationServiceError.emptyText
        }

        guard !inFlight.contains(itemId) else {
            throw NarrationServiceError.alreadyInProgress
        }
        inFlight.insert(itemId)
        defer { inFlight.remove(itemId) }

        guard let documents = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first else {
            throw NarrationServiceError.documentsDirectoryUnavailable
        }

        let chunks = Self.splitText(normalized, maxCharacters: Self.maxChunkCharacters)
        logger.info("Narration: \(chunks.count) chunk(s) for item \(itemId.uuidString)")

        let relativeName: String
        let finalURL: URL

        if chunks.count <= 1 {
            // Single request — the client stages + replaces atomically for us.
            relativeName = "audio_\(itemId.uuidString).mp3"
            finalURL = documents.appendingPathComponent(relativeName)
            try await synthesizeChunkWithRetry(text: chunks.first ?? normalized, to: finalURL)
            // Remove a stale m4a sibling from a previous multi-chunk run, if any.
            removeSibling(of: finalURL, withExtension: "m4a")
        } else {
            relativeName = "audio_\(itemId.uuidString).m4a"
            finalURL = documents.appendingPathComponent(relativeName)
            try await synthesizeAndAssemble(chunks: chunks, itemId: itemId, to: finalURL)
            removeSibling(of: finalURL, withExtension: "mp3")
        }

        let duration = try await loadDuration(of: finalURL)
        return NarrationAsset(relativeFileName: relativeName, voiceID: Self.voice, duration: duration)
    }

    // MARK: - Diagnostics

    /// Runs a staged self-test against the Liam gateway: token → health →
    /// single-chunk synthesis → two-segment assembly. Never throws; each stage's
    /// outcome is captured so the first failure identifies the cause.
    func runDiagnostics() async -> NarrationDiagnostics {
        var result = NarrationDiagnostics()

        result.tokenPresent = KokoroTTSClient.currentAPIKey() != nil
        guard result.tokenPresent else {
            result.healthDetail = "Skipped — no token"
            result.singleChunkDetail = "Skipped — no token"
            result.assemblyDetail = "Skipped — no token"
            return result
        }

        // Stage 1: gateway reachability. The `/health` endpoint is informational
        // only — narration uses `/v1/audio/speech`, so "reachable" is the pass
        // condition here. A non-200 from `/health` must not read as a failure.
        do {
            let returns200 = try await client.health()
            result.healthOK = true // any HTTP response means the gateway is reachable
            result.healthDetail = returns200
                ? "200 OK"
                : "Reachable (health endpoint non-200; not used for narration)"
        } catch {
            result.healthOK = false
            result.healthDetail = "Unreachable — \(Self.readable(error))"
        }

        // Stage 2: single-chunk synthesis (exercises auth + audio return).
        let tmp = FileManager.default.temporaryDirectory
        let oneURL = tmp.appendingPathComponent("kokoro_diag_one_\(UUID().uuidString).mp3")
        defer { try? FileManager.default.removeItem(at: oneURL) }
        do {
            _ = try await client.synthesizeAndSave(
                text: "Insight Atlas narration check. This is the Liam voice.",
                to: oneURL
            )
            let bytes = (try? FileManager.default.attributesOfItem(atPath: oneURL.path)[.size] as? Int) ?? nil
            result.singleChunkOK = (bytes ?? 0) > 0
            result.singleChunkDetail = result.singleChunkOK
                ? "OK — \((bytes ?? 0) / 1024) KB"
                : "Empty audio returned"
        } catch {
            result.singleChunkDetail = Self.readable(error)
        }

        // Stage 3: two-segment assembly (only meaningful if synthesis works).
        guard result.singleChunkOK else {
            result.assemblyDetail = "Skipped — synthesis failed"
            return result
        }
        let aURL = tmp.appendingPathComponent("kokoro_diag_a_\(UUID().uuidString).mp3")
        let bURL = tmp.appendingPathComponent("kokoro_diag_b_\(UUID().uuidString).mp3")
        let outURL = tmp.appendingPathComponent("kokoro_diag_out_\(UUID().uuidString).m4a")
        defer { [aURL, bURL, outURL].forEach { try? FileManager.default.removeItem(at: $0) } }
        do {
            _ = try await client.synthesizeAndSave(text: "First narration segment for the assembly check.", to: aURL)
            _ = try await client.synthesizeAndSave(text: "Second narration segment for the assembly check.", to: bURL)
            try await assemble(parts: [aURL, bURL], to: outURL)
            let duration = try await loadDuration(of: outURL)
            result.assemblyOK = duration > 0
            result.assemblyDetail = result.assemblyOK
                ? String(format: "OK — %.1fs combined", duration)
                : "Zero-length output"
        } catch {
            result.assemblyDetail = Self.readable(error)
        }

        return result
    }

    private static func readable(_ error: Error) -> String {
        if let n = error as? NarrationServiceError { return n.errorDescription ?? "\(n)" }
        if let k = error as? KokoroTTSError { return k.errorDescription ?? "\(k)" }
        if let u = error as? URLError { return "Network: \(u.code)" }
        return error.localizedDescription
    }

    // MARK: - Managed regeneration (persists state via DataManager)

    /// Regenerate narration for an already-persisted item, driving the durable
    /// `NarrationState` transitions and preserving prior audio on failure.
    ///
    /// Returns the new asset on success, or `nil` if it failed / was blocked as
    /// a duplicate. State (`generating` → `ready`/`failed`) is written to
    /// `DataManager` so it survives relaunch.
    @discardableResult
    func regenerate(itemId: UUID, text: String) async -> NarrationAsset? {
        // Reflect the in-progress state durably before the (possibly long) job.
        await MainActor.run {
            DataManager.shared.setNarrationState(.generating, for: itemId)
        }

        do {
            let asset = try await synthesizeAsset(text: text, itemId: itemId)
            await MainActor.run {
                DataManager.shared.applyNarration(asset, for: itemId)
            }
            return asset
        } catch NarrationServiceError.alreadyInProgress {
            // A concurrent job owns this item; do not disturb its state.
            logger.info("Narration regenerate skipped (already in progress): \(itemId.uuidString)")
            return nil
        } catch {
            logger.error("Narration regenerate failed: \(error.localizedDescription)")
            // Leave any previously valid audio untouched; only mark the state.
            await MainActor.run {
                DataManager.shared.markNarrationFailed(for: itemId)
            }
            return nil
        }
    }

    // MARK: - Chunk synthesis + assembly

    private func synthesizeAndAssemble(chunks: [String], itemId: UUID, to finalURL: URL) async throws {
        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent("kokoro_narration_\(itemId.uuidString)_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }

        var partURLs: [URL] = []
        for (index, chunk) in chunks.enumerated() {
            try Task.checkCancellation()
            let partURL = staging.appendingPathComponent("part_\(index).mp3")
            try await synthesizeChunkWithRetry(text: chunk, to: partURL)
            partURLs.append(partURL)
        }

        let assembled = staging.appendingPathComponent("assembled.m4a")
        try await assemble(parts: partURLs, to: assembled)

        // Atomically promote — prior audio at finalURL survives until this point.
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: finalURL.path) {
            _ = try fileManager.replaceItemAt(finalURL, withItemAt: assembled)
        } else {
            try fileManager.moveItem(at: assembled, to: finalURL)
        }
    }

    /// Merge MP3 parts into a single AAC/M4A file using AVFoundation.
    private func assemble(parts: [URL], to outputURL: URL) async throws {
        guard !parts.isEmpty else { throw NarrationServiceError.assemblyFailed }

        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw NarrationServiceError.assemblyFailed
        }

        var cursor = CMTime.zero
        for part in parts {
            let asset = AVURLAsset(url: part)
            let assetTracks = try await asset.loadTracks(withMediaType: .audio)
            guard let assetTrack = assetTracks.first else { continue }
            let duration = try await asset.load(.duration)
            try track.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: assetTrack,
                at: cursor
            )
            cursor = CMTimeAdd(cursor, duration)
        }

        try? FileManager.default.removeItem(at: outputURL)
        guard let export = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw NarrationServiceError.assemblyFailed
        }
        export.outputURL = outputURL
        export.outputFileType = .m4a
        await export.export()
        guard export.status == .completed else {
            if let error = export.error {
                logger.error("Narration assembly export failed: \(error.localizedDescription)")
            }
            throw NarrationServiceError.assemblyFailed
        }
    }

    /// Synthesize a single chunk to `destinationURL` with bounded backoff for
    /// transient backend conditions (429 / 5xx). Non-transient errors (401,
    /// 422, missing token, empty text) fail immediately.
    private func synthesizeChunkWithRetry(text: String, to destinationURL: URL) async throws {
        let maxAttempts = 3
        var delaySeconds: UInt64 = 2

        for attempt in 1...maxAttempts {
            try Task.checkCancellation()
            do {
                _ = try await client.synthesizeAndSave(text: text, to: destinationURL)
                return
            } catch let error as KokoroTTSError {
                guard Self.isTransient(error), attempt < maxAttempts else {
                    throw NarrationServiceError.underlying(error)
                }
                logger.warning("Transient narration error (attempt \(attempt)): \(error.localizedDescription)")
                try await Task.sleep(nanoseconds: delaySeconds * 1_000_000_000)
                delaySeconds = min(delaySeconds * 2, 8)
            } catch let urlError as URLError {
                // Network failures (timeout, connection loss) are thrown as
                // URLError by URLSession and previously bypassed retry entirely.
                guard attempt < maxAttempts else {
                    throw NarrationServiceError.network(urlError.localizedDescription)
                }
                logger.warning("Network narration error (attempt \(attempt)): \(urlError.localizedDescription)")
                try await Task.sleep(nanoseconds: delaySeconds * 1_000_000_000)
                delaySeconds = min(delaySeconds * 2, 8)
            }
        }
    }

    private static func isTransient(_ error: KokoroTTSError) -> Bool {
        switch error {
        case let .server(statusCode, _):
            return statusCode == 429 || (500...599).contains(statusCode)
        case .invalidResponse:
            return true
        case .missingAPIKey, .emptyText, .textTooLong, .invalidAudio, .documentsDirectoryUnavailable:
            return false
        }
    }

    // MARK: - Helpers

    private func loadDuration(of url: URL) async throws -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }

    private func removeSibling(of url: URL, withExtension ext: String) {
        let sibling = url.deletingPathExtension().appendingPathExtension(ext)
        guard sibling.path != url.path else { return }
        try? FileManager.default.removeItem(at: sibling)
    }

    // MARK: - Deterministic text splitting

    /// Split text so each chunk stays within `maxCharacters`, breaking first on
    /// paragraph boundaries, then sentences, then whitespace. Never drops text.
    static func splitText(_ text: String, maxCharacters: Int) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= maxCharacters { return trimmed.isEmpty ? [] : [trimmed] }

        // Paragraphs first, preserving them as atomic where possible.
        let paragraphs = trimmed.components(separatedBy: "\n\n")
        var chunks: [String] = []
        var current = ""

        func flush() {
            let piece = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !piece.isEmpty { chunks.append(piece) }
            current = ""
        }

        for paragraph in paragraphs {
            let unit = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            if unit.isEmpty { continue }

            if unit.count > maxCharacters {
                // Paragraph itself too large — descend to sentences/words.
                flush()
                for sub in splitLongUnit(unit, maxCharacters: maxCharacters) {
                    if sub.count > maxCharacters {
                        chunks.append(sub) // last-resort hard slice already applied
                    } else if current.count + sub.count + 1 > maxCharacters {
                        flush()
                        current = sub
                    } else {
                        current = current.isEmpty ? sub : current + " " + sub
                    }
                }
            } else if current.count + unit.count + 2 > maxCharacters {
                flush()
                current = unit
            } else {
                current = current.isEmpty ? unit : current + "\n\n" + unit
            }
        }
        flush()
        return chunks
    }

    /// Break an oversized unit into sentence-sized pieces, then word-sized, then
    /// a hard character slice as a final guarantee.
    private static func splitLongUnit(_ unit: String, maxCharacters: Int) -> [String] {
        let sentences = unit
            .replacingOccurrences(of: "([.!?])\\s+", with: "$1\u{0001}", options: .regularExpression)
            .components(separatedBy: "\u{0001}")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var result: [String] = []
        for sentence in sentences {
            if sentence.count <= maxCharacters {
                result.append(sentence)
                continue
            }
            // Split by words.
            var buffer = ""
            for word in sentence.split(separator: " ") {
                let w = String(word)
                if w.count > maxCharacters {
                    if !buffer.isEmpty { result.append(buffer); buffer = "" }
                    result.append(contentsOf: hardSlice(w, maxCharacters: maxCharacters))
                } else if buffer.count + w.count + 1 > maxCharacters {
                    result.append(buffer)
                    buffer = w
                } else {
                    buffer = buffer.isEmpty ? w : buffer + " " + w
                }
            }
            if !buffer.isEmpty { result.append(buffer) }
        }
        return result
    }

    private static func hardSlice(_ text: String, maxCharacters: Int) -> [String] {
        var pieces: [String] = []
        var index = text.startIndex
        while index < text.endIndex {
            let end = text.index(index, offsetBy: maxCharacters, limitedBy: text.endIndex) ?? text.endIndex
            pieces.append(String(text[index..<end]))
            index = end
        }
        return pieces
    }
}
