//
//  OpenAIAudioService.swift
//  InsightAtlas
//
//  OpenAI Text-to-Speech Service.
//
//  Provides audio narration generation using OpenAI TTS API.
//  Uses the existing OpenAI API key from Keychain.
//
//  SECURITY:
//  - API key stored ONLY in iOS Keychain
//  - Key retrieved at request time, not cached in memory
//  - No logging of API key values
//  - Fails gracefully if key is missing
//
//  VERSION: 1.1.0 - Fixed audio concatenation for long content
//

import Foundation
import AVFoundation
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "InsightAtlas", category: "OpenAIAudioService")

// MARK: - OpenAI Audio Error

/// Errors that can occur during OpenAI audio generation
enum OpenAIAudioError: LocalizedError {
    case apiKeyMissing
    case invalidVoiceID
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case audioDecodingFailed
    case audioConcatenationFailed
    case rateLimitExceeded
    case quotaExceeded
    case serverError(Int)
    case textTooLong

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "OpenAI API key not configured. Please add your API key in Settings."
        case .invalidVoiceID:
            return "Invalid voice ID specified for audio generation."
        case .invalidURL:
            return "OpenAI API endpoint URL is invalid."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response received from OpenAI API."
        case .audioDecodingFailed:
            return "Failed to decode audio data from response."
        case .audioConcatenationFailed:
            return "Failed to concatenate audio chunks."
        case .rateLimitExceeded:
            return "OpenAI rate limit exceeded. Please try again later."
        case .quotaExceeded:
            return "OpenAI quota exceeded. Please check your account."
        case .serverError(let code):
            return "OpenAI server error (HTTP \(code)). Please try again."
        case .textTooLong:
            return "Text exceeds maximum length for OpenAI TTS."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .apiKeyMissing:
            return "Go to Settings → AI Provider → OpenAI API Key and enter your API key."
        case .quotaExceeded:
            return "Consider checking your OpenAI billing or waiting for quota reset."
        case .rateLimitExceeded:
            return "Wait a few minutes before trying again."
        case .textTooLong:
            return "The text will be split into smaller chunks automatically."
        case .audioConcatenationFailed:
            return "Try generating the audio again."
        default:
            return nil
        }
    }
}

// MARK: - OpenAI TTS Request

/// Request body for OpenAI TTS API
private struct OpenAITTSRequest: Codable {
    let model: String
    let input: String
    let voice: String
    let response_format: String
    let speed: Double

    init(text: String, voiceID: String, speed: Double = 1.0) {
        self.model = "tts-1-hd" // High-quality model
        self.input = text
        self.voice = voiceID
        self.response_format = "mp3"
        self.speed = speed
    }
}

// MARK: - OpenAI Audio Service

/// Service for generating audio narration using OpenAI TTS API.
///
/// SECURITY NOTES:
/// - API key is retrieved from Keychain at request time
/// - Key is NEVER stored in memory beyond the scope of a single request
/// - Key is NEVER logged or transmitted to any other service
///
/// Usage:
/// ```swift
/// let service = OpenAIAudioService()
/// do {
///     let audio = try await service.generateAudio(
///         text: "Hello, world!",
///         voiceID: "alloy"
///     )
///     // Use audio.data
/// } catch OpenAIAudioError.apiKeyMissing {
///     // Prompt user to configure API key
/// }
/// ```
final class OpenAIAudioService: AudioServiceProtocol {

    // MARK: - Constants

    private enum Constants {
        static let baseURL = "https://api.openai.com/v1"
        static let ttsEndpoint = "/audio/speech"
        static let maxInputLength = 4096 // OpenAI TTS limit
        static let requestTimeout: TimeInterval = 60
    }

    // MARK: - Properties

    private let urlSession: URLSession

