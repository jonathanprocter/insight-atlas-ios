import UIKit
import UIKit
import CoreGraphics
import PDFKit

// MARK: - Insight Atlas PDF Renderer
// Main renderer that coordinates cover page, content blocks, and pagination

final class InsightAtlasPDFRenderer {

    // MARK: - Types

    struct RenderOptions {
        var includeCoverPage: Bool = true
        var includeTableOfContents: Bool = true
        var includePageNumbers: Bool = true
        var includeHeader: Bool = true
        var includeFooter: Bool = true
        var logoImage: UIImage? = nil

        static let `default` = RenderOptions()
    }

    struct RenderResult {
        let pdfData: Data
        let pageCount: Int
        let documentTitle: String
    }

    // MARK: - Properties

    private let pageSize: CGSize
    private let contentRect: CGRect
    private let coverRenderer: PDFCoverPageRenderer
    private let blockRenderer: PDFContentBlockRenderer

    private var currentPage: Int = 0
    private var tableOfContents: [(title: String, page: Int, isSubsection: Bool)] = []

    // MARK: - Initialization

    init(
        pageSize: CGSize = PDFStyleConfiguration.PageLayout.pageSize,
        contentRect: CGRect = PDFStyleConfiguration.PageLayout.contentRect
    ) {
        self.pageSize = pageSize
        self.contentRect = contentRect
        self.coverRenderer = PDFCoverPageRenderer(pageSize: pageSize)
        self.blockRenderer = PDFContentBlockRenderer(pageSize: pageSize, contentRect: contentRect)
    }

    // MARK: - Main Render Method

    /// Render a complete PDF document from parsed analysis content
    /// - Parameters:
    ///   - document: The structured document to render
    ///   - options: Rendering options
    /// - Returns: RenderResult containing PDF data and metadata
    func render(document: PDFAnalysisDocument, options: RenderOptions = .default) throws -> RenderResult {
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        currentPage = 0
        tableOfContents = []

        // First pass: build TOC (calculate page numbers)
        buildTableOfContents(document: document, options: options)

        let pdfData = pdfRenderer.pdfData { context in
            // Cover page
            if options.includeCoverPage {
                renderCoverPage(context: context, document: document, options: options)
            }

            // Table of contents page
            if options.includeTableOfContents && !tableOfContents.isEmpty {
                renderTableOfContentsPage(context: context, options: options)
            }

            // Content pages
            renderContentPages(context: context, document: document, options: options)
        }

        return RenderResult(
            pdfData: pdfData,
            pageCount: currentPage,
            documentTitle: document.book.title
        )
    }

    /// Render PDF from raw markdown content (legacy convenience method)
    ///
    /// - Warning: This method parses raw markdown at render time, bypassing
    ///   semantic normalization. For production use, prefer `render(document:)`
    ///   with a pre-normalized `EditorialDocument` converted to `PDFAnalysisDocument`.
    ///
    /// - Note: This path is maintained for legacy compatibility. New call sites
    ///   should use the normalized document path to ensure output contract compliance.
    ///
    /// GOVERNANCE LOCK: In future versions, this method may be deprecated
    /// in favor of enforcing the normalized content path exclusively.
    func render(
        markdownContent: String,
        title: String,
        author: String,
        options: RenderOptions = .default
    ) throws -> RenderResult {
        #if DEBUG
        // Debug assertion to track usage of raw markdown path
        print("⚠️ [PDF Renderer] Using raw markdown path. Consider using render(document:) with normalized content.")
        #endif

        // Parse the markdown into structured document
        let document = PDFAnalysisDocument.parse(from: markdownContent, title: title, author: author)
        return try render(document: document, options: options)
    }

    // MARK: - Page Rendering

    private func renderCoverPage(context: UIGraphicsPDFRendererContext, document: PDFAnalysisDocument, options: RenderOptions) {
        context.beginPage()
        currentPage += 1

        coverRenderer.render(
            to: context.cgContext,
            title: document.book.title,
            author: document.book.author,
            logoImage: options.logoImage ?? UIImage(named: "Logo")
        )
    }

    private func renderTableOfContentsPage(context: UIGraphicsPDFRendererContext, options: RenderOptions) {
        context.beginPage()
        currentPage += 1

        _ = coverRenderer.renderTableOfContents(
            to: context.cgContext,
            sections: tableOfContents
        )
    }

