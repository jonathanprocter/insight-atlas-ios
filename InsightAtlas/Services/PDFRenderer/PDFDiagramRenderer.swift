import UIKit
import CoreGraphics

// MARK: - PDF Diagram Renderer
// Renders visual diagrams like flowcharts, concept maps, and comparison tables

final class PDFDiagramRenderer {

    // MARK: - Properties

    private let pageSize: CGSize
    private let contentRect: CGRect

    // MARK: - Initialization

    init(
        pageSize: CGSize = PDFStyleConfiguration.PageLayout.pageSize,
        contentRect: CGRect = PDFStyleConfiguration.PageLayout.contentRect
    ) {
        self.pageSize = pageSize
        self.contentRect = contentRect
    }

    // MARK: - Flowchart Rendering

    /// Calculate height required for a flowchart
    func calculateFlowchartHeight(steps: [String], maxWidth: CGFloat) -> CGFloat {
        guard !steps.isEmpty else { return 0 }

        let headerHeight: CGFloat = 28
        let padding: CGFloat = 16
        let stepHeight: CGFloat = 44
        let arrowHeight: CGFloat = 24
        let boxPadding: CGFloat = 8

        var totalContentHeight: CGFloat = 0

        for step in steps {
            let textHeight = calculateTextHeight(step, font: PDFStyleConfiguration.Typography.body(), maxWidth: maxWidth - padding * 2 - boxPadding * 2)
            let actualStepHeight = max(stepHeight, textHeight + boxPadding * 2)
            totalContentHeight += actualStepHeight
        }

        // Add arrows between steps
        let arrowsCount = max(0, steps.count - 1)
        totalContentHeight += CGFloat(arrowsCount) * arrowHeight

        return headerHeight + totalContentHeight + padding * 2 + PDFStyleConfiguration.Spacing.blockSpacing
    }

    /// Render a flowchart diagram
    @discardableResult
    func renderFlowchart(
        title: String,
        steps: [String],
        to context: CGContext,
        at point: CGPoint,
        maxWidth: CGFloat
    ) -> CGFloat {
        guard !steps.isEmpty else { return 0 }

        let headerHeight: CGFloat = 28
        let padding: CGFloat = 16
        let stepHeight: CGFloat = 44
        let arrowHeight: CGFloat = 24
        let boxPadding: CGFloat = 8
        let borderRadius = PDFStyleConfiguration.Radius.md

        // Calculate total height
        var totalContentHeight: CGFloat = 0
        var stepHeights: [CGFloat] = []

        for step in steps {
            let textHeight = calculateTextHeight(step, font: PDFStyleConfiguration.Typography.body(), maxWidth: maxWidth - padding * 2 - boxPadding * 2)
            let actualStepHeight = max(stepHeight, textHeight + boxPadding * 2)
            stepHeights.append(actualStepHeight)
            totalContentHeight += actualStepHeight
        }

        let arrowsCount = max(0, steps.count - 1)
        totalContentHeight += CGFloat(arrowsCount) * arrowHeight

        let totalHeight = headerHeight + totalContentHeight + padding * 2

        // Draw container background
        let bgRect = CGRect(x: point.x, y: point.y, width: maxWidth, height: totalHeight)
        let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: borderRadius)

        context.addPath(bgPath.cgPath)
        context.setFillColor(PDFStyleConfiguration.Colors.bgSecondary.cgColor)
        context.fillPath()

        context.addPath(bgPath.cgPath)
        context.setStrokeColor(PDFStyleConfiguration.Colors.borderMedium.cgColor)
        context.setLineWidth(1.0)
        context.strokePath()

