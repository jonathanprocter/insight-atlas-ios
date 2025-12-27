import SwiftUI
import AVFoundation

struct GuideView: View {

    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss

    let item: LibraryItem

    @State private var showingExportSheet = false
    @State private var showingShareSheet = false
    @State private var showingRegenerateConfirmation = false
    @State private var showingRegenerateView = false
    @State private var exportURL: URL?
    @State private var selectedSection: String?
    @State private var searchText = ""
    @State private var qualityScore: Int?

    // MARK: - Audio Playback State
    @State private var isPlayingAudio = false
    @State private var audioPlaybackProgress: Double = 0
    @State private var audioPlaybackTimer: Timer?
    @State private var audioPlaybackError: String?
    @State private var showingAudioErrorToast = false

    // MARK: - Audio Generation State (for guides without audio)
    @State private var isGeneratingAudio = false
    @State private var showingAudioReadyToast = false
    @State private var audioGenerationError: String?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: InsightAtlasLayout.sectionSpacing) {
                    // Header with branding
                    guideHeader

                    // Table of Contents
                    if !tableOfContents.isEmpty {
                        tableOfContentsSection(proxy: proxy)
                    }

                    // Content
                    if let content = item.summaryContent {
                        InsightAtlasContentView(content: content, searchQuery: searchText)
                    }
                }
                .frame(maxWidth: InsightAtlasLayout.maxContentWidth, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(InsightAtlasColors.background)
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search guide")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingExportSheet = true
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        copyToClipboard()
                    } label: {
                        Label("Copy All", systemImage: "doc.on.doc")
                    }

                    Divider()

                    Button {
                        showingRegenerateConfirmation = true
                    } label: {
                        Label("Regenerate Guide", systemImage: "arrow.triangle.2.circlepath")
                    }

                    if let score = qualityScore {
                        Divider()
                        Label("Quality: \(score)%", systemImage: score >= 95 ? "checkmark.seal.fill" : "exclamationmark.triangle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(InsightAtlasColors.gold)
                }
            }
        }
        .confirmationDialog("Export Format", isPresented: $showingExportSheet) {
            ForEach(ExportFormat.allCases, id: \.self) { format in
                Button(format.rawValue) {
                    exportGuide(format: format)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
        .alert("Regenerate Guide?", isPresented: $showingRegenerateConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Regenerate", role: .destructive) {
                showingRegenerateView = true
            }
        } message: {
            Text("This will create a new version of the guide. The current version will be replaced.")
        }
        .fullScreenCover(isPresented: $showingRegenerateView) {
            RegenerateView(item: item, onComplete: { newContent, score in
                dataManager.saveSummary(for: item.id, content: newContent)
                qualityScore = score
                showingRegenerateView = false
            })
            .environmentObject(dataManager)
        }
        .onAppear {
            // Calculate quality score on appear
            if let content = item.summaryContent {
                qualityScore = QualityAuditService.calculateQualityScore(content: content)
            }
        }
        .onDisappear {
            stopAudioPlayback()
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
    }

    // MARK: - Audio Ready Toast

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

    // MARK: - Guide Header

    private var guideHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Logo/Brand Header
            HStack(spacing: 12) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("INSIGHT ATLAS")
                        .font(InsightAtlasTypography.captionBold)
                        .foregroundColor(InsightAtlasColors.gold)
                        .tracking(2)

                    Text("GUIDE")
                        .font(InsightAtlasTypography.caption)
                        .foregroundColor(InsightAtlasColors.muted)
                        .tracking(1)
                }
            }

            // Book Title
            Text(item.title)
                .font(InsightAtlasTypography.largeTitle)
                .foregroundColor(InsightAtlasColors.heading)

            // Author
            Text("by \(item.author)")
                .font(InsightAtlasTypography.h3)
                .foregroundColor(InsightAtlasColors.muted)

            // Metadata
            HStack(spacing: 16) {
                Label(item.mode.displayName, systemImage: "sparkles")
                Label(item.provider.displayName, systemImage: "cpu")
                if let pageCount = item.pageCount {
                    Label("\(pageCount) pages", systemImage: "doc")
                }
            }
            .font(InsightAtlasTypography.caption)
            .foregroundColor(InsightAtlasColors.muted)

            // Audio Playback Button (if audio available)
            if hasPlayableAudio {
                audioPlaybackSection
            } else if canGenerateAudio {
                generateAudioSection
            } else if item.audioFileURL != nil {
                Text("Audio file missing. Regenerate audio to enable playback.")
                    .font(InsightAtlasTypography.caption)
                    .foregroundColor(InsightAtlasColors.muted)
            }

            // Divider with gold accent
            Rectangle()
                .fill(InsightAtlasColors.gold)
                .frame(height: 2)
                .padding(.top, 8)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Audio Playback Section

    @ViewBuilder
    private var audioPlaybackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                // Play/Pause Button
                Button {
                    toggleAudioPlayback()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isPlayingAudio ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .semibold))

                        Text(isPlayingAudio ? "Pause" : "Listen")
                            .font(InsightAtlasTypography.uiBody)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(InsightAtlasColors.gold)
                    .clipShape(Capsule())
                }

                // Duration
                if let duration = item.formattedAudioDuration {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(duration)
                            .font(InsightAtlasTypography.caption)
                    }
                    .foregroundColor(InsightAtlasColors.muted)
                }

                Spacer()

                // Stop button (when playing)
                if isPlayingAudio {
                    Button {
                        stopAudioPlayback()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 14))
                            .foregroundColor(InsightAtlasColors.muted)
                            .padding(8)
                            .background(InsightAtlasColors.ruleLight)
                            .clipShape(Circle())
                    }
                }
            }

            // Progress bar (when playing)
            if isPlayingAudio {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(InsightAtlasColors.ruleLight)
                            .frame(height: 4)

                        Rectangle()
                            .fill(InsightAtlasColors.gold)
                            .frame(width: geometry.size.width * audioPlaybackProgress, height: 4)
                    }
                    .clipShape(Capsule())
                }
                .frame(height: 4)
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Generate Audio Section (for guides without audio)

    /// Whether audio can be generated for this guide
    private var canGenerateAudio: Bool {
        item.summaryContent != nil &&
        !hasPlayableAudio &&
        KeychainService.shared.hasElevenLabsApiKey
    }

    private var hasPlayableAudio: Bool {
        guard let audioFileName = item.audioFileURL else { return false }
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return false
        }
        let audioFileURL = documentsDir.appendingPathComponent(audioFileName)
        return FileManager.default.fileExists(atPath: audioFileURL.path)
    }

    @ViewBuilder
    private var generateAudioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isGeneratingAudio {
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Generating audio...")
                        .font(InsightAtlasTypography.caption)
                        .foregroundColor(InsightAtlasColors.muted)
                }
                .padding(.vertical, 8)
            } else {
                Button {
                    generateAudioOnly()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "headphones")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Generate Audio")
                            .font(InsightAtlasTypography.uiBody)
                    }
                    .foregroundColor(InsightAtlasColors.gold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .stroke(InsightAtlasColors.gold, lineWidth: 1.5)
                    )
                }

                if let error = audioGenerationError {
                    Text(error)
                        .font(InsightAtlasTypography.caption)
                        .foregroundColor(.red)
                        .padding(.top, 4)
                }
            }
        }
        .padding(.top, 12)
    }

    /// Generate audio only for an existing guide (no text regeneration)
    private func generateAudioOnly() {
        guard let content = item.summaryContent else { return }

        isGeneratingAudio = true
        audioGenerationError = nil

        Task {
            do {
                let audioService = ElevenLabsAudioService()

                // Use default voice
                let profile: ReaderProfile = .practitioner
                var voiceConfig = VoiceSelectionConfig.premium(for: profile)
                if !ElevenLabsVoiceRegistry.isPremiumVoiceID(voiceConfig.voiceID) {
                    let fallback = ElevenLabsVoiceRegistry.premiumPrimaryVoice(for: profile)
                    voiceConfig = .custom(profile: profile, voice: fallback)
                }

                // Generate audio
                let result = try await audioService.generateAudio(
                    text: sanitizeAudioContent(content),
                    voiceID: voiceConfig.voiceID
                )

                // Save audio to documents directory
                guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                    await MainActor.run {
                        isGeneratingAudio = false
                        audioGenerationError = "Unable to access documents directory for audio storage."
                    }
                    return
                }
                let audioFileName = "audio_\(item.id.uuidString).mp3"
                let audioFileURL = documentsDir.appendingPathComponent(audioFileName)

                try result.data.write(to: audioFileURL)

                // Calculate duration
                let asset = AVURLAsset(url: audioFileURL)
                let duration = try await asset.load(.duration)
                let durationSeconds = CMTimeGetSeconds(duration)

                // Update the library item with audio metadata
                await MainActor.run {
                    dataManager.updateAudioMetadata(
                        for: item.id,
                        audioFileURL: audioFileName,
                        audioVoiceID: voiceConfig.voiceID,
                        audioDuration: durationSeconds
                    )

                    isGeneratingAudio = false

                    // Show success toast
                    showingAudioReadyToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        showingAudioReadyToast = false
                    }
                }

            } catch {
                await MainActor.run {
                    isGeneratingAudio = false
                    audioGenerationError = error.localizedDescription
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

    // MARK: - Audio Playback Methods

    private func toggleAudioPlayback() {
        if isPlayingAudio {
            pauseAudioPlayback()
        } else {
            startAudioPlayback()
        }
    }

    private func startAudioPlayback() {
        guard let audioFileName = item.audioFileURL else { return }

        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            reportAudioPlaybackError("Audio storage unavailable.")
            return
        }
        let audioFileURL = documentsDir.appendingPathComponent(audioFileName)

        guard FileManager.default.fileExists(atPath: audioFileURL.path) else {
            reportAudioPlaybackError("Audio file missing. Regenerate audio.")
            return
        }

        do {
            try AudioPlaybackManager.shared.playFile(at: audioFileURL) {
                DispatchQueue.main.async {
                    stopAudioPlayback()
                }
            }

            isPlayingAudio = true
            startAudioProgressTimer()
        } catch {
            reportAudioPlaybackError("Audio playback failed.")
        }
    }

    private func pauseAudioPlayback() {
        AudioPlaybackManager.shared.pause()
        isPlayingAudio = false
        stopAudioProgressTimer()
    }

    private func stopAudioPlayback() {
        AudioPlaybackManager.shared.stop()
        isPlayingAudio = false
        audioPlaybackProgress = 0
        stopAudioProgressTimer()
    }

    private func reportAudioPlaybackError(_ message: String) {
        audioPlaybackError = message
        showingAudioErrorToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            showingAudioErrorToast = false
        }
    }

    private func updateAudioProgress() {
        audioPlaybackProgress = AudioPlaybackManager.shared.progress
    }

    private func startAudioProgressTimer() {
        stopAudioProgressTimer()
        audioPlaybackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            updateAudioProgress()
        }
    }

    private func stopAudioProgressTimer() {
        audioPlaybackTimer?.invalidate()
        audioPlaybackTimer = nil
    }

    // MARK: - Table of Contents

    private var tableOfContents: [String] {
        guard let content = item.summaryContent else { return [] }

        var sections: [String] = []
        let lines = content.components(separatedBy: "\n")
        var index = 0

        while index < lines.count {
            let line = lines[index]

            if let title = extractInlineTag(line, tag: "PREMIUM_H2") {
                sections.append(title)
                index += 1
                continue
            }

            if let title = extractInlineTag(line, tag: "PREMIUM_H1") {
                sections.append(title)
                index += 1
                continue
            }

            if line.hasPrefix("[PREMIUM_H2]") {
                var titleLines: [String] = []
                index += 1
                while index < lines.count, !lines[index].hasPrefix("[/PREMIUM_H2]") {
                    let trimmed = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        titleLines.append(trimmed)
                    }
                    index += 1
                }
                if !titleLines.isEmpty {
                    sections.append(titleLines.joined(separator: " "))
                }
                index += 1
                continue
            }

            if line.hasPrefix("[PREMIUM_H1]") {
                var titleLines: [String] = []
                index += 1
                while index < lines.count, !lines[index].hasPrefix("[/PREMIUM_H1]") {
                    let trimmed = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        titleLines.append(trimmed)
                    }
                    index += 1
                }
                if !titleLines.isEmpty {
                    sections.append(titleLines.joined(separator: " "))
                }
                index += 1
                continue
            }

            if line.hasPrefix("## ") {
                let title = String(line.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                sections.append(title)
                index += 1
                continue
            }

            index += 1
        }

        return sections
    }

    private func extractInlineTag(_ line: String, tag: String) -> String? {
        let open = "[\(tag)]"
        let close = "[/\(tag)]"
        guard line.contains(open), line.contains(close) else { return nil }
        guard let openRange = line.range(of: open),
              let closeRange = line.range(of: close) else { return nil }
        let content = line[openRange.upperBound..<closeRange.lowerBound]
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func tableOfContentsSection(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Contents")
                .font(InsightAtlasTypography.h2)
                .foregroundColor(InsightAtlasColors.heading)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(tableOfContents, id: \.self) { section in
                    Button {
                        withAnimation {
                            proxy.scrollTo(section, anchor: .top)
                        }
                    } label: {
                        HStack {
                            Text(section)
                                .font(InsightAtlasTypography.uiBody)
                                .foregroundColor(InsightAtlasColors.body)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(InsightAtlasColors.gold)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                    }

                    if section != tableOfContents.last {
                        Divider()
                            .background(InsightAtlasColors.ruleLight)
                    }
                }
            }
            .background(InsightAtlasColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(InsightAtlasColors.rule, lineWidth: 1)
            )
        }
        .padding(.bottom, 16)
    }

    // MARK: - Methods

    private func copyToClipboard() {
        if let content = item.summaryContent {
            UIPasteboard.general.string = content
        }
    }

    private func exportGuide(format: ExportFormat) {
        do {
            let url = try dataManager.exportGuide(item, format: format)
            exportURL = url
            showingShareSheet = true
        } catch {
            // Handle error
        }
    }
}

