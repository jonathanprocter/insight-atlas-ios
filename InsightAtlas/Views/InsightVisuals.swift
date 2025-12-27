import SwiftUI

// MARK: - Insight Visual Models

enum InsightVisualType: String {
    case timeline = "VISUAL_TIMELINE"
    case flowchart = "VISUAL_FLOWCHART"
    case comparisonMatrix = "VISUAL_COMPARISON_MATRIX"
    case conceptMap = "VISUAL_CONCEPT_MAP"
    case radarChart = "VISUAL_RADAR"
    case hierarchy = "VISUAL_HIERARCHY"
    case networkGraph = "VISUAL_NETWORK"
    case barChart = "VISUAL_BAR_CHART"
    case quadrant = "VISUAL_QUADRANT"
    case pieChart = "VISUAL_PIE_CHART"
    case lineChart = "VISUAL_LINE_CHART"
    case areaChart = "VISUAL_AREA_CHART"
    case scatterPlot = "VISUAL_SCATTER_PLOT"
    case vennDiagram = "VISUAL_VENN"
    case ganttChart = "VISUAL_GANTT"
    case funnelDiagram = "VISUAL_FUNNEL"
    case pyramidDiagram = "VISUAL_PYRAMID"
    case cycleDiagram = "VISUAL_CYCLE"
    case fishboneDiagram = "VISUAL_FISHBONE"
    case swotMatrix = "VISUAL_SWOT"
    case sankeyDiagram = "VISUAL_SANKEY"
    case treemap = "VISUAL_TREEMAP"
    case heatmap = "VISUAL_HEATMAP"
    case bubbleChart = "VISUAL_BUBBLE"
    case infographic = "VISUAL_INFOGRAPHIC"
    case storyboard = "VISUAL_STORYBOARD"
    case journeyMap = "VISUAL_JOURNEY_MAP"
    case barChartStacked = "VISUAL_BAR_CHART_STACKED"
    case barChartGrouped = "VISUAL_BAR_CHART_GROUPED"
    case generic = "VISUAL_GENERIC"
}

struct InsightVisual {
    let type: InsightVisualType
    let title: String?
    let payload: InsightVisualPayload
}

enum InsightVisualPayload {
    case timeline(TimelineData)
    case flowchart(FlowchartData)
    case comparison(ComparisonMatrixData)
    case conceptMap(ConceptMapData)
    case radar(RadarData)
    case hierarchy(HierarchyData)
    case network(NetworkGraphData)
    case barChart(BarChartData)
    case quadrant(QuadrantData)
    case pieChart(PieChartData)
    case lineChart(LineChartData)
    case areaChart(AreaChartData)
    case scatterPlot(ScatterPlotData)
    case vennDiagram(VennDiagramData)
    case ganttChart(GanttChartData)
    case funnelDiagram(FunnelData)
    case pyramidDiagram(PyramidData)
    case cycleDiagram(CycleData)
    case fishboneDiagram(FishboneData)
    case swotMatrix(SWOTData)
    case sankeyDiagram(SankeyData)
    case treemap(TreemapData)
    case heatmap(HeatmapData)
    case bubbleChart(BubbleChartData)
    case infographic(InfographicData)
    case storyboard(StoryboardData)
    case journeyMap(JourneyMapData)
    case barChartStacked(StackedBarChartData)
    case barChartGrouped(GroupedBarChartData)
    case generic(String)
}

// MARK: - Data Structures

struct TimelineData: Codable {
    struct Event: Codable, Identifiable {
        let id = UUID()
        let date: String
        let title: String
        let description: String?

        enum CodingKeys: String, CodingKey {
            case date
            case title
            case description
        }
    }
    let events: [Event]
}

struct FlowchartData: Codable {
    let nodes: [String]
}

struct ComparisonMatrixData: Codable {
    let columns: [String]
    let rows: [[String]]
}

struct ConceptMapData: Codable {
    let center: String
    let branches: [String]
}

struct RadarData: Codable {
    let dimensions: [String]
}

struct HierarchyData: Codable {
    let root: String
    let children: [String]
}

struct NetworkGraphData: Codable {
    struct Node: Codable, Identifiable {
        let id: String
        let label: String
        let type: String?
    }
    struct Connection: Codable, Identifiable {
        let id = UUID()
        let from: String
        let to: String
        let type: String?
        let strength: String?

        enum CodingKeys: String, CodingKey {
            case from
            case to
            case type
            case strength
        }
    }
    let nodes: [Node]
    let connections: [Connection]
}

struct BarChartData: Codable {
    let labels: [String]
    let values: [Double]
}

struct QuadrantData: Codable {
    let axesX: String?
    let axesY: String?
    let quadrants: [Quadrant]

    struct Quadrant: Codable {
        let name: String
        let items: [String]
    }
}

struct PieChartData: Codable {
    struct Segment: Codable {
        let label: String
        let value: Double
        let color: String?
    }
    let segments: [Segment]
}

struct LineChartData: Codable {
    let labels: [String]
    let values: [Double]
}

struct AreaChartData: Codable {
    let labels: [String]
    let values: [Double]
}

struct ScatterPlotData: Codable {
    struct Point: Codable, Identifiable {
        let id = UUID()
        let x: Double
        let y: Double
        let label: String?

        enum CodingKeys: String, CodingKey {
            case x
            case y
            case label
        }
    }
    let points: [Point]
    let xAxis: String?
    let yAxis: String?
}

struct VennDiagramData: Codable {
    struct Set: Codable {
        let label: String
        let items: [String]
    }
    let sets: [Set]
    let intersection: [String]
}

struct GanttChartData: Codable {
    struct Task: Codable, Identifiable {
        let id = UUID()
        let name: String
        let start: Double
        let duration: Double
        let status: String?

        enum CodingKeys: String, CodingKey {
            case name
            case start
            case duration
            case status
        }
    }
    let tasks: [Task]
}

struct FunnelData: Codable {
    struct Stage: Codable {
        let label: String
        let value: Double
    }
    let stages: [Stage]
}

struct PyramidData: Codable {
    struct Level: Codable {
        let label: String
        let description: String?
    }
    let levels: [Level]
}

struct CycleData: Codable {
    let stages: [String]
}

struct FishboneData: Codable {
    struct Cause: Codable {
        let category: String
        let items: [String]
    }
    let effect: String
    let causes: [Cause]
}

struct SWOTData: Codable {
    let strengths: [String]
    let weaknesses: [String]
    let opportunities: [String]
    let threats: [String]
}

struct SankeyData: Codable {
    struct Flow: Codable {
        let from: String
        let to: String
        let value: Double
    }
    let flows: [Flow]
}

struct TreemapData: Codable {
    struct Item: Codable, Identifiable {
        let id = UUID()
        let label: String
        let value: Double

        enum CodingKeys: String, CodingKey {
            case label
            case value
        }
    }
    let items: [Item]
}

