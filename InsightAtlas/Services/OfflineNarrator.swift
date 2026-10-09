//
//  OfflineNarrator.swift
//  InsightAtlas
//
//  SPIKE / PROTOTYPE — offline narration fallback.
//
//  This is the on-device audio path: `AVSpeechSynthesizer`. It is NOT Apple
//  Intelligence (Foundation Models has no TTS) — it's the classic on-device
//  speech engine. Quality is well below the Kokoro/Liam pipeline, so this is
//  strictly a *fallback* for when the Kokoro gateway is unreachable, clearly
//  labeled as such in the UI.
//

import Foundation
import AVFoundation

@MainActor
final class OfflineNarrator: NSObject, ObservableObject {

    @Published private(set) var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Speaks the given text using the best available on-device en-US voice.
    /// Prefers an enhanced/premium voice if the user has downloaded one.
    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = Self.preferredVoice()
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.prefersAssistiveTechnologySettings = false
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// Picks the highest-quality installed en-US voice: premium > enhanced > default.
    private static func preferredVoice() -> AVSpeechSynthesisVoice? {
        let enUS = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "en-US" }

        if let premium = enUS.first(where: { $0.quality == .premium }) {
            return premium
        }
        if let enhanced = enUS.first(where: { $0.quality == .enhanced }) {
            return enhanced
        }
        return AVSpeechSynthesisVoice(language: "en-US")
    }
}

extension OfflineNarrator: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = true }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
}

// MARK: - Apple Voice Catalog

/// The system speech voices installed on this device, surfaced as a narration
/// engine. Premium/enhanced voices are the ones the user downloads under
/// iOS Settings → Accessibility → Spoken Content → Voices; apps cannot trigger
/// that download, only use what is installed.
enum AppleVoiceCatalog {
    static let selectedVoiceStorageKey = "insight_atlas_apple_voice_id"

    /// Installed English voices, best quality first (premium > enhanced >
    /// default), then alphabetical. Novelty and personal voices are excluded.
    static func installedVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .filter {
                !$0.voiceTraits.contains(.isNoveltyVoice)
                    && !$0.voiceTraits.contains(.isPersonalVoice)
            }
            .sorted { a, b in
                if a.quality != b.quality { return a.quality.rawValue > b.quality.rawValue }
                return a.name < b.name
            }
    }

    /// Default for file rendering. Premium voices are ranked best for live
    /// speech, but `AVSpeechSynthesizer.write` is known to emit no PCM buffers
    /// for some premium voices — so the automatic default prefers enhanced,
    /// then standard, and reaches for premium only when nothing else exists.
    /// An explicit user selection still wins (the render watchdog covers it).
    static func defaultVoice() -> AVSpeechSynthesisVoice? {
        let voices = installedVoices()
        return voices.first(where: { $0.quality == .enhanced })
            ?? voices.first(where: { $0.quality == .default })
            ?? voices.first
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    static func voice(byID identifier: String) -> AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice(identifier: identifier)
    }

    /// The user's chosen voice, falling back to the best installed one.
    static func selectedVoice() -> AVSpeechSynthesisVoice? {
        if let id = UserDefaults.standard.string(forKey: selectedVoiceStorageKey),
           let voice = AVSpeechSynthesisVoice(identifier: id) {
            return voice
        }
        return defaultVoice()
    }

    static func qualityLabel(for voice: AVSpeechSynthesisVoice) -> String {
        switch voice.quality {
        case .premium: return "Premium"
        case .enhanced: return "Enhanced"
        default: return "Standard"
        }
    }
}

// MARK: - Apple Speech File Renderer

enum AppleSpeechAudioError: LocalizedError {
    case emptyText
    case noVoiceAvailable
    case noAudioProduced

    var errorDescription: String? {
        switch self {
        case .emptyText: return "There is no text to narrate."
        case .noVoiceAvailable: return "No system voice is available for narration."
        case .noAudioProduced: return "The system voice produced no audio."
        }
    }
}

/// Renders narration to a WAV file with `AVSpeechSynthesizer.write`, so Apple
/// voices plug into the same saved-asset pipeline as Kokoro (`GeneratedAudio`
/// → validation → Documents). Unlike `OfflineNarrator` above, nothing is
/// played live here.
final class AppleSpeechAudioService: NSObject, @unchecked Sendable {
    static let shared = AppleSpeechAudioService()

    /// Mutable synthesis state shared with the buffer callback; callbacks for
    /// one utterance arrive serially, and utterances run one at a time.
    private final class RenderState {
        var audioFile: AVAudioFile?
        var totalFrames: AVAudioFramePosition = 0
        var sampleRate: Double = 0
    }

