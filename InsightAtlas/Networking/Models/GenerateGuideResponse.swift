//
//  GenerateGuideResponse.swift
//  InsightAtlas
//
//  Response model for guide generation API.
//

import Foundation

struct GenerateGuideResponse: Codable {
    let title: String
    let qualityScore: Double
    let sections: [GuideSection]
    let concepts: [String]
    let generatedAt: Date
    let layoutScore: LayoutScore?
}

struct GuideSection: Codable, Identifiable {
    let id: UUID
    let heading: String
    let content: String
    let visual: GuideVisual?
}