struct HeatmapData: Codable {
    let rows: [String]
    let cols: [String]
    let values: [[Double]]
}

struct BubbleChartData: Codable {
    struct Bubble: Codable, Identifiable {
        let id = UUID()
        let label: String
        let x: Double
        let y: Double
        let size: Double

        enum CodingKeys: String, CodingKey {
            case label
            case x
            case y
            case size
        }
    }
    let bubbles: [Bubble]
}

struct InfographicData: Codable {
    struct Stat: Codable {
        let label: String
        let value: String
    }
    let title: String
    let stats: [Stat]
    let highlights: [String]
}

struct StoryboardData: Codable {
    struct Scene: Codable, Identifiable {
        let id = UUID()
        let title: String
        let description: String
        let number: Int?

        enum CodingKeys: String, CodingKey {
            case title
            case description
            case number
        }
    }
    let scenes: [Scene]
}

struct JourneyMapData: Codable {
    struct Stage: Codable, Identifiable {
        let id = UUID()
        let name: String
        let touchpoints: [String]
        let emotion: String?

        enum CodingKeys: String, CodingKey {
            case name
            case touchpoints
            case emotion
        }
    }
    let stages: [Stage]
}

struct StackedBarChartData: Codable {
    let labels: [String]
    let series: [[Double]]
    let seriesLabels: [String]
}

struct GroupedBarChartData: Codable {
    let labels: [String]
    let series: [[Double]]
    let seriesLabels: [String]
}

// MARK: - Parser

struct InsightVisualParser {
    static func parse(tag: String, title: String?, lines: [String]) -> InsightVisual? {
        guard let type = InsightVisualType(rawValue: tag) else {
            return nil
        }

        let payloadText = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if content looks like JSON
        let looksLikeJSON = payloadText.hasPrefix("{") || payloadText.hasPrefix("[")

        if looksLikeJSON {
            // Try JSON parsing first
            if let visual = parseJSON(type: type, title: title, text: payloadText) {
                return visual
            }
            // If JSON parsing failed but content is JSON-like, return a generic visual
            // rather than trying to parse malformed JSON as line format
            return InsightVisual(type: type, title: title ?? "Visual", payload: .generic("Unable to render visual content"))
        }

        // For non-JSON content, try line format parsing
        if let visual = parseLineFormat(type: type, title: title, lines: lines) {
            return visual
        }

        // Fallback: return a generic visual with the raw content
        return InsightVisual(type: type, title: title ?? "Visual", payload: .generic(payloadText))
    }

    private static func parseJSON(type: InsightVisualType, title: String?, text: String) -> InsightVisual? {
        guard text.hasPrefix("{") || text.hasPrefix("[") else { return nil }
        let decoder = JSONDecoder()

        func decode<T: Decodable>(_ type: T.Type) -> T? {
            guard let data = text.data(using: .utf8) else { return nil }
            return try? decoder.decode(T.self, from: data)
        }

        switch type {
        case .timeline:
            guard let data = decode(TimelineData.self) else { return nil }
            return InsightVisual(type: type, title: title, payload: .timeline(data))
        case .flowchart:
            guard let data = decode(FlowchartData.self) else { return nil }
            return InsightVisual(type: type, title: title, payload: .flowchart(data))
        case .comparisonMatrix:
            guard let data = decode(ComparisonMatrixData.self) else { return nil }
            return InsightVisual(type: type, title: title, payload: .comparison(data))
        case .conceptMap:
            guard let data = decode(ConceptMapData.self) else { return nil }
            return InsightVisual(type: type, title: title, payload: .conceptMap(data))
        case .radarChart:
            guard let data = decode(RadarData.self) else { return nil }
            return InsightVisual(type: type, title: title, payload: .radar(data))
        case .hierarchy:
            guard let data = decode(HierarchyData.self) else { return nil }
            return InsightVisual(type: type, title: title, payload: .hierarchy(data))
        case .networkGraph:
            guard let data = decode(NetworkGraphData.self) else { return nil }
            return InsightVisual(type: type, title: title, payload: .network(data))
        case .barChart:
            guard let data = decode(BarChartData.self) else { return nil }
            return InsightVisual(type: type, title: title, payload: .barChart(data))
        case .quadrant:
            guard let data = decode(QuadrantData.self) else { return nil }
            return InsightVisual(type: type, title: title, payload: .quadrant(data))
        case .pieChart:
            guard let data = decode(PieChartData.self) else { return nil }
            return InsightVisual(type: type, title: title, payload: .pieChart(data))
        case .lineChart:
            guard let data = decode(LineChartData.self) else { return nil }
            return InsightVisual(type: type, title: title, payload: .lineChart(data))
        case .areaChart:
            guard let data = decode(AreaChartData.self) else { return nil }
            return InsightVisual(type: type, title: title, payload: .areaChart(data))
        case .scatterPlot:
            guard let data = decode(ScatterPlotData.self) else { return nil }
            return InsightVisual(type: type, title: title, payload: .scatterPlot(data))
        case .vennDiagram:
            guard let data = decode(VennDiagramData.self) else { return nil }
            return InsightVisual(type: type, title: title, payload: .vennDiagram(data))
        case .ganttChart:
            guard let data = decode(GanttChartData.self) else { return nil }
            return InsightVisual(type: type, title: title, payload: .ganttChart(data))
        case .funnelDiagram:
            guard let data = decode(FunnelData.self) else { return nil }
            return InsightVisual(type: type, title: title, payload: .funnelDiagram(data))
        case .pyramidDiagram:
            guard let data = decode(PyramidData.self) else { return nil }
            return InsightVisual(type: type, title: title, payload: .pyramidDiagram(data))
        case .cycleDiagram:
            guard let data = decode(CycleData.self) else { return nil }
            return InsightVisual(type: type, title: title, payload: .cycleDiagram(data))
        case .fishboneDiagram:
            guard let data = decode(FishboneData.self) else { return nil }
            return InsightVisual(type: type, title: title, payload: .fishboneDiagram(data))
        case .swotMatrix:
            guard let data = decode(SWOTData.self) else { return nil }
            return InsightVisual(type: type, title: title, payload: .swotMatrix(data))
        case .sankeyDiagram:
            guard let data = decode(SankeyData.self) else { return nil }
            return InsightVisual(type: type, title: title, payload: .sankeyDiagram(data))
        case .treemap:
            guard let data = decode(TreemapData.self) else { return nil }
            return InsightVisual(type: type, title: title, payload: .treemap(data))
        case .heatmap:
            guard let data = decode(HeatmapData.self) else { return nil }
            return InsightVisual(type: type, title: title, payload: .heatmap(data))
        case .bubbleChart:
            guard let data = decode(BubbleChartData.self) else { return nil }
            return InsightVisual(type: type, title: title, payload: .bubbleChart(data))
        case .infographic:
            guard let data = decode(InfographicData.self) else { return nil }
            return InsightVisual(type: type, title: title, payload: .infographic(data))
        case .storyboard:
            guard let data = decode(StoryboardData.self) else { return nil }
            return InsightVisual(type: type, title: title, payload: .storyboard(data))
        case .journeyMap:
            guard let data = decode(JourneyMapData.self) else { return nil }
            return InsightVisual(type: type, title: title, payload: .journeyMap(data))
        case .barChartStacked:
            guard let data = decode(StackedBarChartData.self) else { return nil }
            return InsightVisual(type: type, title: title, payload: .barChartStacked(data))
        case .barChartGrouped:
            guard let data = decode(GroupedBarChartData.self) else { return nil }
            return InsightVisual(type: type, title: title, payload: .barChartGrouped(data))
        case .generic:
            return InsightVisual(type: type, title: title, payload: .generic(text))
        }
    }

