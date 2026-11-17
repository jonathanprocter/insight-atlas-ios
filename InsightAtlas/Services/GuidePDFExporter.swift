//
//  GuidePDFExporter.swift
//  Extracted from DataManager — PDF generation with no library state.
//

import Foundation
import UIKit
import PDFKit

enum GuidePDFExporter {
// MARK: - PDF Generation

/// PDF layout uses UIKit/PDFKit APIs that must run on the main actor.
/// Callers off the main thread must use `DataManager.exportGuideAsync`.
@MainActor
static func generate(content: String, title: String, author: String, to url: URL) throws {
    // Use the new InsightAtlasPDFRenderer for premium PDF generation
    let pdfRenderer = InsightAtlasPDFRenderer()

    var options = InsightAtlasPDFRenderer.RenderOptions.default
    options.includeCoverPage = true
    options.includeTableOfContents = true
    options.includePageNumbers = true
    options.includeHeader = false
    options.logoImage = ExportBrandAssets.getLogoImage()

    do {
        let parsedContent = ParsedAnalysisContent.parse(from: content)
        if !parsedContent.sections.isEmpty || parsedContent.quickGlance != nil {
            let pdfData = try pdfRenderer.generatePDFData(
                from: parsedContent,
                title: title,
                author: author,
                options: options
            )
            try pdfData.write(to: url)
        } else {
            try pdfRenderer.generatePDF(
                from: content,
                title: title,
                author: author,
                to: url,
                options: options
            )
        }
    } catch {
        // Fall back to legacy PDF generation if new renderer fails
        try generateLegacyPDF(content: content, title: title, author: author, to: url)
    }
}

/// Legacy PDF generation (fallback)
static func generateLegacyPDF(content: String, title: String, author: String, to url: URL) throws {
    let pageWidth: CGFloat = 612  // US Letter width in points
    let pageHeight: CGFloat = 792 // US Letter height in points
    let margin: CGFloat = 72      // 1 inch margins

    let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

    let attributedContent = createAttributedString(from: content, title: title, author: author, pageWidth: pageWidth - margin * 2)

    let data = pdfRenderer.pdfData { context in
        // Draw premium cover page first
        context.beginPage()
        drawPDFCoverPage(context: context.cgContext, title: title, author: author, content: content, pageWidth: pageWidth, pageHeight: pageHeight)

        let textRect = CGRect(x: margin, y: margin, width: pageWidth - margin * 2, height: pageHeight - margin * 2)

        // Calculate text layout for content pages
        let framesetter = CTFramesetterCreateWithAttributedString(attributedContent)
        var currentPosition = 0
        var pageNumber = 1  // Start at 1 since cover page is page 0

        while currentPosition < attributedContent.length {
            context.beginPage()
            pageNumber += 1

            // Draw header on first content page (page 2)
            if pageNumber == 2 {
                drawPDFHeader(context: context.cgContext, title: title, author: author, rect: textRect)
            }

            let headerOffset: CGFloat = pageNumber == 2 ? 190 : 0 // Includes logo height on first content page
            let contentRect = CGRect(x: textRect.origin.x,
                                    y: textRect.origin.y + headerOffset,
                                    width: textRect.width,
                                    height: textRect.height - headerOffset - 30) // Leave room for footer

            let path = CGPath(rect: contentRect, transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter,
                                                 CFRangeMake(currentPosition, 0),
                                                 path,
                                                 nil)

            // Draw the text
            context.cgContext.textMatrix = .identity
            context.cgContext.translateBy(x: 0, y: pageHeight)
            context.cgContext.scaleBy(x: 1.0, y: -1.0)

            CTFrameDraw(frame, context.cgContext)

            // Get the range that was drawn
            let visibleRange = CTFrameGetVisibleStringRange(frame)
            currentPosition += visibleRange.length

            // Reset transform for footer
            context.cgContext.scaleBy(x: 1.0, y: -1.0)
            context.cgContext.translateBy(x: 0, y: -pageHeight)

            // Draw page footer (showing page number minus 1 so content starts at page 1)
            drawPDFFooter(context: context.cgContext, pageNumber: pageNumber - 1, pageWidth: pageWidth, pageHeight: pageHeight)
        }
    }

    try data.write(to: url)
}

static func drawPDFHeader(context: CGContext, title: String, author: String, rect: CGRect) {
    var yOffset: CGFloat = rect.origin.y

    // Draw logo if available
    if let logo = ExportBrandAssets.getLogoImage() {
        let logoHeight: CGFloat = 60
        let logoWidth = logoHeight * (logo.size.width / logo.size.height)
        let logoRect = CGRect(x: rect.origin.x, y: yOffset, width: logoWidth, height: logoHeight)
        logo.draw(in: logoRect)
        yOffset += logoHeight + 10
    }

    // Brand text
    let brandAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
        .foregroundColor: UIColor.iaGold,
        .kern: 2
    ]
    let brandText = "INSIGHT ATLAS GUIDE"
    let brandString = NSAttributedString(string: brandText, attributes: brandAttributes)
    brandString.draw(at: CGPoint(x: rect.origin.x, y: yOffset))

