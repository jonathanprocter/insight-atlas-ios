import SwiftUI

struct GenerationView: View {

    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss

    /// Observe the background generation coordinator for progress updates
    @ObservedObject private var generationCoordinator = BackgroundGenerationCoordinator.shared

    let bookData: Data?
    let fileType: FileType
    @State var title: String
    @State var author: String
    let coverImageData: Data?
    var existingItem: LibraryItem?

    @State private var isGenerating = false
    @State private var generatedContent = ""
    @State private var showingError = false
    @State private var errorMessage: String?
    @State private var selectedMode: GenerationMode
    @State private var selectedTone: ToneMode
    @State private var selectedFormat: OutputFormat
    @State private var selectedSummaryType: SummaryType
    @State private var showingInterruptedAlert = false

    // MARK: - Audio Toast State
    @State private var showingAudioReadyToast = false

    // MARK: - Voice Selection State
    @State private var showingVoicePicker = false
    @State private var selectedVoiceID: String = ElevenLabsVoiceRegistry.rachel.voiceID

    private let bookProcessor = BookProcessor()

    init(
        bookData: Data?,
        fileType: FileType,
        title: String,
        author: String,
        coverImageData: Data? = nil,
        existingItem: LibraryItem? = nil
    ) {
        self.bookData = bookData
        self.fileType = fileType
        self._title = State(initialValue: title)
        self._author = State(initialValue: author)
        self.coverImageData = coverImageData
        self.existingItem = existingItem
        self._selectedMode = State(initialValue: .standard)
        self._selectedTone = State(initialValue: .accessible)
        self._selectedFormat = State(initialValue: .fullGuide)
        self._selectedSummaryType = State(initialValue: .accessible) // Default to Comprehensive (6,000 words) for most books
    }