    private static func parseLineFormat(type: InsightVisualType, title: String?, lines: [String]) -> InsightVisual? {
        let trimmed = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

        switch type {
        case .timeline:
            let events = trimmed.compactMap { line -> TimelineData.Event? in
                let parts = line.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                guard parts.count >= 2 else { return nil }
                let detail = parts[1].split(separator: "—", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                let titleText = detail.first ?? parts[1]
                let desc = detail.count > 1 ? detail[1] : nil
                return TimelineData.Event(date: parts[0], title: titleText, description: desc)
            }
            guard !events.isEmpty else { return nil }
            return InsightVisual(type: type, title: title, payload: .timeline(TimelineData(events: events)))

        case .flowchart:
            let nodes = trimmed.map { $0.replacingOccurrences(of: "→", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "-•")) }
                .filter { !$0.isEmpty }
            guard !nodes.isEmpty else { return nil }
            return InsightVisual(type: type, title: title, payload: .flowchart(FlowchartData(nodes: nodes)))

        case .comparisonMatrix:
            let tableLines = trimmed.filter { $0.contains("|") }
            guard tableLines.count >= 2 else { return nil }
            let header = tableLines[0].split(separator: "|").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            let rows = tableLines.dropFirst(1).compactMap { row -> [String]? in
                let cells = row.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                let joined = cells.joined()
                if !joined.isEmpty && joined.allSatisfy({ $0 == "-" }) {
                    return nil
                }
                return cells
            }
            guard !header.isEmpty else { return nil }
            return InsightVisual(type: type, title: title, payload: .comparison(ComparisonMatrixData(columns: header, rows: rows)))

        case .conceptMap:
            let centerLine = trimmed.first(where: { $0.lowercased().hasPrefix("central:") })
            let center = centerLine?.replacingOccurrences(of: "Central:", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespaces) ?? (trimmed.first ?? "")
            let branches = trimmed.filter { $0.contains("→") }.map {
                $0.components(separatedBy: "→").last?.trimmingCharacters(in: .whitespaces) ?? $0
            }
            guard !center.isEmpty else { return nil }
            return InsightVisual(type: type, title: title, payload: .conceptMap(ConceptMapData(center: center, branches: branches)))

        case .radarChart:
            guard !trimmed.isEmpty else { return nil }
            return InsightVisual(type: type, title: title, payload: .radar(RadarData(dimensions: trimmed)))

        case .hierarchy:
            guard let root = trimmed.first else { return nil }
            let children = Array(trimmed.dropFirst())
            return InsightVisual(type: type, title: title, payload: .hierarchy(HierarchyData(root: root, children: children)))

        case .networkGraph:
            var nodes: [NetworkGraphData.Node] = []
            var connections: [NetworkGraphData.Connection] = []
            for line in trimmed {
                if line.lowercased().hasPrefix("node:") {
                    let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                    let parts = payload.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespaces) }
                    if parts.count >= 2 {
                        nodes.append(NetworkGraphData.Node(id: parts[0], label: parts[1], type: parts.count > 2 ? parts[2] : nil))
                    }
                } else if line.lowercased().hasPrefix("link:") {
                    let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                    let parts = payload.components(separatedBy: "->")
                    if parts.count == 2 {
                        let left = parts[0].trimmingCharacters(in: .whitespaces)
                        let right = parts[1].trimmingCharacters(in: .whitespaces)
                        connections.append(NetworkGraphData.Connection(from: left, to: right, type: nil, strength: nil))
                    }
                }
            }
            guard !nodes.isEmpty else { return nil }
            return InsightVisual(type: type, title: title, payload: .network(NetworkGraphData(nodes: nodes, connections: connections)))

        case .barChart:
            let pairs = trimmed.compactMap { line -> (String, Double)? in
                let parts = line.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                guard parts.count == 2, let value = Double(parts[1]) else { return nil }
                return (parts[0], value)
            }
            guard !pairs.isEmpty else { return nil }
            return InsightVisual(type: type, title: title, payload: .barChart(BarChartData(labels: pairs.map { $0.0 }, values: pairs.map { $0.1 })))

        case .quadrant:
            var quadrants: [QuadrantData.Quadrant] = []
            var currentName: String?
            var items: [String] = []
            for line in trimmed {
                if line.lowercased().hasPrefix("quadrant:") {
                    if let name = currentName {
                        quadrants.append(QuadrantData.Quadrant(name: name, items: items))
                    }
                    currentName = line.dropFirst(9).trimmingCharacters(in: .whitespaces)
                    items = []
                } else {
                    items.append(line.replacingOccurrences(of: "•", with: "").trimmingCharacters(in: .whitespaces))
                }
            }
            if let name = currentName {
                quadrants.append(QuadrantData.Quadrant(name: name, items: items))
            }
            guard !quadrants.isEmpty else { return nil }
            return InsightVisual(type: type, title: title, payload: .quadrant(QuadrantData(axesX: nil, axesY: nil, quadrants: quadrants)))

        case .pieChart:
            let segments = trimmed.compactMap { line -> PieChartData.Segment? in
                let parts = line.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                guard parts.count == 2, let value = Double(parts[1]) else { return nil }
                return PieChartData.Segment(label: parts[0], value: value, color: nil)
            }
            guard !segments.isEmpty else { return nil }
            return InsightVisual(type: type, title: title, payload: .pieChart(PieChartData(segments: segments)))

        case .lineChart:
            let pairs = trimmed.compactMap { line -> (String, Double)? in
                let parts = line.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                guard parts.count == 2, let value = Double(parts[1]) else { return nil }
                return (parts[0], value)
            }
            guard !pairs.isEmpty else { return nil }
            return InsightVisual(type: type, title: title, payload: .lineChart(LineChartData(labels: pairs.map { $0.0 }, values: pairs.map { $0.1 })))

        case .areaChart:
            let pairs = trimmed.compactMap { line -> (String, Double)? in
                let parts = line.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                guard parts.count == 2, let value = Double(parts[1]) else { return nil }
                return (parts[0], value)
            }
            guard !pairs.isEmpty else { return nil }
            return InsightVisual(type: type, title: title, payload: .areaChart(AreaChartData(labels: pairs.map { $0.0 }, values: pairs.map { $0.1 })))

