//
//  VoiceProvider.swift
//  InsightAtlas
//
//  Voice provider abstraction for placeholder on-device Kokoro narration.
//

import Foundation

// MARK: - Voice Provider Enum

/// Available voice-generation providers, ordered by the default primary route.
enum VoiceProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case onDevice = "on_device"

    var id: String { rawValue }

    var displayName: String {
        "On-Device (Kokoro)"
    }

    var description: String {
        "On-device Kokoro TTS — no API key required, works offline"
    }

    /// Whether this provider requires a provider-specific key beyond existing app credentials.
    var requiresSeparateApiKey: Bool {
        false
    }

    var defaultVoiceID: String {
        OnDeviceVoiceRegistry.defaultVoice.voiceID
    }

    var audioFileExtension: String {
        "wav"
    }

    /// Check whether this provider has credentials available on this device.
    func isConfigured() -> Bool {
        true
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = (try? container.decode(String.self)) ?? VoiceProvider.onDevice.rawValue
        self = VoiceProvider(rawValue: rawValue) ?? .onDevice
    }
}

// MARK: - Provider Availability and Fallbacks

struct VoiceProviderAvailability: Equatable, Sendable {
    let onDevice: Bool

    static var current: VoiceProviderAvailability {
        VoiceProviderAvailability(onDevice: true)
    }

    func contains(_ provider: VoiceProvider) -> Bool {
        provider == .onDevice && onDevice
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
            return "No narration provider is available."
        case .allProvidersFailed(let detail):
            return "On-device narration is currently unavailable. \(detail)"
        }
    }
}

// MARK: - Voice Service Manager

@MainActor
final class VoiceServiceManager: ObservableObject {
    static let shared = VoiceServiceManager()

    @Published var currentProvider: VoiceProvider

    private init() {
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
        _ = text
        _ = voiceID
        _ = provider
        throw VoiceRoutingError.allProvidersFailed("Kokoro on-device integration not yet wired.")
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
        _ = readerProfile
        switch provider {
        case .onDevice:
            if let preferredVoiceID, OnDeviceVoiceRegistry.isValidVoiceID(preferredVoiceID) {
                return preferredVoiceID
            }
            return OnDeviceVoiceRegistry.defaultVoice.voiceID
        }
    }

    func availableVoices() -> [any UnifiedVoice] {
        OnDeviceVoiceRegistry.allVoices
    }

    func defaultVoice() -> any UnifiedVoice {
        OnDeviceVoiceRegistry.defaultVoice
    }

    func voice(byID id: String) -> (any UnifiedVoice)? {
        OnDeviceVoiceRegistry.voice(byID: id)
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
