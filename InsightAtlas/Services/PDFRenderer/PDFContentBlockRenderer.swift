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
                .ligature: 0,
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
    // MARK: - Figure / Table numbering

    /// The "Figure N" / "Table N" label assigned by `PDFReferentialIntegrity`
    /// (stored in `metadata["figureLabel"]` + `["figureNumber"]`), or `nil` when
    /// this block was not assigned a number. Used so the number shown on a
    /// figure matches the "Figure N" reference rewritten into the prose.
    private func figureLabel(for block: PDFContentBlock) -> String? {
        guard let number = block.metadata?["figureNumber"], !number.isEmpty else { return nil }
        let label = block.metadata?["figureLabel"] ?? "Figure"
        return "\(label) \(number)"
    }

    /// Prefix a diagram title with its assigned figure label, if any.
    private func titleWithFigureLabel(_ base: String, for block: PDFContentBlock) -> String {
        guard let fig = figureLabel(for: block) else { return base }
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fig : "\(fig): \(trimmed)"
    }

    /// Fixed height reserved for a standalone "Figure N" / "Table N" caption line.
    private var figureCaptionHeight: CGFloat { 18 }

    /// Draw a standalone figure/table caption line; returns the height consumed.
    @discardableResult
    private func renderFigureCaption(_ text: String, to context: CGContext, at point: CGPoint, maxWidth: CGFloat) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .ligature: 0,
            .foregroundColor: PDFStyleConfiguration.Colors.primaryGold
        ]
        NSAttributedString(string: text.uppercased(), attributes: attrs)
            .draw(at: CGPoint(x: point.x, y: point.y))
        return figureCaptionHeight
    }

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
            return calculateExerciseHeight(title: block.metadata?["title"] ?? "Exercise", content: block.content, steps: block.listItems ?? [], maxWidth: maxWidth)

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
            let tableCaptionHeight = figureLabel(for: block) != nil ? figureCaptionHeight : 0
            return calculateTableHeight(tableData: block.tableData ?? [], maxWidth: maxWidth) + tableCaptionHeight

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

        case .loopDiagram:
            return diagramRenderer.calculateLoopDiagramHeight(
                nodes: block.listItems ?? [],
                maxWidth: maxWidth
            )

        case .spectrum:
            return diagramRenderer.calculateSpectrumHeight(maxWidth: maxWidth)

        case .pyramid:
            return diagramRenderer.calculatePyramidHeight(levels: block.listItems ?? [], maxWidth: maxWidth)

        case .cycle:
            return diagramRenderer.calculateCycleHeight(stages: block.listItems ?? [], maxWidth: maxWidth)

        case .funnel:
            return diagramRenderer.calculateFunnelHeight(stages: block.listItems ?? [], maxWidth: maxWidth)

        case .barChart:
            return diagramRenderer.calculateBarChartHeight(count: block.listItems?.count ?? 0, maxWidth: maxWidth)

        case .pieChart:
            return diagramRenderer.calculatePieChartHeight(count: block.listItems?.count ?? 0, maxWidth: maxWidth)

        case .libraryEntry:
            return calculateLibraryEntryHeight(block: block, maxWidth: maxWidth)

        case .readingChip:
            return 18 + PDFStyleConfiguration.Spacing.blockSpacing

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
                title: titleWithFigureLabel(block.metadata?["title"] ?? "Visual Guide", for: block),
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
            var tableUsed: CGFloat = 0
            if let fig = figureLabel(for: block) {
                tableUsed += renderFigureCaption(fig, to: context, at: point, maxWidth: maxWidth)
            }
            tableUsed += renderTable(
                tableData: block.tableData ?? [],
                to: context,
                at: CGPoint(x: point.x, y: point.y + tableUsed),
                maxWidth: maxWidth
            )
            return tableUsed

        // Premium block types
        case .premiumQuote:
            return renderBlockquote(block.content, cite: block.metadata?["cite"], to: context, at: point, maxWidth: maxWidth)
            
        case .authorSpotlight:
            return renderMockupBlock(
                content: block.content,
                title: "Author Spotlight",
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
            // Limitations / counterpoints get a warning-toned (amber) treatment,
            // visually distinct from supportive notes (Directives §B1, §C3).
            return renderMockupBlock(
                content: block.content,
                title: "Alternative Perspective",
                bgColor: PDFStyleConfiguration.Colors.semanticCautionBg,
                accentColor: PDFStyleConfiguration.Colors.semanticCaution,
                to: context,
                at: point,
                maxWidth: maxWidth
            )

        case .researchInsight:
            // Research / data get the evidence (teal) accent.
            return renderMockupBlock(
                content: block.content,
                title: "Research Insight",
                accentColor: PDFStyleConfiguration.Colors.semanticEvidence,
                to: context,
                at: point,
                maxWidth: maxWidth
            )
            
        case .conceptMap:
            // Render an actual radial concept-map DIAGRAM. This was a bulleted text
            // list via renderMockupBlock — both the diagram-to-bullets bug and a
            // measure/draw mismatch (the height calc already used the diagram
            // calculator). listItems are the related concepts.
            return diagramRenderer.renderConceptMap(
                title: titleWithFigureLabel(block.metadata?["title"] ?? "Concept Map", for: block),
                centralConcept: block.metadata?["central"] ?? "Core Concept",
                relatedConcepts: (block.listItems ?? []).map { (label: $0, description: "") },
                to: context,
                at: point,
                maxWidth: maxWidth
            )

        case .processTimeline:
            // Render process timeline
            return diagramRenderer.renderProcessDiagram(
                title: titleWithFigureLabel(block.metadata?["title"] ?? "Process Timeline", for: block),
                phases: block.listItems?.map { (name: $0, description: "") } ?? [],
                to: context,
                at: point,
                maxWidth: maxWidth
            )

        case .loopDiagram:
            return diagramRenderer.renderLoopDiagram(
                title: titleWithFigureLabel(block.metadata?["title"] ?? "Feedback Loop", for: block),
                nodes: block.listItems ?? [],
                caption: block.metadata?["caption"],
                to: context,
                at: point,
                maxWidth: maxWidth
            )

        case .pyramid:
            return diagramRenderer.renderPyramid(
                title: titleWithFigureLabel(block.metadata?["title"] ?? "Pyramid", for: block),
                levels: block.listItems ?? [],
                to: context,
                at: point,
                maxWidth: maxWidth
            )

        case .cycle:
            return diagramRenderer.renderCycle(
                title: titleWithFigureLabel(block.metadata?["title"] ?? "Cycle", for: block),
                stages: block.listItems ?? [],
                to: context,
                at: point,
                maxWidth: maxWidth
            )

        case .funnel:
            return diagramRenderer.renderFunnel(
                title: titleWithFigureLabel(block.metadata?["title"] ?? "Funnel", for: block),
                stages: block.listItems ?? [],
                to: context,
                at: point,
                maxWidth: maxWidth
            )

        case .barChart:
            let values = (block.metadata?["values"] ?? "").split(separator: "|").compactMap { Double($0) }
            return diagramRenderer.renderBarChart(
                title: titleWithFigureLabel(block.metadata?["title"] ?? "Bar Chart", for: block),
                labels: block.listItems ?? [],
                values: values,
                to: context,
                at: point,
                maxWidth: maxWidth
            )

        case .pieChart:
            let values = (block.metadata?["values"] ?? "").split(separator: "|").compactMap { Double($0) }
            let labels = block.listItems ?? []
            let segments = zip(labels, values).map { (label: $0, value: $1) }
            return diagramRenderer.renderPieChart(
                title: titleWithFigureLabel(block.metadata?["title"] ?? "Pie Chart", for: block),
                segments: segments,
                to: context,
                at: point,
                maxWidth: maxWidth
            )

        case .spectrum:
            let poles = block.listItems ?? []
            return diagramRenderer.renderSpectrum(
                title: titleWithFigureLabel(block.metadata?["title"] ?? "Spectrum", for: block),
                leftPole: poles.first ?? "",
                rightPole: poles.count > 1 ? poles[1] : "",
                zoneLabel: block.metadata?["zone"] ?? "healthy range",
                to: context,
                at: point,
                maxWidth: maxWidth
            )

        case .libraryEntry:
            return renderLibraryEntry(block: block, to: context, at: point, maxWidth: maxWidth)

        case .readingChip:
            return renderReadingChip(block: block, to: context, at: point, maxWidth: maxWidth)

        case .visual:
            // Render visual image in PDF
            return renderVisual(block: block, to: context, at: point, maxWidth: maxWidth)

        // Synthesis Engine block types (v3.0)
        case .example:
            return renderMockupBlock(
                content: block.content,
                title: block.metadata?["title"] ?? "Case Study",
                to: context,
                at: point,
                maxWidth: maxWidth
            )

        case .exerciseReflection:
            return renderMockupBlock(
                content: block.content,
                title: "Reflection Question",
                bgColor: PDFStyleConfiguration.Colors.warmGray,
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
            .ligature: 0,
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
            .ligature: 0,
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

        // Consistent color scheme per heading level.
        // Per brand direction: near-black is the color for ALL primary reading
        // headings; the accent color is reserved for the underline rules below,
        // not the heading text. Previously level-1 (`#`) section titles rendered
        // in burnt orange while level-2 (`##`) titles were near-black, which
        // read as an inconsistent, arbitrary heading-color scheme.
        let color: UIColor
        switch level {
        case 1:
            color = PDFStyleConfiguration.Colors.textHeading  // Near-black (accent moved to the rule)
        case 2:
            color = PDFStyleConfiguration.Colors.textHeading  // Near-black for section titles
        case 3:
            color = PDFStyleConfiguration.Colors.textHeading  // Near-black for subsections
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
            .ligature: 0,
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
            .ligature: 0,
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
                .ligature: 0,
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

    /// The three editorial jobs an Insight Atlas note performs. Differentiating
    /// them visually is what lets a skimmer spot where the book gets pushed back
    /// on — the product's real differentiator — instead of 30 identical cards.
    private enum InsightNoteType {
        case corroboration  // supporting evidence — stays quiet
        case expansion      // extends the idea — distinct accent
        case challenge      // limitation / counterpoint — strongest treatment

        var accentColor: UIColor {
            switch self {
            case .challenge: return PDFStyleConfiguration.Colors.semanticNotes      // deep burgundy/maroon
            case .expansion: return PDFStyleConfiguration.Colors.primaryGold        // gold
            case .corroboration: return PDFStyleConfiguration.BlockStyles.insightNoteBorderColor
            }
        }

        func label(defaultTitle: String) -> String {
            switch self {
            case .challenge: return "KEY CHALLENGE"
            case .expansion: return "EXPANSION"
            case .corroboration:
                let t = defaultTitle.trimmingCharacters(in: .whitespaces)
                return (t.isEmpty || t.lowercased().contains("insight atlas note"))
                    ? "CORROBORATION" : t.uppercased()
            }
        }
    }

    /// Heuristic classification from the note's own text. Conservative: only the
    /// strong pushback/extension signals promote a card off the quiet default, so
    /// a mislabel errs toward "corroboration". (Superseded automatically once the
    /// Phase 4/5 CitationTaxonomy pipeline is enabled.)
    /// Manual type pins — a bridge until the CitationTaxonomy Phase 4/5 pipeline
    /// is live. Key is `noteSignature(_:)`; add one line here to correct any
    /// mislabel spotted in review instead of tweaking the heuristic.
    ///
    /// NOTE: keys are derived from the note's RAW content, which includes any
    /// leading type prefix (e.g. a "Key Challenge:" card's signature begins
    /// "keychallenge…"). If a later stage strips prefixes upstream, re-derive
    /// these keys or the pins will silently stop matching.
    private static let manualNoteTypeOverrides: [String: InsightNoteType] = [:]

    /// Stable, whitespace/punctuation-insensitive signature of a note's opening,
    /// used to key manual overrides.
    private static func noteSignature(_ content: String) -> String {
        String(content.lowercased().filter { $0.isLetter || $0.isNumber }.prefix(48))
    }

    private static func classifyInsightNote(content: String, title: String) -> InsightNoteType {
        if let pinned = manualNoteTypeOverrides[noteSignature(content)] { return pinned }
        let hay = (title + " " + content).lowercased()
        // Deliberately narrow: only unambiguous pushback markers promote a card
        // to the LOUD burgundy treatment, so a mislabel errs toward quiet
        // corroboration. Bare "limitation"/"complicat"/"caveat" were dropped —
        // they match ordinary prose ("despite some limitations…").
        let challengeSignals = ["key challenge", "key limitation", "counterpoint",
                                "counter-point", "pushback", "critique", "objection"]
        if challengeSignals.contains(where: { hay.contains($0) }) { return .challenge }
        let expansionSignals = ["expand", "extends", "builds on", "build on", "goes beyond", "broaden"]
        if expansionSignals.contains(where: { hay.contains($0) }) { return .expansion }
        return .corroboration
    }

    /// Builds the exact composite footer string — small-caps label + em dash +
    /// inline italic body. Shared by the renderer and both height calcs so the
    /// string that is measured is byte-for-byte the string that is drawn; this is
    /// what prevents the measure/draw font mismatch from causing wrap drift.
    /// `label` is a parameter so per-note-type footers ("THE OTHER SIDE",
    /// "SEE ALSO") can reuse this verbatim once the generator emits those markers.
    private func buildInsightFooter(label: String, body: String) -> NSAttributedString {
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Inter-Semibold", size: 9) ?? PDFStyleConfiguration.Typography.captionBold(),
            .ligature: 0,
            .foregroundColor: PDFStyleConfiguration.Colors.terracotta,
            .kern: 0.8
        ]
        var italicAttributes = PDFStyleConfiguration.bodyAttributes()
        italicAttributes[.font] = PDFStyleConfiguration.Typography.bodyItalic()
        let footer = NSMutableAttributedString(string: "\(label) — ", attributes: labelAttributes)
        footer.append(parseInlineMarkdown(body, baseAttributes: italicAttributes))
        return footer
    }

    private func renderInsightNote(content: String, title: String, to context: CGContext, at point: CGPoint, maxWidth: CGFloat) -> CGFloat {
        let parsed = parseInsightNoteContent(content)
        let noteType = Self.classifyInsightNote(content: content, title: title)
        return drawInsightNoteCard(parsed: parsed, accentColor: noteType.accentColor, headerLabel: noteType.label(defaultTitle: title), to: context, at: point, maxWidth: maxWidth)
    }

    /// Draws one insight-note card — or one fragment of a split note. The caller
    /// supplies the already-parsed sections, the accent color, and the header
    /// label; a continuation fragment passes a SUBSET of sections and a
    /// "… (CONTINUED)" label. Total height comes from the shared
    /// insightNoteCardHeight so the drawn card matches every measurer.
    private func drawInsightNoteCard(parsed: InsightNoteParsed, accentColor: UIColor, headerLabel: String, to context: CGContext, at point: CGPoint, maxWidth: CGFloat) -> CGFloat {
        let padding: CGFloat = 14
        let headerHeight: CGFloat = 30
        let sectionSpacing: CGFloat = 8
        let borderRadius: CGFloat = 6.0
        let leftAccentWidth: CGFloat = 4  // Increased from 3pt to 4pt for visual hierarchy
        let subsectionAccentWidth: CGFloat = 4  // Left accent bar for subsections
        let insetWidth = maxWidth - padding * 2 - leftAccentWidth

        let totalHeight = insightNoteCardHeight(parsed, maxWidth: maxWidth)

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
        context.setFillColor(accentColor.cgColor)
        context.fillPath()
        context.restoreGState()

        // Draw header with enhanced label weight, colored by note type.
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Inter-Semibold", size: 11) ?? PDFStyleConfiguration.Typography.captionBold(),
            .ligature: 0,
            .foregroundColor: accentColor,
            .kern: 1.2
        ]
        let headerText = NSAttributedString(string: headerLabel, attributes: headerAttributes)
        let headerTextRect = CGRect(x: point.x + padding + leftAccentWidth, y: point.y + 8, width: maxWidth - padding * 2 - leftAccentWidth, height: headerHeight - 10)
        headerText.draw(in: headerTextRect)

        // Draw divider
        let dividerY = point.y + headerHeight
        context.setStrokeColor(accentColor.withAlphaComponent(0.3).cgColor)
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

        // Key Distinction section - warm gray background
        if let keyDist = parsed.keyDistinction, !keyDist.isEmpty {
            let sectionHeight = 20 + calculateTextHeight(keyDist, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: insetWidth - 20) + 12
            let sectionRect = CGRect(x: point.x + padding + leftAccentWidth, y: currentY, width: insetWidth, height: sectionHeight)

            // Warm gray background
            context.setFillColor(PDFStyleConfiguration.Colors.warmGray.cgColor)
            context.fill(sectionRect)

            // Left accent bar - increased to 4pt
            context.setFillColor(PDFStyleConfiguration.Colors.terracotta.cgColor)
            context.fill(CGRect(x: point.x + padding + leftAccentWidth, y: currentY, width: subsectionAccentWidth, height: sectionHeight))

            // Subtle bottom border for visual separation
            context.setStrokeColor(PDFStyleConfiguration.Colors.lightTan.cgColor)
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: point.x + padding + leftAccentWidth + subsectionAccentWidth + 8, y: currentY + sectionHeight - 1))
            context.addLine(to: CGPoint(x: point.x + maxWidth - padding, y: currentY + sectionHeight - 1))
            context.strokePath()

            // Enhanced label weight
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Inter-Semibold", size: 10) ?? PDFStyleConfiguration.Typography.captionBold(),
                .ligature: 0,
                .foregroundColor: PDFStyleConfiguration.Colors.terracotta
            ]
            let labelText = NSAttributedString(string: "KEY DISTINCTION", attributes: labelAttributes)
            labelText.draw(at: CGPoint(x: point.x + padding + leftAccentWidth + subsectionAccentWidth + 8, y: currentY + 4))

            // Draw content
            let keyAttributed = parseInlineMarkdown(keyDist, baseAttributes: PDFStyleConfiguration.bodyAttributes())
            drawAttributedString(keyAttributed, to: context, at: CGPoint(x: point.x + padding + leftAccentWidth + subsectionAccentWidth + 8, y: currentY + 22), maxWidth: insetWidth - 20)
            currentY += sectionHeight + sectionSpacing
        }

        // Practical Implication section - warm gray background
        if let practical = parsed.practicalImplication, !practical.isEmpty {
            let sectionHeight = 20 + calculateTextHeight(practical, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: insetWidth - 20) + 12
            let sectionRect = CGRect(x: point.x + padding + leftAccentWidth, y: currentY, width: insetWidth, height: sectionHeight)

            context.setFillColor(PDFStyleConfiguration.Colors.warmGray.cgColor)
            context.fill(sectionRect)

            // Left accent bar
            context.setFillColor(PDFStyleConfiguration.Colors.terracotta.cgColor)
            context.fill(CGRect(x: point.x + padding + leftAccentWidth, y: currentY, width: subsectionAccentWidth, height: sectionHeight))

            // Subtle bottom border
            context.setStrokeColor(PDFStyleConfiguration.Colors.lightTan.cgColor)
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: point.x + padding + leftAccentWidth + subsectionAccentWidth + 8, y: currentY + sectionHeight - 1))
            context.addLine(to: CGPoint(x: point.x + maxWidth - padding, y: currentY + sectionHeight - 1))
            context.strokePath()

            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Inter-Semibold", size: 10) ?? PDFStyleConfiguration.Typography.captionBold(),
                .ligature: 0,
                .foregroundColor: PDFStyleConfiguration.Colors.terracotta
            ]
            let labelText = NSAttributedString(string: "PRACTICAL IMPLICATION", attributes: labelAttributes)
            labelText.draw(at: CGPoint(x: point.x + padding + leftAccentWidth + subsectionAccentWidth + 8, y: currentY + 4))

            let practicalAttributed = parseInlineMarkdown(practical, baseAttributes: PDFStyleConfiguration.bodyAttributes())
            drawAttributedString(practicalAttributed, to: context, at: CGPoint(x: point.x + padding + leftAccentWidth + subsectionAccentWidth + 8, y: currentY + 22), maxWidth: insetWidth - 20)
            currentY += sectionHeight + sectionSpacing
        }

        // Go Deeper — compact italic footer line (small-caps label + em dash +
        // italic description), no nested box-in-box.
        if let goDeeper = parsed.goDeeper, !goDeeper.isEmpty {
            let footerX = point.x + padding + leftAccentWidth

            // Thin separator hairline above the footer.
            context.setStrokeColor(accentColor.withAlphaComponent(0.25).cgColor)
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: footerX, y: currentY + 2))
            context.addLine(to: CGPoint(x: point.x + maxWidth - padding, y: currentY + 2))
            context.strokePath()

            let footer = buildInsightFooter(label: "GO DEEPER", body: goDeeper)
            drawAttributedString(footer, to: context, at: CGPoint(x: footerX, y: currentY + 10), maxWidth: insetWidth)
        }

        return totalHeight + PDFStyleConfiguration.Spacing.blockSpacing
    }

    // MARK: - Insight Note Fragmentation (parallel to Quick Glance / Exercise)

    /// One page-sized fragment of a split insight note. Carries a SUBSET of the
    /// four sections plus its header label ("… (CONTINUED)" for continuations).
    struct InsightNoteFragment {
        let core: String
        let keyDistinction: String?
        let practicalImplication: String?
        let goDeeper: String?
        let headerLabel: String
        let accentColor: UIColor
        let plannedHeight: CGFloat   // == renderInsightNoteFragment's return (measure==draw)
        var parsed: InsightNoteParsed { (core, keyDistinction, practicalImplication, goDeeper) }
    }

    /// PROVISIONAL floor — the minimum real content (sections only, excluding the
    /// 58pt header+padding chrome) a fragment must carry to be worth creating. A
    /// note that can't split into fragments all clearing this pushes whole
    /// instead (no runt fragments). Higher than the exercise floor on purpose: a
    /// two-line orphan of a note card reads worse than a two-step exercise
    /// fragment. Confirm against real note sizes on the first fragmented export.
    static let insightNoteFragmentContentFloor: CGFloat = 120

    /// A note may split only when it is NOT a KEY CHALLENGE — a burgundy
    /// interruption must stay whole (a halved interruption costs more than the gap
    /// it would fill). The renderer gates on this before calling the planner.
    func insightNoteIsSplittable(content: String, title: String) -> Bool {
        Self.classifyInsightNote(content: content, title: title) != .challenge
    }

    /// Split an oversized, splittable note into self-contained fragment cards at
    /// SECTION SEAMS (sections are atomic — never split mid-section). Fragment 1
    /// packs to `firstBudget` (space left on the page), later fragments to
    /// `pageBudget`. Returns nil when the note should NOT be split — fewer than
    /// two sections, only one fragment results, or any fragment falls below the
    /// content floor — so the caller pushes the whole note instead.
    func planInsightNoteFragments(content: String, title: String, maxWidth: CGFloat, firstBudget: CGFloat, pageBudget: CGFloat) -> [InsightNoteFragment]? {
        let noteType = Self.classifyInsightNote(content: content, title: title)
        // Code-side invariant (belt-and-suspenders with the caller's gate): a
        // KEY CHALLENGE must never reach the planner.
        precondition(noteType != .challenge, "KEY CHALLENGE notes must never enter the insight-note fragment planner")

        let parsed = parseInsightNoteContent(content)
        let baseLabel = noteType.label(defaultTitle: title)
        let accent = noteType.accentColor
        let heights = insightNoteSectionHeights(parsed, maxWidth: maxWidth)

        enum Sec { case core, keyDist, practical, goDeeper }
        var units: [(sec: Sec, height: CGFloat)] = []
        if !parsed.coreConnection.isEmpty { units.append((.core, heights.core)) }
        if let kd = parsed.keyDistinction, !kd.isEmpty { units.append((.keyDist, heights.keyDistinction)) }
        if let pr = parsed.practicalImplication, !pr.isEmpty { units.append((.practical, heights.practicalImplication)) }
        if let gd = parsed.goDeeper, !gd.isEmpty { units.append((.goDeeper, heights.goDeeper)) }
        guard units.count >= 2 else { return nil }   // nothing to split at

        // Fixed per-fragment chrome: header(30) + padding*2(28) + trailing spacing.
        let chrome: CGFloat = 30 + 14 * 2 + PDFStyleConfiguration.Spacing.blockSpacing

        // Greedy pack section units into groups, ≥1 unit per group (progress).
        var groups: [[Int]] = []
        var idx = 0
        var isFirst = true
        while idx < units.count {
            let budget = isFirst ? firstBudget : pageBudget
            var used = chrome
            var group: [Int] = []
            while idx < units.count {
                let h = units[idx].height
                if !group.isEmpty && used + h > budget { break }
                group.append(idx); used += h; idx += 1
            }
            groups.append(group)
            isFirst = false
        }

        // Must actually split, and every fragment must clear the content floor.
        guard groups.count >= 2 else { return nil }
        for g in groups {
            let contentH = g.reduce(CGFloat(0)) { $0 + units[$1].height }
            if contentH < Self.insightNoteFragmentContentFloor { return nil }
        }

        var fragments: [InsightNoteFragment] = []
        for (gi, g) in groups.enumerated() {
            var fp: InsightNoteParsed = ("", nil, nil, nil)
            for u in g {
                switch units[u].sec {
                case .core: fp.coreConnection = parsed.coreConnection
                case .keyDist: fp.keyDistinction = parsed.keyDistinction
                case .practical: fp.practicalImplication = parsed.practicalImplication
                case .goDeeper: fp.goDeeper = parsed.goDeeper
                }
            }
            let label = gi == 0 ? baseLabel : "\(baseLabel) (CONTINUED)"
            let planned = insightNoteCardHeight(fp, maxWidth: maxWidth) + PDFStyleConfiguration.Spacing.blockSpacing
            fragments.append(InsightNoteFragment(core: fp.coreConnection, keyDistinction: fp.keyDistinction, practicalImplication: fp.practicalImplication, goDeeper: fp.goDeeper, headerLabel: label, accentColor: accent, plannedHeight: planned))
        }
        return fragments
    }

    /// Draw one planned note fragment (used by the paginating renderer).
    func renderInsightNoteFragment(_ fragment: InsightNoteFragment, to context: CGContext, at point: CGPoint, maxWidth: CGFloat) -> CGFloat {
        drawInsightNoteCard(parsed: fragment.parsed, accentColor: fragment.accentColor, headerLabel: fragment.headerLabel, to: context, at: point, maxWidth: maxWidth)
    }

    /// Strip a redundant leading type prefix ("Key Challenge:" / "Key
    /// Limitation:") from a note's opening. The card header now announces the
    /// type in burgundy, so repeating it as the first words is double-labeling.
    private static func stripRedundantTypePrefix(_ text: String) -> String {
        let prefixes = ["Key Challenge:", "Key Limitation:",
                        "Key Challenge —", "Key Challenge -",
                        "Key Limitation —", "Key Limitation -"]
        let lower = text.lowercased()
        for prefix in prefixes where lower.hasPrefix(prefix.lowercased()) {
            return String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
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
        } else if let goRange = normalizedContent.range(of: "Go Deeper:", options: .caseInsensitive) {
            coreText = String(normalizedContent[..<goRange.lowerBound])
        }
        coreConnection = coreText.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        coreConnection = Self.stripRedundantTypePrefix(coreConnection)

        return (coreConnection, keyDistinction, practicalImplication, goDeeper)
    }

    /// The four parsed sections of an insight note, in draw order.
    typealias InsightNoteParsed = (coreConnection: String, keyDistinction: String?, practicalImplication: String?, goDeeper: String?)

    /// Per-section drawn heights (0 when a section is empty). SINGLE SOURCE OF
    /// TRUTH shared by drawInsightNoteCard (draw), calculateInsightNoteHeight
    /// (measure), and planInsightNoteFragments (split) — so a fragment's planned
    /// height cannot drift from what is drawn. Mirrors the inline math that used
    /// to be duplicated across the draw and measure paths.
    private struct InsightNoteSectionHeights {
        var core: CGFloat = 0
        var keyDistinction: CGFloat = 0
        var practicalImplication: CGFloat = 0
        var goDeeper: CGFloat = 0
        var total: CGFloat { core + keyDistinction + practicalImplication + goDeeper }
    }

    private func insightNoteSectionHeights(_ parsed: InsightNoteParsed, maxWidth: CGFloat) -> InsightNoteSectionHeights {
        let padding: CGFloat = 14
        let leftAccentWidth: CGFloat = 4
        let sectionSpacing: CGFloat = 8
        let insetWidth = maxWidth - padding * 2 - leftAccentWidth
        var h = InsightNoteSectionHeights()
        if !parsed.coreConnection.isEmpty {
            h.core = calculateTextHeight(parsed.coreConnection, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: insetWidth) + sectionSpacing + 4
        }
        if let keyDist = parsed.keyDistinction, !keyDist.isEmpty {
            h.keyDistinction = 20 + calculateTextHeight(keyDist, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: insetWidth - 20) + 16 + sectionSpacing
        }
        if let practical = parsed.practicalImplication, !practical.isEmpty {
            h.practicalImplication = 20 + calculateTextHeight(practical, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: insetWidth - 20) + 16 + sectionSpacing
        }
        if let goDeeper = parsed.goDeeper, !goDeeper.isEmpty {
            let footer = buildInsightFooter(label: "GO DEEPER", body: goDeeper)
            h.goDeeper = 10 + measureAttributed(footer, maxWidth: insetWidth) + 4
        }
        return h
    }

    /// Total drawn card height EXCLUDING the trailing blockSpacing. header(30) +
    /// sections + padding*2. Because the header is a FIXED 30pt slot regardless
    /// of label text, a continuation fragment's "(CONTINUED)" header overhead is
    /// counted for EVERY fragment automatically — measure==draw holds per fragment.
    private func insightNoteCardHeight(_ parsed: InsightNoteParsed, maxWidth: CGFloat) -> CGFloat {
        let padding: CGFloat = 14
        let headerHeight: CGFloat = 30
        return headerHeight + insightNoteSectionHeights(parsed, maxWidth: maxWidth).total + padding * 2
    }

    /// Calculate height for structured insight note (measure twin of the draw path).
    private func calculateInsightNoteHeight(content: String, maxWidth: CGFloat) -> CGFloat {
        let parsed = parseInsightNoteContent(content)
        return insightNoteCardHeight(parsed, maxWidth: maxWidth) + PDFStyleConfiguration.Spacing.blockSpacing
    }

    /// Number of populated sections in a callout block, used by the renderer's
    /// whitespace instrumentation to gauge whether pushed callouts are
    /// multi-section (which would favor section-boundary splitting). Returns 0
    /// for block types without an internal section structure.
    func debugCalloutSectionCount(for block: PDFContentBlock) -> Int {
        guard block.type == .insightNote else { return 0 }
        let parsed = parseInsightNoteContent(block.content)
        var count = 0
        if !parsed.coreConnection.isEmpty { count += 1 }
        if let keyDist = parsed.keyDistinction, !keyDist.isEmpty { count += 1 }
        if let practical = parsed.practicalImplication, !practical.isEmpty { count += 1 }
        if let goDeeper = parsed.goDeeper, !goDeeper.isEmpty { count += 1 }
        return count
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

        // Draw header background (subtle, same tone as card)
        let headerRect = CGRect(x: point.x, y: point.y, width: maxWidth, height: headerHeight)
        let headerPath = UIBezierPath(
            roundedRect: headerRect,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: borderRadius, height: borderRadius)
        )
        context.addPath(headerPath.cgPath)
        context.setFillColor(PDFStyleConfiguration.BlockStyles.actionBoxHeaderBgColor.cgColor)
        context.fillPath()

        // Draw header label (small terracotta text)
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Inter-Semibold", size: 11) ?? PDFStyleConfiguration.Typography.captionBold(),
            .ligature: 0,
            .foregroundColor: PDFStyleConfiguration.Colors.terracotta,
            .kern: 1.1
        ]
        let headerText = NSAttributedString(string: title.uppercased(), attributes: headerAttributes)
        let headerTextRect = CGRect(x: point.x + padding, y: point.y + 8, width: maxWidth - padding * 2, height: headerHeight - 10)
        headerText.draw(in: headerTextRect)

        // Draw steps with bold orange numbers and consistent alignment
        var currentY = point.y + headerHeight + padding
        for (index, step) in steps.enumerated() {
            // Bold orange number
            let numberAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Inter-Bold", size: 17) ?? PDFStyleConfiguration.Typography.bodyBold(),
                .ligature: 0,
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
            .font: UIFont(name: "Inter-Semibold", size: 11) ?? PDFStyleConfiguration.Typography.captionBold(),
            .ligature: 0,
            .foregroundColor: PDFStyleConfiguration.Colors.terracotta,
            .kern: 1.1
        ]
        let headerText = NSAttributedString(string: "KEY TAKEAWAYS", attributes: headerAttributes)
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
                .ligature: 0,
                .foregroundColor: PDFStyleConfiguration.Colors.terracotta
            ]
            let bulletText = NSAttributedString(string: "•", attributes: bulletAttributes)
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
            icon: "",
            borderColor: PDFStyleConfiguration.BlockStyles.narrativeBorderColor,
            bgColor: PDFStyleConfiguration.BlockStyles.narrativeBgColor,
            headerBgColor: PDFStyleConfiguration.Colors.terracotta,
            to: context,
            at: point,
            maxWidth: maxWidth
        )
    }

    /// Shared exercise-header text attributes (font/kern) — used by BOTH the
    /// wrapped-height measure and the draw so they can't drift.
    private static let exerciseHeaderAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont(name: "Inter-Semibold", size: 11) ?? PDFStyleConfiguration.Typography.captionBold(),
        .ligature: 0,
        .kern: 1.1
    ]

    /// Exercise header height grown to fit a WRAPPED title (fixes the p90
    /// "…CORE FRAMEWORK INTO" single-line clip). Single-line titles stay ≈ 30.
    private func exerciseHeaderHeight(_ title: String, maxWidth: CGFloat) -> CGFloat {
        let insetWidth = maxWidth - 14 * 2   // padding = 14
        let h = calculateTextHeight(title.uppercased(), attributes: Self.exerciseHeaderAttributes, maxWidth: insetWidth)
        return max(30, ceil(h) + 16)
    }

    /// Height contributed by one exercise step (number gutter + wrapped step text
    /// + inter-step gap). Shared by exerciseCardHeight and planExerciseFragments
    /// so a fragment's packing decision matches the drawn layout exactly.
    private func exerciseStepHeight(_ step: String, insetWidth: CGFloat, numberWidth: CGFloat = 28) -> CGFloat {
        calculateTextHeight(step, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: insetWidth - numberWidth) + 10
    }

    /// Single source of truth for an exercise card's drawn height (EXCLUDING the
    /// trailing blockSpacing). renderExercise draws to exactly this; both
    /// calculateExerciseHeight and planExerciseFragments measure to exactly this,
    /// so a planned fragment height equals what renderExercise actually returns.
    private func exerciseCardHeight(displayTitle: String, content: String, steps: [String], hasTime: Bool, maxWidth: CGFloat) -> CGFloat {
        let padding: CGFloat = 14
        let numberWidth: CGFloat = 28
        let insetWidth = maxWidth - padding * 2
        let headerHeight = exerciseHeaderHeight(displayTitle, maxWidth: maxWidth)

        let (regularContent, tableData) = parseContentForTables(content)
        var contentHeight: CGFloat = 0
        if !regularContent.isEmpty {
            contentHeight += calculateTextHeight(regularContent, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: insetWidth) + 12
        }
        if !tableData.isEmpty {
            contentHeight += calculateTableHeight(tableData: tableData, maxWidth: insetWidth) + 8
        }
        for step in steps {
            contentHeight += exerciseStepHeight(step, insetWidth: insetWidth, numberWidth: numberWidth)
        }
        if hasTime { contentHeight += 24 } // Time badge height
        return headerHeight + contentHeight + padding * 2
    }

    /// Renders an exercise card. When `continued` is true the header reads
    /// "TITLE (CONTINUED)" and the caller passes an empty `content` (intro text /
    /// table ride on fragment 1) — see planExerciseFragments. Internal (not
    /// private) so the paginating renderer can draw fragments directly.
    func renderExercise(content: String, title: String, steps: [String], estimatedTime: String?, to context: CGContext, at point: CGPoint, maxWidth: CGFloat, continued: Bool = false, startNumber: Int = 1) -> CGFloat {
        let padding: CGFloat = 14
        // displayTitle drives BOTH the measured header height and the drawn header
        // string, so a continuation card's taller/longer header stays measure==draw.
        let displayTitle = continued ? "\(title) (Continued)" : title
        let headerHeight = exerciseHeaderHeight(displayTitle, maxWidth: maxWidth)
        let borderRadius: CGFloat = 6.0
        let numberWidth: CGFloat = 28
        let insetWidth = maxWidth - padding * 2

        // Parse content for potential markdown tables
        let (regularContent, tableData) = parseContentForTables(content)

        // Total card height comes from the shared calculator so it can never
        // drift from calculateExerciseHeight / the fragment planner.
        let hasTime = (estimatedTime.map { !$0.isEmpty } ?? false)
        let totalHeight = exerciseCardHeight(displayTitle: displayTitle, content: content, steps: steps, hasTime: hasTime, maxWidth: maxWidth)

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

        // Draw header — wraps to multiple lines for long titles; the rect grows
        // with the dynamic headerHeight so it never clips (was a fixed 20pt slot).
        var headerAttributes = Self.exerciseHeaderAttributes
        headerAttributes[.foregroundColor] = PDFStyleConfiguration.BlockStyles.exerciseIconColor
        let headerText = NSAttributedString(string: displayTitle.uppercased(), attributes: headerAttributes)
        let headerRect = CGRect(x: point.x + padding, y: point.y + 8, width: insetWidth, height: headerHeight - 12)
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
                .ligature: 0,
                .foregroundColor: PDFStyleConfiguration.BlockStyles.exerciseIconColor
            ]
            // startNumber offsets continuation fragments so a split exercise keeps
            // one continuous sequence (fragment 2 shows 4., 5., … not 1., 2., …).
            let numberText = NSAttributedString(string: "\(startNumber + index).", attributes: numberAttributes)
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
                .ligature: 0,
                .foregroundColor: PDFStyleConfiguration.Colors.textMuted
            ]
            let timeText = NSAttributedString(string: time, attributes: timeAttributes)
            let timeRect = CGRect(x: point.x + padding, y: currentY + 4, width: insetWidth, height: 16)
            timeText.draw(in: timeRect)
        }

        return totalHeight + PDFStyleConfiguration.Spacing.blockSpacing
    }

    /// Renders a Quick Glance card. When `continued` is true the header reads
    /// "QUICK GLANCE (CONTINUED)" and the reading-time badge is suppressed; an
    /// empty `coreMessage` skips the lead quote entirely. Both support splitting
    /// an over-long Quick Glance across pages as self-contained cards.
    func renderQuickGlance(coreMessage: String, keyPoints: [String], readingTime: String?, to context: CGContext, at point: CGPoint, maxWidth: CGFloat, continued: Bool = false) -> CGFloat {
        let padding: CGFloat = 16
        let headerHeight: CGFloat = 32
        let borderRadius: CGFloat = PDFStyleConfiguration.Radius.lg
        let borderWidth: CGFloat = 2
        let insetWidth = maxWidth - padding * 2

        // Calculate heights
        let hasCore = !coreMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let coreMessageHeight = hasCore ? calculateTextHeight(coreMessage, attributes: [
            .font: PDFStyleConfiguration.Typography.bodyLarge(),
            .ligature: 0,
            .foregroundColor: PDFStyleConfiguration.Colors.textBody,
            .paragraphStyle: PDFStyleConfiguration.paragraphStyle(lineHeight: 20, alignment: .left, paragraphSpacing: 8)
        ], maxWidth: insetWidth) : 0
        let coreGap: CGFloat = hasCore ? 16 : 0

        var keyPointsHeight: CGFloat = 0
        for point in keyPoints {
            let pointHeight = calculateTextHeight(point, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: insetWidth - 20)
            keyPointsHeight += pointHeight + 8
        }

        let totalHeight = headerHeight + coreMessageHeight + coreGap + keyPointsHeight + padding * 2

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
            .font: UIFont(name: "Inter-Semibold", size: 11) ?? PDFStyleConfiguration.Typography.captionBold(),
            .ligature: 0,
            .foregroundColor: PDFStyleConfiguration.Colors.terracotta,
            .kern: 1.1
        ]
        let headerText = NSAttributedString(string: continued ? "QUICK GLANCE (CONTINUED)" : "QUICK GLANCE", attributes: headerAttributes)
        let headerTextRect = CGRect(x: point.x + padding, y: point.y + 8, width: maxWidth * 0.7, height: headerHeight - 12)
        headerText.draw(in: headerTextRect)

        // Draw reading time badge with clarification (first fragment only)
        if !continued, let time = readingTime, !time.isEmpty {
            // Clarify that this is the reading time for this guide, not the original book
            let badgeText = "\(time) min guide"
            let badgeAttributes: [NSAttributedString.Key: Any] = [
                .font: PDFStyleConfiguration.Typography.captionBold(),
                .ligature: 0,
                .foregroundColor: PDFStyleConfiguration.Colors.terracotta
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
            context.setFillColor(PDFStyleConfiguration.Colors.terracotta.withAlphaComponent(0.12).cgColor)
            context.fillPath()

            badgeAttributed.draw(in: CGRect(x: badgeRect.minX + 8, y: badgeRect.minY + 2, width: badgeSize.width, height: badgeSize.height))
        }

        var currentY = point.y + headerHeight + padding

        // Draw core message (first fragment only)
        if hasCore {
            let coreAttributes: [NSAttributedString.Key: Any] = [
                .font: PDFStyleConfiguration.Typography.bodyLarge(),
                .ligature: 0,
                .foregroundColor: PDFStyleConfiguration.Colors.textBody,
                .paragraphStyle: PDFStyleConfiguration.paragraphStyle(lineHeight: 20, alignment: .left, paragraphSpacing: 8)
            ]
            let coreAttributed = parseInlineMarkdown(coreMessage, baseAttributes: coreAttributes)
            let drawnCoreHeight = drawAttributedString(coreAttributed, to: context, at: CGPoint(x: point.x + padding, y: currentY), maxWidth: insetWidth)
            currentY += drawnCoreHeight + 16
        }

        // Draw key points
        for keyPoint in keyPoints {
            // Bullet
            let bulletAttributes: [NSAttributedString.Key: Any] = [
                .font: PDFStyleConfiguration.Typography.body(),
                .ligature: 0,
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

    /// One page-sized fragment of a Quick Glance card.
    struct QuickGlanceFragment {
        let coreMessage: String   // empty on continuation fragments
        let keyPoints: [String]
        let continued: Bool
    }

    /// Partition a Quick Glance into fragments that each fit within `pageBudget`
    /// (the full content height of a page). Used only when the whole card is
    /// taller than a single page; each fragment renders as its own bordered card.
    func planQuickGlanceFragments(coreMessage: String, keyPoints: [String], maxWidth: CGFloat, pageBudget: CGFloat) -> [QuickGlanceFragment] {
        let padding: CGFloat = 16
        let headerHeight: CGFloat = 32
        let insetWidth = maxWidth - padding * 2

        func bulletHeight(_ p: String) -> CGFloat {
            calculateTextHeight(p, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: insetWidth - 20) + 8
        }
        let coreHeight = calculateTextHeight(coreMessage, attributes: [
            .font: PDFStyleConfiguration.Typography.bodyLarge(),
            .ligature: 0,
            .foregroundColor: PDFStyleConfiguration.Colors.textBody,
            .paragraphStyle: PDFStyleConfiguration.paragraphStyle(lineHeight: 20, alignment: .left, paragraphSpacing: 8)
        ], maxWidth: insetWidth)

        let chrome = headerHeight + padding * 2   // header + top/bottom padding
        var fragments: [QuickGlanceFragment] = []
        var remaining = keyPoints
        var isFirst = true

        repeat {
            let includeCore = isFirst
            var used = chrome + (includeCore ? coreHeight + 16 : 0)
            var take: [String] = []
            while let next = remaining.first {
                let h = bulletHeight(next)
                // Always take at least one bullet per fragment to guarantee progress.
                if !take.isEmpty && used + h > pageBudget { break }
                take.append(next)
                used += h
                remaining.removeFirst()
            }
            fragments.append(QuickGlanceFragment(coreMessage: includeCore ? coreMessage : "", keyPoints: take, continued: !isFirst))
            isFirst = false
        } while !remaining.isEmpty

        return fragments
    }

    /// One page-sized fragment of an exercise card. Mirrors QuickGlanceFragment.
    struct ExerciseFragment {
        let title: String           // raw title; renderExercise adds the CONTINUED suffix
        let content: String         // intro text / table — carried by fragment 1 only
        let steps: [String]
        let estimatedTime: String?  // time badge — carried by the LAST fragment only
        let continued: Bool
        let startNumber: Int        // 1-based index of this fragment's first step in the whole exercise
        let plannedHeight: CGFloat  // == renderExercise's return value (measure==draw)
    }

    /// Partition an oversized exercise into self-contained bordered cards, one per
    /// page — the exercise analogue of planQuickGlanceFragments. The FIRST fragment
    /// is packed to `firstBudget` (the space left on the current page) so it can
    /// sit under its section heading without stranding it; every later fragment is
    /// packed to the full `pageBudget`. Intro text/table ride on fragment 1; the
    /// time badge rides on the last. All height math routes through
    /// exerciseStepHeight/exerciseCardHeight — the same code the draw path uses —
    /// so each fragment's planned height equals what renderExercise draws.
    func planExerciseFragments(title: String, content: String, steps: [String], estimatedTime: String?, maxWidth: CGFloat, firstBudget: CGFloat, pageBudget: CGFloat) -> [ExerciseFragment] {
        let padding: CGFloat = 14
        let numberWidth: CGFloat = 28
        let insetWidth = maxWidth - padding * 2
        let hasTime = (estimatedTime.map { !$0.isEmpty } ?? false)
        let timeReserve: CGFloat = hasTime ? 24 : 0   // reserved on every fragment; drawn only on the last

        let firstTitle = title
        let contTitle = "\(title) (Continued)"

        // Fragment-1 chrome carries intro content/table; continuation chrome is
        // just its (longer) header + padding.
        let (regularContent, tableData) = parseContentForTables(content)
        var headContentH: CGFloat = 0
        if !regularContent.isEmpty {
            headContentH += calculateTextHeight(regularContent, attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: insetWidth) + 12
        }
        if !tableData.isEmpty {
            headContentH += calculateTableHeight(tableData: tableData, maxWidth: insetWidth) + 8
        }
        let firstChrome = exerciseHeaderHeight(firstTitle, maxWidth: maxWidth) + padding * 2 + headContentH
        let contChrome = exerciseHeaderHeight(contTitle, maxWidth: maxWidth) + padding * 2

        // Greedy pack — always take ≥1 step per fragment to guarantee progress.
        var groups: [[String]] = []
        var remaining = steps
        var isFirst = true
        while !remaining.isEmpty {
            let chrome = isFirst ? firstChrome : contChrome
            let budget = isFirst ? firstBudget : pageBudget
            var used = chrome + timeReserve
            var take: [String] = []
            while let next = remaining.first {
                let h = exerciseStepHeight(next, insetWidth: insetWidth, numberWidth: numberWidth)
                if !take.isEmpty && used + h > budget { break }
                if take.isEmpty && used + h > budget {
                    // Unsplittable atom: a single step + chrome already exceeds the
                    // page. Take it anyway (progress) and leave a ⏭️ trace — it
                    // draws past the page edge, the same defined fallback QG uses.
                    print("⏭️ [PDF Renderer] exercise step exceeds page budget (chrome+step=\(Int((used + h).rounded()))pt > \(Int(budget.rounded()))pt) — fragment renders with overflow")
                }
                take.append(next)
                used += h
                remaining.removeFirst()
            }
            groups.append(take)
            isFirst = false
        }

        // Tail floor: a lone runt step at the end is only acceptable when the
        // prior fragment was genuinely full — log it so it isn't a silent quirk.
        if groups.count > 1, let last = groups.last, last.count < 2 {
            print("ℹ️ [PDF Renderer] exercise final fragment has \(last.count) step(s) — unavoidable at these step heights")
        }

        var fragments: [ExerciseFragment] = []
        let lastIndex = groups.count - 1
        var stepCursor = 1   // 1-based running index so step numbers stay continuous across fragments
        for (i, group) in groups.enumerated() {
            let isFirstFrag = (i == 0)
            let dispTitle = isFirstFrag ? firstTitle : contTitle
            let fragContent = isFirstFrag ? content : ""
            let fragTime = (i == lastIndex) ? estimatedTime : nil
            let fragHasTime = (fragTime.map { !$0.isEmpty } ?? false)
            let h = exerciseCardHeight(displayTitle: dispTitle, content: fragContent, steps: group, hasTime: fragHasTime, maxWidth: maxWidth)
                + PDFStyleConfiguration.Spacing.blockSpacing
            fragments.append(ExerciseFragment(title: title, content: fragContent, steps: group, estimatedTime: fragTime, continued: !isFirstFrag, startNumber: stepCursor, plannedHeight: h))
            stepCursor += group.count
        }
        return fragments
    }

    /// Minimum height a viable FIRST fragment needs (header + intro + a 2-step
    /// floor). The renderer uses this to decide whether the current page has room
    /// to start the exercise here or should break first — avoiding a runt
    /// fragment-1 that carries only chrome and no meaningful body.
    func minExerciseFragmentHeight(title: String, content: String, steps: [String], maxWidth: CGFloat) -> CGFloat {
        let floorSteps = Array(steps.prefix(2))
        return exerciseCardHeight(displayTitle: title, content: content, steps: floorSteps, hasTime: false, maxWidth: maxWidth)
    }

    private func renderList(items: [String], numbered: Bool, to context: CGContext, at point: CGPoint, maxWidth: CGFloat) -> CGFloat {
        var currentY = point.y

        for (index, item) in items.enumerated() {
            let bulletWidth: CGFloat = numbered ? 24 : 16

            if numbered {
                let numberAttributes: [NSAttributedString.Key: Any] = [
                    .font: PDFStyleConfiguration.Typography.bodyBold(),
                    .ligature: 0,
                    .foregroundColor: PDFStyleConfiguration.Colors.primaryGold
                ]
                let numberText = NSAttributedString(string: "\(index + 1).", attributes: numberAttributes)
                let numberRect = CGRect(x: point.x, y: currentY, width: bulletWidth, height: 18)
                numberText.draw(in: numberRect)
            } else {
                let bulletAttributes: [NSAttributedString.Key: Any] = [
                    .font: PDFStyleConfiguration.Typography.body(),
                    .ligature: 0,
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

    /// Per-row drawn heights (min 20pt + cell padding). SINGLE SOURCE OF TRUTH
    /// shared by renderTable (draw), calculateTableHeight (measure), and
    /// planTableFragments (split) so a fragment's planned height cannot drift.
    /// Column widths are an EVEN split by column count (content-independent), so
    /// every fragment with the same columnCount + maxWidth aligns identically.
    private func tableRowHeights(_ tableData: [[String]], maxWidth: CGFloat) -> [CGFloat] {
        let padding: CGFloat = 8
        let cellPadding: CGFloat = 10
        let columnCount = tableData.first?.count ?? 1
        let cellWidth = (maxWidth - padding * 2) / CGFloat(columnCount)
        let cellContentWidth = cellWidth - cellPadding * 2
        return tableData.map { row in
            var maxCellHeight: CGFloat = 20
            for cell in row {
                let cellHeight = calculateTextHeight(stripMarkdownSyntax(cell), attributes: PDFStyleConfiguration.bodyAttributes(), maxWidth: cellContentWidth)
                maxCellHeight = max(maxCellHeight, cellHeight + cellPadding * 2)
            }
            return maxCellHeight
        }
    }

    private func renderTable(tableData: [[String]], to context: CGContext, at point: CGPoint, maxWidth: CGFloat) -> CGFloat {
        guard !tableData.isEmpty else { return 0 }

        let padding: CGFloat = 8
        let borderRadius = PDFStyleConfiguration.Radius.sm
        let cellPadding: CGFloat = 10

        // Calculate column widths evenly
        let columnCount = tableData.first?.count ?? 1
        let cellWidth = (maxWidth - padding * 2) / CGFloat(columnCount)
        let cellContentWidth = cellWidth - cellPadding * 2

        // Row heights — shared single source (see tableRowHeights).
        let rowHeights = tableRowHeights(tableData, maxWidth: maxWidth)

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
                    .ligature: 0,
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
        return tableRowHeights(tableData, maxWidth: maxWidth).reduce(0, +) + padding * 2 + PDFStyleConfiguration.Spacing.blockSpacing
    }

    // MARK: - Table Fragmentation (row-atomic, header repeats per fragment)

    struct TableFragment {
        let rows: [[String]]        // row 0 is the repeated header; then this fragment's data rows
        let plannedHeight: CGFloat  // == renderTableFragment's return (measure==draw)
    }

    /// Caption ("TABLE N: …") height for a table block — 0 when unnumbered. The
    /// caption rides fragment 1 ONLY; the renderer reserves this from fragment-1's
    /// budget and draws it once.
    func tableCaptionHeight(for block: PDFContentBlock) -> CGFloat {
        figureLabel(for: block) != nil ? figureCaptionHeight : 0
    }

    /// Draw the table caption once (fragment 1). Returns drawn height (0 if none).
    func renderTableCaption(for block: PDFContentBlock, to context: CGContext, at point: CGPoint, maxWidth: CGFloat) -> CGFloat {
        guard let fig = figureLabel(for: block) else { return 0 }
        return renderFigureCaption(fig, to: context, at: point, maxWidth: maxWidth)
    }

    /// Split an oversized table at ROW boundaries (never mid-row). Each fragment
    /// is a complete small table = [repeated header row] + a subset of data rows,
    /// so the existing renderTable draws it verbatim (header once, columns aligned
    /// by the even-split width). Fragment 1 packs to `firstBudget`, the rest to
    /// `pageBudget`. Returns nil — push the whole table — when there are fewer
    /// than 4 data rows or any fragment would carry fewer than 2 data rows.
    func planTableFragments(tableData: [[String]], maxWidth: CGFloat, firstBudget: CGFloat, pageBudget: CGFloat) -> [TableFragment]? {
        guard tableData.count >= 3 else { return nil }   // header + ≥2 data rows to form two groups
        let padding: CGFloat = 8
        let rowHeights = tableRowHeights(tableData, maxWidth: maxWidth)
        let headerH = rowHeights[0]
        let chrome = padding * 2 + PDFStyleConfiguration.Spacing.blockSpacing + headerH

        // Greedy pack DATA row indices (1...) into groups, ≥1 per group.
        var groups: [[Int]] = []
        var idx = 1
        var isFirst = true
        while idx < tableData.count {
            let budget = isFirst ? firstBudget : pageBudget
            var used = chrome
            var group: [Int] = []
            while idx < tableData.count {
                let h = rowHeights[idx]
                if !group.isEmpty && used + h > budget { break }
                group.append(idx); used += h; idx += 1
            }
            groups.append(group); isFirst = false
        }

        guard groups.count >= 2 else { return nil }
        // Floor: a fragment is acceptable if it holds ≥2 data rows OR its single
        // row is tall enough to justify its own card. Without the height escape, a
        // table whose rows are each too tall to pair (greedy yields one row per
        // group) would be rejected and pushed WHOLE — overflowing the page by
        // multiples (the 2402pt-table bug). A tall single row is a legitimate
        // fragment, not an orphan runt; only a SHORT single-row group is rejected.
        let minSingleRowFragment = max(120, pageBudget * 0.30)
        for g in groups where g.count < 2 {
            if rowHeights[g[0]] < minSingleRowFragment { return nil }
        }

        return groups.map { g in
            var rows: [[String]] = [tableData[0]]
            for i in g { rows.append(tableData[i]) }
            let h = tableRowHeights(rows, maxWidth: maxWidth).reduce(0, +) + padding * 2 + PDFStyleConfiguration.Spacing.blockSpacing
            return TableFragment(rows: rows, plannedHeight: h)
        }
    }

    /// Draw one table fragment — it is a complete small table, so this defers to
    /// renderTable (header drawn once as row 0, columns aligned by even split).
    func renderTableFragment(_ fragment: TableFragment, to context: CGContext, at point: CGPoint, maxWidth: CGFloat) -> CGFloat {
        renderTable(tableData: fragment.rows, to: context, at: point, maxWidth: maxWidth)
    }

    // MARK: - Diagram Scale-to-Fit (whitespace lever for vector diagrams)

    /// Diagram block types that are pure vector drawings — safe to scale
    /// uniformly (text scales with the figure, legibility ratio preserved).
    /// Text-heavy blocks (notes/tables/paragraphs) are NEVER scaled.
    static let scalableDiagramTypes: Set<PDFContentBlock.BlockType> = [.flowchart, .conceptMap, .processTimeline, .loopDiagram, .spectrum, .pyramid, .cycle, .funnel, .barChart, .pieChart]

    /// Below this uniform scale, a diagram is judged illegible — push whole
    /// instead (legibility outranks whitespace). Observed real gaps (458–510pt
    /// against ~526pt diagrams) yield s≈0.87–0.97, so the floor should not bind
    /// on measured content; it only guards genuinely monstrous diagrams.
    static let diagramLegibilityFloor: CGFloat = 0.70

    enum DiagramFit: Equatable {
        case fits                                   // H ≤ remaining — draw normally
        case scale(factor: CGFloat, target: CGFloat) // draw uniformly scaled to fill `target` (== the height the loop advances by)
        case pushWhole                              // scale would fall below the floor — push to a fresh page at 100%
    }

    /// PURE decision (no canvas) — the measure==draw contract lives here: when we
    /// scale, `target` is exactly the height the renderer draws AND the height the
    /// paginator advances currentY by. Unit-tested directly.
    func diagramScaleDecision(naturalHeight H: CGFloat, remaining R: CGFloat, floor: CGFloat = PDFContentBlockRenderer.diagramLegibilityFloor) -> DiagramFit {
        if H <= R { return .fits }
        guard H > 0 else { return .fits }
        let s = R / H
        return s >= floor ? .scale(factor: s, target: R) : .pushWhole
    }

    /// Draw a diagram block uniformly scaled by `factor` so it fills `target`
    /// height, horizontally centered. Pure CGContext transform around the
    /// existing renderBlock draw — PDFDiagramRenderer is untouched. Returns
    /// `target` (the scaled drawn height == what the paginator advances by).
    func renderDiagramScaledToFit(_ block: PDFContentBlock, factor: CGFloat, target: CGFloat, to context: CGContext, at point: CGPoint, maxWidth: CGFloat) -> CGFloat {
        context.saveGState()
        // Center the shrunken figure horizontally, anchor its top at point.y,
        // then scale both axes by `factor` so the natural-size draw lands at
        // `target` tall and (maxWidth*factor) wide.
        context.translateBy(x: point.x + maxWidth * (1 - factor) / 2, y: point.y)
        context.scaleBy(x: factor, y: factor)
        _ = renderBlock(block, to: context, at: .zero, maxWidth: maxWidth)
        context.restoreGState()
        return target
    }

    // MARK: - Helper: Special Block Renderer
    // Unified styling matching Insight Note pattern for consistency

    /// Renders a special block using the shared mockup palette (lightTan border,
    /// terracotta header, no icon). Background defaults to warmCream.
    private func renderMockupBlock(
        content: String,
        title: String,
        bgColor: UIColor = PDFStyleConfiguration.Colors.warmCream,
        accentColor: UIColor? = nil,
        to context: CGContext,
        at point: CGPoint,
        maxWidth: CGFloat
    ) -> CGFloat {
        // A semantic accent (when supplied) tints both the left accent bar and the
        // label chip so component classes are pre-attentively distinguishable —
        // e.g. research (evidence/teal) vs limitations (caution/amber).
        return renderSpecialBlock(
            content: content,
            title: title,
            icon: "",
            borderColor: accentColor ?? PDFStyleConfiguration.Colors.lightTan,
            bgColor: bgColor,
            headerBgColor: accentColor ?? PDFStyleConfiguration.Colors.terracotta,
            to: context,
            at: point,
            maxWidth: maxWidth
        )
    }

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
            .ligature: 0,
            .foregroundColor: headerBgColor
        ]
        let headerString = icon.isEmpty ? title.uppercased() : "\(icon) \(title.uppercased())"
        let headerText = NSAttributedString(string: headerString, attributes: headerAttributes)
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
            .ligature: 0,
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

    private func calculateExerciseHeight(title: String, content: String, steps: [String], maxWidth: CGFloat) -> CGFloat {
        // hasTime: true mirrors the non-fragmented render path — PDFAnalysisDocument
        // always attaches a "~N min" estimate, so the whole-card height reserves
        // the time badge just as renderExercise draws it.
        return exerciseCardHeight(displayTitle: title, content: content, steps: steps, hasTime: true, maxWidth: maxWidth)
            + PDFStyleConfiguration.Spacing.blockSpacing
    }

    private func calculateQuickGlanceHeight(coreMessage: String, keyPoints: [String], readingTime: String?, maxWidth: CGFloat) -> CGFloat {
        let padding: CGFloat = 16
        let headerHeight: CGFloat = 32
        let insetWidth = maxWidth - padding * 2

        let coreMessageHeight = calculateTextHeight(coreMessage, attributes: [
            .font: PDFStyleConfiguration.Typography.bodyLarge(),
            .ligature: 0,
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

    /// Height of an attributed string using the EXACT same layout as
    /// `drawAttributedString` (same word-wrap paragraph style, same bounding
    /// options, same +2 buffer), so a measured height matches the drawn height
    /// for the identical string. Draw-free counterpart for height calcs.
    private func measureAttributed(_ attributedString: NSAttributedString, maxWidth: CGFloat) -> CGFloat {
        let mutableString = NSMutableAttributedString(attributedString: attributedString)
        guard mutableString.length > 0 else { return 0 }
        let fullRange = NSRange(location: 0, length: mutableString.length)

        var paragraphStyle: NSMutableParagraphStyle
        if let existingStyle = mutableString.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle,
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

        // Strip ASCII/heavy box-drawing characters. Directional arrows
        // (→ ← ↑ ↓) are intentionally NOT stripped: an arrow in paragraph text
        // is a semantic connector in a process flow (e.g. "World → senses →
        // internal image → action"). Deleting it left mangled double spaces;
        // keeping it preserves meaning (CormorantGaramond renders these glyphs).
        // Mirrors the same decision in PDFAnalysisDocument.sanitize.
        let boxChars = ["┌", "┐", "└", "┘", "├", "┤", "┬", "┴", "┼", "─", "│"]
        for char in boxChars {
            result = result.replacingOccurrences(of: char, with: "")
        }

        // Collapse any runs of horizontal whitespace left by earlier
        // substitutions (or by arrows already stripped upstream), so flows
        // never render with stray double spaces.
        if let spaceRegex = try? NSRegularExpression(pattern: "[ \\t]{2,}", options: []) {
            result = spaceRegex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: " "
            )
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
            // Fallback: render placeholder + caption if image not cached. The
            // 16pt label slot is always drawn by renderVisual, so reserve it here
            // too (matches the cached-image path below).
            let placeholderHeight: CGFloat = 120 // Consistent placeholder size
            let captionHeight = block.content.isEmpty ? 0 :
                calculateTextHeight(block.content, attributes: PDFStyleConfiguration.captionAttributes(), maxWidth: maxWidth)
            let labelHeight: CGFloat = 16
            return placeholderHeight + captionHeight + labelHeight + PDFStyleConfiguration.Spacing.blockSpacing
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
                .ligature: 0,
                .paragraphStyle: PDFStyleConfiguration.paragraphStyle(lineHeight: 32, alignment: .center, paragraphSpacing: 0)
            ]
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: PDFStyleConfiguration.Typography.caption(),
                .ligature: 0,
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

        // Render the assigned figure label ("Figure N") alongside the visual
        // type label, in the 16pt slot that calculateVisualHeight always
        // reserves. Rendering the figure number here keeps it in sync with the
        // "Figure N" reference woven into the prose.
        var labelParts: [String] = []
        if let fig = figureLabel(for: block) { labelParts.append(fig) }
        if let visualType = block.visualType { labelParts.append(visualTypeLabel(visualType)) }
        if !labelParts.isEmpty {
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .medium),
                .ligature: 0,
                .foregroundColor: PDFStyleConfiguration.Colors.primaryGold
            ]
            let labelString = NSAttributedString(string: labelParts.joined(separator: " · "), attributes: labelAttributes)
            labelString.draw(at: CGPoint(x: point.x, y: point.y + yOffset))
        }
        yOffset += 16

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

    // MARK: - The Library entry (Citation Spec §4)

    private func calculateLibraryEntryHeight(block: PDFContentBlock, maxWidth: CGFloat) -> CGFloat {
        let m = block.metadata ?? [:]
        let authors = m["authors"].map { " · \($0)" } ?? ""
        let title = (m["title"] ?? "") + authors
        let why = m["why"] ?? ""
        let textWidth = maxWidth - 18 - 72
        let titleH = calculateTextHeight(title, attributes: [.font: PDFStyleConfiguration.Typography.bodyBold()], maxWidth: textWidth)
        let whyH = why.isEmpty ? 0 : calculateTextHeight(why, attributes: [.font: PDFStyleConfiguration.Typography.caption()], maxWidth: maxWidth - 18)
        return titleH + whyH + 18
    }

    /// Render one citation on The Library page: color dot (by function), title +
    /// authors, a fresh one-line "why", and an audience-level pill.
    @discardableResult
    private func renderLibraryEntry(block: PDFContentBlock, to context: CGContext, at point: CGPoint, maxWidth: CGFloat) -> CGFloat {
        let m = block.metadata ?? [:]
        let color = PDFStyleConfiguration.Colors.semanticColor(for: m["colorToken"] ?? "burgundy")
        let title = m["title"] ?? ""
        let authors = m["authors"] ?? ""
        let why = m["why"] ?? ""
        let level = m["level"] ?? ""

        var y = point.y

        // Function color dot.
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: CGRect(x: point.x, y: y + 5, width: 8, height: 8))

        let textX = point.x + 18

        // Audience-level pill, right-aligned.
        var pillWidth: CGFloat = 0
        if !level.isEmpty {
            let pillText = NSAttributedString(string: level.uppercased(), attributes: [
                .font: PDFStyleConfiguration.Typography.caption(),
                .ligature: 0,
                .foregroundColor: PDFStyleConfiguration.Colors.textMuted
            ])
            let tw = pillText.size().width
            pillWidth = tw + 18
            let pillRect = CGRect(x: point.x + maxWidth - pillWidth, y: y, width: pillWidth, height: 18)
            let pillPath = UIBezierPath(roundedRect: pillRect, cornerRadius: 9)
            context.addPath(pillPath.cgPath)
            context.setStrokeColor(PDFStyleConfiguration.Colors.borderMedium.cgColor)
            context.setLineWidth(1.0)
            context.strokePath()
            pillText.draw(in: CGRect(x: pillRect.minX + 9, y: pillRect.minY + 3, width: tw + 2, height: 14))
        }

        // Title + authors.
        let titleWidth = maxWidth - 18 - (pillWidth > 0 ? pillWidth + 10 : 0)
        let titleAttr = NSMutableAttributedString(string: title, attributes: [
            .font: PDFStyleConfiguration.Typography.bodyBold(),
            .ligature: 0,
            .foregroundColor: PDFStyleConfiguration.Colors.textHeading
        ])
        if !authors.isEmpty {
            titleAttr.append(NSAttributedString(string: " · \(authors)", attributes: [
                .font: PDFStyleConfiguration.Typography.bodySmall(),
                .ligature: 0,
                .foregroundColor: PDFStyleConfiguration.Colors.textMuted
            ]))
        }
        let titleH = titleAttr.boundingRect(with: CGSize(width: titleWidth, height: .greatestFiniteMagnitude),
                                            options: [.usesLineFragmentOrigin], context: nil).height
        titleAttr.draw(with: CGRect(x: textX, y: y, width: titleWidth, height: titleH),
                       options: [.usesLineFragmentOrigin], context: nil)
        y += titleH + 2

        // Fresh one-line "why".
        if !why.isEmpty {
            let whyAttr = NSAttributedString(string: why, attributes: [
                .font: PDFStyleConfiguration.Typography.caption(),
                .ligature: 0,
                .foregroundColor: PDFStyleConfiguration.Colors.textMuted
            ])
            let whyH = whyAttr.boundingRect(with: CGSize(width: maxWidth - 18, height: .greatestFiniteMagnitude),
                                            options: [.usesLineFragmentOrigin], context: nil).height
            whyAttr.draw(with: CGRect(x: textX, y: y, width: maxWidth - 18, height: whyH),
                         options: [.usesLineFragmentOrigin], context: nil)
            y += whyH
        }

        // Dashed separator.
        y += 8
        context.saveGState()
        context.setStrokeColor(PDFStyleConfiguration.Colors.borderLight.cgColor)
        context.setLineWidth(0.5)
        context.setLineDash(phase: 0, lengths: [2, 2])
        context.move(to: CGPoint(x: point.x, y: y))
        context.addLine(to: CGPoint(x: point.x + maxWidth, y: y))
        context.strokePath()
        context.restoreGState()

        return (y - point.y) + 6
    }

    // MARK: - Section-opener reading chip (Directives §C1)

    /// Render a single muted small-caps line: "⏱ 6 MIN READ · THEME 3 OF 8".
    @discardableResult
    private func renderReadingChip(block: PDFContentBlock, to context: CGContext, at point: CGPoint, maxWidth: CGFloat) -> CGFloat {
        let m = block.metadata ?? [:]
        var parts: [String] = []
        if let time = m["readingTime"], !time.isEmpty { parts.append("\(time) MIN READ") }
        if let progress = m["progress"], !progress.isEmpty { parts.append(progress.uppercased()) }
        guard !parts.isEmpty else { return 0 }

        let style = NSMutableParagraphStyle()
        style.alignment = .left
        let attributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.caption(),
            .ligature: 0,
            .foregroundColor: PDFStyleConfiguration.Colors.textMuted,
            .kern: 1.2,
            .paragraphStyle: style
        ]
        NSAttributedString(string: parts.joined(separator: "   ·   "), attributes: attributes)
            .draw(in: CGRect(x: point.x, y: point.y, width: maxWidth, height: 16))

        return 18 + PDFStyleConfiguration.Spacing.blockSpacing
    }

    /// Get a user-friendly label for visual type
    private func visualTypeLabel(_ type: GuideVisualType) -> String {
        switch type {
        // Emoji removed — the embedded serif/sans fonts don't contain these
        // glyphs, so they rendered as the missing-glyph box in the PDF.
        case .timeline: return "Timeline"
        case .flowDiagram: return "Flow Diagram"
        case .comparisonMatrix: return "Comparison Matrix"
        case .barChart: return "Bar Chart"
        case .quadrant: return "Quadrant Analysis"
        case .conceptMap: return "Concept Map"
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
        // Promoted diagram types (Directives §A4)
        case loopDiagram
        case spectrum
        // Native visual renderers (capability-audit Batch 2)
        case pyramid
        case cycle
        case funnel
        case barChart
        case pieChart
        // The Library end-page entry (Citation Spec §4)
        case libraryEntry
        // Section-opener reading-time + progress chip (Directives §C1)
        case readingChip
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
