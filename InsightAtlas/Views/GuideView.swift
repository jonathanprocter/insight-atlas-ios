import SwiftUI
import os.log

struct GuideView: View {

    // MARK: - Logger

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "InsightAtlas", category: "GuideView")

    // MARK: - Properties

    let item: LibraryItem

    // MARK: - Environment

    @EnvironmentObject var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var searchText = ""
    @State private var isPlayingAudio = false
    @State private var audioPlaybackProgress: Double = 0
    @State private var isGeneratingAudio = false
    @State private var audioPlaybackRate: Float = 1.0
    @State private var tableOfContents: [TOCEntry] = []
    @State private var bookmarks: [GuideBookmark] = []
    @State private var showBookmarksSheet = false
    @State private var showAddBookmarkSheet = false
    @State private var selectedBookmarkSection: TOCEntry?
    @State private var audioProgressTimer: Timer?
    @State private var showExportSheet = false
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var shareItem: URL?
    
    // MARK: - Computed Properties
    
    private var hasPlayableAudio: Bool {
        item.audioFileURL != nil
    }
    
    private var canGenerateAudio: Bool {
        item.summaryContent != nil && item.canRetryAudioGeneration
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        GuideHeaderView(item: item)
                        
                        // Table of Contents
                        if !tableOfContents.isEmpty {
                            tableOfContentsSection(proxy: proxy)
                        }
                        
                        // Content
                        if let content = item.summaryContent {
                            InsightAtlasContentView(content: content, searchQuery: searchText)
                        } else {
                            emptyContentView
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, hasPlayableAudio || canGenerateAudio ? 120 : 20)
                    .frame(maxWidth: 800, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .background(Color(.systemGroupedBackground))
            
            // Sticky Audio Player
            if hasPlayableAudio || canGenerateAudio {
                StickyAudioPlayer(
                    item: item,
                    isPlaying: $isPlayingAudio,
                    progress: $audioPlaybackProgress,
                    isGenerating: $isGeneratingAudio,
                    playbackRate: $audioPlaybackRate,
                    onPlayPause: toggleAudioPlayback,
                    onGenerate: generateAudioOnly,
                    onRateChange: setPlaybackRate
                )
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)
            }
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search in guide")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // Bookmarks button
                    Button {
                        showBookmarksSheet = true
                    } label: {
                        Image(systemName: bookmarks.isEmpty ? "bookmark" : "bookmark.fill")
                            .foregroundColor(bookmarks.isEmpty ? .secondary : AnalysisTheme.primaryGold)
                    }

                    // More options menu
                    Menu {
                        // Export submenu
                        Menu {
                            Button {
                                exportGuide(format: .pdfOnly)
                            } label: {
                                Label("Export as PDF", systemImage: "doc.fill")
                            }
                            .disabled(item.summaryContent == nil)

                            if item.audioFileURL != nil {
                                Button {
                                    exportGuide(format: .audioOnly)
                                } label: {
                                    Label("Export Audio Only", systemImage: "speaker.wave.2.fill")
                                }

                                Button {
                                    exportGuide(format: .bundled)
                                } label: {
                                    Label("Export PDF + Audio Bundle", systemImage: "archivebox.fill")
                                }
                            }
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }

                        Divider()

                        Button(role: .destructive) {
                            deleteGuide()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        if isExporting {
                            ProgressView()
                        } else {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showBookmarksSheet) {
            BookmarksListSheet(
                bookmarks: $bookmarks,
                tableOfContents: tableOfContents,
                onSelectBookmark: { bookmark in
                    // Navigate to bookmark - handled by caller
                },
                onDeleteBookmark: { bookmark in
                    bookmarks.removeAll { $0.id == bookmark.id }
                    saveBookmarks()
                },
                onAddBookmark: {
                    showBookmarksSheet = false
                    showAddBookmarkSheet = true
                }
            )
        }
        .sheet(isPresented: $showAddBookmarkSheet) {
            AddBookmarkSheet(
                tableOfContents: tableOfContents,
                existingBookmarks: bookmarks,
                onSave: { newBookmark in
                    bookmarks.append(newBookmark)
                    saveBookmarks()
                }
            )
        }
        .sheet(item: $shareItem) { url in
            ShareSheet(activityItems: [url])
        }
        .alert("Export Error", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportError ?? "An unknown error occurred")
        }
        .onAppear {
            generateTableOfContents()
            loadBookmarks()
        }
    }

    // MARK: - Table of Contents
    
    private func tableOfContentsSection(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with collapsible toggle
            HStack {
                Image(systemName: "list.bullet.rectangle.portrait")
                    .foregroundColor(AnalysisTheme.primaryGold)
                Text("Table of Contents")
                    .font(.custom("CormorantGaramond-SemiBold", size: 18))
                Spacer()
                Text("\(tableOfContents.count) sections")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Divider()
                .padding(.horizontal)

            // TOC entries with proper indentation
            ForEach(tableOfContents) { entry in
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(entry.id, anchor: .top)
                    }
                } label: {
                    HStack(spacing: 12) {
                        // Indentation based on level
                        if entry.level > 1 {
                            Spacer()
                                .frame(width: CGFloat((entry.level - 1) * 16))
                        }

                        // Icon based on type
                        Image(systemName: iconForTOCType(entry.type))
                            .font(.system(size: 14))
                            .foregroundColor(colorForTOCType(entry.type))
                            .frame(width: 20)

                        Text(entry.title)
                            .font(fontForTOCLevel(entry.level))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(entry.level == 1 ? Color(.secondarySystemGroupedBackground) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
            }
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        )
        .padding(.horizontal, 4)
    }

    private func iconForTOCType(_ type: TOCEntry.TOCEntryType) -> String {
        switch type {
        case .header1: return "bookmark.fill"
        case .header2: return "text.alignleft"
        case .quickGlance: return "sparkles"
        case .takeaways: return "checkmark.circle.fill"
        case .exercise: return "figure.walk"
        case .section: return "doc.text"
        }
    }

    private func colorForTOCType(_ type: TOCEntry.TOCEntryType) -> Color {
        switch type {
        case .header1: return AnalysisTheme.primaryGold
        case .header2: return .secondary
        case .quickGlance: return AnalysisTheme.accentOrange
        case .takeaways: return AnalysisTheme.accentSuccess
        case .exercise: return AnalysisTheme.accentTeal
        case .section: return .secondary
        }
    }

    private func fontForTOCLevel(_ level: Int) -> Font {
        switch level {
        case 1: return .custom("CormorantGaramond-SemiBold", size: 16)
        case 2: return .custom("CormorantGaramond-Regular", size: 15)
        default: return .custom("Inter-Regular", size: 14)
        }
    }
    
    private func generateTableOfContents() {
        guard let content = item.summaryContent else { return }

        var toc: [TOCEntry] = []
        var sectionIndex = 0

        // Regex patterns for Insight Atlas custom tags
        let h1Pattern = #"\[PREMIUM_H1\]([^\[]+)\[/PREMIUM_H1\]"#
        let h2Pattern = #"\[PREMIUM_H2\]([^\[]+)\[/PREMIUM_H2\]"#
        _ = #"\[QUICK_GLANCE\]"#
        _ = #"\[TAKEAWAYS\]"#
        let exercisePattern = #"\[EXERCISE_[A-Z]+:([^\]]+)\]"#

        // Also support markdown headers as fallback
        _ = #"^# (.+)$"#
        _ = #"^## (.+)$"#

        let lines = content.components(separatedBy: .newlines)

        for (_, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Check for PREMIUM_H1
            if let match = trimmedLine.range(of: h1Pattern, options: .regularExpression) {
                let fullMatch = String(trimmedLine[match])
                if let titleRange = fullMatch.range(of: #"(?<=\[PREMIUM_H1\]).*(?=\[/PREMIUM_H1\])"#, options: .regularExpression) {
                    let title = String(fullMatch[titleRange]).trimmingCharacters(in: .whitespaces)
                    if !title.isEmpty {
                        sectionIndex += 1
                        toc.append(TOCEntry(id: "section-\(sectionIndex)", title: title, level: 1, type: .header1))
                    }
                }
            }

            // Check for PREMIUM_H2
            else if let match = trimmedLine.range(of: h2Pattern, options: .regularExpression) {
                let fullMatch = String(trimmedLine[match])
                if let titleRange = fullMatch.range(of: #"(?<=\[PREMIUM_H2\]).*(?=\[/PREMIUM_H2\])"#, options: .regularExpression) {
                    let title = String(fullMatch[titleRange]).trimmingCharacters(in: .whitespaces)
                    if !title.isEmpty {
                        sectionIndex += 1
                        toc.append(TOCEntry(id: "section-\(sectionIndex)", title: title, level: 2, type: .header2))
                    }
                }
            }

            // Check for QUICK_GLANCE
            else if trimmedLine.contains("[QUICK_GLANCE]") {
                sectionIndex += 1
                toc.append(TOCEntry(id: "section-\(sectionIndex)", title: "Quick Glance", level: 1, type: .quickGlance))
            }

            // Check for TAKEAWAYS
            else if trimmedLine.contains("[TAKEAWAYS]") {
                sectionIndex += 1
                toc.append(TOCEntry(id: "section-\(sectionIndex)", title: "Key Takeaways", level: 1, type: .takeaways))
            }

            // Check for exercises
            else if let match = trimmedLine.range(of: exercisePattern, options: .regularExpression) {
                let fullMatch = String(trimmedLine[match])
                if let titleRange = fullMatch.range(of: #"(?<=:)[^\]]+(?=\])"#, options: .regularExpression) {
                    let title = String(fullMatch[titleRange]).trimmingCharacters(in: .whitespaces)
                    if !title.isEmpty {
                        sectionIndex += 1
                        toc.append(TOCEntry(id: "section-\(sectionIndex)", title: "Exercise: \(title)", level: 3, type: .exercise))
                    }
                }
            }

            // Fallback: Markdown H1
            else if trimmedLine.hasPrefix("# ") {
                let title = String(trimmedLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !title.isEmpty && !title.hasPrefix("[") {
                    sectionIndex += 1
                    toc.append(TOCEntry(id: "section-\(sectionIndex)", title: title, level: 1, type: .header1))
                }
            }

            // Fallback: Markdown H2
            else if trimmedLine.hasPrefix("## ") {
                let title = String(trimmedLine.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                if !title.isEmpty && !title.hasPrefix("[") {
                    sectionIndex += 1
                    toc.append(TOCEntry(id: "section-\(sectionIndex)", title: title, level: 2, type: .header2))
                }
            }
        }

        tableOfContents = toc
    }
    
    // MARK: - Empty State
    
    private var emptyContentView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Content Available")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Generate content for this guide to view it here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Actions

    private func toggleAudioPlayback() {
        guard let audioURLString = item.audioFileURL,
              let audioURL = URL(string: audioURLString) ?? URL(fileURLWithPath: audioURLString) as URL? else { return }

        if isPlayingAudio {
            // Pause playback
            AudioPlaybackManager.shared.pause()
            stopProgressTimer()
            isPlayingAudio = false
        } else {
            // Start playback
            do {
                try AudioPlaybackManager.shared.playFile(at: audioURL, rate: audioPlaybackRate) { [weak self] in
                    // Playback completed
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.isPlayingAudio = false
                        self.audioPlaybackProgress = 0
                        self.stopProgressTimer()
                    }
                }
                isPlayingAudio = true
                startProgressTimer()
            } catch {
                Self.logger.error("Failed to play audio: \(error.localizedDescription)")
            }
        }
    }

    private func setPlaybackRate(_ rate: Float) {
        audioPlaybackRate = rate
        AudioPlaybackManager.shared.setPlaybackRate(rate)
    }

    private func startProgressTimer() {
        audioProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            audioPlaybackProgress = AudioPlaybackManager.shared.progress
            if !AudioPlaybackManager.shared.isPlaying && isPlayingAudio {
                isPlayingAudio = false
                stopProgressTimer()
            }
        }
    }

    private func stopProgressTimer() {
        audioProgressTimer?.invalidate()
        audioProgressTimer = nil
    }

    private func generateAudioOnly() {
        isGeneratingAudio = true

        // Increment attempt counter immediately
        var updatedItem = item
        updatedItem.audioGenerationAttempts = (item.audioGenerationAttempts ?? 0) + 1
        environment.updateLibraryItem(updatedItem)

        Task {
            do {
                let audioService = environment.audioService
                guard let content = item.summaryContent else {
                    isGeneratingAudio = false
                    return
                }

                let result = try await audioService.generateAudio(
                    text: content,
                    voiceId: environment.settings.selectedVoiceId ?? "21m00Tcm4TlvDq8ikWAM"
                )

                // Save audio file
                let savedURL = try audioService.exportAudio(result, filename: item.id.uuidString)

                // Update library item with audio URL on success
                var successItem = item
                successItem.audioFileURL = savedURL.path
                successItem.audioDuration = result.duration
                successItem.audioVoiceID = environment.settings.selectedVoiceId
                successItem.audioGenerationAttempts = (item.audioGenerationAttempts ?? 0) + 1
                environment.updateLibraryItem(successItem)

                isGeneratingAudio = false
            } catch {
                Self.logger.error("Audio generation failed (attempt \(item.audioGenerationAttempts ?? 1)/\(LibraryItem.maxAudioGenerationAttempts)): \(error.localizedDescription)")
                isGeneratingAudio = false
            }
        }
    }
    
    private func deleteGuide() {
        environment.deleteLibraryItem(item)
        dismiss()
    }

    private func exportGuide(format: PDFAudioBundler.ExportFormat) {
        isExporting = true

        Task {
            do {
                let bundler = PDFAudioBundler()

                // Generate PDF data if needed
                var pdfData: Data? = nil
                if format == .pdfOnly || format == .bundled {
                    if let content = item.summaryContent {
                        let pdfRenderer = InsightAtlasPDFRenderer()
                        let document = PDFAnalysisDocument(
                            title: item.title,
                            author: item.author,
                            content: content,
                            coverImageURL: item.coverImageURL
                        )
                        let result = try pdfRenderer.render(document: document)
                        pdfData = result.pdfData
                    }
                }

                // Convert audio file path to URL
                var audioURL: URL? = nil
                if let audioPath = item.audioFileURL {
                    audioURL = URL(string: audioPath) ?? URL(fileURLWithPath: audioPath)
                }

                let result = try bundler.createBundle(
                    pdfData: pdfData,
                    audioURL: audioURL,
                    title: item.title,
                    format: format
                )

                await MainActor.run {
                    isExporting = false
                    shareItem = result.url
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    exportError = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Bookmark Management

    private func loadBookmarks() {
        bookmarks = item.bookmarks ?? []
    }

    private func saveBookmarks() {
        var updatedItem = item
        updatedItem.bookmarks = bookmarks
        environment.updateLibraryItem(updatedItem)
    }

    private func isBookmarked(_ sectionId: String) -> Bool {
        bookmarks.contains { $0.sectionId == sectionId }
    }

    private func toggleBookmark(for entry: TOCEntry) {
        if let index = bookmarks.firstIndex(where: { $0.sectionId == entry.id }) {
            bookmarks.remove(at: index)
        } else {
            let newBookmark = GuideBookmark(
                sectionId: entry.id,
                sectionTitle: entry.title
            )
            bookmarks.append(newBookmark)
        }
        saveBookmarks()
    }
}

// MARK: - Bookmarks List Sheet

struct BookmarksListSheet: View {
    @Binding var bookmarks: [GuideBookmark]
    let tableOfContents: [TOCEntry]
    let onSelectBookmark: (GuideBookmark) -> Void
    let onDeleteBookmark: (GuideBookmark) -> Void
    let onAddBookmark: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Group {
                if bookmarks.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)

                        Text("No Bookmarks Yet")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Add bookmarks to quickly navigate to your favorite sections")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button {
                            onAddBookmark()
                        } label: {
                            Label("Add Bookmark", systemImage: "plus")
                                .padding()
                                .background(AnalysisTheme.primaryGold)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                } else {
                    List {
                        ForEach(bookmarks.sorted(by: { $0.createdAt > $1.createdAt })) { bookmark in
                            Button {
                                dismiss()
                                onSelectBookmark(bookmark)
                            } label: {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(bookmark.highlightColor.color)
                                        .frame(width: 12, height: 12)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(bookmark.sectionTitle)
                                            .font(.headline)
                                            .foregroundColor(.primary)

                                        if let note = bookmark.note, !note.isEmpty {
                                            Text(note)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                        }

                                        Text(bookmark.createdAt, style: .relative)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    onDeleteBookmark(bookmark)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !bookmarks.isEmpty {
                        Button {
                            onAddBookmark()
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Add Bookmark Sheet

struct AddBookmarkSheet: View {
    let tableOfContents: [TOCEntry]
    let existingBookmarks: [GuideBookmark]
    let onSave: (GuideBookmark) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSection: TOCEntry?
    @State private var note = ""
    @State private var selectedColor: BookmarkColor = .gold

    private var availableSections: [TOCEntry] {
        tableOfContents.filter { entry in
            !existingBookmarks.contains { $0.sectionId == entry.id }
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Section") {
                    if availableSections.isEmpty {
                        Text("All sections are already bookmarked")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Select Section", selection: $selectedSection) {
                            Text("Choose a section").tag(nil as TOCEntry?)
                            ForEach(availableSections) { entry in
                                Text(entry.title).tag(entry as TOCEntry?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section("Note (Optional)") {
                    TextField("Add a note...", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                        ForEach(BookmarkColor.allCases, id: \.self) { color in
                            Button {
                                selectedColor = color
                            } label: {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: selectedColor == color ? 3 : 0)
                                    )
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Add Bookmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        guard let section = selectedSection else { return }
                        let bookmark = GuideBookmark(
                            sectionId: section.id,
                            sectionTitle: section.title,
                            note: note.isEmpty ? nil : note,
                            highlightColor: selectedColor
                        )
                        onSave(bookmark)
                        dismiss()
                    }
                    .disabled(selectedSection == nil)
                }
            }
        }
    }
}

// MARK: - Guide Header View

struct GuideHeaderView: View {
    let item: LibraryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Cover Image
            if let coverPath = item.coverImagePath,
               let imageData = loadCoverImageData(from: coverPath),
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 220)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            }
            
            // Title and Author
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Based on the work of \(item.author)")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            // Metadata
            HStack(spacing: 24) {
                if let wordCount = item.governedWordCount {
                    let minutes = wordCount / 200
                    InfoPill(label: "\(minutes) min read", icon: "clock")
                }
                if let pageCount = item.pageCount {
                    InfoPill(label: "\(pageCount) pages", icon: "doc")
                }
                InfoPill(label: item.mode.displayName, icon: "sparkles")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            Divider()
        }
    }

    private func loadCoverImageData(from path: String) -> Data? {
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let fileURL = documentsDir.appendingPathComponent(path)
        return try? Data(contentsOf: fileURL)
    }
}

struct InfoPill: View {
    let label: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(label)
        }
    }
}

// MARK: - Sticky Audio Player

struct StickyAudioPlayer: View {
    let item: LibraryItem
    @Binding var isPlaying: Bool
    @Binding var progress: Double
    @Binding var isGenerating: Bool
    @Binding var playbackRate: Float

    let onPlayPause: () -> Void
    let onGenerate: () -> Void
    let onRateChange: (Float) -> Void

    // Available playback speeds
    private let speedOptions: [(label: String, rate: Float)] = [
        ("0.5x", 0.5),
        ("0.75x", 0.75),
        ("1x", 1.0),
        ("1.25x", 1.25),
        ("1.5x", 1.5),
        ("2x", 2.0)
    ]

    private var currentSpeedLabel: String {
        speedOptions.first { $0.rate == playbackRate }?.label ?? "\(playbackRate)x"
    }

    var body: some View {
        VStack(spacing: 8) {
            if isPlaying || item.audioFileURL != nil {
                // Progress bar with time labels
                HStack(spacing: 8) {
                    Text(formatTime(AudioPlaybackManager.shared.duration * progress))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)

                    ProgressView(value: progress)
                        .tint(.accentColor)

                    Text(formatTime(AudioPlaybackManager.shared.duration))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                // Album art/icon
                Image(systemName: "headphones")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .frame(width: 44, height: 44)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(6)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(item.author)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if isGenerating {
                    ProgressView()
                } else if item.audioFileURL != nil {
                    HStack(spacing: 12) {
                        // Speed control menu
                        Menu {
                            ForEach(speedOptions, id: \.rate) { option in
                                Button {
                                    onRateChange(option.rate)
                                } label: {
                                    HStack {
                                        Text(option.label)
                                        if option.rate == playbackRate {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Text(currentSpeedLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.15))
                                .cornerRadius(4)
                        }

                        // Play/Pause button
                        Button(action: onPlayPause) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                                .frame(width: 44, height: 44)
                        }
                    }
                } else {
                    // Generate/Retry button
                    let attempts = item.audioGenerationAttempts ?? 0
                    let isRetry = attempts > 0
                    VStack(spacing: 2) {
                        Button(action: onGenerate) {
                            Image(systemName: isRetry ? "arrow.clockwise.circle" : "speaker.wave.2.circle")
                                .font(.title2)
                                .frame(width: 44, height: 44)
                        }
                        if isRetry {
                            Text("Retry \(attempts)/\(LibraryItem.maxAudioGenerationAttempts)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5)
    }

    // Format seconds to MM:SS
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - TOC Entry

struct TOCEntry: Identifiable, Hashable {
    let id: String
    let title: String
    let level: Int  // 1 for H1, 2 for H2, 3 for blocks
    let type: TOCEntryType

    enum TOCEntryType: String, Hashable {
        case header1 = "h1"
        case header2 = "h2"
        case quickGlance = "quick_glance"
        case takeaways = "takeaways"
        case exercise = "exercise"
        case section = "section"
    }

    init(id: String, title: String, level: Int = 1, type: TOCEntryType = .header1) {
        self.id = id
        self.title = title
        self.level = level
        self.type = type
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: TOCEntry, rhs: TOCEntry) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Content View Placeholder

struct InsightAtlasContentView: View {
    let content: String
    let searchQuery: String

    var body: some View {
        // This is a placeholder - implement your actual content rendering
        Text(content)
            .font(.body)
            .padding()
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - URL Identifiable Extension

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
