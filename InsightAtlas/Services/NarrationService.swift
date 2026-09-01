//
//  NarrationService.swift
//  InsightAtlas
//
//  Narration orchestration with a zero-download Apple system voice first,
//  optional Kokoro second, and configured hosted Liam as a final fallback.
//
//  Successful output conforms to the app's standard `NarrationAsset` contract:
//  a validated file in Documents plus duration and voice metadata shared by the
//  reader, library, and export paths.
//

import Foundation
import AVFoundation
import UIKit
import os.log

private let narrationLog = Logger(subsystem: "com.insightatlas", category: "NarrationService")

enum NarrationProviderRoute: String, Equatable, Sendable {
    case system
    case kokoro
    case liam
}

enum NarrationFallbackPolicy {
    static func orderedRoutes(
        kokoroConfigured: Bool,
        liamConfigured: Bool
    ) -> [NarrationProviderRoute] {
        var routes: [NarrationProviderRoute] = [.system]
        if kokoroConfigured { routes.append(.kokoro) }
        if liamConfigured { routes.append(.liam) }
        return routes
    }
}

enum NarrationPreparationPolicy {
    /// MiniMax writes the bounded, audio-first summary before Kokoro speaks it.
    static let rewritesBeforeInitialSynthesis = true
}

enum NarrationListeningEdition {
    static func maximumWords(for summaryType: SummaryType?) -> Int {
        switch summaryType {
        case .quickReference: return 900
        case .professional, .none: return 2_400
        case .accessible: return 3_000
        case .deepResearch: return 3_600
        }
    }

    static func prepare(
        _ content: String,
        summaryType: SummaryType?,
        maximumWordsOverride: Int? = nil
    ) -> String {
        let sanitized = NarrationTextSanitizer.prepare(content)
        let budget = max(1, maximumWordsOverride ?? maximumWords(for: summaryType))
        let words = sanitized.split(whereSeparator: { $0.isWhitespace })
        guard words.count > budget else { return sanitized }

        let paragraphs = sanitized
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard paragraphs.count > 1 else {
            return words.prefix(budget).joined(separator: " ")
        }

        let averageWords = max(1, words.count / paragraphs.count)
        let selectionCount = min(paragraphs.count, max(2, budget / averageWords))
        let rawIndices = (0..<selectionCount).map { position -> Int in
            guard selectionCount > 1 else { return 0 }
            return Int(
                (Double(position) * Double(paragraphs.count - 1)
                    / Double(selectionCount - 1)).rounded()
            )
        }
        let indices = Array(Set(rawIndices)).sorted()
        let perSectionBudget = max(1, budget / max(1, indices.count))

        return indices.map { index in
            boundedParagraph(paragraphs[index], wordLimit: perSectionBudget)
        }
        .joined(separator: "\n\n")
    }

    private static func boundedParagraph(_ paragraph: String, wordLimit: Int) -> String {
        let words = paragraph.split(whereSeparator: { $0.isWhitespace })
        guard words.count > wordLimit else { return paragraph }

        let prefix = words.prefix(wordLimit).joined(separator: " ")
        if let punctuationIndex = prefix.lastIndex(where: { ".!?".contains($0) }) {
            let complete = String(prefix[...punctuationIndex])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if complete.split(whereSeparator: { $0.isWhitespace }).count >= min(5, wordLimit) {
                return complete
            }
        }

        return prefix.trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}

enum NarrationAudioValidation {
    static func hasSupportedContainer(_ data: Data) -> Bool {
        if data.count >= 4, data.prefix(4) == Data("RIFF".utf8) { return true }
        if data.count >= 8, data.subdata(in: 4..<8) == Data("ftyp".utf8) { return true }
        if data.count >= 3, data.prefix(3) == Data("ID3".utf8) { return true }
        if data.count >= 2 {
            let bytes = [UInt8](data.prefix(2))
            if bytes[0] == 0xFF, bytes[1] & 0xE0 == 0xE0 { return true }
        }
        return false
    }

