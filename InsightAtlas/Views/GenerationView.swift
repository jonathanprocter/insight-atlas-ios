import SwiftUI
import UniformTypeIdentifiers

struct GenerationView: View {

    // MARK: - Environment

    @EnvironmentObject var environment: AppEnvironment
    @ObservedObject private var generationCoordinator = BackgroundGenerationCoordinator.shared
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var generationState: GenerationUIState = .idle
    @State private var generatedItem: LibraryItem?
    @State private var progress: Double = 0
    @State private var statusMessage = ""

    // File picker state
    @State private var showingFilePicker = false
    @State private var selectedFileURL: URL?
    @State private var selectedFileName: String?
    @State private var selectedFileType: FileType?
    @State private var cachedFileData: Data?

    // Voice selection state
    @State private var showingVoicePicker = false
    @State private var selectedVoiceID: String?
    @State private var audioSpeed: Double = 1.0

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                switch generationState {
                case .idle:
                    setupView
                case .generating:
                    generatingView
                case .completed:
                    completedView
                case .error(let message):
                    errorView(message: message)
                }
            }
            .navigationTitle("Generate Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(PremiumUI.teal)
                    .accessibilityIdentifier("generation_cancel_button")
                }
            }
            .background(PremiumUI.background.ignoresSafeArea())
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.pdf, .epub],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .sheet(isPresented: $showingVoicePicker) {
            VoiceSelectionSheet(
                selectedVoiceID: $selectedVoiceID,
                voiceProvider: environment.userSettings.voiceProvider
            )
        }
        .onAppear {
            syncGenerationState()
        }
        .onReceive(generationCoordinator.$progress) { updated in
            guard generationState == .generating else { return }
            statusMessage = updated.phase
            progress = max(0, min(updated.percentComplete, 1.0))
        }
        .onReceive(generationCoordinator.$isGenerating) { isGenerating in
            if isGenerating {
                generationState = .generating
            }
        }
        .onReceive(generationCoordinator.$lastResult) { result in
            guard let result = result else { return }
            handleGenerationResult(result)
        }
    }

    // MARK: - Setup View

    private var setupView: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(PremiumUI.teal)
                        .padding(.top, 40)

                    Text("Create Your Guide")
                        .font(PremiumUI.display(26, .bold))
                        .foregroundColor(PremiumUI.ink)

                    Text("Upload a PDF or EPUB book to generate a comprehensive reading guide")
                        .font(PremiumUI.ui(16))
                        .foregroundColor(PremiumUI.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Selected file preview
                if let fileName = selectedFileName {
                    selectedFileCard(fileName: fileName)
                }

                generationOptionsCard

                // File picker button
                Button {
                    showingFilePicker = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: selectedFileName == nil ? "doc.badge.plus" : "arrow.triangle.2.circlepath")
                            .font(.title2)
                        Text(selectedFileName == nil ? "Choose File" : "Change File")
                            .font(PremiumUI.ui(16, .semibold))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14).foregroundStyle(PremiumUI.gold).background(PremiumUI.gold.opacity(0.12)).clipShape(Capsule()).overlay(Capsule().stroke(PremiumUI.gold.opacity(0.30), lineWidth: 1))
                }
                .padding(.horizontal, 24)
                .accessibilityIdentifier("generation_choose_file_button")

                // Generate button (only show when file is selected)
                if selectedFileName != nil {
                    Button {
                        startGeneration()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.title2)
                            Text("Generate Guide")
                                .font(PremiumUI.ui(16, .semibold))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 16).foregroundStyle(.white).background(PremiumUI.gold).clipShape(Capsule()).shadow(color: PremiumUI.gold.opacity(0.25), radius: 12, y: 4)
                    }
                    .padding(.horizontal, 24)
                    .accessibilityIdentifier("generation_generate_button")
                }

                // Supported formats info
                VStack(spacing: 8) {
                    Text("Supported Formats")
                        .font(PremiumUI.ui(13))
                        .foregroundColor(PremiumUI.secondaryText)

                    HStack(spacing: 16) {
                        formatBadge(icon: "doc.text", label: "PDF")
                        formatBadge(icon: "book", label: "EPUB")
                    }
                }
                .padding(.top, 16)

                Spacer(minLength: 40)
            }
        }
    }

    private var generationOptionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Output Options")
                .font(PremiumUI.ui(16, .semibold))
                .foregroundColor(PremiumUI.ink)

            VStack(alignment: .leading, spacing: 8) {
                Text("AI Provider")
                    .font(PremiumUI.ui(13))
                    .foregroundColor(PremiumUI.secondaryText)
                Picker("Provider", selection: $environment.userSettings.preferredProvider) {
                    ForEach(AIProvider.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: environment.userSettings.preferredProvider) {
                    environment.saveSettings()
                }
                .accessibilityIdentifier("generation_provider_picker")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Analysis Depth")
                    .font(PremiumUI.ui(13))
                    .foregroundColor(PremiumUI.secondaryText)
                Picker("Mode", selection: $environment.userSettings.preferredMode) {
                    ForEach(GenerationMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: environment.userSettings.preferredMode) {
                    environment.saveSettings()
                }
                .accessibilityIdentifier("generation_mode_picker")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Writing Style")
                    .font(PremiumUI.ui(13))
                    .foregroundColor(PremiumUI.secondaryText)
                Picker("Tone", selection: $environment.userSettings.preferredTone) {
                    ForEach(ToneMode.allCases, id: \.self) { tone in
                        Text(tone.displayName).tag(tone)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: environment.userSettings.preferredTone) {
                    environment.saveSettings()
                }
                .accessibilityIdentifier("generation_tone_picker")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Output Format")
                    .font(PremiumUI.ui(13))
                    .foregroundColor(PremiumUI.secondaryText)
                Picker("Format", selection: $environment.userSettings.preferredFormat) {
                    ForEach(OutputFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: environment.userSettings.preferredFormat) {
                    environment.saveSettings()
                }
                .accessibilityIdentifier("generation_format_picker")
                Text(environment.userSettings.preferredFormat.description)
                    .font(PremiumUI.ui(13))
                    .foregroundColor(PremiumUI.secondaryText)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Summary Length")
                    .font(PremiumUI.ui(13))
                    .foregroundColor(PremiumUI.secondaryText)
                Picker("Summary Type", selection: $environment.userSettings.preferredSummaryType) {
                    ForEach(SummaryType.allCases, id: \.self) { summaryType in
                        Text(summaryType.displayName).tag(summaryType)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: environment.userSettings.preferredSummaryType) {
                    environment.saveSettings()
                }
                .accessibilityIdentifier("generation_summary_type_picker")
            }

            Divider()
                .padding(.vertical, 8)

            // Audio Voice Selection
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "waveform")
                        .foregroundColor(PremiumUI.teal)
                    Text("Audio Narration")
                        .font(PremiumUI.ui(16, .semibold))
                        .foregroundColor(PremiumUI.ink)
                }

                // Voice Provider
                VStack(alignment: .leading, spacing: 4) {
                    Text("Voice Provider")
                        .font(PremiumUI.ui(13))
                        .foregroundColor(PremiumUI.secondaryText)
                    Picker("Voice Provider", selection: $environment.userSettings.voiceProvider) {
                        ForEach(VoiceProvider.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: environment.userSettings.voiceProvider) {
                        environment.updateVoiceProvider(environment.userSettings.voiceProvider)
                        selectedVoiceID = environment.userSettings.voiceProvider.defaultVoiceID
                        environment.userSettings.selectedVoiceID = selectedVoiceID
                        environment.saveSettings()
                    }
                    .accessibilityIdentifier("generation_voice_provider_picker")

                    if !environment.userSettings.voiceProvider.isConfigured() {
                        Text("\(environment.userSettings.voiceProvider.displayName) API key not configured.")
                            .font(PremiumUI.ui(13))
                            .foregroundColor(PremiumUI.warmOrange)
                    }
                }

                // Voice Selection Button
                Button {
                    showingVoicePicker = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Selected Voice")
                                .font(PremiumUI.ui(13))
                                .foregroundColor(PremiumUI.secondaryText)
                            Text(selectedVoiceName)
                                .font(PremiumUI.ui(16))
                                .foregroundColor(PremiumUI.ink)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(PremiumUI.secondaryText)
                    }
                    .padding(12)
                    .background(PremiumUI.background)
                    .cornerRadius(8)
                }
                .accessibilityIdentifier("generation_voice_select_button")

                // Audio Speed
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Playback Speed")
                            .font(PremiumUI.ui(13))
                            .foregroundColor(PremiumUI.secondaryText)
                        Spacer()
                        Text(String(format: "%.1fx", audioSpeed))
                            .font(PremiumUI.ui(13))
                            .foregroundColor(PremiumUI.teal)
                    }
                    Slider(value: $audioSpeed, in: 0.5...2.0, step: 0.1)
                        .tint(PremiumUI.teal)
                        .accessibilityIdentifier("generation_audio_speed_slider")
                }
            }
        }
        .padding(16)
        .background(PremiumUI.card)
        .cornerRadius(12)
        .shadow(color: PremiumUI.cardShadow, radius: 4, y: 2)
        .padding(.horizontal, 24)
    }

    /// Get the display name for the currently selected voice
    private var selectedVoiceName: String {
        let provider = environment.userSettings.voiceProvider
        guard let voiceID = selectedVoiceID else {
            switch provider {
            case .onDevice:
                return "Daniel (Default)"
            case .elevenlabs:
                return ElevenLabsVoiceRegistry.premiumPrimaryVoice(for: .practitioner).name + " (Default)"
            }
        }

        switch provider {
        case .onDevice:
            return OnDeviceVoiceRegistry.voice(byID: voiceID)?.name ?? "Daniel"
        case .elevenlabs:
            return ElevenLabsVoiceRegistry.voice(byVoiceID: voiceID)?.name ?? voiceID
        }
    }

    private func selectedFileCard(fileName: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: selectedFileType == .pdf ? "doc.text.fill" : "book.fill")
                .font(.title)
                .foregroundColor(PremiumUI.teal)
                .frame(width: 50, height: 50)
                .background(PremiumUI.teal.opacity(0.08))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(fileName)
                    .font(PremiumUI.ui(16, .semibold))
                    .foregroundColor(PremiumUI.ink)
                    .lineLimit(2)

                Text(selectedFileType?.rawValue.uppercased() ?? "Document")
                    .font(PremiumUI.ui(13))
                    .foregroundColor(PremiumUI.secondaryText)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(PremiumUI.forest)
        }
        .padding(16)
        .background(PremiumUI.card)
        .cornerRadius(12)
        .shadow(color: PremiumUI.cardShadow, radius: 4, y: 2)
        .padding(.horizontal, 24)
    }

    private func formatBadge(icon: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(label)
                .font(PremiumUI.ui(13))
        }
        .foregroundColor(PremiumUI.secondaryText)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(PremiumUI.divider)
        .cornerRadius(999)
    }

    // MARK: - Generating View

    private var generatingView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated progress indicator
            ZStack {
                Circle()
                    .stroke(PremiumUI.divider, lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [PremiumUI.teal, PremiumUI.teal.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: progress)

                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundColor(PremiumUI.teal)
            }
            .accessibilityIdentifier("generation_progress_ring")

            VStack(spacing: 12) {
                Text(statusMessage.isEmpty ? "Analyzing your book..." : statusMessage)
                    .font(PremiumUI.display(20, .semibold))
                    .foregroundColor(PremiumUI.ink)
                    .multilineTextAlignment(.center)

                Text("This may take a few minutes")
                    .font(PremiumUI.ui(16))
                    .foregroundColor(PremiumUI.secondaryText)

                Text("\(Int(progress * 100))%")
                    .font(PremiumUI.ui(16, .semibold))
                    .foregroundColor(PremiumUI.teal)
                    .padding(.top, 8)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Completed View

    private var completedView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Success Icon
                ZStack {
                    Circle()
                        .fill(PremiumUI.forest.opacity(0.15))
                        .frame(width: 120, height: 120)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 70))
                        .foregroundColor(PremiumUI.forest)
                }
                .padding(.top, 40)

                // Title
                Text("Guide Generated!")
                    .font(PremiumUI.display(32, .bold))
                    .foregroundColor(PremiumUI.ink)

                // Preview Card
                if let item = generatedItem {
                    GuidePreviewCard(item: item)
                        .padding(.horizontal)
                }

                // Actions
                VStack(spacing: 12) {
                    if let item = generatedItem {
                        NavigationLink(destination: AnalysisDetailView(item: item)) {
                            HStack(spacing: 12) {
                                Image(systemName: "book.fill")
                                Text("View Guide")
                                    .font(PremiumUI.ui(16, .semibold))
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 16).foregroundStyle(.white).background(PremiumUI.gold).clipShape(Capsule()).shadow(color: PremiumUI.gold.opacity(0.25), radius: 12, y: 4)
                        }
                        .accessibilityIdentifier("generation_view_guide_button")
                    }

                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save to Library")
                                .font(PremiumUI.ui(16, .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(PremiumUI.card)
                        .foregroundColor(PremiumUI.ink)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(PremiumUI.divider, lineWidth: 1)
                        )
                    }
                    .accessibilityIdentifier("generation_save_to_library_button")
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 70))
                .foregroundColor(PremiumUI.warmOrange)

            Text("Generation Failed")
                .font(PremiumUI.display(26, .bold))
                .foregroundColor(PremiumUI.ink)

            Text(message)
                .font(PremiumUI.ui(16))
                .foregroundColor(PremiumUI.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                generationState = .idle
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                        .font(PremiumUI.ui(16, .semibold))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 16).foregroundStyle(.white).background(PremiumUI.gold).clipShape(Capsule()).shadow(color: PremiumUI.gold.opacity(0.25), radius: 12, y: 4)
            }
            .padding(.horizontal, 24)
            .accessibilityIdentifier("generation_try_again_button")

            Spacer()
        }
    }

    // MARK: - File Selection Handler

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                generationState = .error("Unable to access the selected file. Please try again.")
                return
            }

            defer { url.stopAccessingSecurityScopedResource() }

            // Cache file data while we have access to avoid re-accessing later
            do {
                cachedFileData = try Data(contentsOf: url)
            } catch {
                generationState = .error("Failed to read file: \(error.localizedDescription)")
                return
            }

            selectedFileURL = url
            selectedFileName = url.lastPathComponent

            // Determine file type
            if url.pathExtension.lowercased() == "pdf" {
                selectedFileType = .pdf
            } else if url.pathExtension.lowercased() == "epub" {
                selectedFileType = .epub
            }

        case .failure(let error):
            generationState = .error("Failed to select file: \(error.localizedDescription)")
        }
    }

    // MARK: - Generation

    private func startGeneration() {
        guard let fileURL = selectedFileURL,
              let fileType = selectedFileType,
              let bookData = cachedFileData else {
            generationState = .error("Please select a file first.")
            return
        }

        generationState = .generating
        statusMessage = "Reading your book..."
        progress = 0.1

        // Pre-create item ID so cover image is saved with the correct ID
        let newItemId = UUID()

        Task {
            do {
                await MainActor.run {
                    statusMessage = "Analyzing content..."
                    progress = 0.2
                }

                // Extract title and author from filename (metadata resolved during processing)
                let fileName = fileURL.deletingPathExtension().lastPathComponent
                let title = fileName
                let author = "Unknown Author"

                // Start generation using cached file data
                let output = try await environment.generationCoordinator.startGeneration(
                    bookData: bookData,
                    fileType: fileType,
                    title: title,
                    author: author,
                    settings: environment.userSettings,
                    existingItemId: newItemId,
                    summaryType: environment.userSettings.preferredSummaryType,
                    voiceID: selectedVoiceID
                )

                await MainActor.run {
                    progress = 1.0

                    let resolvedTitle = output.resolvedTitle
                    let resolvedAuthor = output.resolvedAuthor

                    // Create library item with cover image path (using pre-created ID)
                    let item = LibraryItem(
                        id: newItemId,
                        title: resolvedTitle,
                        author: resolvedAuthor,
                        fileType: fileType,
                        summaryContent: output.content,
                        provider: environment.userSettings.preferredProvider,
                        mode: environment.userSettings.preferredMode,
                        coverImagePath: output.coverImagePath,
                        summaryType: output.metadata?.summaryType,
                        governedWordCount: output.metadata?.governedWordCount,
                        cutPolicyActivated: output.metadata?.cutPolicyActivated,
                        cutEventCount: output.metadata?.cutEventCount,
                        audioFileURL: output.metadata?.audioFileURL,
                        audioVoiceID: output.metadata?.audioVoiceID,
                        audioDuration: output.metadata?.audioDuration
                    )

                    // Save to library
                    environment.addLibraryItem(item)
                    generatedItem = item
                    generationState = .completed

                    // Clear cached data to free memory
                    cachedFileData = nil
                }

            } catch {
                await MainActor.run {
                    generationState = .error(error.localizedDescription)
                    cachedFileData = nil
                }
            }
        }
    }

    private func syncGenerationState() {
        if generationCoordinator.isGenerating {
            generationState = .generating
            statusMessage = generationCoordinator.progress.phase
            progress = max(0, min(generationCoordinator.progress.percentComplete, 1.0))
        }
    }

    private func handleGenerationResult(_ result: GenerationResult) {
        switch result {
        case .success(_, let itemId, _, _):
            if let itemId = itemId,
               let item = environment.dataManager.getLibraryItem(id: itemId) {
                generatedItem = item
            }
            generationState = .completed
            progress = 1.0
        case .failure(let error):
            generationState = .error(error.localizedDescription)
        case .cancelled:
            generationState = .error("Generation was cancelled.")
        }
    }
}

