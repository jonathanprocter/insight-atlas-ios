//
//  GuideVisualType.swift
//  InsightAtlas
//
//  Enum representing the types of AI-generated visuals.
//

import Foundation

/// Types of visuals that can be generated for editorial blocks
enum GuideVisualType: String, Codable, CaseIterable {
    case timeline = "timeline"
    case flowDiagram = "flow_diagram"
    case comparisonMatrix = "comparison_matrix"
    case barChart = "bar_chart"
    case quadrant = "quadrant"
    case conceptMap = "concept_map"
    
    var displayName: String {
        switch self {
        case .timeline: return "Timeline"
        case .flowDiagram: return "Flow Diagram"
        case .comparisonMatrix: return "Comparison Matrix"
        case .barChart: return "Bar Chart"
        case .quadrant: return "Quadrant Diagram"
        case .conceptMap: return "Concept Map"
        }
    }
}