    static func validatedDuration(
        at url: URL,
        declaredDuration: TimeInterval
    ) async throws -> TimeInterval {
        guard declaredDuration.isFinite, declaredDuration > 0 else {
            throw NarrationServiceError.invalidAudio
        }

        let asset = AVURLAsset(url: url)
        let isPlayable = try await asset.load(.isPlayable)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        let duration = try await asset.load(.duration).seconds
        guard isPlayable, !tracks.isEmpty, duration.isFinite, duration > 0 else {
            throw NarrationServiceError.invalidAudio
        }
        return duration
    }
}

/// Keeps the app running briefly after it is backgrounded so narration in
/// flight is not suspended the moment the user leaves.
///
/// Guide generation already did this; narration never did, so leaving the app
/// mid-render simply killed it and the audio never appeared. iOS grants only a
/// short window, so this rescues shorter renders rather than guaranteeing long
/// ones -- server-side synthesis is the durable answer for a full guide.
@MainActor
final class NarrationBackgroundAssertion {
    private var identifier: UIBackgroundTaskIdentifier = .invalid

    func begin() {
        guard identifier == .invalid else { return }
        identifier = UIApplication.shared.beginBackgroundTask(withName: "NarrationSynthesis") { [weak self] in
            self?.end()
        }
    }

    func end() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}

/// Tracks when narration last made observable progress.
///
/// A long guide legitimately takes minutes, so a fixed total timeout would
/// abort healthy work. What is never acceptable is silence: no model load, no
/// chunk completing, nothing, indefinitely.
private actor ProgressHeartbeat {
    private var last = ContinuousClock.now
    func beat() { last = ContinuousClock.now }
    func idleFor() -> Duration { ContinuousClock.now - last }
}

/// Narration stalled with no progress for `NarrationService.stallTimeout`.
struct NarrationStalled: LocalizedError {
    let stage: String
    var errorDescription: String? {
        "Narration stopped responding while \(stage). Retry or choose another installed Kokoro voice."
    }
}

actor NarrationService {

    static let shared = NarrationService()

    /// Longest narration may go without any observable progress before the
    /// route is abandoned. On-device synthesis reports per chunk, so healthy
    /// work never approaches this.
    static let stallTimeout: Duration = .seconds(120)

    /// Run `work`, failing if `heartbeat` reports no progress for
    /// `stallTimeout`. The heartbeat is beaten by the progress callbacks the
    /// caller wires into `work`.
    private func withStallDetection<T: Sendable>(
        stage: String,
        heartbeat: ProgressHeartbeat,
        _ work: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T?.self) { group in
            group.addTask { try await work() }
            group.addTask {
                while true {
                    try await Task.sleep(for: .seconds(5))
                    if await heartbeat.idleFor() > Self.stallTimeout { return nil }
                }
            }
            defer { group.cancelAll() }
            while let result = try await group.next() {
                if let result { return result }
                throw NarrationStalled(stage: stage)
            }
            throw NarrationStalled(stage: stage)
        }
    }