    private func renderContentPages(context: UIGraphicsPDFRendererContext, document: PDFAnalysisDocument, options: RenderOptions) {
        var currentY = contentRect.minY
        var needsNewPage = true
        let minContentAfterHeading: CGFloat = 100 // Minimum content to keep with heading to avoid orphans

        // Render Quick Glance if present
        if let quickGlance = document.quickGlance {
            if needsNewPage {
                startNewContentPage(context: context, options: options)
                currentY = contentRect.minY
                needsNewPage = false
            }

            let quickGlanceBlock = PDFContentBlock(
                type: .quickGlance,
                content: quickGlance.coreMessage,
                listItems: quickGlance.keyPoints,
                metadata: ["readingTime": "\(quickGlance.readingTime)"]
            )

            let height = blockRenderer.calculateBlockHeight(block: quickGlanceBlock, maxWidth: contentRect.width)

            if currentY + height > contentRect.maxY {
                startNewContentPage(context: context, options: options)
                currentY = contentRect.minY
            }

            blockRenderer.renderBlock(
                quickGlanceBlock,
                to: context.cgContext,
                at: CGPoint(x: contentRect.minX, y: currentY),
                maxWidth: contentRect.width
            )

            currentY += height
        }

        // Render sections
        for section in document.sections {
            // Skip sections with no content (empty heading + no blocks)
            if section.blocks.isEmpty && section.heading == nil {
                continue
            }

            // Render section heading if present
            if let heading = section.heading {
                // Use the section heading height calculator which handles PART headers
                let headingHeight = blockRenderer.calculateSectionHeadingHeight(heading, level: section.headingLevel, maxWidth: contentRect.width)

                // Calculate first block height to avoid orphaned headings
                let firstBlockHeight = section.blocks.first.map {
                    blockRenderer.calculateBlockHeight(block: $0, maxWidth: contentRect.width)
                } ?? 0
                let combinedHeight = headingHeight + min(firstBlockHeight, minContentAfterHeading)

                // Check if heading + some content fits, otherwise start new page
                if needsNewPage || currentY + combinedHeight > contentRect.maxY - 30 {
                    startNewContentPage(context: context, options: options)
                    currentY = contentRect.minY
                    needsNewPage = false
                }

                // Render with the correct heading level
                let renderedHeight = blockRenderer.renderSectionHeading(
                    heading,
                    level: section.headingLevel,
                    to: context.cgContext,
                    at: CGPoint(x: contentRect.minX, y: currentY),
                    maxWidth: contentRect.width
                )

                currentY += renderedHeight
            } else if needsNewPage {
                startNewContentPage(context: context, options: options)
                currentY = contentRect.minY
                needsNewPage = false
            }

            // Render section blocks
            for (index, block) in section.blocks.enumerated() {
                let blockHeight = blockRenderer.calculateBlockHeight(block: block, maxWidth: contentRect.width)

                // Skip rendering empty content blocks
                if block.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   (block.listItems?.isEmpty ?? true) &&
                   block.type != .divider {
                    continue
                }

                // Check if this is a heading block - apply widow/orphan control
                let isHeadingBlock = [.heading1, .heading2, .heading3, .heading4].contains(block.type)
                if isHeadingBlock {
                    // Look ahead to see if there's content after this heading
                    let nextBlockHeight = (index + 1 < section.blocks.count) ?
                        blockRenderer.calculateBlockHeight(block: section.blocks[index + 1], maxWidth: contentRect.width) : 0
                    let combinedHeight = blockHeight + min(nextBlockHeight, minContentAfterHeading)

                    if currentY + combinedHeight > contentRect.maxY - 30 {
                        startNewContentPage(context: context, options: options)
                        currentY = contentRect.minY
                    }
                } else if currentY + blockHeight > contentRect.maxY {
                    // Regular block - just check if it fits
                    startNewContentPage(context: context, options: options)
                    currentY = contentRect.minY
                }

                let renderedHeight = blockRenderer.renderBlock(
                    block,
                    to: context.cgContext,
                    at: CGPoint(x: contentRect.minX, y: currentY),
                    maxWidth: contentRect.width
                )

                currentY += renderedHeight
            }
        }

        // Render closing page with branding
        renderClosingPage(context: context, options: options)
    }