    var body: some View {
        NavigationStack {
            if isGenerating {
                generatingView
            } else if !generatedContent.isEmpty {
                completedView
            } else {
                configurationView
            }
        }
        .overlay(alignment: .bottom) {
            if showingAudioReadyToast {
                audioReadyToast
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showingAudioReadyToast)
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

    // MARK: - Configuration View

    private var configurationView: some View {
        Form {
            Section("Book Details") {
                TextField("Title", text: $title)
                TextField("Author", text: $author)
            }

            Section("Generation Mode") {
                Picker("Mode", selection: $selectedMode) {
                    ForEach(GenerationMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(modeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Tone") {
                Picker("Tone", selection: $selectedTone) {
                    ForEach(ToneMode.allCases, id: \.self) { tone in
                        Text(tone.displayName).tag(tone)
                    }
                }
                .pickerStyle(.segmented)

                Text(toneDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Output Format") {
                Picker("Format", selection: $selectedFormat) {
                    ForEach(OutputFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }

                Text(formatDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            summaryDepthSection

            audioEstimateSection

            voiceSelectionSection

            generateButtonSection
        }
        .navigationTitle("New Guide")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
        .alert("Resume Interrupted Generation?", isPresented: $showingInterruptedAlert) {
            Button("Resume") {
                resumeInterruptedGeneration()
            }
            Button("Discard", role: .destructive) {
                generationCoordinator.discardInterruptedGeneration()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let info = generationCoordinator.getInterruptedGenerationInfo() {
                Text("A previous generation for \"\(info.title)\" was interrupted. Would you like to resume?")
            } else {
                Text("A previous generation was interrupted. Would you like to resume?")
            }
        }
        .onAppear {
            checkForInterruptedGeneration()
        }
    }

    // MARK: - Extracted Form Sections

    @ViewBuilder
    private var summaryDepthSection: some View {
        Section("Summary Depth") {
            Picker("Depth", selection: $selectedSummaryType) {
                ForEach(SummaryType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }

            Text(summaryTypeDescription)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Image(systemName: "text.word.spacing")
                    .foregroundStyle(.secondary)
                Text("Target: \(selectedGovernor.baseWordCount)–\(selectedGovernor.maxWordCeiling) words")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var audioEstimateSection: some View {
        if KeychainService.shared.hasElevenLabsApiKey {
            Section {
                HStack(spacing: 8) {
                    Image(systemName: "headphones")
                        .foregroundStyle(.secondary)
                    Text("Estimated audio length: ~\(estimatedAudioMinutes) minutes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var voiceSelectionSection: some View {
        if KeychainService.shared.hasElevenLabsApiKey {
            Section("Narrator Voice") {
                Button {
                    showingVoicePicker = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedVoiceName)
                                .foregroundStyle(.primary)
                            if let voice = ElevenLabsVoiceRegistry.voice(byVoiceID: selectedVoiceID) {
                                Text(voice.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showingVoicePicker) {
                VoicePickerView(
                    profile: .practitioner,
                    selectedVoiceID: $selectedVoiceID
                )
            }
        }
    }

    private var selectedVoiceName: String {
        ElevenLabsVoiceRegistry.voice(byVoiceID: selectedVoiceID)?.name ?? "Rachel"
    }

    @ViewBuilder
    private var generateButtonSection: some View {
        Section {
            Button {
                startGeneration()
            } label: {
                HStack {
                    Spacer()
                    Label("Generate Insight Atlas Guide", systemImage: "wand.and.stars")
                        .fontWeight(.semibold)
                    Spacer()
                }
            }
            .disabled(!dataManager.hasValidApiKeys)
        } footer: {
            if !dataManager.hasValidApiKeys {
                Text("Please configure your API keys in Settings to generate guides.")
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Generating View

    private var generatingView: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                ProgressView(value: generationCoordinator.progress.percentComplete)
                    .progressViewStyle(.circular)
                    .scaleEffect(2)

                VStack(spacing: 8) {
                    Text(generationCoordinator.progress.phase)
                        .font(.headline)

                    Text("\(generationCoordinator.progress.wordCount) words generated")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if !generationCoordinator.progress.model.isEmpty {
                        Text("Using \(generationCoordinator.progress.model)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            // Live preview of content being generated
            ScrollViewReader { proxy in
                ScrollView {
                    Text(generationCoordinator.progress.content)
                        .font(.system(.body, design: .serif))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id("content-bottom")
                }
                .onChange(of: generationCoordinator.progress.content) { _, _ in
                    // Auto-scroll to bottom as content streams in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("content-bottom", anchor: .bottom)
                    }
                }
            }
            .frame(maxHeight: 300)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding()

            // Cancel button
            Button(role: .destructive) {
                generationCoordinator.cancelGeneration()
                isGenerating = false
            } label: {
                Text("Cancel Generation")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .navigationTitle("Generating...")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Completed View

    private var completedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("Guide Generated!")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("\(wordCount) words")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                saveAndDismiss()
            } label: {
                Label("Save to Library", systemImage: "square.and.arrow.down")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
        }
        .navigationTitle("Complete")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Computed Properties

    private var modeDescription: String {
        switch selectedMode {
        case .standard:
            return "Comprehensive guide with practical insights and exercises."
        case .deepResearch:
            return "Extended analysis with academic citations, research references, and framework comparisons."
        }
    }

    private var toneDescription: String {
        switch selectedTone {
        case .professional:
            return "Clinical language suitable for professional contexts and therapist handouts."
        case .accessible:
            return "Warm, conversational tone with rhetorical questions and engaging transitions."
        }
    }

    private var formatDescription: String {
        switch selectedFormat {
        case .fullGuide:
            return "Complete guide with all sections, exercises, and appendices."
        case .thematicSynthesis:
            return "JSON-structured thematic analysis with 8-12 cross-book themes (8,000-12,000 words)."
        case .quickReference:
            return "One-page summary plus action boxes only."
        case .professionalEdition:
            return "Full guide with formal terminology for professional use."
        case .readerEdition:
            return "Full guide optimized for general readers."
        case .exerciseWorkbook:
            return "Exercises only, formatted for printing."
        case .visualSummary:
            return "Visual frameworks and diagrams only."
        }
    }

    /// Selected governor based on summary type
    private var selectedGovernor: SummaryTypeGovernor {
        SummaryTypeGovernor.governor(for: selectedSummaryType)
    }

    /// Estimated audio duration based on selected summary type governor
    private var estimatedAudioMinutes: Int {
        selectedGovernor.maxAudioMinutes
    }

    /// Description for the selected summary type
    private var summaryTypeDescription: String {
        switch selectedSummaryType {
        case .quickReference:
            return "Concise overview for quick review. Perfect for busy readers who need the essentials."
        case .professional:
            return "Balanced depth with practical insights. Ideal for most books and professional use."
        case .accessible:
            return "Comprehensive coverage with extended examples. Great for complex topics."
        case .deepResearch:
            return "Maximum depth with research references and framework analysis. For academic or specialized use."
        }
    }

    private var wordCount: Int {
        generatedContent.split(separator: " ").count
    }

    // MARK: - Methods

    private func startGeneration() {
        guard let data = bookData else {
            errorMessage = "No book data available"
            showingError = true
            return
        }

        isGenerating = true
        generatedContent = ""

        // Update settings with selected options
        var settings = dataManager.userSettings
        settings.preferredMode = selectedMode
        settings.preferredTone = selectedTone
        settings.preferredFormat = selectedFormat
        settings.preferredSummaryType = selectedSummaryType

        Task {
            do {
                // Use BackgroundGenerationCoordinator for background-safe generation
                let result = try await generationCoordinator.startGeneration(
                    bookData: data,
                    fileType: fileType,
                    title: title,
                    author: author,
                    settings: settings,
                    existingItemId: existingItem?.id,
                    summaryType: selectedSummaryType,
                    voiceID: selectedVoiceID
                )

                await MainActor.run {
                    generatedContent = result
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }

    private func saveAndDismiss() {
        // Extract metadata from generation result (includes audio metadata)
        var metadata: GenerationMetadata?
        if case .success(_, _, let meta) = generationCoordinator.lastResult {
            metadata = meta
        }

        // Check if audio was successfully generated
        let audioGenerated = metadata?.audioFileURL != nil

        if let existing = existingItem {
            // Update existing item with content and audio metadata
            dataManager.saveSummary(
                for: existing.id,
                content: generatedContent,
                metadata: metadata
            )
        } else {
            let itemID = UUID()
            let coverPath = coverImageData.flatMap { dataManager.storeCoverImageData($0, for: itemID) }
            let newItem = LibraryItem(
                id: itemID,
                title: title,
                author: author,
                fileType: fileType,
                summaryContent: generatedContent,
                provider: dataManager.userSettings.preferredProvider,
                mode: selectedMode,
                coverImagePath: coverPath,
                summaryType: metadata?.summaryType,
                governedWordCount: metadata?.governedWordCount,
                cutPolicyActivated: metadata?.cutPolicyActivated,
                cutEventCount: metadata?.cutEventCount,
                audioFileURL: metadata?.audioFileURL,
                audioVoiceID: metadata?.audioVoiceID,
                audioDuration: metadata?.audioDuration,
                audioGenerationAttempted: metadata != nil
            )
            dataManager.addLibraryItem(newItem)
        }

        // Show audio toast if audio was generated, then dismiss after delay
        if audioGenerated {
            showingAudioReadyToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                showingAudioReadyToast = false
                dismiss()
            }
        } else {
            dismiss()
        }
    }

    private func checkForInterruptedGeneration() {
        if generationCoordinator.hasInterruptedGeneration() {
            showingInterruptedAlert = true
        }
    }

    private func resumeInterruptedGeneration() {
        isGenerating = true

        Task {
            do {
                let result = try await generationCoordinator.resumeInterruptedGeneration(
                    settings: dataManager.userSettings
                )

                await MainActor.run {
                    generatedContent = result
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

#Preview {
    GenerationView(
        bookData: nil,
        fileType: .pdf,
        title: "The Four Agreements",
        author: "Don Miguel Ruiz"
    )
    .environmentObject(DataManager())
}
