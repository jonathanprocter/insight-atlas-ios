//
//  InsightAtlasConfig.swift
//  InsightAtlas
//
//  Configuration defaults for Insight Atlas API.
//

import Foundation

enum InsightAtlasConfig {
    // API Defaults
    static let defaultReaderProfile: ReaderProfile = .executive
    static let defaultEditorialStance: EditorialStance = .neutralAnalyst
    /// Provider requested from the optional hosted backend only (see
    /// `GuideGenerationService`). `LLMProvider` has no MiniMax case because the
    /// backend contract only accepts Anthropic or OpenRouter; on-device guide
    /// generation uses `UserSettings.preferredProvider` (MiniMax by default),
    /// not this value.
    static let defaultModel: LLMProvider = .anthropic

    // Visual Settings
    static var visualsEnabled: Bool = true
}