    // Title
    let titleAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 28, weight: .bold),
        .foregroundColor: UIColor.iaHeading
    ]
    let titleString = NSAttributedString(string: title, attributes: titleAttributes)
    titleString.draw(at: CGPoint(x: rect.origin.x, y: yOffset + 20))

    // Author
    let authorAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.italicSystemFont(ofSize: 14),
        .foregroundColor: UIColor.iaMuted
    ]
    let authorString = NSAttributedString(string: "by \(author)", attributes: authorAttributes)
    authorString.draw(at: CGPoint(x: rect.origin.x, y: yOffset + 55))

    // Gold divider line
    context.setStrokeColor(UIColor.iaGold.cgColor)
    context.setLineWidth(2)
    context.move(to: CGPoint(x: rect.origin.x, y: yOffset + 85))
    context.addLine(to: CGPoint(x: rect.origin.x + rect.width, y: yOffset + 85))
    context.strokePath()
}

static func drawPDFFooter(context: CGContext, pageNumber: Int, pageWidth: CGFloat, pageHeight: CGFloat) {
    let footerAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 10),
        .foregroundColor: UIColor.iaMuted
    ]

    let footerText = "Insight Atlas Guide • Page \(pageNumber)"
    let footerString = NSAttributedString(string: footerText, attributes: footerAttributes)
    let footerSize = footerString.size()

    footerString.draw(at: CGPoint(x: (pageWidth - footerSize.width) / 2, y: pageHeight - 50))
}

// MARK: - Premium Cover Page

/// Extracts the Quick Glance content from the guide for the cover page
static func extractQuickGlanceForCover(from content: String) -> [String] {
    var bullets: [String] = []
    let lines = content.components(separatedBy: .newlines)
    var inQuickGlance = false

    for line in lines {
        if line.hasPrefix("[QUICK_GLANCE]") {
            inQuickGlance = true
            continue
        }
        if line.hasPrefix("[/QUICK_GLANCE]") {
            break // Only use first Quick Glance block
        }
        if inQuickGlance {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Extract bullet points (lines starting with - or •)
            if trimmed.hasPrefix("-") || trimmed.hasPrefix("•") || trimmed.hasPrefix("*") {
                var bulletText = trimmed
                bulletText.removeFirst()
                bulletText = bulletText.trimmingCharacters(in: .whitespaces)
                // Strip markdown from bullet text
                bulletText = stripMarkdownForPDF(bulletText)
                if !bulletText.isEmpty && bullets.count < 5 {
                    bullets.append(bulletText)
                }
            }
        }
    }

    return bullets
}

