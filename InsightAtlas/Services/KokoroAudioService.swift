//
//  KokoroAudioService.swift
//  InsightAtlas
//
//  On-device Kokoro text-to-speech powered by sherpa-onnx.
//

import AVFoundation
import Foundation
import SherpaOnnx

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

final class KokoroAudioService: AudioServiceProtocol, @unchecked Sendable {
    static let shared = KokoroAudioService()

    let provider: VoiceProvider = .kokoro

    var isConfigured: Bool {
        KokoroModelStore.isInstalled
    }

    private let engine: KokoroSynthesisEngine

    init(engine: KokoroSynthesisEngine = KokoroSynthesisEngine()) {
        self.engine = engine
    }

    func generateAudio(
        text: String,
        voiceID: String
    ) async throws -> GeneratedAudio {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw KokoroAudioError.emptyText }
        guard KokoroModelStore.isInstalled else {
            throw KokoroAudioError.modelNotInstalled
        }
        guard let voice = KokoroVoiceRegistry.voice(byVoiceID: voiceID) else {
            throw KokoroAudioError.invalidVoiceID
        }

        let result = try await engine.generate(
            text: trimmed,
            speakerID: voice.speakerID,
            modelDirectory: KokoroModelStore.modelDirectory()
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

actor KokoroSynthesisEngine {
    private var tts: KokoroNativeTTS?
    private var loadedDirectory: URL?
    private let chunker: KokoroTextChunker

    init(chunker: KokoroTextChunker = KokoroTextChunker()) {
        self.chunker = chunker
    }

    func reset() {
        tts = nil
        loadedDirectory = nil
    }

    func generate(
        text: String,
        speakerID: Int,
        modelDirectory: URL
    ) throws -> KokoroSynthesisResult {
        let chunks = chunker.chunks(for: text)
        guard !chunks.isEmpty else { throw KokoroAudioError.emptyText }

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

        return KokoroSynthesisResult(
            data: data,
            duration: Double(totalFrames) / Double(sampleRate)
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
            numThreads: 2,
            debug: 0,
            provider: "cpu",
            kokoro: kokoro
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
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw KokoroAudioError.audioWritingFailed
        }

        return try AVAudioFile(
            forWriting: url,
            settings: format.settings,
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