    func generateAudio(
        text: String,
        voiceID: String,
        onProgress: @escaping @Sendable (Int, Int) -> Void = { _, _ in }
    ) async throws -> GeneratedAudio {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AppleSpeechAudioError.emptyText }
        guard let voice = AVSpeechSynthesisVoice(identifier: voiceID)
                ?? AppleVoiceCatalog.selectedVoice() else {
            throw AppleSpeechAudioError.noVoiceAvailable
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple_narration_\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let state = RenderState()
        let synthesizer = AVSpeechSynthesizer()
        let chunks = Self.chunk(trimmed)

        for (index, chunk) in chunks.enumerated() {
            try Task.checkCancellation()
            try await withTaskCancellationHandler {
                try await render(
                    chunk,
                    voice: voice,
                    synthesizer: synthesizer,
                    into: tempURL,
                    state: state
                )
            } onCancel: {
                synthesizer.stopSpeaking(at: .immediate)
            }
            onProgress(index + 1, chunks.count)
        }

        guard state.totalFrames > 0, state.sampleRate > 0 else {
            throw AppleSpeechAudioError.noAudioProduced
        }
        // Close the file before reading it back.
        state.audioFile = nil

        let data = try Data(contentsOf: tempURL)
        return GeneratedAudio(
            data: data,
            duration: Double(state.totalFrames) / state.sampleRate,
            characterCount: trimmed.count,
            voiceID: voice.identifier
        )
    }

    /// Longest a chunk may go without a single PCM buffer before the render
    /// is abandoned. Some voices (notably premium ones) silently emit nothing
    /// from `write`, and the end-of-utterance callback never arrives — without
    /// this watchdog that chunk would hang its continuation forever.
    static let bufferIdleTimeout: TimeInterval = 30

    private func render(
        _ text: String,
        voice: AVSpeechSynthesisVoice,
        synthesizer: AVSpeechSynthesizer,
        into fileURL: URL,
        state: RenderState
    ) async throws {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.prefersAssistiveTechnologySettings = false

        // Guards finish/activity state: buffer callbacks arrive serially, but
        // the watchdog fires from a detached task.
        let gate = RenderWatchdogGate()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let watchdog = Task.detached {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    if gate.isFinished() { return }
                    if gate.idleSeconds() > Self.bufferIdleTimeout {
                        if gate.tryFinish() {
                            synthesizer.stopSpeaking(at: .immediate)
                            continuation.resume(throwing: AppleSpeechAudioError.noAudioProduced)
                        }
                        return
                    }
                }
            }

            synthesizer.write(utterance) { buffer in
                gate.touch()
                guard !gate.isFinished() else { return }
                guard let pcm = buffer as? AVAudioPCMBuffer else { return }

                // A zero-length buffer marks the end of the utterance.
                guard pcm.frameLength > 0 else {
                    if gate.tryFinish() {
                        watchdog.cancel()
                        continuation.resume()
                    }
                    return
                }

                do {
                    if state.audioFile == nil {
                        state.sampleRate = pcm.format.sampleRate
                        state.audioFile = try AVAudioFile(
                            forWriting: fileURL,
                            settings: pcm.format.settings,
                            commonFormat: pcm.format.commonFormat,
                            interleaved: pcm.format.isInterleaved
                        )
                    }
                    try state.audioFile?.write(from: pcm)
                    state.totalFrames += AVAudioFramePosition(pcm.frameLength)
                } catch {
                    if gate.tryFinish() {
                        watchdog.cancel()
                        synthesizer.stopSpeaking(at: .immediate)
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    /// Lock-protected finish/activity state shared between the serial buffer
    /// callback and the detached watchdog task. Synchronous accessors keep the
    /// lock usage legal from async contexts.
    private final class RenderWatchdogGate: @unchecked Sendable {
        private let lock = NSLock()
        private var finished = false
        private var lastActivity = Date()

        func touch() {
            lock.lock()
            lastActivity = Date()
            lock.unlock()
        }

        func isFinished() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return finished
        }

        func idleSeconds() -> TimeInterval {
            lock.lock()
            defer { lock.unlock() }
            return Date().timeIntervalSince(lastActivity)
        }

        /// Marks finished; returns true only for the caller that won the race.
        func tryFinish() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            if finished { return false }
            finished = true
            return true
        }
    }

    /// Splits narration into utterance-sized pieces on paragraph boundaries
    /// (sentence boundaries inside oversized paragraphs) so progress can be
    /// reported and a stall never loses the whole render.
    static func chunk(_ text: String, limit: Int = 2_500) -> [String] {
        var chunks: [String] = []
        var current = ""

        func flush() {
            let t = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { chunks.append(t) }
            current = ""
        }

        for paragraph in text.components(separatedBy: "\n\n") {
            let para = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            if para.isEmpty { continue }

            if para.count > limit {
                flush()
                var sentence = ""
                for character in para {
                    sentence.append(character)
                    if ".!?".contains(character), sentence.count >= limit / 2 {
                        chunks.append(sentence.trimmingCharacters(in: .whitespaces))
                        sentence = ""
                    }
                }
                let tail = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                if !tail.isEmpty { chunks.append(tail) }
            } else if current.count + para.count + 2 > limit {
                flush()
                current = para
            } else {
                current += current.isEmpty ? para : "\n\n" + para
            }
        }
        flush()

        return chunks.isEmpty ? [text] : chunks
    }
}
