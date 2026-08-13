//
//  VoiceProvider.swift
//  InsightAtlas
//
//  Voice provider abstraction for placeholder on-device Kokoro narration and ElevenLabs.
//

import Foundation

// MARK: - Voice Provider Enum

/// Available voice-generation providers, ordered by the default primary route.
enum VoiceProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case onDevice = "on_device"
    case elevenlabs = "elevenlabs"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .onDevice:
            return "On-Device (Kokoro)"
        case .elevenlabs:
            return "ElevenLabs"
        }
    }

    var description: String {
        switch self {
        case .onDevice:
            return "On-device Kokoro TTS — no API key required, works offline"
        case .elevenlabs:
            return "Premium voices with advanced customization"
        }
    }

    /// Whether this provider requires a provider-specific key beyond existing app credentials.
    var requiresSeparateApiKey: Bool {
        switch self {
        case .onDevice:
            return false
        case .elevenlabs:
            return true
        }
    }

    var defaultVoiceID: String {
        switch self {
        case .onDevice:
            return "daniel"
        case .elevenlabs:
            return ElevenLabsVoiceRegistry.adam.voiceID
        }
    }

    var audioFileExtension: String {
        switch self {
        case .onDevice:
            return "wav"
        case .elevenlabs:
            return "mp3"
        }
    }

    /// Check whether this provider has credentials available on this device.
    func isConfigured() -> Bool {
        switch self {
        case .onDevice:
            return true
        case .elevenlabs:
            return KeychainService.shared.hasElevenLabsApiKey
        }
    }
}

// MARK: - Provider Availability and Fallbacks

struct VoiceProviderAvailability: Equatable, Sendable {
    let onDevice: Bool
    let elevenLabs: Bool

    static var current: VoiceProviderAvailability {
        VoiceProviderAvailability(
            onDevice: true,
            elevenLabs: KeychainService.shared.hasElevenLabsApiKey
        )
    }

    func contains(_ provider: VoiceProvider) -> Bool {
        switch provider {
        case .onDevice:
            return onDevice
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
        var candidates: [VoiceProvider] = [.onDevice]
        if preferred != .onDevice {
            candidates.append(preferred)
        }
        candidates.append(.elevenlabs)

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
    var isConfigured: Bool { get }

    func generateAudio(
        text: String,
        voiceID: String
    ) async throws -> GeneratedAudio

    func validateApiKey() async throws -> Bool
}

// MARK: - Routed Audio Result

struct RoutedGeneratedAudio: Sendable {
    let audio: GeneratedAudio
    let provider: VoiceProvider
    let voiceID: String
}

enum VoiceRoutingError: LocalizedError {
    case noConfiguredProvider
    case allProvidersFailed(String)

    var errorDescription: String? {
        switch self {
        case .noConfiguredProvider:
            return "No narration provider is configured. On-device synthesis is coming soon; configure an ElevenLabs key to enable narration now."
        case .allProvidersFailed(let detail):
            return "All configured narration providers failed. \(detail)"
        }
    }
}

// MARK: - Voice Service Manager

@MainActor
final class VoiceServiceManager: ObservableObject {
    static let shared = VoiceServiceManager()

    private let elevenLabsService: ElevenLabsAudioService

    @Published var currentProvider: VoiceProvider

    private init() {
        self.elevenLabsService = ElevenLabsAudioService()

        if let savedProvider = UserDefaults.standard.string(forKey: "voice_provider"),
           let provider = VoiceProvider(rawValue: savedProvider) {
            self.currentProvider = provider
        } else {
            self.currentProvider = .onDevice
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
        case .onDevice:
            throw VoiceRoutingError.allProvidersFailed("Kokoro on-device integration not yet wired — coming soon")
        case .elevenlabs:
            return try await elevenLabsService.generateAudio(text: text, voiceID: voiceID)
        }
    }

    func generateAudioWithFallback(
        text: String,
        preferredVoiceID: String?,
        preferredProvider: VoiceProvider? = nil,
        readerProfile: ReaderProfile = .practitioner
    ) async throws -> RoutedGeneratedAudio {
        let providers = VoiceProviderFallbackPlanner.orderedProviders(
            preferred: preferredProvider ?? currentProvider,
            availability: .current
        )
        guard !providers.isEmpty else {
            throw VoiceRoutingError.noConfiguredProvider
        }

        var lastError: Error?
        for provider in providers {
            let voiceID = resolvedVoiceID(
                for: provider,
                preferredVoiceID: preferredVoiceID,
                readerProfile: readerProfile
            )
            do {
                let audio = try await generateAudio(
                    text: text,
                    voiceID: voiceID,
                    provider: provider
                )
                return RoutedGeneratedAudio(audio: audio, provider: provider, voiceID: voiceID)
            } catch {
                lastError = error
            }
        }

        throw VoiceRoutingError.allProvidersFailed(
            lastError?.localizedDescription ?? "No provider returned playable audio."
        )
    }

    private func resolvedVoiceID(
        for provider: VoiceProvider,
        preferredVoiceID: String?,
        readerProfile: ReaderProfile
    ) -> String {
        switch provider {
        case .onDevice:
            if let preferredVoiceID, OnDeviceVoiceRegistry.isValidVoiceID(preferredVoiceID) {
                return preferredVoiceID
            }
            return OnDeviceVoiceRegistry.defaultVoice.voiceID

        case .elevenlabs:
            if let preferredVoiceID,
               ElevenLabsVoiceRegistry.voice(byVoiceID: preferredVoiceID) != nil {
                return preferredVoiceID
            }
            return ElevenLabsVoiceRegistry.premiumPrimaryVoice(for: readerProfile).voiceID
        }
    }

    func availableVoices() -> [any UnifiedVoice] {
        switch currentProvider {
        case .onDevice:
            return OnDeviceVoiceRegistry.allVoices
        case .elevenlabs:
            return ElevenLabsVoiceRegistry.allVoices.map { ElevenLabsUnifiedVoice(voice: $0) }
        }
    }

    func defaultVoice() -> any UnifiedVoice {
        switch currentProvider {
        case .onDevice:
            return OnDeviceVoiceRegistry.defaultVoice
        case .elevenlabs:
            return ElevenLabsUnifiedVoice(voice: ElevenLabsVoiceRegistry.adam)
        }
    }

    func voice(byID id: String) -> (any UnifiedVoice)? {
        switch currentProvider {
        case .onDevice:
            return OnDeviceVoiceRegistry.voice(byID: id)
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

struct OnDevicePlaceholderVoice: UnifiedVoice {
    let voiceID: String
    let name: String
    let description: String

    var id: String { voiceID }
    var provider: VoiceProvider { .onDevice }
    var previewText: String { VoicePreviewScript.primary }

    static func == (lhs: OnDevicePlaceholderVoice, rhs: OnDevicePlaceholderVoice) -> Bool {
        lhs.voiceID == rhs.voiceID
    }
}

enum OnDeviceVoiceRegistry {
    static let daniel = OnDevicePlaceholderVoice(
        voiceID: "daniel",
        name: "Daniel",
        description: "Default Kokoro placeholder voice. On-device synthesis integration coming soon."
    )

    static let allVoices: [OnDevicePlaceholderVoice] = [daniel]
    static let defaultVoice: OnDevicePlaceholderVoice = daniel

    static func voice(byID id: String) -> OnDevicePlaceholderVoice? {
        allVoices.first { $0.voiceID == id }
    }

    static func isValidVoiceID(_ id: String) -> Bool {
        voice(byID: id) != nil
    }
}