    // MARK: - Initialization

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Constants.requestTimeout
        config.timeoutIntervalForResource = Constants.requestTimeout * 2
        self.urlSession = URLSession(configuration: config)
    }

    // MARK: - Retry Configuration

    private enum RetryConfig {
        static let maxRetries = 3
        static let initialDelaySeconds: Double = 1.0
        static let maxDelaySeconds: Double = 10.0
        static let backoffMultiplier: Double = 2.0
    }

    // MARK: - Public Methods

    /// Generate audio from text using OpenAI TTS (protocol conformance).
    /// Uses default playback speed of 1.0.
    func generateAudio(
        text: String,
        voiceID: String
    ) async throws -> GeneratedAudio {
        try await generateAudio(text: text, voiceID: voiceID, speed: 1.0)
    }

    /// Generate audio from text using OpenAI TTS with automatic retry for transient failures.
    /// Handles long text by splitting into chunks and properly concatenating the audio using AVFoundation.
    ///
    /// - Parameters:
    ///   - text: Text to convert to speech (will be chunked if > 4096 chars)
    ///   - voiceID: OpenAI voice ID (alloy, echo, fable, onyx, nova, shimmer)
    ///   - speed: Playback speed (0.25 to 4.0, default 1.0)
    /// - Returns: Generated audio data (properly concatenated if text was chunked)
    /// - Throws: `OpenAIAudioError` if generation fails after all retries
    func generateAudio(
        text: String,
        voiceID: String,
        speed: Double
    ) async throws -> GeneratedAudio {
        // Validate voice ID
        guard OpenAIVoiceRegistry.isValidVoiceID(voiceID) else {
            throw OpenAIAudioError.invalidVoiceID
        }

        // Split text into chunks if needed
        let chunks = splitTextIntoChunks(text)

        // If only one chunk, generate directly
        if chunks.count == 1 {
            return try await generateAudioWithRetry(
                text: chunks[0],
                voiceID: voiceID,
                speed: speed
            )
        }

        // Generate audio for each chunk
        var chunkAudios: [GeneratedAudio] = []
        var totalCharacters = 0

        for (index, chunk) in chunks.enumerated() {
            logger.info("Generating audio chunk \(index + 1)/\(chunks.count) (\(chunk.count) chars)")

            let chunkAudio = try await generateAudioWithRetry(
                text: chunk,
                voiceID: voiceID,
                speed: speed
            )

            chunkAudios.append(chunkAudio)
            totalCharacters += chunkAudio.characterCount
        }

        // Properly concatenate audio chunks using AVFoundation
        logger.info("Concatenating \(chunks.count) audio chunks...")
        let concatenatedAudio = try await concatenateAudioChunks(chunkAudios)

        logger.info("Generated \(chunks.count) chunks, total duration: \(String(format: "%.1f", concatenatedAudio.duration))s")

        return GeneratedAudio(
            data: concatenatedAudio.data,
            duration: concatenatedAudio.duration,
            characterCount: totalCharacters,
            voiceID: voiceID
        )
    }

    /// Properly concatenate multiple audio chunks using AVFoundation
    /// This method decodes each MP3 chunk, combines them, and exports as M4A (AAC)
    private func concatenateAudioChunks(_ chunks: [GeneratedAudio]) async throws -> (data: Data, duration: TimeInterval) {
        guard !chunks.isEmpty else {
            throw OpenAIAudioError.audioConcatenationFailed
        }

        // Create temporary directory for chunk files
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("audio_concat_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            // Clean up temporary files
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Save each chunk to a temporary file
        var chunkURLs: [URL] = []
        for (index, chunk) in chunks.enumerated() {
            let chunkURL = tempDir.appendingPathComponent("chunk_\(index).mp3")
            try chunk.data.write(to: chunkURL)
            chunkURLs.append(chunkURL)
        }

        // Create composition to merge all audio
        let composition = AVMutableComposition()
        guard let compositionTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw OpenAIAudioError.audioConcatenationFailed
        }

        var currentTime = CMTime.zero

        for chunkURL in chunkURLs {
            let asset = AVURLAsset(url: chunkURL)

            // Load tracks asynchronously
            let tracks: [AVAssetTrack]
            if #available(iOS 15.0, *) {
                tracks = try await asset.loadTracks(withMediaType: .audio)
            } else {
                tracks = asset.tracks(withMediaType: .audio)
            }

            guard let assetTrack = tracks.first else {
                logger.warning("No audio track found in chunk")
                continue
            }

            // Get duration
            let duration: CMTime
            if #available(iOS 15.0, *) {
                duration = try await asset.load(.duration)
            } else {
                duration = asset.duration
            }

            let timeRange = CMTimeRange(start: .zero, duration: duration)

            do {
                try compositionTrack.insertTimeRange(timeRange, of: assetTrack, at: currentTime)
                currentTime = CMTimeAdd(currentTime, duration)
            } catch {
                logger.error("Failed to insert audio track: \(error.localizedDescription)")
                throw OpenAIAudioError.audioConcatenationFailed
            }
        }

        // Export the merged audio to M4A (AAC) format
        let outputURL = tempDir.appendingPathComponent("merged_audio.m4a")

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw OpenAIAudioError.audioConcatenationFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        // Export using async/await
        await exportSession.export()

        guard exportSession.status == .completed else {
            if let error = exportSession.error {
                logger.error("Export failed: \(error.localizedDescription)")
            }
            throw OpenAIAudioError.audioConcatenationFailed
        }

        // Read the exported file
        let exportedData = try Data(contentsOf: outputURL)
        let totalDuration = CMTimeGetSeconds(currentTime)

        logger.info("Successfully concatenated audio: \(exportedData.count) bytes, \(String(format: "%.1f", totalDuration))s")

        return (data: exportedData, duration: totalDuration)
    }

    /// Split text into chunks that respect sentence boundaries
    private func splitTextIntoChunks(_ text: String) -> [String] {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // If text fits in one chunk, return as-is
        if trimmedText.count <= Constants.maxInputLength {
            return [trimmedText]
        }

        var chunks: [String] = []
        var currentChunk = ""

        // Split by sentences
        let sentencePattern = #"[^.!?]*[.!?]+"#
        let regex = try? NSRegularExpression(pattern: sentencePattern, options: [])
        let range = NSRange(trimmedText.startIndex..., in: trimmedText)

        var sentences: [String] = []
        regex?.enumerateMatches(in: trimmedText, options: [], range: range) { match, _, _ in
            if let matchRange = match?.range, let swiftRange = Range(matchRange, in: trimmedText) {
                sentences.append(String(trimmedText[swiftRange]).trimmingCharacters(in: .whitespaces))
            }
        }

        // If regex failed or no sentences found, fall back to simple splitting
        if sentences.isEmpty {
            sentences = trimmedText.components(separatedBy: ". ").map { $0 + "." }
        }

        for sentence in sentences {
            if currentChunk.count + sentence.count + 1 > Constants.maxInputLength {
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk.trimmingCharacters(in: .whitespaces))
                }

                if sentence.count > Constants.maxInputLength {
                    // Split long sentence by words
                    let words = sentence.split(separator: " ")
                    currentChunk = ""
                    for word in words {
                        if currentChunk.count + word.count + 1 > Constants.maxInputLength {
                            chunks.append(currentChunk.trimmingCharacters(in: .whitespaces))
                            currentChunk = String(word)
                        } else {
                            currentChunk += (currentChunk.isEmpty ? "" : " ") + word
                        }
                    }
                } else {
                    currentChunk = sentence
                }
            } else {
                if currentChunk.isEmpty {
                    currentChunk = sentence
                } else {
                    currentChunk += " " + sentence
                }
            }
        }

        if !currentChunk.trimmingCharacters(in: .whitespaces).isEmpty {
            chunks.append(currentChunk.trimmingCharacters(in: .whitespaces))
        }

        return chunks
    }

    /// Generate audio with automatic retry for transient failures
    private func generateAudioWithRetry(
        text: String,
        voiceID: String,
        speed: Double
    ) async throws -> GeneratedAudio {
        var lastError: Error?
        var delay = RetryConfig.initialDelaySeconds

        for attempt in 1...RetryConfig.maxRetries {
            do {
                return try await performAudioGeneration(
                    text: text,
                    voiceID: voiceID,
                    speed: speed
                )
            } catch let error as OpenAIAudioError {
                lastError = error

                guard isTransientError(error) else {
                    throw error
                }

                guard attempt < RetryConfig.maxRetries else {
                    break
                }

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                delay = min(delay * RetryConfig.backoffMultiplier, RetryConfig.maxDelaySeconds)
            } catch {
                lastError = error

                guard attempt < RetryConfig.maxRetries else {
                    break
                }

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                delay = min(delay * RetryConfig.backoffMultiplier, RetryConfig.maxDelaySeconds)
            }
        }

        throw lastError ?? OpenAIAudioError.invalidResponse
    }

    /// Check if an error is transient and worth retrying
    private func isTransientError(_ error: OpenAIAudioError) -> Bool {
        switch error {
        case .rateLimitExceeded:
            return true
        case .serverError(let code):
            return code >= 500
        case .networkError:
            return true
        case .apiKeyMissing, .invalidVoiceID, .invalidURL, .quotaExceeded,
             .invalidResponse, .audioDecodingFailed, .audioConcatenationFailed, .textTooLong:
            return false
        }
    }

    /// Perform the actual audio generation request
    private func performAudioGeneration(
        text: String,
        voiceID: String,
        speed: Double
    ) async throws -> GeneratedAudio {
        // SECURITY: Retrieve API key from Keychain at request time
        guard let apiKey = KeychainService.shared.openaiApiKey else {
            throw OpenAIAudioError.apiKeyMissing
        }

        // Build request
        guard let url = URL(string: "\(Constants.baseURL)\(Constants.ttsEndpoint)") else {
            throw OpenAIAudioError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // Build request body
        let requestBody = OpenAITTSRequest(text: text, voiceID: voiceID, speed: speed)
        request.httpBody = try JSONEncoder().encode(requestBody)

        // Make request
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw OpenAIAudioError.networkError(error)
        }

        // Handle response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIAudioError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            guard !data.isEmpty else {
                throw OpenAIAudioError.audioDecodingFailed
            }

            let duration = calculateAudioDuration(from: data, characterCount: text.count)

            return GeneratedAudio(
                data: data,
                duration: duration,
                characterCount: text.count,
                voiceID: voiceID
            )

        case 401:
            throw OpenAIAudioError.apiKeyMissing

        case 429:
            throw OpenAIAudioError.rateLimitExceeded

        case 402:
            throw OpenAIAudioError.quotaExceeded

        default:
            throw OpenAIAudioError.serverError(httpResponse.statusCode)
        }
    }

    /// Calculate audio duration from data, with fallback estimation
    private func calculateAudioDuration(from data: Data, characterCount: Int = 0) -> TimeInterval {
        // Primary: Use AVAudioPlayer to get accurate duration
        if let player = try? AVAudioPlayer(data: data) {
            return player.duration
        }

        // Fallback: Estimate from MP3 data size
        // MP3 at typical speech bitrate (~64kbps) = 8KB per second
        let estimatedFromBytes = Double(data.count) / 8000.0 * 1.2

        if data.count > 1000 {
            return estimatedFromBytes
        }

        // Fallback 2: Estimate from character count
        // Average speech rate: ~150 words per minute
        // Average word length: ~5 characters
        // So ~750 characters per minute = ~12.5 characters per second
        if characterCount > 0 {
            return Double(characterCount) / 12.5
        }

        return max(estimatedFromBytes, 0)
    }

    /// Check if the service is properly configured
    var isConfigured: Bool {
        KeychainService.shared.hasOpenAIApiKey
    }

    /// Validate API key by making a test request
    func validateApiKey() async throws -> Bool {
        guard let apiKey = KeychainService.shared.openaiApiKey else {
            throw OpenAIAudioError.apiKeyMissing
        }

        // Use the models endpoint to validate the key
        guard let url = URL(string: "\(Constants.baseURL)/models") else {
            throw OpenAIAudioError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAIAudioError.invalidResponse
            }

            return httpResponse.statusCode == 200
        } catch let error as OpenAIAudioError {
            throw error
        } catch {
            throw OpenAIAudioError.networkError(error)
        }
    }
}
