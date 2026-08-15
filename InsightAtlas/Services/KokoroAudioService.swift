//
//  KokoroAudioService.swift
//  InsightAtlas
//
//  On-device Kokoro text-to-speech powered by sherpa-onnx.
//

import AVFoundation
import Foundation
import SherpaOnnx

/// Generated narration bytes plus the metadata needed by persistence and playback.
struct GeneratedAudio: Sendable {
    let data: Data
    let duration: TimeInterval
    let characterCount: Int
    let voiceID: String
}

private typealias KokoroNativeTTS = SherpaOnnxOfflineTtsWrapper

enum KokoroAudioError: LocalizedError {
    case modelNotInstalled
    case invalidVoiceID
    case emptyText
    case invalidModel
    case generationFailed
    case audioWritingFailed

    var errorDescription: String? {
        switch self {
        case .modelNotInstalled:
            return "Download the Kokoro on-device voice model in Settings → Audio & Narration before generating audio."
        case .invalidVoiceID:
            return "The selected Kokoro voice is not available."
        case .emptyText:
            return "There is no narration text to read."
        case .invalidModel:
            return "The installed Kokoro model could not be loaded. Delete it in Settings and download it again."
        case .generationFailed:
            return "Kokoro could not generate playable speech for this text."
        case .audioWritingFailed:
            return "Kokoro generated speech, but Insight Atlas could not save the audio file."
        }
    }
}

protocol KokoroSynthesizing: Sendable {
    func generate(
        text: String,
        speakerID: Int,
        modelDirectory: URL
    ) async throws -> KokoroSynthesisResult

    func reset() async
}

final class KokoroAudioService: AudioServiceProtocol, @unchecked Sendable {
    static let shared = KokoroAudioService()

    let provider: VoiceProvider = .kokoro

    var isConfigured: Bool {
        isModelInstalled()
    }

    private let engine: any KokoroSynthesizing
    private let isModelInstalled: @Sendable () -> Bool
    private let modelDirectoryProvider: @Sendable () -> URL

    init(
        engine: any KokoroSynthesizing = KokoroSynthesisEngine(),
        isModelInstalled: @escaping @Sendable () -> Bool = { KokoroModelStore.isInstalled },
        modelDirectoryProvider: @escaping @Sendable () -> URL = { KokoroModelStore.modelDirectory() }
    ) {
        self.engine = engine
        self.isModelInstalled = isModelInstalled
        self.modelDirectoryProvider = modelDirectoryProvider
    }

    func generateAudio(
        text: String,
        voiceID: String
    ) async throws -> GeneratedAudio {
        try Task.checkCancellation()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw KokoroAudioError.emptyText }
        guard isModelInstalled() else {
            throw KokoroAudioError.modelNotInstalled
        }
        guard let voice = KokoroVoiceRegistry.voice(byVoiceID: voiceID) else {
            throw KokoroAudioError.invalidVoiceID
        }

        try Task.checkCancellation()
        let result = try await engine.generate(
            text: trimmed,
            speakerID: voice.speakerID,
            modelDirectory: modelDirectoryProvider()
        )
        return GeneratedAudio(
            data: result.data,
            duration: result.duration,
            characterCount: trimmed.count,
            voiceID: voice.voiceID
        )
    }

    func validateApiKey() async throws -> Bool {
        isConfigured
    }

    func reset() async {
        await engine.reset()
    }
}

struct KokoroSynthesisResult: Sendable {
    let data: Data
    let duration: TimeInterval
}

