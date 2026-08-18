import UIKit
import UIKit
import CoreGraphics

// MARK: - PDF Cover Page Renderer
// Creates the scholarly cover page with logo, title, author, and branding

final class PDFCoverPageRenderer {

    // MARK: - Properties

    private let style = PDFStyleConfiguration.self
    private let pageSize: CGSize

    // MARK: - Initialization

    init(pageSize: CGSize = PDFStyleConfiguration.PageLayout.pageSize) {
        self.pageSize = pageSize
    }

    // MARK: - Main Render Method

    /// Render the cover page to a PDF context
    /// - Parameters:
    ///   - context: The Core Graphics context to render to
    ///   - title: Book title
    ///   - author: Book author
    ///   - logoImage: Optional logo image (uses default if nil)
    func render(
        to context: CGContext,
        title: String,
        author: String,
        logoImage: UIImage? = nil
    ) {
        // Fill background with parchment color
        context.setFillColor(PDFStyleConfiguration.Colors.bgPrimary.cgColor)
        context.fill(CGRect(origin: .zero, size: pageSize))

        // Draw decorative border
        drawDecorativeBorder(context: context)

        // Draw top tagline
        drawTopTagline(context: context)

        // Draw logo/illustration
        drawLogo(context: context, image: logoImage)

        // Draw title and author
        drawTitleBlock(context: context, title: title, author: author)

        // Draw bottom tagline and branding
        drawBottomBranding(context: context)

        // Draw decorative corner elements
        drawCornerDecorations(context: context)
    }

    // MARK: - Private Drawing Methods

