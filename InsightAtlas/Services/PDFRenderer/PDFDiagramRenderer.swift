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
        let headerText = NSAttributedString(string: "\(PDFStyleConfiguration.Icons.flowchart) \(title.uppercased())", attributes: headerAttributes)
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
    func calculateConceptMapHeight(centralConcept: String, relatedConcepts: [String], maxWidth: CGFloat) -> CGFloat {
        let baseHeight: CGFloat = 200 // Minimum height for visual appeal
        let conceptsPerRow = 3
        let rows = ceil(Double(relatedConcepts.count) / Double(conceptsPerRow))
        return baseHeight + CGFloat(rows - 1) * 60 + PDFStyleConfiguration.Spacing.blockSpacing
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

        // Calculate layout
        let conceptCount = relatedConcepts.count
        let mapHeight: CGFloat = 180
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
        let headerText = NSAttributedString(string: "🗺️ \(title.uppercased())", attributes: headerAttributes)
        let headerRect = CGRect(x: point.x + padding, y: point.y + 6, width: maxWidth - padding * 2, height: headerHeight - 8)
        headerText.draw(in: headerRect)

        // Map area
        let mapY = point.y + headerHeight + padding
        let centerX = point.x + maxWidth / 2
        let centerY = mapY + mapHeight / 2

        // Draw central concept
        let centralRadius: CGFloat = 50
        drawConceptNode(
            context: context,
            text: centralConcept,
            center: CGPoint(x: centerX, y: centerY),
            radius: centralRadius,
            color: PDFStyleConfiguration.Colors.primaryGold,
            isCenter: true
        )

        // Draw related concepts in a circle around the center
        let orbitRadius: CGFloat = 75
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
                radius: 35,
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

        // Draw text
        let textFont = isCenter ? PDFStyleConfiguration.Typography.bodyBold() : PDFStyleConfiguration.Typography.bodySmall()
        let textColor = isCenter ? PDFStyleConfiguration.Colors.textHeading : PDFStyleConfiguration.Colors.textBody

        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: textFont,
            .foregroundColor: textColor,
            .paragraphStyle: centeredParagraphStyle()
        ]

        let attributedText = NSAttributedString(string: text, attributes: textAttributes)
        let textSize = attributedText.boundingRect(
            with: CGSize(width: radius * 1.6, height: radius * 2),
            options: [.usesLineFragmentOrigin],
            context: nil
        )

        let textRect = CGRect(
            x: center.x - textSize.width / 2,
            y: center.y - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )

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
        let headerText = NSAttributedString(string: "⟶ \(title.uppercased())", attributes: headerAttributes)
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