/// Draws decorative corner frames on the cover page
static func drawCornerFrames(context: CGContext, pageWidth: CGFloat, pageHeight: CGFloat, margin: CGFloat) {
    let cornerLength: CGFloat = 40
    let cornerInset: CGFloat = margin - 20

    context.setStrokeColor(UIColor.iaGold.cgColor)
    context.setLineWidth(2)

    // Top-left corner
    context.move(to: CGPoint(x: cornerInset, y: cornerInset + cornerLength))
    context.addLine(to: CGPoint(x: cornerInset, y: cornerInset))
    context.addLine(to: CGPoint(x: cornerInset + cornerLength, y: cornerInset))

    // Top-right corner
    context.move(to: CGPoint(x: pageWidth - cornerInset - cornerLength, y: cornerInset))
    context.addLine(to: CGPoint(x: pageWidth - cornerInset, y: cornerInset))
    context.addLine(to: CGPoint(x: pageWidth - cornerInset, y: cornerInset + cornerLength))

    // Bottom-left corner
    context.move(to: CGPoint(x: cornerInset, y: pageHeight - cornerInset - cornerLength))
    context.addLine(to: CGPoint(x: cornerInset, y: pageHeight - cornerInset))
    context.addLine(to: CGPoint(x: cornerInset + cornerLength, y: pageHeight - cornerInset))

    // Bottom-right corner
    context.move(to: CGPoint(x: pageWidth - cornerInset - cornerLength, y: pageHeight - cornerInset))
    context.addLine(to: CGPoint(x: pageWidth - cornerInset, y: pageHeight - cornerInset))
    context.addLine(to: CGPoint(x: pageWidth - cornerInset, y: pageHeight - cornerInset - cornerLength))

    context.strokePath()
}