    private func drawDecorativeBorder(context: CGContext) {
        let inset: CGFloat = 36 // 0.5 inch from edge
        let borderRect = CGRect(
            x: inset,
            y: inset,
            width: pageSize.width - (inset * 2),
            height: pageSize.height - (inset * 2)
        )

        // Outer border - thin gold line
        context.setStrokeColor(PDFStyleConfiguration.Colors.primaryGold.cgColor)
        context.setLineWidth(1.0)
        context.stroke(borderRect)

        // Inner border - double line effect
        let innerInset: CGFloat = 4
        let innerRect = borderRect.insetBy(dx: innerInset, dy: innerInset)
        context.setStrokeColor(PDFStyleConfiguration.Colors.primaryGold.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(0.5)
        context.stroke(innerRect)
    }

    private func drawTopTagline(context: CGContext) {
        let tagline = PDFStyleConfiguration.CoverPage.taglineTop
        let y = PDFStyleConfiguration.CoverPage.topTaglineY

        let attributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.bodySmall(),
            .ligature: 0,
            .foregroundColor: PDFStyleConfiguration.Colors.accentCrimson,
            .paragraphStyle: PDFStyleConfiguration.paragraphStyle(
                lineHeight: 14,
                alignment: .center,
                paragraphSpacing: 0
            ),
            .kern: 2.0 // Letter spacing for elegance
        ]

        let attributedString = NSAttributedString(string: tagline.uppercased(), attributes: attributes)
        let textSize = attributedString.size()
        let textRect = CGRect(
            x: (pageSize.width - textSize.width) / 2,
            y: y,
            width: textSize.width,
            height: textSize.height
        )

        attributedString.draw(in: textRect)

        // Draw decorative line under tagline
        let lineY = y + textSize.height + 8
        let lineWidth: CGFloat = 100
        let lineX = (pageSize.width - lineWidth) / 2

        context.setStrokeColor(PDFStyleConfiguration.Colors.primaryGold.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: lineX, y: lineY))
        context.addLine(to: CGPoint(x: lineX + lineWidth, y: lineY))
        context.strokePath()
    }

    private func drawLogo(context: CGContext, image: UIImage?) {
        let logo = image ?? UIImage(named: "Logo")

        guard let logoImage = logo else {
            // Draw placeholder if no logo
            drawLogoPlaceholder(context: context)
            return
        }

        let maxWidth = PDFStyleConfiguration.CoverPage.logoMaxWidth
        let maxHeight = PDFStyleConfiguration.CoverPage.logoMaxHeight
        let topOffset = PDFStyleConfiguration.CoverPage.logoTopOffset

        // Calculate aspect-fit dimensions
        let imageSize = logoImage.size
        let widthRatio = maxWidth / imageSize.width
        let heightRatio = maxHeight / imageSize.height
        let scale = min(widthRatio, heightRatio)

        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale

        let logoRect = CGRect(
            x: (pageSize.width - scaledWidth) / 2,
            y: topOffset,
            width: scaledWidth,
            height: scaledHeight
        )

        // Draw the logo image
        UIGraphicsPushContext(context)
        logoImage.draw(in: logoRect)
        UIGraphicsPopContext()
    }

    private func drawLogoPlaceholder(context: CGContext) {
        // Draw a decorative circular placeholder if no logo is available
        let centerX = pageSize.width / 2
        let centerY = PDFStyleConfiguration.CoverPage.logoTopOffset + 150
        let radius: CGFloat = 100

        // Draw circle
        context.setStrokeColor(PDFStyleConfiguration.Colors.primaryGold.cgColor)
        context.setLineWidth(2.0)
        context.addArc(
            center: CGPoint(x: centerX, y: centerY),
            radius: radius,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: true
        )
        context.strokePath()

        // Draw inner circle
        context.setLineWidth(1.0)
        context.addArc(
            center: CGPoint(x: centerX, y: centerY),
            radius: radius - 10,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: true
        )
        context.strokePath()

        // Draw "IA" monogram in center
        let monogramAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.displayTitle(),
            .ligature: 0,
            .foregroundColor: PDFStyleConfiguration.Colors.primaryGold
        ]
        let monogram = NSAttributedString(string: "IA", attributes: monogramAttributes)
        let monogramSize = monogram.size()
        let monogramRect = CGRect(
            x: centerX - monogramSize.width / 2,
            y: centerY - monogramSize.height / 2,
            width: monogramSize.width,
            height: monogramSize.height
        )
        monogram.draw(in: monogramRect)
    }

    private func drawTitleBlock(context: CGContext, title rawTitle: String, author: String) {
        let titleY = PDFStyleConfiguration.CoverPage.titleTopOffset
        let maxWidth = pageSize.width - 100 // 50pt margins on each side

        // Collapse stray runs of whitespace so the cover title never shows the
        // double-space kerning bug (Directives §C5, e.g. "Cognitive  Defusion").
        let title = rawTitle
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Draw title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.displayTitle(),
            .ligature: 0,
            .foregroundColor: PDFStyleConfiguration.Colors.textHeading,
            .paragraphStyle: PDFStyleConfiguration.paragraphStyle(
                lineHeight: 38,
                alignment: .center,
                paragraphSpacing: 8
            )
        ]

        let titleAttributed = NSAttributedString(string: title, attributes: titleAttributes)
        let titleSize = titleAttributed.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let titleRect = CGRect(
            x: (pageSize.width - maxWidth) / 2,
            y: titleY,
            width: maxWidth,
            height: titleSize.height
        )
        titleAttributed.draw(in: titleRect)

        // Draw "by" label
        let byAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.bodyItalic(),
            .ligature: 0,
            .foregroundColor: PDFStyleConfiguration.Colors.textMuted,
            .paragraphStyle: PDFStyleConfiguration.paragraphStyle(
                lineHeight: 16,
                alignment: .center,
                paragraphSpacing: 4
            )
        ]
        let byText = NSAttributedString(string: "by", attributes: byAttributes)
        let bySize = byText.size()
        let actualAuthorY = titleY + titleSize.height + 16
        let byRect = CGRect(
            x: (pageSize.width - bySize.width) / 2,
            y: actualAuthorY,
            width: bySize.width,
            height: bySize.height
        )
        byText.draw(in: byRect)

        // Draw author name
        let authorAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.displayH3(),
            .ligature: 0,
            .foregroundColor: PDFStyleConfiguration.Colors.textBody,
            .paragraphStyle: PDFStyleConfiguration.paragraphStyle(
                lineHeight: 24,
                alignment: .center,
                paragraphSpacing: 0
            )
        ]
        let authorAttributed = NSAttributedString(string: author, attributes: authorAttributes)
        let authorSize = authorAttributed.size()
        let authorRect = CGRect(
            x: (pageSize.width - authorSize.width) / 2,
            y: actualAuthorY + bySize.height + 4,
            width: authorSize.width,
            height: authorSize.height
        )
        authorAttributed.draw(in: authorRect)

        // Draw decorative line under author
        let lineY = authorRect.maxY + 20
        let lineWidth: CGFloat = 60
        let lineX = (pageSize.width - lineWidth) / 2

        context.setStrokeColor(PDFStyleConfiguration.Colors.primaryGold.cgColor)
        context.setLineWidth(1.0)
        context.move(to: CGPoint(x: lineX, y: lineY))
        context.addLine(to: CGPoint(x: lineX + lineWidth, y: lineY))
        context.strokePath()
    }

    private func drawBottomBranding(context: CGContext) {
        let y = PDFStyleConfiguration.CoverPage.bottomTaglineY

        // Draw "Insight Atlas" brand name
        let brandAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.displayH2(),
            .ligature: 0,
            .foregroundColor: PDFStyleConfiguration.Colors.primaryGold,
            .paragraphStyle: PDFStyleConfiguration.paragraphStyle(
                lineHeight: 28,
                alignment: .center,
                paragraphSpacing: 4
            )
        ]
        let brandText = NSAttributedString(string: PDFStyleConfiguration.CoverPage.taglineBottom, attributes: brandAttributes)
        let brandSize = brandText.size()
        let brandRect = CGRect(
            x: (pageSize.width - brandSize.width) / 2,
            y: y,
            width: brandSize.width,
            height: brandSize.height
        )
        brandText.draw(in: brandRect)

        // Draw subtitle
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.bodySmall(),
            .ligature: 0,
            .foregroundColor: PDFStyleConfiguration.Colors.textMuted,
            .paragraphStyle: PDFStyleConfiguration.paragraphStyle(
                lineHeight: 14,
                alignment: .center,
                paragraphSpacing: 0
            ),
            .kern: 1.5
        ]
        let subtitleText = NSAttributedString(
            string: PDFStyleConfiguration.CoverPage.brandSubtitle.uppercased(),
            attributes: subtitleAttributes
        )
        let subtitleSize = subtitleText.size()
        let subtitleRect = CGRect(
            x: (pageSize.width - subtitleSize.width) / 2,
            y: y + brandSize.height + 4,
            width: subtitleSize.width,
            height: subtitleSize.height
        )
        subtitleText.draw(in: subtitleRect)
    }

    private func drawCornerDecorations(context: CGContext) {
        let cornerSize: CGFloat = 20
        let inset: CGFloat = 44 // Just inside the border

        context.setStrokeColor(PDFStyleConfiguration.Colors.primaryGold.cgColor)
        context.setLineWidth(1.0)

        // Top-left corner
        drawCornerMark(context: context, x: inset, y: inset, size: cornerSize, corner: .topLeft)

        // Top-right corner
        drawCornerMark(context: context, x: pageSize.width - inset, y: inset, size: cornerSize, corner: .topRight)

        // Bottom-left corner
        drawCornerMark(context: context, x: inset, y: pageSize.height - inset, size: cornerSize, corner: .bottomLeft)

        // Bottom-right corner
        drawCornerMark(context: context, x: pageSize.width - inset, y: pageSize.height - inset, size: cornerSize, corner: .bottomRight)
    }

    private enum Corner {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    private func drawCornerMark(context: CGContext, x: CGFloat, y: CGFloat, size: CGFloat, corner: Corner) {
        context.saveGState()

        switch corner {
        case .topLeft:
            context.move(to: CGPoint(x: x, y: y + size))
            context.addLine(to: CGPoint(x: x, y: y))
            context.addLine(to: CGPoint(x: x + size, y: y))
        case .topRight:
            context.move(to: CGPoint(x: x - size, y: y))
            context.addLine(to: CGPoint(x: x, y: y))
            context.addLine(to: CGPoint(x: x, y: y + size))
        case .bottomLeft:
            context.move(to: CGPoint(x: x, y: y - size))
            context.addLine(to: CGPoint(x: x, y: y))
            context.addLine(to: CGPoint(x: x + size, y: y))
        case .bottomRight:
            context.move(to: CGPoint(x: x - size, y: y))
            context.addLine(to: CGPoint(x: x, y: y))
            context.addLine(to: CGPoint(x: x, y: y - size))
        }

        context.strokePath()
        context.restoreGState()
    }
}

