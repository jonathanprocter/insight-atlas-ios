//
//  GuideVisual.swift
//  InsightAtlas
//
//  Model for AI-generated visual content returned by the backend.
//

import Foundation

struct GuideVisual: Codable {
    let type: GuideVisualType
    let imageURL: URL
    let caption: String?

    /// AI's rationale for choosing this visual type (developer-only, debug builds)
    let rationale: String?

    init(type: GuideVisualType, imageURL: URL, caption: String? = nil, rationale: String? = nil) {
        self.type = type
        self.imageURL = imageURL
        self.caption = caption
        self.rationale = rationale
    }
}
