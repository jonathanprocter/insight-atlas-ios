import UIKit
import CoreGraphics
import CoreText

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
        drawTitleBlock(
            context: context,
            title: PDFStyleConfiguration.smartTypography(title),
            author: Self.displayAuthorName(author)
        )

        // Draw bottom tagline and branding
        drawBottomBranding(context: context)

        // Draw decorative corner elements
        drawCornerDecorations(context: context)
    }

    // MARK: - Author Formatting

    /// Convert catalog-style "Last, First [Middle]" author names to display order
    /// ("First Middle Last"). Names that don't clearly match that shape are
    /// returned unchanged.
    static func displayAuthorName(_ author: String) -> String {
        let trimmed = author.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.components(separatedBy: ",")
        guard parts.count == 2 else { return trimmed }

        let lastName = parts[0].trimmingCharacters(in: .whitespaces)
        let firstNames = parts[1].trimmingCharacters(in: .whitespaces)

        let looksLikeSuffix = ["jr", "jr.", "sr", "sr.", "ii", "iii", "iv", "phd", "ph.d.", "md", "m.d."]
            .contains(firstNames.lowercased())

        guard !lastName.isEmpty, !firstNames.isEmpty,
              !looksLikeSuffix,
              !trimmed.lowercased().contains(" and "),
              !trimmed.contains("&"),
              firstNames.components(separatedBy: " ").count <= 3
        else { return trimmed }

        return "\(firstNames) \(lastName)"
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

    private func drawTitleBlock(context: CGContext, title: String, author: String) {
        let titleY = PDFStyleConfiguration.CoverPage.titleTopOffset
        let maxWidth = pageSize.width - 100 // 50pt margins on each side

        // Draw title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.displayTitle(),
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

    /// Layout constants shared by TOC rendering and page-count estimation.
    /// Keep these two paths in sync so estimated page counts always match
    /// what actually gets drawn.
    private enum TOCLayout {
        static let pageNumberWidth: CGFloat = 30
        static let titleTrailingGap: CGFloat = 24
        static let firstPageTopY: CGFloat = 100
        static let headerBlockHeight: CGFloat = 80  // "Contents" heading + rule + spacing
        static let entryVerticalPadding: CGFloat = 9
        static let subsectionIndent: CGFloat = 24

        static func minEntryHeight(isSubsection: Bool) -> CGFloat {
            isSubsection ? 24 : 28
        }
    }

    private func tocEntryFont(isSubsection: Bool) -> UIFont {
        isSubsection ? PDFStyleConfiguration.Typography.body() : PDFStyleConfiguration.Typography.bodyBold()
    }

    private func tocTitleAttributes(isSubsection: Bool) -> [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        return [
            .font: tocEntryFont(isSubsection: isSubsection),
            .foregroundColor: isSubsection ? PDFStyleConfiguration.Colors.textBody : PDFStyleConfiguration.Colors.textHeading,
            .paragraphStyle: style
        ]
    }

    private func tocMaxTitleWidth(isSubsection: Bool) -> CGFloat {
        let marginLeft = PDFStyleConfiguration.PageLayout.marginLeft
        let marginRight = PDFStyleConfiguration.PageLayout.marginRight
        let contentWidth = pageSize.width - marginLeft - marginRight
        let indent = isSubsection ? TOCLayout.subsectionIndent : 0
        return contentWidth - indent - TOCLayout.pageNumberWidth - TOCLayout.titleTrailingGap
    }

    /// Wrapped title height and total row height for one TOC entry
    private func tocEntryMetrics(title: String, isSubsection: Bool) -> (rowHeight: CGFloat, titleHeight: CGFloat) {
        let attributed = NSAttributedString(string: title, attributes: tocTitleAttributes(isSubsection: isSubsection))
        let bounding = attributed.boundingRect(
            with: CGSize(width: tocMaxTitleWidth(isSubsection: isSubsection), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let titleHeight = ceil(bounding.height)
        let rowHeight = max(TOCLayout.minEntryHeight(isSubsection: isSubsection), titleHeight + TOCLayout.entryVerticalPadding)
        return (rowHeight, titleHeight)
    }

    /// Width of the last rendered line of a wrapped title, used to start the
    /// dotted leader after the text ends.
    private func tocLastLineWidth(of attributed: NSAttributedString, maxWidth: CGFloat) -> CGFloat {
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let path = CGPath(rect: CGRect(x: 0, y: 0, width: maxWidth, height: 10_000), transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)
        let lines = CTFrameGetLines(frame)
        let lineCount = CFArrayGetCount(lines)
        guard lineCount > 0 else {
            return min(ceil(attributed.size().width), maxWidth)
        }
        let lastLine = unsafeBitCast(CFArrayGetValueAtIndex(lines, lineCount - 1), to: CTLine.self)
        return min(ceil(CGFloat(CTLineGetTypographicBounds(lastLine, nil, nil, nil))), maxWidth)
    }

    /// Number of pages the table of contents will occupy for the given entries.
    /// Mirrors the pagination in `renderTableOfContents` exactly.
    func tableOfContentsPageCount(sections: [(title: String, page: Int, isSubsection: Bool)]) -> Int {
        let maxY = pageSize.height - PDFStyleConfiguration.PageLayout.marginBottom - 40
        var currentY = TOCLayout.firstPageTopY + TOCLayout.headerBlockHeight
        var pageCount = 1

        for entry in sections {
            let title = PDFStyleConfiguration.smartTypography(entry.title)
            let rowHeight = tocEntryMetrics(title: title, isSubsection: entry.isSubsection).rowHeight
            if currentY + rowHeight > maxY {
                pageCount += 1
                currentY = PDFStyleConfiguration.PageLayout.marginTop
            }
            currentY += rowHeight
        }

        return pageCount
    }

    /// Render the table of contents with pagination support
    /// - Parameters:
    ///   - context: The Core Graphics context
    ///   - sections: Array of (title, pageNumber, isSubsection) tuples
    ///   - pdfRenderer: The UIGraphicsPDFRendererContext used to begin
    ///     additional pages when entries overflow. Without it, overflowing
    ///     entries are truncated (never drawn over already-rendered ones).
    /// - Returns: the number of TOC pages rendered
    @discardableResult
    func renderTableOfContents(
        to context: CGContext,
        sections: [(title: String, page: Int, isSubsection: Bool)],
        pdfRenderer: UIGraphicsPDFRendererContext? = nil
    ) -> Int {
        let marginLeft = PDFStyleConfiguration.PageLayout.marginLeft
        let marginRight = PDFStyleConfiguration.PageLayout.marginRight
        let maxY = pageSize.height - PDFStyleConfiguration.PageLayout.marginBottom - 40 // Leave room for page footer

        var currentY = TOCLayout.firstPageTopY
        var pageCount = 1

        func fillBackground() {
            context.setFillColor(PDFStyleConfiguration.Colors.bgPrimary.cgColor)
            context.fill(CGRect(origin: .zero, size: pageSize))
        }

        // First page: background plus "Contents" header
        fillBackground()

        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.displayH1(),
            .foregroundColor: PDFStyleConfiguration.Colors.textHeading,
            .paragraphStyle: PDFStyleConfiguration.paragraphStyle(
                lineHeight: 32,
                alignment: .left,
                paragraphSpacing: 8
            )
        ]
        let headerText = NSAttributedString(string: "Contents", attributes: headerAttributes)
        let contentWidth = pageSize.width - marginLeft - marginRight
        headerText.draw(in: CGRect(x: marginLeft, y: currentY, width: contentWidth, height: 40))

        currentY += 50

        context.setStrokeColor(PDFStyleConfiguration.Colors.primaryGold.cgColor)
        context.setLineWidth(2.0)
        context.move(to: CGPoint(x: marginLeft, y: currentY))
        context.addLine(to: CGPoint(x: marginLeft + 60, y: currentY))
        context.strokePath()

        currentY += 30

        // Draw TOC entries
        for (rawTitle, page, isSubsection) in sections {
            let title = PDFStyleConfiguration.smartTypography(rawTitle)
            let metrics = tocEntryMetrics(title: title, isSubsection: isSubsection)

            // Page break when the next entry doesn't fit
            if currentY + metrics.rowHeight > maxY {
                guard let renderer = pdfRenderer else {
                    // No renderer context to begin a new page with — stop
                    // rather than painting over entries already drawn.
                    break
                }
                renderer.beginPage()
                fillBackground()
                pageCount += 1
                currentY = PDFStyleConfiguration.PageLayout.marginTop
            }

            let indent: CGFloat = isSubsection ? TOCLayout.subsectionIndent : 0
            let maxTitleWidth = tocMaxTitleWidth(isSubsection: isSubsection)
            let titleAttributes = tocTitleAttributes(isSubsection: isSubsection)
            let titleText = NSAttributedString(string: title, attributes: titleAttributes)

            // Draw title (wraps onto multiple lines when needed)
            let titleRect = CGRect(
                x: marginLeft + indent,
                y: currentY,
                width: maxTitleWidth,
                height: metrics.titleHeight
            )
            titleText.draw(in: titleRect)

            // Align leader dots and page number with the last line of the title
            let font = tocEntryFont(isSubsection: isSubsection)
            let lineHeight = ceil(font.lineHeight)
            let lastLineTop = currentY + max(0, metrics.titleHeight - lineHeight)
            let lastLineWidth = tocLastLineWidth(of: titleText, maxWidth: maxTitleWidth)

            // Dotted leader line - 2pt dots with 4pt gaps
            let leaderStartX = marginLeft + indent + lastLineWidth + 8
            let leaderEndX = pageSize.width - marginRight - TOCLayout.pageNumberWidth - 4
            let leaderY = lastLineTop + lineHeight / 2

            if leaderEndX > leaderStartX + 10 {
                context.setStrokeColor(PDFStyleConfiguration.Colors.borderMedium.cgColor)
                context.setLineWidth(0.5)
                context.setLineDash(phase: 0, lengths: [2, 4])
                context.move(to: CGPoint(x: leaderStartX, y: leaderY))
                context.addLine(to: CGPoint(x: leaderEndX, y: leaderY))
                context.strokePath()
                context.setLineDash(phase: 0, lengths: []) // Reset dash
            }

            // Page number - right-aligned on the last title line
            let pageStyle = NSMutableParagraphStyle()
            pageStyle.alignment = .right
            let pageAttributes: [NSAttributedString.Key: Any] = [
                .font: PDFStyleConfiguration.Typography.body(),
                .foregroundColor: PDFStyleConfiguration.Colors.textMuted,
                .paragraphStyle: pageStyle
            ]
            let pageText = NSAttributedString(string: "\(page)", attributes: pageAttributes)
            let pageRect = CGRect(
                x: pageSize.width - marginRight - TOCLayout.pageNumberWidth,
                y: lastLineTop,
                width: TOCLayout.pageNumberWidth,
                height: lineHeight
            )
            pageText.draw(in: pageRect)

            currentY += metrics.rowHeight
        }

        return pageCount
    }
}
