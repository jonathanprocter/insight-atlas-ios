//
//  GuideDOCXExporter.swift
//  InsightAtlas
//  Extracted from DataManager — DOCX ZIP/XML export with no library state.
//

import Foundation

enum GuideDOCXExporter {
// MARK: - DOCX Generation

static func generate(content: String, title: String, author: String, to url: URL) throws {
    // DOCX is a ZIP file with XML content
    // We'll create a minimal valid DOCX structure

    let fileManager = FileManager.default
    let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: tempDir) }

    // Create directory structure
    let wordDir = tempDir.appendingPathComponent("word")
    let relsDir = tempDir.appendingPathComponent("_rels")
    let wordRelsDir = wordDir.appendingPathComponent("_rels")

    try fileManager.createDirectory(at: wordDir, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: relsDir, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: wordRelsDir, withIntermediateDirectories: true)

    // Create [Content_Types].xml
    let contentTypes = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
    </Types>
    """
    try contentTypes.write(to: tempDir.appendingPathComponent("[Content_Types].xml"), atomically: true, encoding: .utf8)

    // Create _rels/.rels
    let rels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
    </Relationships>
    """
    try rels.write(to: relsDir.appendingPathComponent(".rels"), atomically: true, encoding: .utf8)

    // Create word/_rels/document.xml.rels
    let documentRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
    </Relationships>
    """
    try documentRels.write(to: wordRelsDir.appendingPathComponent("document.xml.rels"), atomically: true, encoding: .utf8)

    // Create word/styles.xml with Insight Atlas branding
    let styles = createDOCXStyles()
    try styles.write(to: wordDir.appendingPathComponent("styles.xml"), atomically: true, encoding: .utf8)

    // Create word/document.xml
    let document = createDOCXDocument(content: content, title: title, author: author)
    try document.write(to: wordDir.appendingPathComponent("document.xml"), atomically: true, encoding: .utf8)

    // Create ZIP archive
    try createZipArchive(from: tempDir, to: url)

}

static func createDOCXStyles() -> String {
    return """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:style w:type="paragraph" w:styleId="Title">
            <w:name w:val="Title"/>
            <w:pPr>
                <w:spacing w:after="200"/>
                <w:jc w:val="center"/>
            </w:pPr>
            <w:rPr>
                <w:b/>
                <w:sz w:val="56"/>
                <w:color w:val="0F172A"/>
            </w:rPr>
        </w:style>
        <w:style w:type="paragraph" w:styleId="Heading1">
            <w:name w:val="Heading 1"/>
            <w:pPr>
                <w:spacing w:before="400" w:after="200"/>
                <w:pBdr>
                    <w:bottom w:val="single" w:sz="12" w:color="CBA135"/>
                </w:pBdr>
            </w:pPr>
            <w:rPr>
                <w:b/>
                <w:sz w:val="36"/>
                <w:color w:val="0F172A"/>
            </w:rPr>
        </w:style>
        <w:style w:type="paragraph" w:styleId="Heading2">
            <w:name w:val="Heading 2"/>
            <w:pPr>
                <w:spacing w:before="300" w:after="100"/>
            </w:pPr>
            <w:rPr>
                <w:b/>
                <w:sz w:val="28"/>
                <w:color w:val="0F172A"/>
            </w:rPr>
        </w:style>
        <w:style w:type="character" w:styleId="BurgundyText">
            <w:name w:val="Burgundy Text"/>
            <w:rPr>
                <w:color w:val="582534"/>
            </w:rPr>
        </w:style>
        <w:style w:type="paragraph" w:styleId="Normal">
            <w:name w:val="Normal"/>
            <w:pPr>
                <w:spacing w:after="200" w:line="360" w:lineRule="auto"/>
            </w:pPr>
            <w:rPr>
                <w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/>
                <w:sz w:val="24"/>
                <w:color w:val="1E293B"/>
            </w:rPr>
        </w:style>
        <w:style w:type="paragraph" w:styleId="InsightNote">
            <w:name w:val="Insight Note"/>
            <w:pPr>
                <w:spacing w:before="200" w:after="200"/>
                <w:pBdr>
                    <w:left w:val="single" w:sz="24" w:color="2A8B7F"/>
                </w:pBdr>
                <w:ind w:left="400"/>
                <w:shd w:val="clear" w:fill="FEFCE8"/>
            </w:pPr>
            <w:rPr>
                <w:sz w:val="22"/>
                <w:color w:val="1E293B"/>
            </w:rPr>
        </w:style>
        <w:style w:type="paragraph" w:styleId="ActionBox">
            <w:name w:val="Action Box"/>
            <w:pPr>
                <w:spacing w:before="200" w:after="200"/>
                <w:pBdr>
                    <w:top w:val="single" w:sz="12" w:color="CBA135"/>
                    <w:left w:val="single" w:sz="12" w:color="CBA135"/>
                    <w:bottom w:val="single" w:sz="12" w:color="CBA135"/>
                    <w:right w:val="single" w:sz="12" w:color="CBA135"/>
                </w:pBdr>
                <w:ind w:left="200" w:right="200"/>
                <w:shd w:val="clear" w:fill="FEFCE8"/>
            </w:pPr>
            <w:rPr>
                <w:sz w:val="24"/>
                <w:color w:val="1E293B"/>
            </w:rPr>
        </w:style>
        <w:style w:type="paragraph" w:styleId="QuickGlance">
            <w:name w:val="Quick Glance"/>
            <w:pPr>
                <w:spacing w:before="200" w:after="200"/>
                <w:pBdr>
                    <w:top w:val="single" w:sz="12" w:color="CBA135"/>
                    <w:left w:val="single" w:sz="12" w:color="CBA135"/>
                    <w:bottom w:val="single" w:sz="12" w:color="CBA135"/>
                    <w:right w:val="single" w:sz="12" w:color="CBA135"/>
                </w:pBdr>
                <w:ind w:left="200" w:right="200"/>
                <w:shd w:val="clear" w:fill="FEFCE8"/>
            </w:pPr>
            <w:rPr>
                <w:sz w:val="24"/>
                <w:color w:val="1E293B"/>
            </w:rPr>
        </w:style>
        <w:style w:type="paragraph" w:styleId="Exercise">
            <w:name w:val="Exercise"/>
            <w:pPr>
                <w:spacing w:before="200" w:after="200"/>
                <w:pBdr>
                    <w:top w:val="single" w:sz="12" w:color="2A8B7F"/>
                    <w:left w:val="single" w:sz="12" w:color="2A8B7F"/>
                    <w:bottom w:val="single" w:sz="12" w:color="2A8B7F"/>
                    <w:right w:val="single" w:sz="12" w:color="2A8B7F"/>
                </w:pBdr>
                <w:ind w:left="200" w:right="200"/>
                <w:shd w:val="clear" w:fill="FEFCE8"/>
            </w:pPr>
            <w:rPr>
                <w:sz w:val="24"/>
                <w:color w:val="1E293B"/>
            </w:rPr>
        </w:style>
        <w:style w:type="paragraph" w:styleId="Flowchart">
            <w:name w:val="Flowchart"/>
            <w:pPr>
                <w:spacing w:before="100" w:after="100"/>
                <w:pBdr>
                    <w:top w:val="single" w:sz="8" w:color="CBA135"/>
                    <w:left w:val="single" w:sz="8" w:color="CBA135"/>
                    <w:bottom w:val="single" w:sz="8" w:color="CBA135"/>
                    <w:right w:val="single" w:sz="8" w:color="CBA135"/>
                </w:pBdr>
                <w:jc w:val="center"/>
                <w:shd w:val="clear" w:fill="FEFCE8"/>
            </w:pPr>
            <w:rPr>
                <w:sz w:val="22"/>
                <w:color w:val="1E293B"/>
            </w:rPr>
        </w:style>
        <w:style w:type="paragraph" w:styleId="FlowchartArrow">
            <w:name w:val="Flowchart Arrow"/>
            <w:pPr>
                <w:spacing w:before="50" w:after="50"/>
                <w:jc w:val="center"/>
            </w:pPr>
            <w:rPr>
                <w:sz w:val="28"/>
                <w:color w:val="CBA135"/>
            </w:rPr>
        </w:style>
        <w:style w:type="paragraph" w:styleId="FoundationalNarrative">
            <w:name w:val="Foundational Narrative"/>
            <w:pPr>
                <w:spacing w:before="200" w:after="200"/>
                <w:pBdr>
                    <w:left w:val="single" w:sz="24" w:color="CBA135"/>
                </w:pBdr>
                <w:ind w:left="400"/>
                <w:shd w:val="clear" w:fill="FEFCE8"/>
            </w:pPr>
            <w:rPr>
                <w:i/>
                <w:sz w:val="24"/>
                <w:color w:val="1E293B"/>
            </w:rPr>
        </w:style>
        <w:style w:type="paragraph" w:styleId="Takeaways">
            <w:name w:val="Takeaways"/>
            <w:pPr>
                <w:spacing w:before="200" w:after="200"/>
                <w:pBdr>
                    <w:top w:val="single" w:sz="12" w:color="CBA135"/>
                    <w:left w:val="single" w:sz="12" w:color="CBA135"/>
                    <w:bottom w:val="single" w:sz="12" w:color="CBA135"/>
                    <w:right w:val="single" w:sz="12" w:color="CBA135"/>
                </w:pBdr>
                <w:ind w:left="200" w:right="200"/>
                <w:shd w:val="clear" w:fill="FEFCE8"/>
            </w:pPr>
            <w:rPr>
                <w:sz w:val="24"/>
                <w:color w:val="1E293B"/>
            </w:rPr>
        </w:style>
        <w:style w:type="paragraph" w:styleId="BlockHeader">
            <w:name w:val="Block Header"/>
            <w:pPr>
                <w:spacing w:after="100"/>
            </w:pPr>
            <w:rPr>
                <w:b/>
                <w:caps/>
                <w:sz w:val="20"/>
                <w:color w:val="64748B"/>
                <w:spacing w:val="40"/>
            </w:rPr>
        </w:style>
        <!-- PREMIUM STYLES -->
        <w:style w:type="paragraph" w:styleId="PremiumQuote">
            <w:name w:val="Premium Quote"/>
            <w:pPr>
                <w:spacing w:before="300" w:after="300"/>
                <w:pBdr>
                    <w:left w:val="single" w:sz="24" w:color="D4735C"/>
                </w:pBdr>
                <w:ind w:left="400" w:right="200"/>
                <w:shd w:val="clear" w:fill="FEFCE8"/>
            </w:pPr>
            <w:rPr>
                <w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/>
                <w:i/>
                <w:sz w:val="26"/>
                <w:color w:val="1E293B"/>
            </w:rPr>
        </w:style>
        <w:style w:type="paragraph" w:styleId="PremiumQuoteAttribution">
            <w:name w:val="Premium Quote Attribution"/>
            <w:pPr>
                <w:spacing w:before="100" w:after="200"/>
                <w:jc w:val="right"/>
                <w:ind w:right="200"/>
            </w:pPr>
            <w:rPr>
                <w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/>
                <w:b/>
                <w:sz w:val="22"/>
                <w:color w:val="D4735C"/>
            </w:rPr>
        </w:style>
        <w:style w:type="paragraph" w:styleId="AuthorSpotlight">
            <w:name w:val="Author Spotlight"/>
            <w:pPr>
                <w:spacing w:before="200" w:after="200"/>
                <w:pBdr>
                    <w:top w:val="double" w:sz="12" w:color="CBA135"/>
                    <w:left w:val="double" w:sz="12" w:color="CBA135"/>
                    <w:bottom w:val="double" w:sz="12" w:color="CBA135"/>
                    <w:right w:val="double" w:sz="12" w:color="CBA135"/>
                </w:pBdr>
                <w:ind w:left="200" w:right="200"/>
                <w:shd w:val="clear" w:fill="FEFCE8"/>
            </w:pPr>
            <w:rPr>
                <w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/>
                <w:sz w:val="24"/>
                <w:color w:val="1E293B"/>
            </w:rPr>
        </w:style>
        <w:style w:type="paragraph" w:styleId="AuthorSpotlightName">
            <w:name w:val="Author Spotlight Name"/>
            <w:pPr>
                <w:spacing w:before="100" w:after="100"/>
            </w:pPr>
            <w:rPr>
                <w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/>
                <w:b/>
                <w:sz w:val="36"/>
                <w:color w:val="D4735C"/>
            </w:rPr>
        </w:style>
        <w:style w:type="paragraph" w:styleId="PremiumDivider">
            <w:name w:val="Premium Divider"/>
            <w:pPr>
                <w:spacing w:before="400" w:after="400"/>
                <w:jc w:val="center"/>
            </w:pPr>
            <w:rPr>
                <w:sz w:val="24"/>
                <w:color w:val="CBA135"/>
                <w:spacing w:val="100"/>
            </w:rPr>
        </w:style>
        <w:style w:type="paragraph" w:styleId="PremiumH1">
            <w:name w:val="Premium H1"/>
            <w:pPr>
                <w:spacing w:before="500" w:after="300"/>
                <w:jc w:val="center"/>
            </w:pPr>
            <w:rPr>
                <w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/>
                <w:b/>
                <w:caps/>
                <w:sz w:val="32"/>
                <w:color w:val="CBA135"/>
                <w:spacing w:val="60"/>
            </w:rPr>
        </w:style>
        <w:style w:type="paragraph" w:styleId="PremiumH1Ornament">
            <w:name w:val="Premium H1 Ornament"/>
            <w:pPr>
                <w:spacing w:before="200" w:after="100"/>
                <w:jc w:val="center"/>
            </w:pPr>
            <w:rPr>
                <w:sz w:val="16"/>
                <w:color w:val="CBA135"/>
                <w:spacing w:val="80"/>
            </w:rPr>
        </w:style>
        <w:style w:type="paragraph" w:styleId="PremiumH2">
            <w:name w:val="Premium H2"/>
            <w:pPr>
                <w:spacing w:before="400" w:after="200"/>
                <w:pBdr>
                    <w:left w:val="single" w:sz="24" w:color="CBA135"/>
                </w:pBdr>
                <w:ind w:left="200"/>
            </w:pPr>
            <w:rPr>
                <w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/>
                <w:b/>
                <w:sz w:val="32"/>
                <w:color w:val="0F172A"/>
            </w:rPr>
        </w:style>
        <w:style w:type="paragraph" w:styleId="PartHeader">
            <w:name w:val="Part Header"/>
            <w:pPr>
                <w:spacing w:before="600" w:after="400"/>
                <w:jc w:val="center"/>
                <w:pBdr>
                    <w:top w:val="single" w:sz="12" w:color="CBA135"/>
                    <w:bottom w:val="single" w:sz="12" w:color="CBA135"/>
                </w:pBdr>
            </w:pPr>
            <w:rPr>
                <w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/>
                <w:b/>
                <w:caps/>
                <w:sz w:val="40"/>
                <w:color w:val="0F172A"/>
                <w:spacing w:val="60"/>
            </w:rPr>
        </w:style>
        <w:style w:type="paragraph" w:styleId="PartOrnament">
            <w:name w:val="Part Ornament"/>
            <w:pPr>
                <w:spacing w:before="100" w:after="100"/>
                <w:jc w:val="center"/>
            </w:pPr>
            <w:rPr>
                <w:sz w:val="28"/>
                <w:color w:val="CBA135"/>
                <w:spacing w:val="80"/>
            </w:rPr>
        </w:style>
    </w:styles>
    """
}

static func createDOCXDocument(content: String, title: String, author: String) -> String {
    var paragraphs = ""
    var inTable = false
    var tableRows: [[String]] = []

    // ============================================
    // COVER PAGE - Premium branded design
    // ============================================

    // Top spacing to push content down
    for _ in 0..<4 {
        paragraphs += "<w:p><w:pPr><w:spacing w:after=\"0\"/></w:pPr></w:p>"
    }

    // Top tagline - "Where Understanding Illuminates the World"
    paragraphs += """
    <w:p>
        <w:pPr>
            <w:jc w:val="center"/>
            <w:spacing w:after="200"/>
        </w:pPr>
        <w:r>
            <w:rPr>
                <w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/>
                <w:sz w:val="18"/>
                <w:color w:val="5C4A3D"/>
                <w:spacing w:val="40"/>
            </w:rPr>
            <w:t>WHERE UNDERSTANDING ILLUMINATES THE WORLD</w:t>
        </w:r>
    </w:p>
    """

    // Decorative line under tagline
    paragraphs += """
    <w:p>
        <w:pPr>
            <w:jc w:val="center"/>
            <w:spacing w:after="600"/>
        </w:pPr>
        <w:r>
            <w:rPr>
                <w:color w:val="CBA135"/>
            </w:rPr>
            <w:t>━━━━━━━━━━</w:t>
        </w:r>
    </w:p>
    """

    // Large spacing before title area
    for _ in 0..<6 {
        paragraphs += "<w:p><w:pPr><w:spacing w:after=\"0\"/></w:pPr></w:p>"
    }

    // Logo placeholder - decorative circle with "IA" monogram
    paragraphs += """
    <w:p>
        <w:pPr>
            <w:jc w:val="center"/>
            <w:spacing w:after="100"/>
        </w:pPr>
        <w:r>
            <w:rPr>
                <w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/>
                <w:b/>
                <w:sz w:val="72"/>
                <w:color w:val="CBA135"/>
            </w:rPr>
            <w:t>◎</w:t>
        </w:r>
    </w:p>
    """

    // Large spacing before title
    for _ in 0..<4 {
        paragraphs += "<w:p><w:pPr><w:spacing w:after=\"0\"/></w:pPr></w:p>"
    }

    // Book Title - Large, prominent
    paragraphs += """
    <w:p>
        <w:pPr>
            <w:jc w:val="center"/>
            <w:spacing w:after="200"/>
        </w:pPr>
        <w:r>
            <w:rPr>
                <w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/>
                <w:b/>
                <w:sz w:val="56"/>
                <w:color w:val="2D2520"/>
            </w:rPr>
            <w:t>\(escapeXML(title))</w:t>
        </w:r>
    </w:p>
    """

    // "by" label
    paragraphs += """
    <w:p>
        <w:pPr>
            <w:jc w:val="center"/>
            <w:spacing w:after="60"/>
        </w:pPr>
        <w:r>
            <w:rPr>
                <w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/>
                <w:i/>
                <w:sz w:val="22"/>
                <w:color w:val="5C5248"/>
            </w:rPr>
            <w:t>by</w:t>
        </w:r>
    </w:p>
    """

    // Author name
    paragraphs += """
    <w:p>
        <w:pPr>
            <w:jc w:val="center"/>
            <w:spacing w:after="200"/>
        </w:pPr>
        <w:r>
            <w:rPr>
                <w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/>
                <w:sz w:val="32"/>
                <w:color w:val="3D3229"/>
            </w:rPr>
            <w:t>\(escapeXML(author))</w:t>
        </w:r>
    </w:p>
    """

    // Decorative line under author
    paragraphs += """
    <w:p>
        <w:pPr>
            <w:jc w:val="center"/>
            <w:spacing w:after="400"/>
        </w:pPr>
        <w:r>
            <w:rPr>
                <w:color w:val="CBA135"/>
            </w:rPr>
            <w:t>━━━━━</w:t>
        </w:r>
    </w:p>
    """

    // Large spacing before bottom branding
    for _ in 0..<8 {
        paragraphs += "<w:p><w:pPr><w:spacing w:after=\"0\"/></w:pPr></w:p>"
    }

    // Brand name - "Insight Atlas"
    paragraphs += """
    <w:p>
        <w:pPr>
            <w:jc w:val="center"/>
            <w:spacing w:after="60"/>
        </w:pPr>
        <w:r>
            <w:rPr>
                <w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/>
                <w:b/>
                <w:sz w:val="36"/>
                <w:color w:val="CBA135"/>
            </w:rPr>
            <w:t>Insight Atlas</w:t>
        </w:r>
    </w:p>
    """

    // Subtitle - "A Comprehensive Analysis Guide"
    paragraphs += """
    <w:p>
        <w:pPr>
            <w:jc w:val="center"/>
            <w:spacing w:after="0"/>
        </w:pPr>
        <w:r>
            <w:rPr>
                <w:rFonts w:ascii="Helvetica Neue" w:hAnsi="Helvetica Neue"/>
                <w:sz w:val="16"/>
                <w:color w:val="5C5248"/>
                <w:spacing w:val="30"/>
            </w:rPr>
            <w:t>A COMPREHENSIVE ANALYSIS GUIDE</w:t>
        </w:r>
    </w:p>
    """

    // Page break after cover page
    paragraphs += """
    <w:p>
        <w:r>
            <w:br w:type="page"/>
        </w:r>
    </w:p>
    """

    // ============================================
    // CONTENT PAGES - Start after page break
    // ============================================

    // Content header - smaller branded header for content pages
    paragraphs += """
    <w:p>
        <w:pPr><w:jc w:val="center"/></w:pPr>
        <w:r>
            <w:rPr>
                <w:sz w:val="18"/>
                <w:color w:val="CBA135"/>
                <w:spacing w:val="60"/>
            </w:rPr>
            <w:t>INSIGHT ATLAS GUIDE</w:t>
        </w:r>
    </w:p>
    """

    // Content title
    paragraphs += """
    <w:p>
        <w:pPr><w:pStyle w:val="Title"/></w:pPr>
        <w:r><w:t>\(escapeXML(title))</w:t></w:r>
    </w:p>
    """

    // Content author
    paragraphs += """
    <w:p>
        <w:pPr><w:jc w:val="center"/></w:pPr>
        <w:r>
            <w:rPr><w:i/><w:color w:val="4A5568"/></w:rPr>
            <w:t>by \(escapeXML(author))</w:t>
        </w:r>
    </w:p>
    """

    // Divider
    paragraphs += """
    <w:p>
        <w:pPr>
            <w:pBdr>
                <w:bottom w:val="single" w:sz="12" w:color="CBA135"/>
            </w:pBdr>
        </w:pPr>
    </w:p>
    """

    // Parse content
    var inSpecialBlock = false
    var specialBlockType = ""
    var specialBlockContent = ""

    let lines = content.components(separatedBy: "\n")

    for line in lines {
        // Handle special blocks
        if line.hasPrefix("[QUICK_GLANCE]") {
            inSpecialBlock = true
            specialBlockType = "QuickGlance"
            specialBlockContent = ""
            paragraphs += createDOCXBlockHeader(icon: "📋", title: "QUICK GLANCE")
            continue
        }
        if line.hasPrefix("[INSIGHT_NOTE]") {
            inSpecialBlock = true
            specialBlockType = "InsightNote"
            specialBlockContent = ""
            paragraphs += createDOCXBlockHeader(icon: "💡", title: "INSIGHT ATLAS NOTE")
            continue
        }
        if line.hasPrefix("[ACTION_BOX") {
            inSpecialBlock = true
            specialBlockType = "ActionBox"
            specialBlockContent = ""
            paragraphs += createDOCXBlockHeader(icon: "✓", title: "APPLY IT")
            continue
        }
        if line.hasPrefix("[FOUNDATIONAL_NARRATIVE]") {
            inSpecialBlock = true
            specialBlockType = "FoundationalNarrative"
            specialBlockContent = ""
            // Add header for block
            paragraphs += createDOCXBlockHeader(icon: "📖", title: "THE STORY BEHIND THE IDEAS")
            continue
        }
        if line.hasPrefix("[TAKEAWAYS]") {
            inSpecialBlock = true
            specialBlockType = "Takeaways"
            specialBlockContent = ""
            paragraphs += createDOCXBlockHeader(icon: "⭐", title: "KEY TAKEAWAYS")
            continue
        }
        if line.hasPrefix("[VISUAL_FLOWCHART") {
            inSpecialBlock = true
            specialBlockType = "Flowchart"
            specialBlockContent = ""
            paragraphs += createDOCXBlockHeader(icon: "📊", title: "VISUAL GUIDE")
            continue
        }
        if line.hasPrefix("[EXERCISE_") {
            inSpecialBlock = true
            specialBlockType = "Exercise"
            specialBlockContent = ""
            paragraphs += createDOCXBlockHeader(icon: "✏️", title: "EXERCISE")
            continue
        }
        if line.hasPrefix("[STRUCTURE_MAP]") || line.hasPrefix("[VISUAL_TABLE") || line.hasPrefix("[QUOTE]") {
            inSpecialBlock = true
            specialBlockType = "Normal"
            specialBlockContent = ""
            continue
        }
        // Premium block types
        if line.hasPrefix("[PREMIUM_QUOTE]") {
            inSpecialBlock = true
            specialBlockType = "PremiumQuote"
            specialBlockContent = ""
            continue
        }
        if line.hasPrefix("[AUTHOR_SPOTLIGHT]") {
            inSpecialBlock = true
            specialBlockType = "AuthorSpotlight"
            specialBlockContent = ""
            paragraphs += createDOCXBlockHeader(icon: "📖", title: "ABOUT THE AUTHOR")
            continue
        }
        if line.hasPrefix("[PREMIUM_DIVIDER]") {
            paragraphs += createDOCXParagraph(text: "◆  ◇  ◆", style: "PremiumDivider")
            continue
        }
        if line.hasPrefix("[PREMIUM_H1]") {
            inSpecialBlock = true
            specialBlockType = "PremiumH1"
            specialBlockContent = ""
            paragraphs += createDOCXParagraph(text: "◆ ◇ ◆", style: "PremiumH1Ornament")
            continue
        }
        if line.hasPrefix("[PREMIUM_H2]") {
            inSpecialBlock = true
            specialBlockType = "PremiumH2"
            specialBlockContent = ""
            continue
        }

        if line.hasPrefix("[/QUICK_GLANCE]") || line.hasPrefix("[/INSIGHT_NOTE]") || line.hasPrefix("[/ACTION_BOX]") ||
           line.hasPrefix("[/FOUNDATIONAL_NARRATIVE]") || line.hasPrefix("[/STRUCTURE_MAP]") ||
           line.hasPrefix("[/TAKEAWAYS]") || line.hasPrefix("[/VISUAL_FLOWCHART]") ||
           line.hasPrefix("[/VISUAL_TABLE]") || line.hasPrefix("[/EXERCISE_") || line.hasPrefix("[/QUOTE]") ||
           // Premium block end markers
           line.hasPrefix("[/PREMIUM_QUOTE]") || line.hasPrefix("[/AUTHOR_SPOTLIGHT]") ||
           line.hasPrefix("[/PREMIUM_DIVIDER]") || line.hasPrefix("[/PREMIUM_H1]") || line.hasPrefix("[/PREMIUM_H2]") {
            if inSpecialBlock && !specialBlockContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Handle structured blocks specially
                if specialBlockType == "InsightNote" {
                    paragraphs += createDOCXInsightNote(content: specialBlockContent)
                } else if specialBlockType == "PremiumQuote" {
                    paragraphs += createDOCXPremiumQuote(content: specialBlockContent)
                } else if specialBlockType == "AuthorSpotlight" {
                    paragraphs += createDOCXAuthorSpotlight(content: specialBlockContent)
                } else if specialBlockType == "PremiumH1" {
                    paragraphs += createDOCXParagraph(text: specialBlockContent.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(), style: "PremiumH1")
                    paragraphs += createDOCXParagraph(text: "◆ ◇ ◆", style: "PremiumH1Ornament")
                } else if specialBlockType == "PremiumH2" {
                    paragraphs += createDOCXParagraph(text: specialBlockContent.trimmingCharacters(in: .whitespacesAndNewlines), style: "PremiumH2")
                } else {
                    paragraphs += createDOCXParagraph(text: specialBlockContent.trimmingCharacters(in: .whitespacesAndNewlines), style: specialBlockType)
                }
            }
            inSpecialBlock = false
            specialBlockType = ""
            specialBlockContent = ""
            continue
        }

        // Skip other markers and box drawing
        if line.hasPrefix("[") && line.contains("]") && !line.contains("](") { continue }
        if line.contains("┌") || line.contains("│") || line.contains("└") || line.contains("─") || line.contains("↓") { continue }

        if inSpecialBlock {
            // Preserve newlines so quote attribution and author/bio splits work.
            specialBlockContent += line + "\n"
            continue
        }

        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

        // Handle table rows
        if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") {
            // Skip separator rows
            if trimmed.contains("---") || ExportMarkdownTable.isTableSeparator(trimmed) {
                continue
            }
            let cells = ExportMarkdownTable.parseTableRow(trimmed)
            if !cells.isEmpty {
                if !inTable {
                    inTable = true
                    tableRows = []
                }
                tableRows.append(cells)
            }
            continue
        } else if inTable {
            // End of table - render it
            paragraphs += createDOCXTable(rows: tableRows)
            inTable = false
            tableRows = []
        }

        // Headers
        if line.hasPrefix("## ") {
            let text = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            // Check if this is a PART header (PART I, PART II, etc.)
            if text.uppercased().hasPrefix("PART ") {
                paragraphs += createDOCXParagraph(text: "◇ ◆ ◇", style: "PartOrnament")
                paragraphs += createDOCXParagraph(text: text, style: "PartHeader")
                paragraphs += createDOCXParagraph(text: "◇ ◆ ◇", style: "PartOrnament")
            } else {
                paragraphs += createDOCXParagraph(text: text, style: "Heading1")
            }
            continue
        }
        if line.hasPrefix("# ") {
            let text = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            // Check if this is a PART header (PART I, PART II, etc.)
            if text.uppercased().hasPrefix("PART ") {
                paragraphs += createDOCXParagraph(text: "◇ ◆ ◇", style: "PartOrnament")
                paragraphs += createDOCXParagraph(text: text, style: "PartHeader")
                paragraphs += createDOCXParagraph(text: "◇ ◆ ◇", style: "PartOrnament")
            } else {
                paragraphs += createDOCXParagraph(text: text, style: "Heading1")
            }
            continue
        }
        if line.hasPrefix("### ") {
            paragraphs += createDOCXParagraph(text: String(line.dropFirst(4)), style: "Heading2")
            continue
        }

        // List items - with space after marker
        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
            paragraphs += createDOCXParagraph(text: "• " + String(line.dropFirst(2)), style: "Normal")
            continue
        }

        // List items - without space after marker
        if line.hasPrefix("-") || line.hasPrefix("*") || line.hasPrefix("•") {
            let text = String(line.dropFirst(1)).trimmingCharacters(in: .whitespaces)
            paragraphs += createDOCXParagraph(text: "• " + text, style: "Normal")
            continue
        }

        // Numbered list items - with space
        if trimmed.range(of: "^\\d+\\.\\s+", options: .regularExpression) != nil {
            paragraphs += createDOCXParagraph(text: trimmed, style: "Normal")
            continue
        }

        // Numbered list items - without space (e.g., "1.Item")
        if trimmed.range(of: "^\\d+\\.", options: .regularExpression) != nil {
            let text = trimmed.replacingOccurrences(of: "^\\d+\\.", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
            let number = trimmed.prefix(while: { $0.isNumber || $0 == "." })
            paragraphs += createDOCXParagraph(text: "\(number) \(text)", style: "Normal")
            continue
        }

        // Regular paragraphs
        if !trimmed.isEmpty {
            paragraphs += createDOCXParagraph(text: trimmed, style: "Normal")
        }
    }

    // Handle any remaining table
    if inTable && !tableRows.isEmpty {
        paragraphs += createDOCXTable(rows: tableRows)
    }

    return """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
            \(paragraphs)
        </w:body>
    </w:document>
    """
}

/// Create a styled block header for DOCX special blocks
static func createDOCXBlockHeader(icon: String, title: String) -> String {
    return """
    <w:p>
        <w:pPr><w:pStyle w:val="BlockHeader"/></w:pPr>
        <w:r><w:t>\(icon) \(title)</w:t></w:r>
    </w:p>
    """
}

/// Create a premium quote block for DOCX with coral border and attribution
static func createDOCXPremiumQuote(content: String) -> String {
    // Parse content for quote text and attribution
    let lines = content.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
    var quoteLines: [String] = []
    var attribution: String? = nil

    for line in lines {
        if line.hasPrefix("—") || line.hasPrefix("-") {
            attribution = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
        } else if !line.isEmpty {
            quoteLines.append(line)
        }
    }

    let quoteText = quoteLines.joined(separator: " ")

    var result = """
    <w:p>
        <w:pPr><w:pStyle w:val="PremiumQuote"/></w:pPr>
        <w:r>
            <w:rPr><w:sz w:val="72"/><w:color w:val="CBA13540"/></w:rPr>
            <w:t>"</w:t>
        </w:r>
        <w:r><w:t>\(escapeXML(quoteText))</w:t></w:r>
    </w:p>
    """

    if let attr = attribution {
        result += """
        <w:p>
            <w:pPr><w:pStyle w:val="PremiumQuoteAttribution"/></w:pPr>
            <w:r><w:t>— \(escapeXML(attr))</w:t></w:r>
        </w:p>
        """
    }

    return result
}

/// Create an author spotlight block for DOCX with double gold border
static func createDOCXAuthorSpotlight(content: String) -> String {
    // Parse content for author name and bio
    let lines = content.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    var authorName: String? = nil
    var bioLines: [String] = []

    for line in lines {
        if authorName == nil {
            authorName = line
        } else {
            bioLines.append(line)
        }
    }

    let bio = bioLines.joined(separator: " ")

    var result = ""

    if let name = authorName {
        result += """
        <w:p>
            <w:pPr><w:pStyle w:val="AuthorSpotlightName"/></w:pPr>
            <w:r><w:t>\(escapeXML(name))</w:t></w:r>
        </w:p>
        """
    }

    if !bio.isEmpty {
        result += """
        <w:p>
            <w:pPr><w:pStyle w:val="AuthorSpotlight"/></w:pPr>
            <w:r><w:t>\(escapeXML(bio))</w:t></w:r>
        </w:p>
        """
    }

    return result
}

/// Create a structured INSIGHT ATLAS NOTE block for DOCX with Key Distinction, Practical Implication, Go Deeper sections
static func createDOCXInsightNote(content: String) -> String {
    var coreConnection = ""
    var keyDistinction: String?
    var practicalImplication: String?
    var goDeeper: String?

    // Normalize content
    let normalizedContent = content.replacingOccurrences(of: "\n", with: " ")

    // Extract Key Distinction
    if let keyStart = normalizedContent.range(of: "Key Distinction:", options: .caseInsensitive) {
        var keyText = String(normalizedContent[keyStart.upperBound...])
        if let practicalStart = keyText.range(of: "Practical Implication:", options: .caseInsensitive) {
            keyText = String(keyText[..<practicalStart.lowerBound])
        } else if let goStart = keyText.range(of: "Go Deeper:", options: .caseInsensitive) {
            keyText = String(keyText[..<goStart.lowerBound])
        }
        keyDistinction = keyText.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Extract Practical Implication
    if let practStart = normalizedContent.range(of: "Practical Implication:", options: .caseInsensitive) {
        var practText = String(normalizedContent[practStart.upperBound...])
        if let goStart = practText.range(of: "Go Deeper:", options: .caseInsensitive) {
            practText = String(practText[..<goStart.lowerBound])
        }
        practicalImplication = practText.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Extract Go Deeper
    if let goStart = normalizedContent.range(of: "Go Deeper:", options: .caseInsensitive) {
        let goText = String(normalizedContent[goStart.upperBound...])
        goDeeper = goText.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Extract core connection (everything before first structured section)
    var coreText = normalizedContent
    if let keyRange = normalizedContent.range(of: "Key Distinction", options: .caseInsensitive) {
        coreText = String(normalizedContent[..<keyRange.lowerBound])
    }
    coreConnection = coreText.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespacesAndNewlines)

    var result = ""

    // Core connection paragraph
    if !coreConnection.isEmpty {
        result += """
        <w:p>
            <w:pPr><w:pStyle w:val="InsightNote"/></w:pPr>
            <w:r><w:t>\(escapeXML(coreConnection))</w:t></w:r>
        </w:p>
        """
    }

    // Key Distinction section with coral/gold accent
    if let key = keyDistinction, !key.isEmpty {
        result += """
        <w:p>
            <w:pPr>
                <w:pStyle w:val="InsightNote"/>
                <w:pBdr>
                    <w:left w:val="single" w:sz="24" w:color="D4735C"/>
                </w:pBdr>
                <w:shd w:val="clear" w:fill="FEF3F0"/>
            </w:pPr>
            <w:r>
                <w:rPr><w:b/><w:caps/><w:sz w:val="18"/><w:color w:val="D4735C"/></w:rPr>
                <w:t>KEY DISTINCTION</w:t>
            </w:r>
        </w:p>
        <w:p>
            <w:pPr>
                <w:pStyle w:val="InsightNote"/>
                <w:pBdr>
                    <w:left w:val="single" w:sz="24" w:color="D4735C"/>
                </w:pBdr>
                <w:shd w:val="clear" w:fill="FEF3F0"/>
            </w:pPr>
            <w:r><w:t>\(escapeXML(key))</w:t></w:r>
        </w:p>
        """
    }

    // Practical Implication section with orange accent
    if let practical = practicalImplication, !practical.isEmpty {
        result += """
        <w:p>
            <w:pPr>
                <w:pStyle w:val="InsightNote"/>
                <w:pBdr>
                    <w:left w:val="single" w:sz="24" w:color="F59E0B"/>
                </w:pBdr>
                <w:shd w:val="clear" w:fill="FFFBEB"/>
            </w:pPr>
            <w:r>
                <w:rPr><w:b/><w:caps/><w:sz w:val="18"/><w:color w:val="D97706"/></w:rPr>
                <w:t>PRACTICAL IMPLICATION</w:t>
            </w:r>
        </w:p>
        <w:p>
            <w:pPr>
                <w:pStyle w:val="InsightNote"/>
                <w:pBdr>
                    <w:left w:val="single" w:sz="24" w:color="F59E0B"/>
                </w:pBdr>
                <w:shd w:val="clear" w:fill="FFFBEB"/>
            </w:pPr>
            <w:r><w:t>\(escapeXML(practical))</w:t></w:r>
        </w:p>
        """
    }

    // Go Deeper section with blue accent
    if let deeper = goDeeper, !deeper.isEmpty {
        result += """
        <w:p>
            <w:pPr>
                <w:pStyle w:val="InsightNote"/>
                <w:pBdr>
                    <w:left w:val="single" w:sz="24" w:color="3B82F6"/>
                </w:pBdr>
                <w:shd w:val="clear" w:fill="EFF6FF"/>
            </w:pPr>
            <w:r>
                <w:rPr><w:b/><w:caps/><w:sz w:val="18"/><w:color w:val="2563EB"/></w:rPr>
                <w:t>GO DEEPER</w:t>
            </w:r>
        </w:p>
        <w:p>
            <w:pPr>
                <w:pStyle w:val="InsightNote"/>
                <w:pBdr>
                    <w:left w:val="single" w:sz="24" w:color="3B82F6"/>
                </w:pBdr>
                <w:shd w:val="clear" w:fill="EFF6FF"/>
            </w:pPr>
            <w:r>
                <w:rPr><w:i/></w:rPr>
                <w:t>\(escapeXML(deeper))</w:t>
            </w:r>
        </w:p>
        """
    }

    return result
}

static func createDOCXParagraph(text: String, style: String) -> String {
    // Parse markdown formatting and convert to DOCX runs with proper styling
    let runs = parseMarkdownToDocxRuns(text)

    return """
    <w:p>
        <w:pPr><w:pStyle w:val="\(style)"/></w:pPr>
        \(runs)
    </w:p>
    """
}

/// Parse markdown bold/italic and convert to DOCX runs with proper formatting
static func parseMarkdownToDocxRuns(_ rawText: String) -> String {
    var text = PresentationTextSanitizer.attributedMarkupSource(rawText)
    text = text.replacingOccurrences(
        of: #"__([^_\n]+)__"#,
        with: "**$1**",
        options: .regularExpression
    )
    text = text.replacingOccurrences(
        of: #"(?<![_\w])_([^_\n]+)_(?![_\w])"#,
        with: "*$1*",
        options: .regularExpression
    )

    var result = ""
    var currentIndex = text.startIndex
    let endIndex = text.endIndex

    while currentIndex < endIndex {
        // Check for bold (**text**)
        if text[currentIndex...].hasPrefix("**") {
            let afterOpening = text.index(currentIndex, offsetBy: 2)
            if let closingRange = text.range(of: "**", range: afterOpening..<endIndex) {
                let boldText = String(text[afterOpening..<closingRange.lowerBound])
                result += "<w:r><w:rPr><w:b/></w:rPr><w:t>\(escapeXML(boldText))</w:t></w:r>"
                currentIndex = closingRange.upperBound
                continue
            }
        }

        // Check for italic (*text*) - but not bold
        if text[currentIndex...].hasPrefix("*") && !text[currentIndex...].hasPrefix("**") {
            let afterOpening = text.index(after: currentIndex)
            if afterOpening < endIndex {
                // Find closing * that isn't part of **
                var searchIndex = afterOpening
                while searchIndex < endIndex {
                    if text[searchIndex] == "*" {
                        // Check it's not part of **
                        let nextIndex = text.index(after: searchIndex)
                        if nextIndex >= endIndex || text[nextIndex] != "*" {
                            let italicText = String(text[afterOpening..<searchIndex])
                            result += "<w:r><w:rPr><w:i/></w:rPr><w:t>\(escapeXML(italicText))</w:t></w:r>"
                            currentIndex = text.index(after: searchIndex)
                            break
                        }
                    }
                    searchIndex = text.index(after: searchIndex)
                }
                if searchIndex >= endIndex {
                    // No closing found, treat as regular text
                    result += "<w:r><w:t>\(escapeXML(String(text[currentIndex])))</w:t></w:r>"
                    currentIndex = text.index(after: currentIndex)
                }
                continue
            }
        }

        // An unmatched asterisk is malformed presentation syntax. Drop it
        // and advance so the serializer can never spin at the same index.
        if text[currentIndex] == "*" {
            currentIndex = text.index(after: currentIndex)
            continue
        }

        // Regular text - collect until next formatting marker
        var regularText = ""
        while currentIndex < endIndex && !text[currentIndex...].hasPrefix("*") {
            regularText += String(text[currentIndex])
            currentIndex = text.index(after: currentIndex)
        }
        if !regularText.isEmpty {
            result += "<w:r><w:t>\(escapeXML(regularText))</w:t></w:r>"
        }
    }

    return result
}

/// Creates a DOCX-formatted table from parsed rows
static func createDOCXTable(rows: [[String]]) -> String {
    guard !rows.isEmpty else { return "" }

    var tableXML = """
    <w:tbl>
        <w:tblPr>
            <w:tblStyle w:val="TableGrid"/>
            <w:tblW w:w="5000" w:type="pct"/>
            <w:tblBorders>
                <w:top w:val="single" w:sz="4" w:color="CBA135"/>
                <w:left w:val="single" w:sz="4" w:color="CBA135"/>
                <w:bottom w:val="single" w:sz="4" w:color="CBA135"/>
                <w:right w:val="single" w:sz="4" w:color="CBA135"/>
                <w:insideH w:val="single" w:sz="4" w:color="E8E4DC"/>
                <w:insideV w:val="single" w:sz="4" w:color="E8E4DC"/>
            </w:tblBorders>
        </w:tblPr>
    """

    for (rowIndex, row) in rows.enumerated() {
        tableXML += "<w:tr>"

        for cell in row {
            // Parse cell content for bold/italic formatting
            let cellRuns = parseMarkdownToDocxRuns(cell)

            if rowIndex == 0 {
                // Header row with gold background - override runs with bold white text
                let headerText = cell.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "*", with: "")
                tableXML += """
                <w:tc>
                    <w:tcPr>
                        <w:shd w:val="clear" w:fill="CBA135"/>
                    </w:tcPr>
                    <w:p>
                        <w:pPr>
                            <w:jc w:val="left"/>
                        </w:pPr>
                        <w:r>
                            <w:rPr>
                                <w:b/>
                                <w:color w:val="FFFFFF"/>
                                <w:sz w:val="22"/>
                            </w:rPr>
                            <w:t>\(escapeXML(headerText))</w:t>
                        </w:r>
                    </w:p>
                </w:tc>
                """
            } else {
                // Data row with alternating background - preserve formatting
                let bgColor = rowIndex % 2 == 0 ? "FFFFFF" : "F5F3ED"
                tableXML += """
                <w:tc>
                    <w:tcPr>
                        <w:shd w:val="clear" w:fill="\(bgColor)"/>
                    </w:tcPr>
                    <w:p>
                        \(cellRuns)
                    </w:p>
                </w:tc>
                """
            }
        }

        tableXML += "</w:tr>"
    }

    tableXML += "</w:tbl>"

    // Add spacing after table
    tableXML += """
    <w:p>
        <w:pPr><w:spacing w:after="200"/></w:pPr>
    </w:p>
    """

    return tableXML
}

static func escapeXML(_ string: String) -> String {
    return string
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&apos;")
}

static func createZipArchive(from sourceDir: URL, to destinationURL: URL) throws {
    let fileManager = FileManager.default
    // Remove existing file if present
    if fileManager.fileExists(atPath: destinationURL.path) {
        try fileManager.removeItem(at: destinationURL)
    }

    // Use NSFileCoordinator to create proper DOCX archive (native iOS API)
    let coordinator = NSFileCoordinator()
    var coordinatorError: NSError?

    coordinator.coordinate(readingItemAt: sourceDir, options: .forUploading, error: &coordinatorError) { zipURL in
        do {
            try FileManager.default.copyItem(at: zipURL, to: destinationURL)
        } catch {
            // If copy fails, try moving
            try? FileManager.default.moveItem(at: zipURL, to: destinationURL)
        }
    }

    if let coordinatorError = coordinatorError {
        throw DataManagerError.zipArchiveFailed(reason: coordinatorError.localizedDescription)
    }
}

}
