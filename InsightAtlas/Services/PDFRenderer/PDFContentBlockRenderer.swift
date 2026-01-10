import Foundation
import UIKit
import CoreGraphics

// MARK: - PDF Content Block Renderer
// Renders individual content blocks (paragraphs, headings, special blocks) to PDF

final class PDFContentBlockRenderer {

    // MARK: - Properties

    private let pageSize: CGSize
    private let contentRect: CGRect
    private let diagramRenderer: PDFDiagramRenderer

    // MARK: - Initialization

    init(
        pageSize: CGSize = PDFStyleConfiguration.PageLayout.pageSize,
        contentRect: CGRect = PDFStyleConfiguration.PageLayout.contentRect
    ) {
        self.pageSize = pageSize
        self.contentRect = contentRect
        self.diagramRenderer = PDFDiagramRenderer(pageSize: pageSize, contentRect: contentRect)
    }

    // MARK: - Block Height Calculation

    /// Calculate height for section heading - accounts for special PART header styling
    func calculateSectionHeadingHeight(_ text: String, level: Int, maxWidth: CGFloat) -> CGFloat {
        // Check if this is a PART header (PART I, PART II, etc.)
        if text.uppercased().hasPrefix("PART ") {
            // PART header has: padding (20) + ornament (24) + text spacing (8+4) + heading + text spacing (8+4) + ornament (24) + padding (20)
            let headingAttributes: [NSAttributedString.Key: Any] = [
                .font: PDFStyleConfiguration.Typography.displayH1(),
                .kern: 4.0
            ]
            let headingAttrString = NSAttributedString(string: text.uppercased(), attributes: headingAttributes)
            let headingSize = headingAttrString.size()
            return 20 + 24 + 12 + headingSize.height + 12 + 24 + 20
        }
        // Standard heading
        let attributes = PDFStyleConfiguration.headingAttributes(level: level)
        let spacing = level == 2 ? PDFStyleConfiguration.Spacing.sectionSpacing : PDFStyleConfiguration.Spacing.lg
        return calculateTextHeight(text, attributes: attributes, maxWidth: maxWidth) + spacing
    }

    /// Calculate the height required to render a block
    func calculateBlockHeight(block: PDFContentBlock, maxWidth: CGFloat) -> CGFloat {
        switch block.type {
        case .paragraph:
            return calculateTextHeight(block.content, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: maxWidth)
                + PDFStyleConfiguration.Spacing.paragraphSpacing

        case .heading1:
            return calculateTextHeight(block.content, attributes: PDFStyleConfiguration.headingAttributes(level: 1), maxWidth: maxWidth)
                + PDFStyleConfiguration.Spacing.sectionSpacing * 1.5

        case .heading2:
            return calculateTextHeight(block.content, attributes: PDFStyleConfiguration.headingAttributes(level: 2), maxWidth: maxWidth)
                + PDFStyleConfiguration.Spacing.sectionSpacing

        case .heading3:
            return calculateTextHeight(block.content, attributes: PDFStyleConfiguration.headingAttributes(level: 3), maxWidth: maxWidth)
                + PDFStyleConfiguration.Spacing.lg

        case .heading4:
            return calculateTextHeight(block.content, attributes: PDFStyleConfiguration.headingAttributes(level: 4), maxWidth: maxWidth)
                + PDFStyleConfiguration.Spacing.md

        case .blockquote:
            return calculateBlockquoteHeight(block.content, maxWidth: maxWidth)

        case .insightNote:
            return calculateInsightNoteHeight(content: block.content, maxWidth: maxWidth)

        case .actionBox:
            return calculateActionBoxHeight(title: block.metadata?["title"] ?? "Apply It", steps: block.listItems ?? [], maxWidth: maxWidth)

        case .keyTakeaways:
            return calculateTakeawaysHeight(items: block.listItems ?? [], maxWidth: maxWidth)

        case .foundationalNarrative:
            return calculateNarrativeHeight(content: block.content, title: block.metadata?["title"], maxWidth: maxWidth)

        case .exercise:
            return calculateExerciseHeight(content: block.content, steps: block.listItems ?? [], maxWidth: maxWidth)

        case .flowchart:
            return diagramRenderer.calculateFlowchartHeight(steps: block.listItems ?? [], maxWidth: maxWidth)

        case .quickGlance:
            return calculateQuickGlanceHeight(
                coreMessage: block.content,
                keyPoints: block.listItems ?? [],
                readingTime: block.metadata?["readingTime"],
                maxWidth: maxWidth
            )

        case .bulletList:
            return calculateListHeight(items: block.listItems ?? [], numbered: false, maxWidth: maxWidth)

        case .numberedList:
            return calculateListHeight(items: block.listItems ?? [], numbered: true, maxWidth: maxWidth)

        case .divider:
            return PDFStyleConfiguration.Spacing.xl2

        case .table:
            return calculateTableHeight(tableData: block.tableData ?? [], maxWidth: maxWidth)
            
        // Premium block types
        case .premiumQuote:
            return calculateBlockquoteHeight(block.content, maxWidth: maxWidth)
            
        case .authorSpotlight:
            return calculateSpecialBlockHeight(content: block.content, title: "Author Spotlight", maxWidth: maxWidth)
            
        case .premiumDivider:
            return PDFStyleConfiguration.Spacing.xl2
            
        case .premiumH1:
            return calculateTextHeight(block.content, attributes: PDFStyleConfiguration.headingAttributes(level: 1), maxWidth: maxWidth)
                + PDFStyleConfiguration.Spacing.sectionSpacing
            
        case .premiumH2:
            return calculateTextHeight(block.content, attributes: PDFStyleConfiguration.headingAttributes(level: 2), maxWidth: maxWidth)
                + PDFStyleConfiguration.Spacing.sectionSpacing
                
        // Additional premium block types
        case .alternativePerspective:
            return calculateSpecialBlockHeight(content: block.content, title: "Alternative Perspective", maxWidth: maxWidth)
            
        case .researchInsight:
            return calculateSpecialBlockHeight(content: block.content, title: "Research Insight", maxWidth: maxWidth)
            
        case .conceptMap:
            // Use diagram renderer for concept maps
            return diagramRenderer.calculateConceptMapHeight(
                centralConcept: block.metadata?["central"] ?? "Core Concept",
                relatedConcepts: block.listItems ?? [],
                maxWidth: maxWidth
            )
            
        case .processTimeline:
            // Use diagram renderer for process timelines
            return diagramRenderer.calculateProcessDiagramHeight(
                phases: block.listItems ?? [],
                maxWidth: maxWidth
            )

        case .visual:
            // Calculate height for visual image
            return calculateVisualHeight(block: block, maxWidth: maxWidth)

        // Synthesis Engine block types (v3.0)
        case .example:
            return calculateSpecialBlockHeight(content: block.content, title: block.metadata?["title"] ?? "Case Study", maxWidth: maxWidth)

        case .exerciseReflection:
            return calculateSpecialBlockHeight(content: block.content, title: "Reflection Question", maxWidth: maxWidth)
        }
    }

    // MARK: - Block Rendering

    /// Render a content block at the specified position
    /// Returns the height consumed by the block
    @discardableResult
    func renderBlock(
        _ block: PDFContentBlock,
        to context: CGContext,
        at point: CGPoint,
        maxWidth: CGFloat
    ) -> CGFloat {
        switch block.type {
        case .paragraph:
            return renderParagraph(block.content, to: context, at: point, maxWidth: maxWidth)

        case .heading1:
            return renderHeading(block.content, level: 1, icon: block.metadata?["icon"], to: context, at: point, maxWidth: maxWidth)

        case .heading2:
            return renderHeading(block.content, level: 2, icon: block.metadata?["icon"], to: context, at: point, maxWidth: maxWidth)

        case .heading3:
            return renderHeading(block.content, level: 3, icon: nil, to: context, at: point, maxWidth: maxWidth)

        case .heading4:
            return renderHeading(block.content, level: 4, icon: nil, to: context, at: point, maxWidth: maxWidth)

        case .blockquote:
            return renderBlockquote(block.content, cite: block.metadata?["cite"], to: context, at: point, maxWidth: maxWidth)

        case .insightNote:
            return renderInsightNote(
                content: block.content,
                title: block.metadata?["title"] ?? "Insight Atlas Note",
                to: context,
                at: point,
                maxWidth: maxWidth
            )

        case .actionBox:
            return renderActionBox(
                title: block.metadata?["title"] ?? "Apply It",
                steps: block.listItems ?? [],
                to: context,
                at: point,
                maxWidth: maxWidth
            )

        case .keyTakeaways:
            return renderKeyTakeaways(items: block.listItems ?? [], to: context, at: point, maxWidth: maxWidth)

        case .foundationalNarrative:
            return renderFoundationalNarrative(
                content: block.content,
                title: block.metadata?["title"],
                to: context,
                at: point,
                maxWidth: maxWidth
            )

        case .exercise:
            return renderExercise(
                content: block.content,
                title: block.metadata?["title"] ?? "Exercise",
                steps: block.listItems ?? [],
                estimatedTime: block.metadata?["time"],
                to: context,
                at: point,
                maxWidth: maxWidth
            )

        case .flowchart:
            return diagramRenderer.renderFlowchart(
                title: block.metadata?["title"] ?? "Visual Guide",
                steps: block.listItems ?? [],
                to: context,
                at: point,
                maxWidth: maxWidth
            )

        case .quickGlance:
            return renderQuickGlance(
                coreMessage: block.content,
                keyPoints: block.listItems ?? [],
                readingTime: block.metadata?["readingTime"],
                to: context,
                at: point,
                maxWidth: maxWidth
            )

        case .bulletList:
            return renderList(items: block.listItems ?? [], numbered: false, to: context, at: point, maxWidth: maxWidth)

        case .numberedList:
            return renderList(items: block.listItems ?? [], numbered: true, to: context, at: point, maxWidth: maxWidth)

        case .divider:
            return renderDivider(to: context, at: point, maxWidth: maxWidth)

        case .table:
            return renderTable(tableData: block.tableData ?? [], to: context, at: point, maxWidth: maxWidth)
            
        // Premium block types
        case .premiumQuote:
            return renderBlockquote(block.content, cite: block.metadata?["cite"], to: context, at: point, maxWidth: maxWidth)
            
        case .authorSpotlight:
            return renderSpecialBlock(
                content: block.content,
                title: "Author Spotlight",
                icon: "👤",
                borderColor: PDFStyleConfiguration.Colors.accentBurgundy,
                bgColor: PDFStyleConfiguration.Colors.accentBurgundy.withAlphaComponent(0.05),
                headerBgColor: PDFStyleConfiguration.Colors.accentBurgundy,
                to: context,
                at: point,
                maxWidth: maxWidth
            )
            
        case .premiumDivider:
            return renderDivider(to: context, at: point, maxWidth: maxWidth)
            
        case .premiumH1:
            return renderHeading(block.content, level: 1, icon: block.metadata?["icon"], to: context, at: point, maxWidth: maxWidth)
            
        case .premiumH2:
            return renderHeading(block.content, level: 2, icon: block.metadata?["icon"], to: context, at: point, maxWidth: maxWidth)
            
        // Additional premium block types
        case .alternativePerspective:
            return renderSpecialBlock(
                content: block.content,
                title: "Alternative Perspective",
                icon: "🔄",
                borderColor: PDFStyleConfiguration.Colors.accentOrange,
                bgColor: PDFStyleConfiguration.Colors.accentOrange.withAlphaComponent(0.05),
                headerBgColor: PDFStyleConfiguration.Colors.accentOrange,
                to: context,
                at: point,
                maxWidth: maxWidth
            )
            
        case .researchInsight:
            return renderSpecialBlock(
                content: block.content,
                title: "Research Insight",
                icon: "🔬",
                borderColor: PDFStyleConfiguration.Colors.accentTeal,
                bgColor: PDFStyleConfiguration.Colors.accentTeal.withAlphaComponent(0.05),
                headerBgColor: PDFStyleConfiguration.Colors.accentTeal,
                to: context,
                at: point,
                maxWidth: maxWidth
            )
            
        case .conceptMap:
            // Render concept map as a list for now (could be enhanced with actual diagram)
            let centralConcept = block.metadata?["central"] ?? "Core Concept"
            let concepts = block.listItems ?? []
            
            // Create a simple textual representation
            var conceptText = "Central Concept: \(centralConcept)\n\nRelated Concepts:\n"
            for (index, concept) in concepts.enumerated() {
                conceptText += "\(index + 1). \(concept)\n"
            }
            
            return renderSpecialBlock(
                content: conceptText,
                title: block.metadata?["title"] ?? "Concept Map",
                icon: "🗺",
                borderColor: PDFStyleConfiguration.Colors.primaryGold,
                bgColor: PDFStyleConfiguration.Colors.primaryGold.withAlphaComponent(0.05),
                headerBgColor: PDFStyleConfiguration.Colors.primaryGold,
                to: context,
                at: point,
                maxWidth: maxWidth
            )
            
        case .processTimeline:
            // Render process timeline
            return diagramRenderer.renderProcessDiagram(
                title: block.metadata?["title"] ?? "Process Timeline",
                phases: block.listItems?.map { (name: $0, description: "") } ?? [],
                to: context,
                at: point,
                maxWidth: maxWidth
            )

        case .visual:
            // Render visual image in PDF
            return renderVisual(block: block, to: context, at: point, maxWidth: maxWidth)

        // Synthesis Engine block types (v3.0)
        case .example:
            return renderSpecialBlock(
                content: block.content,
                title: block.metadata?["title"] ?? "Case Study",
                icon: "📋",
                borderColor: PDFStyleConfiguration.Colors.accentTeal,
                bgColor: PDFStyleConfiguration.Colors.accentTeal.withAlphaComponent(0.05),
                headerBgColor: PDFStyleConfiguration.Colors.accentTeal,
                to: context,
                at: point,
                maxWidth: maxWidth
            )

        case .exerciseReflection:
            return renderSpecialBlock(
                content: block.content,
                title: "Reflection Question",
                icon: "💭",
                borderColor: PDFStyleConfiguration.Colors.accentPurple,
                bgColor: PDFStyleConfiguration.Colors.accentPurple.withAlphaComponent(0.05),
                headerBgColor: PDFStyleConfiguration.Colors.accentPurple,
                to: context,
                at: point,
                maxWidth: maxWidth
            )
        }
    }

