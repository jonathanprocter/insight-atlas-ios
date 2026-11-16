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
    case apple = "apple"

    /// UserDefaults key mirroring the user's engine choice, readable by the
    /// NarrationService actor without decoding the full settings blob.
    static let storageKey = "voice_provider"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kokoro: return "Pocket (On-Device)"
        case .apple: return "Apple Voice (On-Device)"
        }
    }

    var description: String {
        switch self {
        case .kokoro:
            return "Premium offline narration with no API key or per-use fee"
        case .apple:
            return "System voices — no model download; premium voices install via iOS Settings"
        }
    }

    var requiresSeparateApiKey: Bool { false }

    var defaultVoiceID: String {
        switch self {
        case .kokoro: return KokoroVoiceRegistry.defaultVoice.voiceID
        case .apple: return AppleVoiceCatalog.defaultVoice()?.identifier ?? ""
        }
    }

    var audioFileExtension: String { "wav" }

    /// Check whether this provider can generate audio on this device.
    func isConfigured() -> Bool {
        switch self {
        case .kokoro: return KokoroModelStore.isInstalled
        case .apple: return AppleVoiceCatalog.defaultVoice() != nil
        }
    }
}

// MARK: - Provider Availability and Fallbacks

struct VoiceProviderAvailability: Equatable, Sendable {
    let kokoro: Bool
    let apple: Bool

    static var current: VoiceProviderAvailability {
        VoiceProviderAvailability(
            kokoro: KokoroModelStore.isInstalled,
            apple: AppleVoiceCatalog.defaultVoice() != nil
        )
    }

    func contains(_ provider: VoiceProvider) -> Bool {
        switch provider {
        case .kokoro:
            return kokoro
        case .apple:
            return apple
        }
    }
}

enum VoiceProviderFallbackPlanner {
    /// The preferred provider first, then every other available provider, so
    /// a missing Kokoro install degrades to the Apple system voice instead of
    /// failing outright. Mirrors `NarrationFallbackPolicy.orderedRoutes`.
    static func orderedProviders(
        preferred: VoiceProvider,
        availability: VoiceProviderAvailability
    ) -> [VoiceProvider] {
        var ordered: [VoiceProvider] = []
        if availability.contains(preferred) {
            ordered.append(preferred)
        }
        for candidate in VoiceProvider.allCases
        where candidate != preferred && availability.contains(candidate) {
            ordered.append(candidate)
        }
        return ordered
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
            return "On-device narration is not ready. Narration uses an installed Pocket model or an Apple system voice."
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

        // Replace any persisted retired provider with the supported local
        // provider; a valid stored choice (kokoro or apple) is kept.
        let stored = UserDefaults.standard.string(forKey: VoiceProvider.storageKey)
        let provider = stored.flatMap(VoiceProvider.init(rawValue:)) ?? .kokoro
        self.currentProvider = provider
        UserDefaults.standard.set(provider.rawValue, forKey: VoiceProvider.storageKey)
    }

    func setProvider(_ provider: VoiceProvider) {
        currentProvider = provider
        UserDefaults.standard.set(provider.rawValue, forKey: VoiceProvider.storageKey)
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
        case .apple:
            return try await AppleSpeechAudioService.shared.generateAudio(
                text: text, voiceID: voiceID
            )
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
                preferredVoiceID: preferredVoiceID,
                readerProfile: readerProfile,
                provider: provider
            )
            do {
                let audio = try await generateAudio(
                    text: text,
                    voiceID: voiceID,
                    provider: provider
                )
                return RoutedGeneratedAudio(audio: audio, provider: provider, voiceID: voiceID)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
            }
        }
        throw VoiceRoutingError.allProvidersFailed(
            lastError?.localizedDescription ?? "Unknown narration failure."
        )
    }

    private func resolvedVoiceID(
        preferredVoiceID: String?,
        readerProfile: ReaderProfile,
        provider: VoiceProvider
    ) -> String {
        switch provider {
        case .kokoro:
            if let preferredVoiceID,
               KokoroVoiceRegistry.isValidVoiceID(preferredVoiceID) {
                return preferredVoiceID
            }
            return KokoroVoiceRegistry.recommendedVoice(for: readerProfile).voiceID
        case .apple:
            if let preferredVoiceID,
               AppleVoiceCatalog.voice(byID: preferredVoiceID) != nil {
                return preferredVoiceID
            }
            return AppleVoiceCatalog.selectedVoice()?.identifier ?? ""
        }
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
