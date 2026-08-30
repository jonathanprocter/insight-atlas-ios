//
//  KokoroAudioService.swift
//  InsightAtlas
//
//  On-device Kokoro text-to-speech powered by sherpa-onnx.
//

import AVFoundation
import FluidAudio
import Foundation

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
        voiceID: String,
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
            voiceID: voice.voiceID,
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
    private var tts: KokoroAneManager?
    private var loadedDirectory: URL?
    private let chunker: KokoroTextChunker

    init(chunker: KokoroTextChunker = KokoroTextChunker()) {
        self.chunker = chunker
    }

    func reset() async {
        await tts?.cleanup()
        tts = nil
        loadedDirectory = nil
    }

    func generate(
        text: String,
        voiceID: String,
        modelDirectory: URL
    ) async throws -> KokoroSynthesisResult {
        let chunks = chunker.chunks(for: text)
        guard !chunks.isEmpty else { throw KokoroAudioError.emptyText }

        let tts = try await loadModelIfNeeded(from: modelDirectory)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("kokoro-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        var audioFile: AVAudioFile?
        var sampleRate: Int32 = 0
        var totalFrames: Int64 = 0

        for chunk in chunks {
            try Task.checkCancellation()
            let generated = try await tts.synthesizeDetailed(
                text: chunk,
                voice: voiceID,
                speed: 0.96
            )
            let samples = generated.samples
            guard generated.sampleRate > 0, !samples.isEmpty else {
                throw KokoroAudioError.generationFailed
            }

            if audioFile == nil {
                sampleRate = Int32(generated.sampleRate)
                audioFile = try makeAudioFile(
                    at: outputURL,
                    sampleRate: Double(sampleRate)
                )
            }
            guard generated.sampleRate == Int(sampleRate),
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

        return KokoroSynthesisResult(
            data: data,
            duration: Double(totalFrames) / Double(sampleRate)
        )
    }

    private func loadModelIfNeeded(from directory: URL) async throws -> KokoroAneManager {
        let standardizedDirectory = directory.standardizedFileURL
        if let tts, loadedDirectory == standardizedDirectory {
            return tts
        }

        let manager = KokoroAneManager(directory: standardizedDirectory)
        do {
            try await manager.initialize(
                preloadVoices: Set(KokoroVoiceRegistry.allVoices.map(\.voiceID))
            )
        } catch {
            throw KokoroAudioError.invalidModel
        }

        tts = manager
        loadedDirectory = standardizedDirectory
        return manager
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
