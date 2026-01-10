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
                    .foregroundColor(AnalysisTheme.accentTeal)
                }
            }
            .background(AnalysisTheme.bgSecondary.ignoresSafeArea())
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.pdf, .epub],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
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
                        .foregroundColor(AnalysisTheme.accentTeal)
                        .padding(.top, 40)

                    Text("Create Your Guide")
                        .font(.analysisDisplayH2())
                        .foregroundColor(AnalysisTheme.textHeading)

                    Text("Upload a PDF or EPUB book to generate a comprehensive reading guide")
                        .font(.analysisBody())
                        .foregroundColor(AnalysisTheme.textMuted)
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
                            .font(.analysisUIBold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [AnalysisTheme.accentTeal, AnalysisTheme.accentTealLight],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(AnalysisTheme.Radius.lg)
                    .shadow(color: AnalysisTheme.accentTeal.opacity(0.3), radius: 8, y: 4)
                }
                .padding(.horizontal, 24)

                // Generate button (only show when file is selected)
                if selectedFileName != nil {
                    Button {
                        startGeneration()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.title2)
                            Text("Generate Guide")
                                .font(.analysisUIBold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [AnalysisTheme.accentHighlight, AnalysisTheme.accentCoralLight],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(AnalysisTheme.Radius.lg)
                        .shadow(color: AnalysisTheme.accentHighlight.opacity(0.3), radius: 8, y: 4)
                    }
                    .padding(.horizontal, 24)
                }

                // Supported formats info
                VStack(spacing: 8) {
                    Text("Supported Formats")
                        .font(.analysisUISmall())
                        .foregroundColor(AnalysisTheme.textMuted)

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
                .font(.analysisUIBold())
                .foregroundColor(AnalysisTheme.textHeading)

            VStack(alignment: .leading, spacing: 8) {
                Text("AI Provider")
                    .font(.analysisUISmall())
                    .foregroundColor(AnalysisTheme.textMuted)
                Picker("Provider", selection: $environment.userSettings.preferredProvider) {
                    ForEach(AIProvider.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: environment.userSettings.preferredProvider) {
                    environment.saveSettings()
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Analysis Depth")
                    .font(.analysisUISmall())
                    .foregroundColor(AnalysisTheme.textMuted)
                Picker("Mode", selection: $environment.userSettings.preferredMode) {
                    ForEach(GenerationMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: environment.userSettings.preferredMode) {
                    environment.saveSettings()
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Writing Style")
                    .font(.analysisUISmall())
                    .foregroundColor(AnalysisTheme.textMuted)
                Picker("Tone", selection: $environment.userSettings.preferredTone) {
                    ForEach(ToneMode.allCases, id: \.self) { tone in
                        Text(tone.displayName).tag(tone)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: environment.userSettings.preferredTone) {
                    environment.saveSettings()
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Output Format")
                    .font(.analysisUISmall())
                    .foregroundColor(AnalysisTheme.textMuted)
                Picker("Format", selection: $environment.userSettings.preferredFormat) {
                    ForEach(OutputFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: environment.userSettings.preferredFormat) {
                    environment.saveSettings()
                }
                Text(environment.userSettings.preferredFormat.description)
                    .font(.analysisUISmall())
                    .foregroundColor(AnalysisTheme.textMuted)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Summary Length")
                    .font(.analysisUISmall())
                    .foregroundColor(AnalysisTheme.textMuted)
                Picker("Summary Type", selection: $environment.userSettings.preferredSummaryType) {
                    ForEach(SummaryType.allCases, id: \.self) { summaryType in
                        Text(summaryType.displayName).tag(summaryType)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: environment.userSettings.preferredSummaryType) {
                    environment.saveSettings()
                }
            }
        }
        .padding(16)
        .background(AnalysisTheme.bgCard)
        .cornerRadius(AnalysisTheme.Radius.lg)
        .shadow(color: AnalysisTheme.shadowCard, radius: 4, y: 2)
        .padding(.horizontal, 24)
    }

    private func selectedFileCard(fileName: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: selectedFileType == .pdf ? "doc.text.fill" : "book.fill")
                .font(.title)
                .foregroundColor(AnalysisTheme.accentTeal)
                .frame(width: 50, height: 50)
                .background(AnalysisTheme.accentTealSubtle)
                .cornerRadius(AnalysisTheme.Radius.md)

            VStack(alignment: .leading, spacing: 4) {
                Text(fileName)
                    .font(.analysisUIBold())
                    .foregroundColor(AnalysisTheme.textHeading)
                    .lineLimit(2)

                Text(selectedFileType?.rawValue.uppercased() ?? "Document")
                    .font(.analysisUISmall())
                    .foregroundColor(AnalysisTheme.textMuted)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(AnalysisTheme.accentSuccess)
        }
        .padding(16)
        .background(AnalysisTheme.bgCard)
        .cornerRadius(AnalysisTheme.Radius.lg)
        .shadow(color: AnalysisTheme.shadowCard, radius: 4, y: 2)
        .padding(.horizontal, 24)
    }

    private func formatBadge(icon: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(label)
                .font(.analysisUISmall())
        }
        .foregroundColor(AnalysisTheme.textMuted)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(AnalysisTheme.borderLight)
        .cornerRadius(AnalysisTheme.Radius.full)
    }

    // MARK: - Generating View

    private var generatingView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated progress indicator
            ZStack {
                Circle()
                    .stroke(AnalysisTheme.borderLight, lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [AnalysisTheme.accentTeal, AnalysisTheme.accentTealLight],
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
                    .foregroundColor(AnalysisTheme.accentTeal)
            }

            VStack(spacing: 12) {
                Text(statusMessage.isEmpty ? "Analyzing your book..." : statusMessage)
                    .font(.analysisDisplayH3())
                    .foregroundColor(AnalysisTheme.textHeading)
                    .multilineTextAlignment(.center)

                Text("This may take a few minutes")
                    .font(.analysisBody())
                    .foregroundColor(AnalysisTheme.textMuted)

                Text("\(Int(progress * 100))%")
                    .font(.analysisUIBold())
                    .foregroundColor(AnalysisTheme.accentTeal)
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
                        .fill(AnalysisTheme.accentSuccess.opacity(0.15))
                        .frame(width: 120, height: 120)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 70))
                        .foregroundColor(AnalysisTheme.accentSuccess)
                }
                .padding(.top, 40)

                // Title
                Text("Guide Generated!")
                    .font(.analysisDisplayH1())
                    .foregroundColor(AnalysisTheme.textHeading)

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
                                    .font(.analysisUIBold())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [AnalysisTheme.accentTeal, AnalysisTheme.accentTealLight],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(AnalysisTheme.Radius.lg)
                        }
                    }

                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save to Library")
                                .font(.analysisUIBold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AnalysisTheme.bgCard)
                        .foregroundColor(AnalysisTheme.textHeading)
                        .cornerRadius(AnalysisTheme.Radius.lg)
                        .overlay(
                            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.lg)
                                .stroke(AnalysisTheme.borderLight, lineWidth: 1)
                        )
                    }
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
                .foregroundColor(AnalysisTheme.accentHighlight)

            Text("Generation Failed")
                .font(.analysisDisplayH2())
                .foregroundColor(AnalysisTheme.textHeading)

            Text(message)
                .font(.analysisBody())
                .foregroundColor(AnalysisTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                generationState = .idle
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                        .font(.analysisUIBold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AnalysisTheme.accentTeal)
                .foregroundColor(.white)
                .cornerRadius(AnalysisTheme.Radius.lg)
            }
            .padding(.horizontal, 24)

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
                    summaryType: environment.userSettings.preferredSummaryType
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
                    .cornerRadius(AnalysisTheme.Radius.lg)
            }

            // Title and Author
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.analysisDisplayH4())
                    .foregroundColor(AnalysisTheme.textHeading)
                    .lineLimit(2)

                Text(item.author)
                    .font(.analysisBody())
                    .foregroundColor(AnalysisTheme.textMuted)
            }

            // Metadata
            HStack(spacing: 16) {
                if let wordCount = item.governedWordCount {
                    let minutes = wordCount / 200
                    Label("\(minutes) min read", systemImage: "clock")
                        .font(.analysisUISmall())
                        .foregroundColor(AnalysisTheme.textMuted)
                }

                if let wordCount = item.governedWordCount {
                    Label("\(wordCount) words", systemImage: "doc.text")
                        .font(.analysisUISmall())
                        .foregroundColor(AnalysisTheme.textMuted)
                }
            }
        }
        .padding(16)
        .background(AnalysisTheme.bgCard)
        .cornerRadius(AnalysisTheme.Radius.xl)
        .shadow(color: AnalysisTheme.shadowCard, radius: 8, y: 4)
    }

    private func loadCoverImageData(from path: String) -> Data? {
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let fileURL = documentsDir.appendingPathComponent(path)
        return try? Data(contentsOf: fileURL)
    }
}
