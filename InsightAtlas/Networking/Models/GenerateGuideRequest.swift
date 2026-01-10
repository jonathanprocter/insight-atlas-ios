//
//  GenerateGuideRequest.swift
//  InsightAtlas
//
//  Request model for guide generation API.
//

import Foundation

struct GenerateGuideRequest: Codable {
    let sourceType: SourceType
    let sourceValue: String

    let readerProfile: ReaderProfile
    let editorialStance: EditorialStance
    let model: LLMProvider
}

enum SourceType: String, Codable {
    case isbn
    case uploadedText
    case uploadedPDF
}

enum ReaderProfile: String, Codable {
    case executive
    case academic
    case practitioner
    case skeptic
}

enum EditorialStance: String, Codable {
    case neutralAnalyst
    case skepticalEditor
    case practitionerAlly
}

enum LLMProvider: String, Codable {
    case openai
    case anthropic
    case local
}
