//
//  NarrationService.swift
//  InsightAtlas
//
//  Narration orchestration with a stable primary/fallback provider policy:
//    1. Mega Transcript — Arthur preferred from the live English catalog.
//    2. OpenAI Audio API — authenticated with the device's OpenAI API key.
//    3. Kokoro / Liam — the last and final fallback.
//
//  All providers converge on the app's standard `NarrationAsset` contract: a file
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

enum NarrationProviderRoute: String, Equatable, Sendable {
    case megaTranscript
    case openAI
    case liam
}

enum NarrationFallbackPolicy {
    static func orderedRoutes(
        megaTranscriptConfigured: Bool,
        openAIConfigured: Bool,
        liamConfigured: Bool
    ) -> [NarrationProviderRoute] {
        var routes: [NarrationProviderRoute] = []
        if megaTranscriptConfigured { routes.append(.megaTranscript) }
        if openAIConfigured { routes.append(.openAI) }
        if liamConfigured { routes.append(.liam) }
        return routes
    }
}

actor NarrationService {

    static let shared = NarrationService()

    /// Stable OpenAI fallback voice. Onyx is supported by gpt-4o-mini-tts and
    /// preserves the app's established authoritative narration character.
    static let openAIVoice = "onyx"

    /// Synthesize narration for `itemId` using the fixed provider order:
    /// Mega Transcript -> OpenAI Audio API -> Liam. ChatGPT consumer OAuth is
    /// intentionally excluded because it is not supported API authentication.
    /// Cancellation never triggers another provider request.
    func synthesize(
        text: String,
        itemId: UUID,
        progress: @escaping @Sendable (NarrationPreparationProgress) -> Void = { _ in }
    ) async throws -> NarrationAsset {
        let spokenText = NarrationTextSanitizer.prepare(text)
        guard !spokenText.isEmpty else { throw NarrationServiceError.emptyText }

        let routes = NarrationFallbackPolicy.orderedRoutes(
            megaTranscriptConfigured: MegaTranscriptNarrationCoordinator.shared.isConfigured,
            openAIConfigured: KeychainService.shared.hasOpenAIApiKey,
            liamConfigured: KokoroTTSClient.currentAPIKey() != nil
        )
        guard !routes.isEmpty else { throw NarrationServiceError.noConfiguredProvider }

        var lastFailure: Error?

        for route in routes {
            try Task.checkCancellation()

            switch route {
            case .megaTranscript:
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
                    throw CancellationError()
                } catch {
                    lastFailure = error
                    let detail = (error as? MegaTranscriptError).map { String(describing: $0) }
                        ?? error.localizedDescription
                    narrationLog.error(
                        "Mega Transcript failed [\(detail, privacy: .public)] — moving to the next configured narration provider"
                    )
                }

            case .openAI:
                if let lastFailure {
                    progress(.fallingBackToOpenAI(reason: lastFailure.localizedDescription))
                } else {
                    progress(.generating(narrator: "OpenAI API · Onyx"))
                }

                do {
                    let asset = try await synthesizeWithOpenAI(text: spokenText, itemId: itemId)
                    progress(.ready(narrator: "OpenAI API · Onyx"))
                    narrationLog.info("Narration via OpenAI API (Onyx) for \(itemId.uuidString)")
                    return asset
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    lastFailure = error
                    narrationLog.error(
                        "OpenAI Audio API failed [\(error.localizedDescription, privacy: .public)] — moving to the next configured narration provider"
                    )
                }

            case .liam:
                let reason = lastFailure?.localizedDescription
                    ?? "Using Liam as the final configured narration provider."
                progress(.fallingBackToLiam(reason: reason))
                do {
                    let asset = try await KokoroNarrationService.shared.synthesizeAsset(
                        text: spokenText,
                        itemId: itemId
                    )
                    progress(.ready(narrator: "Liam"))
                    narrationLog.info("Narration via Liam final fallback for \(itemId.uuidString)")
                    return asset
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    lastFailure = error
                }
            }
        }

        throw lastFailure ?? NarrationServiceError.noConfiguredProvider
    }

    // MARK: - OpenAI API path

    private func synthesizeWithOpenAI(text: String, itemId: UUID) async throws -> NarrationAsset {
        let service = OpenAIAudioService()
        // OpenAIAudioService chunks long text and returns fully-assembled audio.
        let audio = try await service.generateAudio(text: text, voiceID: Self.openAIVoice, speed: 1.0)
        guard !audio.data.isEmpty else { throw OpenAIAudioError.audioDecodingFailed }
        return try persist(audio: audio, itemId: itemId)
    }

    private func persist(audio: GeneratedAudio, itemId: UUID) throws -> NarrationAsset {
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
