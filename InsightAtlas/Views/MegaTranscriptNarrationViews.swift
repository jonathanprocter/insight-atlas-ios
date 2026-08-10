//
//  MegaTranscriptNarrationViews.swift
//  InsightAtlas
//

import SwiftUI

// MARK: - Developer and narrator settings

@MainActor
final class MegaTranscriptSettingsViewModel: ObservableObject {
    @Published var apiKeyDraft = ""
    @Published private(set) var isConfigured = false
    @Published private(set) var voices: [MegaTranscriptVoice] = []
    @Published private(set) var selectedVoiceID: Int?
    @Published private(set) var isLoadingVoices = false
    @Published private(set) var isPreviewing = false
    @Published private(set) var statusMessage: String?
    @Published var errorMessage: String?

    private let credentialStore: MegaTranscriptCredentialStore
    private let coordinator: MegaTranscriptNarrationCoordinator
    private let preferences: MegaTranscriptNarratorPreferences
    private let playback: NarrationPlaybackController

    init(
        credentialStore: MegaTranscriptCredentialStore = KeychainMegaTranscriptCredentialStore.shared,
        coordinator: MegaTranscriptNarrationCoordinator = .shared,
        preferences: MegaTranscriptNarratorPreferences = .shared,
        playback: NarrationPlaybackController? = nil
    ) {
        self.credentialStore = credentialStore
        self.coordinator = coordinator
        self.preferences = preferences
        self.playback = playback ?? .shared
        isConfigured = credentialStore.hasAPIKey
        selectedVoiceID = preferences.selectedVoiceID
    }

    var selectedVoice: MegaTranscriptVoice? {
        voices.first(where: { $0.id == selectedVoiceID })
    }