        case .scatterPlot:
            let points = trimmed.compactMap { line -> ScatterPlotData.Point? in
                let parts = line.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                guard parts.count >= 2,
                      let x = Double(parts[0]),
                      let y = Double(parts[1]) else { return nil }
                let label = parts.count > 2 ? parts[2] : nil
                return ScatterPlotData.Point(x: x, y: y, label: label)
            }
            guard !points.isEmpty else { return nil }
            return InsightVisual(type: type, title: title, payload: .scatterPlot(ScatterPlotData(points: points, xAxis: nil, yAxis: nil)))

        case .vennDiagram:
            var sets: [VennDiagramData.Set] = []
            var intersection: [String] = []
            for line in trimmed {
                if line.lowercased().hasPrefix("intersection:") {
                    let items = line.dropFirst(13).split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    intersection = items
                } else if let colonIndex = line.firstIndex(of: ":") {
                    let name = line[..<colonIndex].trimmingCharacters(in: .whitespaces)
                    let items = line[line.index(after: colonIndex)...]
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                    sets.append(VennDiagramData.Set(label: String(name), items: items))
                }
            }
            guard !sets.isEmpty else { return nil }
            return InsightVisual(type: type, title: title, payload: .vennDiagram(VennDiagramData(sets: sets, intersection: intersection)))

        case .ganttChart:
            let tasks = trimmed.compactMap { line -> GanttChartData.Task? in
                let parts = line.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespaces) }
                guard parts.count >= 3,
                      let start = Double(parts[1]),
                      let duration = Double(parts[2]) else { return nil }
                let status = parts.count > 3 ? parts[3] : nil
                return GanttChartData.Task(name: parts[0], start: start, duration: duration, status: status)
            }
            guard !tasks.isEmpty else { return nil }
            return InsightVisual(type: type, title: title, payload: .ganttChart(GanttChartData(tasks: tasks)))

        case .funnelDiagram:
            let stages = trimmed.compactMap { line -> FunnelData.Stage? in
                let parts = line.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                guard parts.count == 2, let value = Double(parts[1]) else { return nil }
                return FunnelData.Stage(label: parts[0], value: value)
            }
            guard !stages.isEmpty else { return nil }
            return InsightVisual(type: type, title: title, payload: .funnelDiagram(FunnelData(stages: stages)))

        case .pyramidDiagram:
            let levels = trimmed.map { PyramidData.Level(label: $0, description: nil) }
            guard !levels.isEmpty else { return nil }
            return InsightVisual(type: type, title: title, payload: .pyramidDiagram(PyramidData(levels: levels)))

        case .cycleDiagram:
            guard !trimmed.isEmpty else { return nil }
            return InsightVisual(type: type, title: title, payload: .cycleDiagram(CycleData(stages: trimmed)))

        case .fishboneDiagram:
            var effect: String?
            var causes: [FishboneData.Cause] = []
            for line in trimmed {
                if line.lowercased().hasPrefix("effect:") {
                    effect = String(line.dropFirst(7)).trimmingCharacters(in: .whitespaces)
                } else if let colonIndex = line.firstIndex(of: ":") {
                    let category = line[..<colonIndex].trimmingCharacters(in: .whitespaces)
                    let items = line[line.index(after: colonIndex)...]
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                    causes.append(FishboneData.Cause(category: String(category), items: items))
                }
            }
            guard let finalEffect = effect else { return nil }
            return InsightVisual(type: type, title: title, payload: .fishboneDiagram(FishboneData(effect: finalEffect, causes: causes)))

        case .swotMatrix:
            func readSection(prefix: String) -> [String] {
                trimmed
                    .filter { $0.lowercased().hasPrefix(prefix) }
                    .flatMap { line in
                        line.dropFirst(prefix.count).split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    }
            }
            let strengths = readSection(prefix: "strengths:")
            let weaknesses = readSection(prefix: "weaknesses:")
            let opportunities = readSection(prefix: "opportunities:")
            let threats = readSection(prefix: "threats:")
            guard !strengths.isEmpty || !weaknesses.isEmpty || !opportunities.isEmpty || !threats.isEmpty else { return nil }
            return InsightVisual(type: type, title: title, payload: .swotMatrix(SWOTData(strengths: strengths, weaknesses: weaknesses, opportunities: opportunities, threats: threats)))

        case .sankeyDiagram:
            let flows = trimmed.compactMap { line -> SankeyData.Flow? in
                let parts = line.components(separatedBy: "->")
                guard parts.count == 2 else { return nil }
                let left = parts[0].trimmingCharacters(in: .whitespaces)
                let rightParts = parts[1].split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                guard rightParts.count == 2, let value = Double(rightParts[1]) else { return nil }
                return SankeyData.Flow(from: left, to: rightParts[0], value: value)
            }
            guard !flows.isEmpty else { return nil }
            return InsightVisual(type: type, title: title, payload: .sankeyDiagram(SankeyData(flows: flows)))

        case .treemap:
            let items = trimmed.compactMap { line -> TreemapData.Item? in
                let parts = line.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                guard parts.count == 2, let value = Double(parts[1]) else { return nil }
                return TreemapData.Item(label: parts[0], value: value)
            }
            guard !items.isEmpty else { return nil }
            return InsightVisual(type: type, title: title, payload: .treemap(TreemapData(items: items)))

        case .heatmap:
            guard let header = trimmed.first else { return nil }
            let cols = header.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            var rows: [String] = []
            var values: [[Double]] = []
            for line in trimmed.dropFirst() {
                let parts = line.split(separator: ":").map { String($0).trimmingCharacters(in: .whitespaces) }
                guard parts.count == 2 else { continue }
                rows.append(parts[0])
                let rowValues = parts[1].split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
                values.append(rowValues)
            }
            guard !rows.isEmpty else { return nil }
            return InsightVisual(type: type, title: title, payload: .heatmap(HeatmapData(rows: rows, cols: cols, values: values)))

        case .bubbleChart:
            let bubbles = trimmed.compactMap { line -> BubbleChartData.Bubble? in
                let parts = line.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                guard parts.count >= 4,
                      let x = Double(parts[1]),
                      let y = Double(parts[2]),
                      let size = Double(parts[3]) else { return nil }
                return BubbleChartData.Bubble(label: parts[0], x: x, y: y, size: size)
            }
            guard !bubbles.isEmpty else { return nil }
            return InsightVisual(type: type, title: title, payload: .bubbleChart(BubbleChartData(bubbles: bubbles)))

        case .infographic:
            var titleValue = title ?? "Key Figures"
            var stats: [InfographicData.Stat] = []
            var highlights: [String] = []
            for line in trimmed {
                if line.lowercased().hasPrefix("title:") {
                    titleValue = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                } else if line.lowercased().hasPrefix("stat:") {
                    let parts = line.dropFirst(5).split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                    if parts.count == 2 {
                        stats.append(InfographicData.Stat(label: parts[0], value: parts[1]))
                    }
                } else if line.lowercased().hasPrefix("highlight:") {
                    highlights.append(String(line.dropFirst(10)).trimmingCharacters(in: .whitespaces))
                }
            }
            return InsightVisual(type: type, title: titleValue, payload: .infographic(InfographicData(title: titleValue, stats: stats, highlights: highlights)))

        case .storyboard:
            let scenes = trimmed.compactMap { line -> StoryboardData.Scene? in
                let parts = line.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                guard parts.count == 2 else { return nil }
                let detail = parts[1].split(separator: "—", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                let title = detail.first ?? parts[1]
                let desc = detail.count > 1 ? detail[1] : ""
                return StoryboardData.Scene(title: title, description: desc, number: nil)
            }
            guard !scenes.isEmpty else { return nil }
            return InsightVisual(type: type, title: title, payload: .storyboard(StoryboardData(scenes: scenes)))

        case .journeyMap:
            var stages: [JourneyMapData.Stage] = []
            var currentName: String?
            var currentEmotion: String?
            var touchpoints: [String] = []
            for line in trimmed {
                if line.lowercased().hasPrefix("stage:") {
                    if let name = currentName {
                        stages.append(JourneyMapData.Stage(name: name, touchpoints: touchpoints, emotion: currentEmotion))
                    }
                    let parts = line.dropFirst(6).split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                    currentName = parts.first
                    currentEmotion = parts.count > 1 ? parts[1].lowercased() : nil
                    touchpoints = []
                } else {
                    touchpoints.append(line.replacingOccurrences(of: "•", with: "").trimmingCharacters(in: .whitespaces))
                }
            }
            if let name = currentName {
                stages.append(JourneyMapData.Stage(name: name, touchpoints: touchpoints, emotion: currentEmotion))
            }
            guard !stages.isEmpty else { return nil }
            return InsightVisual(type: type, title: title, payload: .journeyMap(JourneyMapData(stages: stages)))

        case .barChartStacked:
            return nil
        case .barChartGrouped:
            return nil
        case .generic:
            return InsightVisual(type: type, title: title, payload: .generic(lines.joined(separator: "\n")))
        }
    }
}