// MARK: - Generation UI State

enum GenerationUIState: Equatable {
    case idle
    case generating
    case completed
    case error(String)
}

// MARK: - Guide Preview Card

struct GuidePreviewCard: View {
    let item: LibraryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Cover Image
            if let coverPath = item.coverImagePath,
               let imageData = loadCoverImageData(from: coverPath),
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 180)
                    .clipped()
                    .cornerRadius(12)
            }

            // Title and Author
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(PremiumUI.display(18, .semibold))
                    .foregroundColor(PremiumUI.ink)
                    .lineLimit(2)

                Text(item.author)
                    .font(PremiumUI.ui(16))
                    .foregroundColor(PremiumUI.secondaryText)
            }

            // Metadata
            HStack(spacing: 16) {
                if let wordCount = item.governedWordCount {
                    let minutes = wordCount / 200
                    Label("\(minutes) min read", systemImage: "clock")
                        .font(PremiumUI.ui(13))
                        .foregroundColor(PremiumUI.secondaryText)
                }

                if let wordCount = item.governedWordCount {
                    Label("\(wordCount) words", systemImage: "doc.text")
                        .font(PremiumUI.ui(13))
                        .foregroundColor(PremiumUI.secondaryText)
                }
            }
        }
        .padding(16)
        .background(PremiumUI.card)
        .cornerRadius(16)
        .shadow(color: PremiumUI.cardShadow, radius: 8, y: 4)
    }

    private func loadCoverImageData(from path: String) -> Data? {
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let fileURL = documentsDir.appendingPathComponent(path)
        return try? Data(contentsOf: fileURL)
    }
}

