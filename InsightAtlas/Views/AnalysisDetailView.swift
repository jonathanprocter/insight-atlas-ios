import SwiftUI
import AVFoundation

// MARK: - Analysis Detail View

struct AnalysisDetailView: View {
    let item: LibraryItem
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var guideGenerationService = GuideGenerationService()
    @State private var showingExportSheet = false
    @State private var parsedContent: ParsedAnalysisContent?
    @State private var showingRegenerateConfirmation = false
    @State private var showingRegenerateView = false
    @State private var showingDeleteConfirmation = false
    @State private var useBackendGeneration = false
    @State private var layoutScore: LayoutScore?
    @State private var scrollProxy: ScrollViewProxy?
    @State private var showTableOfContents = true

    // MARK: - Audio Playback State
    @State private var isPlayingAudio = false
    @State private var audioPlaybackProgress: Double = 0
    @State private var audioPlaybackTimer: Timer?
    @State private var audioPlaybackError: String?
    @State private var showingAudioErrorToast = false

    // MARK: - Audio Generation State
    @State private var isGeneratingAudio = false
    @State private var showingAudioReadyToast = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AnalysisTheme.Spacing.xl2) {
                    // Header with logo, title, author
                    AnalysisHeaderView(
                        title: item.title,
                        author: item.author,
                        subtitle: nil
                    )

                    // Quick Glance section
                    if let quickGlance = parsedContent?.quickGlance {
                        PremiumQuickGlanceView(
                            coreMessage: quickGlance.coreMessage,
                            keyPoints: quickGlance.keyPoints,
                            readingTime: quickGlance.readingTime
                        )
                    }

                    // Table of Contents - only show if there are sections with headings
                    if showTableOfContents,
                       let sections = parsedContent?.sections,
                       sections.filter({ $0.heading != nil && !($0.heading?.isEmpty ?? true) }).count >= 3 {
                        TableOfContentsView(
                            sections: sections,
                            onSectionTap: { sectionIndex in
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo("section_\(sectionIndex)", anchor: .top)
                                }
                            }
                        )
                    }

                    // Main content sections
                    if let sections = parsedContent?.sections, !sections.isEmpty {
                        ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                            renderSection(section)
                                .id("section_\(index)")

                            if index < sections.count - 1 {
                                PremiumSectionDivider()
                            }
                        }
                    } else if let content = item.summaryContent {
                        // Fallback: render raw markdown content when no special blocks found
                        FallbackMarkdownView(content: content)
                    }

                // Footer
                AnalysisFooterView()

                // Debug: Layout score overlay (only in DEBUG builds)
                #if DEBUG
                if let score = layoutScore {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Layout Scores (Debug)")
                            .font(.caption.bold())
                        HStack(spacing: 16) {
                            scoreLabel("PDF", score: score.pdf)
                            scoreLabel("DOCX", score: score.docx)
                            scoreLabel("HTML", score: score.html)
                        }
                        if !score.issues.isEmpty {
                            Text("\(score.issues.count) layout issue(s)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                #endif
                }
                .padding(AnalysisTheme.Spacing.base)
            }
        }
        .background(AnalysisTheme.bgPrimary)
        .safeAreaInset(edge: .bottom) {
            // Floating audio player (only shown when audio is available)
            if hasPlayableAudio {
                audioPlayerBar
            }
        }
        .overlay(alignment: .bottom) {
            if showingAudioReadyToast {
                audioReadyToast
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if showingAudioErrorToast, let audioPlaybackError = audioPlaybackError {
                audioErrorToast(message: audioPlaybackError)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showingAudioReadyToast)
        .animation(.easeInOut(duration: 0.3), value: showingAudioErrorToast)
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Audio button in toolbar (if audio available)
            if hasPlayableAudio {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { toggleAudioPlayback() }) {
                        Image(systemName: isPlayingAudio ? "pause.circle.fill" : "headphones.circle.fill")
                            .font(.title3)
                            .foregroundColor(AnalysisTheme.primaryGold)
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    // Audio controls in menu
                    if hasPlayableAudio {
                        Button(action: { toggleAudioPlayback() }) {
                            Label(isPlayingAudio ? "Pause Audio" : "Listen to Guide", systemImage: isPlayingAudio ? "pause.fill" : "headphones")
                        }

                        Divider()
                    }
                    if !hasPlayableAudio, item.summaryContent != nil {
                        Button(action: { generateAudioOnly() }) {
                            Label(isGeneratingAudio ? "Generating Audio..." : "Generate Audio", systemImage: "waveform")
                        }
                        .disabled(isGeneratingAudio)
                        Divider()
                    }

                    Button(action: { showingExportSheet = true }) {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }

                    Button(action: { shareAnalysis() }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }

                    Divider()

                    Button(action: { showingRegenerateConfirmation = true }) {
                        Label("Regenerate Guide", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(guideGenerationService.isGenerating)

                    // Only show backend option if backend API is configured
                    if guideGenerationService.isBackendConfigured {
                        Button(action: { generateWithBackend() }) {
                            Label("Generate via Backend", systemImage: "server.rack")
                        }
                        .disabled(guideGenerationService.isGenerating)
                    }

                    Divider()

                    Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                        Label("Delete Guide", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(AnalysisTheme.primaryGold)
                }
            }
        }
        .onDisappear {
            stopAudio()
        }
        .sheet(isPresented: $showingExportSheet) {
            AnalysisExportOptionsView(item: item, parsedContent: parsedContent, layoutScore: layoutScore)
        }
        .alert("Regenerate Guide?", isPresented: $showingRegenerateConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Regenerate", role: .destructive) {
                showingRegenerateView = true
            }
        } message: {
            Text("This will create a new analysis of the book. The current guide will be replaced.")
        }
        .alert("Delete Guide?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                dataManager.deleteLibraryItem(item)
                dismiss()
            }
        } message: {
            Text("This will permanently delete \"\(item.title)\" from your library. This action cannot be undone.")
        }
        .fullScreenCover(isPresented: $showingRegenerateView) {
            RegenerateView(item: item, onComplete: { newContent, score in
                // Update the item with new content
                dataManager.updateLibraryItem(item, with: newContent)
                showingRegenerateView = false
                // Re-parse the content
                parsedContent = ParsedAnalysisContent.parse(from: newContent)
            })
        }
        .onAppear {
            parseContent()
        }
        .onChange(of: guideGenerationService.lastResult?.title) {
            // When backend returns a result, convert it to our format
            if let result = guideGenerationService.lastResult {
                parsedContent = convertBackendResponse(result)
                layoutScore = result.layoutScore
            }
        }
    }

    #if DEBUG
    @ViewBuilder
    private func scoreLabel(_ label: String, score: Double) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(Int(score * 100))%")
                .font(.caption.bold())
                .foregroundColor(score >= 0.9 ? .green : score >= 0.8 ? .orange : .red)
        }
    }
    #endif

    private func parseContent() {
        guard let content = item.summaryContent else { return }
        parsedContent = ParsedAnalysisContent.parse(from: content)
    }

    // MARK: - Audio Player UI

    private var resolvedAudioFileURL: URL? {
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        if let audioFileName = item.audioFileURL {
            let fileURL = documentsDir.appendingPathComponent(audioFileName)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return fileURL
            }
        }

        let fallback = documentsDir.appendingPathComponent("audio_\(item.id.uuidString).mp3")
        if FileManager.default.fileExists(atPath: fallback.path) {
            return fallback
        }

        return nil
    }

    private var hasPlayableAudio: Bool {
        resolvedAudioFileURL != nil
    }

    @ViewBuilder
    private var audioPlayerBar: some View {
        VStack(spacing: 0) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 3)

                    Rectangle()
                        .fill(AnalysisTheme.primaryGold)
                        .frame(width: geometry.size.width * audioPlaybackProgress, height: 3)
                }
            }
            .frame(height: 3)

            // Player controls
            HStack(spacing: 16) {
                // Play/Pause button
                Button(action: { toggleAudioPlayback() }) {
                    Image(systemName: isPlayingAudio ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(AnalysisTheme.primaryGold)
                }

                // Track info
                VStack(alignment: .leading, spacing: 2) {
                    Text("Audio Guide")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AnalysisTheme.textHeading)

                    if let duration = item.audioDuration, duration > 0 {
                        let currentTime = duration * audioPlaybackProgress
                        Text("\(formatTime(currentTime)) / \(formatTime(duration))")
                            .font(.caption)
                            .foregroundColor(AnalysisTheme.textMuted)
                    } else if AudioPlaybackManager.shared.duration > 0 {
                        let duration = AudioPlaybackManager.shared.duration
                        let currentTime = duration * audioPlaybackProgress
                        Text("\(formatTime(currentTime)) / \(formatTime(duration))")
                            .font(.caption)
                            .foregroundColor(AnalysisTheme.textMuted)
                    }
                }

                Spacer()

                // Stop button
                if isPlayingAudio {
                    Button(action: { stopAudio() }) {
                        Image(systemName: "stop.circle")
                            .font(.system(size: 28))
                            .foregroundColor(AnalysisTheme.textMuted)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, y: -2)
        )
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private var audioReadyToast: some View {
        HStack(spacing: 10) {
            Image(systemName: "headphones")
                .font(.system(size: 16, weight: .semibold))
            Text("Audio narration ready")
                .font(.subheadline.weight(.medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.85))
        )
        .padding(.bottom, 32)
    }

    private func audioErrorToast(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .semibold))
            Text(message)
                .font(.subheadline.weight(.medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.85))
        )
        .padding(.bottom, 32)
    }

    // MARK: - Audio Playback Methods

    private func toggleAudioPlayback() {
        if isPlayingAudio {
            pauseAudio()
        } else {
            playAudio()
        }
    }

    private func playAudio() {
        guard let audioFileURL = resolvedAudioFileURL else {
            reportAudioPlaybackError("Audio file missing. Regenerate audio.")
            return
        }

        do {
            try AudioPlaybackManager.shared.playFile(at: audioFileURL) {
                stopAudio()
            }
            isPlayingAudio = true
            startProgressTimer()
        } catch {
            reportAudioPlaybackError("Audio playback failed.")
        }
    }

    private func pauseAudio() {
        AudioPlaybackManager.shared.pause()
        isPlayingAudio = false
        stopProgressTimer()
    }

    private func stopAudio() {
        AudioPlaybackManager.shared.stop()
        isPlayingAudio = false
        audioPlaybackProgress = 0
        stopProgressTimer()
    }

    private func startProgressTimer() {
        stopProgressTimer()
        audioPlaybackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            updatePlaybackProgress()
        }
    }

    private func stopProgressTimer() {
        audioPlaybackTimer?.invalidate()
        audioPlaybackTimer = nil
    }

    private func updatePlaybackProgress() {
        audioPlaybackProgress = AudioPlaybackManager.shared.progress

        if !AudioPlaybackManager.shared.isPlaying {
            isPlayingAudio = false
            audioPlaybackProgress = 0
            stopProgressTimer()
        }
    }

    private func reportAudioPlaybackError(_ message: String) {
        audioPlaybackError = message
        showingAudioErrorToast = true
        // Use Task.sleep for modern async/await pattern instead of DispatchQueue
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000) // 2.5 seconds
            showingAudioErrorToast = false
        }
    }

    private func generateAudioOnly() {
        guard let content = item.summaryContent else { return }

        isGeneratingAudio = true

        Task {
            do {
                let audioService = ElevenLabsAudioService()

                let profile = dataManager.userSettings.preferredReaderProfile
                var voiceConfig = VoiceSelectionConfig.premium(for: profile)
                if !ElevenLabsVoiceRegistry.isPremiumVoiceID(voiceConfig.voiceID) {
                    let fallback = ElevenLabsVoiceRegistry.premiumPrimaryVoice(for: profile)
                    voiceConfig = .custom(profile: profile, voice: fallback)
                }

                let result = try await audioService.generateAudio(
                    text: sanitizeAudioContent(content),
                    voiceID: voiceConfig.voiceID
                )

                guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                    await MainActor.run {
                        isGeneratingAudio = false
                        reportAudioPlaybackError("Unable to access documents directory for audio storage.")
                    }
                    return
                }

                let audioFileName = "audio_\(item.id.uuidString).mp3"
                let audioFileURL = documentsDir.appendingPathComponent(audioFileName)
                try result.data.write(to: audioFileURL)

                let asset = AVURLAsset(url: audioFileURL)
                let duration = try await asset.load(.duration)
                let durationSeconds = CMTimeGetSeconds(duration)

                await MainActor.run {
                    dataManager.updateAudioMetadata(
                        for: item.id,
                        audioFileURL: audioFileName,
                        audioVoiceID: voiceConfig.voiceID,
                        audioDuration: durationSeconds
                    )
                    isGeneratingAudio = false
                    showingAudioReadyToast = true
                }
                // Dismiss toast after delay using modern async/await
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2.0 seconds
                await MainActor.run {
                    showingAudioReadyToast = false
                }
            } catch {
                await MainActor.run {
                    isGeneratingAudio = false
                    reportAudioPlaybackError(error.localizedDescription)
                }
            }
        }
    }

    private func sanitizeAudioContent(_ content: String) -> String {
        var cleaned = content
        cleaned = cleaned.replacingOccurrences(
            of: "\\[[^\\]]+\\]",
            with: "",
            options: .regularExpression
        )
        cleaned = cleaned.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Trigger backend-powered guide generation
    private func generateWithBackend() {
        guard let sourceText = item.summaryContent ?? item.title as String? else { return }

        Task {
            await guideGenerationService.generate(
                sourceText: sourceText,
                readerProfile: InsightAtlasConfig.defaultReaderProfile,
                editorialStance: InsightAtlasConfig.defaultEditorialStance,
                model: InsightAtlasConfig.defaultModel
            )
        }
    }

    /// Convert backend GenerateGuideResponse to local ParsedAnalysisContent format
    private func convertBackendResponse(_ response: GenerateGuideResponse) -> ParsedAnalysisContent {
        // Convert GuideSection array to AnalysisSection array
        let analysisSections: [AnalysisSection] = response.sections.map { guideSection in
            var blocks: [AnalysisContentBlock] = []

            // Create a paragraph block for the section content
            let contentBlock = AnalysisContentBlock(
                type: .paragraph,
                content: guideSection.content
            )
            blocks.append(contentBlock)

            // Add visual block if present
            if let visual = guideSection.visual {
                let visualBlock = AnalysisContentBlock(
                    type: .visual,
                    content: visual.caption ?? "",
                    visual: visual
                )
                blocks.append(visualBlock)
            }

            return AnalysisSection(
                heading: guideSection.heading,
                blocks: blocks
            )
        }

        // Create a quick glance from title and concepts
        let quickGlance = QuickGlanceData(
            coreMessage: response.title,
            keyPoints: response.concepts,
            readingTime: max(1, response.sections.count * 3) // Estimate reading time
        )

        return ParsedAnalysisContent(
            quickGlance: quickGlance,
            sections: analysisSections
        )
    }

    @ViewBuilder
    private func renderSection(_ section: AnalysisSection) -> some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.lg) {
            // Section heading
            if let heading = section.heading {
                Text(heading)
                    .font(.analysisDisplayH2())
                    .foregroundColor(AnalysisTheme.textHeading)
                    .padding(.top, AnalysisTheme.Spacing.md)
            }

            // Section content blocks
            ForEach(Array(section.blocks.enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
    }

    @ViewBuilder
    private func renderBlock(_ block: AnalysisContentBlock) -> some View {
        switch block.type {
        case .paragraph:
            Text(parseMarkdown(block.content))
                .font(.analysisBody())
                .foregroundColor(AnalysisTheme.textBody)
                .lineSpacing(6)

        case .heading1:
            VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.sm) {
                Text(parseMarkdown(block.content))
                    .font(.analysisDisplayH1())
                    .foregroundColor(AnalysisTheme.primaryGold)
                    .tracking(0.5)
                Divider()
                    .background(AnalysisTheme.primaryGoldMuted)
            }
            .padding(.top, AnalysisTheme.Spacing.xl2)
            .padding(.bottom, AnalysisTheme.Spacing.md)

        case .heading2:
            Text(parseMarkdown(block.content))
                .font(.analysisDisplayH2())
                .foregroundColor(AnalysisTheme.textHeading)
                .padding(.top, AnalysisTheme.Spacing.lg)

        case .heading3:
            Text(parseMarkdown(block.content))
                .font(.analysisDisplayH3())
                .foregroundColor(AnalysisTheme.textHeading)
                .padding(.top, AnalysisTheme.Spacing.md)

        case .heading4:
            Text(parseMarkdown(block.content))
                .font(.analysisDisplayH4())
                .foregroundColor(AnalysisTheme.textHeading)
                .padding(.top, AnalysisTheme.Spacing.sm)

        case .blockquote:
            PremiumBlockquoteView(
                text: block.content,
                cite: block.metadata?["cite"]
            )

        case .insightNote:
            PremiumInsightNoteView(
                title: block.metadata?["title"] ?? "Insight Atlas Note",
                content: block.content
            )

        case .actionBox:
            if let steps = block.listItems {
                PremiumActionBoxView(
                    title: block.metadata?["title"] ?? "Apply It",
                    steps: steps
                )
            }

        case .keyTakeaways:
            if let takeaways = block.listItems {
                PremiumKeyTakeawaysView(takeaways: takeaways)
            }

        case .foundationalNarrative:
            PremiumFoundationalNarrativeView(
                title: block.metadata?["title"] ?? "The Insight Atlas Philosophy",
                content: block.content
            )

        case .exercise:
            PremiumExerciseView(
                title: block.metadata?["title"] ?? "Exercise",
                content: block.content,
                steps: block.listItems ?? [],
                estimatedTime: block.metadata?["time"]
            )

        case .flowchart:
            if let steps = block.listItems {
                PremiumFlowchartView(
                    title: block.metadata?["title"] ?? "Visual Guide",
                    steps: steps
                )
            }

        case .bulletList:
            if let items = block.listItems {
                VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.sm) {
                    ForEach(items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .font(.analysisBody())
                                .foregroundColor(AnalysisTheme.primaryGold)
                            Text(parseMarkdown(item))
                                .font(.analysisBody())
                                .foregroundColor(AnalysisTheme.textBody)
                        }
                    }
                }
            }

        case .numberedList:
            if let items = block.listItems {
                VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.sm) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1).")
                                .font(.analysisBody())
                                .foregroundColor(AnalysisTheme.primaryGold)
                                .frame(width: 20, alignment: .leading)
                            Text(parseMarkdown(item))
                                .font(.analysisBody())
                                .foregroundColor(AnalysisTheme.textBody)
                        }
                    }
                }
            }

        case .visual:
            if InsightAtlasConfig.visualsEnabled,
               let visual = block.visual {
                GuideVisualView(visual: visual)
                    .padding(.vertical, AnalysisTheme.Spacing.md)
            }

        case .insightVisual:
            if let visualPayload = block.visualPayload {
                InsightVisualView(visual: visualPayload)
            }

        case .alternativePerspective:
            AlternativePerspectiveView(content: block.content)

        case .researchInsight:
            ResearchInsightView(
                content: block.content,
                source: block.metadata?["source"]
            )

        case .processTimeline:
            if let steps = block.listItems, !steps.isEmpty {
                ProcessTimelineView(steps: steps)
            }

        case .conceptMap:
            let central = block.metadata?["central"] ?? block.content
            let connections = parseConceptMapConnections(from: block.listItems ?? [])
            if !central.isEmpty {
                ConceptMapView(centralConcept: central, connections: connections)
            }

        // Premium block types
        case .premiumQuote:
            PremiumQuoteView(
                quote: block.content,
                author: block.metadata?["attribution"],
                source: block.metadata?["source"]
            )

        case .authorSpotlight:
            PremiumAuthorSpotlightView(
                authorName: block.metadata?["authorName"] ?? "",
                bio: block.content
            )

        case .premiumDivider:
            PremiumSectionDivider()

        case .premiumH1:
            PremiumSectionHeaderH1(title: block.content)

        case .premiumH2:
            PremiumSectionHeaderH2(title: block.content)
        }
    }

    /// Parse markdown inline formatting using Swift's built-in markdown parser with caching
    private func parseMarkdown(_ text: String) -> AttributedString {
        // Check cache first for performance optimization
        if let cached = Self.markdownCache[text] {
            return cached
        }

        let result: AttributedString
        do {
            let sanitized = sanitizeInlineMarkdown(text)
            let attributedString = try AttributedString(
                markdown: sanitized,
                options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            )
            // Skip custom emphasis styling for compatibility with older SDKs.
            result = attributedString
        } catch {
            result = AttributedString(text)
        }

        // Cache the result (limit cache size to prevent memory issues)
        if Self.markdownCache.count < 500 {
            Self.markdownCache[text] = result
        }

        return result
    }

    /// Cache for parsed markdown to avoid redundant parsing
    private static var markdownCache: [String: AttributedString] = [:]

    /// Clear the markdown cache (call on memory warning or view disposal)
    static func clearMarkdownCache() {
        markdownCache.removeAll()
    }

    private func sanitizeInlineMarkdown(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(
            of: #"(?m)^\s{0,3}#{1,6}\s+"#,
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"(?m)^\s*>\s+"#,
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"(?m)^\s*[-*•]\s+"#,
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"(?m)^\s*\d+\.\s+"#,
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\[([^\]]+)\]\([^)]+\)"#,
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(of: "__", with: "")
        result = result.replacingOccurrences(of: "~~", with: "")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseConceptMapConnections(from lines: [String]) -> [(concept: String, relationship: String)] {
        var connections: [(concept: String, relationship: String)] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let pieces: [String]
            if trimmed.contains("—") {
                pieces = trimmed.components(separatedBy: "—")
            } else {
                pieces = trimmed.components(separatedBy: ":")
            }

            let concept = pieces.first?.trimmingCharacters(in: .whitespaces) ?? trimmed
            let relationship = pieces.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
            connections.append((
                concept: concept,
                relationship: relationship.isEmpty ? "relates to" : relationship
            ))
        }

        return connections
    }

    private func shareAnalysis() {
        // Implementation to share analysis
    }
}

