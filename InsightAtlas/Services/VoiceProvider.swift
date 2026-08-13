//
//  VoiceProvider.swift
//  InsightAtlas
//
//  Voice provider abstraction for on-device Kokoro narration.
//

import Foundation

// MARK: - Voice Provider Enum

/// Available voice-generation providers.
enum VoiceProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case kokoro = "kokoro"

    var id: String { rawValue }
    var displayName: String { "Kokoro (On-Device)" }
    var description: String { "Premium offline narration with no API key or per-use fee" }
    var requiresSeparateApiKey: Bool { false }
    var defaultVoiceID: String { KokoroVoiceRegistry.defaultVoice.voiceID }
    var audioFileExtension: String { "wav" }

    /// Check whether Kokoro can generate audio on this device.
    func isConfigured() -> Bool {
        KokoroModelStore.isInstalled
    }
}

// MARK: - Provider Availability and Fallbacks

struct VoiceProviderAvailability: Equatable, Sendable {
    let kokoro: Bool

    static var current: VoiceProviderAvailability {
        VoiceProviderAvailability(kokoro: KokoroModelStore.isInstalled)
    }

    func contains(_ provider: VoiceProvider) -> Bool {
        switch provider {
        case .kokoro:
            return kokoro
        }
    }
}

enum VoiceProviderFallbackPlanner {
    static func orderedProviders(
        preferred: VoiceProvider,
        availability: VoiceProviderAvailability
    ) -> [VoiceProvider] {
        availability.contains(preferred) ? [preferred] : []
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
            return "On-device narration is not ready. Download the Kokoro voice model in Settings."
        case .allProvidersFailed(let detail):
            return "On-device narration failed. \(detail)"
        }
    }
}

// MARK: - Voice Service Manager

@MainActor
final class VoiceServiceManager: ObservableObject {
    static let shared = VoiceServiceManager()

    private let kokoroService: KokoroAudioService

    @Published var currentProvider: VoiceProvider

    private init() {
        self.kokoroService = KokoroAudioService.shared
        self.currentProvider = .kokoro

        // Replace any persisted retired provider with the supported local provider.
        if UserDefaults.standard.string(forKey: "voice_provider") != VoiceProvider.kokoro.rawValue {
            UserDefaults.standard.set(VoiceProvider.kokoro.rawValue, forKey: "voice_provider")
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
        case .kokoro:
            return try await kokoroService.generateAudio(text: text, voiceID: voiceID)
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

        let voiceID = resolvedVoiceID(
            preferredVoiceID: preferredVoiceID,
            readerProfile: readerProfile
        )
        do {
            let audio = try await generateAudio(
                text: text,
                voiceID: voiceID,
                provider: .kokoro
            )
            return RoutedGeneratedAudio(audio: audio, provider: .kokoro, voiceID: voiceID)
        } catch {
            throw VoiceRoutingError.allProvidersFailed(error.localizedDescription)
        }
    }

    private func resolvedVoiceID(
        preferredVoiceID: String?,
        readerProfile: ReaderProfile
    ) -> String {
        if let preferredVoiceID,
           KokoroVoiceRegistry.isValidVoiceID(preferredVoiceID) {
            return preferredVoiceID
        }
        return KokoroVoiceRegistry.recommendedVoice(for: readerProfile).voiceID
    }

    func availableVoices() -> [any UnifiedVoice] {
        KokoroVoiceRegistry.allVoices
    }

    func defaultVoice() -> any UnifiedVoice {
        KokoroVoiceRegistry.defaultVoice
    }

    func voice(byID id: String) -> (any UnifiedVoice)? {
        KokoroVoiceRegistry.voice(byID: id)
    }
}
