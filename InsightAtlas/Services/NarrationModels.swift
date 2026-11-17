//
//  NarrationModels.swift
//  InsightAtlas
//
//  Shared narration contracts used by on-device Pocket / Apple synthesis.
//  Hosted TTS types deliberately do not live here.
//

import Foundation

/// The completed, persisted narration for a summary.
struct NarrationAsset {
    /// File name relative to the Documents directory (e.g. `audio_<uuid>.m4a`).
    let relativeFileName: String
    /// Pocket or Apple voice identifier that produced the audio.
    let voiceID: String
    /// Duration of the assembled audio in seconds.
    let duration: TimeInterval
}

enum NarrationServiceError: LocalizedError {
    case alreadyInProgress
    case noConfiguredProvider
    case emptyText
    case documentsDirectoryUnavailable
    case invalidAudio
    case assemblyFailed
    case network(String)

    var errorDescription: String? {
        switch self {
        case .alreadyInProgress:
            return "Narration is already being generated for this guide."
        case .noConfiguredProvider:
            return "Download the Kokoro on-device voice model in Settings → Audio & Narration before listening."
        case .emptyText:
            return "There is no summary text to narrate."
        case .documentsDirectoryUnavailable:
            return "The app's Documents directory is unavailable."
        case .invalidAudio:
            return "The generated narration was not playable. Retry or choose another installed Kokoro voice."
        case .assemblyFailed:
            return "Failed to assemble the narration audio segments."
        case let .network(detail):
            return "Network error during narration: \(detail)"
        }
    }
}
