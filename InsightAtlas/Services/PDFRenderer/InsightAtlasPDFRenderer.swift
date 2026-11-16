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

    /// One table-of-contents row. Page numbers come from an actual layout pass
    /// (the renderer runs the content layout, records where each heading
    /// landed, and re-renders with those numbers), never from an estimate.
    struct TOCEntry: Equatable {
        var title: String
        var page: Int
        var isSubsection: Bool
        var descriptor: String? = nil
        var minutes: Int? = nil
    }

    private var currentPage: Int = 0
    /// Entries printed on the Contents page for the pass in progress.
    private var tableOfContents: [TOCEntry] = []
    /// Entries recorded while laying out content in the pass in progress.
    private var recordedTOC: [TOCEntry] = []
    /// Reading minutes per heading (and "Quick Glance"), computed once per document.
    private var readingMinutes: [String: Int] = [:]
    /// Running header state: the book title (short form) and the section in effect.
    private var runningBookTitle: String = ""
    private var runningSectionTitle: String = ""
    private var documentHasLevelOneHeadings: Bool = false
    /// Page index of the last front-matter page (cover + contents); the running
    /// header starts after it.
    private var lastFrontMatterPage: Int = 0

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

        readingMinutes = Self.computeReadingMinutes(document)
        runningBookTitle = Self.shortTitle(document.book.title)
        documentHasLevelOneHeadings = Self.hasLevelOneHeadings(document)

        // Layout-verified table of contents (elevation spec A2): the first pass
        // lays the content out against a placeholder Contents page with the
        // right NUMBER of rows (so the content starts on the same page it will
        // finally start on) and records where every heading lands; the next
        // pass prints those numbers. A third pass only runs if the recorded
        // entries still moved (a Contents page that spilled over).
        var toc = Self.placeholderTOC(for: document)
        var pdfData = Data()
        for _ in 0..<3 {
            pdfData = renderPass(document: document, options: options, toc: toc)
            if recordedTOC == toc { break }
            toc = recordedTOC
        }

        return RenderResult(
            pdfData: pdfData,
            pageCount: currentPage,
            documentTitle: document.book.title
        )
    }

    /// One complete render of the document with the given Contents rows.
    private func renderPass(document: PDFAnalysisDocument, options: RenderOptions, toc: [TOCEntry]) -> Data {
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        currentPage = 0
        tableOfContents = toc
        recordedTOC = []
        runningSectionTitle = ""
        lastFrontMatterPage = 0

        return pdfRenderer.pdfData { context in
            // Cover page
            if options.includeCoverPage {
                renderCoverPage(context: context, document: document, options: options)
            }

            // Table of contents page
            if options.includeTableOfContents && !tableOfContents.isEmpty {
                renderTableOfContentsPage(context: context, options: options)
            }
            lastFrontMatterPage = currentPage

            // Content pages
            renderContentPages(context: context, document: document, options: options)
        }
    }

    /// Titles the Contents page will carry, in order, with no page numbers yet.
    /// Must mirror what `renderContentPages` records so the Contents page has
    /// the same row count on the first pass as on the last.
    static func placeholderTOC(for document: PDFAnalysisDocument) -> [TOCEntry] {
        var entries: [TOCEntry] = []
        var seen: Set<String> = []
        func add(_ title: String, _ isSub: Bool, _ descriptor: String?) {
            let key = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, !seen.contains(key) else { return }
            seen.insert(key)
            entries.append(TOCEntry(title: key, page: 0, isSubsection: isSub, descriptor: descriptor, minutes: nil))
        }
        let hasLevelOne = hasLevelOneHeadings(document)
        if document.quickGlance != nil { add("Quick Glance", false, nil) }
        for section in document.sections {
            if section.blocks.isEmpty && section.heading == nil { continue }
            if let heading = section.heading {
                let isPART = heading.uppercased().hasPrefix("PART ")
                add(heading, !(section.headingLevel == 1 || isPART || !hasLevelOne), section.descriptor)
            }
            for block in section.blocks {
                switch block.type {
                case .heading3, .heading2, .premiumH2:
                    add(block.content, hasLevelOne, block.metadata?["descriptor"])
                case .premiumH1:
                    add(block.content, false, block.metadata?["descriptor"])
                case .keyTakeaways:
                    add("Key Takeaways", false, nil)
                default:
                    break
                }
            }
        }
        return entries
    }

    /// Whether the document has any level-1 headings (PART / # / PREMIUM_H1).
    /// Without them, level-2 headings ARE the main sections and the Contents
    /// page lists them flush left rather than as indented subsections.
    static func hasLevelOneHeadings(_ document: PDFAnalysisDocument) -> Bool {
        for section in document.sections {
            if let h = section.heading, section.headingLevel == 1 || h.uppercased().hasPrefix("PART ") { return true }
            if section.blocks.contains(where: { $0.type == .premiumH1 || $0.type == .heading1 }) { return true }
        }
        return false
    }

    /// Reading minutes for each heading: the words from that heading to the
    /// next one, at 250 wpm. Keyed by heading text; "Quick Glance" included.
    static func computeReadingMinutes(_ document: PDFAnalysisDocument) -> [String: Int] {
        var words: [String: Int] = [:]
        var order: [String] = []
        func count(_ block: PDFContentBlock) -> Int {
            var n = block.content.split(whereSeparator: { $0.isWhitespace }).count
            n += (block.listItems ?? []).reduce(0) { $0 + $1.split(whereSeparator: { $0.isWhitespace }).count }
            n += (block.tableData ?? []).flatMap { $0 }.reduce(0) { $0 + $1.split(whereSeparator: { $0.isWhitespace }).count }
            return n
        }
        func open(_ key: String) {
            if words[key] == nil { words[key] = 0; order.append(key) }
        }
        var current: String?
        if let qg = document.quickGlance {
            open("Quick Glance")
            words["Quick Glance"] = qg.coreMessage.split(whereSeparator: { $0.isWhitespace }).count
                + qg.keyPoints.reduce(0) { $0 + $1.split(whereSeparator: { $0.isWhitespace }).count }
        }
        for section in document.sections {
            if let heading = section.heading { open(heading); current = heading }
            for block in section.blocks {
                switch block.type {
                case .heading2, .heading3, .premiumH1, .premiumH2:
                    open(block.content); current = block.content
                default:
                    if let current { words[current, default: 0] += count(block) }
                }
            }
        }
        var minutes: [String: Int] = [:]
        for (key, n) in words { minutes[key] = max(1, Int((Double(n) / 250.0).rounded())) }
        return minutes
    }

    /// Short form of the book title for the running header.
    static func shortTitle(_ title: String) -> String {
        var t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let colon = t.firstIndex(of: ":"), t.distance(from: t.startIndex, to: colon) >= 12 {
            t = String(t[..<colon])
        }
        if t.count > 48 {
            t = String(t.prefix(46)).trimmingCharacters(in: .whitespaces) + "…"
        }
        return t
    }

    /// Record where a heading landed, for the next pass's Contents page.
    private func recordTOC(_ title: String, isSubsection: Bool, descriptor: String?) {
        let key = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !recordedTOC.contains(where: { $0.title == key }) else { return }
        recordedTOC.append(TOCEntry(title: key, page: currentPage, isSubsection: isSubsection,
                                    descriptor: descriptor, minutes: readingMinutes[key]))
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

        let totalWords = document.sections.flatMap(\.blocks).reduce(0) { total, block in
            total + block.content.split(whereSeparator: { $0.isWhitespace }).count
                + (block.listItems ?? []).reduce(0) { $0 + $1.split(whereSeparator: { $0.isWhitespace }).count }
        }
        coverRenderer.render(
            to: context.cgContext,
            title: document.book.title,
            author: document.book.author,
            logoImage: options.logoImage ?? UIImage(named: "Logo"),
            readingMinutes: totalWords > 0 ? max(1, Int((Double(totalWords) / 250.0).rounded())) : nil
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
        /// Below this much free space, float-ahead is not attempted (nothing
        /// useful fits and the lookahead would only add churn).
        let minFloatAheadSpace: CGFloat = 70

        // Render Quick Glance if present
        if let quickGlance = document.quickGlance {
            if needsNewPage {
                runningSectionTitle = "Quick Glance"
                startNewContentPage(context: context, options: options)
                currentY = contentRect.minY
                needsNewPage = false
            }
            recordTOC("Quick Glance", isSubsection: false, descriptor: nil)

            let quickGlanceBlock = PDFContentBlock(
                type: .quickGlance,
                content: quickGlance.coreMessage,
                listItems: quickGlance.keyPoints,
                metadata: ["readingTime": "\(quickGlance.readingTime)"]
            )

            let height = blockRenderer.calculateBlockHeight(block: quickGlanceBlock, maxWidth: contentRect.width)
            let pageBudget = contentRect.height

            if currentY + height <= contentRect.maxY {
                blockRenderer.renderBlock(quickGlanceBlock, to: context.cgContext, at: CGPoint(x: contentRect.minX, y: currentY), maxWidth: contentRect.width)
                currentY += height
            } else if height <= pageBudget {
                startNewContentPage(context: context, options: options)
                currentY = contentRect.minY
                blockRenderer.renderBlock(quickGlanceBlock, to: context.cgContext, at: CGPoint(x: contentRect.minX, y: currentY), maxWidth: contentRect.width)
                currentY += height
            } else {
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
            if section.blocks.isEmpty && section.heading == nil { continue }

            // Render section heading if present
            if let heading = section.heading {
                let headingHeight = blockRenderer.calculateSectionHeadingHeight(heading, level: section.headingLevel, descriptor: section.descriptor, maxWidth: contentRect.width)

                // Keep the heading with its ENTIRE first block when that block
                // fits on a page; otherwise reserve a minimum (fragmentable) or
                // a full page (atomic and taller than a page).
                let firstBlockHeight = section.blocks.first.map {
                    blockRenderer.calculateBlockHeight(block: $0, maxWidth: contentRect.width)
                } ?? 0
                let firstCanFragment = section.blocks.first.map(blockCanFragment) ?? true
                let headingReserve: CGFloat
                if firstCanFragment {
                    // The block can continue on the next page: keep the heading
                    // with its first ~100pt rather than with all of it.
                    headingReserve = min(firstBlockHeight, minContentAfterHeading)
                } else if (headingHeight + firstBlockHeight) <= contentRect.height {
                    headingReserve = firstBlockHeight
                } else {
                    headingReserve = contentRect.height
                }
                let combinedHeight = headingHeight + headingReserve

                runningSectionTitle = heading
                if needsNewPage || currentY + combinedHeight > contentRect.maxY - 12 {
                    if !needsNewPage {
                        recordTrailingGap(at: currentY, cause: "section heading kept with next (\(heading))")
                    }
                    startNewContentPage(context: context, options: options)
                    currentY = contentRect.minY
                    needsNewPage = false
                }

                let isPART = heading.uppercased().hasPrefix("PART ")
                recordTOC(heading, isSubsection: !(section.headingLevel == 1 || isPART || !documentHasLevelOneHeadings), descriptor: section.descriptor)

                let renderedHeight = blockRenderer.renderSectionHeading(
                    heading,
                    level: section.headingLevel,
                    descriptor: section.descriptor,
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

            // Render section blocks. `floated` holds indices of paragraphs that
            // were pulled ahead of an atomic block (float-ahead) and are
            // therefore already drawn.
            var floated: Set<Int> = []
            let blocks = section.blocks
            var index = 0
            while index < blocks.count {
                defer { index += 1 }
                if floated.contains(index) { continue }
                let block = blocks[index]
                let blockHeight = blockRenderer.calculateBlockHeight(block: block, maxWidth: contentRect.width)

                // Skip genuinely empty blocks (metadata-only and data-bearing
                // types are kept — see the original diagnosis of Table 1/2
                // vanishing from a shipped export).
                let metadataOnlyTypes: Set<PDFContentBlock.BlockType> = [.divider, .libraryEntry, .readingChip, .premiumDivider]
                let hasTableData = !(block.tableData?.isEmpty ?? true)
                let hasVisual = block.visualURL != nil
                let hasNodes = !(block.metadata?["nodes"] ?? "").isEmpty
                if block.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   (block.listItems?.isEmpty ?? true) &&
                   !hasTableData && !hasVisual && !hasNodes &&
                   !metadataOnlyTypes.contains(block.type) {
                    print("⏭️ [PDF Renderer] skipped empty block (type=\(block.type)) — no content/listItems/tableData/visualURL")
                    continue
                }

                // TOC + running header for in-section headings.
                let isHeadingBlock = [.heading1, .heading2, .heading3, .heading4, .premiumH1, .premiumH2].contains(block.type)
                if isHeadingBlock {
                    runningSectionTitle = block.content
                }

                // Exercise fragmentation (self-contained cards across pages).
                if block.type == .exercise && currentY + blockHeight > contentRect.maxY {
                    let exTitle = block.metadata?["title"] ?? "Exercise"
                    let exTime = block.metadata?["time"]
                    let exSteps = block.listItems ?? []
                    var firstBudget = contentRect.maxY - currentY
                    let minFirst = blockRenderer.minExerciseFragmentHeight(title: exTitle, content: block.content, steps: exSteps, maxWidth: contentRect.width)

                    if firstBudget < minFirst {
                        currentY = floatAhead(blocks: blocks, from: index, floated: &floated, currentY: currentY, context: context, minSpace: minFloatAheadSpace)
                        recordTrailingGap(at: currentY, cause: debugBlockLabel(block, height: blockHeight) + " (exercise: insufficient head room to fragment)")
                        startNewContentPage(context: context, options: options)
                        currentY = contentRect.minY
                        firstBudget = contentRect.height
                    }
                    if currentY + blockHeight <= contentRect.maxY {
                        currentY += blockRenderer.renderBlock(block, to: context.cgContext, at: CGPoint(x: contentRect.minX, y: currentY), maxWidth: contentRect.width)
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
                        currentY += blockRenderer.renderExercise(
                            content: frag.content, title: frag.title, steps: frag.steps,
                            estimatedTime: frag.estimatedTime,
                            to: context.cgContext, at: CGPoint(x: contentRect.minX, y: currentY),
                            maxWidth: contentRect.width, continued: frag.continued, startNumber: frag.startNumber)
                    }
                    continue
                }

                // Insight-note fragmentation at section seams.
                if block.type == .insightNote && currentY + blockHeight > contentRect.maxY {
                    let noteTitle = block.metadata?["title"] ?? "Insight Atlas Note"
                    if blockRenderer.insightNoteIsSplittable(content: block.content, title: noteTitle) {
                        let remaining = contentRect.maxY - currentY
                        var fragments = blockRenderer.planInsightNoteFragments(content: block.content, title: noteTitle, maxWidth: contentRect.width, firstBudget: remaining, pageBudget: contentRect.height)
                        var brokeFirst = false
                        if fragments == nil {
                            fragments = blockRenderer.planInsightNoteFragments(content: block.content, title: noteTitle, maxWidth: contentRect.width, firstBudget: contentRect.height, pageBudget: contentRect.height)
                            brokeFirst = true
                        }
                        if let frags = fragments, frags.count > 1 {
                            print("✂️ [PDF Renderer] fragmented insight note into \(frags.count) cards across pages")
                            if brokeFirst {
                                currentY = floatAhead(blocks: blocks, from: index, floated: &floated, currentY: currentY, context: context, minSpace: minFloatAheadSpace)
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
                                currentY += blockRenderer.renderInsightNoteFragment(frag, to: context.cgContext, at: CGPoint(x: contentRect.minX, y: currentY), maxWidth: contentRect.width)
                            }
                            continue
                        }
                    }
                }

                // Table fragmentation (row-atomic, header repeats).
                if block.type == .table && currentY + blockHeight > contentRect.maxY {
                    let rows = block.tableData ?? []
                    let captionH = blockRenderer.tableCaptionHeight(for: block, maxWidth: contentRect.width)
                    let remaining = contentRect.maxY - currentY
                    var fragments = blockRenderer.planTableFragments(tableData: rows, maxWidth: contentRect.width, firstBudget: remaining - captionH, pageBudget: contentRect.height)
                    var brokeFirst = false
                    if fragments == nil {
                        fragments = blockRenderer.planTableFragments(tableData: rows, maxWidth: contentRect.width, firstBudget: contentRect.height - captionH, pageBudget: contentRect.height)
                        brokeFirst = true
                    }
                    if let frags = fragments, frags.count > 1 {
                        print("✂️ [PDF Renderer] fragmented table into \(frags.count) cards across pages (\(max(0, rows.count - 1)) data rows)")
                        if brokeFirst {
                            currentY = floatAhead(blocks: blocks, from: index, floated: &floated, currentY: currentY, context: context, minSpace: minFloatAheadSpace)
                            recordTrailingGap(at: currentY, cause: debugBlockLabel(block, height: blockHeight) + " (table: insufficient head room to fragment)")
                            startNewContentPage(context: context, options: options)
                            currentY = contentRect.minY
                        }
                        currentY += blockRenderer.renderTableCaption(for: block, to: context.cgContext, at: CGPoint(x: contentRect.minX, y: currentY), maxWidth: contentRect.width)
                        for (fIndex, frag) in frags.enumerated() {
                            if fIndex > 0 {
                                recordTrailingGap(at: currentY, cause: "table fragment \(fIndex) continues on next page")
                                startNewContentPage(context: context, options: options)
                                currentY = contentRect.minY
                            }
                            currentY += blockRenderer.renderTableFragment(frag, to: context.cgContext, at: CGPoint(x: contentRect.minX, y: currentY), maxWidth: contentRect.width)
                        }
                        continue
                    }
                }

                // Key Takeaways fragmentation (≥ 2 items per card, "continued" header).
                if block.type == .keyTakeaways && currentY + blockHeight > contentRect.maxY {
                    let remaining = contentRect.maxY - currentY
                    if let fragments = blockRenderer.planTakeawayFragments(items: block.listItems ?? [], maxWidth: contentRect.width, firstBudget: remaining, pageBudget: contentRect.height) {
                        recordTOC("Key Takeaways", isSubsection: false, descriptor: nil)
                        for (fIndex, frag) in fragments.enumerated() {
                            if fIndex > 0 {
                                startNewContentPage(context: context, options: options)
                                currentY = contentRect.minY
                            }
                            currentY += blockRenderer.renderTakeawayFragment(frag, to: context.cgContext, at: CGPoint(x: contentRect.minX, y: currentY), maxWidth: contentRect.width)
                        }
                        continue
                    }
                }

                // Paragraph fragmentation (2-line widow/orphan minimum): the
                // single largest source of half-empty pages was a paragraph
                // pushed whole to the next page.
                if block.type == .paragraph && currentY + blockHeight > contentRect.maxY {
                    let remaining = contentRect.maxY - currentY
                    if let fragments = blockRenderer.planParagraphFragments(text: block.content, maxWidth: contentRect.width, firstBudget: remaining, pageBudget: contentRect.height) {
                        for (fIndex, frag) in fragments.enumerated() {
                            if fIndex > 0 {
                                startNewContentPage(context: context, options: options)
                                currentY = contentRect.minY
                            }
                            currentY += blockRenderer.renderParagraphFragment(frag, to: context.cgContext, at: CGPoint(x: contentRect.minX, y: currentY), maxWidth: contentRect.width)
                        }
                        continue
                    }
                }

                // List fragmentation (≥ 2 items per fragment, numbering continues).
                if (block.type == .bulletList || block.type == .numberedList) && currentY + blockHeight > contentRect.maxY {
                    let numbered = block.type == .numberedList
                    let remaining = contentRect.maxY - currentY
                    if let fragments = blockRenderer.planListFragments(items: block.listItems ?? [], numbered: numbered, maxWidth: contentRect.width, firstBudget: remaining, pageBudget: contentRect.height) {
                        for (fIndex, frag) in fragments.enumerated() {
                            if fIndex > 0 {
                                startNewContentPage(context: context, options: options)
                                currentY = contentRect.minY
                            }
                            currentY += blockRenderer.renderListFragment(frag, numbered: numbered, to: context.cgContext, at: CGPoint(x: contentRect.minX, y: currentY), maxWidth: contentRect.width)
                        }
                        continue
                    }
                }

                // Diagram scale-to-fit.
                if PDFContentBlockRenderer.scalableDiagramTypes.contains(block.type) {
                    let remaining = contentRect.maxY - currentY
                    switch blockRenderer.diagramScaleDecision(naturalHeight: blockHeight, remaining: remaining) {
                    case .fits:
                        break
                    case .scale(let factor, let target):
                        let drawn = blockRenderer.renderDiagramScaledToFit(block, factor: factor, target: target, to: context.cgContext, at: CGPoint(x: contentRect.minX, y: currentY), maxWidth: contentRect.width)
                        print("🔎 [PDF Renderer] scaled \(block.type) to \(Int((factor * 100).rounded()))% to fill remaining space (\(Int(blockHeight.rounded()))pt → \(Int(target.rounded()))pt)")
                        currentY += drawn
                        continue
                    case .pushWhole:
                        currentY = floatAhead(blocks: blocks, from: index, floated: &floated, currentY: currentY, context: context, minSpace: minFloatAheadSpace)
                        recordTrailingGap(at: currentY, cause: debugBlockLabel(block, height: blockHeight) + " (diagram scale < legibility floor — pushed whole)")
                        startNewContentPage(context: context, options: options)
                        currentY = contentRect.minY
                        if blockHeight > contentRect.height {
                            // Taller than a whole page: scale to the page rather
                            // than clip the bottom nodes off the sheet.
                            let factor = contentRect.height / blockHeight
                            currentY += blockRenderer.renderDiagramScaledToFit(block, factor: factor, target: contentRect.height, to: context.cgContext, at: CGPoint(x: contentRect.minX, y: currentY), maxWidth: contentRect.width)
                        } else {
                            currentY += blockRenderer.renderBlock(block, to: context.cgContext, at: CGPoint(x: contentRect.minX, y: currentY), maxWidth: contentRect.width)
                        }
                        continue
                    }
                }

                if isHeadingBlock {
                    // Keep the heading with its whole next block when that block
                    // fits on a page, so a heading is never stranded at the foot
                    // of a page (elevation spec A1).
                    let nextBlockHeight = (index + 1 < blocks.count) ?
                        blockRenderer.calculateBlockHeight(block: blocks[index + 1], maxWidth: contentRect.width) : 0
                    let nextCanFragment = (index + 1 < blocks.count) ? blockCanFragment(blocks[index + 1]) : true
                    let nextReserve: CGFloat
                    if nextCanFragment {
                        nextReserve = min(nextBlockHeight, minContentAfterHeading)
                    } else if (blockHeight + nextBlockHeight) <= contentRect.height {
                        nextReserve = nextBlockHeight
                    } else {
                        nextReserve = contentRect.height
                    }
                    // Never let a heading start in the bottom 15% of the text block.
                    let lowestHeadingY = contentRect.minY + contentRect.height * 0.85
                    if currentY + blockHeight + nextReserve > contentRect.maxY - 12 || currentY > lowestHeadingY {
                        recordTrailingGap(at: currentY, cause: debugBlockLabel(block, height: blockHeight) + " (heading kept with next)")
                        startNewContentPage(context: context, options: options)
                        currentY = contentRect.minY
                    }
                    let isMain = block.type == .premiumH1 || block.type == .heading1 || !documentHasLevelOneHeadings
                    recordTOC(block.content, isSubsection: !isMain, descriptor: block.metadata?["descriptor"])
                } else if currentY + blockHeight > contentRect.maxY {
                    // Atomic block that does not fit: let the paragraphs that
                    // follow it flow into the gap first (float-ahead), then
                    // start a fresh page for the block.
                    currentY = floatAhead(blocks: blocks, from: index, floated: &floated, currentY: currentY, context: context, minSpace: minFloatAheadSpace)
                    recordTrailingGap(at: currentY, cause: debugBlockLabel(block, height: blockHeight) + " pushed whole")
                    startNewContentPage(context: context, options: options)
                    currentY = contentRect.minY
                }

                if block.type == .keyTakeaways {
                    recordTOC("Key Takeaways", isSubsection: false, descriptor: nil)
                }

                currentY += blockRenderer.renderBlock(
                    block,
                    to: context.cgContext,
                    at: CGPoint(x: contentRect.minX, y: currentY),
                    maxWidth: contentRect.width
                )
            }
        }

        recordTrailingGap(at: currentY, cause: "end of content")
        logWhitespaceSummary()

        // Render closing page with branding
        renderClosingPage(context: context, options: options)
    }

    /// Float-ahead (elevation spec A3, option b): when the block at `index`
    /// cannot fit the space left on the page, draw the plain paragraphs that
    /// directly follow it into that space — they read identically whether a
    /// callout sits before or after them — and mark them so the main loop
    /// skips them. Stops at the first non-paragraph block, after three
    /// paragraphs, or when nothing more fits. Returns the new `currentY`.
    private func floatAhead(blocks: [PDFContentBlock], from index: Int, floated: inout Set<Int>, currentY: CGFloat, context: UIGraphicsPDFRendererContext, minSpace: CGFloat) -> CGFloat {
        var y = currentY
        guard contentRect.maxY - y >= minSpace else { return y }
        var pulled = 0
        var j = index + 1
        while j < blocks.count, pulled < 3 {
            let candidate = blocks[j]
            guard candidate.type == .paragraph, !floated.contains(j) else { break }
            // A paragraph that opens a labelled sub-part ("**Where it strains.**")
            // belongs with what follows it; do not pull it above its callout.
            if candidate.content.hasPrefix("**") && pulled == 0 && j + 1 < blocks.count && blocks[j + 1].type != .paragraph { break }
            let h = blockRenderer.calculateBlockHeight(block: candidate, maxWidth: contentRect.width)
            // Only pull a paragraph whole: a floated paragraph must never be
            // split across the atomic block it was pulled ahead of.
            guard y + h <= contentRect.maxY else { break }
            y += blockRenderer.renderBlock(candidate, to: context.cgContext, at: CGPoint(x: contentRect.minX, y: y), maxWidth: contentRect.width)
            floated.insert(j)
            pulled += 1
            j += 1
        }
        if pulled > 0 {
            print("↪️ [PDF Renderer] floated \(pulled) paragraph(s) ahead of an atomic block to fill the page")
        }
        return y
    }

    private func startNewContentPage(context: UIGraphicsPDFRendererContext, options: RenderOptions) {
        context.beginPage()
        currentPage += 1

        // Running header: book title left, current section right (elevation
        // spec A10). The section is the one in effect when the page begins;
        // heading branches update it before breaking the page.
        if options.includeHeader {
            drawPageHeader(context: context.cgContext, pageNumber: currentPage)
        }

        // Footer: brand mark + page number.
        if options.includeFooter {
            drawPageFooter(context: context.cgContext, pageNumber: currentPage, includePageNumber: options.includePageNumbers)
        }
    }

    // MARK: - Whitespace instrumentation (DEBUG)

    /// Record the trailing gap left on the current page at the moment a block is
    /// pushed to the next one. `cause` is an @autoclosure so its (potentially
    /// parsing) work is skipped entirely in release builds.

    /// Whether a block can render partially on one page and continue on the
    /// next. Paragraphs, insight notes and lists fragment; a visual card,
    /// table or exercise is drawn whole.
    ///
    /// Keep-with-next depends on this: reserving a small slice below a heading
    /// is only safe when the next block can use that slice. An atomic block
    /// leaves it unused and jumps wholesale to the following page, stranding
    /// the heading at the footer.
    private func blockCanFragment(_ block: PDFContentBlock) -> Bool {
        switch block.type {
        case .paragraph, .insightNote, .bulletList, .numberedList, .exercise:
            return true
        case .keyTakeaways:
            return (block.listItems?.count ?? 0) >= 4
        case .table:
            return (block.tableData?.count ?? 0) >= 5
        default:
            return false
        }
    }

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
            .ligature: 0,
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
            .ligature: 0,
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
            .ligature: 0,
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
            .ligature: 0,
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
        guard pageNumber > lastFrontMatterPage else { return } // Skip header on cover and contents

        let headerY: CGFloat = 36
        let headerHeight: CGFloat = 24

        // Draw thin line
        context.setStrokeColor(PDFStyleConfiguration.Colors.borderLight.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: contentRect.minX, y: headerY + headerHeight))
        context.addLine(to: CGPoint(x: contentRect.maxX, y: headerY + headerHeight))
        context.strokePath()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.runningHeader(),
            .ligature: 0,
            .foregroundColor: PDFStyleConfiguration.Colors.textSubtle,
            .kern: 0.5
        ]
        let leftWidth = contentRect.width * 0.62
        let halfWidth = contentRect.width - leftWidth - 16

        // Left: the book's short title, shortened with an ellipsis if it would
        // not fit its column (drawn text is clipped, never auto-truncated).
        let left = Self.fitted(runningBookTitle.uppercased(), width: leftWidth, attributes: attributes)
        left.draw(in: CGRect(x: contentRect.minX, y: headerY + 6, width: leftWidth, height: headerHeight - 6))

        // Right: the current section, right-aligned, truncated to its half.
        let (numeral, bare) = PDFContentBlockRenderer.splitSectionNumeral(runningSectionTitle)
        let sectionText = numeral.map { "\($0) \(bare)" } ?? bare
        if !sectionText.isEmpty {
            let style = NSMutableParagraphStyle()
            style.alignment = .right
            var rightAttributes = attributes
            rightAttributes[.paragraphStyle] = style
            let right = Self.fitted(sectionText.uppercased(), width: halfWidth, attributes: rightAttributes)
            right.draw(in: CGRect(x: contentRect.maxX - halfWidth, y: headerY + 6, width: halfWidth, height: headerHeight - 6))
        }
    }

    /// The string, or its longest prefix plus "…", that fits `width`.
    static func fitted(_ text: String, width: CGFloat, attributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        var candidate = text
        while !candidate.isEmpty {
            let attributed = NSAttributedString(string: candidate, attributes: attributes)
            if attributed.size().width <= width { return attributed }
            candidate = String(candidate.dropLast(candidate.hasSuffix("…") ? 2 : 1)).trimmingCharacters(in: .whitespaces) + "…"
            if candidate == "…" { break }
        }
        return NSAttributedString(string: candidate, attributes: attributes)
    }

    private func drawPageFooter(context: CGContext, pageNumber: Int, includePageNumber: Bool) {
        guard pageNumber > 1 else { return } // Skip footer on cover

        let footerY = pageSize.height - 36
        let footerHeight: CGFloat = 16

        context.setStrokeColor(PDFStyleConfiguration.Colors.borderLight.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: contentRect.minX, y: footerY - 6))
        context.addLine(to: CGPoint(x: contentRect.maxX, y: footerY - 6))
        context.strokePath()

        // Brand mark, left.
        let brandAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFStyleConfiguration.Typography.runningHeader(),
            .ligature: 0,
            .foregroundColor: PDFStyleConfiguration.Colors.textSubtle,
            .kern: 0.8
        ]
        NSAttributedString(string: "INSIGHT ATLAS", attributes: brandAttributes)
            .draw(in: CGRect(x: contentRect.minX, y: footerY + 2, width: 200, height: footerHeight))

        if includePageNumber {
            let style = NSMutableParagraphStyle()
            style.alignment = .right
            let pageAttributes: [NSAttributedString.Key: Any] = [
                .font: PDFStyleConfiguration.Typography.pageNumber(),
                .ligature: 0,
                .foregroundColor: PDFStyleConfiguration.Colors.textMuted,
                .paragraphStyle: style
            ]
            NSAttributedString(string: "\(pageNumber)", attributes: pageAttributes)
                .draw(in: CGRect(x: contentRect.maxX - 60, y: footerY, width: 60, height: footerHeight))
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