// MARK: - View

struct InsightVisualView: View {
    let visual: InsightVisual

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            if let title = visual.title, !title.isEmpty {
                Text(title)
                    .font(.analysisUIBold())
                    .foregroundColor(AnalysisTheme.textHeading)
            }

            switch visual.payload {
            case .timeline(let data):
                TimelineCardView(data: data)
            case .flowchart(let data):
                FlowDiagramCardView(data: data)
            case .comparison(let data):
                ComparisonMatrixCardView(data: data)
            case .conceptMap(let data):
                ConceptMapCardView(data: data)
            case .radar(let data):
                RadarCardView(data: data)
            case .hierarchy(let data):
                HierarchyCardView(data: data)
            case .network(let data):
                NetworkCardView(data: data)
            case .barChart(let data):
                BarChartCardView(data: data)
            case .quadrant(let data):
                QuadrantCardView(data: data)
            case .pieChart(let data):
                PieChartCardView(data: data)
            case .lineChart(let data):
                LineChartCardView(data: data)
            case .areaChart(let data):
                AreaChartCardView(data: data)
            case .scatterPlot(let data):
                ScatterPlotCardView(data: data)
            case .vennDiagram(let data):
                VennDiagramCardView(data: data)
            case .ganttChart(let data):
                GanttChartCardView(data: data)
            case .funnelDiagram(let data):
                FunnelCardView(data: data)
            case .pyramidDiagram(let data):
                PyramidCardView(data: data)
            case .cycleDiagram(let data):
                CycleCardView(data: data)
            case .fishboneDiagram(let data):
                FishboneCardView(data: data)
            case .swotMatrix(let data):
                SWOTCardView(data: data)
            case .sankeyDiagram(let data):
                SankeyCardView(data: data)
            case .treemap(let data):
                TreemapCardView(data: data)
            case .heatmap(let data):
                HeatmapCardView(data: data)
            case .bubbleChart(let data):
                BubbleChartCardView(data: data)
            case .infographic(let data):
                InfographicCardView(data: data)
            case .storyboard(let data):
                StoryboardCardView(data: data)
            case .journeyMap(let data):
                JourneyMapCardView(data: data)
            case .barChartStacked(let data):
                StackedBarChartCardView(data: data)
            case .barChartGrouped(let data):
                GroupedBarChartCardView(data: data)
            case .generic(let data):
                GenericVisualCardView(data: data)
            }
        }
        .padding(AnalysisTheme.Spacing.lg)
        .background(AnalysisTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: AnalysisTheme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.lg)
                .stroke(AnalysisTheme.primaryGoldMuted, lineWidth: 1)
        )
        .shadow(color: AnalysisTheme.shadowCard, radius: 4, x: 0, y: 2)
    }
}

// MARK: - Visual Card Views

private struct VisualHeader: View {
    let label: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(AnalysisTheme.primaryGold)
            Text(label.uppercased())
                .font(.analysisUISmall())
                .foregroundColor(AnalysisTheme.textMuted)
                .tracking(1)
        }
    }
}

private struct TimelineCardView: View {
    let data: TimelineData

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            VisualHeader(label: "Timeline", icon: "calendar")
            ForEach(data.events) { event in
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(AnalysisTheme.primaryGold)
                        .frame(width: 8, height: 8)
                        .padding(.top, 6)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(event.date): \(event.title)")
                            .font(.analysisUIBold())
                            .foregroundColor(AnalysisTheme.textHeading)
                        if let description = event.description, !description.isEmpty {
                            Text(description)
                                .font(.analysisBody())
                                .foregroundColor(AnalysisTheme.textBody)
                        }
                    }
                }
            }
        }
    }
}

private struct FlowDiagramCardView: View {
    let data: FlowchartData

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            VisualHeader(label: "Process Flow", icon: "arrow.triangle.branch")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(data.nodes.enumerated()), id: \.offset) { index, node in
                        HStack(spacing: 8) {
                            Text(node)
                                .font(.analysisUIBold())
                                .foregroundColor(AnalysisTheme.textHeading)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(AnalysisTheme.bgSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            if index < data.nodes.count - 1 {
                                Image(systemName: "arrow.right")
                                    .foregroundColor(AnalysisTheme.primaryGoldMuted)
                            }
                        }
                    }
                }
                .padding(.bottom, 2)
            }
        }
    }
}

private struct ComparisonMatrixCardView: View {
    let data: ComparisonMatrixData

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            VisualHeader(label: "Comparison", icon: "square.grid.2x2")
            ComparisonTableView(headers: data.columns, rows: data.rows)
        }
    }
}

private struct ConceptMapCardView: View {
    let data: ConceptMapData

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            VisualHeader(label: "Concept Map", icon: "point.3.connected.trianglepath.dotted")
            ConceptMapView(centralConcept: data.center, connections: data.branches.map { ($0, "relates to") })
        }
    }
}