    // MARK: - Private Rendering Methods
    
    /// Render a section heading with the specified level
    /// Returns the height consumed
    func renderSectionHeading(_ text: String, level: Int, to context: CGContext, at point: CGPoint, maxWidth: CGFloat) -> CGFloat {
        // Check if this is a PART header (PART I, PART II, etc.)
        if text.uppercased().hasPrefix("PART ") {
            return renderPartHeader(text, to: context, at: point, maxWidth: maxWidth)
        }
        return renderHeading(text, level: level, icon: nil, to: context, at: point, maxWidth: maxWidth)
    }

    /// Render a premium PART header with diamond ornaments
    private func renderPartHeader(_ text: String, to context: CGContext, at point: CGPoint, maxWidth: CGFloat) -> CGFloat {
        let padding: CGFloat = 20
        let ornamentHeight: CGFloat = 24
        let textSpacing: CGFloat = 8

        var currentY = point.y + padding

        // Draw top ornament
        let ornamentText = "◇  ◆  ◇"
        let ornamentAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.body(),
            .foregroundColor: PDFStyleConfiguration.Colors.primaryGold
        ]
        let ornamentAttrString = NSAttributedString(string: ornamentText, attributes: ornamentAttributes)
        let ornamentSize = ornamentAttrString.size()
        let ornamentX = point.x + (maxWidth - ornamentSize.width) / 2
        ornamentAttrString.draw(at: CGPoint(x: ornamentX, y: currentY))
        currentY += ornamentHeight

        // Draw top gold line
        context.setStrokeColor(PDFStyleConfiguration.Colors.primaryGold.cgColor)
        context.setLineWidth(1.0)
        let lineStartX = point.x + maxWidth * 0.2
        let lineEndX = point.x + maxWidth * 0.8
        context.move(to: CGPoint(x: lineStartX, y: currentY))
        context.addLine(to: CGPoint(x: lineEndX, y: currentY))
        context.strokePath()
        currentY += textSpacing + 4