// MARK: - Cover Page with Table of Contents

extension PDFCoverPageRenderer {

    /// Render a table of contents page with pagination support
    /// - Parameters:
    ///   - context: The Core Graphics context
    ///   - sections: Array of (title, pageNumber, isSubsection) tuples
    ///   - pdfRenderer: The UIGraphicsPDFRendererContext for creating new pages
    /// Returns the number of TOC pages rendered
    @discardableResult
    func renderTableOfContents(
        to context: CGContext,
        sections: [(title: String, page: Int, isSubsection: Bool)],
        pdfRenderer: UIGraphicsPDFRendererContext? = nil
    ) -> Int {
        let marginLeft = PDFStyleConfiguration.PageLayout.marginLeft
        let marginRight = PDFStyleConfiguration.PageLayout.marginRight
        let marginBottom = PDFStyleConfiguration.PageLayout.marginBottom
        let contentWidth = pageSize.width - marginLeft - marginRight
        let maxY = pageSize.height - marginBottom - 40 // Leave room for page footer

        var currentY: CGFloat = 100
        var pageCount = 1

        // Helper to start a new TOC page
        func startNewPage() {
            if let renderer = pdfRenderer {
                renderer.beginPage()
            }
            // Fill background
            context.setFillColor(PDFStyleConfiguration.Colors.bgPrimary.cgColor)
            context.fill(CGRect(origin: .zero, size: pageSize))
            pageCount += 1
            currentY = PDFStyleConfiguration.PageLayout.marginTop
        }

        // Helper to draw header on first page
        func drawHeader() {
            // Fill background
            context.setFillColor(PDFStyleConfiguration.Colors.bgPrimary.cgColor)
            context.fill(CGRect(origin: .zero, size: pageSize))

            // Draw "Contents" header
            let headerAttributes: [NSAttributedString.Key: Any] = [
                .font: PDFStyleConfiguration.Typography.displayH1(),
                .ligature: 0,
                .foregroundColor: PDFStyleConfiguration.Colors.textHeading,
                .paragraphStyle: PDFStyleConfiguration.paragraphStyle(
                    lineHeight: 32,
                    alignment: .left,
                    paragraphSpacing: 8
                )
            ]
            let headerText = NSAttributedString(string: "Contents", attributes: headerAttributes)
            let headerRect = CGRect(x: marginLeft, y: currentY, width: contentWidth, height: 40)
            headerText.draw(in: headerRect)

            currentY += 50

            // Draw decorative line
            context.setStrokeColor(PDFStyleConfiguration.Colors.primaryGold.cgColor)
            context.setLineWidth(2.0)
            context.move(to: CGPoint(x: marginLeft, y: currentY))
            context.addLine(to: CGPoint(x: marginLeft + 60, y: currentY))
            context.strokePath()

            currentY += 30
        }

        // Draw header on first page
        drawHeader()

        // Draw TOC entries with improved leader lines
        for (title, page, isSubsection) in sections {
            let indent: CGFloat = isSubsection ? 24 : 0  // Increased indent for clearer hierarchy
            let font = isSubsection ? PDFStyleConfiguration.Typography.body() : PDFStyleConfiguration.Typography.bodyBold()
            let color = isSubsection ? PDFStyleConfiguration.Colors.textBody : PDFStyleConfiguration.Colors.textHeading
            let pageNumberWidth: CGFloat = 30
            let maxTitleWidth = contentWidth - indent - pageNumberWidth - 24

            // Title wraps to as many lines as needed so long headings are never clipped
            let titleParagraph = NSMutableParagraphStyle()
            titleParagraph.lineBreakMode = .byWordWrapping
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .ligature: 0,
                .foregroundColor: color,
                .paragraphStyle: titleParagraph
            ]
            let titleText = NSAttributedString(string: title, attributes: titleAttributes)

            let pageText = NSAttributedString(string: "\(page)", attributes: [
                .font: PDFStyleConfiguration.Typography.body(),
                .ligature: 0,
                .foregroundColor: PDFStyleConfiguration.Colors.textMuted
            ])
            let lineHeight = pageText.size().height

            // Measure the wrapped title so the row can grow to fit it
            let titleBounds = titleText.boundingRect(
                with: CGSize(width: maxTitleWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            let titleHeight = max(ceil(titleBounds.height), lineHeight)
            let rowPadding: CGFloat = isSubsection ? 8 : 10
            let entryHeight = titleHeight + rowPadding

            // Page break using the actual (possibly multi-line) height
            if currentY + entryHeight > maxY {
                startNewPage()
            }

            // Draw the wrapped title
            let titleRect = CGRect(x: marginLeft + indent, y: currentY, width: maxTitleWidth, height: titleHeight)
            titleText.draw(with: titleRect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)

            let firstLineCenterY = currentY + lineHeight / 2

            // Dotted leader — only for single-line entries (a leader mid-wrap looks broken)
            let isSingleLine = titleHeight <= lineHeight + 1
            if isSingleLine {
                let leaderStartX = marginLeft + indent + min(ceil(titleBounds.width), maxTitleWidth) + 8
                let leaderEndX = self.pageSize.width - marginRight - pageNumberWidth - 4
                if leaderEndX > leaderStartX + 10 {
                    context.setStrokeColor(PDFStyleConfiguration.Colors.borderMedium.cgColor)
                    context.setLineWidth(0.5)
                    context.setLineDash(phase: 0, lengths: [2, 4])
                    context.move(to: CGPoint(x: leaderStartX, y: firstLineCenterY))
                    context.addLine(to: CGPoint(x: leaderEndX, y: firstLineCenterY))
                    context.strokePath()
                    context.setLineDash(phase: 0, lengths: [])
                }
            }

            // Page number — right-aligned on the first line of the entry
            let rightAlignedPageStyle = NSMutableParagraphStyle()
            rightAlignedPageStyle.alignment = .right
            let rightAlignedPageText = NSAttributedString(string: "\(page)", attributes: [
                .font: PDFStyleConfiguration.Typography.body(),
                .ligature: 0,
                .foregroundColor: PDFStyleConfiguration.Colors.textMuted,
                .paragraphStyle: rightAlignedPageStyle
            ])
            let pageRect = CGRect(
                x: self.pageSize.width - marginRight - pageNumberWidth,
                y: currentY,
                width: pageNumberWidth,
                height: lineHeight
            )
            rightAlignedPageText.draw(in: pageRect)

            currentY += entryHeight
        }

        return pageCount
    }
}
