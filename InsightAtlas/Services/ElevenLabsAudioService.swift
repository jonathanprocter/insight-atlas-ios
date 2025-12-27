//
//  ElevenLabsAudioService.swift
//  InsightAtlas
//
//  Secure ElevenLabs Text-to-Speech Service.
//
//  Provides audio narration generation using ElevenLabs API.
//  API key is retrieved securely from Keychain at request time.
//
//  SECURITY:
//  - API key stored ONLY in iOS Keychain
//  - Key retrieved at request time, not cached in memory
//  - No logging of API key values
//  - Fails gracefully if key is missing
//
//  VERSION: 1.0.0
//

import Foundation
import AVFoundation

// MARK: - ElevenLabs Audio Error

/// Errors that can occur during audio generation
enum ElevenLabsAudioError: LocalizedError {
    case apiKeyMissing
    case invalidVoiceID
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case audioDecodingFailed
    case rateLimitExceeded
    case quotaExceeded
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "ElevenLabs API key not configured. Please add your API key in Settings → Audio."
        case .invalidVoiceID:
            return "Invalid voice ID specified for audio generation."
        case .invalidURL:
            return "ElevenLabs API endpoint URL is invalid."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response received from ElevenLabs API."
        case .audioDecodingFailed:
            return "Failed to decode audio data from response."
        case .rateLimitExceeded:
            return "ElevenLabs rate limit exceeded. Please try again later."
        case .quotaExceeded:
            return "ElevenLabs character quota exceeded. Please check your account."
        case .serverError(let code):
            return "ElevenLabs server error (HTTP \(code)). Please try again."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .apiKeyMissing:
            return "Go to Settings → Audio → ElevenLabs API Key and enter your API key."
        case .quotaExceeded:
            return "Consider upgrading your ElevenLabs plan or waiting for quota reset."
        case .rateLimitExceeded:
            return "Wait a few minutes before trying again."
        default:
            return nil
        }
    }
}

// MARK: - Audio Generation Request

/// Request parameters for audio generation
struct AudioGenerationRequest {
    let text: String
    let voiceID: String
    let modelID: String
    let voiceSettings: VoiceSettings

    struct VoiceSettings: Codable {
        let stability: Double
        let similarityBoost: Double
        let style: Double
        let useSpeakerBoost: Bool

        enum CodingKeys: String, CodingKey {
            case stability
            case similarityBoost = "similarity_boost"
            case style
            case useSpeakerBoost = "use_speaker_boost"
        }

        /// Default settings optimized for narration
        static let narration = VoiceSettings(
            stability: 0.5,
            similarityBoost: 0.75,
            style: 0.0,
            useSpeakerBoost: true
        )

        /// Settings for emphatic/quote delivery
        static let emphatic = VoiceSettings(
            stability: 0.6,
            similarityBoost: 0.8,
            style: 0.2,
            useSpeakerBoost: true
        )
    }

    /// Default model for high-quality narration
    static let defaultModel = "eleven_multilingual_v2"
}

// MARK: - Audio Generation Response

/// Generated audio data with metadata
struct GeneratedAudio {
    let data: Data
    /// Duration in seconds. Always provided (uses estimation fallback if AVAudioPlayer fails).
    let duration: TimeInterval
    let characterCount: Int
    let voiceID: String
}

// MARK: - ElevenLabs Audio Service

/// Service for generating audio narration using ElevenLabs API.
///
/// SECURITY NOTES:
/// - API key is retrieved from Keychain at request time
/// - Key is NEVER stored in memory beyond the scope of a single request
/// - Key is NEVER logged or transmitted to any other service
///
/// Usage:
/// ```swift
/// let service = ElevenLabsAudioService()
/// do {
///     let audio = try await service.generateAudio(
///         text: "Hello, world!",
///         voiceID: "pNInz6obpgDQGcFmaJgB"
///     )
///     // Use audio.data
/// } catch ElevenLabsAudioError.apiKeyMissing {
///     // Prompt user to configure API key
/// }
/// ```
final class ElevenLabsAudioService {

    // MARK: - Constants

    private enum Constants {
        static let baseURL = "https://api.elevenlabs.io/v1"
        static let textToSpeechPath = "/text-to-speech"
        static let maxTextLength = 5000 // Characters per request
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