    func saveKey() {
        do {
            try credentialStore.saveAPIKey(apiKeyDraft)
            apiKeyDraft = ""
            isConfigured = true
            statusMessage = "API key configured"
            errorMessage = nil
            Task { await loadVoices() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteKey() {
        do {
            try credentialStore.deleteAPIKey()
            apiKeyDraft = ""
            isConfigured = false
            voices = []
            statusMessage = "API key deleted"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadVoices() async {
        guard isConfigured else { return }
        isLoadingVoices = true
        defer { isLoadingVoices = false }
        do {
            voices = try await coordinator.availableVoices()
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            selectedVoiceID = preferences.selectedVoice(from: voices)?.id
            statusMessage = "English voice catalog refreshed"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func select(_ voice: MegaTranscriptVoice) {
        preferences.select(voice)
        selectedVoiceID = voice.id
        statusMessage = "\(voice.name) selected"
    }

    func previewSelectedVoice() async {
        guard let voice = selectedVoice else {
            errorMessage = "Choose a narrator before generating a preview."
            return
        }
        isPreviewing = true
        defer { isPreviewing = false }
        do {
            let sample = "Insight Atlas turns a complex book into a clear intellectual map—preserving the author’s central argument, testing its limits, and guiding you toward one practical next step."
            let url = try await coordinator.preview(text: sample, voice: voice)
            try playback.play(
                url: url,
                title: "Narrator Preview",
                author: voice.name,
                coverImagePath: nil
            )
            statusMessage = "Playing \(voice.name) preview"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearCache() async {
        do {
            playback.stop()
            try await coordinator.clearCache()
            statusMessage = "Narration cache cleared"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct MegaTranscriptDeveloperSettingsView: View {
    @StateObject private var model = MegaTranscriptSettingsViewModel()

    var body: some View {
        List {
            Section {
                HStack {
                    Label(
                        model.isConfigured ? "API key configured" : "API key not configured",
                        systemImage: model.isConfigured ? "checkmark.shield.fill" : "exclamationmark.shield"
                    )
                    .foregroundStyle(model.isConfigured ? Color.green : Color.orange)
                    Spacer()
                }

                SecureField(
                    model.isConfigured ? "Paste replacement key" : "Paste regenerated API key",
                    text: $model.apiKeyDraft
                )
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel("Mega Transcript API key")

                Button(model.isConfigured ? "Replace Key" : "Save Key") {
                    model.saveKey()
                }
                .disabled(model.apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if model.isConfigured {
                    Button("Delete Key", role: .destructive) {
                        model.deleteKey()
                    }
                }
            } header: {
                Text("Developer Credential")
            } footer: {
                Text("Stored in this device’s Keychain as a development credential. The key is never displayed again, logged, or placed in the project. Regenerate the key that appeared in the screenshot before testing.")
            }

            Section {
                if !model.isConfigured {
                    ContentUnavailableView(
                        "Configure Mega Transcript",
                        systemImage: "waveform.badge.key",
                        description: Text("Save the regenerated key above to load the live English narrator catalog. Liam remains the fallback narrator.")
                    )
                } else if model.isLoadingVoices {
                    HStack {
                        ProgressView()
                        Text("Loading English voices…")
                    }
                } else if model.voices.isEmpty {
                    Button("Load English Voices") {
                        Task { await model.loadVoices() }
                    }
                } else {
                    ForEach(model.voices) { voice in
                        Button {
                            model.select(voice)
                        } label: {
                            MegaTranscriptVoiceRow(
                                voice: voice,
                                isSelected: voice.id == model.selectedVoiceID
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                HStack {
                    Text("Narrator")
                    Spacer()
                    if model.isConfigured {
                        Button {
                            Task { await model.loadVoices() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(model.isLoadingVoices)
                        .accessibilityLabel("Refresh narrator catalog")
                    }
                }
            } footer: {
                Text("Arthur is preferred on first use. If unavailable, the app selects Mia, then an emotion-aware English voice, then the first English voice. Your manual choice is revalidated against the live catalog.")
            }

            Section {
                Button {
                    Task { await model.previewSelectedVoice() }
                } label: {
                    HStack {
                        Label("Preview Selected Narrator", systemImage: "play.circle")
                        Spacer()
                        if model.isPreviewing { ProgressView() }
                    }
                }
                .disabled(model.selectedVoice == nil || model.isPreviewing)
            } footer: {
                Text("Preview generates a short sample and uses Mega Transcript API credits. It never runs automatically.")
            }

            Section("Fallback") {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Liam")
                        Text("Kokoro narration fallback")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: KokoroTTSClient.currentAPIKey() == nil ? "exclamationmark.circle" : "checkmark.circle.fill")
                        .foregroundStyle(KokoroTTSClient.currentAPIKey() == nil ? Color.orange : Color.green)
                }
            }

            Section {
                Button("Clear Narration Cache", role: .destructive) {
                    Task { await model.clearCache() }
                }
            } footer: {
                Text("Removes cached Mega Transcript WAV files. Existing book-level narration can still be deleted from its Listen control.")
            }

            if let statusMessage = model.statusMessage {
                Section {
                    Text(statusMessage)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Mega Transcript")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model.isConfigured && model.voices.isEmpty {
                await model.loadVoices()
            }
        }
        .alert(
            "Mega Transcript",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "An unknown error occurred.")
        }
    }
}

private struct MegaTranscriptVoiceRow: View {
    let voice: MegaTranscriptVoice
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? PremiumUI.gold : Color.secondary)

            VStack(alignment: .leading, spacing: 5) {
                Text(voice.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                HStack(spacing: 7) {
                    Text(voice.gender.capitalized)
                    Text(voice.provider)
                    if voice.emotionAware {
                        Text("Emotion aware")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(PremiumUI.gold.opacity(0.16), in: Capsule())
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(voice.name), \(voice.gender), \(voice.provider)\(voice.emotionAware ? ", emotion aware" : "")")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

// MARK: - Summary-screen narration controls

@MainActor
final class NarrationControlViewModel: ObservableObject {
    @Published private(set) var progress: NarrationPreparationProgress?
    @Published private(set) var isPreparing = false
    @Published private(set) var fallbackMessage: String?
    @Published var errorMessage: String?
    @Published private(set) var canRetry = false

    private var generationTask: Task<Void, Never>?

    var progressLabel: String {
        switch progress {
        case .checkingCache: return "Checking narration cache…"
        case .fetchingVoices: return "Selecting narrator…"
        case .generating(let narrator): return "Preparing narration with \(narrator)…"
        case .downloading: return "Downloading narration…"
        case .usingCache: return "Opening cached narration…"
        case .fallingBackToLiam: return "Preparing Liam fallback…"
        case .ready(let narrator): return "Ready with \(narrator)"
        case nil: return "Preparing narration…"
        }
    }

    func generate(item: LibraryItem) {
        guard generationTask == nil, let summary = item.summaryContent, !summary.isEmpty else { return }
        isPreparing = true
        errorMessage = nil
        fallbackMessage = nil
        canRetry = false
        DataManager.shared.setNarrationState(.generating, for: item.id)

        generationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let asset = try await NarrationService.shared.synthesize(
                    text: summary,
                    itemId: item.id
                ) { [weak self] update in
                    Task { @MainActor in
                        self?.progress = update
                        if case .fallingBackToLiam(let reason) = update {
                            self?.fallbackMessage = reason
                        }
                    }
                }
                if Task.isCancelled { throw MegaTranscriptError.cancelled }

                DataManager.shared.applyNarration(asset, for: item.id)
                isPreparing = false
                generationTask = nil
                progress = .ready(narrator: narratorName(for: asset.voiceID))
                if let url = Self.audioURL(for: asset.relativeFileName) {
                    try NarrationPlaybackController.shared.play(
                        url: url,
                        title: item.title,
                        author: item.author,
                        coverImagePath: item.coverImagePath
                    )
                }
            } catch MegaTranscriptError.cancelled {
                isPreparing = false
                generationTask = nil
                progress = nil
                DataManager.shared.setNarrationState(.notGenerated, for: item.id)
            } catch is CancellationError {
                isPreparing = false
                generationTask = nil
                progress = nil
                DataManager.shared.setNarrationState(.notGenerated, for: item.id)
            } catch {
                isPreparing = false
                generationTask = nil
                DataManager.shared.markNarrationFailed(for: item.id)
                errorMessage = error.localizedDescription
                canRetry = !(error is NarrationServiceError && KokoroTTSClient.currentAPIKey() == nil)
            }
        }
    }

    func cancel() {
        generationTask?.cancel()
    }

    func deleteNarration(item: LibraryItem) {
        NarrationPlaybackController.shared.stop()
        if let filename = item.audioFileURL, let url = Self.audioURL(for: filename) {
            try? FileManager.default.removeItem(at: url)
        }
        Task {
            if let summary = item.summaryContent {
                try? await MegaTranscriptNarrationCoordinator.shared.removeCachedNarration(
                    text: summary,
                    audioVoiceID: item.audioVoiceID,
                    itemID: item.id
                )
            }
            var updated = item
            updated.audioFileURL = nil
            updated.audioVoiceID = nil
            updated.audioDuration = nil
            updated.audioGenerationAttempts = 0
            updated.narrationState = .notGenerated
            DataManager.shared.updateLibraryItem(updated)
        }
    }

    func play(item: LibraryItem) {
        guard let filename = item.audioFileURL, let url = Self.audioURL(for: filename) else {
            errorMessage = "The local narration file is missing. Generate it again."
            canRetry = true
            return
        }
        do {
            if NarrationPlaybackController.shared.currentURL == url {
                NarrationPlaybackController.shared.toggle()
            } else {
                try NarrationPlaybackController.shared.play(
                    url: url,
                    title: item.title,
                    author: item.author,
                    coverImagePath: item.coverImagePath
                )
            }
        } catch {
            errorMessage = "Audio playback failed: \(error.localizedDescription)"
        }
    }

    func narratorName(for voiceID: String?) -> String {
        guard let voiceID else { return "Narrator" }
        if voiceID.hasPrefix("megatranscript:") {
            return MegaTranscriptNarrationCoordinator.megaVoiceName(from: voiceID)
                ?? MegaTranscriptNarratorPreferences.shared.selectedVoiceName
                ?? "Mega Transcript"
        }
        if voiceID == KokoroTTSClient.voice { return "Liam" }
        return voiceID
    }

    static func audioURL(for filename: String) -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(filename)
    }
}

struct NarrationControlsView: View {
    let item: LibraryItem

    @EnvironmentObject private var dataManager: DataManager
    @StateObject private var model = NarrationControlViewModel()
    @ObservedObject private var playback = NarrationPlaybackController.shared
    @State private var showingSettings = false

    private let speeds: [Float] = [0.75, 1, 1.25, 1.5, 2]

    private var currentItem: LibraryItem {
        dataManager.libraryItems.first(where: { $0.id == item.id }) ?? item
    }

    private var hasAudio: Bool {
        guard let filename = currentItem.audioFileURL,
              let url = NarrationControlViewModel.audioURL(for: filename) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    private var megaConfigured: Bool {
        KeychainMegaTranscriptCredentialStore.shared.hasAPIKey
    }

    private var liamConfigured: Bool {
        KokoroTTSClient.currentAPIKey() != nil
    }

    private var selectedMegaVoiceDiffersFromAudio: Bool {
        guard let storedID = MegaTranscriptNarrationCoordinator.megaVoiceID(
            from: currentItem.audioVoiceID
        ), let selectedID = MegaTranscriptNarratorPreferences.shared.selectedVoiceID else {
            return false
        }
        return storedID != selectedID
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "headphones")
                    .font(.title3)
                    .foregroundStyle(PremiumUI.gold)
                    .frame(width: 42, height: 42)
                    .background(PremiumUI.gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Listen")
                        .font(.headline)
                    Text(hasAudio ? model.narratorName(for: currentItem.audioVoiceID) : readySubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Menu {
                    Button("Narrator Settings", systemImage: "person.wave.2") {
                        showingSettings = true
                    }
                    if hasAudio {
                        Button("Delete Narration", systemImage: "trash", role: .destructive) {
                            model.deleteNarration(item: currentItem)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Narration options")
            }

            if model.isPreparing {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(model.progressLabel)
                        .font(.subheadline)
                    Spacer()
                    Button("Cancel") { model.cancel() }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(model.progressLabel)
            } else if hasAudio {
                playbackControls
            } else if !megaConfigured && !liamConfigured {
                HStack {
                    Text("Configure Arthur or Liam before listening.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Settings") { showingSettings = true }
                }
            } else {
                Button {
                    model.generate(item: currentItem)
                } label: {
                    Label(listenButtonTitle, systemImage: "speaker.wave.2.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(PremiumUI.slate)
                .accessibilityLabel(listenButtonTitle)
            }

            if let fallbackMessage = model.fallbackMessage {
                Text(fallbackMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error = model.errorMessage {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                    Spacer()
                    if model.canRetry {
                        Button("Retry") { model.generate(item: currentItem) }
                            .font(.caption.weight(.semibold))
                    }
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(PremiumUI.divider, lineWidth: 0.8)
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                MegaTranscriptDeveloperSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showingSettings = false }
                        }
                    }
            }
        }
    }

    private var readySubtitle: String {
        if megaConfigured {
            return "\(MegaTranscriptNarratorPreferences.shared.selectedVoiceName ?? "Arthur") preferred · Liam fallback"
        }
        return "Liam fallback"
    }

    private var listenButtonTitle: String {
        megaConfigured
            ? "Listen with \(MegaTranscriptNarratorPreferences.shared.selectedVoiceName ?? "Arthur")"
            : "Listen with Liam"
    }

    private var playbackControls: some View {
        VStack(spacing: 8) {
            Slider(
                value: Binding(
                    get: { min(playback.currentTime, max(playback.duration, 0)) },
                    set: { playback.seek(to: $0) }
                ),
                in: 0...max(max(playback.duration, currentItem.audioDuration ?? 1), 1)
            )
            .tint(PremiumUI.gold)
            .accessibilityLabel("Narration position")
            .accessibilityValue("\(timeLabel(playback.currentTime)) of \(timeLabel(max(playback.duration, currentItem.audioDuration ?? 0)))")

            HStack {
                Text(timeLabel(playback.currentTime))
                Spacer()
                Text(timeLabel(max(playback.duration, currentItem.audioDuration ?? 0)))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)

            HStack {
                Menu {
                    ForEach(speeds, id: \.self) { speed in
                        Button(speedLabel(speed)) { playback.setRate(speed) }
                    }
                } label: {
                    Text(speedLabel(playback.playbackRate))
                        .font(.subheadline.weight(.semibold))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Playback speed")
                .accessibilityValue(speedLabel(playback.playbackRate))

                Spacer()

                Button {
                    model.play(item: currentItem)
                } label: {
                    Label(
                        playback.isPlaying ? "Pause" : "Resume",
                        systemImage: playback.isPlaying ? "pause.fill" : "play.fill"
                    )
                    .frame(minWidth: 100, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(PremiumUI.slate)
                .accessibilityLabel(playback.isPlaying ? "Pause narration" : "Resume narration")
            }

            if selectedMegaVoiceDiffersFromAudio {
                Button {
                    model.generate(item: currentItem)
                } label: {
                    Label(
                        "Generate with \(MegaTranscriptNarratorPreferences.shared.selectedVoiceName ?? "selected narrator")",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                }
                .font(.caption.weight(.semibold))
                .accessibilityHint("Generates new narration and may use API credits")
            }
        }
    }

    private func speedLabel(_ rate: Float) -> String {
        "\(String(format: "%g", rate))×"
    }

    private func timeLabel(_ time: TimeInterval) -> String {
        guard time.isFinite, time >= 0 else { return "0:00" }
        let total = Int(time)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