    private func startNewContentPage(context: UIGraphicsPDFRendererContext, options: RenderOptions) {
        context.beginPage()
        currentPage += 1

        // Draw header
        if options.includeHeader {
            drawPageHeader(context: context.cgContext, pageNumber: currentPage)
        }

        // Draw footer
        if options.includeFooter {
            drawPageFooter(context: context.cgContext, pageNumber: currentPage, includePageNumber: options.includePageNumbers)
        }
    }

    private func renderClosingPage(context: UIGraphicsPDFRendererContext, options: RenderOptions) {
        context.beginPage()
        currentPage += 1

        let cgContext = context.cgContext

        // Fill background
        cgContext.setFillColor(PDFStyleConfiguration.Colors.bgPrimary.cgColor)
        cgContext.fill(CGRect(origin: .zero, size: pageSize))

        // Draw decorative border
        let inset: CGFloat = 72
        let borderRect = CGRect(
            x: inset,
            y: inset,
            width: pageSize.width - inset * 2,
            height: pageSize.height - inset * 2
        )

        cgContext.setStrokeColor(PDFStyleConfiguration.Colors.primaryGold.withAlphaComponent(0.3).cgColor)
        cgContext.setLineWidth(0.5)
        cgContext.stroke(borderRect)

        // Draw closing content
        let centerX = pageSize.width / 2
        var currentY: CGFloat = 280

        // Draw logo
        if let logo = options.logoImage ?? UIImage(named: "Logo") {
            let logoSize: CGFloat = 120
            let logoRect = CGRect(
                x: centerX - logoSize / 2,
                y: currentY,
                width: logoSize,
                height: logoSize
            )
            UIGraphicsPushContext(cgContext)
            logo.draw(in: logoRect)
            UIGraphicsPopContext()
            currentY += logoSize + 40
        }

        // Draw closing quote
        let quoteAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.bodyItalic(),
            .foregroundColor: PDFStyleConfiguration.Colors.textMuted,
            .paragraphStyle: PDFStyleConfiguration.paragraphStyle(lineHeight: 20, alignment: .center, paragraphSpacing: 8)
        ]

        let quote = "Where the weight of understanding\nbecomes the clarity to act."
        let quoteText = NSAttributedString(string: quote, attributes: quoteAttributes)
        let quoteRect = CGRect(x: 100, y: currentY, width: pageSize.width - 200, height: 60)
        quoteText.draw(in: quoteRect)

        currentY += 80

