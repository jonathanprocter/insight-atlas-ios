//
//  NarrationService.swift
//  InsightAtlas
//
//  Narration orchestration with an offline-first provider policy:
//    1. Kokoro — premium on-device narration with no per-use fee.
//    2. Liam — the hosted Kokoro voice, used as the final fallback.
//
//  All providers converge on the app's standard `NarrationAsset` contract: a file
//  written into Documents as `audio_<itemId>.<ext>` plus a duration and voice
//  id. Because the output shape is identical to `KokoroNarrationService`, every
//  existing caller (GuideView, GenerationView) and the playback/persistence
//  layer keep working unchanged — only the source of the audio differs.
//

import Foundation
import os.log

private let narrationLog = Logger(subsystem: "com.insightatlas", category: "NarrationService")

enum NarrationProviderRoute: String, Equatable, Sendable {
    case kokoro
    case liam
}

enum NarrationFallbackPolicy {
    static func orderedRoutes(
        kokoroConfigured: Bool,
        liamConfigured: Bool
    ) -> [NarrationProviderRoute] {
        var routes: [NarrationProviderRoute] = []
        if kokoroConfigured { routes.append(.kokoro) }
        if liamConfigured { routes.append(.liam) }
        return routes
    }
}

actor NarrationService {

    static let shared = NarrationService()

    /// Synthesize narration for `itemId` using the fixed provider order:
    /// on-device Kokoro -> hosted Liam.
    /// Cancellation never triggers another provider request.
    func synthesize(
        text: String,
        itemId: UUID,
        progress: @escaping @Sendable (NarrationPreparationProgress) -> Void = { _ in }
    ) async throws -> NarrationAsset {
        // Rewrite the written guide into an audio-first script (describing every
        // visual in words) when MiniMax is available. Safe pass-through otherwise:
        // `spokenScript` returns `text` unchanged on any failure.
        let narrationSource = await NarrationScriptService.shared.spokenScript(
            for: itemId,
            guideContent: text,
            progress: progress
        )
        let spokenText = NarrationTextSanitizer.prepare(narrationSource)
        guard !spokenText.isEmpty else { throw NarrationServiceError.emptyText }

        let routes = NarrationFallbackPolicy.orderedRoutes(
            kokoroConfigured: KokoroModelStore.isInstalled,
            liamConfigured: KokoroTTSClient.currentAPIKey() != nil
        )
        guard !routes.isEmpty else { throw NarrationServiceError.noConfiguredProvider }

        var lastFailure: Error?

        for route in routes {
            try Task.checkCancellation()

            switch route {
            case .kokoro:
                let voice = Self.selectedKokoroVoice()
                let narrator = "Kokoro · \(voice.name)"
                progress(.generating(narrator: narrator))
                do {
                    let audio = try await KokoroAudioService.shared.generateAudio(
                        text: spokenText,
                        voiceID: voice.voiceID,
                        onProgress: { fraction in
                            progress(.synthesizing(narrator: narrator, fraction: fraction))
                        }
                    )
                    let asset = try persist(audio: audio, itemId: itemId)
                    progress(.ready(narrator: narrator))
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
