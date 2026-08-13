// ElevenLabs removed

import Foundation
import AVFoundation
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "InsightAtlas", category: "AudioPlayback")

struct GeneratedAudio {
    let data: Data
    let duration: TimeInterval
    let characterCount: Int
    let voiceID: String
}

@available(*, unavailable, message: "ElevenLabs integration removed")
enum ElevenLabsAudioError: LocalizedError {
    case removed

    var errorDescription: String? {
        "ElevenLabs integration removed"
    }
}

@available(*, unavailable, message: "ElevenLabs integration removed")
struct AudioGenerationRequest {
    @available(*, unavailable, message: "ElevenLabs integration removed")
    struct VoiceSettings: Codable {
        let stability: Double
        let similarityBoost: Double
        let style: Double
        let useSpeakerBoost: Bool
    }

    static let defaultModel = "removed"
}

@available(*, unavailable, message: "ElevenLabs integration removed")
final class ElevenLabsAudioService: AudioServiceProtocol {
    var isConfigured: Bool { false }

    func generateAudio(text: String, voiceID: String) async throws -> GeneratedAudio {
        _ = text
        _ = voiceID
        throw VoiceRoutingError.allProvidersFailed("ElevenLabs integration removed")
    }

    func validateApiKey() async throws -> Bool {
        throw VoiceRoutingError.allProvidersFailed("ElevenLabs integration removed")
    }

    func generateAudio(
        for blockPlan: AudioBlockPlan,
        using voiceConfig: VoiceSelectionConfig
    ) async throws -> GeneratedAudio {
        _ = blockPlan
        _ = voiceConfig
        throw VoiceRoutingError.allProvidersFailed("ElevenLabs integration removed")
    }
}

final class AudioPlaybackManager: NSObject, AVAudioPlayerDelegate {
    static let shared = AudioPlaybackManager()

    private var audioPlayer: AVAudioPlayer?
    private var completionHandler: (() -> Void)?
    private var currentRate: Float = 1.0

    private override init() {
        super.init()
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers, .allowBluetoothA2DP]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            logger.error("AudioPlaybackManager: Failed to configure audio session: \(error.localizedDescription)")
        }
    }

    func ensureAudioSessionActive() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers, .allowBluetoothA2DP]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            logger.error("AudioPlaybackManager: Failed to activate audio session: \(error.localizedDescription)")
        }
    }

    func play(_ audio: GeneratedAudio, rate: Float = 1.0, completion: (() -> Void)? = nil) throws {
        guard !audio.data.isEmpty else {
            completion?()
            return
        }

        stop()
        ensureAudioSessionActive()

        audioPlayer = try AVAudioPlayer(data: audio.data)
        audioPlayer?.delegate = self
        audioPlayer?.enableRate = true
        audioPlayer?.rate = max(0.5, min(2.0, rate))
        currentRate = audioPlayer?.rate ?? 1.0
        completionHandler = completion
        audioPlayer?.play()
    }

    func setPlaybackRate(_ rate: Float) {
        let clampedRate = max(0.5, min(2.0, rate))
        currentRate = clampedRate
        audioPlayer?.rate = clampedRate
    }

    var playbackRate: Float { currentRate }

    func playFile(at url: URL, rate: Float = 1.0, completion: (() -> Void)? = nil) throws {
        stop()
        ensureAudioSessionActive()

        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.delegate = self
        audioPlayer?.enableRate = true
        audioPlayer?.rate = max(0.5, min(2.0, rate))
        currentRate = audioPlayer?.rate ?? 1.0
        completionHandler = completion
        audioPlayer?.play()
    }

    func exportAudio(_ audio: GeneratedAudio, filename: String) throws -> URL {
        guard !audio.data.isEmpty else {
            throw CocoaError(.coderInvalidValue)
        }
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }

        let exportsDir = documentsDir.appendingPathComponent("AudioExports", isDirectory: true)
        if !FileManager.default.fileExists(atPath: exportsDir.path) {
            try FileManager.default.createDirectory(at: exportsDir, withIntermediateDirectories: true)
        }

        let sanitizedFilename = filename
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let fileURL = exportsDir.appendingPathComponent("\(sanitizedFilename).mp3")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        try audio.data.write(to: fileURL)
        return fileURL
    }

    func getShareableURL(for audio: GeneratedAudio, title: String) throws -> URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let shareDir = documentsDir.appendingPathComponent("SharedAudio", isDirectory: true)
        if !FileManager.default.fileExists(atPath: shareDir.path) {
            try FileManager.default.createDirectory(at: shareDir, withIntermediateDirectories: true)
        }

        let existingFiles = try FileManager.default.contentsOfDirectory(
            at: shareDir,
            includingPropertiesForKeys: nil
        )
        for fileURL in existingFiles {
            try? FileManager.default.removeItem(at: fileURL)
        }

        let sanitizedTitle = title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fileURL = shareDir.appendingPathComponent("\(sanitizedTitle).mp3")

        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }

        try audio.data.write(to: fileURL)
        return fileURL
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        completionHandler = nil

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            logger.debug("Failed to deactivate audio session after stop: \(error.localizedDescription)")
        }
    }

    func pause() {
        audioPlayer?.pause()
    }

    func resume() {
        audioPlayer?.play()
    }

    var isPlaying: Bool {
        audioPlayer?.isPlaying ?? false
    }

    var progress: Double {
        guard let player = audioPlayer, player.duration > 0 else { return 0 }
        return player.currentTime / player.duration
    }

    var duration: TimeInterval {
        audioPlayer?.duration ?? 0
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        completionHandler?()
        completionHandler = nil

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            logger.debug("Failed to deactivate audio session after playback: \(error.localizedDescription)")
        }
    }
}