// MARK: - Inline Markdown Helpers

fileprivate func parseInlineMarkdown(_ text: String, baseFontSize: CGFloat = 16) -> AttributedString {
    let sanitized = sanitizeInlineMarkdown(text)
    var result = AttributedString(sanitized)

    // Bold
    let boldPattern = #"\*\*([^*]+)\*\*"#
    if let boldRegex = try? NSRegularExpression(pattern: boldPattern) {
        let matches = boldRegex.matches(in: sanitized, range: NSRange(sanitized.startIndex..., in: sanitized))
        for match in matches.reversed() {
            if let _ = Range(match.range, in: sanitized),
               let captureRange = Range(match.range(at: 1), in: sanitized) {
                let boldText = String(sanitized[captureRange])
                if let range = result.range(of: "**\(boldText)**") {
                    var attrs = AttributeContainer()
                    attrs.font = UIFont.boldSystemFont(ofSize: baseFontSize)
                    result.replaceSubrange(range, with: AttributedString(boldText, attributes: attrs))
                }
            }
        }
    }

    // Italic
    let italicPattern = #"(?<!\*)\*([^*]+)\*(?!\*)"#
    if let italicRegex = try? NSRegularExpression(pattern: italicPattern) {
        let currentText = String(result.characters)
        let italicMatches = italicRegex.matches(in: currentText, range: NSRange(currentText.startIndex..., in: currentText))
        for match in italicMatches.reversed() {
            if let captureRange = Range(match.range(at: 1), in: currentText) {
                let italicText = String(currentText[captureRange])
                if let range = result.range(of: "*\(italicText)*") {
                    var attrs = AttributeContainer()
                    attrs.font = UIFont.italicSystemFont(ofSize: baseFontSize)
                    result.replaceSubrange(range, with: AttributedString(italicText, attributes: attrs))
                }
            }
        }
    }

    return result
}

