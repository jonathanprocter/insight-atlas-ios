//
//  VoiceProvider.swift
//  InsightAtlas
//
//  Voice Provider abstraction for multi-provider TTS support.
//
//  Supports OpenAI (default) and ElevenLabs voice providers.
//  OpenAI uses the existing OpenAI API key from Keychain.
//
//  VERSION: 1.0.0
//

import Foundation

// MARK: - Voice Provider Enum

/// Available voice generation providers
enum VoiceProvider: String, Codable, CaseIterable, Identifiable {
    case openai = "openai"
    case elevenlabs = "elevenlabs"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openai:
            return "OpenAI"
        case .elevenlabs:
            return "ElevenLabs"
        }
    }

    var description: String {
        switch self {
        case .openai:
            return "High-quality voices using your OpenAI API key"
        case .elevenlabs:
            return "Premium voices with advanced customization"
        }
    }

    /// Whether this provider requires a separate API key
    var requiresSeparateApiKey: Bool {
        switch self {
        case .openai:
            return false // Uses existing OpenAI key
        case .elevenlabs:
            return true
        }
    }

    /// Check if the provider is configured
    func isConfigured() -> Bool {
        switch self {
        case .openai:
            return KeychainService.shared.hasOpenAIApiKey
        case .elevenlabs:
            return KeychainService.shared.hasElevenLabsApiKey
        }
    }
}

// MARK: - Unified Voice Protocol

/// Protocol for voice representation across providers
protocol UnifiedVoice: Identifiable, Equatable {
    var id: String { get }
    var voiceID: String { get }
    var name: String { get }
    var description: String { get }
    var provider: VoiceProvider { get }
    var previewText: String { get }
}

// MARK: - Audio Service Protocol

/// Protocol for audio generation services
protocol AudioServiceProtocol {
    var provider: VoiceProvider { get }
    var isConfigured: Bool { get }

    func generateAudio(
        text: String,
        voiceID: String
    ) async throws -> GeneratedAudio

    func validateApiKey() async throws -> Bool
}

// MARK: - Voice Service Manager

/// Unified manager for voice generation across providers
@MainActor
final class VoiceServiceManager: ObservableObject {

    // MARK: - Singleton

    static let shared = VoiceServiceManager()

    // MARK: - Services

    private let openAIService: OpenAIAudioService
    private let elevenLabsService: ElevenLabsAudioService

    // MARK: - Published State

    @Published var currentProvider: VoiceProvider

    // MARK: - Initialization

    private init() {
        self.openAIService = OpenAIAudioService()
        self.elevenLabsService = ElevenLabsAudioService()

        // Load saved provider preference, default to OpenAI
        if let savedProvider = UserDefaults.standard.string(forKey: "voice_provider"),
           let provider = VoiceProvider(rawValue: savedProvider) {
            self.currentProvider = provider
        } else {
            self.currentProvider = .openai
        }
    }

    // MARK: - Provider Management

    func setProvider(_ provider: VoiceProvider) {
        currentProvider = provider
        UserDefaults.standard.set(provider.rawValue, forKey: "voice_provider")
    }

    var isCurrentProviderConfigured: Bool {
        currentProvider.isConfigured()
    }

    // MARK: - Audio Generation

    /// Generate audio using the current provider
    func generateAudio(
        text: String,
        voiceID: String
    ) async throws -> GeneratedAudio {
        switch currentProvider {
        case .openai:
            return try await openAIService.generateAudio(text: text, voiceID: voiceID)
        case .elevenlabs:
            return try await elevenLabsService.generateAudio(text: text, voiceID: voiceID)
        }
    }

    /// Generate audio with specific provider
    func generateAudio(
        text: String,
        voiceID: String,
        provider: VoiceProvider
    ) async throws -> GeneratedAudio {
        switch provider {
        case .openai:
            return try await openAIService.generateAudio(text: text, voiceID: voiceID)
        case .elevenlabs:
            return try await elevenLabsService.generateAudio(text: text, voiceID: voiceID)
        }
    }

    // MARK: - Voice Access

    /// Get all voices for current provider
    func availableVoices() -> [any UnifiedVoice] {
        switch currentProvider {
        case .openai:
            return OpenAIVoiceRegistry.allVoices
        case .elevenlabs:
            return ElevenLabsVoiceRegistry.allVoices.map { ElevenLabsUnifiedVoice(voice: $0) }
        }
    }

    /// Get default voice for current provider
    func defaultVoice() -> any UnifiedVoice {
        switch currentProvider {
        case .openai:
            return OpenAIVoiceRegistry.defaultVoice
        case .elevenlabs:
            return ElevenLabsUnifiedVoice(voice: ElevenLabsVoiceRegistry.adam)
        }
    }

    /// Get voice by ID for current provider
    func voice(byID id: String) -> (any UnifiedVoice)? {
        switch currentProvider {
        case .openai:
            return OpenAIVoiceRegistry.voice(byID: id)
        case .elevenlabs:
            if let voice = ElevenLabsVoiceRegistry.voice(byID: id) {
                return ElevenLabsUnifiedVoice(voice: voice)
            }
            return nil
        }
    }
}

// MARK: - ElevenLabs Unified Voice Wrapper

/// Wrapper to make ElevenLabsVoice conform to UnifiedVoice
struct ElevenLabsUnifiedVoice: UnifiedVoice {
    let voice: ElevenLabsVoice

    var id: String { voice.id }
    var voiceID: String { voice.voiceID }
    var name: String { voice.name }
    var description: String { voice.description }
    var provider: VoiceProvider { .elevenlabs }
    var previewText: String { VoicePreviewScript.primary }

    static func == (lhs: ElevenLabsUnifiedVoice, rhs: ElevenLabsUnifiedVoice) -> Bool {
        lhs.voice == rhs.voice
    }
}