/// Draws the premium cover page for PDF exports
static func drawPDFCoverPage(context: CGContext, title: String, author: String, content: String, pageWidth: CGFloat, pageHeight: CGFloat) {
    let margin: CGFloat = 72
    let centerX = pageWidth / 2

    // Draw decorative corner frames
    drawCornerFrames(context: context, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin)

    var yPosition: CGFloat = 120

    // Draw logo centered at top
    if let logo = ExportBrandAssets.getLogoImage() {
        let logoHeight: CGFloat = 80
        let logoWidth = logoHeight * (logo.size.width / logo.size.height)
        let logoRect = CGRect(x: centerX - logoWidth / 2, y: yPosition, width: logoWidth, height: logoHeight)
        logo.draw(in: logoRect)
        yPosition += logoHeight + 20
    }

    // Brand text - "INSIGHT ATLAS"
    let brandAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 12, weight: .bold),
        .foregroundColor: UIColor.iaGold,
        .kern: 4
    ]
    let brandText = "INSIGHT ATLAS"
    let brandString = NSAttributedString(string: brandText, attributes: brandAttributes)
    let brandSize = brandString.size()
    brandString.draw(at: CGPoint(x: centerX - brandSize.width / 2, y: yPosition))
    yPosition += 40

    // Gold decorative line
    context.setStrokeColor(UIColor.iaGold.cgColor)
    context.setLineWidth(1)
    context.move(to: CGPoint(x: margin + 80, y: yPosition))
    context.addLine(to: CGPoint(x: pageWidth - margin - 80, y: yPosition))
    context.strokePath()
    yPosition += 30

    // Main title - large, bold, centered
    let titleStyle = NSMutableParagraphStyle()
    titleStyle.alignment = .center
    titleStyle.lineSpacing = 8

    let titleAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 36, weight: .bold),
        .foregroundColor: UIColor.iaHeading,
        .paragraphStyle: titleStyle
    ]

    let titleRect = CGRect(x: margin, y: yPosition, width: pageWidth - margin * 2, height: 120)
    let titleString = NSAttributedString(string: title.uppercased(), attributes: titleAttributes)
    titleString.draw(in: titleRect)
    yPosition += 100

    // Author line
    let authorStyle = NSMutableParagraphStyle()
    authorStyle.alignment = .center

    let authorAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.italicSystemFont(ofSize: 16),
        .foregroundColor: UIColor.iaMuted,
        .paragraphStyle: authorStyle
    ]
    let authorString = NSAttributedString(string: "Based on the work of \(author)", attributes: authorAttributes)
    let authorRect = CGRect(x: margin, y: yPosition, width: pageWidth - margin * 2, height: 30)
    authorString.draw(in: authorRect)
    yPosition += 50

    // Another decorative line
    context.setStrokeColor(UIColor.iaGold.cgColor)
    context.setLineWidth(1)
    context.move(to: CGPoint(x: margin + 80, y: yPosition))
    context.addLine(to: CGPoint(x: pageWidth - margin - 80, y: yPosition))
    context.strokePath()
    yPosition += 40

    // "AT A GLANCE" card
    let quickGlanceBullets = extractQuickGlanceForCover(from: content)

    if !quickGlanceBullets.isEmpty {
        let cardMargin: CGFloat = 60
        let cardX = cardMargin
        let cardWidth = pageWidth - cardMargin * 2
        let cardY = yPosition

        // Calculate card height based on content
        let bulletLineHeight: CGFloat = 24
        let cardPadding: CGFloat = 20
        let headerHeight: CGFloat = 35
        let cardHeight = headerHeight + cardPadding * 2 + CGFloat(quickGlanceBullets.count) * bulletLineHeight + 10

        // Draw card background with subtle border
        let cardRect = CGRect(x: cardX, y: cardY, width: cardWidth, height: cardHeight)

        // Fill with light background
        context.setFillColor(UIColor.iaCard.cgColor)
        context.fill(cardRect)

        // Draw burgundy accent line at top of card
        context.setFillColor(UIColor.iaBurgundy.cgColor)
        context.fill(CGRect(x: cardX, y: cardY, width: cardWidth, height: 4))

        // Card header - "AT A GLANCE"
        let cardHeaderAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: UIColor.iaBurgundy,
            .kern: 2
        ]
        let cardHeaderString = NSAttributedString(string: "AT A GLANCE", attributes: cardHeaderAttributes)
        cardHeaderString.draw(at: CGPoint(x: cardX + cardPadding, y: cardY + 12))

        // Draw bullet points
        let bulletAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Georgia", size: 11) ?? UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.iaBody
        ]

        let bulletSymbolAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.iaGold
        ]

        var bulletY = cardY + headerHeight + 8
        let bulletTextWidth = cardWidth - cardPadding * 2 - 25  // Available width for text

        for bullet in quickGlanceBullets {
            // Gold bullet symbol
            let bulletSymbol = NSAttributedString(string: "◆  ", attributes: bulletSymbolAttributes)
            bulletSymbol.draw(at: CGPoint(x: cardX + cardPadding, y: bulletY))

            // Bullet text with word wrapping instead of truncation
            let bulletParagraphStyle = NSMutableParagraphStyle()
            bulletParagraphStyle.lineBreakMode = .byWordWrapping

            var wrappedBulletAttributes = bulletAttributes
            wrappedBulletAttributes[.paragraphStyle] = bulletParagraphStyle

            let bulletTextString = NSAttributedString(string: bullet, attributes: wrappedBulletAttributes)
            let bulletTextRect = CGRect(x: cardX + cardPadding + 20, y: bulletY, width: bulletTextWidth, height: bulletLineHeight * 3)
            bulletTextString.draw(with: bulletTextRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)

            // Calculate actual height used and advance accordingly
            let boundingRect = bulletTextString.boundingRect(with: CGSize(width: bulletTextWidth, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, context: nil)
            bulletY += max(bulletLineHeight, boundingRect.height + 4)
        }

        yPosition = cardY + cardHeight + 30
    }

    // Tagline at bottom
    let taglineStyle = NSMutableParagraphStyle()
    taglineStyle.alignment = .center

    let taglineAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.italicSystemFont(ofSize: 12),
        .foregroundColor: UIColor.iaMuted,
        .paragraphStyle: taglineStyle
    ]
    let taglineString = NSAttributedString(string: "Where Understanding Illuminates the World", attributes: taglineAttributes)
    let taglineRect = CGRect(x: margin, y: pageHeight - 80, width: pageWidth - margin * 2, height: 30)
    taglineString.draw(in: taglineRect)

    // Small decorative element above tagline
    let diamondAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 10),
        .foregroundColor: UIColor.iaGold
    ]
    let diamondStyle = NSMutableParagraphStyle()
    diamondStyle.alignment = .center
    var diamondAttrs = diamondAttributes
    diamondAttrs[.paragraphStyle] = diamondStyle
    let diamondString = NSAttributedString(string: "◆ ◇ ◆", attributes: diamondAttrs)
    let diamondRect = CGRect(x: margin, y: pageHeight - 100, width: pageWidth - margin * 2, height: 20)
    diamondString.draw(in: diamondRect)
}