fileprivate func sanitizeInlineMarkdown(_ text: String) -> String {
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

// MARK: - Insight Atlas Content View

struct InsightAtlasContentView: View {

    let content: String
    let searchQuery: String

    var body: some View {
        let blocks = filteredBlocks(from: parseContent(), query: searchQuery)
        return VStack(alignment: .leading, spacing: InsightAtlasLayout.paragraphSpacing) {
            ForEach(blocks, id: \.id) { block in
                renderBlock(block)
            }
        }
    }

    private func parseContent() -> [IAContentBlock] {
        var blocks: [IAContentBlock] = []
        let lines = content.components(separatedBy: "\n")
        var currentParagraph = ""
        var inCodeBlock = false
        var codeContent = ""
        var inSpecialBlock = false
        var specialBlockType: IABlockType?
        var specialBlockContent = ""
        var specialBlockTitle = ""
        var inInsightVisual = false
        var insightVisualTag: String?
        var insightVisualTitle: String?
        var insightVisualContent: [String] = []

        func shouldAutoCloseBlock(_ line: String) -> Bool {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.hasPrefix("[/") else { return false }
            if trimmed.hasPrefix("#") {
                return true
            }
            let upper = trimmed.uppercased()
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
                upper.hasPrefix("[STRUCTURE_MAP]") ||
                upper.hasPrefix("[PREMIUM_DIVIDER]")
        }

        func appendSpecialBlock(
            type: IABlockType,
            content: String,
            title: String,
            blocks: inout [IAContentBlock]
        ) {
            switch type {
            case .quickGlance:
                blocks.append(IAContentBlock(type: .quickGlance, content: content, title: "Quick Glance Summary"))
            case .insightNote:
                blocks.append(IAContentBlock(type: .insightNote, content: content, title: "Insight Atlas Note"))
            case .actionBox:
                let resolvedTitle = title.isEmpty ? "Apply It" : title
                blocks.append(IAContentBlock(type: .actionBox, content: content, title: resolvedTitle))
            case .authorSpotlight:
                blocks.append(IAContentBlock(type: .authorSpotlight, content: content, title: "Author Spotlight"))
            case .premiumQuote:
                blocks.append(IAContentBlock(type: .premiumQuote, content: content.trimmingCharacters(in: .whitespacesAndNewlines), title: ""))
            case .premiumH1:
                blocks.append(IAContentBlock(type: .premiumH1, content: content, title: ""))
            case .premiumH2:
                blocks.append(IAContentBlock(type: .premiumH2, content: content, title: ""))
            case .alternativePerspective:
                blocks.append(IAContentBlock(type: .alternativePerspective, content: content, title: "Alternative Perspective"))
            case .researchInsight:
                blocks.append(IAContentBlock(type: .researchInsight, content: content, title: "Research Insight"))
            case .structureMap:
                blocks.append(IAContentBlock(type: .structureMap, content: content, title: "Structure Map"))
            case .foundationalNarrative:
                blocks.append(IAContentBlock(type: .foundationalNarrative, content: content, title: "The Story Behind the Ideas"))
            case .takeaways:
                blocks.append(IAContentBlock(type: .takeaways, content: content, title: "Key Takeaways"))
            case .exercise:
                blocks.append(IAContentBlock(type: .exercise, content: content, title: ""))
            default:
                blocks.append(IAContentBlock(type: type, content: content, title: title))
            }
        }

        for line in lines {
            if let visualOpen = parseVisualOpen(line) {
                flushParagraph(&currentParagraph, to: &blocks)
                inInsightVisual = true
                insightVisualTag = visualOpen.tag
                insightVisualTitle = visualOpen.title
                insightVisualContent = []
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
                        blocks.append(IAContentBlock(type: .insightVisual, content: "", title: "", visualPayload: visualPayload))
                    }
                    inInsightVisual = false
                    insightVisualTag = nil
                    insightVisualTitle = nil
                    insightVisualContent = []
                    continue
                }
            }

            if inInsightVisual {
                insightVisualContent.append(line)
                continue
            }

            if inSpecialBlock, let specialType = specialBlockType, shouldAutoCloseBlock(line) {
                appendSpecialBlock(
                    type: specialType,
                    content: specialBlockContent,
                    title: specialBlockTitle,
                    blocks: &blocks
                )
                inSpecialBlock = false
                specialBlockType = nil
                specialBlockContent = ""
                specialBlockTitle = ""
            }

            // Handle special block markers
            if let inline = inlineTagContent(line, tag: "PREMIUM_H1") {
                flushParagraph(&currentParagraph, to: &blocks)
                blocks.append(IAContentBlock(type: .premiumH1, content: inline, title: ""))
                continue
            }

            if let inline = inlineTagContent(line, tag: "PREMIUM_H2") {
                flushParagraph(&currentParagraph, to: &blocks)
                blocks.append(IAContentBlock(type: .premiumH2, content: inline, title: ""))
                continue
            }

            if line.hasPrefix("[PREMIUM_H1]") {
                flushParagraph(&currentParagraph, to: &blocks)
                inSpecialBlock = true
                specialBlockType = .premiumH1
                specialBlockContent = ""
                continue
            }

            if line.hasPrefix("[/PREMIUM_H1]") {
                if inSpecialBlock {
                    blocks.append(IAContentBlock(type: .premiumH1, content: specialBlockContent, title: ""))
                    inSpecialBlock = false
                    specialBlockType = nil
                    specialBlockContent = ""
                }
                continue
            }

            if line.hasPrefix("[PREMIUM_H2]") {
                flushParagraph(&currentParagraph, to: &blocks)
                inSpecialBlock = true
                specialBlockType = .premiumH2
                specialBlockContent = ""
                continue
            }

            if line.hasPrefix("[/PREMIUM_H2]") {
                if inSpecialBlock {
                    blocks.append(IAContentBlock(type: .premiumH2, content: specialBlockContent, title: ""))
                    inSpecialBlock = false
                    specialBlockType = nil
                    specialBlockContent = ""
                }
                continue
            }

            if line.hasPrefix("[PREMIUM_DIVIDER]") {
                flushParagraph(&currentParagraph, to: &blocks)
                blocks.append(IAContentBlock(type: .premiumDivider, content: "", title: ""))
                continue
            }
            if line.hasPrefix("[/PREMIUM_DIVIDER]") {
                continue
            }

            if line.hasPrefix("[QUICK_GLANCE]") {
                flushParagraph(&currentParagraph, to: &blocks)
                inSpecialBlock = true
                specialBlockType = .quickGlance
                specialBlockContent = ""
                continue
            }

            if line.hasPrefix("[/QUICK_GLANCE]") {
                if inSpecialBlock {
                    blocks.append(IAContentBlock(type: .quickGlance, content: specialBlockContent, title: "Quick Glance Summary"))
                    inSpecialBlock = false
                    specialBlockType = nil
                    specialBlockContent = ""
                }
                continue
            }

            if line.hasPrefix("[INSIGHT_NOTE]") {
                flushParagraph(&currentParagraph, to: &blocks)
                inSpecialBlock = true
                specialBlockType = .insightNote
                specialBlockContent = ""
                continue
            }

            if line.hasPrefix("[/INSIGHT_NOTE]") {
                if inSpecialBlock {
                    blocks.append(IAContentBlock(type: .insightNote, content: specialBlockContent, title: "Insight Atlas Note"))
                    inSpecialBlock = false
                    specialBlockType = nil
                    specialBlockContent = ""
                }
                continue
            }

            if line.hasPrefix("[AUTHOR_SPOTLIGHT]") {
                flushParagraph(&currentParagraph, to: &blocks)
                inSpecialBlock = true
                specialBlockType = .authorSpotlight
                specialBlockContent = ""
                continue
            }

            if line.hasPrefix("[/AUTHOR_SPOTLIGHT]") {
                if inSpecialBlock {
                    blocks.append(IAContentBlock(type: .authorSpotlight, content: specialBlockContent, title: "Author Spotlight"))
                    inSpecialBlock = false
                    specialBlockType = nil
                    specialBlockContent = ""
                }
                continue
            }

            if line.hasPrefix("[PREMIUM_QUOTE]") {
                flushParagraph(&currentParagraph, to: &blocks)
                inSpecialBlock = true
                specialBlockType = .premiumQuote
                specialBlockContent = ""
                continue
            }

            if line.hasPrefix("[/PREMIUM_QUOTE]") {
                if inSpecialBlock {
                    blocks.append(IAContentBlock(type: .premiumQuote, content: specialBlockContent.trimmingCharacters(in: .whitespacesAndNewlines), title: ""))
                    inSpecialBlock = false
                    specialBlockType = nil
                    specialBlockContent = ""
                }
                continue
            }

            if line.hasPrefix("[ALTERNATIVE_PERSPECTIVE]") {
                flushParagraph(&currentParagraph, to: &blocks)
                inSpecialBlock = true
                specialBlockType = .alternativePerspective
                specialBlockContent = ""
                continue
            }

            if line.hasPrefix("[/ALTERNATIVE_PERSPECTIVE]") {
                if inSpecialBlock {
                    blocks.append(IAContentBlock(type: .alternativePerspective, content: specialBlockContent, title: "Alternative Perspective"))
                    inSpecialBlock = false
                    specialBlockType = nil
                    specialBlockContent = ""
                }
                continue
            }

            if line.hasPrefix("[RESEARCH_INSIGHT]") {
                flushParagraph(&currentParagraph, to: &blocks)
                inSpecialBlock = true
                specialBlockType = .researchInsight
                specialBlockContent = ""
                continue
            }

            if line.hasPrefix("[/RESEARCH_INSIGHT]") {
                if inSpecialBlock {
                    blocks.append(IAContentBlock(type: .researchInsight, content: specialBlockContent, title: "Research Insight"))
                    inSpecialBlock = false
                    specialBlockType = nil
                    specialBlockContent = ""
                }
                continue
            }

            if line.hasPrefix("[STRUCTURE_MAP]") {
                flushParagraph(&currentParagraph, to: &blocks)
                inSpecialBlock = true
                specialBlockType = .structureMap
                specialBlockContent = ""
                continue
            }

            if line.hasPrefix("[/STRUCTURE_MAP]") {
                if inSpecialBlock {
                    blocks.append(IAContentBlock(type: .structureMap, content: specialBlockContent, title: "Structure Map"))
                    inSpecialBlock = false
                    specialBlockType = nil
                    specialBlockContent = ""
                }
                continue
            }

            if line.hasPrefix("[ACTION_BOX") {
                flushParagraph(&currentParagraph, to: &blocks)
                inSpecialBlock = true
                specialBlockType = .actionBox
                specialBlockContent = ""
                // Extract title if present
                if let colonIndex = line.firstIndex(of: ":") {
                    let titleStart = line.index(after: colonIndex)
                    let titleEnd = line.firstIndex(of: "]") ?? line.endIndex
                    specialBlockTitle = String(line[titleStart..<titleEnd]).trimmingCharacters(in: .whitespaces)
                }
                continue
            }

            if line.hasPrefix("[/ACTION_BOX]") {
                if inSpecialBlock {
                    blocks.append(IAContentBlock(type: .actionBox, content: specialBlockContent, title: specialBlockTitle.isEmpty ? "Apply It" : specialBlockTitle))
                    inSpecialBlock = false
                    specialBlockType = nil
                    specialBlockContent = ""
                    specialBlockTitle = ""
                }
                continue
            }

            if line.hasPrefix("[QUOTE]") {
                flushParagraph(&currentParagraph, to: &blocks)
                inSpecialBlock = true
                specialBlockType = .quote
                specialBlockContent = ""
                continue
            }

            if line.hasPrefix("[/QUOTE]") {
                if inSpecialBlock {
                    blocks.append(IAContentBlock(type: .quote, content: specialBlockContent.trimmingCharacters(in: .whitespacesAndNewlines), title: ""))
                    inSpecialBlock = false
                    specialBlockType = nil
                    specialBlockContent = ""
                }
                continue
            }

            if line.hasPrefix("[VISUAL_FLOWCHART") {
                flushParagraph(&currentParagraph, to: &blocks)
                inSpecialBlock = true
                specialBlockType = .flowchart
                specialBlockContent = ""
                if let colonIndex = line.firstIndex(of: ":") {
                    let titleStart = line.index(after: colonIndex)
                    let titleEnd = line.firstIndex(of: "]") ?? line.endIndex
                    specialBlockTitle = String(line[titleStart..<titleEnd]).trimmingCharacters(in: .whitespaces)
                }
                continue
            }

            if line.hasPrefix("[/VISUAL_FLOWCHART]") {
                if inSpecialBlock {
                    blocks.append(IAContentBlock(type: .flowchart, content: specialBlockContent, title: specialBlockTitle))
                    inSpecialBlock = false
                    specialBlockType = nil
                    specialBlockContent = ""
                    specialBlockTitle = ""
                }
                continue
            }

            if line.hasPrefix("[VISUAL_TABLE") {
                flushParagraph(&currentParagraph, to: &blocks)
                inSpecialBlock = true
                specialBlockType = .table
                specialBlockContent = ""
                if let colonIndex = line.firstIndex(of: ":") {
                    let titleStart = line.index(after: colonIndex)
                    let titleEnd = line.firstIndex(of: "]") ?? line.endIndex
                    specialBlockTitle = String(line[titleStart..<titleEnd]).trimmingCharacters(in: .whitespaces)
                }
                continue
            }

            if line.hasPrefix("[/VISUAL_TABLE]") {
                if inSpecialBlock {
                    blocks.append(IAContentBlock(type: .table, content: specialBlockContent, title: specialBlockTitle))
                    inSpecialBlock = false
                    specialBlockType = nil
                    specialBlockContent = ""
                    specialBlockTitle = ""
                }
                continue
            }

            if line.hasPrefix("[EXERCISE_") || line.hasPrefix("[FOUNDATIONAL_NARRATIVE]") || line.hasPrefix("[TAKEAWAYS]") || line.hasPrefix("[STRUCTURE_MAP]") {
                flushParagraph(&currentParagraph, to: &blocks)
                inSpecialBlock = true
                if line.contains("REFLECTION") {
                    specialBlockType = .exercise
                } else if line.contains("FOUNDATIONAL") {
                    specialBlockType = .foundationalNarrative
                } else if line.contains("TAKEAWAYS") {
                    specialBlockType = .takeaways
                } else {
                    specialBlockType = .exercise
                }
                specialBlockContent = ""
                continue
            }

            if line.hasPrefix("[/EXERCISE_") || line.hasPrefix("[/FOUNDATIONAL_NARRATIVE]") || line.hasPrefix("[/TAKEAWAYS]") || line.hasPrefix("[/STRUCTURE_MAP]") {
                if inSpecialBlock {
                    blocks.append(IAContentBlock(type: specialBlockType ?? .paragraph, content: specialBlockContent, title: ""))
                    inSpecialBlock = false
                    specialBlockType = nil
                    specialBlockContent = ""
                }
                continue
            }

            // Skip decorative box characters
            if line.contains("┌") || line.contains("├") || line.contains("└") || line.contains("│") || line.contains("─") {
                if inSpecialBlock {
                    // Extract text content from within box
                    let cleanedLine = line.replacingOccurrences(of: "┌", with: "")
                        .replacingOccurrences(of: "├", with: "")
                        .replacingOccurrences(of: "└", with: "")
                        .replacingOccurrences(of: "│", with: "")
                        .replacingOccurrences(of: "─", with: "")
                        .replacingOccurrences(of: "┐", with: "")
                        .replacingOccurrences(of: "┤", with: "")
                        .replacingOccurrences(of: "┘", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    if !cleanedLine.isEmpty {
                        specialBlockContent += cleanedLine + "\n"
                    }
                }
                continue
            }

            // If inside special block, accumulate content
            if inSpecialBlock {
                specialBlockContent += line + "\n"
                continue
            }

            // Code blocks
            if line.hasPrefix("```") {
                if inCodeBlock {
                    blocks.append(IAContentBlock(type: .code, content: codeContent, title: ""))
                    codeContent = ""
                }
                inCodeBlock.toggle()
                continue
            }

            if inCodeBlock {
                codeContent += line + "\n"
                continue
            }

            // Headers
            if line.hasPrefix("# ") {
                flushParagraph(&currentParagraph, to: &blocks)
                blocks.append(IAContentBlock(type: .h1, content: String(line.dropFirst(2)), title: ""))
                continue
            }

            if line.hasPrefix("## ") {
                flushParagraph(&currentParagraph, to: &blocks)
                blocks.append(IAContentBlock(type: .h2, content: String(line.dropFirst(3)), title: ""))
                continue
            }

            if line.hasPrefix("### ") {
                flushParagraph(&currentParagraph, to: &blocks)
                blocks.append(IAContentBlock(type: .h3, content: String(line.dropFirst(4)), title: ""))
                continue
            }

            // Horizontal rule
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                flushParagraph(&currentParagraph, to: &blocks)
                blocks.append(IAContentBlock(type: .divider, content: "", title: ""))
                continue
            }

            // Blockquotes (standard markdown)
            if line.hasPrefix("> ") {
                flushParagraph(&currentParagraph, to: &blocks)
                blocks.append(IAContentBlock(type: .quote, content: String(line.dropFirst(2)), title: ""))
                continue
            }

            // Lists
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                flushParagraph(&currentParagraph, to: &blocks)
                blocks.append(IAContentBlock(type: .listItem, content: String(line.dropFirst(2)), title: ""))
                continue
            }

            // Numbered lists
            if line.first?.isNumber == true && line.contains(". ") {
                flushParagraph(&currentParagraph, to: &blocks)
                blocks.append(IAContentBlock(type: .numberedItem, content: line, title: ""))
                continue
            }

            // Empty lines
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                flushParagraph(&currentParagraph, to: &blocks)
                continue
            }

            // Regular text
            currentParagraph += (currentParagraph.isEmpty ? "" : " ") + line
        }

        flushParagraph(&currentParagraph, to: &blocks)

        return blocks
    }

    private func filteredBlocks(from blocks: [IAContentBlock], query: String) -> [IAContentBlock] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return blocks }
        let needle = trimmed.lowercased()

        var results: [IAContentBlock] = []
        var pendingHeaders: [IAContentBlock] = []

        for block in blocks {
            if isHeaderBlock(block.type) {
                pendingHeaders = [block]
                if block.content.lowercased().contains(needle) {
                    results.append(contentsOf: pendingHeaders)
                    pendingHeaders.removeAll()
                }
                continue
            }

            if block.content.lowercased().contains(needle) || block.title.lowercased().contains(needle) {
                results.append(contentsOf: pendingHeaders)
                pendingHeaders.removeAll()
                results.append(block)
            }
        }

        return results.isEmpty ? blocks : results
    }

    private func isHeaderBlock(_ type: IABlockType) -> Bool {
        switch type {
        case .h1, .h2, .h3, .premiumH1, .premiumH2:
            return true
        default:
            return false
        }
    }

    private func parseVisualOpen(_ line: String) -> (tag: String, title: String?)? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("[") && trimmed.hasSuffix("]") else { return nil }
        guard !trimmed.hasPrefix("[/") else { return nil }
        let raw = trimmed.dropFirst().dropLast()
        let parts = raw.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
        let tag = canonicalVisualTag(parts.first ?? "")
        guard tag.hasPrefix("VISUAL_") else { return nil }
        let title = parts.count > 1 ? parts[1] : nil
        return (tag: tag, title: title)
    }

    private func inlineTagContent(_ line: String, tag: String) -> String? {
        let open = "[\(tag)]"
        let close = "[/\(tag)]"
        guard line.contains(open), line.contains(close) else { return nil }
        guard let openRange = line.range(of: open),
              let closeRange = line.range(of: close) else { return nil }
        let content = line[openRange.upperBound..<closeRange.lowerBound]
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseVisualClose(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("[/") && trimmed.hasSuffix("]") else { return nil }
        let raw = trimmed.dropFirst(2).dropLast()
        let tag = canonicalVisualTag(String(raw))
        guard tag.hasPrefix("VISUAL_") else { return nil }
        return tag
    }

    private func canonicalVisualTag(_ tag: String) -> String {
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

    private func flushParagraph(_ paragraph: inout String, to blocks: inout [IAContentBlock]) {
        if !paragraph.isEmpty {
            blocks.append(IAContentBlock(type: .paragraph, content: paragraph, title: ""))
            paragraph = ""
        }
    }

    @ViewBuilder
    private func renderBlock(_ block: IAContentBlock) -> some View {
        switch block.type {
        case .premiumH1:
            PremiumHeaderBlockView(content: sanitizeInlineMarkdown(block.content))
                .padding(.top, 12)

        case .premiumH2:
            PremiumSubheaderBlockView(content: sanitizeInlineMarkdown(block.content))
                .padding(.top, 8)

        case .premiumDivider:
            PremiumDividerView()
                .padding(.vertical, 12)

        case .h1:
            Text(sanitizeInlineMarkdown(block.content))
                .font(InsightAtlasTypography.h1)
                .foregroundColor(InsightAtlasColors.heading)
                .padding(.top, 24)
                .id(block.content)

        case .h2:
            VStack(alignment: .leading, spacing: 8) {
                Text(sanitizeInlineMarkdown(block.content))
                    .font(InsightAtlasTypography.h2)
                    .foregroundColor(InsightAtlasColors.heading)

                Rectangle()
                    .fill(InsightAtlasColors.gold.opacity(0.3))
                    .frame(height: 2)
            }
            .padding(.top, 20)
            .id(block.content)

        case .h3:
            Text(sanitizeInlineMarkdown(block.content))
                .font(InsightAtlasTypography.h3)
                .foregroundColor(InsightAtlasColors.heading)
                .padding(.top, 12)

        case .paragraph:
            Text(parseInlineMarkdown(block.content))
                .font(InsightAtlasTypography.body)
                .foregroundColor(InsightAtlasColors.body)
                .lineSpacing(8)
                .padding(.vertical, 2)

        case .quote:
            QuoteBlockView(content: block.content)

        case .premiumQuote:
            PremiumQuoteBlockView(content: block.content)

        case .listItem:
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(InsightAtlasColors.gold)
                    .frame(width: 5, height: 5)
                    .padding(.top, 8)

                Text(parseInlineMarkdown(block.content))
                    .font(InsightAtlasTypography.body)
                    .foregroundColor(InsightAtlasColors.body)
            }
            .padding(.leading, 8)

        case .numberedItem:
            Text(parseInlineMarkdown(block.content))
                .font(InsightAtlasTypography.body)
                .foregroundColor(InsightAtlasColors.body)
                .padding(.leading, 8)

        case .code:
            Text(block.content)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(InsightAtlasColors.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(InsightAtlasColors.card)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(InsightAtlasColors.ruleLight, lineWidth: 1)
                )

        case .divider:
            HStack(spacing: 16) {
                Rectangle()
                    .fill(InsightAtlasColors.rule)
                    .frame(height: 1)

                Circle()
                    .fill(InsightAtlasColors.gold)
                    .frame(width: 6, height: 6)

                Rectangle()
                    .fill(InsightAtlasColors.rule)
                    .frame(height: 1)
            }
            .padding(.vertical, 16)

        case .quickGlance:
            QuickGlanceBlockView(content: sanitizeInlineMarkdown(block.content))

        case .insightNote:
            InsightNoteBlockView(content: sanitizeInlineMarkdown(block.content))

        case .actionBox:
            ActionBoxBlockView(content: sanitizeInlineMarkdown(block.content), title: sanitizeInlineMarkdown(block.title))

        case .authorSpotlight:
            AuthorSpotlightBlockView(content: sanitizeInlineMarkdown(block.content))

        case .alternativePerspective:
            AlternativePerspectiveBlockView(content: sanitizeInlineMarkdown(block.content))

        case .researchInsight:
            ResearchInsightBlockView(content: sanitizeInlineMarkdown(block.content))

        case .flowchart:
            FlowchartBlockView(content: block.content, title: block.title)
                .padding(.vertical, 12)

        case .table:
            TableBlockView(content: block.content, title: block.title)
                .padding(.vertical, 12)

        case .structureMap:
            StructureMapBlockView(content: block.content, title: block.title)
                .padding(.vertical, 12)

        case .exercise:
            ExerciseBlockView(content: sanitizeInlineMarkdown(block.content))

        case .foundationalNarrative:
            FoundationalNarrativeBlockView(content: sanitizeInlineMarkdown(block.content))
                .padding(.vertical, 8)

        case .takeaways:
            TakeawaysBlockView(content: sanitizeInlineMarkdown(block.content))
                .padding(.vertical, 8)
        case .insightVisual:
            if let visualPayload = block.visualPayload {
                InsightVisualView(visual: visualPayload)
                    .padding(.vertical, 12)
            }
        }
    }

}