    /// Generate audio from text using ElevenLabs TTS with automatic retry for transient failures
    ///
    /// - Parameters:
    ///   - text: Text to convert to speech
    ///   - voiceID: ElevenLabs voice ID
    ///   - settings: Optional voice settings (defaults to narration settings)
    ///   - modelID: Optional model ID (defaults to multilingual v2)
    ///   - retryOnTransientFailure: Whether to retry on transient failures (default: true)
    /// - Returns: Generated audio data
    /// - Throws: `ElevenLabsAudioError` if generation fails after all retries
    func generateAudio(
        text: String,
        voiceID: String,
        settings: AudioGenerationRequest.VoiceSettings = .narration,
        modelID: String = AudioGenerationRequest.defaultModel,
        retryOnTransientFailure: Bool = true
    ) async throws -> GeneratedAudio {
        if retryOnTransientFailure {
            return try await generateAudioWithRetry(
                text: text,
                voiceID: voiceID,
                settings: settings,
                modelID: modelID
            )
        } else {
            return try await performAudioGeneration(
                text: text,
                voiceID: voiceID,
                settings: settings,
                modelID: modelID
            )
        }
    }

    /// Generate audio with automatic retry for transient failures
    private func generateAudioWithRetry(
        text: String,
        voiceID: String,
        settings: AudioGenerationRequest.VoiceSettings,
        modelID: String
    ) async throws -> GeneratedAudio {
        var lastError: Error?
        var delay = RetryConfig.initialDelaySeconds

        for attempt in 1...RetryConfig.maxRetries {
            do {
                return try await performAudioGeneration(
                    text: text,
                    voiceID: voiceID,
                    settings: settings,
                    modelID: modelID
                )
            } catch let error as ElevenLabsAudioError {
                lastError = error

                // Only retry on transient errors
                guard isTransientError(error) else {
                    throw error
                }

                // Don't retry on last attempt
                guard attempt < RetryConfig.maxRetries else {
                    break
                }

                // Wait with exponential backoff
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                delay = min(delay * RetryConfig.backoffMultiplier, RetryConfig.maxDelaySeconds)
            } catch {
                // Non-ElevenLabs errors (network, etc.) - retry
                lastError = error

                guard attempt < RetryConfig.maxRetries else {
                    break
                }

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                delay = min(delay * RetryConfig.backoffMultiplier, RetryConfig.maxDelaySeconds)
            }
        }

        throw lastError ?? ElevenLabsAudioError.invalidResponse
    }

    /// Check if an error is transient and worth retrying
    private func isTransientError(_ error: ElevenLabsAudioError) -> Bool {
        switch error {
        case .rateLimitExceeded:
            return true // Rate limit is temporary
        case .serverError(let code):
            return code >= 500 // 5xx errors are server-side and may be transient
        case .networkError:
            return true // Network errors may be transient
        case .apiKeyMissing, .invalidVoiceID, .invalidURL, .quotaExceeded, .invalidResponse, .audioDecodingFailed:
            return false // These are not transient
        }
    }

