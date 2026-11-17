//
//  GuideHTMLExporter.swift
//  InsightAtlas
//  Extracted from DataManager — HTML export with no library state.
//

import Foundation
import UIKit

enum GuideHTMLExporter {
// MARK: - HTML Conversion Helpers

static func detectBlockStart(_ line: String) -> String? {
    let blockStarts: [(String, String)] = [
        ("[QUICK_GLANCE]", "quick-glance"),
        ("[INSIGHT_NOTE]", "insight-note"),
        ("[ALTERNATIVE_PERSPECTIVE]", "alternative-perspective"),
        ("[RESEARCH_INSIGHT]", "research-insight"),
        ("[ACTION_BOX", "action-box"),
        ("[QUOTE]", "quote"),
        ("[VISUAL_FLOWCHART", "visual-flowchart"),
        ("[VISUAL_TABLE", "visual-table"),
        ("[PROCESS_TIMELINE]", "process-timeline"),
        ("[CONCEPT_MAP]", "concept-map"),
        ("[EXERCISE_", "exercise"),
        ("[FOUNDATIONAL_NARRATIVE]", "foundational-narrative"),
        ("[STRUCTURE_MAP]", "structure-map"),
        ("[TAKEAWAYS]", "takeaways"),
        // Premium block types
        ("[PREMIUM_QUOTE]", "premium-quote"),
        ("[AUTHOR_SPOTLIGHT]", "author-spotlight"),
        ("[PREMIUM_DIVIDER]", "premium-divider"),
        ("[PREMIUM_H1]", "premium-h1"),
        ("[PREMIUM_H2]", "premium-h2")
    ]
    for (marker, type) in blockStarts {
        if line.hasPrefix(marker) {
            return type
        }
    }

    if line.hasPrefix("[VISUAL_"),
       !line.hasPrefix("[VISUAL_FLOWCHART"),
       !line.hasPrefix("[VISUAL_TABLE") {
        let inner = line.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        let tag = inner.split(separator: ":", maxSplits: 1).first.map(String.init)
        return tag
    }
    return nil
}

/// The title in a `[VISUAL_X: Some Title]` opening marker, if any.
///
/// `detectBlockStart` returns the type alone, so the export used to drop
/// every visual title — the same guide showed titled visuals in the reader
/// and the PDF but untitled ones in exported HTML.
static func detectBlockTitle(_ line: String) -> String? {
    guard line.hasPrefix("["), let close = line.firstIndex(of: "]") else { return nil }
    let inner = line[line.index(after: line.startIndex)..<close]
    guard let colon = inner.firstIndex(of: ":") else { return nil }
    let title = inner[inner.index(after: colon)...]
        .trimmingCharacters(in: .whitespaces)
    return title.isEmpty ? nil : title
}

static func detectBlockEnd(_ line: String) -> Bool {
    if line.hasPrefix("[/VISUAL_") {
        return true
    }
    let endMarkers = ["[/QUICK_GLANCE]", "[/INSIGHT_NOTE]", "[/ACTION_BOX]", "[/QUOTE]",
                      "[/VISUAL_FLOWCHART]", "[/VISUAL_TABLE]", "[/EXERCISE_",
                      "[/FOUNDATIONAL_NARRATIVE]", "[/STRUCTURE_MAP]", "[/TAKEAWAYS]",
                      "[/PROCESS_TIMELINE]", "[/CONCEPT_MAP]",
                      // Premium block end markers
                      "[/PREMIUM_QUOTE]", "[/AUTHOR_SPOTLIGHT]", "[/PREMIUM_DIVIDER]",
                      "[/PREMIUM_H1]", "[/PREMIUM_H2]",
                      // Additional note box types
                      "[/ALTERNATIVE_PERSPECTIVE]", "[/RESEARCH_INSIGHT]"]
    return endMarkers.contains { line.hasPrefix($0) }
}

/// Validation result for markdown content
struct MarkdownValidationResult {
    let isValid: Bool
    let unclosedBlocks: [String]
    let unmatchedEndMarkers: [String]
    let warnings: [String]
}

/// Validates markdown content for proper block marker matching
func validateMarkdown(_ content: String) -> MarkdownValidationResult {
    var openBlocks: [(type: String, line: Int)] = []
    var unmatchedEndMarkers: [String] = []
    var warnings: [String] = []

    let lines = content.components(separatedBy: .newlines)

    for (index, line) in lines.enumerated() {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let lineNumber = index + 1

        if let blockType = detectBlockStart(trimmed) {
            openBlocks.append((type: blockType, line: lineNumber))
        }

        if detectBlockEnd(trimmed) {
            if openBlocks.isEmpty {
                unmatchedEndMarkers.append("Line \(lineNumber): \(trimmed)")
            } else {
                openBlocks.removeLast()
            }
        }
    }

    let unclosedBlocks = openBlocks.map { "'\($0.type)' opened at line \($0.line)" }

    if !unclosedBlocks.isEmpty {
        warnings.append("Found \(unclosedBlocks.count) unclosed block(s)")
    }
    if !unmatchedEndMarkers.isEmpty {
        warnings.append("Found \(unmatchedEndMarkers.count) unmatched end marker(s)")
    }

    return MarkdownValidationResult(
        isValid: unclosedBlocks.isEmpty && unmatchedEndMarkers.isEmpty,
        unclosedBlocks: unclosedBlocks,
        unmatchedEndMarkers: unmatchedEndMarkers,
        warnings: warnings
    )
}

static func renderSpecialBlock(
    type: String,
    content: [String],
    fullContent: String = "",
    blockTitle: String? = nil
) -> String {
    let processedContent = content
        .filter { !$0.isEmpty }
        .map { convertInlineMarkdown($0) }

    let headers: [String: (icon: String, title: String)] = [
        "quick-glance": ("👁", "QUICK GLANCE"),
        "insight-note": ("💡", "INSIGHT ATLAS NOTE"),
        "alternative-perspective": ("⚖️", "ALTERNATIVE PERSPECTIVE"),
        "research-insight": ("🔬", "RESEARCH INSIGHT"),
        "action-box": ("✓", "APPLY IT"),
        "visual-flowchart": ("📊", "VISUAL GUIDE"),
        "visual-table": ("📋", "REFERENCE TABLE"),
        "process-timeline": ("⟶", "PROCESS TIMELINE"),
        "concept-map": ("🗺️", "CONCEPT MAP"),
        "exercise": ("✏️", "EXERCISE"),
        "foundational-narrative": ("📖", "THE STORY BEHIND THE IDEAS"),
        "structure-map": ("🗺️", "STRUCTURE MAP"),
        "takeaways": ("⭐", "KEY TAKEAWAYS")
    ]

    if type == "quote" {
        return "<blockquote>\(processedContent.joined(separator: "<br>"))</blockquote>"
    }

    // Handle premium block types with special rendering
    if type == "premium-quote" {
        return renderPremiumQuoteHTML(content: content)
    }
    if type == "author-spotlight" {
        return renderAuthorSpotlightHTML(content: content)
    }
    if type == "premium-divider" {
        return renderPremiumDividerHTML()
    }
    if type == "premium-h1" {
        let title = content.first ?? ""
        return renderPremiumH1HTML(title: title)
    }
    if type == "premium-h2" {
        let title = content.first ?? ""
        return renderPremiumH2HTML(title: title)
    }

    // Handle INSIGHT_NOTE with structured formatting
    if type == "insight-note" {
        return renderInsightNoteHTML(content: content)
    }

    if type.hasPrefix("VISUAL_") {
        return renderGenericVisualHTML(tag: type, content: content, title: blockTitle)
    }

    var header = headers[type] ?? ("", type.uppercased())
    // A titled marker names this specific block; the generic class label is
    // only a fallback for untitled ones.
    if let blockTitle {
        header.title = escapeHTML(blockTitle)
    }
    var contentHTML: String

    if type == "visual-flowchart" {
        // For flowcharts, render as styled steps with arrows
        contentHTML = renderFlowchartContent(processedContent)
    } else if type == "process-timeline" {
        // For process timeline, render as numbered timeline steps
        contentHTML = renderProcessTimelineContent(processedContent)
    } else if type == "concept-map" {
        // For concept maps, render central concept with related nodes
        contentHTML = renderConceptMapContent(content.joined(separator: "\n"))
    } else if type == "structure-map" {
        // For structure maps, check if content contains table format
        let hasTable = content.contains { $0.hasPrefix("|") }
        if hasTable {
            contentHTML = renderStructureMapContent(content)
        } else {
            contentHTML = renderBlockContent(content)
        }
    } else if type == "visual-table" {
        // For tables within blocks, render as styled table
        contentHTML = renderBlockTableContent(processedContent)
    } else if type == "quick-glance" {
        // For Quick Glance, add dynamic reading time badge
        let readingTime = ExportBrandAssets.calculateReadingTime(from: fullContent)
        let badge = "<div class=\"reading-time-badge\">\(readingTime) min read</div>"
        contentHTML = badge + renderBlockContent(content)
        // Remove any hardcoded "Read time:" lines (both converted HTML and raw markdown versions)
        contentHTML = contentHTML.replacingOccurrences(of: "<p><em>Read time: \\d+ minutes?</em></p>", with: "", options: .regularExpression)
        contentHTML = contentHTML.replacingOccurrences(of: "<p>\\*Read time: \\d+ minutes?\\*</p>", with: "", options: .regularExpression)
    } else {
        // For other blocks, render as formatted paragraphs/lists
        contentHTML = renderBlockContent(content)
    }

    return """
    <div class="\(type)">
        <div class="block-header">\(header.icon) \(header.title)</div>
        <div class="block-content">\(contentHTML)</div>
    </div>
    """
}

static func renderGenericVisualHTML(
    tag: String,
    content: [String],
    title: String? = nil
) -> String {
    let canonicalTag = canonicalizeVisualTag(tag)
    guard let visual = InsightVisualParser.parse(tag: canonicalTag, title: title, lines: content) else {
        let fallbackBody = renderBlockContent(content)
        return """
        <div class="visual-generic">
            <div class="block-header">📌 VISUAL</div>
            <div class="block-content">\(fallbackBody)</div>
        </div>
        """
    }

    let header = visualHeader(for: visual.type)
    let body = renderVisualBodyHTML(for: visual)
    let containerClass = visualContainerClass(for: visual.type)
    // Show the visual's own title when it has one, matching the reader and
    // the PDF; the type label ("COMPARISON", "TIMELINE") is the fallback.
    let headerText = title.map { escapeHTML($0) } ?? header.title

    return """
    <div class="\(containerClass)">
        <div class="block-header">\(header.icon) \(headerText)</div>
        <div class="block-content">\(body)</div>
    </div>
    """
}

static func visualContainerClass(for type: InsightVisualType) -> String {
    switch type {
    case .flowchart:
        return "visual-flowchart"
    case .table:
        return "visual-table"
    case .timeline:
        return "visual-timeline"
    case .conceptMap:
        return "visual-concept-map"
    case .comparisonMatrix:
        return "visual-comparison"
    case .networkGraph:
        return "visual-network"
    case .quadrant:
        return "visual-quadrant"
    case .barChart, .barChartStacked, .barChartGrouped, .pieChart, .lineChart, .areaChart,
         .scatterPlot, .radarChart, .heatmap, .treemap, .bubbleChart:
        return "visual-chart"
    case .ganttChart, .funnelDiagram, .pyramidDiagram, .cycleDiagram, .fishboneDiagram,
         .swotMatrix, .sankeyDiagram, .hierarchy, .journeyMap, .storyboard, .infographic:
        return "visual-diagram"
    default:
        return "visual-generic"
    }
}

static func canonicalizeVisualTag(_ tag: String) -> String {
    InsightVisualParser.canonicalizeTag(tag)
}

static func visualHeader(for type: InsightVisualType) -> (icon: String, title: String) {
    switch type {
    case .spectrum: return ("↔️", "SPECTRUM")
    case .timeline: return ("📅", "TIMELINE")
    case .flowchart: return ("🔀", "PROCESS FLOW")
    case .comparisonMatrix: return ("📊", "COMPARISON")
    case .conceptMap: return ("🗺️", "CONCEPT MAP")
    case .radarChart: return ("🧭", "ASSESSMENT")
    case .hierarchy: return ("🧱", "HIERARCHY")
    case .networkGraph: return ("🧩", "NETWORK")
    case .barChart: return ("📈", "BAR CHART")
    case .quadrant: return ("⊞", "QUADRANT")
    case .pieChart: return ("🥧", "DISTRIBUTION")
    case .lineChart: return ("📉", "TREND")
    case .areaChart: return ("🌊", "CUMULATIVE TREND")
    case .scatterPlot: return ("🪶", "CORRELATION")
    case .vennDiagram: return ("◐", "VENN DIAGRAM")
    case .ganttChart: return ("🗓", "TIMELINE")
    case .funnelDiagram: return ("🔻", "FUNNEL")
    case .pyramidDiagram: return ("🔺", "PYRAMID")
    case .cycleDiagram: return ("♻️", "CYCLE")
    case .fishboneDiagram: return ("🐟", "CAUSE & EFFECT")
    case .swotMatrix: return ("🎯", "SWOT")
    case .sankeyDiagram: return ("➡️", "FLOW")
    case .treemap: return ("🧮", "TREEMAP")
    case .heatmap: return ("🔥", "HEATMAP")
    case .bubbleChart: return ("🫧", "BUBBLE CHART")
    case .infographic: return ("🧾", "INFOGRAPHIC")
    case .storyboard: return ("🎬", "STORYBOARD")
    case .journeyMap: return ("🧭", "JOURNEY MAP")
    case .barChartStacked: return ("📊", "STACKED BARS")
    case .barChartGrouped: return ("📊", "GROUPED BARS")
    case .table: return ("📋", "TABLE")
    case .generic: return ("📌", "VISUAL")
    }
}

static func renderVisualBodyHTML(for visual: InsightVisual) -> String {
    func formatNumber(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
    }

    func listHTML(_ items: [String]) -> String {
        let lines = items.map { "- \($0)" }
        return renderBlockContent(lines)
    }

    func chipsHTML(_ items: [String]) -> String {
        let chips = items.map { "<span class=\"visual-chip\">\($0)</span>" }.joined()
        return "<div class=\"visual-chips\">\(chips)</div>"
    }

    func barsHTML(_ pairs: [(String, Double)], valueLabel: String = "Value") -> String {
        let maxValue = pairs.map { $0.1 }.max() ?? 0
        let rows = pairs.map { label, value -> String in
            let width = maxValue > 0 ? (value / maxValue) * 100 : 0
            return """
            <div class="visual-bar-row">
                <div class="visual-bar-label">\(label)</div>
                <div class="visual-bar-track">
                    <div class="visual-bar-fill" style="width: \(String(format: "%.2f", width))%"></div>
                </div>
                <div class="visual-bar-value">\(formatNumber(value))</div>
            </div>
            """
        }.joined()
        return """
        <div class="visual-bars">
            <div class="visual-subheader">\(valueLabel)</div>
            \(rows)
        </div>
        """
    }

    func timelineHTML(_ events: [TimelineData.Event]) -> String {
        let items = events.map { event -> String in
            let date = event.date.isEmpty ? "" : "<div class=\"timeline-date\">\(event.date)</div>"
            let desc = (event.description ?? "").isEmpty ? "" : "<div class=\"timeline-desc\">\(event.description ?? "")</div>"
            return """
            <div class="timeline-item">
                \(date)
                <div class="timeline-title">\(event.title)</div>
                \(desc)
            </div>
            """
        }.joined()
        return "<div class=\"visual-timeline-list\">\(items)</div>"
    }

    func quadrantHTML(_ data: QuadrantData) -> String {
        let axisX = data.axesX.map { "<div class=\"quadrant-axis quadrant-axis-x\">\($0)</div>" } ?? ""
        let axisY = data.axesY.map { "<div class=\"quadrant-axis quadrant-axis-y\">\($0)</div>" } ?? ""
        let cells = data.quadrants.map { quad -> String in
            let items = quad.items.map { "<li>\($0)</li>" }.joined()
            return """
            <div class="quadrant-cell">
                <div class="quadrant-title">\(quad.name)</div>
                <ul class="quadrant-items">\(items)</ul>
            </div>
            """
        }.joined()
        return """
        <div class="visual-quadrant-grid">
            \(axisX)\(axisY)
            \(cells)
        </div>
        """
    }

    func swotHTML(_ data: SWOTData) -> String {
        let strengths = data.strengths.map { "<li>\($0)</li>" }.joined()
        let weaknesses = data.weaknesses.map { "<li>\($0)</li>" }.joined()
        let opportunities = data.opportunities.map { "<li>\($0)</li>" }.joined()
        let threats = data.threats.map { "<li>\($0)</li>" }.joined()
        return """
        <div class="visual-grid-2x2">
            <div class="visual-cell"><div class="visual-cell-title">Strengths</div><ul>\(strengths)</ul></div>
            <div class="visual-cell"><div class="visual-cell-title">Weaknesses</div><ul>\(weaknesses)</ul></div>
            <div class="visual-cell"><div class="visual-cell-title">Opportunities</div><ul>\(opportunities)</ul></div>
            <div class="visual-cell"><div class="visual-cell-title">Threats</div><ul>\(threats)</ul></div>
        </div>
        """
    }

    switch visual.payload {
    case .spectrum(let data):
        // Poles as a labelled row, items beneath, mirroring the in-app card.
        let items = data.items
            .map { "<li>\(escapeHTML($0.label))</li>" }
            .joined()
        return """
        <div class="spectrum">
          <div class="spectrum-poles">
            <span class="spectrum-pole-left">\(escapeHTML(data.leftPole))</span>
            <span class="spectrum-pole-right">\(escapeHTML(data.rightPole))</span>
          </div>
          <div class="spectrum-axis"></div>
          \(items.isEmpty ? "" : "<ul class=\"spectrum-items\">\(items)</ul>")
        </div>
        """

    case .timeline(let data):
        return timelineHTML(data.events)

    case .flowchart(let data):
        return renderFlowchartContent(data.nodes)

    case .comparison(let data):
        let table = data.columns.isEmpty ? data.rows : [data.columns] + data.rows
        return renderTable(rows: table)

    case .table(let data):
        let table = data.columns.isEmpty ? data.rows : [data.columns] + data.rows
        return renderTable(rows: table)

    case .conceptMap(let data):
        let mapLines = ["Central: \(data.center)"] + data.branches.map { "- \($0)" }
        return renderConceptMapContent(mapLines.joined(separator: "\n"))

    case .radar(let data):
        return chipsHTML(data.dimensions)

    case .hierarchy(let data):
        let children = data.children.map { "<li>\($0)</li>" }.joined()
        return """
        <div class="hierarchy-root">\(data.root)</div>
        <ul class="hierarchy-list">\(children)</ul>
        """

    case .network(let data):
        let nodes = data.nodes.map { node in
            "<li><strong>\(node.label)</strong> <span class=\"visual-muted\">(\(node.id))</span> \(node.type.map { "• \($0)" } ?? "")</li>"
        }.joined()
        let connections = data.connections.map { connection in
            "<li>\(connection.from) → \(connection.to) \(connection.type.map { "• \($0)" } ?? "")</li>"
        }.joined()
        return """
        <div class="visual-subheader">Nodes</div>
        <ul class="visual-list">\(nodes)</ul>
        <div class="visual-subheader">Connections</div>
        <ul class="visual-list">\(connections)</ul>
        """

    case .barChart(let data):
        let pairs = Array(zip(data.labels, data.values))
        return barsHTML(pairs, valueLabel: "Value")

    case .quadrant(let data):
        return quadrantHTML(data)

    case .pieChart(let data):
        let total = data.segments.map { $0.value }.reduce(0, +)
        let rows = data.segments.map { segment in
            let percent = total > 0 ? (segment.value / total) * 100 : 0
            return (segment.label, percent)
        }
        let items = rows.map { label, percent in
            "<li><span class=\"visual-dot\"></span><strong>\(label)</strong> <span class=\"visual-muted\">\(formatNumber(percent))%</span></li>"
        }.joined()
        return "<ul class=\"visual-list\">\(items)</ul>"

    case .lineChart(let data):
        let pairs = Array(zip(data.labels, data.values))
        return barsHTML(pairs, valueLabel: "Value")

    case .areaChart(let data):
        let pairs = Array(zip(data.labels, data.values))
        return barsHTML(pairs, valueLabel: "Value")

    case .scatterPlot(let data):
        let points = data.points.map { point in
            "<li><strong>\(point.label ?? "Point")</strong>: (\(formatNumber(point.x)), \(formatNumber(point.y)))</li>"
        }.joined()
        return "<ul class=\"visual-list\">\(points)</ul>"

    case .vennDiagram(let data):
        let rows = data.sets.map { [$0.label, $0.items.joined(separator: " • ")] }
        let table = renderTable(rows: [["Set", "Items"]] + rows)
        if data.intersection.isEmpty {
            return table
        }
        let intersection = "<div class=\"visual-callout\">Intersection: \(data.intersection.joined(separator: ", "))</div>"
        return table + intersection

    case .ganttChart(let data):
        let maxDuration = data.tasks.map { $0.duration }.max() ?? 0
        let tasks = data.tasks.map { task -> String in
            let width = maxDuration > 0 ? (task.duration / maxDuration) * 100 : 0
            return """
            <div class="gantt-row">
                <div class="gantt-label">\(task.name)</div>
                <div class="gantt-track">
                    <div class="gantt-bar" style="width: \(String(format: "%.2f", width))%"></div>
                </div>
                <div class="gantt-meta">\(formatNumber(task.start)) • \(formatNumber(task.duration))</div>
            </div>
            """
        }.joined()
        return "<div class=\"gantt-list\">\(tasks)</div>"

    case .funnelDiagram(let data):
        let maxValue = data.stages.map { $0.value }.max() ?? 0
        let steps = data.stages.map { stage -> String in
            let width = maxValue > 0 ? (stage.value / maxValue) * 100 : 0
            return """
            <div class="funnel-step">
                <div class="funnel-label">\(stage.label)</div>
                <div class="funnel-bar" style="width: \(String(format: "%.2f", width))%"></div>
                <div class="funnel-value">\(formatNumber(stage.value))</div>
            </div>
            """
        }.joined()
        return "<div class=\"funnel-list\">\(steps)</div>"

    case .pyramidDiagram(let data):
        let items = data.levels.map { level in
            if let description = level.description, !description.isEmpty {
                return "\(level.label): \(description)"
            }
            return level.label
        }
        let rows = items.map { "<div class=\"pyramid-level\">\($0)</div>" }.joined()
        return "<div class=\"pyramid-list\">\(rows)</div>"

    case .cycleDiagram(let data):
        let stages = data.stages.enumerated().map { index, stage -> String in
            let arrow = index < data.stages.count - 1 ? "<span class=\"cycle-arrow\">→</span>" : ""
            return "<span class=\"cycle-step\">\(stage)</span>\(arrow)"
        }.joined()
        return "<div class=\"cycle-list\">\(stages)</div>"

    case .fishboneDiagram(let data):
        let header = "<div class=\"visual-callout\">Effect: \(data.effect)</div>"
        let items = data.causes.map { cause -> String in
            let details = cause.items.map { "<li>\($0)</li>" }.joined()
            return "<div class=\"fishbone-row\"><div class=\"fishbone-title\">\(cause.category)</div><ul>\(details)</ul></div>"
        }.joined()
        return header + "<div class=\"fishbone-list\">\(items)</div>"

    case .swotMatrix(let data):
        return swotHTML(data)

    case .sankeyDiagram(let data):
        let flows = data.flows.map { flow in
            "<li>\(flow.from) → \(flow.to) <span class=\"visual-muted\">\(formatNumber(flow.value))</span></li>"
        }.joined()
        return "<ul class=\"visual-list\">\(flows)</ul>"

    case .treemap(let data):
        let rows = data.items.map { "<li><strong>\($0.label)</strong> <span class=\"visual-muted\">\(formatNumber($0.value))</span></li>" }.joined()
        return "<ul class=\"visual-list\">\(rows)</ul>"

    case .heatmap(let data):
        var table: [[String]] = []
        table.append([""] + data.cols)
        for (rowIndex, row) in data.rows.enumerated() {
            let values = rowIndex < data.values.count ? data.values[rowIndex] : []
            let rowValues = values.prefix(data.cols.count).map { formatNumber($0) }
            table.append([row] + rowValues)
        }
        return renderTable(rows: table)

    case .bubbleChart(let data):
        let rows = data.bubbles.map { bubble in
            "<li><strong>\(bubble.label)</strong> <span class=\"visual-muted\">x:\(formatNumber(bubble.x)) y:\(formatNumber(bubble.y)) size:\(formatNumber(bubble.size))</span></li>"
        }.joined()
        return "<ul class=\"visual-list\">\(rows)</ul>"

    case .infographic(let data):
        let stats = data.stats.map { stat in
            "<div class=\"stat-card\"><div class=\"stat-value\">\(stat.value)</div><div class=\"stat-label\">\(stat.label)</div></div>"
        }.joined()
        let highlights = data.highlights.isEmpty ? "" : "<div class=\"visual-subheader\">Highlights</div>" + listHTML(data.highlights)
        return "<div class=\"stat-grid\">\(stats)</div>" + highlights

    case .storyboard(let data):
        let scenes = data.scenes.enumerated().map { index, scene -> String in
            let desc = scene.description.isEmpty ? "" : "<div class=\"story-desc\">\(scene.description)</div>"
            return "<div class=\"story-card\"><div class=\"story-title\">\(index + 1). \(scene.title)</div>\(desc)</div>"
        }.joined()
        return "<div class=\"story-list\">\(scenes)</div>"

    case .journeyMap(let data):
        let stages = data.stages.map { stage -> String in
            let emotion = stage.emotion?.capitalized ?? ""
            let touchpoints = stage.touchpoints.map { "<li>\($0)</li>" }.joined()
            let emotionTag = emotion.isEmpty ? "" : "<span class=\"journey-emotion\">\(emotion)</span>"
            return """
            <div class="journey-stage">
                <div class="journey-title">\(stage.name) \(emotionTag)</div>
                <ul class="journey-touchpoints">\(touchpoints)</ul>
            </div>
            """
        }.joined()
        return "<div class=\"journey-list\">\(stages)</div>"

    case .barChartStacked(let data):
        var table: [[String]] = []
        table.append([""] + data.seriesLabels)
        for (index, label) in data.labels.enumerated() {
            let values = data.series.map { series in
                series.indices.contains(index) ? formatNumber(series[index]) : ""
            }
            table.append([label] + values)
        }
        return renderTable(rows: table)

    case .barChartGrouped(let data):
        var table: [[String]] = []
        table.append([""] + data.seriesLabels)
        for (index, label) in data.labels.enumerated() {
            let values = data.series.map { series in
                series.indices.contains(index) ? formatNumber(series[index]) : ""
            }
            table.append([label] + values)
        }
        return renderTable(rows: table)

    case .generic(let data):
        return renderBlockContent([data])
    }
}

// MARK: - Premium Block HTML Renderers

/// Render premium quote with coral border and decorative quotation mark
static func renderPremiumQuoteHTML(content: [String]) -> String {
    // Parse content: first lines are the quote, last line starting with "—" or "-" is attribution
    var quoteLines: [String] = []
    var attribution: String? = nil
    var source: String? = nil

    for line in content {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("—") || trimmed.hasPrefix("-") {
            // This is attribution
            let attrText = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
            // Check if there's a source in parentheses or after comma
            if let parenRange = attrText.range(of: "(") {
                attribution = String(attrText[..<parenRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                source = String(attrText[parenRange.lowerBound...]).replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
            } else if let commaRange = attrText.range(of: ",") {
                attribution = String(attrText[..<commaRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                source = String(attrText[commaRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            } else {
                attribution = attrText
            }
        } else if !trimmed.isEmpty {
            quoteLines.append(convertInlineMarkdown(trimmed))
        }
    }

    let quoteText = quoteLines.joined(separator: "<br>")
    var attributionHTML = ""
    if let attr = attribution {
        attributionHTML = "<cite>\(attr)"
        if let src = source {
            attributionHTML += "<span class=\"premium-quote-source\">\(src)</span>"
        }
        attributionHTML += "</cite>"
    }

    return """
    <div class="premium-quote">
        <div class="premium-quote-mark">"</div>
        <blockquote>
            <p>\(quoteText)</p>
            \(attributionHTML)
        </blockquote>
    </div>
    """
}

/// Render author spotlight with double gold border
static func renderAuthorSpotlightHTML(content: [String]) -> String {
    // Parse content: look for author name and description
    var authorName: String? = nil
    var descriptionLines: [String] = []

    for line in content {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { continue }

        // First non-empty line is typically the author name
        if authorName == nil {
            authorName = trimmed
        } else {
            descriptionLines.append(convertInlineMarkdown(trimmed))
        }
    }

    let description = descriptionLines.joined(separator: "<br>")

    return """
    <div class="author-spotlight">
        <div class="author-spotlight-header">
            <span class="author-spotlight-icon">📖</span>
            <span class="author-spotlight-label">ABOUT THE AUTHOR</span>
        </div>
        <h3 class="author-spotlight-name">\(authorName ?? "")</h3>
        <p class="author-spotlight-bio">\(description)</p>
    </div>
    """
}

/// Render premium section divider with diamond ornaments
static func renderPremiumDividerHTML() -> String {
    return """
    <div class="premium-divider">
        <span class="premium-divider-line"></span>
        <span class="premium-divider-diamond">◆</span>
        <span class="premium-divider-diamond-outline">◇</span>
        <span class="premium-divider-diamond">◆</span>
        <span class="premium-divider-line"></span>
    </div>
    """
}

/// Render premium H1 header with diamond ornaments
static func renderPremiumH1HTML(title: String) -> String {
    return """
    <div class="premium-h1">
        <div class="premium-h1-ornaments">
            <span class="diamond-filled">◆</span>
            <span class="diamond-outline">◇</span>
            <span class="diamond-filled">◆</span>
        </div>
        <h1>\(convertInlineMarkdown(title.uppercased()))</h1>
        <div class="premium-h1-ornaments">
            <span class="diamond-filled">◆</span>
            <span class="diamond-outline">◇</span>
            <span class="diamond-filled">◆</span>
        </div>
    </div>
    """
}

/// Render premium H2 header with gold bar
static func renderPremiumH2HTML(title: String) -> String {
    return """
    <div class="premium-h2">
        <span class="premium-h2-bar"></span>
        <h2>\(convertInlineMarkdown(title))</h2>
    </div>
    """
}

/// Render INSIGHT ATLAS NOTE with structured formatting for Key Distinction, Practical Implication, Go Deeper
static func renderInsightNoteHTML(content: [String]) -> String {
    var coreConnection: [String] = []
    var keyDistinction: String? = nil
    var practicalImplication: String? = nil
    var goDeeper: String? = nil

    // Join content to handle multi-line parsing
    let fullContent = content.joined(separator: "\n")

    // Parse structured sections using regex patterns
    // Pattern for **Key Distinction:** or Key Distinction:
    let keyDistinctionPattern = #"\*{0,2}Key Distinction:?\*{0,2}\s*(.+?)(?=\*{0,2}Practical Implication|\*{0,2}Go Deeper|$)"#
    let practicalImplicationPattern = #"\*{0,2}Practical Implication:?\*{0,2}\s*(.+?)(?=\*{0,2}Go Deeper|$)"#
    let goDeepPattern = #"\*{0,2}Go Deeper:?\*{0,2}\s*(.+?)$"#

    // Extract Key Distinction
    if let keyMatch = fullContent.range(of: keyDistinctionPattern, options: [.regularExpression, .caseInsensitive]) {
        var matched = String(fullContent[keyMatch])
        // Clean up the prefix
        matched = matched.replacingOccurrences(of: #"^\*{0,2}Key Distinction:?\*{0,2}\s*"#, with: "", options: .regularExpression)
        keyDistinction = matched.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Extract Practical Implication
    if let practicalMatch = fullContent.range(of: practicalImplicationPattern, options: [.regularExpression, .caseInsensitive]) {
        var matched = String(fullContent[practicalMatch])
        matched = matched.replacingOccurrences(of: #"^\*{0,2}Practical Implication:?\*{0,2}\s*"#, with: "", options: .regularExpression)
        practicalImplication = matched.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Extract Go Deeper
    if let goMatch = fullContent.range(of: goDeepPattern, options: [.regularExpression, .caseInsensitive]) {
        var matched = String(fullContent[goMatch])
        matched = matched.replacingOccurrences(of: #"^\*{0,2}Go Deeper:?\*{0,2}\s*"#, with: "", options: .regularExpression)
        goDeeper = matched.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Extract core connection (everything before the first structured section)
    var coreText = fullContent
    if let keyRange = fullContent.range(of: #"\*{0,2}Key Distinction"#, options: [.regularExpression, .caseInsensitive]) {
        coreText = String(fullContent[..<keyRange.lowerBound])
    }
    coreConnection = [coreText.trimmingCharacters(in: .whitespacesAndNewlines)]

    // Build HTML output with proper structure
    var html = """
    <div class="insight-note">
        <div class="block-header">💡 INSIGHT ATLAS NOTE</div>
        <div class="block-content">
    """

    // Core connection paragraph
    if !coreConnection.isEmpty && !coreConnection[0].isEmpty {
        html += "<p class=\"core-connection\">\(convertInlineMarkdown(coreConnection[0]))</p>"
    }

    // Key Distinction section
    if let key = keyDistinction, !key.isEmpty {
        html += """
        <div class="insight-section key-distinction">
            <span class="insight-label">Key Distinction:</span>
            <span class="insight-text">\(convertInlineMarkdown(key))</span>
        </div>
        """
    }

    // Practical Implication section
    if let practical = practicalImplication, !practical.isEmpty {
        html += """
        <div class="insight-section practical-implication">
            <span class="insight-label">Practical Implication:</span>
            <span class="insight-text">\(convertInlineMarkdown(practical))</span>
        </div>
        """
    }

    // Go Deeper section
    if let deeper = goDeeper, !deeper.isEmpty {
        html += """
        <div class="insight-section go-deeper">
            <span class="insight-label">Go Deeper:</span>
            <span class="insight-text">\(convertInlineMarkdown(deeper))</span>
        </div>
        """
    }

    html += """
        </div>
    </div>
    """

    return html
}

static func renderStructureMapContent(_ lines: [String]) -> String {
    var tableHTML = "<table class=\"styled-table\"><tbody>"
    var hasHeaderRow = false

    for line in lines {
        // Skip header markers like "## Structure Map..."
        if line.hasPrefix("##") || line.hasPrefix("#") {
            continue
        }

        if line.hasPrefix("|") {
            var row = line.trimmingCharacters(in: .whitespaces)
            if row.hasPrefix("|") { row.removeFirst() }
            if row.hasSuffix("|") { row.removeLast() }
            let cells = row
                .components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }

            // Skip separator rows
            if cells.allSatisfy({ $0.contains("---") || $0.contains("-") && $0.count < 5 }) {
                continue
            }

            // First row becomes header
            if !hasHeaderRow {
                tableHTML += "<thead><tr>"
                for cell in cells {
                    tableHTML += "<th>\(convertInlineMarkdown(cell))</th>"
                }
                tableHTML += "</tr></thead>"
                hasHeaderRow = true
            } else {
                tableHTML += "<tr>"
                for cell in cells {
                    tableHTML += "<td>\(convertInlineMarkdown(cell))</td>"
                }
                tableHTML += "</tr>"
            }
        }
    }

    tableHTML += "</tbody></table>"
    return tableHTML
}

static func renderFlowchartContent(_ lines: [String]) -> String {
    var steps: [String] = []
    for line in lines {
        let cleaned = line.trimmingCharacters(in: .whitespaces)
        if !cleaned.isEmpty && cleaned != "vs." {
            steps.append("<div class=\"flow-step\">\(cleaned)</div>")
        } else if cleaned == "vs." {
            steps.append("<div class=\"flow-separator\">vs.</div>")
        }
    }
    return "<div class=\"flow-container\">\(steps.joined(separator: "\n<div class=\"flow-arrow\">↓</div>\n"))</div>"
}

static func renderProcessTimelineContent(_ lines: [String]) -> String {
    var timelineHTML = "<div class=\"timeline-container\">"
    var stepNumber = 1

    for line in lines {
        let cleaned = line.trimmingCharacters(in: .whitespaces)
        if cleaned.isEmpty { continue }

        // Check if line has a time/phase marker (e.g., "Phase 1:", "Step 1:", "1.", "1)")
        var phase = ""
        var description = cleaned

        // Parse numbered formats: "1. Description" or "1) Description"
        if cleaned.range(of: #"^(\d+[\.\)])\s*(.+)$"#, options: .regularExpression) != nil {
            let components = cleaned.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
            if let num = components.first {
                phase = "Step \(num)"
                if let colonIndex = cleaned.firstIndex(where: { $0 == "." || $0 == ")" }) {
                    description = String(cleaned[cleaned.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                }
            }
        }
        // Parse "Phase X:" or "Step X:" format
        else if let colonIndex = cleaned.firstIndex(of: ":") {
            let prefix = String(cleaned[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            if prefix.lowercased().hasPrefix("phase") || prefix.lowercased().hasPrefix("step") || prefix.lowercased().hasPrefix("stage") {
                phase = prefix
                description = String(cleaned[cleaned.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            }
        }

        // Default phase label if none detected
        if phase.isEmpty {
            phase = "Step \(stepNumber)"
        }

        timelineHTML += """
        <div class="timeline-step">
            <div class="timeline-marker">\(stepNumber)</div>
            <div class="timeline-content">
                <div class="timeline-phase">\(phase)</div>
                <div class="timeline-description">\(convertInlineMarkdown(description))</div>
            </div>
        </div>
        """
        stepNumber += 1
    }

    timelineHTML += "</div>"
    return timelineHTML
}

static func renderConceptMapContent(_ content: String) -> String {
    let lines = content.components(separatedBy: .newlines)
    var conceptsHTML = "<div class=\"concept-map-container\">"

    var centralConcept = ""
    var relatedConcepts: [(concept: String, relationship: String)] = []

    for line in lines {
        let cleaned = line.trimmingCharacters(in: .whitespaces)
        if cleaned.isEmpty { continue }

        // Detect central concept (usually first line or marked with "Central:" or similar)
        if centralConcept.isEmpty {
            if cleaned.lowercased().hasPrefix("central:") || cleaned.lowercased().hasPrefix("main:") || cleaned.lowercased().hasPrefix("core:") {
                if let colonIndex = cleaned.firstIndex(of: ":") {
                    centralConcept = String(cleaned[cleaned.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                } else {
                    centralConcept = cleaned
                }
            } else {
                centralConcept = cleaned
            }
            continue
        }

        // Parse related concepts with relationships
        // Format: "→ Concept: relationship" or "- Concept (relationship)" or just "- Concept"
        var concept = cleaned
        var relationship = "relates to"

        // Remove leading markers
        if concept.hasPrefix("→") || concept.hasPrefix("-") || concept.hasPrefix("•") || concept.hasPrefix("*") {
            concept = String(concept.dropFirst()).trimmingCharacters(in: .whitespaces)
        }

        // Parse "Concept: relationship" format
        if let colonIndex = concept.firstIndex(of: ":") {
            let beforeColon = String(concept[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let afterColon = String(concept[concept.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            concept = beforeColon
            relationship = afterColon
        }
        // Parse "Concept (relationship)" format
        else if let parenStart = concept.firstIndex(of: "("), let parenEnd = concept.firstIndex(of: ")") {
            relationship = String(concept[concept.index(after: parenStart)..<parenEnd]).trimmingCharacters(in: .whitespaces)
            concept = String(concept[..<parenStart]).trimmingCharacters(in: .whitespaces)
        }

        relatedConcepts.append((concept: concept, relationship: relationship))
    }

    // Build the visual concept map
    conceptsHTML += """
    <div class="concept-central">
        <div class="concept-node central">\(convertInlineMarkdown(centralConcept))</div>
    </div>
    <div class="concept-connections">
    """

    for (index, item) in relatedConcepts.enumerated() {
        let position = index % 4 // Cycle through positions
        let positionClass = ["top-left", "top-right", "bottom-left", "bottom-right"][position]
        conceptsHTML += """
        <div class="concept-branch \(positionClass)">
            <div class="concept-line"></div>
            <div class="concept-relationship">\(item.relationship)</div>
            <div class="concept-node related">\(convertInlineMarkdown(item.concept))</div>
        </div>
        """
    }

    conceptsHTML += "</div></div>"
    return conceptsHTML
}

static func renderBlockTableContent(_ lines: [String]) -> String {
    var tableHTML = "<table class=\"styled-table\"><tbody>"
    for line in lines {
        if line.hasPrefix("|") {
            var row = line.trimmingCharacters(in: .whitespaces)
            if row.hasPrefix("|") { row.removeFirst() }
            if row.hasSuffix("|") { row.removeLast() }
            let cells = row
                .components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            if !cells.allSatisfy({ $0.contains("---") || $0.contains("-") && $0.count < 5 }) {
                tableHTML += "<tr>"
                for cell in cells {
                    tableHTML += "<td>\(convertInlineMarkdown(cell))</td>"
                }
                tableHTML += "</tr>"
            }
        } else if !line.isEmpty {
            tableHTML += "<tr><td colspan=\"100%\">\(convertInlineMarkdown(line))</td></tr>"
        }
    }
    tableHTML += "</tbody></table>"
    return tableHTML
}

static func renderBlockContent(_ lines: [String]) -> String {
    var html: [String] = []
    var inList = false
    var listType = "" // "ul" or "ol"
    var currentParagraph: [String] = []
    var currentListItem: [String] = [] // Track multi-line list item content
    var inTable = false
    var tableRows: [[String]] = []

    // Helper to flush accumulated paragraph text
    func flushParagraph() {
        if !currentParagraph.isEmpty {
            let combinedText = currentParagraph.joined(separator: " ")
            html.append("<p>\(convertInlineMarkdown(combinedText))</p>")
            currentParagraph = []
        }
    }

    // Helper to flush the current list item
    func flushListItem() {
        if !currentListItem.isEmpty {
            let combinedText = currentListItem.joined(separator: " ")
            html.append("<li>\(convertInlineMarkdown(combinedText))</li>")
            currentListItem = []
        }
    }

    // Helper to close list properly
    func closeList() {
        if inList {
            flushListItem()
            html.append("</\(listType)>")
            inList = false
            listType = ""
        }
    }

    // Helper to flush table
    func flushTable() {
        if inTable && !tableRows.isEmpty {
            html.append(renderTable(rows: tableRows))
            tableRows = []
            inTable = false
        }
    }

    for line in lines {
        // Skip redundant headers inside blocks
        if line.hasPrefix("#") || line.hasPrefix("INSIGHT ATLAS NOTE") ||
           line.hasPrefix("APPLY IT") || line.hasPrefix("Quick Glance") {
            continue
        }

        // Handle table rows
        if line.hasPrefix("|") && line.hasSuffix("|") {
            flushParagraph()
            closeList()
            // Check if it's a separator row (skip it)
            if line.contains("---") || line.contains("|-") {
                continue
            }
            let cells = line.dropFirst().dropLast()
                .components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            inTable = true
            tableRows.append(cells)
            continue
        } else if inTable {
            // End of table
            flushTable()
        }

        // Handle unordered list items - with space after marker
        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
            flushParagraph()
            flushListItem()
            if !inList || listType != "ul" {
                closeList()
                html.append("<ul>")
                inList = true
                listType = "ul"
            }
            let text = String(line.dropFirst(2))
            currentListItem.append(text)
        }
        // Handle unordered list items - without space after marker
        else if line.hasPrefix("-") || line.hasPrefix("*") || line.hasPrefix("•") {
            flushParagraph()
            flushListItem()
            if !inList || listType != "ul" {
                closeList()
                html.append("<ul>")
                inList = true
                listType = "ul"
            }
            let text = String(line.dropFirst(1)).trimmingCharacters(in: .whitespaces)
            currentListItem.append(text)
        }
        // Handle ordered list items - with space
        else if let _ = line.range(of: "^\\d+\\.\\s+", options: .regularExpression) {
            flushParagraph()
            flushListItem()
            if !inList || listType != "ol" {
                closeList()
                html.append("<ol>")
                inList = true
                listType = "ol"
            }
            let text = line.replacingOccurrences(of: "^\\d+\\.\\s+", with: "", options: .regularExpression)
            currentListItem.append(text)
        }
        // Handle ordered list items - without space (e.g., "1.Item")
        else if let _ = line.range(of: "^\\d+\\.", options: .regularExpression) {
            flushParagraph()
            flushListItem()
            if !inList || listType != "ol" {
                closeList()
                html.append("<ol>")
                inList = true
                listType = "ol"
            }
            let text = line.replacingOccurrences(of: "^\\d+\\.", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
            currentListItem.append(text)
        }
        // Regular text - check if it's a continuation of a list item
        else if inList && !line.isEmpty {
            // This is a continuation of the current list item
            currentListItem.append(line)
        }
        // Empty line handling
        else if line.isEmpty {
            // Empty lines inside a list just flush the current item but keep list open
            // Don't close the list on empty lines - let subsequent non-list content close it
            if inList {
                flushListItem()
                // Keep list open - it will be closed when we hit non-list content
            } else if !currentParagraph.isEmpty {
                // Empty line outside list - flush current paragraph
                flushParagraph()
            }
        }
        // Regular text outside of list
        else {
            closeList()
            // Check if this looks like a continuation of the previous line
            // A line is a continuation if:
            // - It starts with lowercase OR
            // - The previous line doesn't end with sentence-ending punctuation OR
            // - The line starts with common continuations (name, etc.)
            let startsWithLowercase = line.first?.isLowercase == true
            let previousEndsWithPunctuation = currentParagraph.last?.last.map { ".!?:".contains($0) } ?? false
            let isContinuation = startsWithLowercase ||
                (!currentParagraph.isEmpty && !previousEndsWithPunctuation)

            if isContinuation && !currentParagraph.isEmpty {
                // Continuation of previous paragraph
                currentParagraph.append(line)
            } else {
                // New paragraph
                flushParagraph()
                currentParagraph.append(line)
            }
        }
    }

    // Flush any remaining content
    flushParagraph()
    closeList()
    flushTable()

    return html.joined(separator: "\n")
}

static func closeListIfNeeded(_ htmlLines: inout [String], _ inList: inout Bool, _ listType: inout String) {
    if inList && !listType.isEmpty {
        htmlLines.append("</\(listType)>")
        inList = false
        listType = ""
    }
}

/// Escapes HTML special characters to prevent XSS attacks
static func escapeHTML(_ string: String) -> String {
    return string
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&#39;")
}

static func convertInlineMarkdown(_ text: String) -> String {
    // Remove editorial control tags and convert image syntax to its semantic
    // alt text before escaping. Links remain intact for the native HTML pass.
    var source = PresentationTextSanitizer.withoutEditorialMarkup(text)
    source = source.replacingOccurrences(
        of: #"!\[([^\]]*)\]\([^)]*\)"#,
        with: "$1",
        options: .regularExpression
    )
    var result = escapeHTML(source)

    // Convert bold (must come before italic)
    // Use a more robust pattern that handles multi-word bold text
    result = result.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*",
                                          with: "<strong>$1</strong>",
                                          options: .regularExpression)

    // Convert strikethrough before the single-character emphasis passes.
    result = result.replacingOccurrences(of: "~~(.+?)~~",
                                          with: "<del>$1</del>",
                                          options: .regularExpression)

    // Convert italic (non-greedy to handle multiple italics on same line)
    result = result.replacingOccurrences(of: "\\*(.+?)\\*",
                                          with: "<em>$1</em>",
                                          options: .regularExpression)
    result = result.replacingOccurrences(of: "_(.+?)_",
                                          with: "<em>$1</em>",
                                          options: .regularExpression)

    // Convert inline code
    result = result.replacingOccurrences(of: "`([^`]+)`",
                                          with: "<code>$1</code>",
                                          options: .regularExpression)

    // Convert links - validate URL to prevent javascript: injection
    result = result.replacingOccurrences(of: "\\[([^\\]]+)\\]\\(([^)]+)\\)",
                                          with: "<a href=\"$2\">$1</a>",
                                          options: .regularExpression)

    // Remove any javascript: URLs that might have been injected
    result = result.replacingOccurrences(of: "href=\"javascript:[^\"]*\"",
                                          with: "href=\"#\"",
                                          options: [.regularExpression, .caseInsensitive])

    // Never expose malformed generation delimiters as visible content.
    // Valid pairs have already become native HTML elements above.
    result = result.replacingOccurrences(of: "**", with: "")
    result = result.replacingOccurrences(of: "~~", with: "")
    result = result.replacingOccurrences(of: "`", with: "")

    return result
}

static func renderTable(rows: [[String]]) -> String {
    guard !rows.isEmpty else { return "" }

    var html = "<table class=\"styled-table\">"

    // First row is header
    if let headerRow = rows.first {
        html += "<thead><tr>"
        for cell in headerRow {
            html += "<th>\(convertInlineMarkdown(cell))</th>"
        }
        html += "</tr></thead>"
    }

    // Remaining rows are body
    if rows.count > 1 {
        html += "<tbody>"
        for (index, row) in rows.dropFirst().enumerated() {
            let rowClass = index % 2 == 0 ? "even-row" : "odd-row"
            html += "<tr class=\"\(rowClass)\">"
            for cell in row {
                html += "<td>\(convertInlineMarkdown(cell))</td>"
            }
            html += "</tr>"
        }
        html += "</tbody>"
    }

    html += "</table>"
    return html
}

static func convert(_ markdown: String, title: String, author: String) -> String {
    // Parse markdown line by line for proper conversion
    let lines = markdown.components(separatedBy: "\n")
    var htmlLines: [String] = []
    var inList = false
    var listType = "" // "ul" or "ol"
    var currentListItem: [String] = [] // Track multi-line list item content
    var inBlockquote = false
    var inCodeBlock = false
    var inSpecialBlock = false
    var specialBlockType = ""
    var specialBlockTitle: String?
    var specialBlockContent: [String] = []
    var inTable = false
    var tableRows: [[String]] = []
    var tocEntries: [(text: String, level: Int, id: String)] = [] // For Table of Contents
    var headingCounter = 0

    // Helper to flush current list item
    func flushListItem() {
        if !currentListItem.isEmpty {
            let combinedText = currentListItem.joined(separator: " ")
            htmlLines.append("<li>\(convertInlineMarkdown(combinedText))</li>")
            currentListItem = []
        }
    }

    // Helper to close list with proper flushing
    func closeListWithFlush() {
        if inList {
            flushListItem()
            htmlLines.append("</\(listType)>")
            inList = false
            listType = ""
        }
    }

    func isNewBlockStartLine(_ trimmed: String) -> Bool {
        if trimmed.hasPrefix("#") {
            return true
        }
        return detectBlockStart(trimmed) != nil
    }

    func parseInlineBlock(_ trimmed: String) -> (type: String, content: [String])? {
        let patterns: [(tag: String, type: String)] = [
            ("QUICK_GLANCE", "quick-glance"),
            ("INSIGHT_NOTE", "insight-note"),
            ("ACTION_BOX", "action-box"),
            ("FOUNDATIONAL_NARRATIVE", "foundational-narrative"),
            ("TAKEAWAYS", "takeaways"),
            ("PREMIUM_QUOTE", "premium-quote"),
            ("AUTHOR_SPOTLIGHT", "author-spotlight"),
            ("ALTERNATIVE_PERSPECTIVE", "alternative-perspective"),
            ("RESEARCH_INSIGHT", "research-insight"),
            ("PREMIUM_H1", "premium-h1"),
            ("PREMIUM_H2", "premium-h2")
        ]

        for pattern in patterns {
            let openTag = "[\(pattern.tag)"
            let closeTag = "[/\(pattern.tag)]"
            guard let openRange = trimmed.range(of: openTag),
                  let closeRange = trimmed.range(of: closeTag) else {
                continue
            }
            guard let openEnd = trimmed[openRange.lowerBound...].firstIndex(of: "]") else {
                continue
            }
            // A closing tag can precede the opening tag on the same line, which
            // reverses this range and traps with "Range requires lowerBound <=
            // upperBound". Treat that as malformed rather than crashing.
            guard closeRange.lowerBound > openEnd else { return nil }
            let contentRange = trimmed.index(after: openEnd)..<closeRange.lowerBound
            let content = String(trimmed[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let lines = content.components(separatedBy: "\n")
            return (type: pattern.type, content: lines)
        }

        if trimmed.contains("[EXERCISE_"), let closeRange = trimmed.range(of: "[/EXERCISE_") {
            guard let openStart = trimmed.range(of: "[EXERCISE_"),
                  let openEnd = trimmed[openStart.lowerBound...].firstIndex(of: "]") else {
                return nil
            }
            // A closing tag can precede the opening tag on the same line, which
            // reverses this range and traps with "Range requires lowerBound <=
            // upperBound". Treat that as malformed rather than crashing.
            guard closeRange.lowerBound > openEnd else { return nil }
            let contentRange = trimmed.index(after: openEnd)..<closeRange.lowerBound
            let content = String(trimmed[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (type: "exercise", content: content.components(separatedBy: "\n"))
        }

        return nil
    }

    for line in lines {
        var processedLine = line

        // Remove box drawing characters
        for char in ["┌", "├", "└", "│", "─", "┐", "┤", "┘", "↓", "→", "←", "↑"] {
            processedLine = processedLine.replacingOccurrences(of: char, with: "")
        }

        let trimmed = processedLine.trimmingCharacters(in: .whitespaces)

        if let inlineBlock = parseInlineBlock(trimmed) {
            let blockHTML = renderSpecialBlock(type: inlineBlock.type, content: inlineBlock.content, fullContent: markdown)
            htmlLines.append(blockHTML)
            continue
        }

        if inSpecialBlock && !detectBlockEnd(trimmed) && isNewBlockStartLine(trimmed) {
            let blockHTML = renderSpecialBlock(
                type: specialBlockType,
                content: specialBlockContent,
                fullContent: markdown,
                blockTitle: specialBlockTitle
            )
            htmlLines.append(blockHTML)
            inSpecialBlock = false
            specialBlockType = ""
            specialBlockTitle = nil
            specialBlockContent = []
        }

        // Skip empty lines in special blocks
        if inSpecialBlock && trimmed.isEmpty {
            specialBlockContent.append("")
            continue
        }

        // Handle code blocks (```)
        if trimmed.hasPrefix("```") {
            inCodeBlock = !inCodeBlock
            continue
        }
        if inCodeBlock {
            continue // Skip code block content
        }

        // Handle special block markers
        if let blockStart = detectBlockStart(trimmed) {
            closeListWithFlush()
            inSpecialBlock = true
            specialBlockType = blockStart
            specialBlockTitle = detectBlockTitle(trimmed)
            specialBlockContent = []
            continue
        }

        if detectBlockEnd(trimmed) {
            if inSpecialBlock {
                let blockHTML = renderSpecialBlock(
                    type: specialBlockType,
                    content: specialBlockContent,
                    fullContent: markdown,
                    blockTitle: specialBlockTitle
                )
                htmlLines.append(blockHTML)
            }
            inSpecialBlock = false
            specialBlockType = ""
            specialBlockTitle = nil
            specialBlockContent = []
            continue
        }

        if inSpecialBlock {
            specialBlockContent.append(trimmed)
            continue
        }

        // Skip horizontal rules and convert ═══ dividers to premium dividers
        if trimmed == "---" || trimmed == "***" || trimmed == "___" {
            closeListWithFlush()
            htmlLines.append("<hr class=\"section-divider\">")
            continue
        }

        // Convert ═══ dividers to premium diamond ornament dividers
        // Catch any line that's primarily ═ characters (box drawing dividers)
        if trimmed.contains("═══") || trimmed.hasPrefix("═") ||
           (trimmed.count > 3 && trimmed.filter({ $0 == "═" }).count > trimmed.count / 2) {
            closeListWithFlush()
            htmlLines.append("<div class=\"premium-ornament-divider\"><span class=\"ornament\">◇ ◆ ◇</span></div>")
            continue
        }

        // Skip duplicate title headers that match the document title
        if trimmed.hasPrefix("# ") {
            let headerText = String(trimmed.dropFirst(2))
            if headerText.uppercased() == title.uppercased() ||
               headerText.uppercased().contains(title.uppercased()) {
                continue
            }
        }

        // Handle table rows
        if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") {
            closeListWithFlush()
            // Check if it's a separator row
            if trimmed.contains("---") || trimmed.contains("|-") {
                continue
            }
            let cells = trimmed.dropFirst().dropLast()
                .components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            if !inTable {
                inTable = true
                tableRows = []
            }
            tableRows.append(cells)
            continue
        } else if inTable {
            // End of table
            htmlLines.append(renderTable(rows: tableRows))
            inTable = false
            tableRows = []
        }

        // Handle blockquotes
        if trimmed.hasPrefix(">") {
            closeListWithFlush()
            let quoteContent = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            if !inBlockquote {
                htmlLines.append("<blockquote>")
                inBlockquote = true
            }
            htmlLines.append(convertInlineMarkdown(quoteContent))
            continue
        } else if inBlockquote {
            htmlLines.append("</blockquote>")
            inBlockquote = false
        }

        // Handle headers with IDs for TOC navigation
        if trimmed.hasPrefix("######") {
            closeListWithFlush()
            let text = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            headingCounter += 1
            let headingId = "section-\(headingCounter)"
            tocEntries.append((text: text, level: 6, id: headingId))
            htmlLines.append("<h6 id=\"\(headingId)\">\(convertInlineMarkdown(text))</h6>")
            continue
        }
        if trimmed.hasPrefix("#####") {
            closeListWithFlush()
            let text = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            headingCounter += 1
            let headingId = "section-\(headingCounter)"
            tocEntries.append((text: text, level: 5, id: headingId))
            htmlLines.append("<h5 id=\"\(headingId)\">\(convertInlineMarkdown(text))</h5>")
            continue
        }
        if trimmed.hasPrefix("####") {
            closeListWithFlush()
            let text = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            headingCounter += 1
            let headingId = "section-\(headingCounter)"
            tocEntries.append((text: text, level: 4, id: headingId))
            htmlLines.append("<h4 id=\"\(headingId)\">\(convertInlineMarkdown(text))</h4>")
            continue
        }
        if trimmed.hasPrefix("###") {
            closeListWithFlush()
            let text = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            headingCounter += 1
            let headingId = "section-\(headingCounter)"
            tocEntries.append((text: text, level: 3, id: headingId))
            htmlLines.append("<h3 id=\"\(headingId)\">\(convertInlineMarkdown(text))</h3>")
            continue
        }
        if trimmed.hasPrefix("##") {
            closeListWithFlush()
            let text = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            headingCounter += 1
            let headingId = "section-\(headingCounter)"
            tocEntries.append((text: text, level: 2, id: headingId))

            // Check if this is a PART header (PART I, PART II, etc.) - also detect at H2 level
            if text.uppercased().hasPrefix("PART ") {
                htmlLines.append("""
                <div class="premium-part-header" id="\(headingId)">
                    <div class="part-ornament">◇ ◆ ◇</div>
                    <h1 class="part-title">\(convertInlineMarkdown(text))</h1>
                    <div class="part-ornament">◇ ◆ ◇</div>
                </div>
                """)
            } else {
                // Apply premium h2 styling with gold bar
                htmlLines.append("<h2 id=\"\(headingId)\" class=\"premium-h2\">\(convertInlineMarkdown(text))</h2>")
            }
            continue
        }
        if trimmed.hasPrefix("# ") {
            closeListWithFlush()
            let text = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            headingCounter += 1
            let headingId = "section-\(headingCounter)"
            tocEntries.append((text: text, level: 1, id: headingId))

            // Check if this is a PART header (PART I, PART II, etc.)
            if text.uppercased().hasPrefix("PART ") {
                htmlLines.append("""
                <div class="premium-part-header" id="\(headingId)">
                    <div class="part-ornament">◇ ◆ ◇</div>
                    <h1 class="part-title">\(convertInlineMarkdown(text))</h1>
                    <div class="part-ornament">◇ ◆ ◇</div>
                </div>
                """)
            } else {
                htmlLines.append("<h1 id=\"\(headingId)\">\(convertInlineMarkdown(text))</h1>")
            }
            continue
        }

        // Handle unordered list items - with space after marker
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("• ") {
            // Flush previous list item if any
            flushListItem()
            // If we're in an ordered list, close it first
            if inList && listType == "ol" {
                closeListWithFlush()
            }
            if !inList {
                htmlLines.append("<ul>")
                inList = true
                listType = "ul"
            }
            let text = String(trimmed.dropFirst(2))
            currentListItem.append(text)
            continue
        }

        // Handle unordered list items - without space after marker
        if trimmed.hasPrefix("-") || trimmed.hasPrefix("*") || trimmed.hasPrefix("•") {
            // Flush previous list item if any
            flushListItem()
            // If we're in an ordered list, close it first
            if inList && listType == "ol" {
                closeListWithFlush()
            }
            if !inList {
                htmlLines.append("<ul>")
                inList = true
                listType = "ul"
            }
            let text = String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces)
            currentListItem.append(text)
            continue
        }

        // Handle numbered list items - with space
        if let _ = trimmed.range(of: "^\\d+\\.\\s+", options: .regularExpression) {
            // Flush previous list item if any
            flushListItem()
            // If we're in an unordered list, close it first
            if inList && listType == "ul" {
                closeListWithFlush()
            }
            if !inList {
                htmlLines.append("<ol>")
                inList = true
                listType = "ol"
            }
            let text = trimmed.replacingOccurrences(of: "^\\d+\\.\\s+", with: "", options: .regularExpression)
            currentListItem.append(text)
            continue
        }

        // Handle numbered list items - without space (e.g., "1.Item")
        if let _ = trimmed.range(of: "^\\d+\\.", options: .regularExpression) {
            // Flush previous list item if any
            flushListItem()
            // If we're in an unordered list, close it first
            if inList && listType == "ul" {
                closeListWithFlush()
            }
            if !inList {
                htmlLines.append("<ol>")
                inList = true
                listType = "ol"
            }
            let text = trimmed.replacingOccurrences(of: "^\\d+\\.", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
            currentListItem.append(text)
            continue
        }

        // Check if this is a continuation of a list item
        if inList && !trimmed.isEmpty && !currentListItem.isEmpty {
            // This line is a continuation of the current list item
            currentListItem.append(trimmed)
            continue
        }

        // Handle empty lines - flush current item but keep list open
        if trimmed.isEmpty {
            if inList {
                flushListItem()
            }
            continue
        }

        // Close list if we hit non-list content (actual paragraph text)
        if inList {
            closeListWithFlush()
        }

        // Handle regular paragraphs
        let converted = convertInlineMarkdown(trimmed)
        htmlLines.append("<p>\(converted)</p>")
    }

    // Close any open elements
    closeListWithFlush()
    if inBlockquote {
        htmlLines.append("</blockquote>")
    }
    if inTable {
        htmlLines.append(renderTable(rows: tableRows))
    }

    // Handle unclosed special blocks gracefully
    if inSpecialBlock && !specialBlockContent.isEmpty {
        // Log warning for debugging (in debug builds)
        #if DEBUG
        print("⚠️ Warning: Unclosed block marker for '\(specialBlockType)' - rendering content as-is")
        #endif
        // Render the unclosed block anyway to prevent content loss
        let blockHTML = renderSpecialBlock(
            type: specialBlockType,
            content: specialBlockContent,
            fullContent: markdown,
            blockTitle: specialBlockTitle
        )
        htmlLines.append(blockHTML)
    }

    let html = htmlLines.joined(separator: "\n")

    return generatePremiumHTML(content: html, title: title, author: author, fullContent: markdown, tocEntries: tocEntries)
}

/// Generate premium HTML with 2026 design system, dark mode, and print styles
static func generatePremiumHTML(content: String, title: String, author: String, fullContent: String, tocEntries: [(text: String, level: Int, id: String)] = []) -> String {
    let readingTime = ExportBrandAssets.calculateReadingTime(from: fullContent)

    // Generate Table of Contents HTML
    let tocHTML = generateHTMLTableOfContents(entries: tocEntries, readingTime: readingTime)

    // Generate logo image tags with base64 data
    let logoImageTag: String
    let footerLogoTag: String
    if let logoBase64 = ExportBrandAssets.getLogoBase64() {
        logoImageTag = "<img src=\"\(logoBase64)\" alt=\"Insight Atlas\" class=\"header-logo\">"
        footerLogoTag = "<img src=\"\(logoBase64)\" alt=\"Insight Atlas\" class=\"footer-logo\">"
    } else {
        logoImageTag = "" // Gracefully handle missing logo
        footerLogoTag = ""
    }

    return """
    <!DOCTYPE html>
    <html lang="en" dir="auto">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <meta name="color-scheme" content="light dark">
        <meta name="description" content="Premium book summary by Insight Atlas - Where Understanding Illuminates the World">
        <title>\(escapeHTML(title)) - Insight Atlas Guide</title>

        <!-- Google Fonts: Variable + Display + Handwritten -->
        <link rel="preconnect" href="https://fonts.googleapis.com">
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
        <link href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:ital,wght@0,400;0,500;0,600;0,700;1,400;1,500&family=Inter:wght@300..800&family=Caveat:wght@400;600&display=swap" rel="stylesheet">

        <style>
            /* ═══ INSIGHT ATLAS - PREMIUM 2026 EDITION ═══ */

            :root {
                /* Brand Colors */
                --brand-sepia: \(PremiumUI.Hex.mutedLight);
                --brand-parchment: \(PremiumUI.Hex.chipLight);
                --brand-ink: \(PremiumUI.Hex.inkLight);
                --gold: \(PremiumUI.Hex.emberMarkLight);
                --burgundy: \(PremiumUI.Hex.emberLight);
                --coral: \(PremiumUI.Hex.emberMarkLight);

                /* Primary Palette - Premium Gold */
                --primary-gold: \(PremiumUI.Hex.emberMarkLight);
                --primary-gold-light: \(PremiumUI.Hex.emberMarkLight);
                --primary-gold-dark: \(PremiumUI.Hex.emberLight);
                --primary-gold-subtle: rgba(var(--ember-rgb), 0.08);

                /* Secondary Palette */
                --accent-burgundy: \(PremiumUI.Hex.emberLight);
                --accent-coral: \(PremiumUI.Hex.emberMarkLight);
                --accent-coral-text: \(PremiumUI.Hex.emberLight);  /* WCAG AA compliant for text */
                --accent-teal: \(PremiumUI.Hex.celadonLight);
                --accent-teal-text: \(PremiumUI.Hex.celadonLight);   /* WCAG AA compliant for text */
                --accent-orange: \(PremiumUI.Hex.emberMarkLight);
                --accent-orange-text: \(PremiumUI.Hex.emberLight); /* WCAG AA compliant for text */
                --primary-gold-text: \(PremiumUI.Hex.emberLight);  /* WCAG AA compliant for text */

                /* Text Colors - Master Template 2026 Brown/Sepia */
                --text-heading: \(PremiumUI.Hex.inkLight);
                --text-body: \(PremiumUI.Hex.inkLight);
                --text-muted: \(PremiumUI.Hex.mutedLight);
                --text-subtle: \(PremiumUI.Hex.mutedLight);
                --text-inverse: \(PremiumUI.Hex.cardLight);

                /* Background Colors - Master Template 2026.
                   The page ground is the palette's background, not white —
                   white is the card, and the app and PDF both put cards on
                   a warm ground. With white here, exported guides lost the
                   card/page separation the other two surfaces have. */
                --bg-primary: \(PremiumUI.Hex.backgroundLight);
                --bg-secondary: \(PremiumUI.Hex.chipLight);
                --bg-card: \(PremiumUI.Hex.cardLight);
                --bg-cream: \(PremiumUI.Hex.emberWashLight);

                /* Border Colors - Master Template 2026 */
                --border-light: \(PremiumUI.Hex.dividerLight);
                --border-medium: \(PremiumUI.Hex.dividerStrongLight);

                /* Palette as RGB triplets.
                   Every tinted fill, border and shadow below composes one
                   of these with an alpha instead of writing a literal
                   rgba(). A literal cannot be re-pointed when the palette
                   moves, and cannot be overridden inside the dark block —
                   which is how this export ended up a palette generation
                   behind the app, with ember-era headers over terracotta-era
                   grounds inside the same callout. */
                --ember-rgb: \(PremiumUI.Hex.RGB.emberLight);
                --ember-mark-rgb: \(PremiumUI.Hex.RGB.emberMarkLight);
                --indigo-rgb: \(PremiumUI.Hex.RGB.indigoLight);
                --celadon-rgb: \(PremiumUI.Hex.RGB.celadonLight);
                --destructive-rgb: \(PremiumUI.Hex.RGB.destructiveLight);
                --ink-rgb: \(PremiumUI.Hex.RGB.inkLight);

                /* Fonts */
                --font-display: 'Cormorant Garamond', Georgia, serif;
                --font-ui: 'Inter', -apple-system, sans-serif;
                --font-handwritten: 'Caveat', cursive;

                /* Spacing */
                --content-width: 780px;
                --radius-lg: 14px;
                --radius-xl: 18px;
            }

            /* ═══ DARK MODE - Master Template 2026 ═══ */
            @media (prefers-color-scheme: dark) {
                :root {
                    --text-heading: \(PremiumUI.Hex.inkDark);
                    --text-body: \(PremiumUI.Hex.inkDark);
                    --text-muted: \(PremiumUI.Hex.mutedDark);
                    --text-subtle: \(PremiumUI.Hex.mutedDark);

                    --bg-primary: \(PremiumUI.Hex.backgroundDark);
                    --bg-secondary: \(PremiumUI.Hex.cardDark);
                    --bg-card: \(PremiumUI.Hex.cardDark);
                    --bg-cream: \(PremiumUI.Hex.cardDark);

                    --border-light: \(PremiumUI.Hex.dividerDark);
                    --border-medium: \(PremiumUI.Hex.dividerStrongDark);

                    /* Re-point the triplets, and every tint built from
                       them follows into dark mode automatically. */
                    --ember-rgb: \(PremiumUI.Hex.RGB.emberDark);
                    --ember-mark-rgb: \(PremiumUI.Hex.RGB.emberMarkDark);
                    --indigo-rgb: \(PremiumUI.Hex.RGB.indigoDark);
                    --celadon-rgb: \(PremiumUI.Hex.RGB.celadonDark);
                    --destructive-rgb: \(PremiumUI.Hex.RGB.destructiveDark);
                    --ink-rgb: \(PremiumUI.Hex.RGB.inkDark);

                    --primary-gold: \(PremiumUI.Hex.emberMarkDark);
                    --primary-gold-text: \(PremiumUI.Hex.emberMarkDark);  /* Light enough for dark mode */
                    --primary-gold-subtle: rgba(var(--ember-mark-rgb), 0.12);

                    /* Lighter accent colors for dark mode - already WCAG compliant on dark bg */
                    --accent-coral: \(PremiumUI.Hex.emberMarkDark);
                    --accent-coral-text: \(PremiumUI.Hex.emberMarkDark);
                    --accent-teal: \(PremiumUI.Hex.celadonDark);
                    --accent-teal-text: \(PremiumUI.Hex.celadonDark);
                    --accent-orange-text: \(PremiumUI.Hex.emberMarkDark);
                }

                /* Dark mode SVG icon adjustments */
                .insight-note .block-header::before {
                    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='\(PremiumUI.Hex.URLEncoded.emberOnDark)' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M9 18h6'/%3E%3Cpath d='M10 22h4'/%3E%3Cpath d='M12 2a7 7 0 0 1 7 7c0 2.38-1.19 4.47-3 5.74V17a1 1 0 0 1-1 1H9a1 1 0 0 1-1-1v-2.26C6.19 13.47 5 11.38 5 9a7 7 0 0 1 7-7z'/%3E%3C/svg%3E");
                }
                .alternative-perspective .block-header::before {
                    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='\(PremiumUI.Hex.URLEncoded.celadonOnDark)' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M12 3v18'/%3E%3Cpath d='M3 7l3 9h6l3-9'/%3E%3Cpath d='M15 7l3 9h6'/%3E%3Ccircle cx='6' cy='16' r='2'/%3E%3Ccircle cx='18' cy='16' r='2'/%3E%3Cpath d='M3 7h18'/%3E%3C/svg%3E");
                }
                .research-insight .block-header::before {
                    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='\(PremiumUI.Hex.URLEncoded.celadonOnDark)' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M9 3h6v6l3 9H6l3-9V3z'/%3E%3Cpath d='M9 3h6'/%3E%3Cpath d='M8 18h8'/%3E%3Cpath d='M10 21h4'/%3E%3Ccircle cx='10' cy='13' r='1'/%3E%3Ccircle cx='14' cy='15' r='1'/%3E%3C/svg%3E");
                }

                /* Adjust research insight color for dark mode */
                .research-insight {
                    border-left-color: \(PremiumUI.Hex.celadonDark);
                }
                .research-insight .block-header {
                    color: \(PremiumUI.Hex.celadonDark);
                }
                .research-insight .block-content .author-highlight,
                .research-insight .block-content strong[data-author] {
                    color: \(PremiumUI.Hex.celadonDark);
                }
                .takeaways .block-header {
                    color: \(PremiumUI.Hex.celadonDark);
                    border-bottom-color: rgba(var(--celadon-rgb), 0.3);
                }
            }

            /* ═══ REDUCED MOTION ═══ */
            @media (prefers-reduced-motion: reduce) {
                *, *::before, *::after {
                    animation-duration: 0.01ms !important;
                    transition-duration: 0.01ms !important;
                }
            }

            /* ═══ RTL LANGUAGE SUPPORT ═══ */
            [dir="rtl"] {
                text-align: right;
            }
            [dir="rtl"] .insight-note,
            [dir="rtl"] .alternative-perspective,
            [dir="rtl"] .research-insight,
            [dir="rtl"] .action-box,
            [dir="rtl"] .key-takeaways,
            [dir="rtl"] .premium-quote {
                border-left: none;
                border-right: 4px solid var(--accent-coral);
                padding-left: 1.5rem;
                padding-right: 2rem;
            }
            [dir="rtl"] .alternative-perspective {
                border-right-color: var(--accent-teal);
            }
            [dir="rtl"] .research-insight {
                border-right-color: \(PremiumUI.Hex.celadonLight);
            }
            [dir="rtl"] ul, [dir="rtl"] ol {
                padding-right: 1.5rem;
                padding-left: 0;
            }
            [dir="rtl"] blockquote {
                border-left: none;
                border-right: 3px solid var(--primary-gold);
                padding-left: 0;
                padding-right: 1.5rem;
            }

            /* ═══ BASE STYLES ═══ */
            *, *::before, *::after { box-sizing: border-box; }

            html {
                font-size: 17px;
                scroll-behavior: smooth;
                -webkit-font-smoothing: antialiased;
            }

            body {
                font-family: var(--font-display);
                max-width: var(--content-width);
                margin: 0 auto;
                padding: 48px 24px;
                line-height: 1.75;
                font-size: 1.125rem;
                color: var(--text-body);
                background: var(--bg-primary);
            }

            ::selection {
                background: rgba(var(--ember-mark-rgb), 0.25);
                color: var(--text-heading);
            }

            /* ═══ TYPOGRAPHY ═══ */
            h1, h2, h3, h4, h5, h6 {
                font-family: var(--font-display);
                font-weight: 600;
                color: var(--text-heading);
                margin-top: 3rem;
                margin-bottom: 1rem;
                line-height: 1.2;
            }

            h1 { font-size: clamp(2.25rem, 6vw, 3rem); font-weight: 700; margin-top: 0; }
            h2 {
                font-size: 1.875rem;
                position: relative;
                padding-bottom: 0.75rem;
            }
            h2::after {
                content: '';
                position: absolute;
                bottom: 0;
                left: 0;
                width: 60px;
                height: 2px;
                background: linear-gradient(90deg, var(--primary-gold), var(--accent-orange));
                border-radius: 9999px;
            }
            h3 { font-size: 1.5rem; }
            h4 { font-size: 1.25rem; font-weight: 500; }

            p { margin: 0 0 1.25rem 0; }
            strong { color: var(--text-heading); font-weight: 600; }

            /* ═══ PREMIUM COVER PAGE ═══ */
            .cover-page {
                min-height: 100vh;
                display: flex;
                flex-direction: column;
                align-items: center;
                justify-content: center;
                text-align: center;
                padding: 3rem 2rem;
                margin: -48px -24px 3rem -24px;
                background: linear-gradient(135deg, var(--bg-primary) 0%, var(--bg-secondary) 100%);
                position: relative;
                border-bottom: 3px solid var(--primary-gold);
            }
            .cover-page::before {
                content: '';
                position: absolute;
                top: 24px;
                left: 24px;
                right: 24px;
                bottom: 24px;
                border: 1px solid var(--primary-gold);
                border-radius: 4px;
                pointer-events: none;
            }
            .cover-page::after {
                content: '';
                position: absolute;
                top: 28px;
                left: 28px;
                right: 28px;
                bottom: 28px;
                border: 1px solid rgba(var(--ember-mark-rgb), 0.3);
                border-radius: 2px;
                pointer-events: none;
            }

            .cover-top-tagline {
                font-family: var(--font-ui);
                font-size: 0.7rem;
                font-weight: 500;
                letter-spacing: 0.25em;
                color: var(--brand-sepia);
                text-transform: uppercase;
                margin-bottom: 0.75rem;
            }

            .cover-divider {
                width: 80px;
                height: 1px;
                background: var(--primary-gold);
                margin: 0 auto 3rem auto;
            }

            .cover-logo {
                width: 180px;
                height: auto;
                margin-bottom: 3rem;
                opacity: 0.95;
            }

            .cover-logo-placeholder {
                font-size: 4rem;
                color: var(--primary-gold);
                margin-bottom: 3rem;
                line-height: 1;
            }

            .cover-title {
                font-family: var(--font-display);
                font-size: clamp(2.5rem, 8vw, 4rem);
                font-weight: 700;
                color: var(--text-heading);
                line-height: 1.1;
                margin: 0 0 1.5rem 0;
                max-width: 600px;
            }

            .cover-by {
                font-family: var(--font-display);
                font-size: 1rem;
                font-style: italic;
                color: var(--text-muted);
                margin-bottom: 0.25rem;
            }

            .cover-author {
                font-family: var(--font-display);
                font-size: 1.5rem;
                font-weight: 500;
                color: var(--text-body);
                margin-bottom: 2rem;
            }

            .cover-small-divider {
                width: 50px;
                height: 1px;
                background: var(--primary-gold);
                margin: 0 auto 3rem auto;
            }

            .cover-brand {
                font-family: var(--font-display);
                font-size: 1.75rem;
                font-weight: 600;
                color: var(--primary-gold);
                margin-bottom: 0.5rem;
            }

            .cover-subtitle {
                font-family: var(--font-ui);
                font-size: 0.65rem;
                font-weight: 500;
                letter-spacing: 0.2em;
                color: var(--text-muted);
                text-transform: uppercase;
            }

            /* Corner decorations */
            .cover-corner {
                position: absolute;
                width: 16px;
                height: 16px;
                border-color: var(--primary-gold);
                border-style: solid;
            }
            .cover-corner.top-left { top: 36px; left: 36px; border-width: 1px 0 0 1px; }
            .cover-corner.top-right { top: 36px; right: 36px; border-width: 1px 1px 0 0; }
            .cover-corner.bottom-left { bottom: 36px; left: 36px; border-width: 0 0 1px 1px; }
            .cover-corner.bottom-right { bottom: 36px; right: 36px; border-width: 0 1px 1px 0; }

            /* ═══ DOCUMENT HEADER (for content section) ═══ */
            .document-header {
                text-align: center;
                margin-bottom: 4rem;
                padding-bottom: 2.5rem;
                position: relative;
            }
            .header {
                display: flex;
                flex-direction: column;
                align-items: center;
                gap: 0.25rem;
            }
            .header .brand {
                font-family: var(--font-ui);
                font-size: 0.7rem;
                font-weight: 700;
                letter-spacing: 0.2em;
                text-transform: uppercase;
                color: var(--primary-gold);
            }
            .document-header::after {
                content: '';
                position: absolute;
                bottom: 0;
                left: 50%;
                transform: translateX(-50%);
                width: 100px;
                height: 2px;
                background: linear-gradient(90deg, transparent, var(--primary-gold), transparent);
            }

            .header-logo {
                width: 120px;
                height: auto;
                margin-bottom: 1rem;
                opacity: 0.9;
            }

            .footer-logo {
                width: 80px;
                height: auto;
                margin-bottom: 0.75rem;
                opacity: 0.7;
            }

            .brand-badge {
                display: inline-flex;
                font-family: var(--font-ui);
                font-size: 0.7rem;
                font-weight: 600;
                letter-spacing: 0.15em;
                color: var(--primary-gold);
                text-transform: uppercase;
                margin-bottom: 1rem;
                padding: 0.5rem 1.5rem;
                border: 1px solid var(--primary-gold);
                border-radius: 2px;
                background: transparent;
            }

            .document-header h1 {
                font-size: clamp(2.25rem, 7vw, 3.75rem);
                margin: 1rem 0;
                line-height: 1.1;
            }

            .document-header .subtitle {
                font-size: 1.25rem;
                color: var(--text-muted);
                font-style: italic;
                margin-top: 0.5rem;
            }

            .document-header .author {
                font-family: var(--font-ui);
                font-size: 0.875rem;
                color: var(--text-subtle);
                margin-top: 1.25rem;
            }

            .document-header .tagline {
                font-family: var(--font-handwritten);
                font-size: 1.25rem;
                color: var(--accent-coral-text);
                margin-top: 1rem;
                transform: rotate(-1deg);
                display: inline-block;
            }

            /* ═══ READING TIME BADGE ═══ */
            .reading-time-badge {
                display: inline-flex;
                align-items: center;
                gap: 0.5rem;
                background: linear-gradient(135deg, var(--primary-gold) 0%, var(--accent-orange) 100%);
                color: var(--text-inverse);
                font-family: var(--font-ui);
                font-size: 0.75rem;
                font-weight: 600;
                padding: 0.5rem 1rem;
                border-radius: 9999px;
                letter-spacing: 0.02em;
                box-shadow: 0 0 20px rgba(var(--ember-mark-rgb), 0.25);
            }
            .reading-time-badge::before { content: '⏱'; }

            /* ═══ TABLE OF CONTENTS ═══ */
            .table-of-contents {
                background: var(--bg-card);
                border: 1px solid var(--border-light);
                border-radius: var(--radius-xl);
                padding: 2rem;
                margin: 2.5rem 0;
                box-shadow: 0 4px 24px rgba(var(--ink-rgb), 0.06);
            }
            .toc-header {
                display: flex;
                align-items: center;
                gap: 0.75rem;
                margin-bottom: 1.5rem;
                padding-bottom: 1rem;
                border-bottom: 2px solid var(--primary-gold);
            }
            .toc-header h2 {
                margin: 0;
                font-size: 1.5rem;
                flex-grow: 1;
            }
            .toc-header h2::after { display: none; }
            .toc-icon {
                font-size: 1.5rem;
            }
            .toc-list {
                list-style: none;
                padding: 0;
                margin: 0;
                counter-reset: toc-counter;
            }
            .toc-list li {
                margin: 0;
                padding: 0.5rem 0;
                border-bottom: 1px solid var(--border-light);
            }
            .toc-list li:last-child {
                border-bottom: none;
            }
            .toc-list li a {
                display: flex;
                align-items: center;
                color: var(--text-body);
                text-decoration: none;
                border-bottom: none;
                transition: color 0.2s, padding-left 0.2s;
            }
            .toc-list li a:hover {
                color: var(--primary-gold);
                padding-left: 0.5rem;
            }
            .toc-section {
                font-weight: 600;
                font-family: var(--font-display);
                font-size: 1.1rem;
            }
            .toc-section::before {
                counter-increment: toc-counter;
                content: counter(toc-counter) ".";
                margin-right: 0.75rem;
                color: var(--primary-gold);
                font-weight: 700;
                min-width: 1.5rem;
            }
            .toc-subsection {
                padding-left: 2rem;
                font-size: 0.95rem;
                font-weight: 400;
            }
            .toc-subsection::before {
                content: "—";
                margin-right: 0.5rem;
                color: var(--text-muted);
            }

            /* ═══ QUICK GLANCE ═══ */
            .quick-glance {
                background: var(--bg-card);
                backdrop-filter: blur(20px);
                border: 1px solid rgba(var(--ember-mark-rgb), 0.15);
                border-radius: var(--radius-xl);
                padding: 2rem;
                margin: 2.5rem 0;
                box-shadow: 0 4px 24px rgba(var(--ink-rgb), 0.06);
                position: relative;
                overflow: hidden;
            }
            .quick-glance::before {
                content: '';
                position: absolute;
                top: 0;
                left: 0;
                right: 0;
                height: 3px;
                background: linear-gradient(90deg, var(--primary-gold), var(--accent-orange), var(--primary-gold));
            }

            .block-header {
                display: flex;
                align-items: center;
                gap: 0.75rem;
                font-family: var(--font-ui);
                font-weight: 600;
                font-size: 0.875rem;
                letter-spacing: 0.06em;
                text-transform: uppercase;
                margin-bottom: 1.25rem;
                padding-bottom: 1rem;
                border-bottom: 1px solid var(--border-light);
            }
            .quick-glance .block-header { color: var(--primary-gold-dark); }
            .quick-glance .block-header::before { content: '📋'; font-size: 1.125rem; }

            /* ═══ INSIGHT NOTE ═══ */
            .insight-note {
                background: linear-gradient(135deg, rgba(var(--ember-mark-rgb), 0.08) 0%, rgba(var(--ember-mark-rgb), 0.1) 100%);
                border: 1px solid rgba(var(--ember-mark-rgb), 0.25);
                border-left: 4px solid var(--accent-coral);
                border-radius: var(--radius-lg);
                padding: 1.5rem 1.5rem 1.5rem 2rem;
                margin: 2rem 0;
            }
            .insight-note .block-header {
                color: var(--accent-coral-text);
                padding-bottom: 0.75rem;
                border-bottom: none;
            }
            .insight-note .block-header::before {
                content: '';
                display: inline-block;
                width: 24px;
                height: 24px;
                background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='\(PremiumUI.Hex.URLEncoded.ember)' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M9 18h6'/%3E%3Cpath d='M10 22h4'/%3E%3Cpath d='M12 2a7 7 0 0 1 7 7c0 2.38-1.19 4.47-3 5.74V17a1 1 0 0 1-1 1H9a1 1 0 0 1-1-1v-2.26C6.19 13.47 5 11.38 5 9a7 7 0 0 1 7-7z'/%3E%3C/svg%3E");
                background-size: contain;
                background-repeat: no-repeat;
            }
            .insight-note .block-content p:last-child { margin-bottom: 0; }
            /* Author name highlighting in Insight Note */
            .insight-note .block-content .author-highlight,
            .insight-note .block-content strong[data-author] {
                color: var(--accent-coral-text);
                font-weight: 600;
                letter-spacing: 0.02em;
            }
            /* Structured Insight Note sections */
            .insight-note .core-connection {
                margin-bottom: 1rem;
                line-height: 1.7;
            }
            .insight-note .insight-section {
                margin-top: 0.875rem;
                padding: 0.75rem 1rem;
                background: rgba(var(--ember-mark-rgb), 0.05);
                border-radius: var(--radius-md);
                border-left: 3px solid var(--accent-coral);
            }
            .insight-note .insight-label {
                display: block;
                font-family: var(--font-ui);
                font-size: 0.75rem;
                font-weight: 700;
                text-transform: uppercase;
                letter-spacing: 0.08em;
                color: var(--accent-coral-text);
                margin-bottom: 0.375rem;
            }
            .insight-note .insight-text {
                display: block;
                font-size: 0.95rem;
                line-height: 1.6;
                color: var(--text-body);
            }
            .insight-note .go-deeper {
                background: rgba(var(--ember-mark-rgb), 0.08);
                border-left-color: var(--accent-coral);
            }
            .insight-note .go-deeper .insight-text {
                font-style: italic;
            }
            .insight-note .go-deeper .insight-text em {
                font-style: normal;
                font-weight: 600;
                color: var(--accent-coral-text);
            }

            /* ═══ ALTERNATIVE PERSPECTIVE ═══ */
            .alternative-perspective {
                background: linear-gradient(135deg, rgba(var(--celadon-rgb), 0.08) 0%, rgba(var(--celadon-rgb), 0.05) 100%);
                border: 1px solid rgba(var(--celadon-rgb), 0.25);
                border-left: 4px solid var(--accent-teal);
                border-radius: var(--radius-lg);
                padding: 1.5rem 1.5rem 1.5rem 2rem;
                margin: 2rem 0;
            }
            .alternative-perspective .block-header {
                color: var(--accent-teal);
                padding-bottom: 0.75rem;
                border-bottom: none;
            }
            .alternative-perspective .block-header::before {
                content: '';
                display: inline-block;
                width: 24px;
                height: 24px;
                background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='\(PremiumUI.Hex.URLEncoded.celadon)' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M12 3v18'/%3E%3Cpath d='M3 7l3 9h6l3-9'/%3E%3Cpath d='M15 7l3 9h6'/%3E%3Ccircle cx='6' cy='16' r='2'/%3E%3Ccircle cx='18' cy='16' r='2'/%3E%3Cpath d='M3 7h18'/%3E%3C/svg%3E");
                background-size: contain;
                background-repeat: no-repeat;
            }
            .alternative-perspective .block-content p:last-child { margin-bottom: 0; }
            /* Author name highlighting in Alternative Perspective */
            .alternative-perspective .block-content .author-highlight,
            .alternative-perspective .block-content strong[data-author] {
                color: var(--accent-teal);
                font-weight: 600;
                letter-spacing: 0.02em;
            }

            /* ═══ RESEARCH INSIGHT ═══ */
            .research-insight {
                background: linear-gradient(135deg, rgba(var(--celadon-rgb), 0.10) 0%, rgba(var(--celadon-rgb), 0.05) 100%);
                border: 1px solid rgba(var(--celadon-rgb), 0.30);
                border-left: 4px solid \(PremiumUI.Hex.celadonLight);
                border-radius: var(--radius-lg);
                padding: 1.5rem 1.5rem 1.5rem 2rem;
                margin: 2rem 0;
            }
            .research-insight .block-header {
                color: \(PremiumUI.Hex.celadonLight);
                padding-bottom: 0.75rem;
                border-bottom: none;
            }
            .research-insight .block-header::before {
                content: '';
                display: inline-block;
                width: 24px;
                height: 24px;
                background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='\(PremiumUI.Hex.URLEncoded.celadon)' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M9 3h6v6l3 9H6l3-9V3z'/%3E%3Cpath d='M9 3h6'/%3E%3Cpath d='M8 18h8'/%3E%3Cpath d='M10 21h4'/%3E%3Ccircle cx='10' cy='13' r='1'/%3E%3Ccircle cx='14' cy='15' r='1'/%3E%3C/svg%3E");
                background-size: contain;
                background-repeat: no-repeat;
            }
            .research-insight .block-content p:last-child { margin-bottom: 0; }
            /* Author name highlighting in Research Insight */
            .research-insight .block-content .author-highlight,
            .research-insight .block-content strong[data-author] {
                color: \(PremiumUI.Hex.celadonLight);
                font-weight: 600;
                letter-spacing: 0.02em;
            }

            /* ═══ ACTION BOX ═══ */
            .action-box {
                background: rgba(var(--celadon-rgb), 0.08);
                border: 2px solid rgba(var(--celadon-rgb), 0.25);
                border-radius: var(--radius-xl);
                padding: 1.5rem 2rem;
                margin: 2rem 0;
            }
            .action-box .block-header {
                color: var(--accent-teal);
                border-bottom: 1px solid rgba(var(--celadon-rgb), 0.25);
            }
            .action-box .block-header::before {
                content: '✓';
                font-weight: 700;
                width: 22px;
                height: 22px;
                display: flex;
                align-items: center;
                justify-content: center;
                background: var(--accent-teal);
                color: var(--text-inverse);
                border-radius: 9999px;
                font-size: 0.75rem;
            }
            .action-box ol {
                counter-reset: action-counter;
                list-style: none;
                padding-left: 0;
            }
            .action-box ol li {
                counter-increment: action-counter;
                padding-left: 2.5rem;
                position: relative;
                margin-bottom: 1rem;
            }
            .action-box ol li::before {
                content: counter(action-counter);
                position: absolute;
                left: 0;
                top: 2px;
                width: 26px;
                height: 26px;
                display: flex;
                align-items: center;
                justify-content: center;
                background: linear-gradient(135deg, var(--accent-teal) 0%, \(PremiumUI.Hex.celadonLight) 100%);
                color: var(--text-inverse);
                font-family: var(--font-ui);
                font-weight: 600;
                font-size: 0.875rem;
                border-radius: 9999px;
            }

            /* ═══ EXERCISE ═══ */
            .exercise {
                background: linear-gradient(135deg, rgba(var(--celadon-rgb), 0.08) 0%, rgba(var(--celadon-rgb), 0.04) 100%);
                border: 2px solid rgba(var(--celadon-rgb), 0.25);
                border-radius: var(--radius-xl);
                padding: 2rem;
                margin: 2.5rem 0;
                position: relative;
            }
            .exercise::before {
                content: '✏️';
                position: absolute;
                top: -15px;
                right: -15px;
                font-size: 70px;
                opacity: 0.06;
                transform: rotate(15deg);
            }
            .exercise .block-header {
                color: var(--accent-teal);
                border-bottom: 1px solid rgba(var(--celadon-rgb), 0.25);
            }
            .exercise .block-header::before { content: '✏️'; font-size: 1.125rem; }

            /* ═══ TAKEAWAYS ═══ */
            .takeaways {
                background: linear-gradient(135deg, rgba(var(--celadon-rgb), 0.1) 0%, rgba(var(--celadon-rgb), 0.04) 100%);
                border: 2px solid rgba(var(--celadon-rgb), 0.3);
                border-radius: var(--radius-xl);
                padding: 2rem;
                margin: 2.5rem 0;
            }
            .takeaways .block-header {
                color: \(PremiumUI.Hex.celadonLight);
                border-bottom: 1px solid rgba(var(--celadon-rgb), 0.25);
            }
            .takeaways .block-header::before { content: '🎯'; font-size: 1.125rem; }

            /* ═══ FOUNDATIONAL NARRATIVE ═══ */
            .foundational-narrative {
                background: linear-gradient(135deg, var(--bg-secondary) 0%, var(--brand-parchment) 100%);
                border-left: 4px solid var(--primary-gold);
                border-radius: 0 var(--radius-xl) var(--radius-xl) 0;
                padding: 1.5rem 2rem;
                margin: 2rem 0;
            }
            .foundational-narrative .block-header {
                color: var(--brand-sepia);
                border-bottom: 1px solid var(--border-medium);
            }
            .foundational-narrative .block-header::before { content: '📖'; font-size: 1.125rem; }

            /* ═══ VISUAL FLOWCHART ═══ */
            .visual-flowchart {
                background: linear-gradient(135deg, var(--primary-gold-subtle) 0%, rgba(var(--ember-mark-rgb), 0.1) 100%);
                border: 2px solid rgba(var(--ember-mark-rgb), 0.25);
                border-radius: var(--radius-xl);
                padding: 2rem;
                margin: 2.5rem 0;
            }
            .visual-flowchart .block-header {
                color: var(--primary-gold-dark);
                border-bottom: 1px solid rgba(var(--ember-mark-rgb), 0.25);
            }
            .visual-flowchart .block-header::before { content: '📊'; font-size: 1.125rem; }

            .flow-container {
                display: flex;
                flex-direction: column;
                align-items: center;
                gap: 0.5rem;
            }
            .flow-step {
                width: 100%;
                max-width: 380px;
                padding: 1rem 1.5rem;
                background: var(--bg-card);
                border: 2px solid rgba(var(--ember-mark-rgb), 0.25);
                border-radius: var(--radius-lg);
                font-family: var(--font-ui);
                font-weight: 500;
                font-size: 1rem;
                color: var(--text-heading);
                text-align: center;
                box-shadow: 0 2px 4px rgba(var(--ink-rgb), 0.04);
            }
            .flow-arrow {
                color: var(--primary-gold);
                font-size: 1.5rem;
                font-weight: 700;
            }

            /* ═══ VISUAL TABLE ═══ */
            .visual-table {
                background: linear-gradient(135deg, var(--bg-card) 0%, var(--bg-secondary) 100%);
                border: 1px solid var(--border-medium);
                border-radius: var(--radius-xl);
                padding: 2rem;
                margin: 2.5rem 0;
            }
            .visual-table .block-header {
                color: var(--primary-gold-dark);
                border-bottom: 1px solid var(--border-light);
            }
            .visual-table .block-header::before { content: '📋'; font-size: 1.125rem; }

            /* ═══ VISUAL COMPARISON ═══ */
            .visual-comparison {
                background: linear-gradient(135deg, rgba(var(--ember-mark-rgb), 0.08) 0%, rgba(var(--ember-mark-rgb), 0.03) 100%);
                border: 2px solid rgba(var(--ember-mark-rgb), 0.25);
                border-radius: var(--radius-xl);
                padding: 2rem;
                margin: 2.5rem 0;
            }
            .visual-comparison .block-header {
                color: var(--primary-gold-dark);
                border-bottom: 1px solid rgba(var(--ember-mark-rgb), 0.25);
            }
            .visual-comparison .block-header::before { content: '◧'; font-size: 1.125rem; }

            /* ═══ VISUAL TIMELINE ═══ */
            .visual-timeline {
                background: linear-gradient(135deg, rgba(var(--celadon-rgb), 0.08) 0%, rgba(var(--celadon-rgb), 0.03) 100%);
                border: 2px solid rgba(var(--celadon-rgb), 0.25);
                border-radius: var(--radius-xl);
                padding: 2rem;
                margin: 2.5rem 0;
            }
            .visual-timeline .block-header {
                color: var(--accent-teal-text);
                border-bottom: 1px solid rgba(var(--celadon-rgb), 0.25);
            }
            .visual-timeline .block-header::before { content: '🗓'; font-size: 1.125rem; }

            /* ═══ VISUAL CONCEPT MAP ═══ */
            .visual-concept-map {
                background: linear-gradient(135deg, rgba(var(--ember-mark-rgb), 0.08) 0%, rgba(var(--ember-mark-rgb), 0.03) 100%);
                border: 2px solid rgba(var(--ember-mark-rgb), 0.25);
                border-radius: var(--radius-xl);
                padding: 2rem;
                margin: 2.5rem 0;
            }
            .visual-concept-map .block-header {
                color: var(--accent-coral-text);
                border-bottom: 1px solid rgba(var(--ember-mark-rgb), 0.25);
            }
            .visual-concept-map .block-header::before { content: '🗺️'; font-size: 1.125rem; }

            /* ═══ VISUAL NETWORK ═══ */
            .visual-network {
                background: linear-gradient(135deg, rgba(var(--celadon-rgb), 0.08) 0%, rgba(var(--celadon-rgb), 0.03) 100%);
                border: 2px solid rgba(var(--celadon-rgb), 0.25);
                border-radius: var(--radius-xl);
                padding: 2rem;
                margin: 2.5rem 0;
            }
            .visual-network .block-header {
                color: var(--accent-teal-text);
                border-bottom: 1px solid rgba(var(--celadon-rgb), 0.25);
            }
            .visual-network .block-header::before { content: '🧩'; font-size: 1.125rem; }

            /* ═══ VISUAL QUADRANT ═══ */
            .visual-quadrant {
                background: linear-gradient(135deg, rgba(var(--ember-mark-rgb), 0.1) 0%, rgba(var(--ember-mark-rgb), 0.03) 100%);
                border: 2px solid rgba(var(--ember-mark-rgb), 0.25);
                border-radius: var(--radius-xl);
                padding: 2rem;
                margin: 2.5rem 0;
            }
            .visual-quadrant .block-header {
                color: var(--accent-orange-text);
                border-bottom: 1px solid rgba(var(--ember-mark-rgb), 0.25);
            }
            .visual-quadrant .block-header::before { content: '▣'; font-size: 1.125rem; }

            /* ═══ VISUAL CHART ═══ */
            .visual-chart {
                background: linear-gradient(135deg, rgba(var(--ember-mark-rgb), 0.12) 0%, rgba(var(--ember-mark-rgb), 0.04) 100%);
                border: 2px solid rgba(var(--ember-mark-rgb), 0.25);
                border-radius: var(--radius-xl);
                padding: 2rem;
                margin: 2.5rem 0;
            }
            .visual-chart .block-header {
                color: var(--accent-orange-text);
                border-bottom: 1px solid rgba(var(--ember-mark-rgb), 0.25);
            }
            .visual-chart .block-header::before { content: '📈'; font-size: 1.125rem; }

            /* ═══ VISUAL DIAGRAM ═══ */
            .visual-diagram {
                background: linear-gradient(135deg, rgba(var(--indigo-rgb), 0.08) 0%, rgba(var(--indigo-rgb), 0.03) 100%);
                border: 2px solid rgba(var(--indigo-rgb), 0.25);
                border-radius: var(--radius-xl);
                padding: 2rem;
                margin: 2.5rem 0;
            }
            .visual-diagram .block-header {
                color: var(--accent-teal-text);
                border-bottom: 1px solid rgba(var(--indigo-rgb), 0.25);
            }
            .visual-diagram .block-header::before { content: '🧭'; font-size: 1.125rem; }

            /* ═══ VISUAL ELEMENTS ═══ */
            .visual-subheader {
                font-family: var(--font-ui);
                font-weight: 600;
                font-size: 0.85rem;
                text-transform: uppercase;
                letter-spacing: 0.08em;
                color: var(--text-muted);
                margin: 1rem 0 0.5rem;
            }
            .visual-list {
                margin: 0;
                padding-left: 1.1rem;
                color: var(--text-body);
            }
            .visual-list li { margin-bottom: 0.4rem; }
            .visual-muted { color: var(--text-subtle); }
            .visual-dot {
                display: inline-block;
                width: 8px;
                height: 8px;
                border-radius: 50%;
                background: var(--primary-gold);
                margin-right: 0.5rem;
            }
            .visual-callout {
                background: var(--bg-secondary);
                border-left: 3px solid var(--primary-gold);
                padding: 0.6rem 0.8rem;
                border-radius: 6px;
                margin-top: 0.75rem;
            }

            .visual-chips {
                display: flex;
                flex-wrap: wrap;
                gap: 0.5rem;
            }
            .visual-chip {
                background: var(--bg-secondary);
                border: 1px solid var(--border-light);
                border-radius: 9999px;
                padding: 0.35rem 0.7rem;
                font-family: var(--font-ui);
                font-size: 0.85rem;
            }

            .visual-bars {
                display: flex;
                flex-direction: column;
                gap: 0.6rem;
            }
            .visual-bar-row {
                display: grid;
                grid-template-columns: 1fr 3fr auto;
                gap: 0.8rem;
                align-items: center;
            }
            .visual-bar-track {
                background: var(--bg-secondary);
                border-radius: 9999px;
                height: 8px;
                overflow: hidden;
            }
            .visual-bar-fill {
                height: 100%;
                background: linear-gradient(90deg, var(--primary-gold), var(--accent-orange));
            }
            .visual-bar-label {
                font-family: var(--font-ui);
                font-size: 0.9rem;
                color: var(--text-body);
            }
            .visual-bar-value {
                font-family: var(--font-ui);
                font-size: 0.85rem;
                color: var(--text-muted);
            }

            .visual-timeline-list {
                display: grid;
                gap: 0.8rem;
            }
            .timeline-item {
                background: var(--bg-card);
                border: 1px solid var(--border-light);
                border-radius: var(--radius-lg);
                padding: 0.9rem 1rem;
            }
            .timeline-date {
                font-family: var(--font-ui);
                font-size: 0.8rem;
                text-transform: uppercase;
                letter-spacing: 0.08em;
                color: var(--text-muted);
            }
            .timeline-title {
                font-family: var(--font-display);
                font-size: 1.05rem;
                color: var(--text-heading);
                margin-top: 0.2rem;
            }
            .timeline-desc {
                color: var(--text-body);
                margin-top: 0.35rem;
            }

            .visual-quadrant-grid {
                position: relative;
                display: grid;
                grid-template-columns: 1fr 1fr;
                gap: 0.75rem;
            }
            .quadrant-axis {
                position: absolute;
                font-family: var(--font-ui);
                font-size: 0.75rem;
                color: var(--text-subtle);
                text-transform: uppercase;
                letter-spacing: 0.08em;
            }
            .quadrant-axis-x { bottom: -1.25rem; left: 0; }
            .quadrant-axis-y { top: 0; left: -1.5rem; transform: rotate(-90deg); transform-origin: left top; }
            .quadrant-cell {
                background: var(--bg-card);
                border: 1px solid var(--border-light);
                border-radius: var(--radius-lg);
                padding: 0.75rem 1rem;
            }
            .quadrant-title {
                font-family: var(--font-ui);
                font-weight: 600;
                margin-bottom: 0.4rem;
            }
            .quadrant-items { margin: 0; padding-left: 1.1rem; }

            .hierarchy-root {
                font-family: var(--font-display);
                font-size: 1.1rem;
                color: var(--text-heading);
                margin-bottom: 0.5rem;
            }
            .hierarchy-list { margin: 0; padding-left: 1.2rem; }

            .visual-grid-2x2 {
                display: grid;
                grid-template-columns: 1fr 1fr;
                gap: 0.8rem;
            }
            .visual-cell {
                background: var(--bg-card);
                border: 1px solid var(--border-light);
                border-radius: var(--radius-lg);
                padding: 0.8rem 1rem;
            }
            .visual-cell-title {
                font-family: var(--font-ui);
                font-weight: 600;
                margin-bottom: 0.4rem;
            }
            .visual-cell ul { margin: 0; padding-left: 1.1rem; }

            .gantt-list, .funnel-list, .fishbone-list, .story-list, .journey-list {
                display: grid;
                gap: 0.8rem;
            }
            .gantt-row {
                display: grid;
                grid-template-columns: 1fr 3fr auto;
                gap: 0.8rem;
                align-items: center;
            }
            .gantt-track {
                background: var(--bg-secondary);
                border-radius: 9999px;
                height: 8px;
                overflow: hidden;
            }
            .gantt-bar { height: 100%; background: var(--primary-gold); }
            .gantt-meta { font-size: 0.8rem; color: var(--text-subtle); }

            .funnel-step {
                display: grid;
                grid-template-columns: 1fr 3fr auto;
                gap: 0.8rem;
                align-items: center;
            }
            .funnel-bar {
                height: 10px;
                border-radius: 9999px;
                background: linear-gradient(90deg, var(--accent-orange), var(--primary-gold));
            }
            .funnel-value { font-size: 0.8rem; color: var(--text-subtle); }

            .pyramid-list {
                display: grid;
                gap: 0.5rem;
            }
            .pyramid-level {
                background: var(--bg-secondary);
                border-radius: 6px;
                padding: 0.5rem 0.75rem;
            }

            .cycle-list {
                display: flex;
                flex-wrap: wrap;
                align-items: center;
                gap: 0.5rem;
            }
            .cycle-step {
                background: var(--bg-secondary);
                border-radius: 9999px;
                padding: 0.35rem 0.7rem;
                font-family: var(--font-ui);
                font-size: 0.85rem;
            }
            .cycle-arrow { color: var(--text-subtle); }

            .fishbone-row {
                background: var(--bg-card);
                border: 1px solid var(--border-light);
                border-radius: var(--radius-lg);
                padding: 0.75rem 1rem;
            }
            .fishbone-title {
                font-family: var(--font-ui);
                font-weight: 600;
                margin-bottom: 0.4rem;
            }
            .fishbone-row ul { margin: 0; padding-left: 1.1rem; }

            .stat-grid {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
                gap: 0.8rem;
            }
            .stat-card {
                background: var(--bg-card);
                border: 1px solid var(--border-light);
                border-radius: var(--radius-lg);
                padding: 0.9rem 1rem;
                text-align: center;
            }
            .stat-value {
                font-family: var(--font-display);
                font-size: 1.3rem;
                color: var(--text-heading);
            }
            .stat-label { font-size: 0.85rem; color: var(--text-muted); }

            .story-card {
                background: var(--bg-card);
                border: 1px solid var(--border-light);
                border-radius: var(--radius-lg);
                padding: 0.8rem 1rem;
            }
            .story-title {
                font-family: var(--font-ui);
                font-weight: 600;
            }
            .story-desc { margin-top: 0.35rem; color: var(--text-body); }

            .journey-stage {
                background: var(--bg-card);
                border: 1px solid var(--border-light);
                border-radius: var(--radius-lg);
                padding: 0.8rem 1rem;
            }
            .journey-title {
                font-family: var(--font-ui);
                font-weight: 600;
                display: flex;
                align-items: center;
                gap: 0.5rem;
            }
            .journey-emotion {
                font-size: 0.75rem;
                text-transform: uppercase;
                letter-spacing: 0.08em;
                color: var(--text-subtle);
            }
            .journey-touchpoints { margin: 0.4rem 0 0; padding-left: 1.1rem; }

            /* ═══ GENERIC VISUAL ═══ */
            .visual-generic {
                background: linear-gradient(135deg, var(--bg-card) 0%, var(--bg-secondary) 100%);
                border: 1px solid var(--border-medium);
                border-radius: var(--radius-xl);
                padding: 2rem;
                margin: 2.5rem 0;
            }
            .visual-generic .block-header {
                color: var(--primary-gold-dark);
                border-bottom: 1px solid var(--border-light);
            }
            .visual-generic .block-header::before { content: '📌'; font-size: 1.125rem; }

            /* ═══ PROCESS TIMELINE ═══ */
            .process-timeline {
                background: linear-gradient(135deg, var(--bg-secondary) 0%, var(--bg-card) 100%);
                border: 1px solid var(--border-medium);
                border-radius: var(--radius-xl);
                padding: 2rem;
                margin: 2.5rem 0;
            }
            .process-timeline .block-header {
                color: var(--primary-gold-dark);
                border-bottom: 1px solid var(--border-light);
            }
            .process-timeline .block-header::before { content: '⟶'; font-size: 1.125rem; }
            .timeline-container {
                display: flex;
                flex-direction: column;
                gap: 1.5rem;
                padding-top: 1rem;
            }
            .timeline-step {
                display: flex;
                align-items: flex-start;
                gap: 1rem;
            }
            .timeline-number {
                width: 36px;
                height: 36px;
                border-radius: 50%;
                background: linear-gradient(135deg, var(--primary-gold) 0%, var(--accent-orange) 100%);
                color: white;
                font-family: var(--font-ui);
                font-weight: 700;
                font-size: 1rem;
                display: flex;
                align-items: center;
                justify-content: center;
                flex-shrink: 0;
                box-shadow: 0 2px 6px rgba(var(--ember-mark-rgb), 0.3);
            }
            .timeline-content {
                flex: 1;
                padding-top: 0.5rem;
            }
            .timeline-content p {
                margin: 0;
                font-family: var(--font-ui);
                font-weight: 500;
                color: var(--text-heading);
            }
            .timeline-connector {
                width: 2px;
                height: 24px;
                background: linear-gradient(to bottom, var(--primary-gold), var(--primary-gold-light));
                margin-left: 17px;
            }

            /* ═══ CONCEPT MAP ═══ */
            .concept-map {
                background: linear-gradient(135deg, var(--bg-secondary) 0%, var(--bg-card) 100%);
                border: 1px solid var(--border-medium);
                border-radius: var(--radius-xl);
                padding: 2rem;
                margin: 2.5rem 0;
            }
            .concept-map .block-header {
                color: var(--primary-gold-dark);
                border-bottom: 1px solid var(--border-light);
            }
            .concept-map .block-header::before { content: '🗺️'; font-size: 1.125rem; }

            /* ═══ STRUCTURE MAP ═══ */
            .structure-map {
                background: linear-gradient(135deg, var(--bg-card) 0%, var(--bg-secondary) 100%);
                border: 1px solid var(--border-medium);
                border-radius: var(--radius-xl);
                padding: 2rem;
                margin: 2.5rem 0;
            }
            .structure-map .block-header {
                color: var(--primary-gold-dark);
                border-bottom: 1px solid var(--border-light);
            }
            .structure-map .block-header::before { content: '🧭'; font-size: 1.125rem; }
            .concept-map-container {
                display: flex;
                flex-direction: column;
                align-items: center;
                gap: 1.5rem;
                padding-top: 1rem;
            }
            .concept-central {
                padding: 1.25rem 2rem;
                background: linear-gradient(135deg, var(--primary-gold-subtle) 0%, rgba(var(--ember-mark-rgb), 0.15) 100%);
                border: 2px solid var(--primary-gold);
                border-radius: 50px;
                font-family: var(--font-display);
                font-weight: 600;
                font-size: 1.25rem;
                color: var(--primary-gold-dark);
                text-align: center;
            }
            .concept-related {
                display: flex;
                flex-wrap: wrap;
                justify-content: center;
                gap: 1rem;
            }
            .concept-node {
                padding: 0.75rem 1.25rem;
                background: var(--bg-card);
                border: 1.5px solid var(--accent-teal);
                border-radius: var(--radius-lg);
                font-family: var(--font-ui);
                font-size: 0.9rem;
                color: var(--text-body);
                position: relative;
            }
            .concept-node::before {
                content: '';
                position: absolute;
                top: -12px;
                left: 50%;
                transform: translateX(-50%);
                width: 1px;
                height: 12px;
                background: var(--primary-gold);
            }

            /* ═══ BLOCKQUOTE ═══ */
            blockquote {
                position: relative;
                margin: 2rem 0;
                padding: 2rem;
                padding-left: 2.5rem;
                background: var(--bg-card);
                border-left: 3px solid var(--primary-gold);
                border-radius: 0 var(--radius-xl) var(--radius-xl) 0;
                box-shadow: 0 2px 4px rgba(var(--ink-rgb), 0.04);
            }
            blockquote::before {
                content: '"';
                position: absolute;
                top: 0.75rem;
                left: 0.75rem;
                font-family: var(--font-display);
                font-size: 3rem;
                color: rgba(var(--ember-mark-rgb), 0.25);
                line-height: 1;
            }
            blockquote p {
                font-style: italic;
                color: var(--text-muted);
                font-size: 1.125rem;
                margin: 0;
            }
            blockquote cite {
                display: block;
                margin-top: 1rem;
                font-family: var(--font-handwritten);
                font-size: 1.125rem;
                font-style: normal;
                color: var(--accent-coral-text);
            }
            blockquote cite::before { content: '— '; }

            /* ═══ TABLES ═══ */
            .styled-table {
                width: 100%;
                border-collapse: separate;
                border-spacing: 0;
                font-family: var(--font-ui);
                font-size: 0.875rem;
                border-radius: var(--radius-xl);
                overflow: hidden;
                box-shadow: 0 2px 8px rgba(var(--ink-rgb), 0.04);
                margin: 1.5rem 0;
            }
            .styled-table thead th {
                background: linear-gradient(135deg, var(--primary-gold) 0%, var(--accent-orange) 100%);
                color: var(--text-inverse);
                font-weight: 600;
                padding: 1rem 1.25rem;
                text-align: left;
                letter-spacing: 0.02em;
                white-space: nowrap;
            }
            .styled-table tbody td {
                padding: 1rem 1.25rem;
                background: var(--bg-card);
                border-bottom: 1px solid var(--border-light);
                vertical-align: top;
            }
            .styled-table tbody tr.odd-row td {
                background: var(--bg-secondary);
            }
            .styled-table tbody tr:last-child td { border-bottom: none; }
            .styled-table tbody tr:hover td { background: var(--primary-gold-subtle); }

            /* Responsive table wrapper */
            @media (max-width: 640px) {
                .styled-table {
                    display: block;
                    overflow-x: auto;
                    -webkit-overflow-scrolling: touch;
                }
                .styled-table thead th,
                .styled-table tbody td {
                    padding: 0.75rem 1rem;
                    font-size: 0.8rem;
                }
            }

            /* ═══ LISTS ═══ */
            ul, ol { padding-left: 1.5rem; margin: 1rem 0; }
            li { margin: 0.5rem 0; line-height: 1.5; }
            li::marker { color: var(--primary-gold); }

            /* ═══ SECTION DIVIDER ═══ */
            hr.section-divider {
                border: none;
                height: 2px;
                background: linear-gradient(90deg, transparent, var(--primary-gold), transparent);
                margin: 3rem 0;
            }

            .section-divider-ornament {
                border: none;
                text-align: center;
                margin: 3rem 0;
            }
            .section-divider-ornament::before {
                content: '◆ ◇ ◆';
                font-size: 0.875rem;
                color: var(--primary-gold);
                letter-spacing: 0.5em;
            }

            /* Premium Ornament Divider (converted from ═══ markdown) */
            .premium-ornament-divider {
                text-align: center;
                margin: 2.5rem 0;
                padding: 1rem 0;
            }
            .premium-ornament-divider .ornament {
                font-size: 1rem;
                color: var(--primary-gold);
                letter-spacing: 0.75em;
                opacity: 0.85;
            }

            /* ═══ PREMIUM QUOTE ═══ */
            .premium-quote {
                position: relative;
                margin: 2.5rem 0;
                padding: 2rem 2rem 2rem 2.5rem;
                background: var(--bg-card);
                border-left: 4px solid var(--accent-coral);
                border-radius: 0 var(--radius-xl) var(--radius-xl) 0;
                box-shadow: 0 4px 16px rgba(var(--ink-rgb), 0.06);
            }
            .premium-quote-mark {
                position: absolute;
                top: -0.5rem;
                right: 1.5rem;
                font-family: var(--font-display);
                font-size: 5rem;
                font-weight: 700;
                color: rgba(var(--ember-mark-rgb), 0.2);
                line-height: 1;
                pointer-events: none;
            }
            .premium-quote blockquote {
                margin: 0;
                padding: 0;
                border: none;
                background: transparent;
                box-shadow: none;
            }
            .premium-quote blockquote::before {
                display: none;
            }
            .premium-quote blockquote p {
                font-family: var(--font-display);
                font-size: 1.25rem;
                font-style: italic;
                color: var(--text-body);
                line-height: 1.6;
                margin: 0 0 1rem 0;
            }
            .premium-quote blockquote cite {
                display: block;
                text-align: right;
                font-family: var(--font-display);
                font-size: 1rem;
                font-style: normal;
                font-weight: 600;
                color: var(--accent-coral-text);
                margin-top: 1rem;
            }
            .premium-quote blockquote cite::before {
                content: '— ';
            }
            .premium-quote-source {
                display: block;
                font-weight: 400;
                font-style: italic;
                color: var(--text-muted);
                font-size: 0.9rem;
                margin-top: 0.25rem;
            }

            /* ═══ AUTHOR SPOTLIGHT ═══ */
            .author-spotlight {
                position: relative;
                margin: 3rem 0;
                padding: 2rem;
                background: var(--bg-card);
                border: 2px solid var(--primary-gold);
                border-radius: var(--radius-xl);
                box-shadow: 0 4px 20px rgba(var(--ember-mark-rgb), 0.1);
            }
            .author-spotlight::before {
                content: '';
                position: absolute;
                top: 4px;
                left: 4px;
                right: 4px;
                bottom: 4px;
                border: 1px solid rgba(var(--ember-mark-rgb), 0.4);
                border-radius: calc(var(--radius-xl) - 4px);
                pointer-events: none;
            }
            .author-spotlight-header {
                display: flex;
                align-items: center;
                gap: 0.75rem;
                margin-bottom: 1rem;
                padding-bottom: 0.75rem;
                border-bottom: 1px solid var(--border-light);
            }
            .author-spotlight-icon {
                font-size: 1.25rem;
            }
            .author-spotlight-label {
                font-family: var(--font-ui);
                font-size: 0.7rem;
                font-weight: 600;
                letter-spacing: 0.15em;
                color: var(--primary-gold);
                text-transform: uppercase;
            }
            .author-spotlight-name {
                font-family: var(--font-display);
                font-size: 1.75rem;
                font-weight: 600;
                color: var(--accent-coral-text);
                margin: 0 0 0.75rem 0;
                padding: 0;
            }
            .author-spotlight-name::after {
                display: none;
            }
            .author-spotlight-bio {
                font-family: var(--font-display);
                font-size: 1.05rem;
                color: var(--text-body);
                line-height: 1.7;
                margin: 0;
            }

            /* ═══ PREMIUM DIVIDER ═══ */
            .premium-divider {
                display: flex;
                align-items: center;
                justify-content: center;
                gap: 1rem;
                margin: 3rem 0;
                padding: 1rem 0;
            }
            .premium-divider-line {
                flex: 1;
                max-width: 120px;
                height: 1px;
                background: linear-gradient(90deg, transparent, var(--primary-gold));
            }
            .premium-divider-line:last-child {
                background: linear-gradient(90deg, var(--primary-gold), transparent);
            }
            .premium-divider-diamond,
            .premium-divider-diamond-outline {
                font-size: 0.75rem;
                color: var(--primary-gold);
                line-height: 1;
            }
            .premium-divider-diamond-outline {
                font-size: 0.625rem;
                opacity: 0.7;
            }

            /* ═══ PREMIUM H1 HEADER ═══ */
            .premium-h1 {
                text-align: center;
                margin: 4rem 0 3rem 0;
            }
            .premium-h1-ornaments {
                display: flex;
                align-items: center;
                justify-content: center;
                gap: 0.5rem;
                margin-bottom: 1rem;
            }
            .premium-h1-ornaments:last-child {
                margin-bottom: 0;
                margin-top: 1rem;
            }
            .premium-h1 .diamond-filled,
            .premium-h1 .diamond-outline {
                font-size: 0.625rem;
                color: var(--primary-gold);
            }
            .premium-h1 .diamond-outline {
                font-size: 0.5rem;
                opacity: 0.6;
            }
            .premium-h1 h1 {
                font-family: var(--font-display);
                font-size: 1.5rem;
                font-weight: 700;
                letter-spacing: 0.1em;
                color: var(--primary-gold);
                margin: 0;
                padding: 0;
            }

            /* ═══ PREMIUM H2 HEADER ═══ */
            h2.premium-h2 {
                display: flex;
                align-items: center;
                gap: 1rem;
                margin: 3rem 0 1.5rem 0;
                font-family: var(--font-display);
                font-size: 1.5rem;
                font-weight: 600;
                color: var(--text-heading);
                padding-left: 1.25rem;
                position: relative;
            }
            h2.premium-h2::before {
                content: '';
                position: absolute;
                left: 0;
                top: 50%;
                transform: translateY(-50%);
                width: 4px;
                height: 28px;
                background: var(--primary-gold);
                border-radius: 2px;
            }
            h2.premium-h2::after {
                display: none;
            }
            .premium-h2-bar {
                width: 4px;
                height: 28px;
                background: var(--primary-gold);
                border-radius: 2px;
                flex-shrink: 0;
            }
            .premium-h2 h2 {
                font-family: var(--font-display);
                font-size: 1.5rem;
                font-weight: 600;
                color: var(--text-heading);
                margin: 0;
                padding: 0;
            }
            .premium-h2 h2::after {
                display: none;
            }

            /* Premium H2 with category label wrapper */
            .premium-h2-wrapper {
                margin: 3rem 0 1.5rem 0;
                padding-left: 1.25rem;
                position: relative;
            }
            .premium-h2-wrapper::before {
                content: '';
                position: absolute;
                left: 0;
                top: 0;
                bottom: 0;
                width: 4px;
                background: var(--primary-gold);
                border-radius: 2px;
            }
            .premium-h2-wrapper .section-category {
                display: block;
                font-family: var(--font-ui);
                font-size: 0.7rem;
                font-weight: 600;
                letter-spacing: 0.15em;
                text-transform: uppercase;
                color: var(--text-muted);
                margin-bottom: 0.25rem;
            }
            .premium-h2-wrapper h2 {
                font-family: var(--font-display);
                font-size: 1.75rem;
                font-weight: 600;
                color: var(--text-heading);
                margin: 0;
                padding: 0;
                line-height: 1.2;
            }
            .premium-h2-wrapper h2::after {
                display: none;
            }

            /* ═══ PREMIUM PART HEADER ═══ */
            .premium-part-header {
                text-align: center;
                margin: 4rem 0 3rem 0;
                padding: 2rem 0;
            }
            .premium-part-header .part-ornament {
                font-size: 0.875rem;
                color: var(--primary-gold);
                letter-spacing: 0.5em;
                margin: 1rem 0;
            }
            .premium-part-header .part-title {
                font-family: var(--font-display);
                font-size: 2rem;
                font-weight: 700;
                letter-spacing: 0.15em;
                text-transform: uppercase;
                color: var(--primary-gold);
                margin: 0;
                padding: 0;
            }

            /* ═══ LINKS ═══ */
            a {
                color: var(--accent-burgundy);
                text-decoration: none;
                border-bottom: 1px solid rgba(var(--destructive-rgb), 0.3);
                transition: border-color 0.25s;
            }
            a:hover { border-bottom-color: var(--accent-burgundy); }

            /* ═══ CODE ═══ */
            code {
                background: rgba(var(--ember-mark-rgb), 0.15);
                padding: 2px 6px;
                border-radius: 4px;
                font-family: 'SF Mono', Monaco, monospace;
                font-size: 0.9em;
            }

            /* ═══ FOOTER ═══ */
            .document-footer {
                text-align: center;
                margin-top: 4rem;
                padding-top: 2.5rem;
                border-top: 1px solid var(--border-light);
                font-family: var(--font-ui);
                font-size: 0.875rem;
                color: var(--text-subtle);
            }
            .document-footer .brand-footer {
                font-weight: 600;
                color: var(--brand-sepia);
                letter-spacing: 0.06em;
            }
            .document-footer .tagline-footer {
                font-family: var(--font-handwritten);
                font-size: 1.125rem;
                color: var(--text-muted);
                margin-top: 0.5rem;
            }

            /* ═══ RESPONSIVE ═══ */
            @media (max-width: 640px) {
                html { font-size: 16px; }
                body { padding: 1.5rem 1rem; }
                .document-header h1 { font-size: 2.25rem; }
                .quick-glance, .insight-note, .action-box, .exercise,
                .visual-flowchart, .visual-table, .visual-comparison, .visual-timeline,
                .visual-concept-map, .visual-network, .visual-quadrant, .visual-chart,
                .visual-diagram, .visual-generic, .takeaways, .foundational-narrative { padding: 1.25rem; }
                .flow-step { max-width: 100%; }
            }

            /* ═══ PRINT STYLES ═══ */
            @media print {
                body {
                    background: white;
                    color: black;
                    font-size: 11pt;
                    max-width: 100%;
                    padding: 0;
                }
                .cover-page {
                    min-height: auto;
                    page-break-after: always;
                    margin: 0;
                    padding: 2rem;
                    border: 1px solid \(PremiumUI.Hex.emberMarkLight);
                    background: white;
                }
                .cover-page::before, .cover-page::after { display: none; }
                .cover-corner { display: none; }
                .document-header, .quick-glance, .insight-note, .action-box,
                .exercise, .visual-flowchart, .visual-table, .visual-comparison, .visual-timeline,
                .visual-concept-map, .visual-network, .visual-quadrant, .visual-chart,
                .visual-diagram, .visual-generic, .takeaways, .foundational-narrative {
                    break-inside: avoid;
                    box-shadow: none;
                }
                .table-of-contents {
                    page-break-after: always;
                    box-shadow: none;
                }
                /* Print TOC with dotted leaders */
                .toc-list li a {
                    display: flex;
                    justify-content: space-between;
                }
                .toc-list li a::after {
                    content: leader(dotted) target-counter(attr(href), page);
                    flex: 1;
                    text-align: right;
                    margin-left: 0.5rem;
                }
                a::after {
                    content: ' (' attr(href) ')';
                    font-size: 0.8em;
                    color: #666;
                }
                .toc-list a::after {
                    content: leader(dotted);
                }
                .flow-step { box-shadow: none; }
                /* Dark mode SVG icons need color adjustment for print */
                .insight-note .block-header::before,
                .alternative-perspective .block-header::before,
                .research-insight .block-header::before {
                    filter: brightness(0.8);
                }
            }
        </style>
    </head>
    <body>
        <!-- Premium Cover Page -->
        <section class="cover-page">
            <div class="cover-corner top-left"></div>
            <div class="cover-corner top-right"></div>
            <div class="cover-corner bottom-left"></div>
            <div class="cover-corner bottom-right"></div>

            <p class="cover-top-tagline">Where Understanding Illuminates the World</p>
            <div class="cover-divider"></div>

            \(logoImageTag.isEmpty ? "<div class=\"cover-logo-placeholder\">◎</div>" : logoImageTag.replacingOccurrences(of: "header-logo", with: "cover-logo"))

            <h1 class="cover-title">\(title)</h1>
            <p class="cover-by">by</p>
            <p class="cover-author">\(author)</p>

            <div class="cover-small-divider"></div>

            <p class="cover-brand">Insight Atlas</p>
            <p class="cover-subtitle">A Comprehensive Analysis Guide</p>
        </section>

        <!-- Content Section Header -->
        <header class="document-header header">
            <span class="brand">Insight Atlas Guide</span>
            <span class="brand-badge">Insight Atlas Guide</span>
            <h1>\(title)</h1>
            <p class="author">Based on the work of <strong>\(author)</strong></p>
        </header>

        \(tocHTML)

        \(content)

        <hr class="section-divider-ornament">

        <footer class="document-footer">
            \(footerLogoTag)
            <p><span class="brand-footer">INSIGHT ATLAS</span></p>
            <p class="tagline-footer">Where Understanding Illuminates the World</p>
        </footer>
    </body>
    </html>
    """
}

/// Generate HTML Table of Contents from heading entries
static func generateHTMLTableOfContents(entries: [(text: String, level: Int, id: String)], readingTime: Int) -> String {
    // Only include H2 and H3 entries (skip H1 which is typically just the title)
    let filteredEntries = entries.filter { $0.level >= 2 && $0.level <= 3 }

    guard !filteredEntries.isEmpty else { return "" }

    var tocItems = ""
    for entry in filteredEntries {
        let indent = entry.level == 3 ? "toc-subsection" : "toc-section"
        tocItems += """
        <li class="\(indent)"><a href="#\(entry.id)">\(entry.text)</a></li>

        """
    }

    return """
    <nav class="table-of-contents">
        <div class="toc-header">
            <span class="toc-icon">📑</span>
            <h2>Contents</h2>
            <span class="reading-time-badge">\(readingTime) min read</span>
        </div>
        <ol class="toc-list">
            \(tocItems)
        </ol>
    </nav>
    <hr class="section-divider">
    """
}


}