// MARK: - Content Block Model

struct IAContentBlock: Identifiable {
    let id = UUID()
    let type: IABlockType
    let content: String
    let title: String
    var visualPayload: InsightVisual? = nil
}

enum IABlockType {
    case h1, h2, h3
    case premiumH1, premiumH2, premiumDivider
    case paragraph
    case quote
    case premiumQuote
    case listItem
    case numberedItem
    case code
    case divider
    case quickGlance
    case insightNote
    case actionBox
    case authorSpotlight
    case alternativePerspective
    case researchInsight
    case flowchart
    case table
    case structureMap
    case exercise
    case foundationalNarrative
    case takeaways
    case insightVisual
}

// MARK: - Branded Block Views

struct QuoteBlockView: View {
    let content: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Rectangle()
                .fill(InsightAtlasColors.gold)
                .frame(width: 3)

            Text(parseInlineMarkdown(content))
                .font(InsightAtlasTypography.bodyItalic)
                .foregroundColor(InsightAtlasColors.body)
                .lineSpacing(8)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(InsightAtlasColors.card.opacity(0.3))
        .cornerRadius(4)
    }
}

struct QuickGlanceBlockView: View {
    let content: String

    private var readingTime: String {
        // Average reading speed is ~200-250 words per minute
        let wordsPerMinute = 225.0
        let wordCount = Double(content.split(separator: " ").count)
        let minutes = max(1, Int(ceil(wordCount / wordsPerMinute)))
        return "\(minutes) min read"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                BlockLabel(text: "Quick Glance", color: InsightAtlasColors.gold)

                Spacer()

                Text(readingTime)
                    .font(InsightAtlasTypography.caption)
                    .foregroundColor(InsightAtlasColors.muted)
            }