private struct RadarCardView: View {
    let data: RadarData

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            VisualHeader(label: "Assessment Dimensions", icon: "scope")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AnalysisTheme.Spacing.md) {
                ForEach(data.dimensions, id: \.self) { dimension in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(dimension)
                            .font(.analysisUIBold())
                            .foregroundColor(AnalysisTheme.textHeading)
                        Capsule()
                            .fill(AnalysisTheme.primaryGold.opacity(0.3))
                            .frame(height: 6)
                            .overlay(
                                Capsule()
                                    .fill(AnalysisTheme.primaryGold)
                                    .frame(width: 60, height: 6),
                                alignment: .leading
                            )
                    }
                    .padding(AnalysisTheme.Spacing.sm)
                    .background(AnalysisTheme.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

private struct HierarchyCardView: View {
    let data: HierarchyData

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            VisualHeader(label: "Hierarchy", icon: "list.bullet.indent")
            VStack(spacing: AnalysisTheme.Spacing.sm) {
                Text(data.root)
                    .font(.analysisUIBold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AnalysisTheme.primaryGold)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                ForEach(data.children, id: \.self) { child in
                    Text(child)
                        .font(.analysisUI())
                        .foregroundColor(AnalysisTheme.textHeading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AnalysisTheme.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

private struct NetworkCardView: View {
    let data: NetworkGraphData

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            VisualHeader(label: "Network Graph", icon: "person.3")
            FlowLayout(alignment: .leading, spacing: 8) {
                ForEach(data.nodes) { node in
                    VStack(spacing: 2) {
                        Text(node.label)
                            .font(.analysisUIBold())
                            .foregroundColor(AnalysisTheme.textHeading)
                        if let type = node.type {
                            Text(type.uppercased())
                                .font(.analysisUISmall())
                                .foregroundColor(AnalysisTheme.textMuted)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AnalysisTheme.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("RELATIONSHIPS")
                    .font(.analysisUISmall())
                    .foregroundColor(AnalysisTheme.textMuted)
                    .tracking(1)
                ForEach(data.connections) { connection in
                    HStack(spacing: 8) {
                        Text(connection.from)
                            .font(.analysisUI())
                        Image(systemName: "arrow.right")
                            .foregroundColor(AnalysisTheme.primaryGoldMuted)
                        Text(connection.to)
                            .font(.analysisUI())
                        if let type = connection.type {
                            Text(type)
                                .font(.analysisUISmall())
                                .foregroundColor(AnalysisTheme.textMuted)
                        }
                    }
                }
            }
        }
    }
}

private struct BarChartCardView: View {
    let data: BarChartData

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            VisualHeader(label: "Bar Chart", icon: "chart.bar")
            let maxValue = (data.values.max() ?? 1)
            let count = min(data.labels.count, data.values.count)
            ForEach(0..<count, id: \.self) { index in
                let label = data.labels[index]
                HStack(spacing: 12) {
                    Text(label)
                        .font(.analysisUI())
                        .foregroundColor(AnalysisTheme.textHeading)
                        .frame(width: 100, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(AnalysisTheme.bgSecondary)
                            RoundedRectangle(cornerRadius: 6)
                                .fill(AnalysisTheme.primaryGold)
                                .frame(width: geo.size.width * CGFloat(data.values[index] / maxValue))
                        }
                    }
                    .frame(height: 12)
                    Text(String(format: "%.0f", data.values[index]))
                        .font(.analysisUISmall())
                        .foregroundColor(AnalysisTheme.textMuted)
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
    }
}

private struct QuadrantCardView: View {
    let data: QuadrantData

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            VisualHeader(label: "Quadrant", icon: "square.split.2x2")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AnalysisTheme.Spacing.md) {
                ForEach(Array(data.quadrants.enumerated()), id: \.offset) { _, quadrant in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(quadrant.name.uppercased())
                            .font(.analysisUISmall())
                            .foregroundColor(AnalysisTheme.textMuted)
                            .tracking(0.5)
                        ForEach(quadrant.items, id: \.self) { item in
                            Text("• \(item)")
                                .font(.analysisUI())
                                .foregroundColor(AnalysisTheme.textHeading)
                        }
                    }
                    .padding(AnalysisTheme.Spacing.sm)
                    .background(AnalysisTheme.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

private struct PieChartCardView: View {
    let data: PieChartData

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            VisualHeader(label: "Distribution", icon: "chart.pie")
            let total = data.segments.map { $0.value }.reduce(0, +)
            ForEach(Array(data.segments.enumerated()), id: \.offset) { index, segment in
                HStack(spacing: 10) {
                    Circle()
                        .fill(colorForIndex(index))
                        .frame(width: 10, height: 10)
                    Text(segment.label)
                        .font(.analysisUI())
                    Spacer()
                    Text(String(format: "%.1f%%", total > 0 ? (segment.value / total) * 100 : 0))
                        .font(.analysisUISmall())
                        .foregroundColor(AnalysisTheme.textMuted)
                }
            }
        }
    }
}

private struct LineChartCardView: View {
    let data: LineChartData

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            VisualHeader(label: "Trend", icon: "chart.line.uptrend.xyaxis")
            TrendBarRow(labels: data.labels, values: data.values, color: AnalysisTheme.primaryGold)
        }
    }
}

private struct AreaChartCardView: View {
    let data: AreaChartData

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            VisualHeader(label: "Cumulative Trend", icon: "chart.area")
            TrendBarRow(labels: data.labels, values: data.values, color: AnalysisTheme.primaryGoldLight)
        }
    }
}

private struct ScatterPlotCardView: View {
    let data: ScatterPlotData

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            VisualHeader(label: "Correlation", icon: "circle.grid.cross")
            GeometryReader { geo in
                let width = max(1, geo.size.width)
                let height = max(1, geo.size.height)
                ZStack(alignment: .bottomLeading) {
                    Rectangle()
                        .stroke(AnalysisTheme.primaryGoldMuted, lineWidth: 1)
                    ForEach(data.points) { point in
                        Circle()
                            .fill(AnalysisTheme.primaryGold)
                            .frame(width: 8, height: 8)
                            .position(
                                x: CGFloat(point.x) / 100.0 * width,
                                y: height - CGFloat(point.y) / 100.0 * height
                            )
                    }
                }
            }
            .frame(height: 160)
        }
    }
}

private struct VennDiagramCardView: View {
    let data: VennDiagramData

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            VisualHeader(label: "Venn Diagram", icon: "circlebadge.2")
            HStack(spacing: -12) {
                VennCircle(label: data.sets.first?.label ?? "", items: data.sets.first?.items ?? [])
                VennCircle(label: data.sets.dropFirst().first?.label ?? "", items: data.sets.dropFirst().first?.items ?? [])
            }
            if !data.intersection.isEmpty {
                Text("Intersection: \(data.intersection.joined(separator: ", "))")
                    .font(.analysisUISmall())
                    .foregroundColor(AnalysisTheme.textMuted)
            }
        }
    }
}

