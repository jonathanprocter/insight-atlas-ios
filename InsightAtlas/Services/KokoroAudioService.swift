//
//  KokoroAudioService.swift
//  InsightAtlas
//
//  On-device text-to-speech (Kyutai Pocket TTS) powered by sherpa-onnx.
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
            return "Download the Pocket on-device voice model in Settings → Audio & Narration before generating audio."
        case .invalidVoiceID:
            return "The selected Pocket voice is not available."
        case .emptyText:
            return "There is no narration text to read."
        case .invalidModel:
            return "The installed Pocket model could not be loaded. Delete it in Settings and download it again."
        case .generationFailed:
            return "Pocket could not generate playable speech for this text."
        case .audioWritingFailed:
            return "Pocket generated speech, but Insight Atlas could not save the audio file."
        }
    }
}

protocol KokoroSynthesizing: Sendable {
    /// - Parameters:
    ///   - onModelLoadStart: Called before a cold model load, which is slow and
    ///     otherwise indistinguishable from a stalled first chunk.
    ///   - onProgress: `(completed, total)` chunks, called before the first
    ///     chunk and after each one completes.
    ///   - segmentDirectory / onSegment: optional streaming output — each chunk
    ///     is also written as its own playable file and reported immediately,
    ///     so playback can start before the whole narration is rendered.
    func generate(
        text: String,
        speakerID: Int,
        modelDirectory: URL,
        segmentDirectory: URL?,
        onModelLoadStart: (@Sendable () -> Void)?,
        onProgress: (@Sendable (Int, Int) -> Void)?,
        onSegment: (@Sendable (URL, Int, Int) -> Void)?
    ) async throws -> KokoroSynthesisResult

    func reset() async
}

extension KokoroSynthesizing {
    /// Non-streaming convenience used by tests and the background pipeline.
    func generate(
        text: String,
        speakerID: Int,
        modelDirectory: URL,
        onModelLoadStart: (@Sendable () -> Void)? = nil,
        onProgress: (@Sendable (Int, Int) -> Void)? = nil
    ) async throws -> KokoroSynthesisResult {
        try await generate(
            text: text,
            speakerID: speakerID,
            modelDirectory: modelDirectory,
            segmentDirectory: nil,
            onModelLoadStart: onModelLoadStart,
            onProgress: onProgress,
            onSegment: nil
        )
    }
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

    /// `AudioServiceProtocol` conformance. Prefer `generateAudio(text:voiceID:onProgress:)`
    /// when the caller can show synthesis progress.
    func generateAudio(
        text: String,
        voiceID: String
    ) async throws -> GeneratedAudio {
        try await generateAudio(text: text, voiceID: voiceID, onModelLoadStart: nil, onProgress: nil)
    }

    func generateAudio(
        text: String,
        voiceID: String,
        onModelLoadStart: (@Sendable () -> Void)?,
        onProgress: (@Sendable (Int, Int) -> Void)?
    ) async throws -> GeneratedAudio {
        try await generateAudio(
            text: text,
            voiceID: voiceID,
            segmentDirectory: nil,
            onModelLoadStart: onModelLoadStart,
            onProgress: onProgress,
            onSegment: nil
        )
    }

    func generateAudio(
        text: String,
        voiceID: String,
        segmentDirectory: URL?,
        onModelLoadStart: (@Sendable () -> Void)?,
        onProgress: (@Sendable (Int, Int) -> Void)?,
        onSegment: (@Sendable (URL, Int, Int) -> Void)?
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
            modelDirectory: modelDirectoryProvider(),
            segmentDirectory: segmentDirectory,
            onModelLoadStart: onModelLoadStart,
            onProgress: onProgress,
            onSegment: onSegment
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
    private var referenceAudio: [Int: (samples: [Float], sampleRate: Int)] = [:]
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
        referenceAudio.removeAll()
    }

