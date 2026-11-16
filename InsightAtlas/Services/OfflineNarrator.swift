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
        onProgress: @escaping @Sendable (Int, Int) -> Void = { _, _ in },
        onActivity: @escaping @Sendable () -> Void = {}
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
                    state: state,
                    onActivity: onActivity
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

    /// Longest a chunk may go without any synthesizer activity before the
    /// render is abandoned. Some voices (notably premium ones) silently emit
    /// nothing from `write`, and the end-of-utterance callback never arrives -
    /// without this watchdog that chunk would hang its continuation forever.
    /// This is an idle limit, not a total one: a 2,500-character chunk takes
    /// well over 30 s to render on a phone.
    static let bufferIdleTimeout: TimeInterval = 30

    private func render(
        _ text: String,
        voice: AVSpeechSynthesisVoice,
        synthesizer: AVSpeechSynthesizer,
        into fileURL: URL,
        state: RenderState,
        onActivity: @escaping @Sendable () -> Void
    ) async throws {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.prefersAssistiveTechnologySettings = false

        let session = UtteranceRenderSession(
            synthesizer: synthesizer,
            fileURL: fileURL,
            state: state,
            idleTimeout: Self.bufferIdleTimeout,
            onActivity: onActivity
        )
        try await session.run(utterance)
    }

    /// One `AVSpeechSynthesizer.write` pass for a single chunk.
    ///
    /// `write` delivers a zero-length buffer at the end of EVERY sentence, not
    /// once at the end of the utterance (measured on macOS: a 40-sentence
    /// utterance produced 20 empty buffers at roughly 12 s audio intervals).
    /// Treating the first empty buffer as "finished" - which this service used
    /// to do - resolved the chunk after its opening sentence and discarded the
    /// rest, so every system-voice narration was cut short. Completion is now
    /// taken from the delegate's `didFinish`, empty buffers are treated as the
    /// sentence markers they are, and an idle watchdog still catches voices
    /// that never deliver anything.
    private final class UtteranceRenderSession: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
        private let synthesizer: AVSpeechSynthesizer
        private let fileURL: URL
        private let state: RenderState
        private let idleTimeout: TimeInterval
        private let onActivity: @Sendable () -> Void

        private let lock = NSLock()
        private var continuation: CheckedContinuation<Void, Error>?
        private var completedSuccessfully = false
        private var lastActivity = Date()
        private var sawSentenceBoundary = false
        private var wroteAudio = false
        private var watchdog: Task<Void, Never>?

        init(
            synthesizer: AVSpeechSynthesizer,
            fileURL: URL,
            state: RenderState,
            idleTimeout: TimeInterval,
            onActivity: @escaping @Sendable () -> Void
        ) {
            self.synthesizer = synthesizer
            self.fileURL = fileURL
            self.state = state
            self.idleTimeout = idleTimeout
            self.onActivity = onActivity
            super.init()
        }

        func run(_ utterance: AVSpeechUtterance) async throws {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                lock.withLock {
                    self.continuation = continuation
                    self.lastActivity = Date()
                }
                synthesizer.delegate = self
                watchdog = Task.detached { [weak self] in
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        guard let self, !Task.isCancelled else { return }
                        if self.idleSeconds() > self.idleTimeout {
                            self.handleIdleTimeout()
                            return
                        }
                    }
                }
                synthesizer.write(utterance) { [self] buffer in
                    self.handle(buffer)
                }
            }
        }

        // MARK: Buffer handling

        private func handle(_ buffer: AVAudioBuffer) {
            var failure: Error?
            var boundary = false
            lock.withLock {
                // Buffers that trail a resolved session may only be appended
                // if the session completed normally; after a failure or a
                // watchdog abort nothing more goes into the file.
                let live = continuation != nil
                guard live || completedSuccessfully else { return }
                lastActivity = Date()
                guard let pcm = buffer as? AVAudioPCMBuffer else { return }
                guard pcm.frameLength > 0 else {
                    // End of a sentence, not of the utterance. Keep going.
                    sawSentenceBoundary = true
                    boundary = true
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
                    wroteAudio = true
                } catch {
                    failure = error
                }
            }
            if boundary { onActivity() }
            if let failure {
                finish(.failure(failure))
                synthesizer.stopSpeaking(at: .immediate)
            }
        }

        private func idleSeconds() -> TimeInterval {
            lock.withLock { Date().timeIntervalSince(lastActivity) }
        }

        private func handleIdleTimeout() {
            // Going quiet right after a sentence boundary with audio already
            // on disk means the terminal delegate callback was dropped; the
            // chunk is complete. Anything else is a genuine stall. Resolve
            // first: stopping the synthesizer fires `didCancel`, which must
            // find nothing left to fail.
            let complete = lock.withLock { wroteAudio && sawSentenceBoundary }
            finish(complete ? .success(()) : .failure(AppleSpeechAudioError.noAudioProduced))
            synthesizer.stopSpeaking(at: .immediate)
        }

        private func finish(_ result: Result<Void, Error>) {
            let pending: CheckedContinuation<Void, Error>? = lock.withLock {
                defer { continuation = nil }
                if case .success = result, continuation != nil { completedSuccessfully = true }
                return continuation
            }
            guard let pending else { return }
            watchdog?.cancel()
            watchdog = nil
            synthesizer.delegate = nil
            pending.resume(with: result)
        }

        // MARK: AVSpeechSynthesizerDelegate

        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
            finish(.success(()))
        }

        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
            // Reached only when something other than this session stopped the
            // synthesizer (task cancellation in `generateAudio`); our own stops
            // have already resolved the continuation.
            finish(.failure(CancellationError()))
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
