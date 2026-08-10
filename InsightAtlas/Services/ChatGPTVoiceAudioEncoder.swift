import Foundation
import AVFoundation

struct ChatGPTEncodedAudio: Equatable, Sendable {
    let data: Data
    let duration: TimeInterval
}

protocol ChatGPTVoiceAudioEncoding: Sendable {
    func appendPCM(_ data: Data) async throws
    func finish() async throws -> ChatGPTEncodedAudio
    func cancel() async
}

enum ChatGPTVoiceEncodingError: LocalizedError {
    case invalidAudioFormat
    case unableToCreateBuffer
    case unableToCreateExporter
    case exportFailed(String)
    case emptyAudio

    var errorDescription: String? {
        switch self {
        case .invalidAudioFormat:
            return "Unable to create the ChatGPT Voice PCM format."
        case .unableToCreateBuffer:
            return "Unable to create a ChatGPT Voice PCM buffer."
        case .unableToCreateExporter:
            return "Unable to create the ChatGPT Voice M4A exporter."
        case .exportFailed(let message):
            return "ChatGPT Voice audio export failed: \(message)"
        case .emptyAudio:
            return "ChatGPT Voice produced no audio."
        }
    }
}

actor ChatGPTVoiceM4AEncoder: ChatGPTVoiceAudioEncoding {
    static let sampleRate: Double = 24_000
    static let channelCount: AVAudioChannelCount = 1

    private let temporaryDirectory: URL
    private let pcmURL: URL
    private let outputURL: URL
    private let format: AVAudioFormat
    private var audioFile: AVAudioFile?
    private var totalFrameCount: AVAudioFramePosition = 0
    private var isFinished = false

    init(fileManager: FileManager = .default) throws {
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("insightatlas-chatgpt-voice-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Self.sampleRate,
            channels: Self.channelCount,
            interleaved: true
        ) else {
            try? fileManager.removeItem(at: directory)
            throw ChatGPTVoiceEncodingError.invalidAudioFormat
        }

        self.temporaryDirectory = directory
        self.pcmURL = directory.appendingPathComponent("narration.caf")
        self.outputURL = directory.appendingPathComponent("narration.m4a")
        self.format = format
        self.audioFile = try AVAudioFile(
            forWriting: pcmURL,
            settings: format.settings,
            commonFormat: .pcmFormatInt16,
            interleaved: true
        )
    }

    func appendPCM(_ data: Data) async throws {
        guard !isFinished else {
            throw ChatGPTVoiceEncodingError.exportFailed("The encoder is already closed.")
        }
        try ChatGPTPCMValidator.validate(data)

        let frameCount = AVAudioFrameCount(data.count / MemoryLayout<Int16>.size)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw ChatGPTVoiceEncodingError.unableToCreateBuffer
        }
        buffer.frameLength = frameCount

        let buffers = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
        guard !buffers.isEmpty,
              let destination = buffers[0].mData,
              Int(buffers[0].mDataByteSize) >= data.count else {
            throw ChatGPTVoiceEncodingError.unableToCreateBuffer
        }

        data.copyBytes(to: destination.assumingMemoryBound(to: UInt8.self), count: data.count)
        buffers[0].mDataByteSize = UInt32(data.count)

        guard let audioFile else {
            throw ChatGPTVoiceEncodingError.exportFailed("The PCM file is unavailable.")
        }
        try audioFile.write(from: buffer)
        totalFrameCount += AVAudioFramePosition(frameCount)
    }

    func finish() async throws -> ChatGPTEncodedAudio {
        guard !isFinished else {
            throw ChatGPTVoiceEncodingError.exportFailed("The encoder is already closed.")
        }
        guard totalFrameCount > 0 else {
            await cancel()
            throw ChatGPTVoiceEncodingError.emptyAudio
        }

        // Releasing AVAudioFile flushes and closes it on iOS 17.
        audioFile = nil

        guard let exporter = AVAssetExportSession(
            asset: AVURLAsset(url: pcmURL),
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            await cancel()
            throw ChatGPTVoiceEncodingError.unableToCreateExporter
        }

        try? FileManager.default.removeItem(at: outputURL)
        exporter.outputURL = outputURL
        exporter.outputFileType = .m4a
        await exporter.export()

        guard exporter.status == .completed else {
            let detail = exporter.error?.localizedDescription ?? "Unknown export error"
            await cancel()
            throw ChatGPTVoiceEncodingError.exportFailed(detail)
        }

        let outputData = try Data(contentsOf: outputURL)
        guard !outputData.isEmpty else {
            await cancel()
            throw ChatGPTVoiceEncodingError.emptyAudio
        }

        let duration = TimeInterval(totalFrameCount) / Self.sampleRate
        isFinished = true
        cleanupTemporaryFiles()
        return ChatGPTEncodedAudio(data: outputData, duration: duration)
    }

    func cancel() async {
        guard !isFinished else { return }
        // Releasing AVAudioFile flushes and closes it on iOS 17.
        audioFile = nil
        isFinished = true
        cleanupTemporaryFiles()
    }

    private func cleanupTemporaryFiles() {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }
}