    /// - Parameters:
    ///   - segmentDirectory: when supplied, each chunk is also written as its
    ///     own playable WAV here and reported through `onSegment` as soon as it
    ///     is on disk. That lets playback start on chunk 1 while the rest of a
    ///     long narration is still rendering. The combined file is still
    ///     produced exactly as before, so persistence and caching are unchanged.
    ///   - onSegment: `(url, index, total)` for each finished chunk.
    func generate(
        text: String,
        speakerID: Int,
        modelDirectory: URL,
        segmentDirectory: URL? = nil,
        onModelLoadStart: (@Sendable () -> Void)? = nil,
        onProgress: (@Sendable (Int, Int) -> Void)? = nil,
        onSegment: (@Sendable (URL, Int, Int) -> Void)? = nil
    ) async throws -> KokoroSynthesisResult {
        let chunks = chunker.chunks(for: text)
        guard !chunks.isEmpty else { throw KokoroAudioError.emptyText }

        let synthesisStart = Date()
        if tts == nil || loadedDirectory != modelDirectory.standardizedFileURL {
            onModelLoadStart?()
        }
        let loadStart = Date()
        let tts = try loadModelIfNeeded(from: modelDirectory)
        let reference = try referenceAudio(for: speakerID, in: modelDirectory)
        let loadElapsed = Date().timeIntervalSince(loadStart)
        if loadElapsed > 0.1 {
            print(String(format: "[Timing] Pocket model load: %.1fs", loadElapsed))
        }
        print("[Timing] Pocket synthesis starting: \(chunks.count) chunk(s), \(text.count) chars")
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("kokoro-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        var audioFile: AVAudioFile?
        var sampleRate: Int32 = 0
        var totalFrames: Int64 = 0

        for (chunkIndex, chunk) in chunks.enumerated() {
            try Task.checkCancellation()
            // Report before rendering so the UI shows "0 of N" immediately
            // rather than sitting blank until the first chunk lands.
            onProgress?(chunkIndex, chunks.count)
            let chunkStart = Date()
            // Fixed seed: Pocket samples its flow with noise, and a different
            // seed per chunk would make the narrator drift between chunks.
            let config = SherpaOnnxGenerationConfigSwift(
                silenceScale: 0.2,
                speed: 1.0,
                sid: 0,
                referenceAudio: reference.samples,
                referenceSampleRate: reference.sampleRate,
                extra: ["max_reference_audio_len": 10.0, "seed": 42]
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

            // Publish this chunk on its own so playback can begin before the
            // whole narration is rendered. Scoped so the AVAudioFile flushes
            // and closes before the player is handed the URL.
            if let segmentDirectory, let onSegment {
                let segmentURL = segmentDirectory.appendingPathComponent(
                    String(format: "seg_%04d.wav", chunkIndex)
                )
                do {
                    var segmentFile: AVAudioFile? = try makeAudioFile(
                        at: segmentURL,
                        sampleRate: Double(sampleRate)
                    )
                    if let segmentFile {
                        try append(
                            samples: samples,
                            sampleRate: Double(sampleRate),
                            to: segmentFile
                        )
                    }
                    segmentFile = nil
                    onSegment(segmentURL, chunkIndex, chunks.count)
                } catch {
                    // A segment failure must never abort the real render; the
                    // combined file is still authoritative.
                    print("[Narration] segment \(chunkIndex) unavailable: \(error.localizedDescription)")
                }
            }

            onProgress?(chunkIndex + 1, chunks.count)
            print(String(
                format: "[Timing] Pocket chunk %d/%d: %.1fs for %d chars",
                chunkIndex + 1, chunks.count,
                Date().timeIntervalSince(chunkStart), chunk.count
            ))
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
            format: "[Timing] Pocket synthesis: %.1fs wall for %.1fs audio across %d chunk(s) — RTF %.2f (threads: %d)",
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

        func path(_ name: String) -> String {
            standardizedDirectory.appendingPathComponent(name).path
        }
        let pocket = sherpaOnnxOfflineTtsPocketModelConfig(
            lmFlow: path("lm_flow.int8.onnx"),
            lmMain: path("lm_main.int8.onnx"),
            encoder: path("encoder.onnx"),
            decoder: path("decoder.int8.onnx"),
            textConditioner: path("text_conditioner.onnx"),
            vocabJson: path("vocab.json"),
            tokenScoresJson: path("token_scores.json"),
            voiceEmbeddingCacheCapacity: KokoroVoiceRegistry.allVoices.count
        )
        let modelConfig = sherpaOnnxOfflineTtsModelConfig(
            numThreads: Int(Self.synthesisThreadCount),
            debug: 0,
            provider: "cpu",
            pocket: pocket
        )
        var config = sherpaOnnxOfflineTtsConfig(model: modelConfig)
        let wrapper = KokoroNativeTTS(config: &config)
        guard wrapper.tts != nil else {
            throw KokoroAudioError.invalidModel
        }

        tts = wrapper
        loadedDirectory = standardizedDirectory
        referenceAudio.removeAll()
        return wrapper
    }

    /// Pocket derives its speaker from a reference clip rather than an id. The
    /// decoded clip is kept per voice so every chunk reuses the same samples
    /// (and the engine's embedding cache keeps hitting).
    private func referenceAudio(
        for speakerID: Int,
        in directory: URL
    ) throws -> (samples: [Float], sampleRate: Int) {
        if let cached = referenceAudio[speakerID] { return cached }
        guard let voice = KokoroVoiceRegistry.voice(speakerID: speakerID) else {
            throw KokoroAudioError.invalidVoiceID
        }
        let clipURL = directory.standardizedFileURL
            .appendingPathComponent(voice.referenceAudioRelativePath)
        let wave = SherpaOnnxWaveWrapper.readWave(filename: clipURL.path)
        guard wave.wave != nil, wave.sampleRate > 0 else {
            throw KokoroAudioError.invalidModel
        }
        let samples = wave.samples
        guard !samples.isEmpty else { throw KokoroAudioError.invalidModel }
        let decoded = (samples: samples, sampleRate: Int(wave.sampleRate))
        referenceAudio[speakerID] = decoded
        return decoded
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