        // Draw PART header text
        let headingAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.displayH1(),
            .foregroundColor: PDFStyleConfiguration.Colors.textHeading,
            .kern: 4.0
        ]
        let headingAttrString = NSAttributedString(string: text.uppercased(), attributes: headingAttributes)
        let headingSize = headingAttrString.size()
        let headingX = point.x + (maxWidth - headingSize.width) / 2
        headingAttrString.draw(at: CGPoint(x: headingX, y: currentY))
        currentY += headingSize.height + textSpacing + 4

        // Draw bottom gold line
        context.move(to: CGPoint(x: lineStartX, y: currentY))
        context.addLine(to: CGPoint(x: lineEndX, y: currentY))
        context.strokePath()
        currentY += textSpacing

        // Draw bottom ornament
        ornamentAttrString.draw(at: CGPoint(x: ornamentX, y: currentY))
        currentY += ornamentHeight + padding

        return currentY - point.y
    }

    private func renderParagraph(_ text: String, to context: CGContext, at point: CGPoint, maxWidth: CGFloat) -> CGFloat {
        let attributedText = parseInlineMarkdown(text, baseAttributes: PDFStyleConfiguration.bodyAttributes())
        let height = drawAttributedString(attributedText, to: context, at: point, maxWidth: maxWidth)
        return height + PDFStyleConfiguration.Spacing.paragraphSpacing
    }

    private func renderHeading(_ text: String, level: Int, icon: String?, to context: CGContext, at point: CGPoint, maxWidth: CGFloat) -> CGFloat {
        var currentY = point.y
        let spacing: CGFloat

        // Standardized heading hierarchy:
        // H1 (PART headers): 30pt, Burnt Orange (#D35F2E), all caps, with ornaments
        // H2 (Section titles): 26pt, Ink Black (#2A2725), title case, gold underline
        // H3 (Subsections): 22pt, Ink Black, title case
        // H4 (Minor headings): 19pt, dark gray
        switch level {
        case 1:
            spacing = PDFStyleConfiguration.Spacing.sectionSpacing
            currentY += PDFStyleConfiguration.Spacing.headingTopMargin
        case 2:
            spacing = PDFStyleConfiguration.Spacing.sectionSpacing
            currentY += PDFStyleConfiguration.Spacing.headingTopMargin
        case 3:
            spacing = PDFStyleConfiguration.Spacing.headingBottomMargin + 8
            currentY += PDFStyleConfiguration.Spacing.md
        default:
            spacing = PDFStyleConfiguration.Spacing.headingBottomMargin
            currentY += PDFStyleConfiguration.Spacing.sm
        }

        // Prepare text with optional icon
        let displayText = icon.map { "\($0) \(text)" } ?? text

        // Consistent color scheme per heading level
        let color: UIColor
        switch level {
        case 1:
            color = PDFStyleConfiguration.Colors.primaryGold  // Burnt Orange for PART headers
        case 2:
            color = PDFStyleConfiguration.Colors.textHeading  // Ink Black for section titles
        case 3:
            color = PDFStyleConfiguration.Colors.textHeading  // Ink Black for subsections
        default:
            color = PDFStyleConfiguration.Colors.textSecondary // Warm Gray for minor headings
        }

        let attributes = PDFStyleConfiguration.headingAttributes(level: level, color: color)
        let attributedText = NSAttributedString(string: displayText, attributes: attributes)
        let height = drawAttributedString(attributedText, to: context, at: CGPoint(x: point.x, y: currentY), maxWidth: maxWidth)

        // Draw decorative lines for H1 and H2
        if level == 1 {
            // Full-width divider for H1 (PART headings) - gold underline
            let lineY = currentY + height + 4
            context.setStrokeColor(PDFStyleConfiguration.Colors.primaryGold.withAlphaComponent(0.5).cgColor)
            context.setLineWidth(1.5)
            context.move(to: CGPoint(x: point.x, y: lineY))
            context.addLine(to: CGPoint(x: point.x + maxWidth, y: lineY))
            context.strokePath()
        } else if level == 2 {
            // Gold underline accent for H2 section titles
            let lineY = currentY + height + 3
            let lineWidth: CGFloat = 50

            context.setStrokeColor(PDFStyleConfiguration.Colors.primaryGold.cgColor)
            context.setLineWidth(2.0)
            context.move(to: CGPoint(x: point.x, y: lineY))
            context.addLine(to: CGPoint(x: point.x + lineWidth, y: lineY))
            context.strokePath()
        }

        return (currentY - point.y) + height + spacing
    }

    private func renderBlockquote(_ text: String, cite: String?, to context: CGContext, at point: CGPoint, maxWidth: CGFloat) -> CGFloat {
        let padding: CGFloat = 16
        let borderWidth: CGFloat = 4  // Increased from 3pt to 4pt for more visual distinction
        let rightPadding: CGFloat = 12  // Subtle right padding
        let insetWidth = maxWidth - padding * 2 - borderWidth - rightPadding

        // Calculate text height with proper quote styling
        let attributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.bodyItalic(),
            .foregroundColor: PDFStyleConfiguration.Colors.textBody,
            .paragraphStyle: PDFStyleConfiguration.paragraphStyle(lineHeight: 20, alignment: .left, paragraphSpacing: 8)
        ]
        let textHeight = calculateTextHeight(text, attributes: attributes, maxWidth: insetWidth)

        // Calculate total height: quote mark + padding + text + citation + bottom padding
        let quoteMarkHeight: CGFloat = 24
        var totalHeight = quoteMarkHeight + padding + textHeight + padding

        // Add cite height if present
        var citeHeight: CGFloat = 0
        if let cite = cite, !cite.isEmpty {
            let citeAttributes = PDFStyleConfiguration.captionAttributes(color: PDFStyleConfiguration.Colors.textMuted, alignment: .right)
            citeHeight = calculateTextHeight("— \(cite)", attributes: citeAttributes, maxWidth: insetWidth)
            totalHeight += citeHeight + 6
        }

        // Draw background with subtle rounded corners on right side
        let bgRect = CGRect(x: point.x, y: point.y, width: maxWidth, height: totalHeight)
        context.setFillColor(PDFStyleConfiguration.BlockStyles.blockquoteBgColor.cgColor)
        context.fill(bgRect)

        // Draw left border (thicker for visual distinction)
        context.setFillColor(PDFStyleConfiguration.BlockStyles.blockquoteBorderColor.cgColor)
        context.fill(CGRect(x: point.x, y: point.y, width: borderWidth, height: totalHeight))

        // Draw decorative opening quote mark
        let quoteMarkAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "CormorantGaramond-Bold", size: 36) ?? UIFont.boldSystemFont(ofSize: 36),
            .foregroundColor: PDFStyleConfiguration.Colors.primaryGold.withAlphaComponent(0.4)
        ]
        let quoteMark = NSAttributedString(string: "\u{201C}", attributes: quoteMarkAttributes)
        let quoteMarkRect = CGRect(x: point.x + borderWidth + 8, y: point.y + 4, width: 30, height: quoteMarkHeight)
        quoteMark.draw(in: quoteMarkRect)

        // Draw text
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        let textPoint = CGPoint(x: point.x + borderWidth + padding, y: point.y + quoteMarkHeight + 4)
        let drawnTextHeight = drawAttributedString(attributedText, to: context, at: textPoint, maxWidth: insetWidth)

        // Draw citation with proper styling
        if let cite = cite, !cite.isEmpty {
            let citeAttributes: [NSAttributedString.Key: Any] = [
                .font: PDFStyleConfiguration.Typography.caption(),
                .foregroundColor: PDFStyleConfiguration.BlockStyles.blockquoteBorderColor,
                .paragraphStyle: PDFStyleConfiguration.paragraphStyle(lineHeight: 12, alignment: .right, paragraphSpacing: 0)
            ]
            let citeText = NSAttributedString(string: "— \(cite)", attributes: citeAttributes)
            let citeY = point.y + quoteMarkHeight + 4 + drawnTextHeight + 8
            let citeRect = CGRect(x: point.x + borderWidth + padding, y: citeY, width: insetWidth, height: citeHeight + 4)
            citeText.draw(in: citeRect)
        }

        return totalHeight + PDFStyleConfiguration.Spacing.blockSpacing
    }

    private func renderInsightNote(content: String, title: String, to context: CGContext, at point: CGPoint, maxWidth: CGFloat) -> CGFloat {
        // Parse structured content
        let parsed = parseInsightNoteContent(content)

        let padding: CGFloat = 14
        let headerHeight: CGFloat = 30
        let sectionSpacing: CGFloat = 8
        let borderRadius: CGFloat = 6.0
        let leftAccentWidth: CGFloat = 4  // Increased from 3pt to 4pt for visual hierarchy
        let subsectionAccentWidth: CGFloat = 4  // Left accent bar for subsections
        let insetWidth = maxWidth - padding * 2 - leftAccentWidth

        // Calculate heights for each section
        var contentHeight: CGFloat = 0

        // Core connection
        if !parsed.coreConnection.isEmpty {
            contentHeight += calculateTextHeight(parsed.coreConnection, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: insetWidth)
            contentHeight += sectionSpacing + 4
        }

        // Key Distinction section
        if let keyDist = parsed.keyDistinction, !keyDist.isEmpty {
            contentHeight += 20 // Label height (increased)
            contentHeight += calculateTextHeight(keyDist, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: insetWidth - 20)
            contentHeight += 16 // Section padding
            contentHeight += sectionSpacing
        }

        // Practical Implication section
        if let practical = parsed.practicalImplication, !practical.isEmpty {
            contentHeight += 20 // Label height (increased)
            contentHeight += calculateTextHeight(practical, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: insetWidth - 20)
            contentHeight += 16 // Section padding
            contentHeight += sectionSpacing
        }

        // Go Deeper section
        if let goDeeper = parsed.goDeeper, !goDeeper.isEmpty {
            contentHeight += 20 // Label height (increased)
            contentHeight += calculateTextHeight(goDeeper, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: insetWidth - 20)
            contentHeight += 16 // Section padding
        }

        let totalHeight = headerHeight + contentHeight + padding * 2

        // Draw background with border
        let bgRect = CGRect(x: point.x, y: point.y, width: maxWidth, height: totalHeight)
        let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: borderRadius)

        context.saveGState()
        context.addPath(bgPath.cgPath)
        context.setFillColor(PDFStyleConfiguration.BlockStyles.insightNoteBgColor.cgColor)
        context.fillPath()

        context.addPath(bgPath.cgPath)
        context.setStrokeColor(PDFStyleConfiguration.BlockStyles.insightNoteBorderColor.cgColor)
        context.setLineWidth(1.0)
        context.strokePath()

        // Draw left accent bar (main - increased width)
        let accentRect = CGRect(x: point.x, y: point.y, width: leftAccentWidth, height: totalHeight)
        let accentPath = UIBezierPath(
            roundedRect: accentRect,
            byRoundingCorners: [.topLeft, .bottomLeft],
            cornerRadii: CGSize(width: borderRadius, height: borderRadius)
        )
        context.addPath(accentPath.cgPath)
        context.setFillColor(PDFStyleConfiguration.BlockStyles.insightNoteBorderColor.cgColor)
        context.fillPath()
        context.restoreGState()

        // Draw header with enhanced label weight
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Inter-Bold", size: 13) ?? PDFStyleConfiguration.Typography.blockHeader(),
            .foregroundColor: PDFStyleConfiguration.BlockStyles.insightNoteIconColor
        ]
        let headerText = NSAttributedString(string: "\(PDFStyleConfiguration.Icons.insightNote) \(title.uppercased())", attributes: headerAttributes)
        let headerTextRect = CGRect(x: point.x + padding + leftAccentWidth, y: point.y + 8, width: maxWidth - padding * 2 - leftAccentWidth, height: headerHeight - 10)
        headerText.draw(in: headerTextRect)

        // Draw divider
        let dividerY = point.y + headerHeight
        context.setStrokeColor(PDFStyleConfiguration.BlockStyles.insightNoteBorderColor.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: point.x + padding + leftAccentWidth, y: dividerY))
        context.addLine(to: CGPoint(x: point.x + maxWidth - padding, y: dividerY))
        context.strokePath()

        // Draw content sections
        var currentY = point.y + headerHeight + padding

        // Core connection
        if !parsed.coreConnection.isEmpty {
            let coreAttributed = parseInlineMarkdown(parsed.coreConnection, baseAttributes: PDFStyleConfiguration.bodyAttributes())
            let coreHeight = drawAttributedString(coreAttributed, to: context, at: CGPoint(x: point.x + padding + leftAccentWidth, y: currentY), maxWidth: insetWidth)
            currentY += coreHeight + sectionSpacing + 4
        }

        // Key Distinction section - Light orange background (distinct from Insight Note's main orange)
        if let keyDist = parsed.keyDistinction, !keyDist.isEmpty {
            let sectionHeight = 20 + calculateTextHeight(keyDist, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: insetWidth - 20) + 12
            let sectionRect = CGRect(x: point.x + padding + leftAccentWidth, y: currentY, width: insetWidth, height: sectionHeight)

            // Light orange background (0.08 opacity) - distinct for Key Distinction
            context.setFillColor(PDFStyleConfiguration.Colors.brandOrange.withAlphaComponent(0.08).cgColor)
            context.fill(sectionRect)

            // Left accent bar - increased to 4pt
            context.setFillColor(PDFStyleConfiguration.Colors.brandOrange.cgColor)
            context.fill(CGRect(x: point.x + padding + leftAccentWidth, y: currentY, width: subsectionAccentWidth, height: sectionHeight))

            // Subtle bottom border for visual separation
            context.setStrokeColor(PDFStyleConfiguration.Colors.brandOrange.withAlphaComponent(0.2).cgColor)
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: point.x + padding + leftAccentWidth + subsectionAccentWidth + 8, y: currentY + sectionHeight - 1))
            context.addLine(to: CGPoint(x: point.x + maxWidth - padding, y: currentY + sectionHeight - 1))
            context.strokePath()

            // Enhanced label weight
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Inter-Bold", size: 11) ?? PDFStyleConfiguration.Typography.captionBold(),
                .foregroundColor: PDFStyleConfiguration.Colors.brandOrange
            ]
            let labelText = NSAttributedString(string: "KEY DISTINCTION", attributes: labelAttributes)
            labelText.draw(at: CGPoint(x: point.x + padding + leftAccentWidth + subsectionAccentWidth + 8, y: currentY + 4))

            // Draw content
            let keyAttributed = parseInlineMarkdown(keyDist, baseAttributes: PDFStyleConfiguration.bodyAttributes())
            drawAttributedString(keyAttributed, to: context, at: CGPoint(x: point.x + padding + leftAccentWidth + subsectionAccentWidth + 8, y: currentY + 22), maxWidth: insetWidth - 20)
            currentY += sectionHeight + sectionSpacing
        }

        // Practical Implication section - Light gold background
        if let practical = parsed.practicalImplication, !practical.isEmpty {
            let sectionHeight = 20 + calculateTextHeight(practical, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: insetWidth - 20) + 12
            let sectionRect = CGRect(x: point.x + padding + leftAccentWidth, y: currentY, width: insetWidth, height: sectionHeight)

            // Light gold background (0.08 opacity)
            context.setFillColor(PDFStyleConfiguration.Colors.primaryGold.withAlphaComponent(0.08).cgColor)
            context.fill(sectionRect)

            // Left accent bar
            context.setFillColor(PDFStyleConfiguration.Colors.primaryGold.cgColor)
            context.fill(CGRect(x: point.x + padding + leftAccentWidth, y: currentY, width: subsectionAccentWidth, height: sectionHeight))

            // Subtle bottom border
            context.setStrokeColor(PDFStyleConfiguration.Colors.primaryGold.withAlphaComponent(0.2).cgColor)
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: point.x + padding + leftAccentWidth + subsectionAccentWidth + 8, y: currentY + sectionHeight - 1))
            context.addLine(to: CGPoint(x: point.x + maxWidth - padding, y: currentY + sectionHeight - 1))
            context.strokePath()

            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Inter-Bold", size: 11) ?? PDFStyleConfiguration.Typography.captionBold(),
                .foregroundColor: PDFStyleConfiguration.Colors.primaryGold
            ]
            let labelText = NSAttributedString(string: "PRACTICAL IMPLICATION", attributes: labelAttributes)
            labelText.draw(at: CGPoint(x: point.x + padding + leftAccentWidth + subsectionAccentWidth + 8, y: currentY + 4))

            let practicalAttributed = parseInlineMarkdown(practical, baseAttributes: PDFStyleConfiguration.bodyAttributes())
            drawAttributedString(practicalAttributed, to: context, at: CGPoint(x: point.x + padding + leftAccentWidth + subsectionAccentWidth + 8, y: currentY + 22), maxWidth: insetWidth - 20)
            currentY += sectionHeight + sectionSpacing
        }

        // Go Deeper section - Light burgundy/gold background
        if let goDeeper = parsed.goDeeper, !goDeeper.isEmpty {
            let sectionHeight = 20 + calculateTextHeight(goDeeper, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: insetWidth - 20) + 12
            let sectionRect = CGRect(x: point.x + padding + leftAccentWidth, y: currentY, width: insetWidth, height: sectionHeight)

            // Light burgundy background (0.08 opacity)
            context.setFillColor(PDFStyleConfiguration.Colors.accentBurgundy.withAlphaComponent(0.08).cgColor)
            context.fill(sectionRect)

            // Left accent bar
            context.setFillColor(PDFStyleConfiguration.Colors.accentBurgundy.cgColor)
            context.fill(CGRect(x: point.x + padding + leftAccentWidth, y: currentY, width: subsectionAccentWidth, height: sectionHeight))

            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Inter-Bold", size: 11) ?? PDFStyleConfiguration.Typography.captionBold(),
                .foregroundColor: PDFStyleConfiguration.Colors.accentBurgundy
            ]
            let labelText = NSAttributedString(string: "GO DEEPER", attributes: labelAttributes)
            labelText.draw(at: CGPoint(x: point.x + padding + leftAccentWidth + subsectionAccentWidth + 8, y: currentY + 4))

            var italicAttributes = PDFStyleConfiguration.bodyAttributes()
            italicAttributes[.font] = PDFStyleConfiguration.Typography.bodyItalic()
            let goAttributed = parseInlineMarkdown(goDeeper, baseAttributes: italicAttributes)
            drawAttributedString(goAttributed, to: context, at: CGPoint(x: point.x + padding + leftAccentWidth + subsectionAccentWidth + 8, y: currentY + 22), maxWidth: insetWidth - 20)
        }

        return totalHeight + PDFStyleConfiguration.Spacing.blockSpacing
    }

    /// Parse insight note content into structured components
    private func parseInsightNoteContent(_ content: String) -> (coreConnection: String, keyDistinction: String?, practicalImplication: String?, goDeeper: String?) {
        var coreConnection = ""
        var keyDistinction: String?
        var practicalImplication: String?
        var goDeeper: String?

        let normalizedContent = content.replacingOccurrences(of: "\n", with: " ")

        if let keyStart = normalizedContent.range(of: "Key Distinction:", options: .caseInsensitive) {
            var keyText = String(normalizedContent[keyStart.upperBound...])
            if let practicalStart = keyText.range(of: "Practical Implication:", options: .caseInsensitive) {
                keyText = String(keyText[..<practicalStart.lowerBound])
            } else if let goStart = keyText.range(of: "Go Deeper:", options: .caseInsensitive) {
                keyText = String(keyText[..<goStart.lowerBound])
            }
            keyDistinction = keyText.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let practStart = normalizedContent.range(of: "Practical Implication:", options: .caseInsensitive) {
            var practText = String(normalizedContent[practStart.upperBound...])
            if let goStart = practText.range(of: "Go Deeper:", options: .caseInsensitive) {
                practText = String(practText[..<goStart.lowerBound])
            }
            practicalImplication = practText.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let goStart = normalizedContent.range(of: "Go Deeper:", options: .caseInsensitive) {
            let goText = String(normalizedContent[goStart.upperBound...])
            goDeeper = goText.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var coreText = normalizedContent
        if let keyRange = normalizedContent.range(of: "Key Distinction:", options: .caseInsensitive) {
            coreText = String(normalizedContent[..<keyRange.lowerBound])
        } else if let keyRange = normalizedContent.range(of: "**Key Distinction", options: .caseInsensitive) {
            coreText = String(normalizedContent[..<keyRange.lowerBound])
        }
        coreConnection = coreText.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespacesAndNewlines)

        return (coreConnection, keyDistinction, practicalImplication, goDeeper)
    }

    /// Calculate height for structured insight note
    private func calculateInsightNoteHeight(content: String, maxWidth: CGFloat) -> CGFloat {
        let parsed = parseInsightNoteContent(content)

        let padding: CGFloat = 14
        let headerHeight: CGFloat = 30
        let sectionSpacing: CGFloat = 8
        let leftAccentWidth: CGFloat = 4
        let insetWidth = maxWidth - padding * 2 - leftAccentWidth

        var contentHeight: CGFloat = 0

        // Core connection
        if !parsed.coreConnection.isEmpty {
            contentHeight += calculateTextHeight(parsed.coreConnection, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: insetWidth)
            contentHeight += sectionSpacing + 4
        }

        // Key Distinction section
        if let keyDist = parsed.keyDistinction, !keyDist.isEmpty {
            contentHeight += 20 // Label height (increased)
            contentHeight += calculateTextHeight(keyDist, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: insetWidth - 20)
            contentHeight += 16 // Section padding
            contentHeight += sectionSpacing
        }

        // Practical Implication section
        if let practical = parsed.practicalImplication, !practical.isEmpty {
            contentHeight += 20 // Label height (increased)
            contentHeight += calculateTextHeight(practical, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: insetWidth - 20)
            contentHeight += 16 // Section padding
            contentHeight += sectionSpacing
        }

        // Go Deeper section
        if let goDeeper = parsed.goDeeper, !goDeeper.isEmpty {
            contentHeight += 20 // Label height (increased)
            contentHeight += calculateTextHeight(goDeeper, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: insetWidth - 20)
            contentHeight += 16 // Section padding
        }

        return headerHeight + contentHeight + padding * 2 + PDFStyleConfiguration.Spacing.blockSpacing
    }

    private func renderActionBox(title: String, steps: [String], to context: CGContext, at point: CGPoint, maxWidth: CGFloat) -> CGFloat {
        let padding: CGFloat = 14
        let headerHeight: CGFloat = 30
        let borderRadius: CGFloat = 6.0
        let numberWidth: CGFloat = 28  // Consistent left padding for wrapped lines
        let insetWidth = maxWidth - padding * 2

        // Calculate content height
        var contentHeight: CGFloat = 0
        for step in steps {
            let stepHeight = calculateTextHeight(step, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: insetWidth - numberWidth)
            contentHeight += stepHeight + 10  // Slightly more spacing between steps
        }

        let totalHeight = headerHeight + contentHeight + padding * 2

        // Draw background with border
        let bgRect = CGRect(x: point.x, y: point.y, width: maxWidth, height: totalHeight)
        let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: borderRadius)

        context.saveGState()
        context.addPath(bgPath.cgPath)
        context.setFillColor(PDFStyleConfiguration.BlockStyles.actionBoxBgColor.cgColor)
        context.fillPath()

        context.addPath(bgPath.cgPath)
        context.setStrokeColor(PDFStyleConfiguration.BlockStyles.actionBoxBorderColor.cgColor)
        context.setLineWidth(1.0)
        context.strokePath()
        context.restoreGState()

        // Draw header background
        let headerRect = CGRect(x: point.x, y: point.y, width: maxWidth, height: headerHeight)
        let headerPath = UIBezierPath(
            roundedRect: headerRect,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: borderRadius, height: borderRadius)
        )
        context.addPath(headerPath.cgPath)
        context.setFillColor(PDFStyleConfiguration.BlockStyles.actionBoxHeaderBgColor.cgColor)
        context.fillPath()

        // Draw header text
        let headerAttributes = PDFStyleConfiguration.blockHeaderAttributes(color: PDFStyleConfiguration.Colors.textInverse)
        let headerText = NSAttributedString(string: "\(PDFStyleConfiguration.Icons.actionBox) \(title.uppercased())", attributes: headerAttributes)
        let headerTextRect = CGRect(x: point.x + padding, y: point.y + 8, width: maxWidth - padding * 2, height: headerHeight - 10)
        headerText.draw(in: headerTextRect)

        // Draw steps with bold orange numbers and consistent alignment
        var currentY = point.y + headerHeight + padding
        for (index, step) in steps.enumerated() {
            // Bold orange number
            let numberAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Inter-Bold", size: 17) ?? PDFStyleConfiguration.Typography.bodyBold(),
                .foregroundColor: PDFStyleConfiguration.Colors.primaryGold
            ]
            let numberText = NSAttributedString(string: "\(index + 1).", attributes: numberAttributes)
            let numberRect = CGRect(x: point.x + padding, y: currentY, width: numberWidth - 4, height: 20)
            numberText.draw(in: numberRect)

            // Step text with consistent left padding for wrapped lines
            let stepAttributes = PDFStyleConfiguration.bodyAttributes()
            let stepAttributed = parseInlineMarkdown(step, baseAttributes: stepAttributes)
            let stepHeight = drawAttributedString(
                stepAttributed,
                to: context,
                at: CGPoint(x: point.x + padding + numberWidth, y: currentY),
                maxWidth: insetWidth - numberWidth
            )

            currentY += stepHeight + 10
        }

        return totalHeight + PDFStyleConfiguration.Spacing.blockSpacing
    }

    private func renderKeyTakeaways(items: [String], to context: CGContext, at point: CGPoint, maxWidth: CGFloat) -> CGFloat {
        let padding: CGFloat = 12
        let headerHeight: CGFloat = 28
        let borderRadius = PDFStyleConfiguration.Radius.md
        let insetWidth = maxWidth - padding * 2

        // Calculate content height
        var contentHeight: CGFloat = 0
        for item in items {
            let itemHeight = calculateTextHeight(item, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: insetWidth - 20)
            contentHeight += itemHeight + 8
        }

        let totalHeight = headerHeight + contentHeight + padding * 2

        // Draw background
        let bgRect = CGRect(x: point.x, y: point.y, width: maxWidth, height: totalHeight)
        let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: borderRadius)

        context.addPath(bgPath.cgPath)
        context.setFillColor(PDFStyleConfiguration.BlockStyles.takeawaysBgColor.cgColor)
        context.fillPath()

        context.addPath(bgPath.cgPath)
        context.setStrokeColor(PDFStyleConfiguration.BlockStyles.takeawaysBorderColor.cgColor)
        context.setLineWidth(1.0)
        context.strokePath()

        // Draw header
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.blockHeader(),
            .foregroundColor: PDFStyleConfiguration.Colors.primaryGoldDark
        ]
        let headerText = NSAttributedString(string: "\(PDFStyleConfiguration.Icons.takeaways) KEY TAKEAWAYS", attributes: headerAttributes)
        let headerRect = CGRect(x: point.x + padding, y: point.y + 6, width: maxWidth - padding * 2, height: headerHeight - 8)
        headerText.draw(in: headerRect)

        // Draw divider line
        let dividerY = point.y + headerHeight
        context.setStrokeColor(PDFStyleConfiguration.BlockStyles.takeawaysBorderColor.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: point.x + padding, y: dividerY))
        context.addLine(to: CGPoint(x: point.x + maxWidth - padding, y: dividerY))
        context.strokePath()

        // Draw items
        var currentY = point.y + headerHeight + padding
        for item in items {
            // Draw star bullet
            let bulletAttributes: [NSAttributedString.Key: Any] = [
                .font: PDFStyleConfiguration.Typography.body(),
                .foregroundColor: PDFStyleConfiguration.Colors.primaryGold
            ]
            let bulletText = NSAttributedString(string: "★", attributes: bulletAttributes)
            let bulletRect = CGRect(x: point.x + padding, y: currentY, width: 16, height: 18)
            bulletText.draw(in: bulletRect)

            // Draw item text
            let itemAttributed = parseInlineMarkdown(item, baseAttributes: PDFStyleConfiguration.bodyAttributes())
            let itemHeight = drawAttributedString(
                itemAttributed,
                to: context,
                at: CGPoint(x: point.x + padding + 20, y: currentY),
                maxWidth: insetWidth - 20
            )

            currentY += itemHeight + 8
        }

        return totalHeight + PDFStyleConfiguration.Spacing.blockSpacing
    }

    private func renderFoundationalNarrative(content: String, title: String?, to context: CGContext, at point: CGPoint, maxWidth: CGFloat) -> CGFloat {
        return renderSpecialBlock(
            content: content,
            title: title ?? "The Story Behind the Ideas",
            icon: PDFStyleConfiguration.Icons.narrative,
            borderColor: PDFStyleConfiguration.BlockStyles.narrativeBorderColor,
            bgColor: PDFStyleConfiguration.BlockStyles.narrativeBgColor,
            headerBgColor: PDFStyleConfiguration.BlockStyles.narrativeBorderColor,
            to: context,
            at: point,
            maxWidth: maxWidth
        )
    }

    private func renderExercise(content: String, title: String, steps: [String], estimatedTime: String?, to context: CGContext, at point: CGPoint, maxWidth: CGFloat) -> CGFloat {
        let padding: CGFloat = 14
        let headerHeight: CGFloat = 30
        let borderRadius: CGFloat = 6.0
        let numberWidth: CGFloat = 28
        let insetWidth = maxWidth - padding * 2

        // Parse content for potential markdown tables
        let (regularContent, tableData) = parseContentForTables(content)

        // Calculate content height
        var contentHeight: CGFloat = 0

        if !regularContent.isEmpty {
            contentHeight += calculateTextHeight(regularContent, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: insetWidth) + 12
        }

        // Add table height if table was found
        if !tableData.isEmpty {
            contentHeight += calculateTableHeight(tableData: tableData, maxWidth: insetWidth) + 8
        }

        for step in steps {
            let stepHeight = calculateTextHeight(step, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: insetWidth - numberWidth)
            contentHeight += stepHeight + 10
        }

        if let time = estimatedTime, !time.isEmpty {
            contentHeight += 24 // Time badge height
        }

        let totalHeight = headerHeight + contentHeight + padding * 2

        // Draw background
        let bgRect = CGRect(x: point.x, y: point.y, width: maxWidth, height: totalHeight)
        let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: borderRadius)

        context.addPath(bgPath.cgPath)
        context.setFillColor(PDFStyleConfiguration.BlockStyles.exerciseBgColor.cgColor)
        context.fillPath()

        context.addPath(bgPath.cgPath)
        context.setStrokeColor(PDFStyleConfiguration.BlockStyles.exerciseBorderColor.cgColor)
        context.setLineWidth(1.0)
        context.strokePath()

        // Draw header
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Inter-Bold", size: 13) ?? PDFStyleConfiguration.Typography.blockHeader(),
            .foregroundColor: PDFStyleConfiguration.BlockStyles.exerciseIconColor
        ]
        let headerText = NSAttributedString(string: "\(PDFStyleConfiguration.Icons.exercise) \(title.uppercased())", attributes: headerAttributes)
        let headerRect = CGRect(x: point.x + padding, y: point.y + 8, width: maxWidth - padding * 2, height: headerHeight - 10)
        headerText.draw(in: headerRect)

        // Draw divider
        let dividerY = point.y + headerHeight
        context.setStrokeColor(PDFStyleConfiguration.BlockStyles.exerciseBorderColor.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: point.x + padding, y: dividerY))
        context.addLine(to: CGPoint(x: point.x + maxWidth - padding, y: dividerY))
        context.strokePath()

        var currentY = point.y + headerHeight + padding

        // Draw content text (non-table parts)
        if !regularContent.isEmpty {
            let contentAttributed = parseInlineMarkdown(regularContent, baseAttributes: PDFStyleConfiguration.bodyAttributes())
            let drawnContentHeight = drawAttributedString(contentAttributed, to: context, at: CGPoint(x: point.x + padding, y: currentY), maxWidth: insetWidth)
            currentY += drawnContentHeight + 12
        }

        // Draw table if present
        if !tableData.isEmpty {
            let tableHeight = renderTable(tableData: tableData, to: context, at: CGPoint(x: point.x + padding, y: currentY), maxWidth: insetWidth)
            currentY += tableHeight + 8
        }

        // Draw steps with bold orange numbers
        for (index, step) in steps.enumerated() {
            let numberAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Inter-Bold", size: 17) ?? PDFStyleConfiguration.Typography.bodyBold(),
                .foregroundColor: PDFStyleConfiguration.BlockStyles.exerciseIconColor
            ]
            let numberText = NSAttributedString(string: "\(index + 1).", attributes: numberAttributes)
            let numberRect = CGRect(x: point.x + padding, y: currentY, width: numberWidth - 4, height: 20)
            numberText.draw(in: numberRect)

            let stepAttributed = parseInlineMarkdown(step, baseAttributes: PDFStyleConfiguration.bodyAttributes())
            let stepHeight = drawAttributedString(
                stepAttributed,
                to: context,
                at: CGPoint(x: point.x + padding + numberWidth, y: currentY),
                maxWidth: insetWidth - numberWidth
            )

            currentY += stepHeight + 10
        }

        // Draw time badge if present
        if let time = estimatedTime, !time.isEmpty {
            let timeAttributes: [NSAttributedString.Key: Any] = [
                .font: PDFStyleConfiguration.Typography.caption(),
                .foregroundColor: PDFStyleConfiguration.Colors.textMuted
            ]
            let timeText = NSAttributedString(string: "⏱ \(time)", attributes: timeAttributes)
            let timeRect = CGRect(x: point.x + padding, y: currentY + 4, width: insetWidth, height: 16)
            timeText.draw(in: timeRect)
        }

        return totalHeight + PDFStyleConfiguration.Spacing.blockSpacing
    }

    private func renderQuickGlance(coreMessage: String, keyPoints: [String], readingTime: String?, to context: CGContext, at point: CGPoint, maxWidth: CGFloat) -> CGFloat {
        let padding: CGFloat = 16
        let headerHeight: CGFloat = 32
        let borderRadius: CGFloat = PDFStyleConfiguration.Radius.lg
        let borderWidth: CGFloat = 2
        let insetWidth = maxWidth - padding * 2

        // Calculate heights
        let coreMessageHeight = calculateTextHeight(coreMessage, attributes: [
            .font: PDFStyleConfiguration.Typography.bodyLarge(),
            .foregroundColor: PDFStyleConfiguration.Colors.textBody,
            .paragraphStyle: PDFStyleConfiguration.paragraphStyle(lineHeight: 20, alignment: .left, paragraphSpacing: 8)
        ], maxWidth: insetWidth)

        var keyPointsHeight: CGFloat = 0
        for point in keyPoints {
            let pointHeight = calculateTextHeight(point, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: insetWidth - 20)
            keyPointsHeight += pointHeight + 8
        }

        let totalHeight = headerHeight + coreMessageHeight + 16 + keyPointsHeight + padding * 2

        // Draw outer border
        let outerRect = CGRect(x: point.x, y: point.y, width: maxWidth, height: totalHeight)
        let outerPath = UIBezierPath(roundedRect: outerRect, cornerRadius: borderRadius)
        context.addPath(outerPath.cgPath)
        context.setStrokeColor(PDFStyleConfiguration.BlockStyles.quickGlanceBorderColor.cgColor)
        context.setLineWidth(borderWidth)
        context.strokePath()

        // Draw background
        let bgRect = outerRect.insetBy(dx: borderWidth / 2, dy: borderWidth / 2)
        let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: borderRadius - 1)
        context.addPath(bgPath.cgPath)
        context.setFillColor(PDFStyleConfiguration.BlockStyles.quickGlanceBgColor.cgColor)
        context.fillPath()

        // Draw header background
        let headerRect = CGRect(x: point.x + borderWidth / 2, y: point.y + borderWidth / 2, width: maxWidth - borderWidth, height: headerHeight)
        let headerPath = UIBezierPath(
            roundedRect: headerRect,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: borderRadius - 1, height: borderRadius - 1)
        )
        context.addPath(headerPath.cgPath)
        context.setFillColor(PDFStyleConfiguration.BlockStyles.quickGlanceHeaderBgColor.cgColor)
        context.fillPath()

        // Draw header text and reading time badge
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.blockHeader(),
            .foregroundColor: PDFStyleConfiguration.Colors.primaryGoldDark
        ]
        let headerText = NSAttributedString(string: "\(PDFStyleConfiguration.Icons.quickGlance) QUICK GLANCE", attributes: headerAttributes)
        let headerTextRect = CGRect(x: point.x + padding, y: point.y + 8, width: maxWidth / 2, height: headerHeight - 12)
        headerText.draw(in: headerTextRect)

        // Draw reading time badge with clarification
        if let time = readingTime, !time.isEmpty {
            // Clarify that this is the reading time for this guide, not the original book
            let badgeText = "\(time) min guide"
            let badgeAttributes: [NSAttributedString.Key: Any] = [
                .font: PDFStyleConfiguration.Typography.captionBold(),
                .foregroundColor: PDFStyleConfiguration.Colors.primaryGold
            ]
            let badgeAttributed = NSAttributedString(string: badgeText, attributes: badgeAttributes)
            let badgeSize = badgeAttributed.size()
            let badgeRect = CGRect(
                x: point.x + maxWidth - padding - badgeSize.width - 16,
                y: point.y + 8,
                width: badgeSize.width + 16,
                height: headerHeight - 12
            )

            // Badge background
            let badgeBgPath = UIBezierPath(roundedRect: badgeRect, cornerRadius: 4)
            context.addPath(badgeBgPath.cgPath)
            context.setFillColor(PDFStyleConfiguration.Colors.primaryGold.withAlphaComponent(0.15).cgColor)
            context.fillPath()

            badgeAttributed.draw(in: CGRect(x: badgeRect.minX + 8, y: badgeRect.minY + 2, width: badgeSize.width, height: badgeSize.height))
        }

        var currentY = point.y + headerHeight + padding

        // Draw core message
        let coreAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.bodyLarge(),
            .foregroundColor: PDFStyleConfiguration.Colors.textBody,
            .paragraphStyle: PDFStyleConfiguration.paragraphStyle(lineHeight: 20, alignment: .left, paragraphSpacing: 8)
        ]
        let coreAttributed = parseInlineMarkdown(coreMessage, baseAttributes: coreAttributes)
        let drawnCoreHeight = drawAttributedString(coreAttributed, to: context, at: CGPoint(x: point.x + padding, y: currentY), maxWidth: insetWidth)
        currentY += drawnCoreHeight + 16

        // Draw key points
        for keyPoint in keyPoints {
            // Bullet
            let bulletAttributes: [NSAttributedString.Key: Any] = [
                .font: PDFStyleConfiguration.Typography.body(),
                .foregroundColor: PDFStyleConfiguration.Colors.primaryGold
            ]
            let bulletText = NSAttributedString(string: "•", attributes: bulletAttributes)
            let bulletRect = CGRect(x: point.x + padding, y: currentY, width: 12, height: 18)
            bulletText.draw(in: bulletRect)

            // Point text
            let pointAttributed = parseInlineMarkdown(keyPoint, baseAttributes: PDFStyleConfiguration.bodyAttributes())
            let pointHeight = drawAttributedString(
                pointAttributed,
                to: context,
                at: CGPoint(x: point.x + padding + 16, y: currentY),
                maxWidth: insetWidth - 16
            )

            currentY += pointHeight + 8
        }

        return totalHeight + PDFStyleConfiguration.Spacing.blockSpacing
    }

    private func renderList(items: [String], numbered: Bool, to context: CGContext, at point: CGPoint, maxWidth: CGFloat) -> CGFloat {
        var currentY = point.y

        for (index, item) in items.enumerated() {
            let bulletWidth: CGFloat = numbered ? 24 : 16

            if numbered {
                let numberAttributes: [NSAttributedString.Key: Any] = [
                    .font: PDFStyleConfiguration.Typography.bodyBold(),
                    .foregroundColor: PDFStyleConfiguration.Colors.primaryGold
                ]
                let numberText = NSAttributedString(string: "\(index + 1).", attributes: numberAttributes)
                let numberRect = CGRect(x: point.x, y: currentY, width: bulletWidth, height: 18)
                numberText.draw(in: numberRect)
            } else {
                let bulletAttributes: [NSAttributedString.Key: Any] = [
                    .font: PDFStyleConfiguration.Typography.body(),
                    .foregroundColor: PDFStyleConfiguration.Colors.primaryGold
                ]
                let bulletText = NSAttributedString(string: "•", attributes: bulletAttributes)
                let bulletRect = CGRect(x: point.x, y: currentY, width: bulletWidth, height: 18)
                bulletText.draw(in: bulletRect)
            }

            let itemAttributed = parseInlineMarkdown(item, baseAttributes: PDFStyleConfiguration.bodyAttributes())
            let itemHeight = drawAttributedString(
                itemAttributed,
                to: context,
                at: CGPoint(x: point.x + bulletWidth, y: currentY),
                maxWidth: maxWidth - bulletWidth
            )

            currentY += itemHeight + 6
        }

        return (currentY - point.y) + PDFStyleConfiguration.Spacing.paragraphSpacing
    }

    private func renderDivider(to context: CGContext, at point: CGPoint, maxWidth: CGFloat) -> CGFloat {
        let y = point.y + PDFStyleConfiguration.Spacing.lg

        // Draw gradient-style divider (simulated with multiple lines)
        let centerX = point.x + maxWidth / 2
        let lineWidth: CGFloat = 100

        context.setStrokeColor(PDFStyleConfiguration.Colors.primaryGold.withAlphaComponent(0.6).cgColor)
        context.setLineWidth(1.0)
        context.move(to: CGPoint(x: centerX - lineWidth / 2, y: y))
        context.addLine(to: CGPoint(x: centerX + lineWidth / 2, y: y))
        context.strokePath()

        // Decorative dots
        let dotRadius: CGFloat = 2
        context.setFillColor(PDFStyleConfiguration.Colors.primaryGold.cgColor)
        context.addArc(center: CGPoint(x: centerX, y: y), radius: dotRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        context.fillPath()

        return PDFStyleConfiguration.Spacing.xl2
    }

    // MARK: - Table Rendering

    private func renderTable(tableData: [[String]], to context: CGContext, at point: CGPoint, maxWidth: CGFloat) -> CGFloat {
        guard !tableData.isEmpty else { return 0 }

        let padding: CGFloat = 8
        let borderRadius = PDFStyleConfiguration.Radius.sm
        let cellPadding: CGFloat = 10

        // Calculate column widths evenly
        let columnCount = tableData.first?.count ?? 1
        let cellWidth = (maxWidth - padding * 2) / CGFloat(columnCount)
        let cellContentWidth = cellWidth - cellPadding * 2

        // Calculate row heights
        var rowHeights: [CGFloat] = []
        for row in tableData {
            var maxCellHeight: CGFloat = 20
            for cell in row {
                let cellText = stripMarkdownSyntax(cell)
                let cellHeight = calculateTextHeight(cellText, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: cellContentWidth)
                maxCellHeight = max(maxCellHeight, cellHeight + cellPadding * 2)
            }
            rowHeights.append(maxCellHeight)
        }

        let totalHeight = rowHeights.reduce(0, +) + padding * 2

        // Draw table background
        let bgRect = CGRect(x: point.x, y: point.y, width: maxWidth, height: totalHeight)
        let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: borderRadius)
        context.addPath(bgPath.cgPath)
        context.setFillColor(UIColor.white.cgColor)
        context.fillPath()

        // Draw table border
        context.addPath(bgPath.cgPath)
        context.setStrokeColor(PDFStyleConfiguration.Colors.borderLight.cgColor)
        context.setLineWidth(1.0)
        context.strokePath()

        var currentY = point.y + padding

        for (rowIndex, row) in tableData.enumerated() {
            let rowHeight = rowHeights[rowIndex]
            let isHeader = rowIndex == 0

            // Draw row background for header
            if isHeader {
                let headerRect = CGRect(x: point.x + padding, y: currentY, width: maxWidth - padding * 2, height: rowHeight)
                context.setFillColor(PDFStyleConfiguration.Colors.primaryGold.withAlphaComponent(0.15).cgColor)
                context.fill(headerRect)
            } else if rowIndex % 2 == 0 {
                // Alternating row colors
                let rowRect = CGRect(x: point.x + padding, y: currentY, width: maxWidth - padding * 2, height: rowHeight)
                context.setFillColor(UIColor(white: 0.98, alpha: 1.0).cgColor)
                context.fill(rowRect)
            }

            // Draw cells
            var currentX = point.x + padding
            for (colIndex, cell) in row.enumerated() {
                let cellText = stripMarkdownSyntax(cell)
                let attributes: [NSAttributedString.Key: Any] = isHeader ? [
                    .font: PDFStyleConfiguration.Typography.bodyBold(),
                    .foregroundColor: PDFStyleConfiguration.Colors.textHeading
                ] : PDFStyleConfiguration.bodyAttributes()

                let attributedText = NSAttributedString(string: cellText, attributes: attributes)
                let textRect = CGRect(
                    x: currentX + cellPadding,
                    y: currentY + cellPadding,
                    width: cellContentWidth,
                    height: rowHeight - cellPadding * 2
                )
                attributedText.draw(in: textRect)

                // Draw vertical cell border (except last column)
                if colIndex < columnCount - 1 {
                    let lineX = currentX + cellWidth
                    context.setStrokeColor(PDFStyleConfiguration.Colors.borderLight.cgColor)
                    context.setLineWidth(0.5)
                    context.move(to: CGPoint(x: lineX, y: currentY))
                    context.addLine(to: CGPoint(x: lineX, y: currentY + rowHeight))
                    context.strokePath()
                }

                currentX += cellWidth
            }

            // Draw horizontal row border (except last row)
            if rowIndex < tableData.count - 1 {
                let lineY = currentY + rowHeight
                context.setStrokeColor(PDFStyleConfiguration.Colors.borderLight.cgColor)
                context.setLineWidth(0.5)
                context.move(to: CGPoint(x: point.x + padding, y: lineY))
                context.addLine(to: CGPoint(x: point.x + maxWidth - padding, y: lineY))
                context.strokePath()
            }

            currentY += rowHeight
        }

        return totalHeight + PDFStyleConfiguration.Spacing.blockSpacing
    }

    private func calculateTableHeight(tableData: [[String]], maxWidth: CGFloat) -> CGFloat {
        guard !tableData.isEmpty else { return 0 }

        let padding: CGFloat = 8
        let cellPadding: CGFloat = 10
        let columnCount = tableData.first?.count ?? 1
        let cellWidth = (maxWidth - padding * 2) / CGFloat(columnCount)
        let cellContentWidth = cellWidth - cellPadding * 2

        var totalHeight: CGFloat = padding * 2

        for row in tableData {
            var maxCellHeight: CGFloat = 20
            for cell in row {
                let cellText = stripMarkdownSyntax(cell)
                let cellHeight = calculateTextHeight(cellText, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: cellContentWidth)
                maxCellHeight = max(maxCellHeight, cellHeight + cellPadding * 2)
            }
            totalHeight += maxCellHeight
        }

        return totalHeight + PDFStyleConfiguration.Spacing.blockSpacing
    }

    // MARK: - Helper: Special Block Renderer
    // Unified styling matching Insight Note pattern for consistency

    private func renderSpecialBlock(
        content: String,
        title: String,
        icon: String,
        borderColor: UIColor,
        bgColor: UIColor,
        headerBgColor: UIColor,
        to context: CGContext,
        at point: CGPoint,
        maxWidth: CGFloat
    ) -> CGFloat {
        let padding: CGFloat = 12
        let headerHeight: CGFloat = 28
        let borderRadius: CGFloat = 6.0  // Consistent 6pt corner radius
        let borderWidth: CGFloat = 1.0   // Consistent 1pt border
        let leftAccentWidth: CGFloat = 4.0  // Left accent bar for visual hierarchy
        let insetWidth = maxWidth - padding * 2

        let contentHeight = calculateTextHeight(content, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: insetWidth)
        let totalHeight = headerHeight + contentHeight + padding * 2

        // Draw background with rounded corners
        let bgRect = CGRect(x: point.x, y: point.y, width: maxWidth, height: totalHeight)
        let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: borderRadius)

        context.saveGState()
        context.addPath(bgPath.cgPath)
        context.setFillColor(bgColor.cgColor)
        context.fillPath()

        // Draw border
        context.addPath(bgPath.cgPath)
        context.setStrokeColor(borderColor.cgColor)
        context.setLineWidth(borderWidth)
        context.strokePath()

        // Draw left accent bar (matching Insight Note pattern)
        let accentRect = CGRect(x: point.x, y: point.y, width: leftAccentWidth, height: totalHeight)
        let accentPath = UIBezierPath(
            roundedRect: accentRect,
            byRoundingCorners: [.topLeft, .bottomLeft],
            cornerRadii: CGSize(width: borderRadius, height: borderRadius)
        )
        context.addPath(accentPath.cgPath)
        context.setFillColor(borderColor.cgColor)
        context.fillPath()
        context.restoreGState()

        // Draw header with icon + uppercase label
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.blockHeader(),
            .foregroundColor: headerBgColor
        ]
        let headerText = NSAttributedString(string: "\(icon) \(title.uppercased())", attributes: headerAttributes)
        let headerTextRect = CGRect(x: point.x + padding + leftAccentWidth, y: point.y + 6, width: maxWidth - padding * 2 - leftAccentWidth, height: headerHeight - 8)
        headerText.draw(in: headerTextRect)

        // Draw divider line under header
        let dividerY = point.y + headerHeight
        context.setStrokeColor(borderColor.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: point.x + padding + leftAccentWidth, y: dividerY))
        context.addLine(to: CGPoint(x: point.x + maxWidth - padding, y: dividerY))
        context.strokePath()

        // Draw content with proper padding from left accent
        let contentAttributed = parseInlineMarkdown(content, baseAttributes: PDFStyleConfiguration.bodyAttributes())
        drawAttributedString(
            contentAttributed,
            to: context,
            at: CGPoint(x: point.x + padding + leftAccentWidth, y: point.y + headerHeight + padding),
            maxWidth: insetWidth - leftAccentWidth
        )

        return totalHeight + PDFStyleConfiguration.Spacing.blockSpacing
    }

    // MARK: - Height Calculation Helpers

    private func calculateTextHeight(_ text: String, attributes: [NSAttributedString.Key: Any], maxWidth: CGFloat) -> CGFloat {
        let mutableString = NSMutableAttributedString(string: text, attributes: attributes)
        let fullRange = NSRange(location: 0, length: mutableString.length)
        
        // Guard against empty strings
        guard mutableString.length > 0 else {
            return 0
        }

        // Get existing paragraph style or create new one with proper word wrapping
        var paragraphStyle: NSMutableParagraphStyle
        if let existingStyle = attributes[.paragraphStyle] as? NSParagraphStyle,
           let mutableStyle = existingStyle.mutableCopy() as? NSMutableParagraphStyle {
            paragraphStyle = mutableStyle
        } else {
            paragraphStyle = NSMutableParagraphStyle()
        }

        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.hyphenationFactor = 0.0
        paragraphStyle.allowsDefaultTighteningForTruncation = false

        mutableString.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)

        let boundingRect = mutableString.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return ceil(boundingRect.height) + 2
    }

    private func calculateBlockquoteHeight(_ text: String, maxWidth: CGFloat) -> CGFloat {
        let padding: CGFloat = 16
        let borderWidth: CGFloat = 4
        let rightPadding: CGFloat = 12
        let insetWidth = maxWidth - padding * 2 - borderWidth - rightPadding
        let quoteMarkHeight: CGFloat = 24

        let attributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.bodyItalic(),
            .foregroundColor: PDFStyleConfiguration.Colors.textBody,
            .paragraphStyle: PDFStyleConfiguration.paragraphStyle(lineHeight: 20, alignment: .left, paragraphSpacing: 8)
        ]
        let textHeight = calculateTextHeight(text, attributes: attributes, maxWidth: insetWidth)
        // Match render method: quote mark + padding + text + bottom padding
        return quoteMarkHeight + padding + textHeight + padding + PDFStyleConfiguration.Spacing.blockSpacing
    }

    private func calculateSpecialBlockHeight(content: String, title: String, maxWidth: CGFloat) -> CGFloat {
        let padding: CGFloat = 12
        let headerHeight: CGFloat = 28
        let insetWidth = maxWidth - padding * 2
        let contentHeight = calculateTextHeight(content, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: insetWidth)
        return headerHeight + contentHeight + padding * 2 + PDFStyleConfiguration.Spacing.blockSpacing
    }

    private func calculateActionBoxHeight(title: String, steps: [String], maxWidth: CGFloat) -> CGFloat {
        let padding: CGFloat = 14
        let headerHeight: CGFloat = 30
        let numberWidth: CGFloat = 28
        let insetWidth = maxWidth - padding * 2

        var contentHeight: CGFloat = 0
        for step in steps {
            let stepHeight = calculateTextHeight(step, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: insetWidth - numberWidth)
            contentHeight += stepHeight + 10
        }

        return headerHeight + contentHeight + padding * 2 + PDFStyleConfiguration.Spacing.blockSpacing
    }

    private func calculateTakeawaysHeight(items: [String], maxWidth: CGFloat) -> CGFloat {
        let padding: CGFloat = 12
        let headerHeight: CGFloat = 28
        let insetWidth = maxWidth - padding * 2

        var contentHeight: CGFloat = 0
        for item in items {
            let itemHeight = calculateTextHeight(item, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: insetWidth - 20)
            contentHeight += itemHeight + 8
        }

        return headerHeight + contentHeight + padding * 2 + PDFStyleConfiguration.Spacing.blockSpacing
    }

    private func calculateNarrativeHeight(content: String, title: String?, maxWidth: CGFloat) -> CGFloat {
        return calculateSpecialBlockHeight(content: content, title: title ?? "The Story Behind the Ideas", maxWidth: maxWidth)
    }

    private func calculateExerciseHeight(content: String, steps: [String], maxWidth: CGFloat) -> CGFloat {
        let padding: CGFloat = 14
        let headerHeight: CGFloat = 30
        let numberWidth: CGFloat = 28
        let insetWidth = maxWidth - padding * 2

        // Parse content for potential tables
        let (regularContent, tableData) = parseContentForTables(content)

        var contentHeight: CGFloat = 0

        if !regularContent.isEmpty {
            contentHeight += calculateTextHeight(regularContent, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: insetWidth) + 12
        }

        // Add table height if present
        if !tableData.isEmpty {
            contentHeight += calculateTableHeight(tableData: tableData, maxWidth: insetWidth) + 8
        }

        for step in steps {
            let stepHeight = calculateTextHeight(step, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: insetWidth - numberWidth)
            contentHeight += stepHeight + 10
        }

        contentHeight += 24 // Time badge

        return headerHeight + contentHeight + padding * 2 + PDFStyleConfiguration.Spacing.blockSpacing
    }

    private func calculateQuickGlanceHeight(coreMessage: String, keyPoints: [String], readingTime: String?, maxWidth: CGFloat) -> CGFloat {
        let padding: CGFloat = 16
        let headerHeight: CGFloat = 32
        let insetWidth = maxWidth - padding * 2

        let coreMessageHeight = calculateTextHeight(coreMessage, attributes: [
            .font: PDFStyleConfiguration.Typography.bodyLarge(),
            .foregroundColor: PDFStyleConfiguration.Colors.textBody,
            .paragraphStyle: PDFStyleConfiguration.paragraphStyle(lineHeight: 20, alignment: .left, paragraphSpacing: 8)
        ], maxWidth: insetWidth)

        var keyPointsHeight: CGFloat = 0
        for point in keyPoints {
            let pointHeight = calculateTextHeight(point, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: insetWidth - 20)
            keyPointsHeight += pointHeight + 8
        }

        return headerHeight + coreMessageHeight + 16 + keyPointsHeight + padding * 2 + PDFStyleConfiguration.Spacing.blockSpacing
    }

    private func calculateListHeight(items: [String], numbered: Bool, maxWidth: CGFloat) -> CGFloat {
        let bulletWidth: CGFloat = numbered ? 24 : 16
        var height: CGFloat = 0

        for item in items {
            let itemHeight = calculateTextHeight(item, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: maxWidth - bulletWidth)
            height += itemHeight + 6
        }

        return height + PDFStyleConfiguration.Spacing.paragraphSpacing
    }

    // MARK: - Text Drawing Helpers

    @discardableResult
    private func drawAttributedString(_ attributedString: NSAttributedString, to context: CGContext, at point: CGPoint, maxWidth: CGFloat) -> CGFloat {
        // Create a mutable copy with proper word wrapping and hyphenation settings
        let mutableString = NSMutableAttributedString(attributedString: attributedString)
        let fullRange = NSRange(location: 0, length: mutableString.length)
        
        // Guard against empty strings
        guard mutableString.length > 0 else {
            return 0
        }

        // Get existing paragraph style or create new one
        var paragraphStyle: NSMutableParagraphStyle
        if let existingStyle = mutableString.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle,
           let mutableStyle = existingStyle.mutableCopy() as? NSMutableParagraphStyle {
            paragraphStyle = mutableStyle
        } else {
            paragraphStyle = NSMutableParagraphStyle()
        }

        // Enable word wrapping and hyphenation to prevent truncation
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.hyphenationFactor = 0.0 // Disable hyphenation for cleaner breaks
        paragraphStyle.allowsDefaultTighteningForTruncation = false

        mutableString.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)

        let boundingRect = mutableString.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )

        // Add small buffer to height to prevent clipping
        let drawRect = CGRect(x: point.x, y: point.y, width: maxWidth, height: ceil(boundingRect.height) + 2)

        UIGraphicsPushContext(context)
        mutableString.draw(in: drawRect)
        UIGraphicsPopContext()

        return ceil(boundingRect.height) + 2
    }

    /// Parse inline markdown (bold, italic) and strip markdown syntax, returning attributed string
    /// Uses a safer parsing approach that handles overlapping matches correctly
    private func parseInlineMarkdown(_ text: String, baseAttributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        // First, strip markdown syntax that shouldn't appear in the output (except bold/italic)
        let cleanedText = stripMarkdownSyntax(text)

        // Guard against empty strings after cleaning
        guard !cleanedText.isEmpty else {
            return NSAttributedString(string: "", attributes: baseAttributes)
        }

        let result = NSMutableAttributedString(string: cleanedText, attributes: baseAttributes)

        // Parse bold (**text** or __text__) - process in reverse order to maintain indices
        let boldPattern = "\\*\\*(.+?)\\*\\*|__(.+?)__"
        if let boldRegex = try? NSRegularExpression(pattern: boldPattern, options: []) {
            // Re-fetch current string after each modification phase
            var currentString = result.string
            let matches = boldRegex.matches(in: currentString, options: [], range: NSRange(currentString.startIndex..., in: currentString))

            // Process in reverse to maintain valid indices
            for match in matches.reversed() {
                // Re-validate range against current string length
                guard match.range.location + match.range.length <= result.length else { continue }

                let captureRange = match.range(at: 1).location != NSNotFound ? match.range(at: 1) : match.range(at: 2)
                guard captureRange.location != NSNotFound else { continue }

                // Get the captured text (content without markers)
                if let swiftCaptureRange = Range(captureRange, in: currentString) {
                    let boldText = String(currentString[swiftCaptureRange])
                    var boldAttributes = baseAttributes
                    boldAttributes[.font] = PDFStyleConfiguration.Typography.bodyBold()
                    let boldAttributed = NSAttributedString(string: boldText, attributes: boldAttributes)

                    // Replace the entire match (including markers) with styled content
                    result.replaceCharacters(in: match.range, with: boldAttributed)

                    // Update currentString for next iteration
                    currentString = result.string
                }
            }
        }

        // Parse italic (*text* or _text_) - must avoid matching bold markers
        // Use a simpler pattern that's less prone to edge cases
        let italicPattern = "(?<![\\*_])\\*([^\\*]+)\\*(?![\\*])|(?<![\\*_])_([^_]+)_(?![_])"
        if let italicRegex = try? NSRegularExpression(pattern: italicPattern, options: []) {
            var currentString = result.string
            let matches = italicRegex.matches(in: currentString, options: [], range: NSRange(currentString.startIndex..., in: currentString))

            // Process in reverse to maintain valid indices
            for match in matches.reversed() {
                // Re-validate range against current string length
                guard match.range.location + match.range.length <= result.length else { continue }

                let captureRange = match.range(at: 1).location != NSNotFound ? match.range(at: 1) : match.range(at: 2)
                guard captureRange.location != NSNotFound else { continue }

                if let swiftCaptureRange = Range(captureRange, in: currentString) {
                    let italicText = String(currentString[swiftCaptureRange])
                    var italicAttributes = baseAttributes
                    italicAttributes[.font] = PDFStyleConfiguration.Typography.bodyItalic()
                    let italicAttributed = NSAttributedString(string: italicText, attributes: italicAttributes)

                    result.replaceCharacters(in: match.range, with: italicAttributed)
                    currentString = result.string
                }
            }
        }

        return result
    }

    /// Parse content for embedded markdown tables
    /// Returns tuple of (regular content without table, table data if found)
    private func parseContentForTables(_ content: String) -> (String, [[String]]) {
        var regularContent = ""
        var tableData: [[String]] = []

        let lines = content.components(separatedBy: "\n")
        var inTable = false
        var tableLines: [String] = []

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Check if line is a table row (contains | separator)
            if trimmedLine.contains("|") && (trimmedLine.hasPrefix("|") || trimmedLine.contains(" | ")) {
                // Skip separator lines (---|----|---)
                if trimmedLine.replacingOccurrences(of: "|", with: "")
                    .replacingOccurrences(of: "-", with: "")
                    .replacingOccurrences(of: ":", with: "")
                    .trimmingCharacters(in: .whitespaces).isEmpty {
                    continue
                }

                inTable = true
                tableLines.append(trimmedLine)
            } else {
                if inTable && !tableLines.isEmpty {
                    // Process accumulated table lines
                    for tableLine in tableLines {
                        let cells = tableLine
                            .trimmingCharacters(in: CharacterSet(charactersIn: "|"))
                            .components(separatedBy: "|")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }

                        if !cells.isEmpty {
                            tableData.append(cells)
                        }
                    }
                    tableLines = []
                }
                inTable = false

                if !trimmedLine.isEmpty {
                    regularContent += (regularContent.isEmpty ? "" : "\n") + line
                }
            }
        }

        // Process any remaining table lines
        if !tableLines.isEmpty {
            for tableLine in tableLines {
                let cells = tableLine
                    .trimmingCharacters(in: CharacterSet(charactersIn: "|"))
                    .components(separatedBy: "|")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }

                if !cells.isEmpty {
                    tableData.append(cells)
                }
            }
        }

        return (regularContent.trimmingCharacters(in: .whitespacesAndNewlines), tableData)
    }

    /// Strip markdown syntax from text (headers, code blocks, links, etc.)
    /// NOTE: This function does NOT strip bold/italic - those are handled by parseInlineMarkdown for styled rendering
    private func stripMarkdownSyntax(_ text: String) -> String {
        var result = text

        // Strip markdown headers (# Header, ## Header, ### Header, etc.)
        // Match "# " at the start of line or entire text
        if let headerRegex = try? NSRegularExpression(pattern: "^#{1,6}\\s+", options: [.anchorsMatchLines]) {
            result = headerRegex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }

        // Strip inline code backticks (`code`)
        if let codeRegex = try? NSRegularExpression(pattern: "`([^`]+)`", options: []) {
            result = codeRegex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1"
            )
        }

        // Strip markdown links [text](url) -> text
        if let linkRegex = try? NSRegularExpression(pattern: "\\[([^\\]]+)\\]\\([^)]+\\)", options: []) {
            result = linkRegex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1"
            )
        }

        // Strip markdown images ![alt](url) -> alt
        if let imageRegex = try? NSRegularExpression(pattern: "!\\[([^\\]]*)\\]\\([^)]+\\)", options: []) {
            result = imageRegex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1"
            )
        }

        // Strip horizontal rules (--- or ***)
        if let hrRegex = try? NSRegularExpression(pattern: "^([-*_]){3,}\\s*$", options: [.anchorsMatchLines]) {
            result = hrRegex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }

        // Strip strikethrough (~~text~~)
        if let strikeRegex = try? NSRegularExpression(pattern: "~~(.+?)~~", options: []) {
            result = strikeRegex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1"
            )
        }

        // Strip blockquote markers (> at start of line)
        if let quoteRegex = try? NSRegularExpression(pattern: "^>\\s*", options: [.anchorsMatchLines]) {
            result = quoteRegex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }

        // Strip ASCII box drawing characters
        let boxChars = ["┌", "┐", "└", "┘", "├", "┤", "┬", "┴", "┼", "─", "│", "↓", "→", "←", "↑"]
        for char in boxChars {
            result = result.replacingOccurrences(of: char, with: "")
        }

        // Clean up multiple consecutive newlines
        if let newlineRegex = try? NSRegularExpression(pattern: "\\n{3,}", options: []) {
            result = newlineRegex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "\n\n"
            )
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Visual Rendering

    /// Calculate the height needed for a visual block
    /// Uses local cache only - no network I/O
    private func calculateVisualHeight(block: PDFContentBlock, maxWidth: CGFloat) -> CGFloat {
        // Load image from local cache only (no network access)
        guard let url = block.visualURL,
              let image = VisualAssetCache.shared.cachedImage(for: url) else {
            // Fallback: render placeholder + caption if image not cached
            let placeholderHeight: CGFloat = 120 // Consistent placeholder size
            let captionHeight = block.content.isEmpty ? 0 :
                calculateTextHeight(block.content, attributes: PDFStyleConfiguration.captionAttributes(), maxWidth: maxWidth)
            return placeholderHeight + captionHeight + PDFStyleConfiguration.Spacing.blockSpacing
        }

        // Calculate scaled image dimensions maintaining aspect ratio
        let imageSize = image.size
        let scaleFactor = min(maxWidth / imageSize.width, 1.0)
        let scaledHeight = imageSize.height * scaleFactor

        // Add caption height if present
        let captionHeight = block.content.isEmpty ? 0 :
            calculateTextHeight(block.content, attributes: PDFStyleConfiguration.captionAttributes(), maxWidth: maxWidth)
                + PDFStyleConfiguration.Spacing.sm

        // Add visual type label height
        let labelHeight: CGFloat = 16

        return scaledHeight + captionHeight + labelHeight + PDFStyleConfiguration.Spacing.blockSpacing
    }

    /// Render a visual block (image with optional caption)
    /// Uses local cache only - no network I/O, fully deterministic
    private func renderVisual(block: PDFContentBlock, to context: CGContext, at point: CGPoint, maxWidth: CGFloat) -> CGFloat {
        var yOffset: CGFloat = 0

        // Load image from local cache only (no network access)
        if let url = block.visualURL,
           let image = VisualAssetCache.shared.cachedImage(for: url),
           let cgImage = image.cgImage {

            // Calculate scaled dimensions
            let imageSize = image.size
            let scaleFactor = min(maxWidth / imageSize.width, 1.0)
            let scaledWidth = imageSize.width * scaleFactor
            let scaledHeight = imageSize.height * scaleFactor

            // Center the image if it's narrower than maxWidth
            let xOffset = (maxWidth - scaledWidth) / 2

            // Draw rounded rect background
            let imageRect = CGRect(x: point.x + xOffset, y: point.y, width: scaledWidth, height: scaledHeight)
            context.saveGState()

            // Add subtle shadow
            context.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: UIColor.black.withAlphaComponent(Double(VisualTheme.pdfShadowOpacity)).cgColor)

            // Draw rounded corners
            let path = UIBezierPath(roundedRect: imageRect, cornerRadius: VisualTheme.pdfCornerRadius)
            context.addPath(path.cgPath)
            context.clip()

            // Draw the image (flip context for proper orientation)
            context.translateBy(x: 0, y: imageRect.origin.y + imageRect.height)
            context.scaleBy(x: 1, y: -1)
            context.draw(cgImage, in: CGRect(x: imageRect.origin.x, y: 0, width: scaledWidth, height: scaledHeight))

            context.restoreGState()

            yOffset += scaledHeight + PDFStyleConfiguration.Spacing.sm
        } else {
            // Render placeholder for missing image
            let placeholderHeight: CGFloat = 120
            let placeholderRect = CGRect(x: point.x, y: point.y, width: maxWidth, height: placeholderHeight)

            // Draw placeholder background with dashed border
            context.saveGState()

            // Fill with light gray background
            context.setFillColor(PDFStyleConfiguration.Colors.bgSecondary.cgColor)
            let path = UIBezierPath(roundedRect: placeholderRect, cornerRadius: PDFStyleConfiguration.Radius.md)
            context.addPath(path.cgPath)
            context.fillPath()

            // Draw dashed border
            context.setStrokeColor(PDFStyleConfiguration.Colors.borderMedium.cgColor)
            context.setLineWidth(1.5)
            context.setLineDash(phase: 0, lengths: [6, 4])
            context.addPath(path.cgPath)
            context.strokePath()

            context.restoreGState()

            // Draw placeholder icon and text
            let placeholderIcon = "🖼️"
            let placeholderText = "Visual not available"
            let iconAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28),
                .paragraphStyle: PDFStyleConfiguration.paragraphStyle(lineHeight: 32, alignment: .center, paragraphSpacing: 0)
            ]
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: PDFStyleConfiguration.Typography.caption(),
                .foregroundColor: PDFStyleConfiguration.Colors.textMuted,
                .paragraphStyle: PDFStyleConfiguration.paragraphStyle(lineHeight: 14, alignment: .center, paragraphSpacing: 0)
            ]

            let iconString = NSAttributedString(string: placeholderIcon, attributes: iconAttributes)
            let textString = NSAttributedString(string: placeholderText, attributes: textAttributes)

            let iconRect = CGRect(x: point.x, y: point.y + 30, width: maxWidth, height: 36)
            let textRect = CGRect(x: point.x, y: point.y + 70, width: maxWidth, height: 20)

            iconString.draw(in: iconRect)
            textString.draw(in: textRect)

            yOffset += placeholderHeight + PDFStyleConfiguration.Spacing.sm
        }

        // Render visual type label
        if let visualType = block.visualType {
            let typeLabel = visualTypeLabel(visualType)
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: PDFStyleConfiguration.Colors.primaryGold
            ]
            let labelString = NSAttributedString(string: typeLabel, attributes: labelAttributes)
            labelString.draw(at: CGPoint(x: point.x, y: point.y + yOffset))
            yOffset += 16
        }

        // Render caption if present
        if !block.content.isEmpty {
            let captionAttributes = PDFStyleConfiguration.captionAttributes()
            let captionRect = CGRect(x: point.x, y: point.y + yOffset, width: maxWidth, height: .greatestFiniteMagnitude)
            let attributedCaption = NSAttributedString(string: block.content, attributes: captionAttributes)
            attributedCaption.draw(with: captionRect, options: [.usesLineFragmentOrigin], context: nil)
            yOffset += calculateTextHeight(block.content, attributes: captionAttributes, maxWidth: maxWidth)
        }

        yOffset += PDFStyleConfiguration.Spacing.blockSpacing
        return yOffset
    }

    /// Get a user-friendly label for visual type
    private func visualTypeLabel(_ type: GuideVisualType) -> String {
        switch type {
        case .timeline: return "📅 Timeline"
        case .flowDiagram: return "🔀 Flow Diagram"
        case .comparisonMatrix: return "📊 Comparison Matrix"
        case .barChart: return "📈 Bar Chart"
        case .quadrant: return "⊞ Quadrant Analysis"
        case .conceptMap: return "🗺 Concept Map"
        }
    }
}

// MARK: - PDF Content Block Model

struct PDFContentBlock {
    enum BlockType {
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
        case quickGlance
        case bulletList
        case numberedList
        case divider
        case table
        case visual
        // Premium block types
        case premiumQuote
        case authorSpotlight
        case premiumDivider
        case premiumH1
        case premiumH2
        case alternativePerspective
        case researchInsight
        case conceptMap
        case processTimeline
        // Synthesis Engine block types (v3.0)
        case example
        case exerciseReflection
    }

    let type: BlockType
    let content: String
    var listItems: [String]?
    var metadata: [String: String]?
    var tableData: [[String]]?
    var visualURL: URL?
    var visualType: GuideVisualType?

    init(type: BlockType, content: String, listItems: [String]? = nil, metadata: [String: String]? = nil, tableData: [[String]]? = nil, visualURL: URL? = nil, visualType: GuideVisualType? = nil) {
        self.type = type
        self.content = content
        self.listItems = listItems
        self.metadata = metadata
        self.tableData = tableData
        self.visualURL = visualURL
        self.visualType = visualType
    }
}
