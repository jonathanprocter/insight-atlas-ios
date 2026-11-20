//
//  AnalysisDetailModels.swift
//  Shared reader/export models for AnalysisDetailView.
//

import Foundation
import SwiftUI

struct QuickGlanceData {
    let coreMessage: String
    let keyPoints: [String]
    let readingTime: Int
}

struct AnalysisSection {
    let heading: String?
    var blocks: [AnalysisContentBlock]
}

struct AnalysisContentBlock {
    let type: AnalysisBlockType
    let content: String
    var listItems: [String]?
    var metadata: [String: String]?
    var visual: GuideVisual?
    var visualPayload: InsightVisual?

    init(
        type: AnalysisBlockType,
        content: String,
        listItems: [String]? = nil,
        metadata: [String: String]? = nil,
        visual: GuideVisual? = nil,
        visualPayload: InsightVisual? = nil
    ) {
        self.type = type
        self.content = content
        self.listItems = listItems
        self.metadata = metadata
        self.visual = visual
        self.visualPayload = visualPayload
    }
}

enum AnalysisBlockType {
    case paragraph
    case heading1
    case heading2
    case heading3
    case heading4
    case blockquote
    case insightNote
    case actionBox
    case keyTakeaways
    case foundationalNarrative
    case exercise
    case flowchart
    case bulletList
    case numberedList
    case visual
    case insightVisual
    case alternativePerspective
    case researchInsight
    case processTimeline
    case conceptMap
    // Premium block types
    case premiumQuote
    case authorSpotlight
    case premiumDivider
    case premiumH1
    case premiumH2
}
