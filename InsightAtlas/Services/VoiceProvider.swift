//
//  VoiceProvider.swift
//  InsightAtlas
//
//  Voice provider abstraction for ChatGPT Voice, OpenAI TTS, and ElevenLabs.
//

import Foundation

// MARK: - Voice Provider Enum

/// Available voice-generation providers, ordered by the default primary route.
enum VoiceProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case chatgptVoice = "chatgpt_voice"
    case openai = "openai"
    case elevenlabs = "elevenlabs"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chatgptVoice:
            return "ChatGPT Voice (Experimental)"
        case .openai:
            return "OpenAI"
        case .elevenlabs:
            return "ElevenLabs"
        }
    }

    var description: String {
        switch self {
        case .chatgptVoice:
            return "Experimental GPT-Live narration using your ChatGPT sign-in"
        case .openai:
            return "High-quality narration using your OpenAI API key"
        case .elevenlabs:
            return "Premium voices with advanced customization"
        }
    }

    /// Whether this provider requires a provider-specific key beyond existing app credentials.
    var requiresSeparateApiKey: Bool {
        switch self {
        case .chatgptVoice, .openai:
            return false
        case .elevenlabs:
            return true
        }
    }

    var defaultVoiceID: String {
        switch self {
        case .chatgptVoice:
            return ChatGPTVoiceRegistry.defaultVoice.voiceID
        case .openai:
            return OpenAIVoiceRegistry.defaultVoice.voiceID
        case .elevenlabs:
            return ElevenLabsVoiceRegistry.adam.voiceID
        }
    }

    var audioFileExtension: String {
        switch self {
        case .chatgptVoice, .openai:
            return "m4a"
        case .elevenlabs:
            return "mp3"
        }
    }

    /// Check whether this provider has credentials available on this device.
    func isConfigured() -> Bool {
        switch self {
        case .chatgptVoice:
            return ChatGPTOAuthService.hasStoredCredentials
        case .openai:
            return KeychainService.shared.hasOpenAIApiKey
        case .elevenlabs:
            return KeychainService.shared.hasElevenLabsApiKey
        }
    }
}

// MARK: - Provider Availability and Fallbacks

struct VoiceProviderAvailability: Equatable, Sendable {
    let chatgptVoice: Bool
    let openAI: Bool
    let elevenLabs: Bool

    static var current: VoiceProviderAvailability {
        VoiceProviderAvailability(
            chatgptVoice: ChatGPTOAuthService.hasStoredCredentials,
            openAI: KeychainService.shared.hasOpenAIApiKey,
            elevenLabs: KeychainService.shared.hasElevenLabsApiKey
        )
    }

    func contains(_ provider: VoiceProvider) -> Bool {
        switch provider {
        case .chatgptVoice:
            return chatgptVoice
        case .openai:
            return openAI
        case .elevenlabs:
            return elevenLabs
        }
    }
}

enum VoiceProviderFallbackPlanner {
    static func orderedProviders(
        preferred: VoiceProvider,
        availability: VoiceProviderAvailability
    ) -> [VoiceProvider] {
        var candidates: [VoiceProvider] = [.chatgptVoice]
        if preferred != .chatgptVoice {
            candidates.append(preferred)
        }
        candidates.append(contentsOf: [.openai, .elevenlabs])

        var seen = Set<VoiceProvider>()
        return candidates.filter { provider in
            availability.contains(provider) && seen.insert(provider).inserted
        }
    }
}

// MARK: - Unified Voice Protocol

protocol UnifiedVoice: Identifiable, Equatable {
    var id: String { get }
    var voiceID: String { get }
    var name: String { get }
    var description: String { get }
    var provider: VoiceProvider { get }
    var previewText: String { get }
}

// MARK: - Audio Service Protocol

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

@MainActor
final class VoiceServiceManager: ObservableObject {
    static let shared = VoiceServiceManager()

    private let chatGPTVoiceService: ChatGPTVoiceService
    private let openAIService: OpenAIAudioService
    private let elevenLabsService: ElevenLabsAudioService

    @Published var currentProvider: VoiceProvider

    private init() {
        self.chatGPTVoiceService = ChatGPTVoiceService()
        self.openAIService = OpenAIAudioService()
        self.elevenLabsService = ElevenLabsAudioService()

        if let savedProvider = UserDefaults.standard.string(forKey: "voice_provider"),
           let provider = VoiceProvider(rawValue: savedProvider) {
            self.currentProvider = provider
        } else {
            self.currentProvider = .chatgptVoice
        }
    }

    func setProvider(_ provider: VoiceProvider) {
        currentProvider = provider
        UserDefaults.standard.set(provider.rawValue, forKey: "voice_provider")
    }

    var isCurrentProviderConfigured: Bool {
        currentProvider.isConfigured()
    }

    func generateAudio(
        text: String,
        voiceID: String
    ) async throws -> GeneratedAudio {
        try await generateAudio(text: text, voiceID: voiceID, provider: currentProvider)
    }

    func generateAudio(
        text: String,
        voiceID: String,
        provider: VoiceProvider
    ) async throws -> GeneratedAudio {
        switch provider {
        case .chatgptVoice:
            return try await chatGPTVoiceService.generateAudio(text: text, voiceID: voiceID)
        case .openai:
            return try await openAIService.generateAudio(text: text, voiceID: voiceID)
        case .elevenlabs:
            return try await elevenLabsService.generateAudio(text: text, voiceID: voiceID)
        }
    }

    func availableVoices() -> [any UnifiedVoice] {
        switch currentProvider {
        case .chatgptVoice:
            return ChatGPTVoiceRegistry.allVoices
        case .openai:
            return OpenAIVoiceRegistry.allVoices
        case .elevenlabs:
            return ElevenLabsVoiceRegistry.allVoices.map { ElevenLabsUnifiedVoice(voice: $0) }
        }
    }

    func defaultVoice() -> any UnifiedVoice {
        switch currentProvider {
        case .chatgptVoice:
            return ChatGPTVoiceRegistry.defaultVoice
        case .openai:
            return OpenAIVoiceRegistry.defaultVoice
        case .elevenlabs:
            return ElevenLabsUnifiedVoice(voice: ElevenLabsVoiceRegistry.adam)
        }
    }

    func voice(byID id: String) -> (any UnifiedVoice)? {
        switch currentProvider {
        case .chatgptVoice:
            return ChatGPTVoiceRegistry.voice(byID: id)
        case .openai:
            return OpenAIVoiceRegistry.voice(byID: id)
        case .elevenlabs:
            guard let voice = ElevenLabsVoiceRegistry.voice(byID: id) else { return nil }
            return ElevenLabsUnifiedVoice(voice: voice)
        }
    }
}

// MARK: - ElevenLabs Unified Voice Wrapper

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
