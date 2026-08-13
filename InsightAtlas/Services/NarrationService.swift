//
//  NarrationService.swift
//  InsightAtlas
//
//  Narration orchestration with an offline-first provider policy:
//    1. Kokoro — premium on-device narration with no per-use fee.
//    2. Mega Transcript — Arthur preferred from the live English catalog.
//    3. OpenAI Audio API — authenticated with the device's OpenAI API key.
//    4. Liam — the last and final fallback.
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
    case kokoro
    case megaTranscript
    case openAI
    case liam
}

enum NarrationFallbackPolicy {
    static func orderedRoutes(
        kokoroConfigured: Bool,
        megaTranscriptConfigured: Bool,
        openAIConfigured: Bool,
        liamConfigured: Bool
    ) -> [NarrationProviderRoute] {
        var routes: [NarrationProviderRoute] = []
        if kokoroConfigured { routes.append(.kokoro) }
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
    /// Kokoro -> Mega Transcript -> OpenAI Audio API -> Liam.
    /// Cancellation never triggers another provider request.
    func synthesize(
        text: String,
        itemId: UUID,
        progress: @escaping @Sendable (NarrationPreparationProgress) -> Void = { _ in }
    ) async throws -> NarrationAsset {
        let spokenText = NarrationTextSanitizer.prepare(text)
        guard !spokenText.isEmpty else { throw NarrationServiceError.emptyText }

        let routes = NarrationFallbackPolicy.orderedRoutes(
            kokoroConfigured: KokoroModelStore.isInstalled,
            megaTranscriptConfigured: MegaTranscriptNarrationCoordinator.shared.isConfigured,
            openAIConfigured: KeychainService.shared.hasOpenAIApiKey,
            liamConfigured: KokoroTTSClient.currentAPIKey() != nil
        )
        guard !routes.isEmpty else { throw NarrationServiceError.noConfiguredProvider }

        var lastFailure: Error?

        for route in routes {
            try Task.checkCancellation()

            switch route {
            case .kokoro:
                let voice = Self.selectedKokoroVoice()
                progress(.generating(narrator: "Kokoro · \(voice.name)"))
                do {
                    let audio = try await KokoroAudioService.shared.generateAudio(
                        text: spokenText,
                        voiceID: voice.voiceID
                    )
                    let asset = try persist(audio: audio, itemId: itemId)
                    progress(.ready(narrator: "Kokoro · \(voice.name)"))
                    narrationLog.info(
                        "Narration via on-device Kokoro (\(voice.name, privacy: .public)) for \(itemId.uuidString)"
                    )
                    return asset
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    lastFailure = error
                    narrationLog.error(
                        "On-device Kokoro failed [\(error.localizedDescription, privacy: .public)] — moving to the next configured narration provider"
                    )
                }

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

        // Remove stale siblings written by previous providers in other containers.
        for otherExt in ["wav", "mp3", "m4a"] where otherExt != ext {
            try? fm.removeItem(
                at: documents.appendingPathComponent("audio_\(itemId.uuidString).\(otherExt)")
            )
        }

        return NarrationAsset(
            relativeFileName: relativeName,
            voiceID: audio.voiceID,
            duration: audio.duration
        )
    }

    /// Detect WAV, MP4/M4A, and MP3 containers produced by the configured routes.
    static func fileExtension(for data: Data) -> String {
        if data.count >= 4, data.prefix(4) == Data("RIFF".utf8) {
            return "wav"
        }
        if data.count >= 8, data.subdata(in: 4..<8) == Data("ftyp".utf8) {
            return "m4a"
        }
        return "mp3"
    }

    private static func selectedKokoroVoice() -> KokoroVoice {
        guard let voiceID = UserDefaults.standard.string(
            forKey: KokoroVoiceRegistry.selectedVoiceStorageKey
        ) else {
            return KokoroVoiceRegistry.defaultVoice
        }
        return KokoroVoiceRegistry.voice(byVoiceID: voiceID)
            ?? KokoroVoiceRegistry.defaultVoice
    }
}
