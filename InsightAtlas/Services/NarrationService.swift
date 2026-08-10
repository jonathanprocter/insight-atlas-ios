//
//  NarrationService.swift
//  InsightAtlas
//
//  Narration orchestration with a primary/fallback provider policy:
//    1. Mega Transcript — Arthur preferred from the live English catalog.
//    2. Kokoro / Liam — fallback when Mega is unavailable or fails.
//
//  Both paths converge on the app's standard `NarrationAsset` contract: a file
//  written into Documents as `audio_<itemId>.<ext>` plus a duration and voice
//  id. Because the output shape is identical to `KokoroNarrationService`, every
//  existing caller (GuideView, GenerationView) and the playback/persistence
//  layer keep working unchanged — only the source of the audio differs.
//
//  Mega Transcript is isolated behind `MegaTranscriptServicing` so a future
//  distributed build can move the vendor request behind an app-owned backend.
//

import Foundation
import os.log

private let narrationLog = Logger(subsystem: "com.insightatlas", category: "NarrationService")

actor NarrationService {

    static let shared = NarrationService()

    /// Retained for the pre-existing OpenAI diagnostics in
    /// `KokoroNarrationService`; it is no longer the primary narration path.
    static let openAIVoice = "onyx"

    /// Synthesize narration for `itemId`, preferring Mega Transcript and falling
    /// back to the existing Kokoro/Liam pipeline. Cancellation never triggers a
    /// paid fallback request.
    func synthesize(
        text: String,
        itemId: UUID,
        progress: @escaping @Sendable (NarrationPreparationProgress) -> Void = { _ in }
    ) async throws -> NarrationAsset {
        let spokenText = NarrationTextSanitizer.prepare(text)
        guard !spokenText.isEmpty else { throw NarrationServiceError.emptyText }

        if MegaTranscriptNarrationCoordinator.shared.isConfigured {
            do {
                let result = try await MegaTranscriptNarrationCoordinator.shared.synthesize(
                    text: text,
                    itemID: itemId,
                    progress: progress
                )
                narrationLog.info(
                    "Narration via Mega Transcript (\(result.voice.name, privacy: .public), cache: \(result.cacheHit)) for \(itemId.uuidString)"
                )
                return result.asset
            } catch MegaTranscriptError.cancelled {
                throw MegaTranscriptError.cancelled
            } catch is CancellationError {
                throw MegaTranscriptError.cancelled
            } catch {
                let reason = error.localizedDescription
                progress(.fallingBackToLiam(reason: reason))
                // Log the REAL failure so a silent Liam fallback is diagnosable.
                // The concrete case identifies the root cause at a glance:
                //   .unauthorized  → bad key / wrong auth header
                //   .notFound      → wrong endpoint path
                //   .decodingFailed→ response schema mismatch
                //   .serverError   → vendor-side / status code
                //   .network       → connectivity / TLS / timeout
                // (This is the user's own device console; the detail is
                // diagnostic, not a secret — the API key itself is never logged.)
                let detail = (error as? MegaTranscriptError).map { String(describing: $0) } ?? reason
                narrationLog.error("Mega Transcript failed [\(detail, privacy: .public)] — falling back to Liam")
            }
        } else {
            let reason = "Arthur is not configured; using Liam fallback."
            progress(.fallingBackToLiam(reason: reason))
            narrationLog.info("No Mega Transcript credential; using Liam narration for \(itemId.uuidString)")
        }

        let asset = try await KokoroNarrationService.shared.synthesizeAsset(text: spokenText, itemId: itemId)
        progress(.ready(narrator: "Liam"))
        return asset
    }

    // MARK: - OpenAI path

    private func synthesizeWithOpenAI(text: String, itemId: UUID, useOAuth: Bool) async throws -> NarrationAsset {
        let service = OpenAIAudioService()
        if useOAuth {
            // Authenticate with the ChatGPT login token (mirrors Codex CLI auth).
            service.bearerOverride = try await ChatGPTOAuthService.shared.validAccessToken()
            service.accountIDHeader = ChatGPTOAuthService.storedAccountID
        }

        // OpenAIAudioService chunks long text and returns fully-assembled audio.
        let audio = try await service.generateAudio(text: text, voiceID: Self.openAIVoice, speed: 1.0)
        guard !audio.data.isEmpty else { throw OpenAIAudioError.audioDecodingFailed }

        guard let documents = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first else {
            throw NarrationServiceError.documentsDirectoryUnavailable
        }

        // Single-chunk output is MP3; multi-chunk is assembled to M4A. Pick the
        // extension from the container so playback/type detection stays correct.
        let ext = Self.fileExtension(for: audio.data)
        let relativeName = "audio_\(itemId.uuidString).\(ext)"
        let finalURL = documents.appendingPathComponent(relativeName)
        let fm = FileManager.default

        // Stage then promote atomically so prior audio survives until success.
        let staging = documents.appendingPathComponent(
            ".\(relativeName).\(UUID().uuidString).partial"
        )
        try? fm.removeItem(at: staging)
        try audio.data.write(to: staging, options: .atomic)
        if fm.fileExists(atPath: finalURL.path) {
            _ = try fm.replaceItemAt(finalURL, withItemAt: staging)
        } else {
            try fm.moveItem(at: staging, to: finalURL)
        }

        // Remove a stale sibling written by a previous run with the other format.
        let otherExt = (ext == "mp3") ? "m4a" : "mp3"
        try? fm.removeItem(at: documents.appendingPathComponent("audio_\(itemId.uuidString).\(otherExt)"))

        return NarrationAsset(
            relativeFileName: relativeName,
            voiceID: audio.voiceID,
            duration: audio.duration
        )
    }

    /// Detect the audio container: MP4/M4A files carry an "ftyp" box at bytes
    /// 4–7; otherwise treat it as MP3.
    private static func fileExtension(for data: Data) -> String {
        if data.count >= 8, data.subdata(in: 4..<8) == Data("ftyp".utf8) {
            return "m4a"
        }
        return "mp3"
    }
}