        // Draw header
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.blockHeader(),
            .foregroundColor: PDFStyleConfiguration.Colors.primaryGoldDark
        ]
        let headerText = NSAttributedString(string: title.uppercased(), attributes: headerAttributes)
        let headerRect = CGRect(x: point.x + padding, y: point.y + 6, width: maxWidth - padding * 2, height: headerHeight - 8)
        headerText.draw(in: headerRect)

        // Draw divider
        let dividerY = point.y + headerHeight
        context.setStrokeColor(PDFStyleConfiguration.Colors.borderMedium.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: point.x + padding, y: dividerY))
        context.addLine(to: CGPoint(x: point.x + maxWidth - padding, y: dividerY))
        context.strokePath()

        // Draw flowchart steps
        var currentY = point.y + headerHeight + padding
        let stepWidth = maxWidth - padding * 2 - 40 // Inset for visual appeal
        let stepX = point.x + padding + 20

        for (index, step) in steps.enumerated() {
            let currentStepHeight = stepHeights[index]

            // Draw step box
            drawFlowchartStep(
                context: context,
                text: step,
                rect: CGRect(x: stepX, y: currentY, width: stepWidth, height: currentStepHeight),
                isFirst: index == 0,
                isLast: index == steps.count - 1
            )

            currentY += currentStepHeight

            // Draw arrow to next step (if not last)
            if index < steps.count - 1 {
                drawFlowchartArrow(
                    context: context,
                    from: CGPoint(x: stepX + stepWidth / 2, y: currentY),
                    length: arrowHeight
                )
                currentY += arrowHeight
            }
        }

        return totalHeight + PDFStyleConfiguration.Spacing.blockSpacing
    }

    private func drawFlowchartStep(context: CGContext, text: String, rect: CGRect, isFirst: Bool, isLast: Bool) {
        let cornerRadius: CGFloat = 8
        let borderWidth: CGFloat = 1.5

        // Determine colors based on position
        let borderColor: UIColor
        let bgColor: UIColor

        if isFirst {
            borderColor = PDFStyleConfiguration.Colors.primaryGold
            bgColor = PDFStyleConfiguration.Colors.primaryGold.withAlphaComponent(0.08)
        } else if isLast {
            borderColor = PDFStyleConfiguration.Colors.accentTeal
            bgColor = PDFStyleConfiguration.Colors.accentTeal.withAlphaComponent(0.08)
        } else {
            borderColor = PDFStyleConfiguration.Colors.borderDark
            bgColor = PDFStyleConfiguration.Colors.bgCard
        }

        // Draw box
        let boxPath = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)

        context.addPath(boxPath.cgPath)
        context.setFillColor(bgColor.cgColor)
        context.fillPath()

        context.addPath(boxPath.cgPath)
        context.setStrokeColor(borderColor.cgColor)
        context.setLineWidth(borderWidth)
        context.strokePath()

        // Draw text
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.body(),
            .foregroundColor: PDFStyleConfiguration.Colors.textBody,
            .paragraphStyle: centeredParagraphStyle()
        ]
        let attributedText = NSAttributedString(string: text, attributes: textAttributes)
        let textRect = rect.insetBy(dx: 8, dy: 8)
        attributedText.draw(in: textRect)
    }

    private func drawFlowchartArrow(context: CGContext, from point: CGPoint, length: CGFloat) {
        let arrowHeadSize: CGFloat = 6

        context.saveGState()

        // Draw line
        context.setStrokeColor(PDFStyleConfiguration.Colors.primaryGold.cgColor)
        context.setLineWidth(2.0)
        context.move(to: point)
        context.addLine(to: CGPoint(x: point.x, y: point.y + length - arrowHeadSize))
        context.strokePath()

        // Draw arrowhead
        context.setFillColor(PDFStyleConfiguration.Colors.primaryGold.cgColor)
        let tipY = point.y + length
        context.move(to: CGPoint(x: point.x, y: tipY))
        context.addLine(to: CGPoint(x: point.x - arrowHeadSize, y: tipY - arrowHeadSize))
        context.addLine(to: CGPoint(x: point.x + arrowHeadSize, y: tipY - arrowHeadSize))
        context.closePath()
        context.fillPath()

        context.restoreGState()
    }

    // MARK: - Comparison Table Rendering

    /// Calculate height for a comparison table
    func calculateComparisonTableHeight(rows: [[String]], headers: [String]?, maxWidth: CGFloat) -> CGFloat {
        guard !rows.isEmpty else { return 0 }

        let headerHeight: CGFloat = 32
        let rowHeight: CGFloat = 36
        let padding: CGFloat = 12

        var totalHeight = headerHeight + padding * 2

        if headers != nil {
            totalHeight += rowHeight
        }

        totalHeight += CGFloat(rows.count) * rowHeight

        return totalHeight + PDFStyleConfiguration.Spacing.blockSpacing
    }

    /// Render a comparison table
    @discardableResult
    func renderComparisonTable(
        title: String,
        headers: [String]?,
        rows: [[String]],
        to context: CGContext,
        at point: CGPoint,
        maxWidth: CGFloat
    ) -> CGFloat {
        guard !rows.isEmpty else { return 0 }

        let headerHeight: CGFloat = 32
        let rowHeight: CGFloat = 36
        let padding: CGFloat = 12
        let borderRadius = PDFStyleConfiguration.Radius.md

        // Determine column count
        let columnCount = rows.first?.count ?? (headers?.count ?? 2)
        let columnWidth = (maxWidth - padding * 2) / CGFloat(columnCount)

        // Calculate total height
        var totalHeight = headerHeight + padding * 2
        if headers != nil {
            totalHeight += rowHeight
        }
        totalHeight += CGFloat(rows.count) * rowHeight

        // Draw container
        let bgRect = CGRect(x: point.x, y: point.y, width: maxWidth, height: totalHeight)
        let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: borderRadius)

        context.addPath(bgPath.cgPath)
        context.setFillColor(PDFStyleConfiguration.Colors.bgCard.cgColor)
        context.fillPath()

        context.addPath(bgPath.cgPath)
        context.setStrokeColor(PDFStyleConfiguration.Colors.borderMedium.cgColor)
        context.setLineWidth(1.0)
        context.strokePath()

        // Draw block header
        let blockHeaderAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.blockHeader(),
            .foregroundColor: PDFStyleConfiguration.Colors.primaryGoldDark
        ]
        let blockHeaderText = NSAttributedString(string: "📋 \(title.uppercased())", attributes: blockHeaderAttributes)
        let blockHeaderRect = CGRect(x: point.x + padding, y: point.y + 6, width: maxWidth - padding * 2, height: headerHeight - 8)
        blockHeaderText.draw(in: blockHeaderRect)

        var currentY = point.y + headerHeight

        // Draw divider under block header
        context.setStrokeColor(PDFStyleConfiguration.Colors.borderMedium.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: point.x + padding, y: currentY))
        context.addLine(to: CGPoint(x: point.x + maxWidth - padding, y: currentY))
        context.strokePath()

        currentY += padding

        // Draw table headers if provided
        if let headers = headers {
            context.setFillColor(PDFStyleConfiguration.Colors.primaryGold.withAlphaComponent(0.1).cgColor)
            context.fill(CGRect(x: point.x + padding, y: currentY, width: maxWidth - padding * 2, height: rowHeight))

            for (index, header) in headers.enumerated() {
                let headerAttributes: [NSAttributedString.Key: Any] = [
                    .font: PDFStyleConfiguration.Typography.bodyBold(),
                    .foregroundColor: PDFStyleConfiguration.Colors.textHeading
                ]
                let headerText = NSAttributedString(string: header, attributes: headerAttributes)
                let headerRect = CGRect(
                    x: point.x + padding + CGFloat(index) * columnWidth + 8,
                    y: currentY + 8,
                    width: columnWidth - 16,
                    height: rowHeight - 16
                )
                headerText.draw(in: headerRect)
            }

            currentY += rowHeight
        }

        // Draw rows
        for (rowIndex, row) in rows.enumerated() {
            // Alternate row background
            if rowIndex % 2 == 1 {
                context.setFillColor(PDFStyleConfiguration.Colors.bgSecondary.cgColor)
                context.fill(CGRect(x: point.x + padding, y: currentY, width: maxWidth - padding * 2, height: rowHeight))
            }

            // Draw row cells
            for (colIndex, cell) in row.enumerated() {
                let cellAttributes: [NSAttributedString.Key: Any] = [
                    .font: PDFStyleConfiguration.Typography.body(),
                    .foregroundColor: PDFStyleConfiguration.Colors.textBody
                ]
                let cellText = NSAttributedString(string: cell, attributes: cellAttributes)
                let cellRect = CGRect(
                    x: point.x + padding + CGFloat(colIndex) * columnWidth + 8,
                    y: currentY + 8,
                    width: columnWidth - 16,
                    height: rowHeight - 16
                )
                cellText.draw(in: cellRect)
            }

            // Draw row separator
            context.setStrokeColor(PDFStyleConfiguration.Colors.borderLight.cgColor)
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: point.x + padding, y: currentY + rowHeight))
            context.addLine(to: CGPoint(x: point.x + maxWidth - padding, y: currentY + rowHeight))
            context.strokePath()

            currentY += rowHeight
        }

        return totalHeight + PDFStyleConfiguration.Spacing.blockSpacing
    }

    // MARK: - Concept Map Rendering

    /// Calculate height for a simple concept map
    struct ConceptMapGeometry: Equatable {
        let central: CGFloat
        let satellite: CGFloat
        let orbit: CGFloat
        let mapHeight: CGFloat
    }

    /// Shared adaptive radial geometry — the SINGLE SOURCE for renderConceptMap
    /// (draw) and calculateConceptMapHeight (measure), so the map GROWS to hold
    /// every concept as a non-overlapping, non-clipping node (no cap, no spill).
    /// Orbit is bounded by width; when width binds, satellites shrink (text
    /// autoshrinks to match). Height plateaus under the page ceiling on real
    /// content because width binds first.
    func conceptMapGeometry(count: Int, maxWidth: CGFloat) -> ConceptMapGeometry {
        let central: CGFloat = 46
        let margin: CGFloat = 12
        let gap: CGFloat = 8
        let base: CGFloat = 34
        let floor: CGFloat = 16
        let n = max(1, count)
        if n == 1 {
            return ConceptMapGeometry(central: central, satellite: 0, orbit: 0, mapHeight: 2 * central + 2 * margin)
        }
        let half = sin(.pi / CGFloat(n))                        // half-angle sine (neighbor spacing)
        let orbitMax = maxWidth / 2 - floor - margin            // widest orbit (min-satellite headroom)
        let orbitIdeal = max(central + base + gap, base / half) // non-overlap orbit at base satellite
        var orbit = min(orbitIdeal, orbitMax)
        // Largest satellite that neither overlaps its neighbor (orbit*sin) nor
        // exceeds the container width, floored so it stays a node.
        let sat = max(floor, min(base, orbit * half, maxWidth / 2 - orbit - margin))
        // Keep satellites clear of the central node, then re-clamp to width.
        orbit = max(orbit, central + sat + gap)
        orbit = min(orbit, maxWidth / 2 - sat - margin)
        let mapHeight = 2 * (orbit + sat) + 2 * margin
        return ConceptMapGeometry(central: central, satellite: sat, orbit: orbit, mapHeight: mapHeight)
    }

    func calculateConceptMapHeight(centralConcept: String, relatedConcepts: [String], maxWidth: CGFloat) -> CGFloat {
        // Adaptive: mirrors renderConceptMap's geometry so reserved == drawn.
        let headerHeight: CGFloat = 28
        let padding: CGFloat = 16
        let geo = conceptMapGeometry(count: relatedConcepts.count, maxWidth: maxWidth)
        return headerHeight + geo.mapHeight + padding * 2 + PDFStyleConfiguration.Spacing.blockSpacing
    }

    /// Render a simple radial concept map
    @discardableResult
    func renderConceptMap(
        title: String,
        centralConcept: String,
        relatedConcepts: [(label: String, description: String)],
        to context: CGContext,
        at point: CGPoint,
        maxWidth: CGFloat
    ) -> CGFloat {
        let headerHeight: CGFloat = 28
        let padding: CGFloat = 16
        let borderRadius = PDFStyleConfiguration.Radius.md

        // Adaptive radial geometry (shared with calculateConceptMapHeight so
        // reserved == drawn). Grows to hold every concept; no cap, no clip.
        let conceptCount = relatedConcepts.count
        let geo = conceptMapGeometry(count: conceptCount, maxWidth: maxWidth)
        let mapHeight = geo.mapHeight
        let totalHeight = headerHeight + mapHeight + padding * 2

        // Draw container
        let bgRect = CGRect(x: point.x, y: point.y, width: maxWidth, height: totalHeight)
        let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: borderRadius)

        context.addPath(bgPath.cgPath)
        context.setFillColor(PDFStyleConfiguration.Colors.bgSecondary.cgColor)
        context.fillPath()

        context.addPath(bgPath.cgPath)
        context.setStrokeColor(PDFStyleConfiguration.Colors.borderMedium.cgColor)
        context.setLineWidth(1.0)
        context.strokePath()

        // Draw header
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.blockHeader(),
            .foregroundColor: PDFStyleConfiguration.Colors.primaryGoldDark
        ]
        let headerText = NSAttributedString(string: title.uppercased(), attributes: headerAttributes)
        let headerRect = CGRect(x: point.x + padding, y: point.y + 6, width: maxWidth - padding * 2, height: headerHeight - 8)
        headerText.draw(in: headerRect)

        // Map area
        let mapY = point.y + headerHeight + padding
        let centerX = point.x + maxWidth / 2
        let centerY = mapY + mapHeight / 2

        // Draw central concept
        drawConceptNode(
            context: context,
            text: centralConcept,
            center: CGPoint(x: centerX, y: centerY),
            radius: geo.central,
            color: PDFStyleConfiguration.Colors.primaryGold,
            isCenter: true
        )

        // Draw related concepts in a circle around the center (adaptive orbit +
        // satellite radius so they never overlap or clip the container).
        let orbitRadius = geo.orbit
        let angleStep = (2 * CGFloat.pi) / CGFloat(max(1, conceptCount))

        for (index, concept) in relatedConcepts.enumerated() {
            let angle = -CGFloat.pi / 2 + CGFloat(index) * angleStep // Start from top
            let nodeX = centerX + orbitRadius * cos(angle)
            let nodeY = centerY + orbitRadius * sin(angle)

            // Draw connecting line
            context.setStrokeColor(PDFStyleConfiguration.Colors.primaryGold.withAlphaComponent(0.4).cgColor)
            context.setLineWidth(1.5)
            context.move(to: CGPoint(x: centerX, y: centerY))
            context.addLine(to: CGPoint(x: nodeX, y: nodeY))
            context.strokePath()

            // Draw node
            drawConceptNode(
                context: context,
                text: concept.label,
                center: CGPoint(x: nodeX, y: nodeY),
                radius: geo.satellite,
                color: PDFStyleConfiguration.Colors.accentTeal,
                isCenter: false
            )
        }

        return totalHeight + PDFStyleConfiguration.Spacing.blockSpacing
    }

    private func drawConceptNode(context: CGContext, text: String, center: CGPoint, radius: CGFloat, color: UIColor, isCenter: Bool) {
        // Draw circle
        context.saveGState()

        let circleRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)

        // Fill
        context.setFillColor(color.withAlphaComponent(isCenter ? 0.15 : 0.1).cgColor)
        context.fillEllipse(in: circleRect)

        // Stroke
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(isCenter ? 2.0 : 1.5)
        context.strokeEllipse(in: circleRect)

        context.restoreGState()

        // Draw text — autoshrink to fit the node (shrink → wrap → ellipsis) so a
        // label can never clip or overflow its circle. Ladder: try the base font
        // down to a floor within the node's inner box; if even the floor overflows,
        // truncate with a tail ellipsis (honest truncation beats clipping).
        let textColor = isCenter ? PDFStyleConfiguration.Colors.textHeading : PDFStyleConfiguration.Colors.textBody
        let inner = CGSize(width: radius * 1.7, height: radius * 1.7)
        let baseSize: CGFloat = isCenter ? 12 : 10
        let floorSize: CGFloat = 7
        let fontName = isCenter ? "Inter-Semibold" : "Inter-Regular"

        func nodeFont(_ s: CGFloat) -> UIFont {
            UIFont(name: fontName, size: s) ?? UIFont.systemFont(ofSize: s, weight: isCenter ? .semibold : .regular)
        }
        func nodePara(_ mode: NSLineBreakMode) -> NSParagraphStyle {
            let p = NSMutableParagraphStyle(); p.alignment = .center; p.lineBreakMode = mode; return p
        }

        var chosenSize = floorSize
        var truncate = true
        var s = baseSize
        while s >= floorSize {
            let a = NSAttributedString(string: text, attributes: [.font: nodeFont(s), .paragraphStyle: nodePara(.byWordWrapping)])
            let b = a.boundingRect(with: CGSize(width: inner.width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], context: nil)
            if b.height <= inner.height { chosenSize = s; truncate = false; break }
            s -= 1
        }

        let attributedText = NSAttributedString(string: text, attributes: [
            .font: nodeFont(chosenSize),
            .foregroundColor: textColor,
            .paragraphStyle: nodePara(truncate ? .byTruncatingTail : .byWordWrapping)
        ])
        let measured = attributedText.boundingRect(with: inner, options: [.usesLineFragmentOrigin], context: nil)
        let drawn = min(measured.height, inner.height)
        let textRect = CGRect(x: center.x - inner.width / 2, y: center.y - drawn / 2, width: inner.width, height: drawn)
        attributedText.draw(in: textRect)
    }

    // MARK: - Process/Timeline Diagram

    /// Calculate height for a horizontal process diagram
    func calculateProcessDiagramHeight(phases: [String], maxWidth: CGFloat) -> CGFloat {
        let headerHeight: CGFloat = 28
        let diagramHeight: CGFloat = 80
        let padding: CGFloat = 16

        return headerHeight + diagramHeight + padding * 2 + PDFStyleConfiguration.Spacing.blockSpacing
    }

    /// Render a horizontal process/timeline diagram
    @discardableResult
    func renderProcessDiagram(
        title: String,
        phases: [(name: String, description: String)],
        to context: CGContext,
        at point: CGPoint,
        maxWidth: CGFloat
    ) -> CGFloat {
        guard !phases.isEmpty else { return 0 }

        let headerHeight: CGFloat = 28
        let diagramHeight: CGFloat = 80
        let padding: CGFloat = 16
        let borderRadius = PDFStyleConfiguration.Radius.md

        let totalHeight = headerHeight + diagramHeight + padding * 2

        // Draw container
        let bgRect = CGRect(x: point.x, y: point.y, width: maxWidth, height: totalHeight)
        let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: borderRadius)

        context.addPath(bgPath.cgPath)
        context.setFillColor(PDFStyleConfiguration.Colors.bgSecondary.cgColor)
        context.fillPath()

        context.addPath(bgPath.cgPath)
        context.setStrokeColor(PDFStyleConfiguration.Colors.borderMedium.cgColor)
        context.setLineWidth(1.0)
        context.strokePath()

        // Draw header
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.blockHeader(),
            .foregroundColor: PDFStyleConfiguration.Colors.primaryGoldDark
        ]
        let headerText = NSAttributedString(string: title.uppercased(), attributes: headerAttributes)
        let headerRect = CGRect(x: point.x + padding, y: point.y + 6, width: maxWidth - padding * 2, height: headerHeight - 8)
        headerText.draw(in: headerRect)

        // Draw process phases
        let diagramY = point.y + headerHeight + padding
        let phaseCount = phases.count
        let availableWidth = maxWidth - padding * 2
        let phaseWidth = availableWidth / CGFloat(phaseCount)
        let circleRadius: CGFloat = 16
        let lineY = diagramY + 20

        // Draw connecting line
        context.setStrokeColor(PDFStyleConfiguration.Colors.primaryGold.withAlphaComponent(0.4).cgColor)
        context.setLineWidth(2.0)
        context.move(to: CGPoint(x: point.x + padding + phaseWidth / 2, y: lineY))
        context.addLine(to: CGPoint(x: point.x + padding + availableWidth - phaseWidth / 2, y: lineY))
        context.strokePath()

        // Draw phase nodes
        for (index, phase) in phases.enumerated() {
            let centerX = point.x + padding + phaseWidth / 2 + CGFloat(index) * phaseWidth

            // Draw circle
            let circleRect = CGRect(
                x: centerX - circleRadius,
                y: lineY - circleRadius,
                width: circleRadius * 2,
                height: circleRadius * 2
            )

            context.setFillColor(PDFStyleConfiguration.Colors.bgCard.cgColor)
            context.fillEllipse(in: circleRect)
            context.setStrokeColor(PDFStyleConfiguration.Colors.primaryGold.cgColor)
            context.setLineWidth(2.0)
            context.strokeEllipse(in: circleRect)

            // Draw phase number
            let numberAttributes: [NSAttributedString.Key: Any] = [
                .font: PDFStyleConfiguration.Typography.bodyBold(),
                .foregroundColor: PDFStyleConfiguration.Colors.primaryGold,
                .paragraphStyle: centeredParagraphStyle()
            ]
            let numberText = NSAttributedString(string: "\(index + 1)", attributes: numberAttributes)
            let numberRect = CGRect(x: centerX - 10, y: lineY - 8, width: 20, height: 16)
            numberText.draw(in: numberRect)

            // Draw phase name below
            let nameAttributes: [NSAttributedString.Key: Any] = [
                .font: PDFStyleConfiguration.Typography.bodySmall(),
                .foregroundColor: PDFStyleConfiguration.Colors.textBody,
                .paragraphStyle: centeredParagraphStyle()
            ]
            let nameText = NSAttributedString(string: phase.name, attributes: nameAttributes)
            let nameRect = CGRect(
                x: centerX - phaseWidth / 2 + 4,
                y: lineY + circleRadius + 8,
                width: phaseWidth - 8,
                height: 30
            )
            nameText.draw(in: nameRect)
        }

        return totalHeight + PDFStyleConfiguration.Spacing.blockSpacing
    }

    // MARK: - Loop Diagram (feedback loop — Directives §A4)

    /// Node bounding box + circle radius chosen to fit `maxWidth` while keeping
    /// nodes separated. Shared by height calculation and rendering so they agree.
    private func loopMetrics(nodeCount: Int, maxWidth: CGFloat) -> (radius: CGFloat, nodeSize: CGSize) {
        let n = max(2, nodeCount)
        let step = (2 * CGFloat.pi) / CGFloat(n)
        let nodeHeight: CGFloat = 44

        // Shrink node width (if needed) until the clearance-required radius also
        // fits within the available width — keeping the geometry contract holdable.
        func fitRadius(_ width: CGFloat) -> CGFloat { (maxWidth - width) / 2 - 8 }
        func requiredRadius(_ width: CGFloat) -> CGFloat {
            let halfDiagonal = hypot(width / 2, nodeHeight / 2)
            return (halfDiagonal + PDFDiagramGeometry.clearance) / sin(step / 2)
        }

        var nodeWidth = min(150, maxWidth * 0.30)
        while nodeWidth > 84, requiredRadius(nodeWidth) > fitRadius(nodeWidth) {
            nodeWidth -= 6
        }

        let radius = max(88, min(fitRadius(nodeWidth), max(requiredRadius(nodeWidth), 100)))
        return (radius, CGSize(width: nodeWidth, height: nodeHeight))
    }

    /// Calculate height for a loop diagram.
    func calculateLoopDiagramHeight(nodes: [String], maxWidth: CGFloat) -> CGFloat {
        guard nodes.count >= 2 else { return 0 }
        let headerHeight: CGFloat = 28
        let padding: CGFloat = 16
        let captionHeight: CGFloat = 34
        let (radius, nodeSize) = loopMetrics(nodeCount: nodes.count, maxWidth: maxWidth)
        let diagramHeight = 2 * radius + nodeSize.height
        return headerHeight + padding * 2 + diagramHeight + captionHeight + PDFStyleConfiguration.Spacing.blockSpacing
    }

    /// Render a self-confirming feedback loop. All connector-arc endpoints are
    /// computed against the circle equation (see `PDFDiagramGeometry`), never
    /// hand-placed, and clear each node box by ≥ the clearance margin.
    @discardableResult
    func renderLoopDiagram(
        title: String,
        nodes: [String],
        caption: String?,
        to context: CGContext,
        at point: CGPoint,
        maxWidth: CGFloat
    ) -> CGFloat {
        guard nodes.count >= 2 else { return 0 }

        let headerHeight: CGFloat = 28
        let padding: CGFloat = 16
        let borderRadius = PDFStyleConfiguration.Radius.md
        let (radius, nodeSize) = loopMetrics(nodeCount: nodes.count, maxWidth: maxWidth)
        let diagramHeight = 2 * radius + nodeSize.height
        let captionHeight: CGFloat = 34
        let totalHeight = headerHeight + padding * 2 + diagramHeight + captionHeight

        // Container
        let bgRect = CGRect(x: point.x, y: point.y, width: maxWidth, height: totalHeight)
        let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: borderRadius)
        context.addPath(bgPath.cgPath)
        context.setFillColor(PDFStyleConfiguration.Colors.bgSecondary.cgColor)
        context.fillPath()
        context.addPath(bgPath.cgPath)
        context.setStrokeColor(PDFStyleConfiguration.Colors.borderMedium.cgColor)
        context.setLineWidth(1.0)
        context.strokePath()

        // Header
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.blockHeader(),
            .foregroundColor: PDFStyleConfiguration.Colors.primaryGoldDark
        ]
        NSAttributedString(string: "↻ \(title.uppercased())", attributes: headerAttributes)
            .draw(in: CGRect(x: point.x + padding, y: point.y + 6, width: maxWidth - padding * 2, height: headerHeight - 8))

        // Circle placement: topmost node sits just under the header band.
        let diagramTop = point.y + headerHeight + padding
        let center = CGPoint(x: point.x + maxWidth / 2, y: diagramTop + nodeSize.height / 2 + radius)
        let geometry = PDFDiagramGeometry.solveLoop(
            center: center, radius: radius, nodeCount: nodes.count, nodeSize: nodeSize
        )

        // Connector arcs (drawn as circle-sampled polylines so they lie exactly
        // on the circle regardless of the PDF's flipped coordinate space).
        let arcColor = PDFStyleConfiguration.Colors.accentBurgundy
        for arc in geometry.arcs {
            drawCircleArc(context: context, center: center, radius: radius,
                          from: arc.startAngle, to: arc.endAngle, color: arcColor)
            let tangent = CGVector(dx: -sin(arc.endAngle), dy: cos(arc.endAngle))
            drawArrowHead(context: context, at: arc.endPoint, direction: tangent,
                          size: 7, color: arcColor)
        }

        // Nodes — origin node (index 0) carries the emphasis border.
        for node in geometry.nodes {
            let isOrigin = node.index == 0
            drawLoopNode(context: context, text: nodes[node.index], rect: node.rect, emphasized: isOrigin)
        }

        // Caption
        if let caption = caption, !caption.isEmpty {
            let captionRect = CGRect(x: point.x + padding, y: point.y + totalHeight - captionHeight + 4,
                                     width: maxWidth - padding * 2, height: captionHeight - 8)
            NSAttributedString(string: caption, attributes: PDFStyleConfiguration.captionAttributes())
                .draw(with: captionRect, options: [.usesLineFragmentOrigin], context: nil)
        }

        return totalHeight + PDFStyleConfiguration.Spacing.blockSpacing
    }

    private func drawLoopNode(context: CGContext, text: String, rect: CGRect, emphasized: Bool) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 4)
        context.addPath(path.cgPath)
        context.setFillColor((emphasized ? PDFStyleConfiguration.Colors.bgSecondary : PDFStyleConfiguration.Colors.bgCard).cgColor)
        context.fillPath()
        context.addPath(path.cgPath)
        context.setStrokeColor((emphasized ? PDFStyleConfiguration.Colors.accentBurgundy : PDFStyleConfiguration.Colors.borderMedium).cgColor)
        context.setLineWidth(emphasized ? 1.6 : 1.0)
        context.strokePath()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: emphasized ? PDFStyleConfiguration.Typography.bodyBold() : PDFStyleConfiguration.Typography.bodySmall(),
            .foregroundColor: PDFStyleConfiguration.Colors.textBody,
            .paragraphStyle: centeredParagraphStyle()
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textHeight = attributed.boundingRect(
            with: CGSize(width: rect.width - 8, height: rect.height),
            options: [.usesLineFragmentOrigin], context: nil
        ).height
        let textRect = CGRect(x: rect.minX + 4, y: rect.midY - min(textHeight, rect.height - 6) / 2,
                              width: rect.width - 8, height: rect.height - 6)
        attributed.draw(with: textRect, options: [.usesLineFragmentOrigin], context: nil)
    }

    /// Stroke an arc by sampling the circle equation between two angles.
    private func drawCircleArc(context: CGContext, center: CGPoint, radius: CGFloat,
                               from startAngle: CGFloat, to endAngle: CGFloat, color: UIColor) {
        let sweep = endAngle - startAngle
        let segments = max(2, Int((abs(sweep) / (CGFloat.pi / 60)).rounded(.up)))
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1.75)
        context.setLineCap(.round)
        context.beginPath()
        for i in 0...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let angle = startAngle + sweep * t
            let p = PDFDiagramGeometry.point(on: center, radius: radius, angle: angle)
            if i == 0 { context.move(to: p) } else { context.addLine(to: p) }
        }
        context.strokePath()
        context.restoreGState()
    }

    /// Draw a filled triangular arrowhead at `point`, pointing along `direction`.
    private func drawArrowHead(context: CGContext, at point: CGPoint, direction: CGVector,
                               size: CGFloat, color: UIColor) {
        let length = hypot(direction.dx, direction.dy)
        guard length > 0 else { return }
        let ux = direction.dx / length
        let uy = direction.dy / length
        // Perpendicular unit vector.
        let px = -uy
        let py = ux
        let tip = point
        let base = CGPoint(x: point.x - ux * size, y: point.y - uy * size)
        let left = CGPoint(x: base.x + px * (size * 0.6), y: base.y + py * (size * 0.6))
        let right = CGPoint(x: base.x - px * (size * 0.6), y: base.y - py * (size * 0.6))
        context.saveGState()
        context.setFillColor(color.cgColor)
        context.beginPath()
        context.move(to: tip)
        context.addLine(to: left)
        context.addLine(to: right)
        context.closePath()
        context.fillPath()
        context.restoreGState()
    }

    // MARK: - Spectrum / Slider (two-pole construct — Directives §A4)

    func calculateSpectrumHeight(maxWidth: CGFloat) -> CGFloat {
        let headerHeight: CGFloat = 28
        let padding: CGFloat = 16
        let bodyHeight: CGFloat = 96
        return headerHeight + padding * 2 + bodyHeight + PDFStyleConfiguration.Spacing.blockSpacing
    }

    /// Render a two-pole spectrum with the healthy target zone marked in the
    /// middle. Geometry is computed from the inner content width.
    @discardableResult
    func renderSpectrum(
        title: String,
        leftPole: String,
        rightPole: String,
        zoneLabel: String,
        to context: CGContext,
        at point: CGPoint,
        maxWidth: CGFloat
    ) -> CGFloat {
        let headerHeight: CGFloat = 28
        let padding: CGFloat = 16
        let bodyHeight: CGFloat = 96
        let borderRadius = PDFStyleConfiguration.Radius.md
        let totalHeight = headerHeight + padding * 2 + bodyHeight

        // Container
        let bgRect = CGRect(x: point.x, y: point.y, width: maxWidth, height: totalHeight)
        let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: borderRadius)
        context.addPath(bgPath.cgPath)
        context.setFillColor(PDFStyleConfiguration.Colors.bgSecondary.cgColor)
        context.fillPath()
        context.addPath(bgPath.cgPath)
        context.setStrokeColor(PDFStyleConfiguration.Colors.borderMedium.cgColor)
        context.setLineWidth(1.0)
        context.strokePath()

        // Header
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.blockHeader(),
            .foregroundColor: PDFStyleConfiguration.Colors.primaryGoldDark
        ]
        NSAttributedString(string: "◄ ► \(title.uppercased())", attributes: headerAttributes)
            .draw(in: CGRect(x: point.x + padding, y: point.y + 6, width: maxWidth - padding * 2, height: headerHeight - 8))

        let innerX = point.x + padding
        let innerW = maxWidth - padding * 2
        let trackY = point.y + headerHeight + padding + 40
        let trackH: CGFloat = 8
        let trackRect = CGRect(x: innerX, y: trackY, width: innerW, height: trackH)

        // Track gradient: muted burgundy pole → parchment center → slate pole.
        let leftColor = UIColor(hex: "#B98A93")
        let midColor = PDFStyleConfiguration.Colors.bgSecondary
        let rightColor = UIColor(hex: "#93A3B9")
        let trackPath = UIBezierPath(roundedRect: trackRect, cornerRadius: trackH / 2)
        context.saveGState()
        context.addPath(trackPath.cgPath)
        context.clip()
        let space = CGColorSpaceCreateDeviceRGB()
        if let gradient = CGGradient(colorsSpace: space,
                                     colors: [leftColor.cgColor, midColor.cgColor, midColor.cgColor, rightColor.cgColor] as CFArray,
                                     locations: [0, 0.32, 0.68, 1]) {
            context.drawLinearGradient(gradient,
                                       start: CGPoint(x: trackRect.minX, y: trackRect.midY),
                                       end: CGPoint(x: trackRect.maxX, y: trackRect.midY),
                                       options: [])
        }
        context.restoreGState()
        context.addPath(trackPath.cgPath)
        context.setStrokeColor(PDFStyleConfiguration.Colors.borderMedium.cgColor)
        context.setLineWidth(1.0)
        context.strokePath()

        // Healthy zone: outlined pill spanning the central 32%–68%.
        let zoneRect = CGRect(x: innerX + innerW * 0.32, y: trackY - 6, width: innerW * 0.36, height: trackH + 12)
        let zonePath = UIBezierPath(roundedRect: zoneRect, cornerRadius: (trackH + 12) / 2)
        context.addPath(zonePath.cgPath)
        context.setStrokeColor(PDFStyleConfiguration.Colors.accentTeal.cgColor)
        context.setLineWidth(1.5)
        context.strokePath()

        // Zone label above the pill.
        let zoneAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.captionBold(),
            .foregroundColor: PDFStyleConfiguration.Colors.accentTeal,
            .paragraphStyle: centeredParagraphStyle()
        ]
        NSAttributedString(string: zoneLabel.isEmpty ? "healthy range" : zoneLabel, attributes: zoneAttributes)
            .draw(in: CGRect(x: zoneRect.minX - 20, y: zoneRect.minY - 20, width: zoneRect.width + 40, height: 16))

        // Pole labels.
        let leftAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.bodySmall(),
            .foregroundColor: PDFStyleConfiguration.Colors.textMuted
        ]
        let rightStyle = NSMutableParagraphStyle()
        rightStyle.alignment = .right
        var rightAttributes = leftAttributes
        rightAttributes[.paragraphStyle] = rightStyle
        let poleY = trackY + trackH + 12
        NSAttributedString(string: leftPole, attributes: leftAttributes)
            .draw(with: CGRect(x: innerX, y: poleY, width: innerW * 0.4, height: 34), options: [.usesLineFragmentOrigin], context: nil)
        NSAttributedString(string: rightPole, attributes: rightAttributes)
            .draw(with: CGRect(x: innerX + innerW * 0.6, y: poleY, width: innerW * 0.4, height: 34), options: [.usesLineFragmentOrigin], context: nil)

        return totalHeight + PDFStyleConfiguration.Spacing.blockSpacing
    }

    // MARK: - Helper Methods

    private func calculateTextHeight(_ text: String, font: UIFont, maxWidth: CGFloat) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let boundingRect = attributedString.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return ceil(boundingRect.height)
    }

    private func centeredParagraphStyle() -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byWordWrapping
        return style
    }
}