            Rectangle()
                .fill(InsightAtlasColors.gold)
                .frame(height: 1.5)

            // Content
            Text(parseInlineMarkdown(content.trimmingCharacters(in: .whitespacesAndNewlines), baseFontSize: 14))
                .font(InsightAtlasTypography.bodySmall)
                .foregroundColor(InsightAtlasColors.body)
                .lineSpacing(6)
        }
        .padding(16)
        .background(InsightAtlasColors.card)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(InsightAtlasColors.rule, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct InsightNoteBlockView: View {
    let content: String

    private var parsed: (coreConnection: String, keyDistinction: String?, practicalImplication: String?, goDeeper: String?) {
        parseInsightNoteContent(content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BlockLabel(text: "Insight Atlas Note", color: InsightAtlasColors.gold)

            if !parsed.coreConnection.isEmpty {
                Text(parseInlineMarkdown(parsed.coreConnection, baseFontSize: 16))
                    .font(InsightAtlasTypography.body)
                    .foregroundColor(InsightAtlasColors.body)
                    .lineSpacing(6)
            }

            if let keyDistinction = parsed.keyDistinction, !keyDistinction.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    BlockLabel(text: "Key Distinction", color: InsightAtlasColors.gold)
                    Text(parseInlineMarkdown(keyDistinction, baseFontSize: 14))
                        .font(InsightAtlasTypography.bodySmall)
                        .foregroundColor(InsightAtlasColors.muted)
                        .lineSpacing(6)
                }
            }

            if let practical = parsed.practicalImplication, !practical.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    BlockLabel(text: "Practical Implication", color: InsightAtlasColors.gold)
                    Text(parseInlineMarkdown(practical, baseFontSize: 14))
                        .font(InsightAtlasTypography.bodySmall)
                        .foregroundColor(InsightAtlasColors.muted)
                        .lineSpacing(6)
                }
            }

            if let goDeeper = parsed.goDeeper, !goDeeper.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    BlockLabel(text: "Go Deeper", color: InsightAtlasColors.gold)
                    Text(parseInlineMarkdown(goDeeper, baseFontSize: 14))
                        .font(InsightAtlasTypography.bodySmall)
                        .italic()
                        .foregroundColor(InsightAtlasColors.muted)
                        .lineSpacing(6)
                }
            }
        }
        .padding(16)
        .background(InsightAtlasColors.card)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(InsightAtlasColors.rule, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

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
        }
        coreConnection = coreText.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespacesAndNewlines)

        return (coreConnection, keyDistinction, practicalImplication, goDeeper)
    }
}