    /// Synthesize narration for `itemId`: MiniMax writes the bounded
    /// audio-summary script, then the built-in system voice speaks it without
    /// requiring a model download.
    func synthesize(
        text: String,
        itemId: UUID,
        summaryType: SummaryType? = nil,
        progress: @escaping @Sendable (NarrationPreparationProgress) -> Void = { _ in }
    ) async throws -> NarrationAsset {
        // Keep a deterministic bounded edition as the safe fallback, but let
        // MiniMax create the actual audio-first summary when it is configured.
        // Hold a background assertion for the whole attempt so leaving the app
        // does not suspend an in-flight render.
        let assertion = await NarrationBackgroundAssertion()
        await assertion.begin()
        await MemoryPressureCoordinator.shared.beginSynthesis()
        defer {
            Task { @MainActor in
                assertion.end()
                MemoryPressureCoordinator.shared.endSynthesis()
            }
        }

        let fallbackText = NarrationListeningEdition.prepare(
            text,
            summaryType: summaryType
        )
        let spokenText = await NarrationScriptService.shared.spokenScript(
            for: itemId,
            guideContent: text,
            summaryType: summaryType,
            fallbackContent: fallbackText,
            progress: progress
        )
        guard !spokenText.isEmpty else { throw NarrationServiceError.emptyText }

        let routes = NarrationFallbackPolicy.orderedRoutes(
            kokoroConfigured: KokoroModelStore.isInstalled,
            liamConfigured: KokoroNarrationService.shared.isTokenConfigured
        )
        guard !routes.isEmpty else { throw NarrationServiceError.noConfiguredProvider }

        var lastFailure: Error?

        for route in routes {
            try Task.checkCancellation()

            switch route {
            case .system:
                let narrator = SystemNarrationRenderer.displayName
                progress(.generating(narrator: narrator))
                do {
                    let audio = try await SystemNarrationRenderer.shared.generateAudio(text: spokenText)
                    let asset = try await persist(audio: audio, itemId: itemId)
                    progress(.ready(narrator: narrator))
                    narrationLog.info("Narration via Apple system voice for \(itemId.uuidString)")
                    return asset
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    lastFailure = error
                    narrationLog.error(
                        "Apple system narration failed [\(error.localizedDescription, privacy: .public)] — moving to the next configured narration provider"
                    )
                }

            case .kokoro:
                let voice = Self.selectedKokoroVoice()
                let narrator = "Kokoro · \(voice.name)"
                progress(.generating(narrator: narrator))
                let heartbeat = ProgressHeartbeat()
                do {
                    let audio = try await withStallDetection(
                        stage: "generating audio on this device",
                        heartbeat: heartbeat
                    ) {
                        try await KokoroAudioService.shared.generateAudio(
                            text: spokenText,
                            voiceID: voice.voiceID,
                            onModelLoadStart: {
                                progress(.loadingModel(narrator: narrator))
                                Task { await heartbeat.beat() }
                            },
                            onProgress: { completed, total in
                                progress(.synthesizing(narrator: narrator, completed: completed, total: total))
                                Task { await heartbeat.beat() }
                            }
                        )
                    }
                    let asset = try await persist(audio: audio, itemId: itemId)
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
                    ?? "Using Liam because the on-device model is not installed."
                progress(.fallingBackToLiam(reason: reason))
                do {
                    let asset = try await KokoroNarrationService.shared.synthesizeAsset(
                        text: spokenText,
                        itemId: itemId
                    )
                    progress(.ready(narrator: "Liam"))
                    narrationLog.info("Narration via hosted Liam fallback for \(itemId.uuidString)")
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

    private func persist(audio: GeneratedAudio, itemId: UUID) async throws -> NarrationAsset {
        guard let documents = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first else {
            throw NarrationServiceError.documentsDirectoryUnavailable
        }

        // Reject HTML/error payloads and other unsupported bytes before they can
        // replace a previously playable narration.
        guard NarrationAudioValidation.hasSupportedContainer(audio.data) else {
            throw NarrationServiceError.invalidAudio
        }

        let ext = Self.fileExtension(for: audio.data)
        let relativeName = "audio_\(itemId.uuidString).\(ext)"
        let finalURL = documents.appendingPathComponent(relativeName)
        let fm = FileManager.default

        // Stage then promote atomically so prior audio survives until success.
        let staging = documents.appendingPathComponent(
            ".audio_\(itemId.uuidString).\(UUID().uuidString).partial.\(ext)"
        )
        try? fm.removeItem(at: staging)
        try audio.data.write(to: staging, options: .atomic)

        let validatedDuration: TimeInterval
        do {
            validatedDuration = try await NarrationAudioValidation.validatedDuration(
                at: staging,
                declaredDuration: audio.duration
            )
        } catch {
            try? fm.removeItem(at: staging)
            throw NarrationServiceError.invalidAudio
        }

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
            duration: validatedDuration
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
