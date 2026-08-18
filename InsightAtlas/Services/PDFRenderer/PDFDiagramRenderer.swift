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
    func calculateFlowchartHeight(steps rawSteps: [String], maxWidth: CGFloat) -> CGFloat {
        guard !rawSteps.isEmpty else { return 0 }
        // Clean node labels in BOTH measure and draw so measure==draw holds.
        let steps = rawSteps.map { cleanDiagramNodeLabel($0) }

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
        steps rawSteps: [String],
        to context: CGContext,
        at point: CGPoint,
        maxWidth: CGFloat
    ) -> CGFloat {
        guard !rawSteps.isEmpty else { return 0 }
        let steps = rawSteps.map { cleanDiagramNodeLabel($0) }

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
            .ligature: 0,
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

    /// Strip a stray leading arrow/bullet token the model sometimes bakes into a
    /// node label ("→ Foundation Required", "- Step"). Node labels are not list
    /// items; the marker is noise.
    private func cleanDiagramNodeLabel(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespaces)
        for token in ["→ ", "-> ", "• ", "- ", "* ", "→", "->", "•"] {
            if s.hasPrefix(token) {
                s = String(s.dropFirst(token.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        return s
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
            .ligature: 0,
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
            .ligature: 0,
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
                    .ligature: 0,
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
                    .ligature: 0,
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
            .ligature: 0,
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
            .ligature: 0,
            .foregroundColor: textColor,
            .paragraphStyle: nodePara(truncate ? .byTruncatingTail : .byWordWrapping)
        ])
        let measured = attributedText.boundingRect(with: inner, options: [.usesLineFragmentOrigin], context: nil)
        let drawn = min(measured.height, inner.height)
        let textRect = CGRect(x: center.x - inner.width / 2, y: center.y - drawn / 2, width: inner.width, height: drawn)
        attributedText.draw(in: textRect)
    }

    // MARK: - Pyramid Diagram

    /// Shared band geometry — SINGLE SOURCE for renderPyramid (draw) and
    /// calculatePyramidHeight (measure), so reserved == drawn. Fixed-height bands
    /// stacked widest-at-base; height is linear in level count, so it never
    /// surprises the paginator.
    private struct PyramidGeometry {
        let bandHeight: CGFloat
        let bandGap: CGFloat
        let mapHeight: CGFloat
    }

    private func pyramidGeometry(count: Int) -> PyramidGeometry {
        let bandHeight: CGFloat = 46
        let bandGap: CGFloat = 6
        let n = max(1, count)
        let mapHeight = CGFloat(n) * bandHeight + CGFloat(max(0, n - 1)) * bandGap
        return PyramidGeometry(bandHeight: bandHeight, bandGap: bandGap, mapHeight: mapHeight)
    }

    func calculatePyramidHeight(levels: [String], maxWidth: CGFloat) -> CGFloat {
        let headerHeight: CGFloat = 28
        let padding: CGFloat = 16
        let geo = pyramidGeometry(count: levels.count)
        return headerHeight + geo.mapHeight + padding * 2 + PDFStyleConfiguration.Spacing.blockSpacing
    }

    /// Render a stacked pyramid: level 0 = apex (narrowest, top), last = base
    /// (widest). Each level a centered rounded band, tint deepening toward the
    /// base, label autoshrunk to fit inside its band (never clips).
    @discardableResult
    func renderPyramid(
        title: String,
        levels: [String],
        to context: CGContext,
        at point: CGPoint,
        maxWidth: CGFloat
    ) -> CGFloat {
        let headerHeight: CGFloat = 28
        let padding: CGFloat = 16
        let geo = pyramidGeometry(count: levels.count)
        let totalHeight = headerHeight + geo.mapHeight + padding * 2

        // Container
        let bgRect = CGRect(x: point.x, y: point.y, width: maxWidth, height: totalHeight)
        let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: PDFStyleConfiguration.Radius.md)
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
            .ligature: 0,
            .foregroundColor: PDFStyleConfiguration.Colors.primaryGoldDark
        ]
        NSAttributedString(string: title.uppercased(), attributes: headerAttributes)
            .draw(in: CGRect(x: point.x + padding, y: point.y + 6, width: maxWidth - padding * 2, height: headerHeight - 8))

        // Bands
        let n = max(1, levels.count)
        let maxBandWidth = maxWidth - padding * 2
        let minBandWidth = n == 1 ? maxBandWidth : maxBandWidth * 0.42
        let centerX = point.x + maxWidth / 2
        let bandsTop = point.y + headerHeight + padding

        for (index, label) in levels.enumerated() {
            let frac = n == 1 ? 1.0 : CGFloat(index) / CGFloat(n - 1)   // 0 = apex, 1 = base
            let bandWidth = minBandWidth + (maxBandWidth - minBandWidth) * frac
            let bandY = bandsTop + CGFloat(index) * (geo.bandHeight + geo.bandGap)
            let bandRect = CGRect(x: centerX - bandWidth / 2, y: bandY, width: bandWidth, height: geo.bandHeight)
            let bandPath = UIBezierPath(roundedRect: bandRect, cornerRadius: 4)
            let tint = PDFStyleConfiguration.Colors.primaryGold.withAlphaComponent(0.12 + 0.12 * frac)
            context.addPath(bandPath.cgPath)
            context.setFillColor(tint.cgColor)
            context.fillPath()
            context.addPath(bandPath.cgPath)
            context.setStrokeColor(PDFStyleConfiguration.Colors.primaryGold.cgColor)
            context.setLineWidth(1.0)
            context.strokePath()
            drawPyramidLabel(context: context, text: label, in: bandRect)
        }

        return totalHeight + PDFStyleConfiguration.Spacing.blockSpacing
    }

    private func drawPyramidLabel(context: CGContext, text: String, in rect: CGRect) {
        let inset = rect.insetBy(dx: 10, dy: 4)
        let baseSize: CGFloat = 11, floorSize: CGFloat = 8
        func labelFont(_ s: CGFloat) -> UIFont {
            UIFont(name: "Inter-Medium", size: s) ?? UIFont.systemFont(ofSize: s, weight: .medium)
        }
        func labelPara(_ mode: NSLineBreakMode) -> NSParagraphStyle {
            let p = NSMutableParagraphStyle(); p.alignment = .center; p.lineBreakMode = mode; return p
        }
        var chosen = floorSize, truncate = true, s = baseSize
        while s >= floorSize {
            let a = NSAttributedString(string: text, attributes: [.font: labelFont(s), .paragraphStyle: labelPara(.byWordWrapping)])
            let b = a.boundingRect(with: CGSize(width: inset.width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], context: nil)
            if b.height <= inset.height { chosen = s; truncate = false; break }
            s -= 1
        }
        let attr = NSAttributedString(string: text, attributes: [
            .font: labelFont(chosen),
            .ligature: 0,
            .foregroundColor: PDFStyleConfiguration.Colors.textHeading,
            .paragraphStyle: labelPara(truncate ? .byTruncatingTail : .byWordWrapping)
        ])
        let measured = attr.boundingRect(with: inset.size, options: [.usesLineFragmentOrigin], context: nil)
        let drawn = min(measured.height, inset.height)
        attr.draw(in: CGRect(x: inset.minX, y: rect.midY - drawn / 2, width: inset.width, height: drawn))
    }

    // MARK: - Bar Chart

    func calculateBarChartHeight(count: Int, maxWidth: CGFloat) -> CGFloat {
        let headerHeight: CGFloat = 28
        let padding: CGFloat = 16
        let rowHeight: CGFloat = 30
        let n = max(1, count)
        return headerHeight + CGFloat(n) * rowHeight + padding * 2 + PDFStyleConfiguration.Spacing.blockSpacing
    }

    /// Render a horizontal bar chart: label on the left, proportional bar, value
    /// at the bar's end. Horizontal reads better than vertical in a narrow column.
    @discardableResult
    func renderBarChart(
        title: String,
        labels: [String],
        values: [Double],
        to context: CGContext,
        at point: CGPoint,
        maxWidth: CGFloat
    ) -> CGFloat {
        let headerHeight: CGFloat = 28
        let padding: CGFloat = 16
        let rowHeight: CGFloat = 30
        let n = max(1, labels.count)
        let totalHeight = headerHeight + CGFloat(n) * rowHeight + padding * 2

        drawDiagramContainer(context: context, at: point, width: maxWidth, height: totalHeight, title: title)

        let inner = maxWidth - padding * 2
        let labelW = inner * 0.34
        let trackX = point.x + padding + labelW + 6
        let trackW = max(1, inner - labelW - 6)
        let plotTop = point.y + headerHeight + padding
        let maxValue = max(values.max() ?? 1, 1)

        for i in 0..<n {
            let y = plotTop + CGFloat(i) * rowHeight
            let value = i < values.count ? values[i] : 0
            drawChartText(labels[i], in: CGRect(x: point.x + padding, y: y, width: labelW, height: rowHeight),
                          align: .left, size: 10, color: PDFStyleConfiguration.Colors.textBody, bold: false)
            let barH: CGFloat = 16
            let barY = y + (rowHeight - barH) / 2
            let w = maxValue > 0 ? CGFloat(value / maxValue) * trackW : 0
            let drawnW = max(2, w)
            let barRect = CGRect(x: trackX, y: barY, width: drawnW, height: barH)
            let barPath = UIBezierPath(roundedRect: barRect, cornerRadius: 3)
            context.addPath(barPath.cgPath)
            context.setFillColor(PDFStyleConfiguration.Colors.primaryGold.withAlphaComponent(0.75).cgColor)
            context.fillPath()
            drawChartText(formatNumber(value), in: CGRect(x: trackX + drawnW + 4, y: y, width: max(10, trackW - drawnW - 4), height: rowHeight),
                          align: .left, size: 9, color: PDFStyleConfiguration.Colors.textHeading, bold: true)
        }

        return totalHeight + PDFStyleConfiguration.Spacing.blockSpacing
    }

    // MARK: - Pie Chart

    func calculatePieChartHeight(count: Int, maxWidth: CGFloat) -> CGFloat {
        let headerHeight: CGFloat = 28
        let padding: CGFloat = 16
        let pieSize: CGFloat = 140
        let legendRow: CGFloat = 22
        let body = max(pieSize, CGFloat(max(1, count)) * legendRow)
        return headerHeight + body + padding * 2 + PDFStyleConfiguration.Spacing.blockSpacing
    }

    /// Render a pie chart with a legend column (label — share%).
    @discardableResult
    func renderPieChart(
        title: String,
        segments: [(label: String, value: Double)],
        to context: CGContext,
        at point: CGPoint,
        maxWidth: CGFloat
    ) -> CGFloat {
        let headerHeight: CGFloat = 28
        let padding: CGFloat = 16
        let pieSize: CGFloat = 140
        let legendRow: CGFloat = 22
        let n = max(1, segments.count)
        let legendH = CGFloat(n) * legendRow
        let body = max(pieSize, legendH)
        let totalHeight = headerHeight + body + padding * 2

        drawDiagramContainer(context: context, at: point, width: maxWidth, height: totalHeight, title: title)

        let total = max(segments.reduce(0) { $0 + $1.value }, 0.0001)
        let cx = point.x + padding + pieSize / 2
        let cy = point.y + headerHeight + padding + body / 2
        let r = pieSize / 2 - 4
        let palette = [
            PDFStyleConfiguration.Colors.primaryGold,
            PDFStyleConfiguration.Colors.accentTeal,
            PDFStyleConfiguration.Colors.semanticEvidence,
            PDFStyleConfiguration.Colors.primaryGoldDark,
            PDFStyleConfiguration.Colors.borderDark
        ]
        var startA = -CGFloat.pi / 2
        for (i, seg) in segments.enumerated() {
            let sweep = CGFloat(seg.value / total) * 2 * .pi
            context.setFillColor(palette[i % palette.count].withAlphaComponent(0.85).cgColor)
            context.move(to: CGPoint(x: cx, y: cy))
            context.addArc(center: CGPoint(x: cx, y: cy), radius: r, startAngle: startA, endAngle: startA + sweep, clockwise: false)
            context.closePath()
            context.fillPath()
            startA += sweep
        }

        // Legend column
        let legX = point.x + padding + pieSize + 12
        let legW = max(20, maxWidth - padding - legX)
        var ly = point.y + headerHeight + padding + (body - legendH) / 2
        for (i, seg) in segments.enumerated() {
            let swatch = CGRect(x: legX, y: ly + (legendRow - 10) / 2, width: 10, height: 10)
            context.setFillColor(palette[i % palette.count].withAlphaComponent(0.85).cgColor)
            context.fill(swatch)
            let pct = seg.value / total * 100
            drawChartText("\(seg.label) — \(formatNumber(pct))%",
                          in: CGRect(x: legX + 16, y: ly, width: legW - 16, height: legendRow),
                          align: .left, size: 10, color: PDFStyleConfiguration.Colors.textBody, bold: false)
            ly += legendRow
        }

        return totalHeight + PDFStyleConfiguration.Spacing.blockSpacing
    }

    /// Shared container chrome (bg + border + header) for the chart renderers.
    private func drawDiagramContainer(context: CGContext, at point: CGPoint, width: CGFloat, height: CGFloat, title: String) {
        let padding: CGFloat = 16
        let headerHeight: CGFloat = 28
        let bgRect = CGRect(x: point.x, y: point.y, width: width, height: height)
        let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: PDFStyleConfiguration.Radius.md)
        context.addPath(bgPath.cgPath)
        context.setFillColor(PDFStyleConfiguration.Colors.bgSecondary.cgColor)
        context.fillPath()
        context.addPath(bgPath.cgPath)
        context.setStrokeColor(PDFStyleConfiguration.Colors.borderMedium.cgColor)
        context.setLineWidth(1.0)
        context.strokePath()
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.blockHeader(),
            .ligature: 0,
            .foregroundColor: PDFStyleConfiguration.Colors.primaryGoldDark
        ]
        NSAttributedString(string: title.uppercased(), attributes: headerAttributes)
            .draw(in: CGRect(x: point.x + padding, y: point.y + 6, width: width - padding * 2, height: headerHeight - 8))
    }

    private func drawChartText(_ text: String, in rect: CGRect, align: NSTextAlignment, size: CGFloat, color: UIColor, bold: Bool) {
        let p = NSMutableParagraphStyle()
        p.alignment = align
        p.lineBreakMode = .byTruncatingTail
        let font = UIFont(name: bold ? "Inter-Semibold" : "Inter-Regular", size: size)
            ?? UIFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular)
        let a = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: p])
        let measured = a.boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
                                      options: [.usesLineFragmentOrigin], context: nil).height
        let h = min(measured, rect.height)
        a.draw(in: CGRect(x: rect.minX, y: rect.midY - h / 2, width: rect.width, height: h))
    }

    /// Compact numeric formatting for chart labels: whole numbers drop decimals,
    /// otherwise one decimal place.
    private func formatNumber(_ value: Double) -> String {
        if value == value.rounded() { return String(Int(value)) }
        return String(format: "%.1f", value)
    }

    // MARK: - Funnel Diagram

    func calculateFunnelHeight(stages: [String], maxWidth: CGFloat) -> CGFloat {
        let headerHeight: CGFloat = 28
        let padding: CGFloat = 16
        let geo = pyramidGeometry(count: stages.count)   // same fixed-band geometry
        return headerHeight + geo.mapHeight + padding * 2 + PDFStyleConfiguration.Spacing.blockSpacing
    }

    /// Render a funnel: widest band at TOP, narrowing downward (inverse of the
    /// pyramid). Reuses the pyramid band geometry + label fitter; value rides in
    /// each stage's label string.
    @discardableResult
    func renderFunnel(
        title: String,
        stages: [String],
        to context: CGContext,
        at point: CGPoint,
        maxWidth: CGFloat
    ) -> CGFloat {
        let headerHeight: CGFloat = 28
        let padding: CGFloat = 16
        let geo = pyramidGeometry(count: stages.count)
        let totalHeight = headerHeight + geo.mapHeight + padding * 2

        // Container
        let bgRect = CGRect(x: point.x, y: point.y, width: maxWidth, height: totalHeight)
        let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: PDFStyleConfiguration.Radius.md)
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
            .ligature: 0,
            .foregroundColor: PDFStyleConfiguration.Colors.primaryGoldDark
        ]
        NSAttributedString(string: title.uppercased(), attributes: headerAttributes)
            .draw(in: CGRect(x: point.x + padding, y: point.y + 6, width: maxWidth - padding * 2, height: headerHeight - 8))

        // Bands — widest at TOP, narrowing down
        let n = max(1, stages.count)
        let maxBandWidth = maxWidth - padding * 2
        let minBandWidth = n == 1 ? maxBandWidth : maxBandWidth * 0.42
        let centerX = point.x + maxWidth / 2
        let bandsTop = point.y + headerHeight + padding

        for (index, label) in stages.enumerated() {
            let frac = n == 1 ? 1.0 : 1 - CGFloat(index) / CGFloat(n - 1)   // 1 = top (widest)
            let bandWidth = minBandWidth + (maxBandWidth - minBandWidth) * frac
            let bandY = bandsTop + CGFloat(index) * (geo.bandHeight + geo.bandGap)
            let bandRect = CGRect(x: centerX - bandWidth / 2, y: bandY, width: bandWidth, height: geo.bandHeight)
            let bandPath = UIBezierPath(roundedRect: bandRect, cornerRadius: 4)
            let tint = PDFStyleConfiguration.Colors.accentTeal.withAlphaComponent(0.12 + 0.12 * frac)
            context.addPath(bandPath.cgPath)
            context.setFillColor(tint.cgColor)
            context.fillPath()
            context.addPath(bandPath.cgPath)
            context.setStrokeColor(PDFStyleConfiguration.Colors.accentTeal.cgColor)
            context.setLineWidth(1.0)
            context.strokePath()
            drawPyramidLabel(context: context, text: label, in: bandRect)
        }

        return totalHeight + PDFStyleConfiguration.Spacing.blockSpacing
    }

    // MARK: - Cycle Diagram

    /// Shared ring geometry — SINGLE SOURCE for renderCycle (draw) and
    /// calculateCycleHeight (measure). Nodes sit on a ring (no center); adaptive
    /// like the concept map so they never overlap or clip — width binds first.
    private struct CycleGeometry {
        let nodeRadius: CGFloat
        let orbit: CGFloat
        let mapHeight: CGFloat
    }

    private func cycleGeometry(count: Int, maxWidth: CGFloat) -> CycleGeometry {
        let base: CGFloat = 36
        let floor: CGFloat = 16
        let margin: CGFloat = 12
        let n = max(1, count)
        if n == 1 {
            return CycleGeometry(nodeRadius: base, orbit: 0, mapHeight: 2 * base + 2 * margin)
        }
        let half = sin(.pi / CGFloat(n))                 // neighbor half-angle sine
        let orbitMax = maxWidth / 2 - floor - margin
        let orbitIdeal = max(base + 8, base / half)      // non-overlap orbit at base node
        var orbit = min(orbitIdeal, orbitMax)
        let node = max(floor, min(base, orbit * half, maxWidth / 2 - orbit - margin))
        orbit = min(orbit, maxWidth / 2 - node - margin)
        let mapHeight = 2 * (orbit + node) + 2 * margin
        return CycleGeometry(nodeRadius: node, orbit: orbit, mapHeight: mapHeight)
    }

    func calculateCycleHeight(stages: [String], maxWidth: CGFloat) -> CGFloat {
        let headerHeight: CGFloat = 28
        let padding: CGFloat = 16
        let geo = cycleGeometry(count: stages.count, maxWidth: maxWidth)
        return headerHeight + geo.mapHeight + padding * 2 + PDFStyleConfiguration.Spacing.blockSpacing
    }

    /// Render a cyclical process: stages on a ring, arrows following clockwise and
    /// closing back to the first (last → first), so it reads as a loop.
    @discardableResult
    func renderCycle(
        title: String,
        stages: [String],
        to context: CGContext,
        at point: CGPoint,
        maxWidth: CGFloat
    ) -> CGFloat {
        let headerHeight: CGFloat = 28
        let padding: CGFloat = 16
        let geo = cycleGeometry(count: stages.count, maxWidth: maxWidth)
        let totalHeight = headerHeight + geo.mapHeight + padding * 2

        // Container
        let bgRect = CGRect(x: point.x, y: point.y, width: maxWidth, height: totalHeight)
        let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: PDFStyleConfiguration.Radius.md)
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
            .ligature: 0,
            .foregroundColor: PDFStyleConfiguration.Colors.primaryGoldDark
        ]
        NSAttributedString(string: title.uppercased(), attributes: headerAttributes)
            .draw(in: CGRect(x: point.x + padding, y: point.y + 6, width: maxWidth - padding * 2, height: headerHeight - 8))

        // Node centers on the ring (start at top, clockwise)
        let n = max(1, stages.count)
        let mapY = point.y + headerHeight + padding
        let centerX = point.x + maxWidth / 2
        let centerY = mapY + geo.mapHeight / 2
        var centers: [CGPoint] = []
        for i in 0..<n {
            let angle = -CGFloat.pi / 2 + CGFloat(i) * (2 * CGFloat.pi / CGFloat(n))
            centers.append(CGPoint(x: centerX + geo.orbit * cos(angle), y: centerY + geo.orbit * sin(angle)))
        }

        // Ring arrows (draw under nodes) — close the loop
        if n >= 2 {
            for i in 0..<n {
                drawCycleArrow(context: context, from: centers[i], to: centers[(i + 1) % n],
                               nodeRadius: geo.nodeRadius, color: PDFStyleConfiguration.Colors.accentTeal)
            }
        }

        // Nodes on top
        for (i, stage) in stages.enumerated() {
            drawConceptNode(context: context, text: stage, center: centers[i],
                            radius: geo.nodeRadius, color: PDFStyleConfiguration.Colors.accentTeal, isCenter: false)
        }

        return totalHeight + PDFStyleConfiguration.Spacing.blockSpacing
    }

    private func drawCycleArrow(context: CGContext, from c0: CGPoint, to c1: CGPoint, nodeRadius r: CGFloat, color: UIColor) {
        let dx = c1.x - c0.x, dy = c1.y - c0.y
        let dist = max(1, hypot(dx, dy))
        let ux = dx / dist, uy = dy / dist
        let start = CGPoint(x: c0.x + ux * (r + 2), y: c0.y + uy * (r + 2))
        let end = CGPoint(x: c1.x - ux * (r + 5), y: c1.y - uy * (r + 5))
        context.setStrokeColor(color.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(1.5)
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()
        // Arrowhead
        let ah: CGFloat = 6
        let angle = atan2(uy, ux)
        let left = CGPoint(x: end.x - ah * cos(angle - .pi / 6), y: end.y - ah * sin(angle - .pi / 6))
        let right = CGPoint(x: end.x - ah * cos(angle + .pi / 6), y: end.y - ah * sin(angle + .pi / 6))
        context.setFillColor(color.cgColor)
        context.move(to: end)
        context.addLine(to: left)
        context.addLine(to: right)
        context.closePath()
        context.fillPath()
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
        phases rawPhases: [(name: String, description: String)],
        to context: CGContext,
        at point: CGPoint,
        maxWidth: CGFloat
    ) -> CGFloat {
        guard !rawPhases.isEmpty else { return 0 }
        let phases = rawPhases.map { (name: cleanDiagramNodeLabel($0.name), description: $0.description) }

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
            .ligature: 0,
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
                .ligature: 0,
                .foregroundColor: PDFStyleConfiguration.Colors.primaryGold,
                .paragraphStyle: centeredParagraphStyle()
            ]
            let numberText = NSAttributedString(string: "\(index + 1)", attributes: numberAttributes)
            let numberRect = CGRect(x: centerX - 10, y: lineY - 8, width: 20, height: 16)
            numberText.draw(in: numberRect)

            // Draw phase name below
            let nameAttributes: [NSAttributedString.Key: Any] = [
                .font: PDFStyleConfiguration.Typography.bodySmall(),
                .ligature: 0,
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
            .ligature: 0,
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
            .ligature: 0,
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
            .ligature: 0,
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
            .ligature: 0,
            .foregroundColor: PDFStyleConfiguration.Colors.accentTeal,
            .paragraphStyle: centeredParagraphStyle()
        ]
        NSAttributedString(string: zoneLabel.isEmpty ? "healthy range" : zoneLabel, attributes: zoneAttributes)
            .draw(in: CGRect(x: zoneRect.minX - 20, y: zoneRect.minY - 20, width: zoneRect.width + 40, height: 16))

        // Pole labels.
        let leftAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.bodySmall(),
            .ligature: 0,
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