    /// Perform the actual audio generation request
    private func performAudioGeneration(
        text: String,
        voiceID: String,
        settings: AudioGenerationRequest.VoiceSettings,
        modelID: String
    ) async throws -> GeneratedAudio {
        // SECURITY: Retrieve API key from Keychain at request time
        guard let apiKey = KeychainService.shared.elevenLabsApiKey else {
            throw ElevenLabsAudioError.apiKeyMissing
        }

        // Validate inputs
        guard !voiceID.isEmpty else {
            throw ElevenLabsAudioError.invalidVoiceID
        }

        // Truncate text if too long (ElevenLabs has character limits)
        let truncatedText = String(text.prefix(Constants.maxTextLength))

        // Build request
        guard let url = URL(string: "\(Constants.baseURL)\(Constants.textToSpeechPath)/\(voiceID)") else {
            throw ElevenLabsAudioError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")

        // SECURITY: API key is used only here and not stored
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        // Build request body
        let body: [String: Any] = [
            "text": truncatedText,
            "model_id": modelID,
            "voice_settings": [
                "stability": settings.stability,
                "similarity_boost": settings.similarityBoost,
                "style": settings.style,
                "use_speaker_boost": settings.useSpeakerBoost
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Make request
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw ElevenLabsAudioError.networkError(error)
        }

        // Handle response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ElevenLabsAudioError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            // Success - return audio data
            guard !data.isEmpty else {
                throw ElevenLabsAudioError.audioDecodingFailed
            }

            let duration = calculateAudioDuration(from: data, characterCount: truncatedText.count)

            return GeneratedAudio(
                data: data,
                duration: duration,
                characterCount: truncatedText.count,
                voiceID: voiceID
            )

        case 401:
            throw ElevenLabsAudioError.apiKeyMissing

        case 429:
            throw ElevenLabsAudioError.rateLimitExceeded

        case 402:
            throw ElevenLabsAudioError.quotaExceeded

        default:
            throw ElevenLabsAudioError.serverError(httpResponse.statusCode)
        }
    }

    /// Calculate audio duration from data, with fallback estimation
    ///
    /// - Parameters:
    ///   - data: Audio data (MP3)
    ///   - characterCount: Number of characters in the source text (for fallback)
    /// - Returns: Duration in seconds
    private func calculateAudioDuration(from data: Data, characterCount: Int = 0) -> TimeInterval {
        // Primary: Use AVAudioPlayer to get accurate duration
        if let player = try? AVAudioPlayer(data: data) {
            return player.duration
        }

        // Fallback 1: Estimate from MP3 data size
        // MP3 at typical speech bitrate (~64kbps) = 8KB per second
        // Add 20% buffer for variable bitrate
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

        // Final fallback: Return the byte-based estimate or 0
        return max(estimatedFromBytes, 0)
    }

    /// Check if the service is properly configured
    var isConfigured: Bool {
        KeychainService.shared.hasElevenLabsApiKey
    }

    /// Validate API key by making a test request
    ///
    /// - Returns: `true` if key is valid
    /// - Throws: Error if validation fails
    func validateApiKey() async throws -> Bool {
        guard let apiKey = KeychainService.shared.elevenLabsApiKey else {
            throw ElevenLabsAudioError.apiKeyMissing
        }

        // Use the /user endpoint to validate the key
        guard let url = URL(string: "\(Constants.baseURL)/user") else {
            throw ElevenLabsAudioError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        do {
            let (_, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ElevenLabsAudioError.invalidResponse
            }

            return httpResponse.statusCode == 200
        } catch let error as ElevenLabsAudioError {
            throw error
        } catch {
            throw ElevenLabsAudioError.networkError(error)
        }
    }

    // MARK: - Convenience Methods

    /// Generate audio for a narration block using voice registry
    ///
    /// - Parameters:
    ///   - blockPlan: Audio block plan from AudioNarrationService
    ///   - voiceConfig: Voice selection configuration
    /// - Returns: Generated audio data
    func generateAudio(
        for blockPlan: AudioBlockPlan,
        using voiceConfig: VoiceSelectionConfig
    ) async throws -> GeneratedAudio {
        // Skip silent blocks
        guard blockPlan.behavior != .silent else {
            return GeneratedAudio(
                data: Data(),
                duration: 0,
                characterCount: 0,
                voiceID: voiceConfig.voiceID
            )
        }

        // Determine voice settings based on behavior
        let settings: AudioGenerationRequest.VoiceSettings
        switch blockPlan.behavior {
        case .emphatic, .quoted:
            settings = .emphatic
        default:
            settings = .narration
        }

        return try await generateAudio(
            text: blockPlan.text,
            voiceID: voiceConfig.voiceID,
            settings: settings
        )
    }
}

// MARK: - Audio Playback Manager

/// Manages playback of generated audio
final class AudioPlaybackManager: NSObject, AVAudioPlayerDelegate {

    // MARK: - Singleton

    static let shared = AudioPlaybackManager()

    // MARK: - Properties

    private var audioPlayer: AVAudioPlayer?
    private var completionHandler: (() -> Void)?

    // MARK: - Initialization

    private override init() {
        super.init()
        configureAudioSession()
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        do {
            // Configure for background playback
            // .playback category allows audio to continue when app is backgrounded
            // .spokenAudio mode optimizes for voice narration
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers, .allowBluetoothA2DP]
            )
            // Activate session immediately to ensure background capability
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Log error but don't crash - audio playback is a nice-to-have
            print("[AudioPlaybackManager] Failed to configure audio session: \(error)")
        }
    }

    /// Ensure audio session is active for background playback
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

    // MARK: - Playback

    /// Play generated audio
    ///
    /// - Parameters:
    ///   - audio: Generated audio data
    ///   - completion: Called when playback completes
    func play(_ audio: GeneratedAudio, completion: (() -> Void)? = nil) throws {
        guard !audio.data.isEmpty else {
            completion?()
            return
        }

        // Stop any existing playback
        stop()

        // Ensure audio session is configured for background playback
        ensureAudioSessionActive()

        // Create player
        audioPlayer = try AVAudioPlayer(data: audio.data)
        audioPlayer?.delegate = self
        completionHandler = completion

        audioPlayer?.play()
    }

    /// Play audio from a file URL
    func playFile(at url: URL, completion: (() -> Void)? = nil) throws {
        // Stop any existing playback
        stop()

        // Ensure audio session is configured for background playback
        ensureAudioSessionActive()

        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.delegate = self
        completionHandler = completion
        audioPlayer?.play()
    }

    /// Stop current playback
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        completionHandler = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Pause current playback
    func pause() {
        audioPlayer?.pause()
    }

    /// Resume paused playback
    func resume() {
        audioPlayer?.play()
    }

    /// Check if audio is currently playing
    var isPlaying: Bool {
        audioPlayer?.isPlaying ?? false
    }

    /// Current playback progress (0.0 to 1.0)
    var progress: Double {
        guard let player = audioPlayer, player.duration > 0 else { return 0 }
        return player.currentTime / player.duration
    }

    var duration: TimeInterval {
        audioPlayer?.duration ?? 0
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        completionHandler?()
        completionHandler = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