// MARK: - Content Models for Analysis Detail

struct ParsedAnalysisContent {
    var quickGlance: QuickGlanceData?
    var sections: [AnalysisSection]

    static func parse(from content: String) -> ParsedAnalysisContent {
        var quickGlance: QuickGlanceData?
        var sections: [AnalysisSection] = []
        var currentSection: AnalysisSection?
        var currentBlocks: [AnalysisContentBlock] = []

        let lines = content.components(separatedBy: "\n")
        var i = 0
        var inQuickGlance = false
        var quickGlanceContent: [String] = []
        var inInsightNote = false
        var insightNoteContent: [String] = []
        var inActionBox = false
        var actionBoxContent: [String] = []
        var inFoundationalNarrative = false
        var foundationalNarrativeContent: [String] = []
        var inExercise = false
        var exerciseContent: [String] = []
        var inTakeaways = false
        var takeawaysContent: [String] = []
        var inFlowchart = false
        var flowchartContent: [String] = []
        // Premium block tracking
        var inPremiumQuote = false
        var premiumQuoteContent: [String] = []
        var inAuthorSpotlight = false
        var authorSpotlightContent: [String] = []
        var inPremiumH1 = false
        var premiumH1Content: [String] = []
        var inPremiumH2 = false
        var premiumH2Content: [String] = []
        var inAlternativePerspective = false
        var alternativePerspectiveContent: [String] = []
        var inResearchInsight = false
        var researchInsightContent: [String] = []
        var inConceptMap = false
        var conceptMapContent: [String] = []
        var conceptMapTitle: String?
        var inProcessTimeline = false
        var processTimelineContent: [String] = []
        var processTimelineTitle: String?
        var inInsightVisual = false
        var insightVisualTag: String?
        var insightVisualTitle: String?
        var insightVisualContent: [String] = []

        func isNewBlockStart(_ line: String) -> Bool {
            if line.hasPrefix("[/") {
                return false
            }
            if line.hasPrefix("#") {
                return true
            }
            let upper = line.uppercased()
            return upper.hasPrefix("[QUICK_GLANCE]") ||
                upper.hasPrefix("[INSIGHT_NOTE]") ||
                upper.hasPrefix("[ACTION_BOX") ||
                upper.hasPrefix("[FOUNDATIONAL_NARRATIVE]") ||
                upper.hasPrefix("[EXERCISE_") ||
                upper.hasPrefix("[TAKEAWAYS]") ||
                upper.hasPrefix("[VISUAL_") ||
                upper.hasPrefix("[PREMIUM_QUOTE]") ||
                upper.hasPrefix("[AUTHOR_SPOTLIGHT]") ||
                upper.hasPrefix("[PREMIUM_H1]") ||
                upper.hasPrefix("[PREMIUM_H2]") ||
                upper.hasPrefix("[ALTERNATIVE_PERSPECTIVE]") ||
                upper.hasPrefix("[RESEARCH_INSIGHT]") ||
                upper.hasPrefix("[CONCEPT_MAP") ||
                upper.hasPrefix("[PROCESS_TIMELINE") ||
                upper.hasPrefix("[PREMIUM_DIVIDER]") ||
                upper.hasPrefix("[STRUCTURE_MAP]")
        }

        func inlineTagContent(_ line: String, tag: String) -> (content: String, title: String?)? {
            let openPrefix = "[\(tag)"
            let closeTag = "[/\(tag)]"
            guard let openRange = line.range(of: openPrefix),
                  let closeRange = line.range(of: closeTag) else {
                return nil
            }
            guard let openEnd = line[openRange.lowerBound...].firstIndex(of: "]") else {
                return nil
            }
            let header = line[line.index(after: openRange.lowerBound)..<openEnd]
            var title: String?
            if let colonIndex = header.firstIndex(of: ":") {
                title = String(header[header.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            }
            let contentRange = line.index(after: openEnd)..<closeRange.lowerBound
            let content = String(line[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (content: content, title: title)
        }

        func inlineExerciseContent(_ line: String) -> (type: String?, content: String)? {
            guard let openStart = line.range(of: "[EXERCISE_"),
                  let openEnd = line[openStart.lowerBound...].firstIndex(of: "]"),
                  let closeRange = line.range(of: "[/EXERCISE_") else {
                return nil
            }
            let typeStart = line.index(openStart.lowerBound, offsetBy: "[EXERCISE_".count)
            let type = String(line[typeStart..<openEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
            let contentRange = line.index(after: openEnd)..<closeRange.lowerBound
            let content = String(line[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (type: type.isEmpty ? nil : type, content: content)
        }

        func flushOpenBlock() {
            if inQuickGlance {
                inQuickGlance = false
                let totalWordCount = content.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
                quickGlance = parseQuickGlance(from: quickGlanceContent.joined(separator: "\n"), totalWordCount: totalWordCount)
                quickGlanceContent = []
            }
            if inInsightNote {
                inInsightNote = false
                let noteContent = insightNoteContent.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                currentBlocks.append(AnalysisContentBlock(
                    type: .insightNote,
                    content: noteContent
                ))
                insightNoteContent = []
            }
            if inActionBox {
                inActionBox = false
                let steps = parseListItems(from: actionBoxContent)
                currentBlocks.append(AnalysisContentBlock(
                    type: .actionBox,
                    content: "",
                    listItems: steps
                ))
                actionBoxContent = []
            }
            if inFoundationalNarrative {
                inFoundationalNarrative = false
                let narrativeContent = foundationalNarrativeContent.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                currentBlocks.append(AnalysisContentBlock(
                    type: .foundationalNarrative,
                    content: narrativeContent
                ))
                foundationalNarrativeContent = []
            }
            if inExercise {
                inExercise = false
                let (exerciseText, steps) = parseExerciseContent(from: exerciseContent)
                currentBlocks.append(AnalysisContentBlock(
                    type: .exercise,
                    content: exerciseText,
                    listItems: steps
                ))
                exerciseContent = []
            }
            if inTakeaways {
                inTakeaways = false
                let items = parseListItems(from: takeawaysContent)
                if items.isEmpty {
                    let fallbackText = takeawaysContent.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !fallbackText.isEmpty {
                        currentBlocks.append(AnalysisContentBlock(
                            type: .paragraph,
                            content: fallbackText
                        ))
                    }
                } else {
                    currentBlocks.append(AnalysisContentBlock(
                        type: .keyTakeaways,
                        content: "",
                        listItems: items
                    ))
                }
                takeawaysContent = []
            }
            if inFlowchart {
                inFlowchart = false
                let flowchartSteps = parseFlowchartSteps(from: flowchartContent)
                currentBlocks.append(AnalysisContentBlock(
                    type: .flowchart,
                    content: "",
                    listItems: flowchartSteps
                ))
                flowchartContent = []
            }
            if inPremiumQuote {
                inPremiumQuote = false
                let quoteContent = premiumQuoteContent.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                currentBlocks.append(AnalysisContentBlock(
                    type: .premiumQuote,
                    content: quoteContent
                ))
                premiumQuoteContent = []
            }
            if inAuthorSpotlight {
                inAuthorSpotlight = false
                let contentText = authorSpotlightContent.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                currentBlocks.append(AnalysisContentBlock(
                    type: .authorSpotlight,
                    content: contentText
                ))
                authorSpotlightContent = []
            }
            if inPremiumH1 {
                inPremiumH1 = false
                let titleText = premiumH1Content.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                if !titleText.isEmpty {
                    currentBlocks.append(AnalysisContentBlock(type: .premiumH1, content: titleText))
                }
                premiumH1Content = []
            }
            if inPremiumH2 {
                inPremiumH2 = false
                let titleText = premiumH2Content.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                if !titleText.isEmpty {
                    currentBlocks.append(AnalysisContentBlock(type: .premiumH2, content: titleText))
                }
                premiumH2Content = []
            }
            if inAlternativePerspective {
                inAlternativePerspective = false
                let contentText = alternativePerspectiveContent.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                currentBlocks.append(AnalysisContentBlock(
                    type: .alternativePerspective,
                    content: contentText
                ))
                alternativePerspectiveContent = []
            }
            if inResearchInsight {
                inResearchInsight = false
                let contentText = researchInsightContent.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                currentBlocks.append(AnalysisContentBlock(
                    type: .researchInsight,
                    content: contentText
                ))
                researchInsightContent = []
            }
            if inConceptMap {
                inConceptMap = false
                let parsedMap = parseConceptMap(from: conceptMapContent)
                if !parsedMap.central.isEmpty || !parsedMap.related.isEmpty {
                    currentBlocks.append(AnalysisContentBlock(
                        type: .conceptMap,
                        content: parsedMap.central,
                        listItems: parsedMap.related
                    ))
                }
                conceptMapContent = []
                conceptMapTitle = nil
            }
            if inProcessTimeline {
                inProcessTimeline = false
                let items = parseProcessTimelineItems(from: processTimelineContent)
                currentBlocks.append(AnalysisContentBlock(
                    type: .processTimeline,
                    content: "",
                    listItems: items
                ))
                processTimelineContent = []
                processTimelineTitle = nil
            }
            if inInsightVisual {
                inInsightVisual = false
                if let tag = insightVisualTag {
                    let parsedVisual = InsightVisualParser.parse(
                        tag: tag,
                        title: insightVisualTitle,
                        lines: insightVisualContent
                    )
                    if let visualPayload = parsedVisual {
                        currentBlocks.append(AnalysisContentBlock(
                            type: .insightVisual,
                            content: "",
                            visualPayload: visualPayload
                        ))
                    }
                }
                insightVisualTag = nil
                insightVisualTitle = nil
                insightVisualContent = []
            }
        }

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)

            if let inline = inlineTagContent(line, tag: "PREMIUM_H1") {
                currentBlocks.append(AnalysisContentBlock(type: .premiumH1, content: stripInlineMarkdown(inline.content)))
                i += 1
                continue
            }
            if let inline = inlineTagContent(line, tag: "PREMIUM_H2") {
                currentBlocks.append(AnalysisContentBlock(type: .premiumH2, content: stripInlineMarkdown(inline.content)))
                i += 1
                continue
            }
            if let inline = inlineTagContent(line, tag: "INSIGHT_NOTE") {
                currentBlocks.append(AnalysisContentBlock(
                    type: .insightNote,
                    content: stripInlineMarkdown(inline.content)
                ))
                i += 1
                continue
            }
            if let inline = inlineTagContent(line, tag: "ACTION_BOX") {
                let steps = parseListItems(from: inline.content.components(separatedBy: "\n"))
                currentBlocks.append(AnalysisContentBlock(
                    type: .actionBox,
                    content: "",
                    listItems: steps
                ))
                i += 1
                continue
            }
            if let inline = inlineTagContent(line, tag: "TAKEAWAYS") {
                let items = parseListItems(from: inline.content.components(separatedBy: "\n"))
                if items.isEmpty {
                    currentBlocks.append(AnalysisContentBlock(type: .paragraph, content: stripInlineMarkdown(inline.content)))
                } else {
                    currentBlocks.append(AnalysisContentBlock(type: .keyTakeaways, content: "", listItems: items))
                }
                i += 1
                continue
            }
            if let inline = inlineTagContent(line, tag: "PREMIUM_QUOTE") {
                currentBlocks.append(AnalysisContentBlock(
                    type: .premiumQuote,
                    content: stripInlineMarkdown(inline.content)
                ))
                i += 1
                continue
            }
            if let inline = inlineTagContent(line, tag: "AUTHOR_SPOTLIGHT") {
                currentBlocks.append(AnalysisContentBlock(
                    type: .authorSpotlight,
                    content: stripInlineMarkdown(inline.content)
                ))
                i += 1
                continue
            }
            if let inline = inlineTagContent(line, tag: "ALTERNATIVE_PERSPECTIVE") {
                currentBlocks.append(AnalysisContentBlock(
                    type: .alternativePerspective,
                    content: stripInlineMarkdown(inline.content)
                ))
                i += 1
                continue
            }
            if let inline = inlineTagContent(line, tag: "RESEARCH_INSIGHT") {
                currentBlocks.append(AnalysisContentBlock(
                    type: .researchInsight,
                    content: stripInlineMarkdown(inline.content)
                ))
                i += 1
                continue
            }
            if let inline = inlineTagContent(line, tag: "FOUNDATIONAL_NARRATIVE") {
                currentBlocks.append(AnalysisContentBlock(
                    type: .foundationalNarrative,
                    content: stripInlineMarkdown(inline.content)
                ))
                i += 1
                continue
            }
            if let inline = inlineExerciseContent(line) {
                let (exerciseText, steps) = parseExerciseContent(from: inline.content.components(separatedBy: "\n"))
                currentBlocks.append(AnalysisContentBlock(
                    type: .exercise,
                    content: exerciseText,
                    listItems: steps
                ))
                i += 1
                continue
            }

            if isNewBlockStart(line) && (
                inQuickGlance || inInsightNote || inActionBox || inFoundationalNarrative || inExercise ||
                inTakeaways || inFlowchart || inPremiumQuote || inAuthorSpotlight || inPremiumH1 ||
                inPremiumH2 || inAlternativePerspective || inResearchInsight || inConceptMap ||
                inProcessTimeline || inInsightVisual
            ) {
                flushOpenBlock()
            }

            if inTakeaways && isNewBlockStart(line) {
                inTakeaways = false
                let items = parseListItems(from: takeawaysContent)
                if items.isEmpty {
                    let fallbackText = takeawaysContent.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !fallbackText.isEmpty {
                        currentBlocks.append(AnalysisContentBlock(
                            type: .paragraph,
                            content: fallbackText
                        ))
                    }
                } else {
                    currentBlocks.append(AnalysisContentBlock(
                        type: .keyTakeaways,
                        content: "",
                        listItems: items
                    ))
                }
                takeawaysContent = []
            }

            if let visualOpen = parseVisualOpen(line) {
                inInsightVisual = true
                insightVisualTag = visualOpen.tag
                insightVisualTitle = visualOpen.title
                insightVisualContent = []
                i += 1
                continue
            }

            if let visualClose = parseVisualClose(line) {
                if inInsightVisual, insightVisualTag == visualClose {
                    let parsedVisual = InsightVisualParser.parse(
                        tag: visualClose,
                        title: insightVisualTitle,
                        lines: insightVisualContent
                    )
                    if let visualPayload = parsedVisual {
                        currentBlocks.append(AnalysisContentBlock(
                            type: .insightVisual,
                            content: "",
                            visualPayload: visualPayload
                        ))
                    }
                    inInsightVisual = false
                    insightVisualTag = nil
                    insightVisualTitle = nil
                    insightVisualContent = []
                    i += 1
                    continue
                }
            }

            if inInsightVisual {
                insightVisualContent.append(line)
                i += 1
                continue
            }

            // Quick Glance block
            if line.hasPrefix("[QUICK_GLANCE]") {
                inQuickGlance = true
                quickGlanceContent = []
                i += 1
                continue
            }
            if line.hasPrefix("[/QUICK_GLANCE]") {
                inQuickGlance = false
                // Calculate reading time based on TOTAL content, not just quick glance
                let totalWordCount = content.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
                quickGlance = parseQuickGlance(from: quickGlanceContent.joined(separator: "\n"), totalWordCount: totalWordCount)
                i += 1
                continue
            }
            if inQuickGlance {
                quickGlanceContent.append(line)
                i += 1
                continue
            }

            // Insight Note block
            if line.hasPrefix("[INSIGHT_NOTE]") {
                inInsightNote = true
                insightNoteContent = []
                i += 1
                continue
            }
            if line.hasPrefix("[/INSIGHT_NOTE]") {
                inInsightNote = false
                let noteContent = insightNoteContent.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                currentBlocks.append(AnalysisContentBlock(
                    type: .insightNote,
                    content: noteContent
                ))
                i += 1
                continue
            }
            if inInsightNote {
                insightNoteContent.append(line)
                i += 1
                continue
            }

            // Action Box block
            if line.hasPrefix("[ACTION_BOX") {
                inActionBox = true
                actionBoxContent = []
                i += 1
                continue
            }
            if line.hasPrefix("[/ACTION_BOX]") {
                inActionBox = false
                let steps = parseListItems(from: actionBoxContent)
                currentBlocks.append(AnalysisContentBlock(
                    type: .actionBox,
                    content: "",
                    listItems: steps
                ))
                i += 1
                continue
            }
            if inActionBox {
                actionBoxContent.append(line)
                i += 1
                continue
            }

            // Foundational Narrative block
            if line.hasPrefix("[FOUNDATIONAL_NARRATIVE]") {
                inFoundationalNarrative = true
                foundationalNarrativeContent = []
                i += 1
                continue
            }
            if line.hasPrefix("[/FOUNDATIONAL_NARRATIVE]") {
                inFoundationalNarrative = false
                let narrativeContent = foundationalNarrativeContent.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                currentBlocks.append(AnalysisContentBlock(
                    type: .foundationalNarrative,
                    content: narrativeContent
                ))
                i += 1
                continue
            }
            if inFoundationalNarrative {
                // Strip markdown heading prefixes from foundational narrative content
                var cleanedLine = line
                if cleanedLine.hasPrefix("#### ") {
                    cleanedLine = String(cleanedLine.dropFirst(5))
                } else if cleanedLine.hasPrefix("### ") {
                    cleanedLine = String(cleanedLine.dropFirst(4))
                } else if cleanedLine.hasPrefix("## ") {
                    cleanedLine = String(cleanedLine.dropFirst(3))
                } else if cleanedLine.hasPrefix("# ") {
                    cleanedLine = String(cleanedLine.dropFirst(2))
                }
                foundationalNarrativeContent.append(cleanedLine)
                i += 1
                continue
            }

            // Exercise block
            if line.hasPrefix("[EXERCISE_") {
                inExercise = true
                exerciseContent = []
                i += 1
                continue
            }
            if line.hasPrefix("[/EXERCISE_") {
                inExercise = false
                let (exerciseText, steps) = parseExerciseContent(from: exerciseContent)
                currentBlocks.append(AnalysisContentBlock(
                    type: .exercise,
                    content: exerciseText,
                    listItems: steps
                ))
                i += 1
                continue
            }
            if inExercise {
                exerciseContent.append(line)
                i += 1
                continue
            }

            // Takeaways block
            if line.hasPrefix("[TAKEAWAYS]") {
                inTakeaways = true
                takeawaysContent = []
                i += 1
                continue
            }
            if line.hasPrefix("[/TAKEAWAYS]") {
                inTakeaways = false
                let items = parseListItems(from: takeawaysContent)
                if items.isEmpty {
                    let fallbackText = takeawaysContent.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !fallbackText.isEmpty {
                        currentBlocks.append(AnalysisContentBlock(
                            type: .paragraph,
                            content: fallbackText
                        ))
                    }
                } else {
                    currentBlocks.append(AnalysisContentBlock(
                        type: .keyTakeaways,
                        content: "",
                        listItems: items
                    ))
                }
                i += 1
                continue
            }
            if inTakeaways {
                takeawaysContent.append(line)
                i += 1
                continue
            }

            // Flowchart block
            if line.hasPrefix("[VISUAL_FLOWCHART") {
                inFlowchart = true
                flowchartContent = []
                i += 1
                continue
            }
            if line.hasPrefix("[/VISUAL_FLOWCHART]") {
                inFlowchart = false
                let steps = parseFlowchartSteps(from: flowchartContent)
                currentBlocks.append(AnalysisContentBlock(
                    type: .flowchart,
                    content: "",
                    listItems: steps
                ))
                i += 1
                continue
            }
            if inFlowchart {
                flowchartContent.append(line)
                i += 1
                continue
            }

            // Alternative Perspective block
            if line.hasPrefix("[ALTERNATIVE_PERSPECTIVE]") {
                inAlternativePerspective = true
                alternativePerspectiveContent = []
                i += 1
                continue
            }
            if line.hasPrefix("[/ALTERNATIVE_PERSPECTIVE]") {
                inAlternativePerspective = false
                let contentText = alternativePerspectiveContent
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                currentBlocks.append(AnalysisContentBlock(
                    type: .alternativePerspective,
                    content: contentText
                ))
                i += 1
                continue
            }
            if inAlternativePerspective {
                alternativePerspectiveContent.append(line)
                i += 1
                continue
            }

            // Research Insight block
            if line.hasPrefix("[RESEARCH_INSIGHT]") {
                inResearchInsight = true
                researchInsightContent = []
                i += 1
                continue
            }
            if line.hasPrefix("[/RESEARCH_INSIGHT]") {
                inResearchInsight = false
                let parsedInsight = parseResearchInsight(from: researchInsightContent)
                var metadata: [String: String] = [:]
                if let source = parsedInsight.source, !source.isEmpty {
                    metadata["source"] = source
                }
                currentBlocks.append(AnalysisContentBlock(
                    type: .researchInsight,
                    content: parsedInsight.content,
                    metadata: metadata.isEmpty ? nil : metadata
                ))
                i += 1
                continue
            }
            if inResearchInsight {
                researchInsightContent.append(line)
                i += 1
                continue
            }

            // Concept Map block
            if line.hasPrefix("[CONCEPT_MAP") {
                inConceptMap = true
                conceptMapContent = []
                if let colonIndex = line.firstIndex(of: ":") {
                    let afterColon = line[line.index(after: colonIndex)...]
                    conceptMapTitle = afterColon.replacingOccurrences(of: "]", with: "").trimmingCharacters(in: .whitespaces)
                } else {
                    conceptMapTitle = nil
                }
                i += 1
                continue
            }
            if line.hasPrefix("[/CONCEPT_MAP]") {
                inConceptMap = false
                let parsedMap = parseConceptMap(from: conceptMapContent)
                var metadata: [String: String] = [:]
                if let title = conceptMapTitle, !title.isEmpty {
                    metadata["title"] = title
                }
                if !parsedMap.central.isEmpty {
                    metadata["central"] = parsedMap.central
                }
                currentBlocks.append(AnalysisContentBlock(
                    type: .conceptMap,
                    content: parsedMap.central,
                    listItems: parsedMap.related,
                    metadata: metadata.isEmpty ? nil : metadata
                ))
                i += 1
                continue
            }
            if inConceptMap {
                conceptMapContent.append(line)
                i += 1
                continue
            }

            // Process Timeline block
            if line.hasPrefix("[PROCESS_TIMELINE") {
                inProcessTimeline = true
                processTimelineContent = []
                if let colonIndex = line.firstIndex(of: ":") {
                    let afterColon = line[line.index(after: colonIndex)...]
                    processTimelineTitle = afterColon.replacingOccurrences(of: "]", with: "").trimmingCharacters(in: .whitespaces)
                } else {
                    processTimelineTitle = nil
                }
                i += 1
                continue
            }
            if line.hasPrefix("[/PROCESS_TIMELINE]") {
                inProcessTimeline = false
                let items = parseProcessTimelineItems(from: processTimelineContent)
                var metadata: [String: String] = [:]
                if let title = processTimelineTitle, !title.isEmpty {
                    metadata["title"] = title
                }
                currentBlocks.append(AnalysisContentBlock(
                    type: .processTimeline,
                    content: "",
                    listItems: items,
                    metadata: metadata.isEmpty ? nil : metadata
                ))
                i += 1
                continue
            }
            if inProcessTimeline {
                processTimelineContent.append(line)
                i += 1
                continue
            }

            // Premium Quote block
            if line.hasPrefix("[PREMIUM_QUOTE]") {
                inPremiumQuote = true
                premiumQuoteContent = []
                i += 1
                continue
            }
            if line.hasPrefix("[/PREMIUM_QUOTE]") {
                inPremiumQuote = false
                let (quoteText, attribution, source) = parsePremiumQuote(from: premiumQuoteContent)
                currentBlocks.append(AnalysisContentBlock(
                    type: .premiumQuote,
                    content: quoteText,
                    metadata: [
                        "attribution": attribution ?? "",
                        "source": source ?? ""
                    ]
                ))
                i += 1
                continue
            }
            if inPremiumQuote {
                premiumQuoteContent.append(line)
                i += 1
                continue
            }

            // Author Spotlight block
            if line.hasPrefix("[AUTHOR_SPOTLIGHT]") {
                inAuthorSpotlight = true
                authorSpotlightContent = []
                i += 1
                continue
            }
            if line.hasPrefix("[/AUTHOR_SPOTLIGHT]") {
                inAuthorSpotlight = false
                let (authorName, bio) = parseAuthorSpotlight(from: authorSpotlightContent)
                currentBlocks.append(AnalysisContentBlock(
                    type: .authorSpotlight,
                    content: bio,
                    metadata: ["authorName": authorName]
                ))
                i += 1
                continue
            }
            if inAuthorSpotlight {
                authorSpotlightContent.append(line)
                i += 1
                continue
            }

            // Premium Divider - single tag, no content
            if line.hasPrefix("[PREMIUM_DIVIDER]") {
                currentBlocks.append(AnalysisContentBlock(
                    type: .premiumDivider,
                    content: ""
                ))
                i += 1
                continue
            }

            // Premium H1 block
            if line.hasPrefix("[PREMIUM_H1]") {
                inPremiumH1 = true
                premiumH1Content = []
                i += 1
                continue
            }
            if line.hasPrefix("[/PREMIUM_H1]") {
                inPremiumH1 = false
                let title = premiumH1Content.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                currentBlocks.append(AnalysisContentBlock(
                    type: .premiumH1,
                    content: title
                ))
                i += 1
                continue
            }
            if inPremiumH1 {
                premiumH1Content.append(line)
                i += 1
                continue
            }

            // Premium H2 block
            if line.hasPrefix("[PREMIUM_H2]") {
                inPremiumH2 = true
                premiumH2Content = []
                i += 1
                continue
            }
            if line.hasPrefix("[/PREMIUM_H2]") {
                inPremiumH2 = false
                let title = premiumH2Content.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                currentBlocks.append(AnalysisContentBlock(
                    type: .premiumH2,
                    content: title
                ))
                i += 1
                continue
            }
            if inPremiumH2 {
                premiumH2Content.append(line)
                i += 1
                continue
            }

            // Skip other block markers
            if line.hasPrefix("[") && line.contains("]") && !line.contains("](") {
                i += 1
                continue
            }

            // H1 headers (# heading) - for PART titles, main sections
            if line.hasPrefix("# ") && !line.hasPrefix("## ") {
                currentBlocks.append(AnalysisContentBlock(
                    type: .heading1,
                    content: String(line.dropFirst(2))
                ))
                i += 1
                continue
            }

            // Section headers (## heading)
            if line.hasPrefix("## ") {
                // Save current section if exists
                if let current = currentSection {
                    var updatedSection = current
                    updatedSection.blocks = currentBlocks
                    sections.append(updatedSection)
                }

                let heading = String(line.dropFirst(3))
                currentSection = AnalysisSection(heading: heading, blocks: [])
                currentBlocks = []
                i += 1
                continue
            }

            // Subheadings
            if line.hasPrefix("### ") {
                currentBlocks.append(AnalysisContentBlock(
                    type: .heading3,
                    content: String(line.dropFirst(4))
                ))
                i += 1
                continue
            }

            if line.hasPrefix("#### ") {
                currentBlocks.append(AnalysisContentBlock(
                    type: .heading4,
                    content: String(line.dropFirst(5))
                ))
                i += 1
                continue
            }

            // Blockquote
            if line.hasPrefix(">") {
                var quoteLines: [String] = []
                while i < lines.count && lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                    let quoteLine = String(lines[i].trimmingCharacters(in: .whitespaces).dropFirst()).trimmingCharacters(in: .whitespaces)
                    quoteLines.append(quoteLine)
                    i += 1
                }
                currentBlocks.append(AnalysisContentBlock(
                    type: .blockquote,
                    content: quoteLines.joined(separator: " ")
                ))
                continue
            }

            // Regular paragraph
            if !line.isEmpty && !line.hasPrefix("-") && !line.hasPrefix("*") && !line.hasPrefix("|") {
                currentBlocks.append(AnalysisContentBlock(
                    type: .paragraph,
                    content: line
                ))
            }

            i += 1
        }

        flushOpenBlock()

        // Save final section
        if let current = currentSection {
            var updatedSection = current
            updatedSection.blocks = currentBlocks
            sections.append(updatedSection)
        } else if !currentBlocks.isEmpty {
            sections.append(AnalysisSection(heading: nil, blocks: currentBlocks))
        }

        return ParsedAnalysisContent(quickGlance: quickGlance, sections: sections)
    }

    /// Parse Quick Glance data from the Quick Glance block content
    /// - Parameters:
    ///   - content: The Quick Glance block content text
    ///   - totalWordCount: The total word count of the entire analysis for accurate reading time
    private static func parseQuickGlance(from content: String, totalWordCount: Int? = nil) -> QuickGlanceData {
        var coreMessage = ""
        var keyPoints: [String] = []
        var inKeyInsightsSection = false

        let lines = content.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") {
                continue
            }
            let cleaned = stripInlineMarkdown(trimmed)
            let lower = cleaned.lowercased()

            // Check for "Key Insights:" section header
            if lower.contains("key insights") && lower.contains(":") {
                inKeyInsightsSection = true
                continue
            }

            // Check for other section headers that end the key insights section
            if inKeyInsightsSection && (lower.hasPrefix("**") && lower.contains(":") && !lower.contains("insight")) {
                inKeyInsightsSection = false
            }

            if lower.contains("core message") || lower.contains("core thesis") ||
               lower.contains("one-sentence premise") || lower.contains("central thesis") {
                // Extract the message after the colon
                if let colonIndex = cleaned.firstIndex(of: ":") {
                    coreMessage = String(cleaned[cleaned.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                }
            } else if cleaned.hasPrefix("- ") || cleaned.hasPrefix("* ") || cleaned.hasPrefix("• ") {
                let cleanPoint = String(cleaned.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !cleanPoint.isEmpty && cleanPoint.count > 10 { // Filter out very short items
                    keyPoints.append(cleanPoint)
                }
            } else if cleaned.hasPrefix("-") || cleaned.hasPrefix("*") || cleaned.hasPrefix("•") {
                let cleanPoint = String(cleaned.dropFirst(1)).trimmingCharacters(in: .whitespaces)
                if !cleanPoint.isEmpty && cleanPoint.count > 10 {
                    keyPoints.append(cleanPoint)
                }
            } else if let range = cleaned.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                let cleanPoint = String(cleaned[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !cleanPoint.isEmpty && cleanPoint.count > 10 {
                    keyPoints.append(cleanPoint)
                }
            }
        }

        // If we still don't have a core message, try to extract from the first substantial paragraph
        if coreMessage.isEmpty {
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let cleaned = stripInlineMarkdown(trimmed)
                // Skip headers, list items, and short lines
                if cleaned.hasPrefix("#") || cleaned.hasPrefix("-") || cleaned.hasPrefix("*") ||
                   cleaned.hasPrefix("•") || cleaned.count < 50 {
                    continue
                }
                // Skip section headers
                let lower = cleaned.lowercased()
                if lower.contains("key insight") || lower.contains("core message") {
                    continue
                }
                // Use first substantial paragraph as core message
                if cleaned.count >= 50 {
                    // Truncate to first sentence if very long
                    if let sentenceEnd = cleaned.firstIndex(of: ".") {
                        coreMessage = String(cleaned[...sentenceEnd])
                    } else {
                        coreMessage = String(cleaned.prefix(200))
                    }
                    break
                }
            }
        }

        // Calculate reading time based on TOTAL content word count (250 words per minute is standard)
        let wordsPerMinute = 250
        let wordCount = totalWordCount ?? content.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        let readingTime = max(1, wordCount / wordsPerMinute)

        // Provide meaningful fallback messages
        let fallbackMessage = "This guide synthesizes the book's key concepts, practical frameworks, and actionable insights."
        let fallbackPoints = [
            "Explore the author's core framework and methodology",
            "Discover practical strategies you can apply immediately",
            "Understand the key principles that drive lasting change"
        ]

        return QuickGlanceData(
            coreMessage: coreMessage.isEmpty ? fallbackMessage : coreMessage,
            keyPoints: keyPoints.isEmpty ? fallbackPoints : keyPoints,
            readingTime: readingTime
        )
    }

    private static func parseListItems(from lines: [String]) -> [String] {
        var items: [String] = []
        for line in lines {
            let trimmed = stripInlineMarkdown(line.trimmingCharacters(in: .whitespaces))
            if trimmed.hasPrefix("- ") {
                items.append(String(trimmed.dropFirst(2)))
            } else if trimmed.hasPrefix("-") {
                items.append(String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces))
            } else if trimmed.hasPrefix("* ") {
                items.append(String(trimmed.dropFirst(2)))
            } else if trimmed.hasPrefix("*") {
                items.append(String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces))
            } else if trimmed.hasPrefix("• ") {
                items.append(String(trimmed.dropFirst(2)))
            } else if trimmed.hasPrefix("•") {
                items.append(String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces))
            } else if trimmed.range(of: "^\\d+\\.\\s+", options: .regularExpression) != nil {
                let text = trimmed.replacingOccurrences(of: "^\\d+\\.\\s+", with: "", options: .regularExpression)
                items.append(text)
            } else if trimmed.range(of: "^\\d+\\.", options: .regularExpression) != nil {
                let text = trimmed.replacingOccurrences(of: "^\\d+\\.", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
                items.append(text)
            }
        }
        return items
    }

    private static func parseExerciseContent(from lines: [String]) -> (String, [String]) {
        var text = ""
        var steps: [String] = []

        for line in lines {
            let trimmed = stripInlineMarkdown(line.trimmingCharacters(in: .whitespaces))
            if trimmed.hasPrefix("- ") {
                steps.append(String(trimmed.dropFirst(2)))
            } else if trimmed.hasPrefix("-") {
                steps.append(String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces))
            } else if trimmed.hasPrefix("* ") {
                steps.append(String(trimmed.dropFirst(2)))
            } else if trimmed.hasPrefix("*") {
                steps.append(String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces))
            } else if trimmed.hasPrefix("• ") {
                steps.append(String(trimmed.dropFirst(2)))
            } else if trimmed.hasPrefix("•") {
                steps.append(String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces))
            } else if trimmed.range(of: "^\\d+\\.\\s+", options: .regularExpression) != nil {
                let stepText = trimmed.replacingOccurrences(of: "^\\d+\\.\\s+", with: "", options: .regularExpression)
                steps.append(stepText)
            } else if trimmed.range(of: "^\\d+\\.", options: .regularExpression) != nil {
                let stepText = trimmed.replacingOccurrences(of: "^\\d+\\.", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
                steps.append(stepText)
            } else if !trimmed.isEmpty {
                text += (text.isEmpty ? "" : " ") + trimmed
            }
        }

        return (text, steps)
    }

    private static func stripInlineMarkdown(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(
            of: #"(?m)^\s{0,3}#{1,6}\s+"#,
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(of: "**", with: "")
        result = result.replacingOccurrences(of: "__", with: "")
        result = result.replacingOccurrences(of: "*", with: "")
        result = result.replacingOccurrences(of: "_", with: "")
        result = result.replacingOccurrences(
            of: #"\[([^\]]+)\]\([^)]+\)"#,
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"`([^`]+)`"#,
            with: "$1",
            options: .regularExpression
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseFlowchartSteps(from lines: [String]) -> [String] {
        var steps: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Skip arrows and empty lines
            if !trimmed.isEmpty && trimmed != "↓" && !trimmed.contains("─") && !trimmed.contains("│") {
                steps.append(trimmed)
            }
        }
        return steps
    }

    private static func parseResearchInsight(from lines: [String]) -> (content: String, source: String?) {
        var contentLines: [String] = []
        var source: String?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("source:") {
                if let colonIndex = trimmed.firstIndex(of: ":") {
                    source = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                }
            } else if !trimmed.isEmpty {
                contentLines.append(trimmed)
            }
        }

        return (contentLines.joined(separator: " "), source)
    }

    private static func parseConceptMap(from lines: [String]) -> (central: String, related: [String]) {
        var central = ""
        var related: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if central.isEmpty {
                if trimmed.lowercased().hasPrefix("central:") ||
                    trimmed.lowercased().hasPrefix("main:") ||
                    trimmed.lowercased().hasPrefix("core:") {
                    if let colonIndex = trimmed.firstIndex(of: ":") {
                        central = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                        continue
                    }
                }
                central = trimmed
                continue
            }

            var entry = trimmed
            if entry.hasPrefix("→") || entry.hasPrefix("-") || entry.hasPrefix("•") || entry.hasPrefix("*") {
                entry = String(entry.dropFirst()).trimmingCharacters(in: .whitespaces)
            }

            if let colonIndex = entry.firstIndex(of: ":") {
                let concept = String(entry[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let relationship = String(entry[entry.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                if relationship.isEmpty {
                    related.append(concept)
                } else {
                    related.append("\(concept) — \(relationship)")
                }
            } else {
                related.append(entry)
            }
        }

        return (central, related)
    }

    private static func parseProcessTimelineItems(from lines: [String]) -> [String] {
        let listItems = parseListItems(from: lines)
        if !listItems.isEmpty {
            return listItems
        }

        var items: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && trimmed != "↓" && !trimmed.contains("─") && !trimmed.contains("│") {
                items.append(trimmed)
            }
        }
        return items
    }

    private static func parseVisualOpen(_ line: String) -> (tag: String, title: String?)? {
        guard line.hasPrefix("[") && line.hasSuffix("]") else { return nil }
        guard !line.hasPrefix("[/") else { return nil }
        let raw = line.dropFirst().dropLast()
        let parts = raw.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
        let tag = canonicalVisualTag(parts.first ?? "")
        guard tag.hasPrefix("VISUAL_") else { return nil }
        let title = parts.count > 1 ? parts[1] : nil
        return (tag: tag, title: title)
    }

    private static func parseVisualClose(_ line: String) -> String? {
        guard line.hasPrefix("[/") && line.hasSuffix("]") else { return nil }
        let raw = line.dropFirst(2).dropLast()
        let tag = canonicalVisualTag(String(raw))
        guard tag.hasPrefix("VISUAL_") else { return nil }
        return tag
    }

    private static func canonicalVisualTag(_ tag: String) -> String {
        let upper = tag.uppercased()
        switch upper {
        case "VISUAL_TABLE", "VISUAL_COMPARISON", "VISUAL_COMPARISON_TABLE":
            return InsightVisualType.comparisonMatrix.rawValue
        case "CONCEPT_MAP":
            return InsightVisualType.conceptMap.rawValue
        case "PROCESS_TIMELINE":
            return InsightVisualType.timeline.rawValue
        case "HIERARCHY_DIAGRAM":
            return InsightVisualType.hierarchy.rawValue
        case "VISUAL_FLOW_DIAGRAM":
            return InsightVisualType.flowchart.rawValue
        default:
            return upper
        }
    }

    /// Parse premium quote content into quote text, attribution, and source
    private static func parsePremiumQuote(from lines: [String]) -> (String, String?, String?) {
        var quoteLines: [String] = []
        var attribution: String? = nil
        var source: String? = nil

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("—") || trimmed.hasPrefix("-") {
                // This is attribution line
                let attrText = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                // Check if there's a source in parentheses or after comma
                if let parenRange = attrText.range(of: "(") {
                    attribution = String(attrText[..<parenRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    source = String(attrText[parenRange.lowerBound...])
                        .replacingOccurrences(of: "(", with: "")
                        .replacingOccurrences(of: ")", with: "")
                } else if let commaRange = attrText.range(of: ",") {
                    attribution = String(attrText[..<commaRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    source = String(attrText[commaRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                } else {
                    attribution = attrText
                }
            } else if !trimmed.isEmpty {
                quoteLines.append(trimmed)
            }
        }

        return (quoteLines.joined(separator: " "), attribution, source)
    }

    /// Parse author spotlight content into author name and bio
    private static func parseAuthorSpotlight(from lines: [String]) -> (String, String) {
        var authorName: String = ""
        var bioLines: [String] = []

        let nonEmptyLines = lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        for (index, line) in nonEmptyLines.enumerated() {
            if index == 0 {
                authorName = line
            } else {
                bioLines.append(line)
            }
        }

        return (authorName, bioLines.joined(separator: " "))
    }

    /// Extract all visual image URLs from the parsed content
    /// Used for prefetching before PDF export
    func allVisualURLs() -> [URL] {
        var urls: [URL] = []
        for section in sections {
            for block in section.blocks {
                if let visual = block.visual {
                    urls.append(visual.imageURL)
                }
            }
        }
        return urls
    }
}

struct QuickGlanceData {
    let coreMessage: String
    let keyPoints: [String]
    let readingTime: Int
}

struct AnalysisSection {
    let heading: String?
    var blocks: [AnalysisContentBlock]
}

struct AnalysisContentBlock {
    let type: AnalysisBlockType
    let content: String
    var listItems: [String]?
    var metadata: [String: String]?
    var visual: GuideVisual?
    var visualPayload: InsightVisual?

    init(
        type: AnalysisBlockType,
        content: String,
        listItems: [String]? = nil,
        metadata: [String: String]? = nil,
        visual: GuideVisual? = nil,
        visualPayload: InsightVisual? = nil
    ) {
        self.type = type
        self.content = content
        self.listItems = listItems
        self.metadata = metadata
        self.visual = visual
        self.visualPayload = visualPayload
    }
}

enum AnalysisBlockType {
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
    case bulletList
    case numberedList
    case visual
    case insightVisual
    case alternativePerspective
    case researchInsight
    case processTimeline
    case conceptMap
    // Premium block types
    case premiumQuote
    case authorSpotlight
    case premiumDivider
    case premiumH1
    case premiumH2
}

// MARK: - Export Options View

struct AnalysisExportOptionsView: View {
    let item: LibraryItem
    let parsedContent: ParsedAnalysisContent?
    let layoutScore: LayoutScore?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    @State private var isExporting = false
    @State private var exportError: String?

    var body: some View {
        NavigationView {
            List {
                Section("Export Format") {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Button(action: { exportAs(format) }) {
                            HStack {
                                Label(format.rawValue, systemImage: iconFor(format))
                                Spacer()
                                // Show warning icon for low layout scores
                                if let score = layoutScore {
                                    let formatScore = scoreFor(format: format, from: score)
                                    if formatScore < 0.85 {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                        .disabled(isExporting)
                    }
                }

                // Layout quality warning
                if let score = layoutScore {
                    let pdfScore = score.pdf
                    if pdfScore < 0.85 {
                        Section {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Layout quality may be reduced")
                                        .font(.subheadline.weight(.medium))
                                    Text("PDF score: \(Int(pdfScore * 100))%. Some sections may need adjustment.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if let error = exportError {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Export Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if isExporting {
                    ProgressView("Exporting...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 10)
                }
            }
        }
    }

    private func iconFor(_ format: ExportFormat) -> String {
        switch format {
        case .markdown: return "doc.text"
        case .plainText: return "doc.plaintext"
        case .html: return "globe"
        case .pdf: return "doc.fill"
        case .docx: return "doc.richtext"
        }
    }

    private func scoreFor(format: ExportFormat, from score: LayoutScore) -> Double {
        switch format {
        case .pdf: return score.pdf
        case .docx: return score.docx
        case .html: return score.html
        case .markdown, .plainText: return score.overall
        }
    }

    private func exportAs(_ format: ExportFormat) {
        isExporting = true
        exportError = nil

        Task { @MainActor in
            do {
                // For PDF export, prefetch all visual images to ensure they're cached locally
                if format == .pdf, InsightAtlasConfig.visualsEnabled, let content = parsedContent {
                    let visualURLs = content.allVisualURLs()
                    if !visualURLs.isEmpty {
                        await VisualAssetCache.shared.prefetchAll(urls: visualURLs)
                    }
                }

                // Generate the export file (DataManager is @MainActor so this is safe)
                let url = try dataManager.exportGuide(item, format: format)

                // Verify file exists and is readable before sharing
                guard FileManager.default.fileExists(atPath: url.path),
                      FileManager.default.isReadableFile(atPath: url.path) else {
                    isExporting = false
                    exportError = "Failed to create export file"
                    return
                }

                // Copy to a more stable location to prevent ShareKit background thread issues
                guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                    isExporting = false
                    exportError = "Unable to access documents directory for sharing."
                    return
                }
                let shareURL = documentsDir.appendingPathComponent(url.lastPathComponent)

                // Remove existing file if present
                try? FileManager.default.removeItem(at: shareURL)
                try FileManager.default.copyItem(at: url, to: shareURL)

                isExporting = false

                // Present share sheet with the stable URL
                let activityVC = UIActivityViewController(
                    activityItems: [shareURL],
                    applicationActivities: nil
                )

                // Set completion handler to clean up the copied file after sharing
                activityVC.completionWithItemsHandler = { _, _, _, _ in
                    try? FileManager.default.removeItem(at: shareURL)
                }

                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootVC = window.rootViewController {
                    var topController = rootVC
                    while let presented = topController.presentedViewController {
                        topController = presented
                    }
                    // Configure popover for iPad - required to prevent crash
                    if let popover = activityVC.popoverPresentationController {
                        popover.sourceView = topController.view
                        popover.sourceRect = CGRect(
                            x: topController.view.bounds.midX,
                            y: topController.view.bounds.midY,
                            width: 0,
                            height: 0
                        )
                        popover.permittedArrowDirections = []
                    }
                    topController.present(activityVC, animated: true)
                }
            } catch {
                isExporting = false
                exportError = error.localizedDescription
            }
        }
    }
}

// MARK: - Fallback Markdown View (for content without special blocks)

struct FallbackMarkdownView: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.lg) {
            ForEach(Array(parseContent().enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
    }

    private func parseContent() -> [FallbackBlock] {
        var blocks: [FallbackBlock] = []
        let lines = content.components(separatedBy: "\n")
        var currentParagraph = ""
        var inQuoteBlock = false
        var quoteLines: [String] = []
        var inListBlock = false
        var listItems: [String] = []
        var isNumberedList = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip special block markers (they'll be handled by the main parser)
            // These are tags like [QUICK_GLANCE], [/QUICK_GLANCE], [INSIGHT_NOTE], etc.
            if isSpecialBlockMarker(trimmed) {
                continue
            }

            // Headers
            if trimmed.hasPrefix("# ") {
                flushParagraph(&currentParagraph, to: &blocks)
                flushList(&listItems, numbered: isNumberedList, to: &blocks)
                blocks.append(FallbackBlock(type: .h1, content: String(trimmed.dropFirst(2))))
                continue
            }
            if trimmed.hasPrefix("## ") {
                flushParagraph(&currentParagraph, to: &blocks)
                flushList(&listItems, numbered: isNumberedList, to: &blocks)
                blocks.append(FallbackBlock(type: .h2, content: String(trimmed.dropFirst(3))))
                continue
            }
            if trimmed.hasPrefix("### ") {
                flushParagraph(&currentParagraph, to: &blocks)
                flushList(&listItems, numbered: isNumberedList, to: &blocks)
                blocks.append(FallbackBlock(type: .h3, content: String(trimmed.dropFirst(4))))
                continue
            }
            if trimmed.hasPrefix("#### ") {
                flushParagraph(&currentParagraph, to: &blocks)
                flushList(&listItems, numbered: isNumberedList, to: &blocks)
                blocks.append(FallbackBlock(type: .h4, content: String(trimmed.dropFirst(5))))
                continue
            }

            // Blockquotes
            if trimmed.hasPrefix(">") {
                flushParagraph(&currentParagraph, to: &blocks)
                flushList(&listItems, numbered: isNumberedList, to: &blocks)
                inQuoteBlock = true
                let quoteLine = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                quoteLines.append(quoteLine)
                continue
            } else if inQuoteBlock {
                blocks.append(FallbackBlock(type: .quote, content: quoteLines.joined(separator: " ")))
                quoteLines = []
                inQuoteBlock = false
            }

            // List items (bullet)
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                flushParagraph(&currentParagraph, to: &blocks)
                if inListBlock && isNumberedList {
                    flushList(&listItems, numbered: true, to: &blocks)
                }
                inListBlock = true
                isNumberedList = false
                listItems.append(String(trimmed.dropFirst(2)))
                continue
            }

            // List items (numbered)
            if let range = trimmed.range(of: "^\\d+\\.\\s+", options: .regularExpression) {
                flushParagraph(&currentParagraph, to: &blocks)
                if inListBlock && !isNumberedList {
                    flushList(&listItems, numbered: false, to: &blocks)
                }
                inListBlock = true
                isNumberedList = true
                listItems.append(String(trimmed[range.upperBound...]))
                continue
            }

            // End of list if not a list item
            if inListBlock && !trimmed.isEmpty {
                flushList(&listItems, numbered: isNumberedList, to: &blocks)
                inListBlock = false
            }

            // Dividers
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushParagraph(&currentParagraph, to: &blocks)
                blocks.append(FallbackBlock(type: .divider, content: ""))
                continue
            }

            // Empty line ends paragraph
            if trimmed.isEmpty {
                flushParagraph(&currentParagraph, to: &blocks)
                continue
            }

            // Skip decorative box characters
            if trimmed.contains("┌") || trimmed.contains("├") || trimmed.contains("└") ||
               trimmed.contains("│") || trimmed.contains("─") || trimmed.contains("┐") ||
               trimmed.contains("┤") || trimmed.contains("┘") || trimmed == "↓" {
                continue
            }

            // Regular text
            currentParagraph += (currentParagraph.isEmpty ? "" : " ") + trimmed
        }

        flushParagraph(&currentParagraph, to: &blocks)
        flushList(&listItems, numbered: isNumberedList, to: &blocks)
        if inQuoteBlock {
            blocks.append(FallbackBlock(type: .quote, content: quoteLines.joined(separator: " ")))
        }

        return blocks
    }

    private func flushParagraph(_ paragraph: inout String, to blocks: inout [FallbackBlock]) {
        if !paragraph.isEmpty {
            blocks.append(FallbackBlock(type: .paragraph, content: paragraph))
            paragraph = ""
        }
    }

    private func flushList(_ items: inout [String], numbered: Bool, to blocks: inout [FallbackBlock]) {
        if !items.isEmpty {
            blocks.append(FallbackBlock(type: numbered ? .numberedList : .bulletList, content: "", listItems: items))
            items = []
        }
    }

    /// Check if a line is a special block marker tag that should be skipped
    private func isSpecialBlockMarker(_ line: String) -> Bool {
        // List of all special block markers used in the content format
        let markers = [
            "[QUICK_GLANCE]", "[/QUICK_GLANCE]",
            "[INSIGHT_NOTE]", "[/INSIGHT_NOTE]",
            "[ACTION_BOX]", "[/ACTION_BOX]",
            "[QUOTE]", "[/QUOTE]",
            "[KEY_TAKEAWAYS]", "[/KEY_TAKEAWAYS]",
            "[FOUNDATIONAL_NARRATIVE]", "[/FOUNDATIONAL_NARRATIVE]",
            "[ALTERNATIVE_PERSPECTIVE]", "[/ALTERNATIVE_PERSPECTIVE]",
            "[RESEARCH_INSIGHT]", "[/RESEARCH_INSIGHT]",
            "[AUTHOR_SPOTLIGHT]", "[/AUTHOR_SPOTLIGHT]",
            "[EXERCISE]", "[/EXERCISE]",
            "[CONCEPT_MAP]", "[/CONCEPT_MAP]",
            "[PROCESS_TIMELINE]", "[/PROCESS_TIMELINE]",
            "[INSIGHT_VISUAL]", "[/INSIGHT_VISUAL]"
        ]

        // Check for exact matches
        if markers.contains(line) {
            return true
        }

        // Check for markers with additional content (e.g., "[ACTION_BOX: Some Title]")
        for marker in markers {
            let baseMarker = marker.replacingOccurrences(of: "]", with: "")
            if line.hasPrefix(baseMarker) && (line.hasSuffix("]") || line.contains("]:")) {
                return true
            }
        }

        // Generic check for any [TAG] or [/TAG] pattern that looks like a block marker
        if line.hasPrefix("[") && line.hasSuffix("]") && !line.contains("](") {
            let inner = line.dropFirst().dropLast()
            // Check if it's all uppercase (with optional slash and underscores)
            if inner.hasPrefix("/") {
                let tagName = inner.dropFirst()
                if tagName.allSatisfy({ $0.isUppercase || $0 == "_" }) {
                    return true
                }
            } else if inner.allSatisfy({ $0.isUppercase || $0 == "_" || $0 == ":" || $0 == " " }) {
                return true
            }
        }

        return false
    }

    @ViewBuilder
    private func renderBlock(_ block: FallbackBlock) -> some View {
        switch block.type {
        case .h1:
            Text(sanitizeInlineMarkdown(block.content))
                .font(.analysisDisplayTitle())
                .foregroundColor(AnalysisTheme.textHeading)
                .padding(.top, AnalysisTheme.Spacing.xl)

        case .h2:
            VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.sm) {
                Text(sanitizeInlineMarkdown(block.content))
                    .font(.analysisDisplayH2())
                    .foregroundColor(AnalysisTheme.textHeading)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [AnalysisTheme.primaryGold, AnalysisTheme.accentOrange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 60, height: 2)
                    .cornerRadius(1)
            }
            .padding(.top, AnalysisTheme.Spacing.xl2)

        case .h3:
            Text(sanitizeInlineMarkdown(block.content))
                .font(.analysisDisplayH3())
                .foregroundColor(AnalysisTheme.textHeading)
                .padding(.top, AnalysisTheme.Spacing.lg)

        case .h4:
            Text(sanitizeInlineMarkdown(block.content))
                .font(.analysisDisplayH4())
                .foregroundColor(AnalysisTheme.textHeading)
                .padding(.top, AnalysisTheme.Spacing.md)

        case .paragraph:
            Text(parseInlineFormatting(block.content))
                .font(.analysisBody())
                .foregroundColor(AnalysisTheme.textBody)
                .lineSpacing(6)

        case .quote:
            PremiumBlockquoteView(text: block.content, cite: nil)

        case .bulletList:
            VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.sm) {
                ForEach(block.listItems ?? [], id: \.self) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(AnalysisTheme.primaryGold)
                            .frame(width: 6, height: 6)
                            .padding(.top, 8)

                        Text(parseInlineFormatting(item))
                            .font(.analysisBody())
                            .foregroundColor(AnalysisTheme.textBody)
                    }
                }
            }

        case .numberedList:
            VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.sm) {
                ForEach(Array((block.listItems ?? []).enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1).")
                            .font(.analysisUIBold())
                            .foregroundColor(AnalysisTheme.primaryGold)
                            .frame(width: 24, alignment: .trailing)

                        Text(parseInlineFormatting(item))
                            .font(.analysisBody())
                            .foregroundColor(AnalysisTheme.textBody)
                    }
                }
            }

        case .divider:
            PremiumSectionDivider()
        }
    }

    private func parseInlineFormatting(_ text: String) -> AttributedString {
        // Use Swift's built-in markdown parsing
        do {
            let sanitized = sanitizeInlineMarkdown(text)
            let attributedString = try AttributedString(markdown: sanitized, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))
            // Skip custom emphasis styling for compatibility with older SDKs.
            return attributedString
        } catch {
            // Fallback to plain text if markdown parsing fails
            return AttributedString(sanitizeInlineMarkdown(text))
        }
    }

    private func sanitizeInlineMarkdown(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(
            of: #"(?m)^\s{0,3}#{1,6}\s+"#,
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"(?m)^\s*>\s+"#,
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"(?m)^\s*[-*•]\s+"#,
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"(?m)^\s*\d+\.\s+"#,
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\[([^\]]+)\]\([^)]+\)"#,
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(of: "__", with: "")
        result = result.replacingOccurrences(of: "~~", with: "")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct FallbackBlock {
    enum BlockType {
        case h1, h2, h3, h4
        case paragraph
        case quote
        case bulletList
        case numberedList
        case divider
    }

    let type: BlockType
    let content: String
    var listItems: [String]?

    init(type: BlockType, content: String, listItems: [String]? = nil) {
        self.type = type
        self.content = content
        self.listItems = listItems
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        AnalysisDetailView(
            item: LibraryItem(
                title: "The Extended Mind",
                author: "Annie Murphy Paul",
                fileType: .pdf,
                summaryContent: """
                [QUICK_GLANCE]
                **Core Message:** Our minds extend beyond our skulls, incorporating our bodies, surroundings, and relationships.

                - **Embodied Cognition:** Physical movement enhances thinking and memory
                - **Environmental Scaffolding:** Our surroundings shape how we think
                - **Social Cognition:** Other people's minds become extensions of our own
                [/QUICK_GLANCE]

                ## The Foundation of Understanding

                This paragraph demonstrates the refined body typography. Notice the elegant serif font—a typeface that creates comfortable reading rhythm.

                [INSIGHT_NOTE]
                This component draws inspiration from Shortform's excellent editorial commentary boxes. Use it to add your own analysis.
                [/INSIGHT_NOTE]

                [ACTION_BOX: Apply It]
                1. Engage actively with pen in hand
                2. Question deeply
                3. Connect broadly
                [/ACTION_BOX]
                """
            )
        )
    }
}