actor KokoroSynthesisEngine: KokoroSynthesizing {
    private var tts: KokoroNativeTTS?
    private var loadedDirectory: URL?
    private let chunker: KokoroTextChunker

    /// ONNX inference threads for synthesis. Scales with the device but leaves a
    /// core for the main/audio threads, so faster hardware finishes sooner while
    /// smaller devices are not oversubscribed. Previously hardcoded to 2.
    static let synthesisThreadCount: Int32 = {
        let cores = ProcessInfo.processInfo.activeProcessorCount
        return Int32(min(6, max(2, cores - 1)))
    }()

    init(chunker: KokoroTextChunker = KokoroTextChunker()) {
        self.chunker = chunker
    }

    func reset() async {
        tts = nil
        loadedDirectory = nil
    }

    func generate(
        text: String,
        speakerID: Int,
        modelDirectory: URL
    ) async throws -> KokoroSynthesisResult {
        let chunks = chunker.chunks(for: text)
        guard !chunks.isEmpty else { throw KokoroAudioError.emptyText }

        let synthesisStart = Date()
        let tts = try loadModelIfNeeded(from: modelDirectory)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("kokoro-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        var audioFile: AVAudioFile?
        var sampleRate: Int32 = 0
        var totalFrames: Int64 = 0

        for chunk in chunks {
            try Task.checkCancellation()
            let config = SherpaOnnxGenerationConfigSwift(
                silenceScale: 0.2,
                speed: 0.96,
                sid: speakerID
            )
            let generated = tts.generateWithConfig(
                text: chunk,
                config: config,
                callback: nil,
                arg: nil
            )
            let samples = generated.samples
            guard generated.sampleRate > 0, !samples.isEmpty else {
                throw KokoroAudioError.generationFailed
            }

            if audioFile == nil {
                sampleRate = generated.sampleRate
                audioFile = try makeAudioFile(
                    at: outputURL,
                    sampleRate: Double(sampleRate)
                )
            }
            guard generated.sampleRate == sampleRate,
                  let audioFile else {
                throw KokoroAudioError.audioWritingFailed
            }

            try append(
                samples: samples,
                sampleRate: Double(sampleRate),
                to: audioFile
            )
            totalFrames += Int64(samples.count)
        }

        guard sampleRate > 0, totalFrames > 0 else {
            throw KokoroAudioError.generationFailed
        }

        audioFile = nil
        let data = try Data(contentsOf: outputURL)
        guard !data.isEmpty else { throw KokoroAudioError.audioWritingFailed }

        let audioDuration = Double(totalFrames) / Double(sampleRate)
        let elapsed = Date().timeIntervalSince(synthesisStart)
        let rtf = audioDuration > 0 ? elapsed / audioDuration : 0
        print(String(
            format: "[Timing] Kokoro synthesis: %.1fs wall for %.1fs audio across %d chunk(s) — RTF %.2f (threads: %d)",
            elapsed, audioDuration, chunks.count, rtf, Self.synthesisThreadCount
        ))

        return KokoroSynthesisResult(
            data: data,
            duration: audioDuration
        )
    }

    private func loadModelIfNeeded(from directory: URL) throws -> KokoroNativeTTS {
        let standardizedDirectory = directory.standardizedFileURL
        if let tts, loadedDirectory == standardizedDirectory {
            return tts
        }

        guard KokoroModelInstallationValidator.isInstalled(at: standardizedDirectory) else {
            throw KokoroAudioError.modelNotInstalled
        }

        let kokoro = sherpaOnnxOfflineTtsKokoroModelConfig(
            model: standardizedDirectory
                .appendingPathComponent("model.int8.onnx").path,
            voices: standardizedDirectory
                .appendingPathComponent("voices.bin").path,
            tokens: standardizedDirectory
                .appendingPathComponent("tokens.txt").path,
            dataDir: standardizedDirectory
                .appendingPathComponent("espeak-ng-data", isDirectory: true).path,
            lexicon: standardizedDirectory
                .appendingPathComponent("lexicon-us-en.txt").path
        )
        let modelConfig = sherpaOnnxOfflineTtsModelConfig(
            kokoro: kokoro,
            numThreads: Int(Self.synthesisThreadCount),
            debug: 0,
            provider: "cpu"
        )
        var config = sherpaOnnxOfflineTtsConfig(model: modelConfig)
        let wrapper = KokoroNativeTTS(config: &config)
        guard wrapper.tts != nil,
              wrapper.numSpeakers >= Int32(KokoroVoiceRegistry.allVoices.count) else {
            throw KokoroAudioError.invalidModel
        }

        tts = wrapper
        loadedDirectory = standardizedDirectory
        return wrapper
    }

    private func makeAudioFile(
        at url: URL,
        sampleRate: Double
    ) throws -> AVAudioFile {
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        return try AVAudioFile(
            forWriting: url,
            settings: outputSettings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
    }

    private func append(
        samples: [Float],
        sampleRate: Double,
        to file: AVAudioFile
    ) throws {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ),
        let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(samples.count)
        ),
        let channel = buffer.floatChannelData?[0] else {
            throw KokoroAudioError.audioWritingFailed
        }

        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            guard let baseAddress = source.baseAddress else { return }
            channel.update(from: baseAddress, count: samples.count)
        }
        try file.write(from: buffer)
    }
}

// MARK: - Audio Playback Manager

/// Manages playback of generated narration and persisted audio files.
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
            print("[AudioPlaybackManager] Failed to configure audio session: \(error)")
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
            print("[AudioPlaybackManager] Failed to activate audio session: \(error)")
        }
    }

    func play(
        _ audio: GeneratedAudio,
        rate: Float = 1.0,
        completion: (() -> Void)? = nil
    ) throws {
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

    var playbackRate: Float {
        currentRate
    }

    func playFile(
        at url: URL,
        rate: Float = 1.0,
        completion: (() -> Void)? = nil
    ) throws {
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

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        completionHandler = nil
        deactivateAudioSession()
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

    var currentTime: TimeInterval {
        audioPlayer?.currentTime ?? 0
    }

    func seek(to time: TimeInterval) {
        guard let player = audioPlayer else { return }
        player.currentTime = max(0, min(time, player.duration))
    }

    func seek(toProgress fraction: Double) {
        guard let player = audioPlayer else { return }
        let clamped = max(0, min(fraction, 1))
        player.currentTime = player.duration * clamped
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        completionHandler?()
        completionHandler = nil
        audioPlayer = nil
        deactivateAudioSession()
    }

    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        } catch {
            print("[AudioPlaybackManager] Failed to deactivate audio session: \(error)")
        }
    }
}