        // Draw brand name
        let brandAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.displayH2(),
            .foregroundColor: PDFStyleConfiguration.Colors.primaryGold,
            .paragraphStyle: PDFStyleConfiguration.paragraphStyle(lineHeight: 28, alignment: .center, paragraphSpacing: 4)
        ]
        let brandText = NSAttributedString(string: "Insight Atlas", attributes: brandAttributes)
        let brandRect = CGRect(x: 100, y: currentY, width: pageSize.width - 200, height: 40)
        brandText.draw(in: brandRect)

        currentY += 50

        // Draw tagline
        let taglineAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.caption(),
            .foregroundColor: PDFStyleConfiguration.Colors.accentCrimson,
            .paragraphStyle: PDFStyleConfiguration.paragraphStyle(lineHeight: 12, alignment: .center, paragraphSpacing: 0),
            .kern: 2.0
        ]
        let taglineText = NSAttributedString(string: "WHERE UNDERSTANDING ILLUMINATES THE WORLD", attributes: taglineAttributes)
        let taglineRect = CGRect(x: 100, y: currentY, width: pageSize.width - 200, height: 20)
        taglineText.draw(in: taglineRect)

        // Draw generation info at bottom
        let infoAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.caption(),
            .foregroundColor: PDFStyleConfiguration.Colors.textSubtle,
            .paragraphStyle: PDFStyleConfiguration.paragraphStyle(lineHeight: 12, alignment: .center, paragraphSpacing: 4)
        ]

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        let dateString = dateFormatter.string(from: Date())

        let infoText = NSAttributedString(string: "Generated on \(dateString)", attributes: infoAttributes)
        let infoRect = CGRect(x: 100, y: pageSize.height - 100, width: pageSize.width - 200, height: 20)
        infoText.draw(in: infoRect)
    }

    // MARK: - Header and Footer

    private func drawPageHeader(context: CGContext, pageNumber: Int) {
        guard pageNumber > 2 else { return } // Skip header on cover and TOC

        let headerY: CGFloat = 36
        let headerHeight: CGFloat = 24

        // Draw thin line
        context.setStrokeColor(PDFStyleConfiguration.Colors.borderLight.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: contentRect.minX, y: headerY + headerHeight))
        context.addLine(to: CGPoint(x: contentRect.maxX, y: headerY + headerHeight))
        context.strokePath()

        // Draw "Insight Atlas" text
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.caption(),
            .foregroundColor: PDFStyleConfiguration.Colors.textSubtle,
            .kern: 1.0
        ]
        let headerText = NSAttributedString(string: "INSIGHT ATLAS", attributes: headerAttributes)
        let headerRect = CGRect(x: contentRect.minX, y: headerY, width: 100, height: headerHeight)
        headerText.draw(in: headerRect)
    }

    private func drawPageFooter(context: CGContext, pageNumber: Int, includePageNumber: Bool) {
        guard pageNumber > 1 else { return } // Skip footer on cover

        // Reduced footer height: moved from 48pt to 36pt offset
        let footerY = pageSize.height - 36
        let footerHeight: CGFloat = 16

        // Draw thin line closer to page number
        context.setStrokeColor(PDFStyleConfiguration.Colors.borderLight.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: contentRect.minX, y: footerY - 6))
        context.addLine(to: CGPoint(x: contentRect.maxX, y: footerY - 6))
        context.strokePath()

        if includePageNumber {
            // Draw page number centered
            let pageAttributes: [NSAttributedString.Key: Any] = [
                .font: PDFStyleConfiguration.Typography.pageNumber(),
                .foregroundColor: PDFStyleConfiguration.Colors.textMuted,
                .paragraphStyle: PDFStyleConfiguration.paragraphStyle(lineHeight: 14, alignment: .center, paragraphSpacing: 0)
            ]
            let pageText = NSAttributedString(string: "\(pageNumber)", attributes: pageAttributes)
            let pageRect = CGRect(x: 0, y: footerY, width: pageSize.width, height: footerHeight)
            pageText.draw(in: pageRect)
        }
    }

    // MARK: - Table of Contents Builder

    private func buildTableOfContents(document: PDFAnalysisDocument, options: RenderOptions) {
        tableOfContents = []
        var estimatedPage = options.includeCoverPage ? 2 : 1
        if options.includeTableOfContents { estimatedPage += 1 }

        var currentY = contentRect.minY
        let minContentAfterHeading: CGFloat = 100 // Minimum content to keep with heading

        // Quick Glance - use safe optional binding to avoid force unwrap
        if let quickGlance = document.quickGlance {
            tableOfContents.append((title: "Quick Glance", page: estimatedPage, isSubsection: false))

            let block = PDFContentBlock(
                type: .quickGlance,
                content: quickGlance.coreMessage,
                listItems: quickGlance.keyPoints
            )
            currentY += blockRenderer.calculateBlockHeight(block: block, maxWidth: contentRect.width)

            if currentY > contentRect.maxY {
                estimatedPage += 1
                currentY = contentRect.minY
            }
        }

        // Sections
        for section in document.sections {
            if let heading = section.heading {
                // Use the section heading height calculator which handles PART headers
                let headingHeight = blockRenderer.calculateSectionHeadingHeight(heading, level: section.headingLevel, maxWidth: contentRect.width)

                // Calculate first block height to ensure we don't orphan headings
                let firstBlockHeight = section.blocks.first.map { blockRenderer.calculateBlockHeight(block: $0, maxWidth: contentRect.width) } ?? 0
                let combinedHeight = headingHeight + min(firstBlockHeight, minContentAfterHeading)

                if currentY + combinedHeight > contentRect.maxY - 50 {
                    estimatedPage += 1
                    currentY = contentRect.minY
                }

                // Determine if this is a main section or subsection
                // PART headers and main titled sections are not subsections
                let isPARTHeader = heading.uppercased().hasPrefix("PART ")
                let isMainSection = section.headingLevel == 1 || isPARTHeader

                tableOfContents.append((title: heading, page: estimatedPage, isSubsection: !isMainSection))
                currentY += headingHeight
            }

            // Estimate block heights for pagination and add special blocks to TOC
            for block in section.blocks {
                let blockHeight = blockRenderer.calculateBlockHeight(block: block, maxWidth: contentRect.width)

                if currentY + blockHeight > contentRect.maxY {
                    estimatedPage += 1
                    currentY = contentRect.minY
                }

                // Track special block types for TOC
                switch block.type {
                case .heading3:
                    // Add H3 subheadings to TOC
                    tableOfContents.append((title: block.content, page: estimatedPage, isSubsection: true))

                case .foundationalNarrative:
                    // Add "The Story Behind the Ideas" to TOC
                    let title = block.metadata?["title"] ?? "The Story Behind the Ideas"
                    if !tableOfContents.contains(where: { $0.title == title }) {
                        tableOfContents.append((title: title, page: estimatedPage, isSubsection: false))
                    }

                case .keyTakeaways:
                    // Add Key Takeaways to TOC (but avoid duplicates)
                    if !tableOfContents.contains(where: { $0.title == "Key Takeaways" }) {
                        tableOfContents.append((title: "Key Takeaways", page: estimatedPage, isSubsection: false))
                    }

                case .heading2:
                    // Ensure H2 headings are captured (Comparative Analysis, Synthesis Arc, etc.)
                    let headingTitle = block.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !headingTitle.isEmpty && !tableOfContents.contains(where: { $0.title == headingTitle }) {
                        tableOfContents.append((title: headingTitle, page: estimatedPage, isSubsection: true))
                    }

                default:
                    break
                }

                currentY += blockHeight
            }
        }
    }
}

