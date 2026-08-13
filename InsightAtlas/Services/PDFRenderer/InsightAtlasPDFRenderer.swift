import UIKit
import UIKit
import CoreGraphics
import PDFKit
import CryptoKit
import os.log

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

    private static let densityLog = Logger(subsystem: "com.insightatlas", category: "PDFDensityAudit")

    private var currentPage: Int = 0
    private var tableOfContents: [(title: String, page: Int, isSubsection: Bool)] = []

    /// DEBUG-only record of trailing whitespace left on each content page when a
    /// block is pushed to the next page. Used to quantify the "half-empty page"
    /// problem on a real render before deciding whether callout-splitting is
    /// worth building. Populated only in DEBUG builds; empty otherwise.
    private var debugTrailingGaps: [(page: Int, gap: CGFloat, cause: String)] = []

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
    func render(document rawDocument: PDFAnalysisDocument, options: RenderOptions = .default) throws -> RenderResult {
        // Single post-assembly pass: promote arrow-chain diagrams, number
        // figures/tables, and enforce referential integrity before any pixels.
        // DEBUG aborts on violations; Release auto-repairs and logs.
        let document = try PDFDocumentProcessor.process(rawDocument).document

        // Detection-only: report note "dumps" for authoring follow-up.
        auditNoteDensity(document)

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

    /// Detection-only density audit. A card "dump" — consecutive Insight Notes
    /// with no synthesis paragraph between them — can't be fixed by the renderer
    /// (the fix is authored prose or a card merge), so we report it for human
    /// action instead of papering over it with spacing. Reported by section +
    /// block index; page numbers await the unified paginator (TOC stage). A run
    /// breaks only on a synthesis block (`.paragraph` / `.foundationalNarrative`)
    /// — headings, dividers, and diagrams between two notes still count as a dump.
    private func auditNoteDensity(_ document: PDFAnalysisDocument) {
        var runs: [String] = []
        for (si, section) in document.sections.enumerated() {
            var runStart: Int?
            var runCount = 0
            func flush(_ endIndex: Int) {
                if runCount >= 2, let start = runStart {
                    let name = section.heading ?? "untitled"
                    runs.append("§\(si + 1) “\(name)”: \(runCount) consecutive notes (blocks \(start)–\(endIndex)) with no synthesis paragraph between")
                }
                runStart = nil
                runCount = 0
            }
            for (bi, block) in section.blocks.enumerated() {
                switch block.type {
                case .insightNote:
                    if runStart == nil { runStart = bi }
                    runCount += 1
                case .paragraph, .foundationalNarrative:
                    flush(bi - 1)   // a synthesis paragraph resets the run
                default:
                    break            // headings/dividers/visuals aren't synthesis
                }
            }
            flush(section.blocks.count - 1)
        }
        if runs.isEmpty {
            Self.densityLog.info("Note-density audit: OK — no card dumps")
        } else {
            Self.densityLog.warning("Note-density audit — \(runs.count) run(s) need a synthesis paragraph or a merge:\n\(runs.joined(separator: "\n"))")
        }
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
        // This is the RICH parser path (not lossy/legacy) — say so, because the old
        // "raw markdown path" wording read as a warning and nearly triggered a false
        // "reopen routing" alarm.
        print("ℹ️ [PDF Renderer] rich parser (PDFAnalysisDocument.parse) — builds real table/visual blocks and #/##/premium-H1 sections")
        // Build/content identity stamp — ends the stale-plausible-producer
        // diagnosis cycles. A genuine regen changes `content`; a rebuild+relaunch
        // changes `linked`. Same content hash on a "fresh" export == stale content
        // (re-export of unchanged markdown); same linked date == stale binary
        // (BuildProject compiled but the app wasn't ⌘R-relaunched).
        let contentHash = SHA256.hash(data: Data(markdownContent.utf8))
            .prefix(4).map { String(format: "%02x", $0) }.joined()
        let linkedAt: String = {
            guard let url = Bundle.main.executableURL,
                  let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let date = attrs[.modificationDate] as? Date else { return "unknown" }
            let f = DateFormatter()
            f.dateFormat = "MMM d HH:mm"
            return f.string(from: date)
        }()
        print("📌 [PDF Build Stamp] binary linked \(linkedAt) · content \(contentHash) · \(markdownContent.count) chars")
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

        // Pass the PDF renderer so a TOC that overflows one page can begin real
        // additional pages. Without it, `renderTableOfContents` repaints the
        // background over the existing entries/header and redraws on the same
        // page, leaving only the final overflow batch visible (a TOC showing
        // just its last entries with no "Contents" header).
        let tocPageCount = coverRenderer.renderTableOfContents(
            to: context.cgContext,
            sections: tableOfContents,
            pdfRenderer: context
        )

        // Account for any additional pages the TOC spilled onto so page
        // numbering stays correct for subsequent content.
        if tocPageCount > 1 {
            currentPage += (tocPageCount - 1)
        }
    }

    private func renderContentPages(context: UIGraphicsPDFRendererContext, document: PDFAnalysisDocument, options: RenderOptions) {
        debugTrailingGaps.removeAll()
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
            let pageBudget = contentRect.height

            if currentY + height <= contentRect.maxY {
                // Fits in the remaining space on the current page.
                blockRenderer.renderBlock(
                    quickGlanceBlock,
                    to: context.cgContext,
                    at: CGPoint(x: contentRect.minX, y: currentY),
                    maxWidth: contentRect.width
                )
                currentY += height
            } else if height <= pageBudget {
                // Fits on a fresh page as a single card.
                startNewContentPage(context: context, options: options)
                currentY = contentRect.minY
                blockRenderer.renderBlock(
                    quickGlanceBlock,
                    to: context.cgContext,
                    at: CGPoint(x: contentRect.minX, y: currentY),
                    maxWidth: contentRect.width
                )
                currentY += height
            } else {
                // Taller than a whole page: split into self-contained cards,
                // each on its own page, so nothing clips off the bottom edge.
                let fragments = blockRenderer.planQuickGlanceFragments(
                    coreMessage: quickGlance.coreMessage,
                    keyPoints: quickGlance.keyPoints,
                    maxWidth: contentRect.width,
                    pageBudget: pageBudget
                )
                for (index, fragment) in fragments.enumerated() {
                    if index > 0 || currentY > contentRect.minY {
                        startNewContentPage(context: context, options: options)
                        currentY = contentRect.minY
                    }
                    let drawn = blockRenderer.renderQuickGlance(
                        coreMessage: fragment.coreMessage,
                        keyPoints: fragment.keyPoints,
                        readingTime: index == 0 ? "\(quickGlance.readingTime)" : nil,
                        to: context.cgContext,
                        at: CGPoint(x: contentRect.minX, y: currentY),
                        maxWidth: contentRect.width,
                        continued: fragment.continued
                    )
                    currentY += drawn
                }
            }
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

                // Calculate first block height to avoid orphaned headings.
                // Keep the heading with its ENTIRE first block when that block
                // fits on a page — otherwise the heading renders at the bottom
                // and the (taller) block is pushed to the next page, stranding
                // the heading. Only fall back to a minimum reserve when the
                // following block is itself taller than a page (unavoidable).
                let firstBlockHeight = section.blocks.first.map {
                    blockRenderer.calculateBlockHeight(block: $0, maxWidth: contentRect.width)
                } ?? 0
                // Only keep them together if both actually fit on one page;
                // if the block is so tall that heading+block can't co-exist on
                // any page, keeping them together is impossible — reserve a
                // minimum instead (the unavoidable case).
                let headingReserve = (headingHeight + firstBlockHeight) <= contentRect.height
                    ? firstBlockHeight
                    : minContentAfterHeading
                let combinedHeight = headingHeight + headingReserve

                // Check if heading + its content fits, otherwise start new page
                if needsNewPage || currentY + combinedHeight > contentRect.maxY - 30 {
                    if !needsNewPage {
                        recordTrailingGap(at: currentY, cause: "section heading kept with next (\(heading))")
                    }
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

                // Skip rendering empty content blocks. Metadata-only types
                // (dividers, library entries, reading chips) carry no
                // `content`/`listItems` by design — and so do TABLE blocks (data in
                // `tableData`) and VISUAL blocks (image in `visualURL`), which have
                // `content == ""`. Those were being silently dropped here despite
                // being registered/numbered upstream — the exact cause of Table 1/
                // Table 2 appearing in the 📊 manifest but never on the page. Treat
                // tableData/visualURL as content so they are not filtered.
                let metadataOnlyTypes: Set<PDFContentBlock.BlockType> = [.divider, .libraryEntry, .readingChip]
                let hasTableData = !(block.tableData?.isEmpty ?? true)
                let hasVisual = block.visualURL != nil
                if block.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   (block.listItems?.isEmpty ?? true) &&
                   !hasTableData &&
                   !hasVisual &&
                   !metadataOnlyTypes.contains(block.type) {
                    // Log the skip — the whole reason Table 1/2 sat undiagnosed was
                    // a silent drop between "manifest says exists" and "page shows
                    // nothing". A genuinely-empty block now leaves a trace.
                    print("⏭️ [PDF Renderer] skipped empty block (type=\(block.type)) — no content/listItems/tableData/visualURL")
                    continue
                }

                // Oversized-exercise fragmentation (Option A). An exercise card
                // that won't fit in the space left on this page is SPLIT into
                // self-contained cards instead of being pushed whole to the next
                // page (which stranded its section heading and left a trailing
                // gap — the page-80 case). Fragment 1 fills the remaining space
                // under the heading; the rest continue on fresh pages. Mirrors the
                // Quick Glance fragmentation path above; see planExerciseFragments.
                if block.type == .exercise && currentY + blockHeight > contentRect.maxY {
                    let exTitle = block.metadata?["title"] ?? "Exercise"
                    let exTime = block.metadata?["time"]
                    let exSteps = block.listItems ?? []
                    var firstBudget = contentRect.maxY - currentY
                    let minFirst = blockRenderer.minExerciseFragmentHeight(title: exTitle, content: block.content, steps: exSteps, maxWidth: contentRect.width)

                    // Not enough room to start a non-runt first fragment here —
                    // break first, then fragment against a full page.
                    if firstBudget < minFirst {
                        recordTrailingGap(at: currentY, cause: debugBlockLabel(block, height: blockHeight) + " (exercise: insufficient head room to fragment)")
                        startNewContentPage(context: context, options: options)
                        currentY = contentRect.minY
                        firstBudget = contentRect.height
                    }

                    // If it now fits whole (only overflowed the old page tail),
                    // draw it atomically — no need to fragment.
                    if currentY + blockHeight <= contentRect.maxY {
                        let drawn = blockRenderer.renderBlock(block, to: context.cgContext, at: CGPoint(x: contentRect.minX, y: currentY), maxWidth: contentRect.width)
                        currentY += drawn
                        continue
                    }

                    let fragments = blockRenderer.planExerciseFragments(
                        title: exTitle, content: block.content, steps: exSteps,
                        estimatedTime: exTime, maxWidth: contentRect.width,
                        firstBudget: firstBudget, pageBudget: contentRect.height)

                    if fragments.count > 1 {
                        print("✂️ [PDF Renderer] fragmented exercise \"\(exTitle)\" into \(fragments.count) cards across pages (\(exSteps.count) steps)")
                    }

                    for (fIndex, frag) in fragments.enumerated() {
                        if fIndex > 0 {
                            recordTrailingGap(at: currentY, cause: "exercise fragment \(fIndex) continues on next page")
                            startNewContentPage(context: context, options: options)
                            currentY = contentRect.minY
                        }
                        let drawn = blockRenderer.renderExercise(
                            content: frag.content, title: frag.title, steps: frag.steps,
                            estimatedTime: frag.estimatedTime,
                            to: context.cgContext, at: CGPoint(x: contentRect.minX, y: currentY),
                            maxWidth: contentRect.width, continued: frag.continued, startNumber: frag.startNumber)
                        currentY += drawn
                    }
                    continue
                }

                // Oversized-insight-note fragmentation (parallel to the exercise
                // branch above). A SPLITTABLE note (not KEY CHALLENGE) that won't
                // fit the space left on this page is split at section seams
                // instead of pushed whole — the dominant whitespace source. KEY
                // CHALLENGE notes and notes that can't split into floor-worthy
                // fragments fall through to the normal push-whole path.
                if block.type == .insightNote && currentY + blockHeight > contentRect.maxY {
                    let noteTitle = block.metadata?["title"] ?? "Insight Atlas Note"
                    if blockRenderer.insightNoteIsSplittable(content: block.content, title: noteTitle) {
                        let remaining = contentRect.maxY - currentY
                        // First try to fill the remaining space; if it can't host a
                        // floor-worthy first fragment, break to a fresh page and
                        // split against a full page (never into sub-floor space).
                        var fragments = blockRenderer.planInsightNoteFragments(content: block.content, title: noteTitle, maxWidth: contentRect.width, firstBudget: remaining, pageBudget: contentRect.height)
                        var brokeFirst = false
                        if fragments == nil {
                            fragments = blockRenderer.planInsightNoteFragments(content: block.content, title: noteTitle, maxWidth: contentRect.width, firstBudget: contentRect.height, pageBudget: contentRect.height)
                            brokeFirst = true
                        }
                        if let frags = fragments, frags.count > 1 {
                            print("✂️ [PDF Renderer] fragmented insight note into \(frags.count) cards across pages")
                            if brokeFirst {
                                recordTrailingGap(at: currentY, cause: debugBlockLabel(block, height: blockHeight) + " (insight note: insufficient head room to fragment)")
                                startNewContentPage(context: context, options: options)
                                currentY = contentRect.minY
                            }
                            for (fIndex, frag) in frags.enumerated() {
                                if fIndex > 0 {
                                    recordTrailingGap(at: currentY, cause: "insight note fragment \(fIndex) continues on next page")
                                    startNewContentPage(context: context, options: options)
                                    currentY = contentRect.minY
                                }
                                let drawn = blockRenderer.renderInsightNoteFragment(frag, to: context.cgContext, at: CGPoint(x: contentRect.minX, y: currentY), maxWidth: contentRect.width)
                                currentY += drawn
                            }
                            continue
                        }
                        // else: not worth splitting → fall through to push-whole
                    }
                }

                // Oversized-table fragmentation (row-atomic, header repeats). A
                // table that won't fit the space left on this page splits at row
                // boundaries; each fragment is a complete small table (repeated
                // header + a subset of data rows). The figure caption rides
                // fragment 1 only. Tables with <4 data rows push whole.
                if block.type == .table && currentY + blockHeight > contentRect.maxY {
                    let rows = block.tableData ?? []
                    let captionH = blockRenderer.tableCaptionHeight(for: block)
                    let remaining = contentRect.maxY - currentY
                    // Fragment 1 must leave room for the caption drawn above it.
                    var fragments = blockRenderer.planTableFragments(tableData: rows, maxWidth: contentRect.width, firstBudget: remaining - captionH, pageBudget: contentRect.height)
                    var brokeFirst = false
                    if fragments == nil {
                        fragments = blockRenderer.planTableFragments(tableData: rows, maxWidth: contentRect.width, firstBudget: contentRect.height - captionH, pageBudget: contentRect.height)
                        brokeFirst = true
                    }
                    if let frags = fragments, frags.count > 1 {
                        print("✂️ [PDF Renderer] fragmented table into \(frags.count) cards across pages (\(max(0, rows.count - 1)) data rows)")
                        if brokeFirst {
                            recordTrailingGap(at: currentY, cause: debugBlockLabel(block, height: blockHeight) + " (table: insufficient head room to fragment)")
                            startNewContentPage(context: context, options: options)
                            currentY = contentRect.minY
                        }
                        // Caption once, above fragment 1.
                        currentY += blockRenderer.renderTableCaption(for: block, to: context.cgContext, at: CGPoint(x: contentRect.minX, y: currentY), maxWidth: contentRect.width)
                        for (fIndex, frag) in frags.enumerated() {
                            if fIndex > 0 {
                                recordTrailingGap(at: currentY, cause: "table fragment \(fIndex) continues on next page")
                                startNewContentPage(context: context, options: options)
                                currentY = contentRect.minY
                            }
                            let drawn = blockRenderer.renderTableFragment(frag, to: context.cgContext, at: CGPoint(x: contentRect.minX, y: currentY), maxWidth: contentRect.width)
                            currentY += drawn
                        }
                        continue
                    }
                    // else: not worth splitting → fall through to push-whole
                }

                // Diagram scale-to-fit. A vector diagram (flowchart/etc.) that
                // would push whole and strand a big gap is instead scaled
                // uniformly to fill the remaining space — unless that scale falls
                // below the legibility floor, in which case it pushes whole at
                // 100%. Diagrams scale continuously (unlike atomic text blocks),
                // so this is the one lever that changes the height distribution.
                if PDFContentBlockRenderer.scalableDiagramTypes.contains(block.type) {
                    let remaining = contentRect.maxY - currentY
                    switch blockRenderer.diagramScaleDecision(naturalHeight: blockHeight, remaining: remaining) {
                    case .fits:
                        break   // fall through to the normal render path
                    case .scale(let factor, let target):
                        let drawn = blockRenderer.renderDiagramScaledToFit(block, factor: factor, target: target, to: context.cgContext, at: CGPoint(x: contentRect.minX, y: currentY), maxWidth: contentRect.width)
                        print("🔎 [PDF Renderer] scaled \(block.type) to \(Int((factor * 100).rounded()))% to fill remaining space (\(Int(blockHeight.rounded()))pt → \(Int(target.rounded()))pt)")
                        currentY += drawn
                        continue
                    case .pushWhole:
                        // Scale would be illegible → fresh page at 100%.
                        recordTrailingGap(at: currentY, cause: debugBlockLabel(block, height: blockHeight) + " (diagram scale < legibility floor — pushed whole)")
                        startNewContentPage(context: context, options: options)
                        currentY = contentRect.minY
                        let drawn = blockRenderer.renderBlock(block, to: context.cgContext, at: CGPoint(x: contentRect.minX, y: currentY), maxWidth: contentRect.width)
                        currentY += drawn
                        continue
                    }
                }

                // Check if this is a heading block - apply widow/orphan control
                let isHeadingBlock = [.heading1, .heading2, .heading3, .heading4, .premiumH1, .premiumH2].contains(block.type)
                if isHeadingBlock {
                    // Look ahead to see if there's content after this heading.
                    // Keep the heading with its whole next block when that block
                    // fits on a page (see section-heading logic above), so a
                    // heading is never left stranded at the bottom of a page.
                    let nextBlockHeight = (index + 1 < section.blocks.count) ?
                        blockRenderer.calculateBlockHeight(block: section.blocks[index + 1], maxWidth: contentRect.width) : 0
                    // Keep together only if both fit on one page (see above).
                    let nextReserve = (blockHeight + nextBlockHeight) <= contentRect.height
                        ? nextBlockHeight
                        : minContentAfterHeading
                    let combinedHeight = blockHeight + nextReserve

                    if currentY + combinedHeight > contentRect.maxY - 30 {
                        recordTrailingGap(at: currentY, cause: debugBlockLabel(block, height: blockHeight) + " (heading kept with next)")
                        startNewContentPage(context: context, options: options)
                        currentY = contentRect.minY
                    }
                } else if currentY + blockHeight > contentRect.maxY {
                    // Regular block - just check if it fits
                    recordTrailingGap(at: currentY, cause: debugBlockLabel(block, height: blockHeight) + " pushed whole")
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

        // Record the final content page's trailing gap and print a summary.
        recordTrailingGap(at: currentY, cause: "end of content")
        logWhitespaceSummary()

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

    // MARK: - Whitespace instrumentation (DEBUG)

    /// Record the trailing gap left on the current page at the moment a block is
    /// pushed to the next one. `cause` is an @autoclosure so its (potentially
    /// parsing) work is skipped entirely in release builds.
    private func recordTrailingGap(at currentY: CGFloat, cause: @autoclosure () -> String) {
        #if DEBUG
        let gap = contentRect.maxY - currentY
        guard gap > 1 else { return }
        let entry = (page: currentPage, gap: gap, cause: cause())
        debugTrailingGaps.append(entry)
        print("[PDF whitespace] page \(entry.page): \(Int(gap.rounded()))pt gap before break — \(entry.cause)")
        #endif
    }

    /// Print an aggregate summary of trailing whitespace across the render.
    private func logWhitespaceSummary() {
        #if DEBUG
        guard !debugTrailingGaps.isEmpty else {
            print("[PDF whitespace] no mid-page breaks recorded")
            return
        }
        let gaps = debugTrailingGaps.map { $0.gap }
        let total = gaps.reduce(0, +)
        let maxGap = gaps.max() ?? 0
        let avg = total / CGFloat(gaps.count)
        let pageFrac = contentRect.height > 0 ? (avg / contentRect.height) : 0
        let bigGaps = gaps.filter { $0 > 150 }.count
        print("""
        [PDF whitespace] SUMMARY — \(gaps.count) mid-page breaks; \
        avg gap \(Int(avg.rounded()))pt (\(Int((pageFrac * 100).rounded()))% of page), \
        max \(Int(maxGap.rounded()))pt, \(bigGaps) breaks left >150pt empty. \
        Page content height: \(Int(contentRect.height.rounded()))pt.
        """)
        #endif
    }

    /// A short DEBUG label describing a block for whitespace logs.
    private func debugBlockLabel(_ block: PDFContentBlock, height: CGFloat) -> String {
        let sections = blockRenderer.debugCalloutSectionCount(for: block)
        let sectionNote = sections > 0 ? " sections=\(sections)" : ""
        return "\(block.type) h=\(Int(height.rounded()))pt\(sectionNote)"
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
        // Was width: 100 — too narrow for "INSIGHT ATLAS" at 12pt + 1.0 kern, so it
        // clipped to "INSIGHT". Give it real room (it renders left-aligned anyway).
        let headerRect = CGRect(x: contentRect.minX, y: headerY, width: 240, height: headerHeight)
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

                // Calculate first block height to ensure we don't orphan headings.
                // Mirror the render-time keep-together reserve so estimated page
                // numbers track where headings actually land.
                let firstBlockHeight = section.blocks.first.map { blockRenderer.calculateBlockHeight(block: $0, maxWidth: contentRect.width) } ?? 0
                let headingReserve = (headingHeight + firstBlockHeight) <= contentRect.height
                    ? firstBlockHeight
                    : minContentAfterHeading
                let combinedHeight = headingHeight + headingReserve

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

                // Mirror render-time exercise fragmentation (Option A) so page
                // numbers for everything AFTER a tall exercise don't drift when
                // that exercise now spans multiple pages. Kept in lockstep with
                // the render loop above.
                if block.type == .exercise && currentY + blockHeight > contentRect.maxY {
                    let exTitle = block.metadata?["title"] ?? "Exercise"
                    let exSteps = block.listItems ?? []
                    var firstBudget = contentRect.maxY - currentY
                    let minFirst = blockRenderer.minExerciseFragmentHeight(title: exTitle, content: block.content, steps: exSteps, maxWidth: contentRect.width)
                    if firstBudget < minFirst {
                        estimatedPage += 1
                        currentY = contentRect.minY
                        firstBudget = contentRect.height
                    }
                    if currentY + blockHeight <= contentRect.maxY {
                        currentY += blockHeight
                    } else {
                        let fragments = blockRenderer.planExerciseFragments(
                            title: exTitle, content: block.content, steps: exSteps,
                            estimatedTime: block.metadata?["time"], maxWidth: contentRect.width,
                            firstBudget: firstBudget, pageBudget: contentRect.height)
                        for (fIndex, frag) in fragments.enumerated() {
                            if fIndex > 0 {
                                estimatedPage += 1
                                currentY = contentRect.minY
                            }
                            currentY += frag.plannedHeight
                        }
                    }
                    continue   // exercise is not a TOC-tracked type; skip the switch + tail add
                }

                // Mirror render-time insight-note fragmentation so page numbers
                // don't drift when a splittable note spans multiple pages.
                if block.type == .insightNote && currentY + blockHeight > contentRect.maxY {
                    let noteTitle = block.metadata?["title"] ?? "Insight Atlas Note"
                    if blockRenderer.insightNoteIsSplittable(content: block.content, title: noteTitle) {
                        let remaining = contentRect.maxY - currentY
                        var frags = blockRenderer.planInsightNoteFragments(content: block.content, title: noteTitle, maxWidth: contentRect.width, firstBudget: remaining, pageBudget: contentRect.height)
                        var brokeFirst = false
                        if frags == nil {
                            frags = blockRenderer.planInsightNoteFragments(content: block.content, title: noteTitle, maxWidth: contentRect.width, firstBudget: contentRect.height, pageBudget: contentRect.height)
                            brokeFirst = true
                        }
                        if let fragments = frags, fragments.count > 1 {
                            if brokeFirst { estimatedPage += 1; currentY = contentRect.minY }
                            for (fIndex, frag) in fragments.enumerated() {
                                if fIndex > 0 { estimatedPage += 1; currentY = contentRect.minY }
                                currentY += frag.plannedHeight
                            }
                            continue   // insight note is not a TOC-tracked type
                        }
                    }
                }

                // Mirror render-time table fragmentation so page numbers don't
                // drift when a big table spans multiple pages.
                if block.type == .table && currentY + blockHeight > contentRect.maxY {
                    let rows = block.tableData ?? []
                    let captionH = blockRenderer.tableCaptionHeight(for: block)
                    let remaining = contentRect.maxY - currentY
                    var frags = blockRenderer.planTableFragments(tableData: rows, maxWidth: contentRect.width, firstBudget: remaining - captionH, pageBudget: contentRect.height)
                    var brokeFirst = false
                    if frags == nil {
                        frags = blockRenderer.planTableFragments(tableData: rows, maxWidth: contentRect.width, firstBudget: contentRect.height - captionH, pageBudget: contentRect.height)
                        brokeFirst = true
                    }
                    if let fragments = frags, fragments.count > 1 {
                        if brokeFirst { estimatedPage += 1; currentY = contentRect.minY }
                        currentY += captionH
                        for (fIndex, frag) in fragments.enumerated() {
                            if fIndex > 0 { estimatedPage += 1; currentY = contentRect.minY }
                            currentY += frag.plannedHeight
                        }
                        continue   // table is not a TOC-tracked type
                    }
                }

                // Mirror render-time diagram scale-to-fit so page estimates track
                // whether a diagram fills the current page (scaled) or pushes to a
                // fresh one (floor-bound). Diagrams aren't TOC-tracked types.
                if PDFContentBlockRenderer.scalableDiagramTypes.contains(block.type) {
                    let remaining = contentRect.maxY - currentY
                    switch blockRenderer.diagramScaleDecision(naturalHeight: blockHeight, remaining: remaining) {
                    case .fits:
                        currentY += blockHeight
                        continue
                    case .scale(_, let target):
                        currentY += target          // fills to maxY; next block starts fresh
                        continue
                    case .pushWhole:
                        estimatedPage += 1
                        currentY = contentRect.minY + blockHeight
                        continue
                    }
                }

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

                case .premiumH1:
                    let headingTitle = block.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !headingTitle.isEmpty && !tableOfContents.contains(where: { $0.title == headingTitle }) {
                        tableOfContents.append((title: headingTitle, page: estimatedPage, isSubsection: false))
                    }

                case .premiumH2:
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