struct ActionBoxBlockView: View {
    let content: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BlockLabel(text: title.isEmpty ? "Apply It" : "Apply It: \(title)", color: InsightAtlasColors.gold)

            ForEach(Array(listItems(from: content).enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1).")
                        .font(InsightAtlasTypography.bodyBold)
                        .foregroundColor(InsightAtlasColors.gold)
                        .padding(.top, 1)
                    Text(parseInlineMarkdown(item))
                        .font(InsightAtlasTypography.body)
                        .foregroundColor(InsightAtlasColors.body)
                        .lineSpacing(6)
                }
            }
        }
        .padding(16)
        .background(InsightAtlasColors.card)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(InsightAtlasColors.rule, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct FlowchartBlockView: View {
    let content: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            BlockLabel(text: title.isEmpty ? "Flowchart" : title, color: InsightAtlasColors.gold)

            // Parse flowchart steps
            let steps = content.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && !$0.contains("↓") && !$0.contains("─") && !$0.contains("│") }

            VStack(alignment: .center, spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    Text(step)
                        .font(InsightAtlasTypography.body)
                        .foregroundColor(InsightAtlasColors.body)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(InsightAtlasColors.card)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(InsightAtlasColors.rule, lineWidth: 1)
                        )

                    if index < steps.count - 1 {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(InsightAtlasColors.gold)
                    }
                }
            }
        }
        .padding(16)
        .background(InsightAtlasColors.card)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(InsightAtlasColors.rule, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct TableBlockView: View {
    let content: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            if !title.isEmpty {
                BlockLabel(text: title, color: InsightAtlasColors.gold)
            }

            // Parse table
            let rows = content.components(separatedBy: "\n")
                .filter { $0.contains("|") && !$0.contains("---") }
                .map { row in
                    row.components(separatedBy: "|")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                }

            VStack(spacing: 0) {
                if let headerRow = rows.first {
                    // Header row
                    HStack(spacing: 0) {
                        ForEach(Array(headerRow.enumerated()), id: \.offset) { _, cell in
                            Text(cell)
                                .font(InsightAtlasTypography.captionBold)
                                .foregroundColor(InsightAtlasColors.heading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                        }
                    }
                    .background(InsightAtlasColors.backgroundAlt)

                    // Data rows
                    ForEach(Array(rows.dropFirst().enumerated()), id: \.offset) { index, row in
                        HStack(spacing: 0) {
                            ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                                Text(cell)
                                    .font(InsightAtlasTypography.body)
                                    .foregroundColor(InsightAtlasColors.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                            }
                        }
                        .background(index % 2 == 0 ? InsightAtlasColors.card : InsightAtlasColors.background)
                    }
                }
            }
        }
        .padding(12)
        .background(InsightAtlasColors.card)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(InsightAtlasColors.rule, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct ExerciseBlockView: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BlockLabel(text: "Exercise", color: InsightAtlasColors.gold)

            Text(parseInlineMarkdown(content.trimmingCharacters(in: .whitespacesAndNewlines)))
                .font(InsightAtlasTypography.body)
                .foregroundColor(InsightAtlasColors.body)
                .lineSpacing(6)
        }
        .padding(16)
        .background(InsightAtlasColors.card)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(InsightAtlasColors.rule, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct FoundationalNarrativeBlockView: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BlockLabel(text: "The Story Behind the Ideas", color: InsightAtlasColors.gold)

            Text(parseInlineMarkdown(content.trimmingCharacters(in: .whitespacesAndNewlines)))
                .font(InsightAtlasTypography.body)
                .foregroundColor(InsightAtlasColors.body)
                .lineSpacing(6)
        }
        .padding(16)
        .background(InsightAtlasColors.card)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(InsightAtlasColors.rule, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct TakeawaysBlockView: View {
    let content: String

    var body: some View {
        let items = listItems(from: content)
        VStack(alignment: .leading, spacing: 12) {
            BlockLabel(text: "Key Takeaways", color: InsightAtlasColors.gold)

            if items.isEmpty {
                Text(parseInlineMarkdown(content.trimmingCharacters(in: .whitespacesAndNewlines)))
                    .font(InsightAtlasTypography.body)
                    .foregroundColor(InsightAtlasColors.body)
                    .lineSpacing(6)
            } else {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1).")
                            .font(InsightAtlasTypography.bodyBold)
                            .foregroundColor(InsightAtlasColors.gold)
                            .padding(.top, 1)
                        Text(parseInlineMarkdown(item))
                            .font(InsightAtlasTypography.body)
                            .foregroundColor(InsightAtlasColors.body)
                            .lineSpacing(6)
                    }
                }
            }
        }
        .padding(16)
        .background(InsightAtlasColors.card)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(InsightAtlasColors.rule, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Premium Block Views

struct PremiumHeaderBlockView: View {
    let content: String

    var body: some View {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
        let label = parts.count > 1 ? parts[0] : ""
        let title = parts.count > 1 ? parts[1] : trimmed

        VStack(alignment: .leading, spacing: 8) {
            if !label.isEmpty {
                BlockLabel(text: label, color: InsightAtlasColors.gold)
            }

            Text(title)
                .font(InsightAtlasTypography.largeTitle)
                .foregroundColor(InsightAtlasColors.heading)

            Rectangle()
                .fill(InsightAtlasColors.gold)
                .frame(height: 2)
        }
    }
}

struct PremiumSubheaderBlockView: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(content.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(InsightAtlasTypography.h2)
                .foregroundColor(InsightAtlasColors.heading)

            Rectangle()
                .fill(InsightAtlasColors.gold)
                .frame(height: 1.5)
        }
    }
}

struct PremiumDividerView: View {
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(InsightAtlasColors.rule)
                .frame(height: 1)

            Rectangle()
                .fill(InsightAtlasColors.gold)
                .frame(width: 28, height: 2)

            Rectangle()
                .fill(InsightAtlasColors.rule)
                .frame(height: 1)
        }
    }
}