private struct GanttChartCardView: View {
    let data: GanttChartData

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            VisualHeader(label: "Timeline", icon: "calendar")
            ForEach(data.tasks) { task in
                HStack(spacing: 10) {
                    Text(task.name)
                        .font(.analysisUI())
                        .frame(width: 120, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(AnalysisTheme.bgSecondary)
                            RoundedRectangle(cornerRadius: 6)
                                .fill(task.status == "complete" ? AnalysisTheme.accentTeal : AnalysisTheme.primaryGold)
                                .frame(
                                    width: geo.size.width * CGFloat(task.duration / 100.0)
                                )
                                .offset(x: geo.size.width * CGFloat(task.start / 100.0))
                        }
                    }
                    .frame(height: 12)
                }
            }
        }
    }
}

private struct FunnelCardView: View {
    let data: FunnelData

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            VisualHeader(label: "Funnel", icon: "line.3.horizontal.decrease.circle")
            let maxValue = data.stages.first?.value ?? 1
            ForEach(data.stages.indices, id: \.self) { index in
                let stage = data.stages[index]
                let width = max(0.4, stage.value / maxValue)
                Text("\(stage.label) (\(Int(stage.value)))")
                    .font(.analysisUIBold())
                    .foregroundColor(.white)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(AnalysisTheme.primaryGold.opacity(0.7))
                    .frame(width: CGFloat(width) * 250, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct PyramidCardView: View {
    let data: PyramidData

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            VisualHeader(label: "Pyramid", icon: "triangle")
            ForEach(Array(data.levels.enumerated()), id: \.offset) { index, level in
                let width = min(1.0, 0.4 + Double(index) * 0.15)
                Text(level.label)
                    .font(.analysisUIBold())
                    .foregroundColor(.white)
                    .padding(.vertical, 6)
                    .frame(width: CGFloat(width) * 250)
                    .background(AnalysisTheme.primaryGold)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}

private struct CycleCardView: View {
    let data: CycleData

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            VisualHeader(label: "Cycle", icon: "arrow.triangle.2.circlepath")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(data.stages.enumerated()), id: \.offset) { index, stage in
                        HStack(spacing: 6) {
                            Text(stage)
                                .font(.analysisUIBold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AnalysisTheme.bgSecondary)
                                .clipShape(Capsule())
                            if index < data.stages.count - 1 {
                                Image(systemName: "arrow.right")
                                    .foregroundColor(AnalysisTheme.primaryGoldMuted)
                            }
                        }
                    }
                }
                .padding(.bottom, 2)
            }
        }
    }
}

private struct FishboneCardView: View {
    let data: FishboneData

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            VisualHeader(label: "Cause & Effect", icon: "fish")
            Text("Effect: \(data.effect)")
                .font(.analysisUIBold())
                .foregroundColor(AnalysisTheme.textHeading)
            ForEach(data.causes, id: \.category) { cause in
                VStack(alignment: .leading, spacing: 4) {
                    Text(cause.category.uppercased())
                        .font(.analysisUISmall())
                        .foregroundColor(AnalysisTheme.textMuted)
                    Text(cause.items.joined(separator: ", "))
                        .font(.analysisUI())
                        .foregroundColor(AnalysisTheme.textHeading)
                }
            }
        }
    }
}

private struct SWOTCardView: View {
    let data: SWOTData

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            VisualHeader(label: "SWOT", icon: "target")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AnalysisTheme.Spacing.md) {
                SWOTCell(title: "Strengths", items: data.strengths, color: AnalysisTheme.accentTeal)
                SWOTCell(title: "Weaknesses", items: data.weaknesses, color: AnalysisTheme.accentCoral)
                SWOTCell(title: "Opportunities", items: data.opportunities, color: AnalysisTheme.accentTeal)
                SWOTCell(title: "Threats", items: data.threats, color: AnalysisTheme.accentOrange)
            }
        }
    }
}

