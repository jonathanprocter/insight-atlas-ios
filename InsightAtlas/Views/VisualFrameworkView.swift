import SwiftUI

/// View for displaying visual framework components (flowcharts, tables, diagrams)
struct VisualFrameworkView: View {

    let framework: any VisualFramework

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: frameworkIcon)
                    .font(.title3)
                    .foregroundStyle(.indigo)

                Text(framework.title)
                    .font(.headline)

                Spacer()
            }

            Divider()

            // Content based on framework type
            frameworkContent
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.indigo.opacity(0.3), lineWidth: 1)
        )
    }

    private var frameworkIcon: String {
        if framework is FlowChart { return "arrow.down.circle" }
        if framework is ComparisonTable { return "table" }
        if framework is ConceptMap { return "circle.hexagongrid" }
        if framework is ProcessDiagram { return "arrow.triangle.2.circlepath" }
        if framework is HierarchyDiagram { return "list.bullet.indent" }
        return "chart.bar"
    }

    @ViewBuilder
    private var frameworkContent: some View {
        if let flowChart = framework as? FlowChart {
            flowChartContent(flowChart)
        } else if let table = framework as? ComparisonTable {
            comparisonTableContent(table)
        } else if let conceptMap = framework as? ConceptMap {
            conceptMapContent(conceptMap)
        } else if let process = framework as? ProcessDiagram {
            processDiagramContent(process)
        } else if let hierarchy = framework as? HierarchyDiagram {
            hierarchyDiagramContent(hierarchy)
        }
    }

    // MARK: - Flow Chart

    private func flowChartContent(_ chart: FlowChart) -> some View {
        VStack(spacing: 8) {
            ForEach(Array(chart.steps.enumerated()), id: \.element.id) { index, step in
                VStack(spacing: 8) {
                    // Step box
                    Text(step.content)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(step.isOutcome ? Color.indigo : Color(.systemGray6))
                        .foregroundStyle(step.isOutcome ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Arrow (if not last step)
                    if index < chart.steps.count - 1 {
                        Image(systemName: "arrow.down")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Comparison Table

    private func comparisonTableContent(_ table: ComparisonTable) -> some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                Text(table.leftColumnHeader)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.red.opacity(0.1))

                Text(table.rightColumnHeader)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.green.opacity(0.1))
            }

            Divider()

            // Data rows
            ForEach(table.rows) { row in
                HStack(spacing: 0) {
                    Text(row.leftValue)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()

                    Divider()

                    Text(row.rightValue)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }

                if row.id != table.rows.last?.id {
                    Divider()
                }
            }
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Concept Map

    private func conceptMapContent(_ map: ConceptMap) -> some View {
        VStack(spacing: 16) {
            // Central concept
            Text(map.centralConcept)
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.indigo)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Connections
            ForEach(map.connections) { connection in
                HStack(spacing: 12) {
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(connection.relationship)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(connection.concept)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Process Diagram

    private func processDiagramContent(_ process: ProcessDiagram) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(process.phases.enumerated()), id: \.element.id) { index, phase in
                VStack(alignment: .leading, spacing: 8) {
                    // Phase header
                    HStack {
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.indigo)
                            .clipShape(Circle())

                        Text(phase.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    // Phase steps
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(phase.steps, id: \.self) { step in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .foregroundStyle(.secondary)
                                Text(step)
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(.leading, 32)
                }

                if index < process.phases.count - 1 {
                    HStack {
                        Spacer()
                            .frame(width: 10)
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 2, height: 20)
                    }
                }
            }
        }
    }

    // MARK: - Hierarchy Diagram

    private func hierarchyDiagramContent(_ hierarchy: HierarchyDiagram) -> some View {
        hierarchyNode(hierarchy.root, level: 0)
    }

    private func hierarchyNode(_ node: HierarchyNode, level: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if level > 0 {
                    ForEach(0..<level, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 20)
                    }
                    Image(systemName: "arrow.turn.down.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(node.name)
                    .font(level == 0 ? .headline : .subheadline)
                    .fontWeight(level == 0 ? .bold : .medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(level == 0 ? Color.indigo : Color(.systemGray6))
                    .foregroundStyle(level == 0 ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            ForEach(node.children) { child in
                AnyView(hierarchyNode(child, level: level + 1))
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            VisualFrameworkView(framework: FlowChart(
                title: "The Assumption-Conflict Cycle",
                steps: [
                    FlowChartStep(content: "Information Gap", isOutcome: false),
                    FlowChartStep(content: "Assumption Created to Fill Gap", isOutcome: false),
                    FlowChartStep(content: "Assumption Treated as Fact", isOutcome: false),
                    FlowChartStep(content: "Expectations Formed", isOutcome: false),
                    FlowChartStep(content: "Reality Doesn't Match", isOutcome: false),
                    FlowChartStep(content: "Conflict / Disappointment", isOutcome: true)
                ]
            ))

            VisualFrameworkView(framework: ComparisonTable(
                title: "Victim vs Warrior Mindset",
                leftColumnHeader: "Victim Mindset",
                rightColumnHeader: "Warrior Mindset",
                rows: [
                    ComparisonRow(leftValue: "Represses emotions from fear", rightValue: "Refrains from expressing until appropriate"),
                    ComparisonRow(leftValue: "Reacts automatically", rightValue: "Responds consciously"),
                    ComparisonRow(leftValue: "Overwhelmed by feelings", rightValue: "Experiences feelings fully"),
                    ComparisonRow(leftValue: "Carries resentment", rightValue: "Practices forgiveness")
                ]
            ))

            VisualFrameworkView(framework: ConceptMap(
                title: "The Four Agreements",
                centralConcept: "Personal Freedom",
                connections: [
                    ConceptConnection(concept: "Be Impeccable with Your Word", relationship: "achieved through"),
                    ConceptConnection(concept: "Don't Take Anything Personally", relationship: "protected by"),
                    ConceptConnection(concept: "Don't Make Assumptions", relationship: "enabled by"),
                    ConceptConnection(concept: "Always Do Your Best", relationship: "sustained by")
                ]
            ))
        }
        .padding()
    }
}
