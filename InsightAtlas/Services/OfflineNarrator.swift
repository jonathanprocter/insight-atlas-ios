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