/// Strips all markdown formatting from text for clean PDF output
static func stripMarkdownForPDF(_ text: String) -> String {
    var result = text

    // Remove bold markers
    if let regex = try? NSRegularExpression(pattern: #"\*\*([^*]+)\*\*"#) {
        result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "$1")
    }

    // Remove italic markers (single asterisks around text)
    if let regex = try? NSRegularExpression(pattern: #"(?<!\*)\*([^*]+)\*(?!\*)"#) {
        result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "$1")
    }

    // Remove code backticks
    result = result.replacingOccurrences(of: "`", with: "")

    // Remove markdown links, keep text: [text](url) -> text
    if let regex = try? NSRegularExpression(pattern: #"\[([^\]]+)\]\([^)]+\)"#) {
        result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "$1")
    }

    return result
}

/// Checks if a line is a markdown table separator (like |---|---|)

/// Parses a markdown table line into cells

static func createAttributedString(from content: String, title: String, author: String, pageWidth: CGFloat) -> NSAttributedString {
    let result = NSMutableAttributedString()

    // Default paragraph style
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineSpacing = 6
    paragraphStyle.paragraphSpacing = 12

    let bodyAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont(name: "Georgia", size: 12) ?? UIFont.systemFont(ofSize: 12),
        .foregroundColor: UIColor.iaBody,
        .paragraphStyle: paragraphStyle
    ]

    let headingStyle = NSMutableParagraphStyle()
    headingStyle.paragraphSpacingBefore = 24
    headingStyle.paragraphSpacing = 8

    let partHeadingStyle = NSMutableParagraphStyle()
    partHeadingStyle.paragraphSpacingBefore = 32
    partHeadingStyle.paragraphSpacing = 12

    // Special block styles
    let blockHeaderStyle = NSMutableParagraphStyle()
    blockHeaderStyle.paragraphSpacingBefore = 16
    blockHeaderStyle.paragraphSpacing = 4

    let quickGlanceHeaderAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
        .foregroundColor: UIColor.iaGold,
        .paragraphStyle: blockHeaderStyle
    ]

    let insightNoteHeaderAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
        .foregroundColor: UIColor.iaCoral,
        .paragraphStyle: blockHeaderStyle
    ]

    let actionBoxHeaderAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
        .foregroundColor: UIColor.iaBurgundy,
        .paragraphStyle: blockHeaderStyle
    ]

    let blockContentStyle = NSMutableParagraphStyle()
    blockContentStyle.lineSpacing = 4
    blockContentStyle.paragraphSpacing = 8
    blockContentStyle.firstLineHeadIndent = 12
    blockContentStyle.headIndent = 12

    let blockContentAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont(name: "Georgia", size: 11) ?? UIFont.systemFont(ofSize: 11),
        .foregroundColor: UIColor.iaBody,
        .paragraphStyle: blockContentStyle
    ]

    // Divider style
    let dividerAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 10),
        .foregroundColor: UIColor.iaGold
    ]

    // Table cell style
    let tableCellStyle = NSMutableParagraphStyle()
    tableCellStyle.lineSpacing = 2
    tableCellStyle.paragraphSpacing = 4

    let tableHeaderAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
        .foregroundColor: UIColor.iaHeading,
        .paragraphStyle: tableCellStyle
    ]

    let tableCellAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont(name: "Georgia", size: 10) ?? UIFont.systemFont(ofSize: 10),
        .foregroundColor: UIColor.iaBody,
        .paragraphStyle: tableCellStyle
    ]

    // Parse content and build attributed string
    let lines = content.components(separatedBy: "\n")
    var inSpecialBlock = false
    var currentBlockType = ""
    var inTable = false

    for line in lines {
        // Handle special block opening markers
        if line.hasPrefix("[QUICK_GLANCE]") {
            inSpecialBlock = true
            currentBlockType = "QUICK_GLANCE"
            result.append(NSAttributedString(string: "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", attributes: [.foregroundColor: UIColor.iaGold]))
            result.append(NSAttributedString(string: "👁 QUICK GLANCE\n", attributes: quickGlanceHeaderAttributes))

            // Add dynamic reading time
            let readingTime = ExportBrandAssets.calculateReadingTime(from: content)
            result.append(NSAttributedString(string: "\(readingTime) min read\n\n", attributes: [
                .font: UIFont.systemFont(ofSize: 9, weight: .medium),
                .foregroundColor: UIColor.iaGold
            ]))
            continue
        }

        if line.hasPrefix("[INSIGHT_NOTE]") {
            inSpecialBlock = true
            currentBlockType = "INSIGHT_NOTE"
            result.append(NSAttributedString(string: "\n💡 INSIGHT ATLAS NOTE\n", attributes: insightNoteHeaderAttributes))
            continue
        }

        if line.hasPrefix("[ACTION_BOX") {
            inSpecialBlock = true
            currentBlockType = "ACTION_BOX"
            result.append(NSAttributedString(string: "\n✓ APPLY IT\n", attributes: actionBoxHeaderAttributes))
            continue
        }

        if line.hasPrefix("[FOUNDATIONAL_NARRATIVE]") {
            inSpecialBlock = true
            currentBlockType = "FOUNDATIONAL_NARRATIVE"
            result.append(NSAttributedString(string: "\n📖 THE STORY BEHIND THE IDEAS\n", attributes: quickGlanceHeaderAttributes))
            continue
        }

        if line.hasPrefix("[STRUCTURE_MAP]") {
            inSpecialBlock = true
            currentBlockType = "STRUCTURE_MAP"
            result.append(NSAttributedString(string: "\n🗺️ STRUCTURE MAP\n", attributes: quickGlanceHeaderAttributes))
            continue
        }

        if line.hasPrefix("[TAKEAWAYS]") {
            inSpecialBlock = true
            currentBlockType = "TAKEAWAYS"
            result.append(NSAttributedString(string: "\n⭐ KEY TAKEAWAYS\n", attributes: quickGlanceHeaderAttributes))
            continue
        }

        if line.hasPrefix("[VISUAL_FLOWCHART") {
            inSpecialBlock = true
            currentBlockType = "VISUAL_FLOWCHART"
            result.append(NSAttributedString(string: "\n📊 VISUAL GUIDE\n", attributes: quickGlanceHeaderAttributes))
            continue
        }

        if line.hasPrefix("[VISUAL_TABLE") {
            inSpecialBlock = true
            currentBlockType = "VISUAL_TABLE"
            result.append(NSAttributedString(string: "\n📋 REFERENCE TABLE\n", attributes: quickGlanceHeaderAttributes))
            continue
        }

        if line.hasPrefix("[EXERCISE_") || line.hasPrefix("[EXERCISE]") {
            inSpecialBlock = true
            currentBlockType = "EXERCISE"
            result.append(NSAttributedString(string: "\n✏️ EXERCISE\n", attributes: actionBoxHeaderAttributes))
            continue
        }

        if line.hasPrefix("[QUOTE]") {
            inSpecialBlock = true
            currentBlockType = "QUOTE"
            continue
        }

        // Handle special block closing markers
        if line.hasPrefix("[/QUICK_GLANCE]") || line.hasPrefix("[/INSIGHT_NOTE]") ||
           line.hasPrefix("[/ACTION_BOX]") || line.hasPrefix("[/QUOTE]") ||
           line.hasPrefix("[/FOUNDATIONAL_NARRATIVE]") || line.hasPrefix("[/STRUCTURE_MAP]") ||
           line.hasPrefix("[/TAKEAWAYS]") || line.hasPrefix("[/VISUAL_FLOWCHART]") ||
           line.hasPrefix("[/VISUAL_TABLE]") || line.hasPrefix("[/EXERCISE") {
            if currentBlockType == "QUICK_GLANCE" {
                result.append(NSAttributedString(string: "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", attributes: [.foregroundColor: UIColor.iaGold]))
            }
            inSpecialBlock = false
            currentBlockType = ""
            inTable = false
            continue
        }

        // Skip any remaining block markers
        if line.hasPrefix("[") && line.contains("]") && !line.contains("](") {
            continue
        }

        // Skip box drawing characters but render cleaner version
        if line.contains("┌") || line.contains("├") || line.contains("└") ||
           line.contains("│") || line.contains("─") || line.contains("┐") ||
           line.contains("┤") || line.contains("┘") {
            // Clean the line of box characters for PDF
            var cleanLine = line
            for char in ["┌", "├", "└", "│", "─", "┐", "┤", "┘"] {
                cleanLine = cleanLine.replacingOccurrences(of: char, with: "")
            }
            cleanLine = cleanLine.trimmingCharacters(in: .whitespaces)
            cleanLine = stripMarkdownForPDF(cleanLine)
            if !cleanLine.isEmpty && !cleanLine.contains("↓") {
                result.append(NSAttributedString(string: "  \(cleanLine)\n", attributes: blockContentAttributes))
            }
            continue
        }

        // Skip arrow indicators (render as flow indicator)
        if line.trimmingCharacters(in: .whitespaces) == "↓" {
            result.append(NSAttributedString(string: "    ↓\n", attributes: [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.iaGold
            ]))
            continue
        }

        // Handle horizontal rules (---)
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        if trimmedLine == "---" || trimmedLine == "***" || trimmedLine == "___" {
            result.append(NSAttributedString(string: "\n◆ ◇ ◆\n\n", attributes: dividerAttributes))
            continue
        }

        // Handle ═══ box drawing dividers - convert to premium ornament
        if trimmedLine.contains("═══") || (trimmedLine.count > 3 && trimmedLine.filter({ $0 == "═" }).count > trimmedLine.count / 2) {
            result.append(NSAttributedString(string: "\n◇ ◆ ◇\n\n", attributes: dividerAttributes))
            continue
        }

        // Handle markdown tables
        if trimmedLine.hasPrefix("|") && trimmedLine.contains("|") {
            // Check if this is a separator line
            if ExportMarkdownTable.isTableSeparator(trimmedLine) {
                continue // Skip separator lines
            }

            let cells = ExportMarkdownTable.parseTableRow(trimmedLine)
            if !cells.isEmpty {
                if !inTable {
                    // This is the header row
                    inTable = true
                    let headerText = cells.joined(separator: "  |  ")
                    result.append(NSAttributedString(string: "\(headerText)\n", attributes: tableHeaderAttributes))
                    result.append(NSAttributedString(string: "─────────────────────────────────────\n", attributes: dividerAttributes))
                } else {
                    // Data row
                    let rowText = cells.joined(separator: "  |  ")
                    result.append(NSAttributedString(string: "\(stripMarkdownForPDF(rowText))\n", attributes: tableCellAttributes))
                }
            }
            continue
        } else if inTable && !trimmedLine.isEmpty && !trimmedLine.hasPrefix("|") {
            // End of table
            inTable = false
            result.append(NSAttributedString(string: "\n", attributes: bodyAttributes))
        }

        // Content inside special blocks
        if inSpecialBlock {
            if !trimmedLine.isEmpty {
                // Skip lines that are just ## headers inside blocks (often duplicates)
                if trimmedLine.hasPrefix("## ") {
                    continue
                }

                // Handle quote blocks specially
                if currentBlockType == "QUOTE" {
                    let quoteStyle = NSMutableParagraphStyle()
                    quoteStyle.firstLineHeadIndent = 20
                    quoteStyle.headIndent = 20
                    let quoteAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.italicSystemFont(ofSize: 12),
                        .foregroundColor: UIColor.iaMuted,
                        .paragraphStyle: quoteStyle
                    ]
                    let cleanText = stripMarkdownForPDF(trimmedLine)
                    result.append(NSAttributedString(string: "\"\(cleanText)\"\n", attributes: quoteAttributes))
                }
                // Handle list items in blocks
                else if trimmedLine.hasPrefix("- ") || trimmedLine.hasPrefix("* ") {
                    let itemText = stripMarkdownForPDF(String(trimmedLine.dropFirst(2)))
                    result.append(NSAttributedString(string: "  • \(itemText)\n", attributes: blockContentAttributes))
                }
                // Handle numbered items in blocks
                else if let _ = trimmedLine.range(of: "^\\d+\\.", options: .regularExpression) {
                    let cleanText = stripMarkdownForPDF(trimmedLine)
                    result.append(NSAttributedString(string: "  \(cleanText)\n", attributes: blockContentAttributes))
                }
                // Regular block content
                else {
                    let cleanText = stripMarkdownForPDF(trimmedLine)
                    result.append(NSAttributedString(string: "  \(cleanText)\n", attributes: blockContentAttributes))
                }
            }
            continue
        }

        // Handle # PART headers (main section dividers)
        if line.hasPrefix("# ") && !line.hasPrefix("## ") {
            let headerText = stripMarkdownForPDF(String(line.dropFirst(2)))
            let partAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor.iaHeading,
                .paragraphStyle: partHeadingStyle
            ]
            result.append(NSAttributedString(string: "\n", attributes: bodyAttributes))
            result.append(NSAttributedString(string: "◆ ◇ ◆\n\n", attributes: dividerAttributes))
            result.append(NSAttributedString(string: "\(headerText)\n", attributes: partAttributes))
            continue
        }

        // Headers
        if line.hasPrefix("## ") {
            let headerText = stripMarkdownForPDF(String(line.dropFirst(3)))
            let headerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .bold),
                .foregroundColor: UIColor.iaHeading,
                .paragraphStyle: headingStyle
            ]
            result.append(NSAttributedString(string: "\n\(headerText)\n", attributes: headerAttributes))
            continue
        }

        if line.hasPrefix("### ") {
            let headerText = stripMarkdownForPDF(String(line.dropFirst(4)))
            let headerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: UIColor.iaHeading,
                .paragraphStyle: headingStyle
            ]
            result.append(NSAttributedString(string: "\n\(headerText)\n", attributes: headerAttributes))
            continue
        }

        // List items
        if line.hasPrefix("- ") || line.hasPrefix("* ") {
            let itemText = stripMarkdownForPDF(String(line.dropFirst(2)))
            result.append(NSAttributedString(string: "• \(itemText)\n", attributes: bodyAttributes))
            continue
        }

        // Numbered list items
        if let _ = trimmedLine.range(of: "^\\d+\\.", options: .regularExpression) {
            let cleanText = stripMarkdownForPDF(trimmedLine)
            result.append(NSAttributedString(string: "\(cleanText)\n", attributes: bodyAttributes))
            continue
        }

        // Regular text
        if !trimmedLine.isEmpty {
            // Strip all markdown formatting
            let processedLine = stripMarkdownForPDF(line)
            result.append(NSAttributedString(string: processedLine + "\n", attributes: bodyAttributes))
        } else {
            result.append(NSAttributedString(string: "\n", attributes: bodyAttributes))
        }
    }

    return result
}


}
