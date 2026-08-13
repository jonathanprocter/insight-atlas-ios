// ElevenLabs removed

import Foundation

struct VoicePacingTuning: Codable, Equatable {
    let baseRateMultiplier: Double
    let pauseMultiplier: Double
    let emphasisMultiplier: Double
    let preferredPlaybackRates: [Double]

    static let standard = VoicePacingTuning(
        baseRateMultiplier: 1.0,
        pauseMultiplier: 1.0,
        emphasisMultiplier: 1.0,
        preferredPlaybackRates: [1.0, 1.25, 1.5]
    )
}

struct VoiceSelectionConfig: Codable, Equatable {
    let profile: ReaderProfile
    let voiceID: String
    let voiceName: String
    let pacingTuning: VoicePacingTuning
    let isBackupVoice: Bool

    static func primary(for profile: ReaderProfile) -> VoiceSelectionConfig {
        VoiceSelectionConfig(
            profile: profile,
            voiceID: OnDeviceVoiceRegistry.defaultVoice.voiceID,
            voiceName: OnDeviceVoiceRegistry.defaultVoice.name,
            pacingTuning: .standard,
            isBackupVoice: false
        )
    }

    static func premium(for profile: ReaderProfile) -> VoiceSelectionConfig {
        primary(for: profile)
    }

    static func backup(for profile: ReaderProfile) -> VoiceSelectionConfig {
        VoiceSelectionConfig(
            profile: profile,
            voiceID: OnDeviceVoiceRegistry.defaultVoice.voiceID,
            voiceName: OnDeviceVoiceRegistry.defaultVoice.name,
            pacingTuning: .standard,
            isBackupVoice: true
        )
    }
}

@available(*, unavailable, message: "ElevenLabs integration removed")
struct ElevenLabsVoice: Codable, Equatable, Identifiable {
    let id: String
    let voiceID: String
    let name: String
    let description: String
}

@available(*, unavailable, message: "ElevenLabs integration removed")
enum ElevenLabsVoiceRegistry {}
