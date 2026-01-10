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
    static let defaultModel: LLMProvider = .anthropic

    // Visual Settings
    static var visualsEnabled: Bool = true
}