struct PremiumQuoteBlockView: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(InsightAtlasColors.gold)

                Text(parseInlineMarkdown(content.trimmingCharacters(in: .whitespacesAndNewlines)))
                    .font(InsightAtlasTypography.bodyItalic)
                    .foregroundColor(InsightAtlasColors.body)
                    .lineSpacing(8)
            }
        }
        .padding(16)
        .background(InsightAtlasColors.card)
        .overlay(
            Rectangle()
                .fill(InsightAtlasColors.gold)
                .frame(width: 4),
            alignment: .leading
        )
        .cornerRadius(8)
    }
}

struct AuthorSpotlightBlockView: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            BlockLabel(text: "Author Spotlight", color: InsightAtlasColors.gold)

            Text(parseInlineMarkdown(content.trimmingCharacters(in: .whitespacesAndNewlines)))
                .font(InsightAtlasTypography.body)
                .foregroundColor(InsightAtlasColors.body)
                .lineSpacing(6)
        }
        .padding(16)
        .background(InsightAtlasColors.card)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(InsightAtlasColors.rule, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct AlternativePerspectiveBlockView: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            BlockLabel(text: "Alternative Perspective", color: InsightAtlasColors.gold)

            Text(parseInlineMarkdown(content.trimmingCharacters(in: .whitespacesAndNewlines)))
                .font(InsightAtlasTypography.body)
                .foregroundColor(InsightAtlasColors.body)
                .lineSpacing(6)
        }
        .padding(16)
        .background(InsightAtlasColors.card)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(InsightAtlasColors.rule, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct ResearchInsightBlockView: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            BlockLabel(text: "Research Insight", color: InsightAtlasColors.gold)

            Text(parseInlineMarkdown(content.trimmingCharacters(in: .whitespacesAndNewlines)))
                .font(InsightAtlasTypography.body)
                .foregroundColor(InsightAtlasColors.body)
                .lineSpacing(6)
        }
        .padding(16)
        .background(InsightAtlasColors.card)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(InsightAtlasColors.rule, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct StructureMapBlockView: View {
    let content: String
    let title: String

    var body: some View {
        TableBlockView(content: content, title: title.isEmpty ? "Structure Map" : title)
    }
}

// MARK: - Shared Helpers

struct BlockLabel: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text.uppercased())
            .font(InsightAtlasTypography.captionBold)
            .foregroundColor(color)
            .tracking(1.2)
    }
}

fileprivate func listItems(from text: String) -> [String] {
    let lines = text.components(separatedBy: "\n")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

    return lines.map { line in
        line.replacingOccurrences(
            of: #"^\d+\.\s*"#,
            with: "",
            options: .regularExpression
        )
        .replacingOccurrences(of: "•", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)

        // Configure popover for iPad - required to prevent crash
        // Note: When used with SwiftUI .sheet(), the popover controller may be nil
        // but this ensures proper configuration when it exists
        if let popover = activityVC.popoverPresentationController {
            popover.permittedArrowDirections = .any
        }

        return activityVC
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