// MARK: - Convenience Extensions

extension InsightAtlasPDFRenderer {

    /// Generate PDF from a ThematicSynthesisResponse (JSON output from thematic synthesis prompt)
    /// This is the preferred path for thematic synthesis output.
    func render(
        thematicSynthesis: ThematicSynthesisResponse,
        options: RenderOptions = .default
    ) throws -> RenderResult {
        let document = thematicSynthesis.toPDFAnalysisDocument()
        return try render(document: document, options: options)
    }

    /// Generate PDF data from a ThematicSynthesisResponse
    func generatePDFData(
        from thematicSynthesis: ThematicSynthesisResponse,
        options: RenderOptions = .default
    ) throws -> Data {
        let result = try render(thematicSynthesis: thematicSynthesis, options: options)
        return result.pdfData
    }

    /// Generate PDF and save to URL from ThematicSynthesisResponse
    func generatePDF(
        from thematicSynthesis: ThematicSynthesisResponse,
        to url: URL,
        options: RenderOptions = .default
    ) throws {
        let result = try render(thematicSynthesis: thematicSynthesis, options: options)
        try result.pdfData.write(to: url)
    }

    /// Generate PDF and save to URL (legacy path using raw content)
    ///
    /// - Warning: This method uses raw content parsing. For new implementations,
    ///   prefer `generatePDFData(from:title:author:)` with pre-parsed content
    ///   or use `render(document:)` with a normalized `EditorialDocument`.
    ///
    /// GOVERNANCE LOCK: This path is maintained for legacy compatibility only.
    func generatePDF(
        from content: String,
        title: String,
        author: String,
        to url: URL,
        options: RenderOptions = .default
    ) throws {
        let result = try render(markdownContent: content, title: title, author: author, options: options)
        try result.pdfData.write(to: url)
    }

    /// Generate PDF data directly from ParsedAnalysisContent (preferred path)
    ///
    /// This is the recommended production path as it uses pre-parsed content
    /// that has gone through semantic normalization.
    func generatePDFData(
        from parsedContent: ParsedAnalysisContent,
        title: String,
        author: String,
        options: RenderOptions = .default
    ) throws -> Data {
        let document = PDFAnalysisDocument.from(parsedContent: parsedContent, title: title, author: author)
        let result = try render(document: document, options: options)
        return result.pdfData
    }
}