// MARK: - Voice Selection Sheet

/// Sheet for selecting a voice before generation
struct VoiceSelectionSheet: View {
    @Binding var selectedVoiceID: String?
    let voiceProvider: VoiceProvider

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select a voice for your audio narration.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    switch voiceProvider {
                    case .onDevice:
                        onDeviceVoiceList
                    case .elevenlabs:
                        elevenLabsVoiceList
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Select Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("voice_selection_cancel_button")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("voice_selection_done_button")
                }
            }
            .background(PremiumUI.background.ignoresSafeArea())
        }
    }

    private var onDeviceVoiceList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ON-DEVICE (KOKORO)")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(1)
                .foregroundColor(PremiumUI.teal)
                .padding(.horizontal)

            ForEach(OnDeviceVoiceRegistry.allVoices, id: \.id) { voice in
                voiceRow(
                    id: voice.voiceID,
                    name: voice.name,
                    description: voice.description,
                    isSelected: selectedVoiceID == voice.voiceID
                )
            }
        }
    }

    private var elevenLabsVoiceList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ELEVENLABS VOICES")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(1)
                .foregroundColor(PremiumUI.gold)
                .padding(.horizontal)

            ForEach(ElevenLabsVoiceRegistry.allVoices, id: \.id) { voice in
                voiceRow(
                    id: voice.voiceID,
                    name: voice.name,
                    description: voice.description,
                    isSelected: selectedVoiceID == voice.voiceID
                )
            }
        }
    }

    private func voiceRow(id: String, name: String, description: String, isSelected: Bool) -> some View {
        Button {
            selectedVoiceID = id
        } label: {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? PremiumUI.teal : PremiumUI.secondaryText)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.headline)
                        .foregroundColor(PremiumUI.ink)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(PremiumUI.secondaryText)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(12)
            .background(isSelected ? PremiumUI.teal.opacity(0.08) : PremiumUI.card)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .accessibilityIdentifier("voice_row_\(id)")
    }
}