private struct SankeyCardView: View {
    let data: SankeyData

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            VisualHeader(label: "Flow", icon: "arrow.left.arrow.right")
            ForEach(Array(data.flows.enumerated()), id: \.offset) { _, flow in
                HStack(spacing: 8) {
                    Text(flow.from)
                        .font(.analysisUI())
                    Image(systemName: "arrow.right")
                        .foregroundColor(AnalysisTheme.primaryGoldMuted)
                    Text(flow.to)
                        .font(.analysisUI())
                    Spacer()
                    Text(String(format: "%.0f", flow.value))
                        .font(.analysisUISmall())
                        .foregroundColor(AnalysisTheme.textMuted)
                }
                .padding(AnalysisTheme.Spacing.sm)
                .background(AnalysisTheme.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

private struct TreemapCardView: View {
    let data: TreemapData

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            VisualHeader(label: "Treemap", icon: "square.grid.3x2")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AnalysisTheme.Spacing.sm) {
                ForEach(data.items) { item in
                    VStack(spacing: 4) {
                        Text(item.label)
                            .font(.analysisUIBold())
                            .foregroundColor(.white)
                        Text(String(format: "%.0f", item.value))
                            .font(.analysisUISmall())
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(AnalysisTheme.Spacing.sm)
                    .background(AnalysisTheme.primaryGold)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

private struct HeatmapCardView: View {
    let data: HeatmapData

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            VisualHeader(label: "Heatmap", icon: "flame")
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("")
                            .frame(width: 80)
                        ForEach(data.cols, id: \.self) { col in
                            Text(col)
                                .font(.analysisUISmall())
                                .frame(width: 50)
                        }
                    }
                    let paired = Array(zip(data.rows, data.values))
                    ForEach(paired.indices, id: \.self) { rowIndex in
                        let row = paired[rowIndex].0
                        let rowValues = paired[rowIndex].1
                        HStack {
                            Text(row)
                                .font(.analysisUISmall())
                                .frame(width: 80, alignment: .leading)
                            let cellCount = min(rowValues.count, data.cols.count)
                            ForEach(0..<cellCount, id: \.self) { valueIndex in
                                let value = rowValues[valueIndex]
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(AnalysisTheme.primaryGold.opacity(min(1.0, value / 10.0)))
                                    .frame(width: 50, height: 30)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct BubbleChartCardView: View {
    let data: BubbleChartData

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            VisualHeader(label: "Bubble Chart", icon: "circle.grid.2x2")
            GeometryReader { geo in
                let width = max(1, geo.size.width)
                let height = max(1, geo.size.height)
                ZStack {
                    ForEach(data.bubbles) { bubble in
                        Circle()
                            .fill(AnalysisTheme.primaryGold.opacity(0.6))
                            .frame(width: bubble.size * 10, height: bubble.size * 10)
                            .position(
                                x: CGFloat(bubble.x) / 100.0 * width,
                                y: height - CGFloat(bubble.y) / 100.0 * height
                            )
                    }
                }
            }
            .frame(height: 160)
        }
    }
}

private struct InfographicCardView: View {
    let data: InfographicData

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            VisualHeader(label: data.title, icon: "doc.text.image")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AnalysisTheme.Spacing.md) {
                ForEach(Array(data.stats.enumerated()), id: \.offset) { _, stat in
                    VStack(spacing: 4) {
                        Text(stat.value)
                            .font(.analysisDisplayH2())
                            .foregroundColor(AnalysisTheme.primaryGold)
                        Text(stat.label)
                            .font(.analysisUISmall())
                            .foregroundColor(AnalysisTheme.textMuted)
                    }
                    .padding(AnalysisTheme.Spacing.sm)
                    .background(AnalysisTheme.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Highlights")
                    .font(.analysisUIBold())
                    .foregroundColor(AnalysisTheme.textHeading)
                ForEach(data.highlights, id: \.self) { highlight in
                    Text("• \(highlight)")
                        .font(.analysisUI())
                        .foregroundColor(AnalysisTheme.textBody)
                }
            }
        }
    }
}

private struct StoryboardCardView: View {
    let data: StoryboardData

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            VisualHeader(label: "Storyboard", icon: "film")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AnalysisTheme.Spacing.md) {
                ForEach(data.scenes) { scene in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(scene.title)
                            .font(.analysisUIBold())
                            .foregroundColor(AnalysisTheme.textHeading)
                        Text(scene.description)
                            .font(.analysisUISmall())
                            .foregroundColor(AnalysisTheme.textBody)
                    }
                    .padding(AnalysisTheme.Spacing.sm)
                    .background(AnalysisTheme.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

private struct JourneyMapCardView: View {
    let data: JourneyMapData

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            VisualHeader(label: "Journey Map", icon: "map")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(data.stages) { stage in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(stage.name)
                                .font(.analysisUIBold())
                                .foregroundColor(AnalysisTheme.textHeading)
                            ForEach(stage.touchpoints, id: \.self) { touchpoint in
                                Text("• \(touchpoint)")
                                    .font(.analysisUISmall())
                                    .foregroundColor(AnalysisTheme.textBody)
                            }
                        }
                        .padding(AnalysisTheme.Spacing.sm)
                        .background(AnalysisTheme.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }
}

private struct StackedBarChartCardView: View {
    let data: StackedBarChartData

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            VisualHeader(label: "Stacked Bars", icon: "chart.bar.fill")
            ForEach(data.labels.indices, id: \.self) { index in
                HStack {
                    Text(data.labels[index])
                        .font(.analysisUI())
                        .frame(width: 90, alignment: .leading)
                    HStack(spacing: 0) {
                        ForEach(data.series.indices, id: \.self) { seriesIndex in
                            let value = data.series[seriesIndex].indices.contains(index) ? data.series[seriesIndex][index] : 0
                            Rectangle()
                                .fill(colorForIndex(seriesIndex))
                                .frame(width: CGFloat(value) * 2, height: 12)
                        }
                    }
                }
            }
        }
    }
}

private struct GroupedBarChartCardView: View {
    let data: GroupedBarChartData

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            VisualHeader(label: "Grouped Bars", icon: "chart.bar.doc.horizontal")
            ForEach(data.labels.indices, id: \.self) { index in
                HStack {
                    Text(data.labels[index])
                        .font(.analysisUI())
                        .frame(width: 90, alignment: .leading)
                    ForEach(data.series.indices, id: \.self) { seriesIndex in
                        let value = data.series[seriesIndex].indices.contains(index) ? data.series[seriesIndex][index] : 0
                        Rectangle()
                            .fill(colorForIndex(seriesIndex))
                            .frame(width: CGFloat(value) * 2, height: 10)
                    }
                }
            }
        }
    }
}

private struct GenericVisualCardView: View {
    let data: String

    var body: some View {
        VStack(alignment: .center, spacing: AnalysisTheme.Spacing.md) {
            VisualHeader(label: "Visual", icon: "sparkles")
            if data == "Unable to render visual content" {
                VStack(spacing: 8) {
                    Image(systemName: "photo.artframe")
                        .font(.system(size: 32))
                        .foregroundColor(AnalysisTheme.textMuted)
                    Text("Visual content is being prepared")
                        .font(.analysisUI())
                        .foregroundColor(AnalysisTheme.textMuted)
                }
                .padding(.vertical, AnalysisTheme.Spacing.lg)
            } else {
                Text(data)
                    .font(.analysisUISmall())
                    .foregroundColor(AnalysisTheme.textBody)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TrendBarRow: View {
    let labels: [String]
    let values: [Double]
    let color: Color

    var body: some View {
        let maxValue = values.max() ?? 1
        let count = min(labels.count, values.count)
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                VStack(spacing: 4) {
                    Rectangle()
                        .fill(color)
                        .frame(height: CGFloat(values[index] / maxValue) * 80)
                    Text(labels[index])
                        .font(.analysisUISmall())
                        .foregroundColor(AnalysisTheme.textMuted)
                        .frame(width: 40)
                }
            }
        }
    }
}

private struct SWOTCell: View {
    let title: String
    let items: [String]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.analysisUISmall())
                .foregroundColor(color)
                .tracking(0.5)
            ForEach(items, id: \.self) { item in
                Text("• \(item)")
                    .font(.analysisUISmall())
                    .foregroundColor(AnalysisTheme.textBody)
            }
        }
        .padding(AnalysisTheme.Spacing.sm)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct VennCircle: View {
    let label: String
    let items: [String]

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.analysisUIBold())
                .foregroundColor(AnalysisTheme.textHeading)
            Text(items.prefix(2).joined(separator: ", "))
                .font(.analysisUISmall())
                .foregroundColor(AnalysisTheme.textMuted)
        }
        .padding(AnalysisTheme.Spacing.sm)
        .frame(width: 140, height: 140)
        .background(AnalysisTheme.bgSecondary.opacity(0.7))
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(AnalysisTheme.primaryGoldMuted, lineWidth: 1)
        )
    }
}

private func colorForIndex(_ index: Int) -> Color {
    let colors: [Color] = [
        AnalysisTheme.primaryGold,
        AnalysisTheme.accentTeal,
        AnalysisTheme.accentCoral,
        AnalysisTheme.accentOrange
    ]
    return colors[index % colors.count]
}

// MARK: - Flow Layout Helper

private struct FlowLayout: Layout {
    let alignment: HorizontalAlignment
    let spacing: CGFloat

    init(alignment: HorizontalAlignment = .leading, spacing: CGFloat = 8) {
        self.alignment = alignment
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 300
        var width: CGFloat = 0
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width + spacing > maxWidth {
                width = max(width, rowWidth)
                height += rowHeight + spacing
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
        }

        width = max(width, rowWidth)
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: size.width, height: size.height))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
