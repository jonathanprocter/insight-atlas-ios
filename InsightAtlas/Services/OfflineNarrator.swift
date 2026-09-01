//
//  OfflineNarrator.swift
//  InsightAtlas
//
//  Guaranteed on-device narration using Apple's built-in speech engine.
//

import Foundation
import AVFoundation

enum SystemNarrationError: LocalizedError {
    case emptyText
    case unavailableVoice
    case renderingFailed

    var errorDescription: String? {
        switch self {
        case .emptyText: return "There is no narration text to read."
        case .unavailableVoice: return "No English system voice is available on this device."
        case .renderingFailed: return "The system voice could not create a playable narration file."
        }
    }
}

/// Renders Apple's built-in voice to a WAV file so it works with the same
/// playback, persistence, and export paths as Kokoro and hosted Liam.
@MainActor
final class SystemNarrationRenderer {
    static let shared = SystemNarrationRenderer()
    nonisolated static let voiceID = "apple-system-en-US"
    nonisolated static let displayName = "Apple On-Device Voice"

    func generateAudio(text: String) async throws -> GeneratedAudio {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SystemNarrationError.emptyText }
        guard let voice = OfflineNarrator.preferredVoice() else {
            throw SystemNarrationError.unavailableVoice
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("system-narration-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.prefersAssistiveTechnologySettings = false

        let rendered = try await render(utterance, to: outputURL)
        return GeneratedAudio(
            data: rendered.data,
            duration: rendered.duration,
            characterCount: trimmed.count,
            voiceID: Self.voiceID
        )
    }

    private func render(
        _ utterance: AVSpeechUtterance,
        to outputURL: URL
    ) async throws -> (data: Data, duration: TimeInterval) {
        try await withCheckedThrowingContinuation { continuation in
            let synthesizer = AVSpeechSynthesizer()
            var audioFile: AVAudioFile?
            var totalFrames: AVAudioFramePosition = 0
            var sampleRate: Double = 0
            var completed = false

            func finish(
                _ result: Result<(data: Data, duration: TimeInterval), Error>
            ) {
                guard !completed else { return }
                completed = true
                audioFile = nil
                continuation.resume(with: result)
            }

            // AVSpeechSynthesizer has no native async timeout and can fail to
            // deliver its terminal buffer. Never leave guide generation stuck.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(30))
                guard !completed else { return }
                synthesizer.stopSpeaking(at: .immediate)
                finish(.failure(SystemNarrationError.renderingFailed))
            }

            synthesizer.write(utterance) { buffer in
                guard let pcm = buffer as? AVAudioPCMBuffer else {
                    finish(.failure(SystemNarrationError.renderingFailed))
                    return
                }

                if pcm.frameLength == 0 {
                    do {
                        guard totalFrames > 0, sampleRate > 0 else {
                            throw SystemNarrationError.renderingFailed
                        }
                        audioFile = nil
                        let data = try Data(contentsOf: outputURL)
                        guard !data.isEmpty else { throw SystemNarrationError.renderingFailed }
                        finish(.success((
                            data: data,
                            duration: Double(totalFrames) / sampleRate
                        )))
                    } catch {
                        finish(.failure(error))
                    }
                    return
                }

                do {
                    if audioFile == nil {
                        sampleRate = pcm.format.sampleRate
                        audioFile = try AVAudioFile(
                            forWriting: outputURL,
                            settings: pcm.format.settings
                        )
                    }
                    try audioFile?.write(from: pcm)
                    totalFrames += AVAudioFramePosition(pcm.frameLength)
                } catch {
                    synthesizer.stopSpeaking(at: .immediate)
                    finish(.failure(error))
                }
            }
        }
    }
}

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
    static func preferredVoice() -> AVSpeechSynthesisVoice? {
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
