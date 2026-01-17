import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var environment: AppEnvironment

    private var selectedVoiceName: String {
        guard let voiceID = environment.userSettings.selectedVoiceID else {
            return "Default"
        }

        switch environment.userSettings.voiceProvider {
        case .openai:
            return OpenAIVoiceRegistry.voice(byID: voiceID)?.name ?? "Alloy"
        case .elevenlabs:
            return ElevenLabsVoiceRegistry.voice(byVoiceID: voiceID)?.name ?? "Default"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // API Keys Section
                Section {
                    SecureFieldRow(
                        label: "Claude",
                        placeholder: "API Key",
                        text: Binding(
                            get: { KeychainService.shared.claudeApiKey ?? "" },
                            set: { environment.updateClaudeApiKey($0.isEmpty ? nil : $0) }
                        ),
                        hasValue: KeychainService.shared.hasClaudeApiKey
                    )

                    SecureFieldRow(
                        label: "OpenAI",
                        placeholder: "API Key",
                        text: Binding(
                            get: { KeychainService.shared.openaiApiKey ?? "" },
                            set: { environment.updateOpenAIApiKey($0.isEmpty ? nil : $0) }
                        ),
                        hasValue: KeychainService.shared.hasOpenAIApiKey
                    )

                    Picker("Provider", selection: $environment.userSettings.preferredProvider) {
                        ForEach(AIProvider.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .onChange(of: environment.userSettings.preferredProvider) {
                        environment.saveSettings()
                    }
                } header: {
                    Text("AI Provider")
                } footer: {
                    Text("API keys are stored securely and never leave your device")
                }

                Section {
                    Picker("Analysis Depth", selection: $environment.userSettings.preferredMode) {
                        ForEach(GenerationMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .onChange(of: environment.userSettings.preferredMode) {
                        environment.saveSettings()
                    }

                    Picker("Writing Style", selection: $environment.userSettings.preferredTone) {
                        ForEach(ToneMode.allCases, id: \.self) { tone in
                            Text(tone.displayName).tag(tone)
                        }
                    }
                    .onChange(of: environment.userSettings.preferredTone) {
                        environment.saveSettings()
                    }

                    Picker("Output Format", selection: $environment.userSettings.preferredFormat) {
                        ForEach(OutputFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .onChange(of: environment.userSettings.preferredFormat) {
                        environment.saveSettings()
                    }

                    Text(environment.userSettings.preferredFormat.description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Picker("Summary Length", selection: $environment.userSettings.preferredSummaryType) {
                        ForEach(SummaryType.allCases, id: \.self) { summaryType in
                            Text(summaryType.displayName).tag(summaryType)
                        }
                    }
                    .onChange(of: environment.userSettings.preferredSummaryType) {
                        environment.saveSettings()
                    }
                } header: {
                    Text("Guide Defaults")
                } footer: {
                    Text("Used for new guides and can be adjusted per generation")
                }

                // Audio Section
                Section {
                    // Voice Provider Selection
                    Picker("Voice Provider", selection: $environment.userSettings.voiceProvider) {
                        ForEach(VoiceProvider.allCases, id: \.self) { provider in
                            HStack {
                                Text(provider.displayName)
                                if provider == .openai {
                                    Text("(Default)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tag(provider)
                        }
                    }
                    .onChange(of: environment.userSettings.voiceProvider) {
                        environment.updateVoiceProvider(environment.userSettings.voiceProvider)
                        // Reset voice selection when changing providers
                        if environment.userSettings.voiceProvider == .openai {
                            environment.userSettings.selectedVoiceID = "alloy"
                        } else {
                            environment.userSettings.selectedVoiceID = ElevenLabsVoiceRegistry.adam.voiceID
                        }
                        environment.saveSettings()
                    }

                    // Show ElevenLabs API key only when ElevenLabs is selected
                    if environment.userSettings.voiceProvider == .elevenlabs {
                        SecureFieldRow(
                            label: "ElevenLabs API Key",
                            placeholder: "Required for ElevenLabs",
                            text: Binding(
                                get: { KeychainService.shared.elevenLabsApiKey ?? "" },
                                set: { KeychainService.shared.elevenLabsApiKey = $0.isEmpty ? nil : $0 }
                            ),
                            hasValue: KeychainService.shared.hasElevenLabsApiKey
                        )

                        if !KeychainService.shared.hasElevenLabsApiKey {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("ElevenLabs API key required")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // OpenAI info when OpenAI voice is selected
                    if environment.userSettings.voiceProvider == .openai {
                        if KeychainService.shared.hasOpenAIApiKey {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Uses your OpenAI API key")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("OpenAI API key required above")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Toggle("Auto-generate audio", isOn: $environment.userSettings.autoGenerateAudio)

                    // Voice Selection
                    NavigationLink {
                        VoiceSelectionSettingsView()
                            .environmentObject(environment)
                    } label: {
                        HStack {
                            Text("Voice")
                            Spacer()
                            Text(selectedVoiceName)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Playback Speed
                    Picker("Playback Speed", selection: $environment.userSettings.playbackSpeed) {
                        ForEach(PlaybackSpeed.allCases, id: \.self) { speed in
                            Text(speed.displayName).tag(speed)
                        }
                    }
                } header: {
                    Text("Audio")
                } footer: {
                    if environment.userSettings.voiceProvider == .openai {
                        Text("OpenAI TTS uses your existing OpenAI API key for high-quality voice narration")
                    } else {
                        Text("ElevenLabs offers premium voices with advanced customization")
                    }
                }

                // About Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text("2025.1")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .tint(AnalysisTheme.brandOrange)
        }
    }
}

// MARK: - Voice Selection Settings View

struct VoiceSelectionSettingsView: View {
    @EnvironmentObject var environment: AppEnvironment
    @State private var previewingVoiceID: String?
    @State private var isLoadingPreview = false

    var body: some View {
        List {
            if environment.userSettings.voiceProvider == .openai {
                // OpenAI Voices
                Section {
                    ForEach(OpenAIVoiceRegistry.allVoices) { voice in
                        OpenAIVoiceRow(
                            voice: voice,
                            isSelected: environment.userSettings.selectedVoiceID == voice.voiceID,
                            isPreviewing: previewingVoiceID == voice.voiceID,
                            isLoading: previewingVoiceID == voice.voiceID && isLoadingPreview,
                            onSelect: { selectOpenAIVoice(voice) },
                            onPreview: { previewOpenAIVoice(voice) }
                        )
                    }
                } header: {
                    Text("OpenAI Voices")
                } footer: {
                    Text("Tap to select, tap play to preview")
                }
            } else {
                // ElevenLabs Voices
                Section {
                    ForEach(ElevenLabsVoiceRegistry.allVoices) { voice in
                        SettingsVoiceRow(
                            voice: voice,
                            isSelected: environment.userSettings.selectedVoiceID == voice.voiceID,
                            isPreviewing: previewingVoiceID == voice.voiceID,
                            isLoading: previewingVoiceID == voice.voiceID && isLoadingPreview,
                            onSelect: { selectElevenLabsVoice(voice) },
                            onPreview: { previewElevenLabsVoice(voice) }
                        )
                    }
                } header: {
                    Text("ElevenLabs Voices")
                } footer: {
                    Text("Tap to select, tap play to preview")
                }
            }
        }
        .navigationTitle("Voice Selection")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - OpenAI Voice Selection

    private func selectOpenAIVoice(_ voice: OpenAIVoice) {
        environment.userSettings.selectedVoiceID = voice.voiceID
        environment.saveSettings()
    }

    private func previewOpenAIVoice(_ voice: OpenAIVoice) {
        guard !isLoadingPreview else { return }

        // Stop any current preview
        if previewingVoiceID == voice.voiceID {
            AudioPlaybackManager.shared.stop()
            previewingVoiceID = nil
            return
        }

        previewingVoiceID = voice.voiceID
        isLoadingPreview = true

        Task {
            do {
                let sampleText = "Hello, I'm \(voice.name). I'll be narrating your book summaries with clarity and warmth."
                let audio = try await environment.openAIAudioService.generateAudio(
                    text: sampleText,
                    voiceID: voice.voiceID
                )

                await MainActor.run {
                    isLoadingPreview = false
                    try? AudioPlaybackManager.shared.play(audio) {
                        previewingVoiceID = nil
                    }
                }
            } catch {
                await MainActor.run {
                    isLoadingPreview = false
                    previewingVoiceID = nil
                }
            }
        }
    }

    // MARK: - ElevenLabs Voice Selection

    private func selectElevenLabsVoice(_ voice: ElevenLabsVoice) {
        environment.userSettings.selectedVoiceID = voice.voiceID
        environment.saveSettings()
    }

    private func previewElevenLabsVoice(_ voice: ElevenLabsVoice) {
        guard !isLoadingPreview else { return }

        // Stop any current preview
        if previewingVoiceID == voice.voiceID {
            AudioPlaybackManager.shared.stop()
            previewingVoiceID = nil
            return
        }

        previewingVoiceID = voice.voiceID
        isLoadingPreview = true

        Task {
            do {
                let sampleText = "Hello, I'm \(voice.name). I'll be narrating your book summaries with clarity and warmth."
                let audio = try await environment.audioService.generateAudio(
                    text: sampleText,
                    voiceID: voice.voiceID
                )

                await MainActor.run {
                    isLoadingPreview = false
                    try? AudioPlaybackManager.shared.play(audio) {
                        previewingVoiceID = nil
                    }
                }
            } catch {
                await MainActor.run {
                    isLoadingPreview = false
                    previewingVoiceID = nil
                }
            }
        }
    }
}

// MARK: - OpenAI Voice Row

struct OpenAIVoiceRow: View {
    let voice: OpenAIVoice
    let isSelected: Bool
    let isPreviewing: Bool
    let isLoading: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Voice info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(voice.name)
                            .font(.body)
                            .fontWeight(.medium)

                        // Gender indicator
                        Text(voice.characteristics.gender.rawValue.capitalized)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .foregroundColor(.secondary)
                            .cornerRadius(4)
                    }

                    Text(voice.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Preview button
                Button(action: onPreview) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: isPreviewing ? "stop.circle.fill" : "play.circle.fill")
                            .font(.title2)
                            .foregroundColor(isPreviewing ? .red : AnalysisTheme.brandOrange)
                    }
                }
                .buttonStyle(.plain)

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(AnalysisTheme.accentSuccess)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings Voice Row (ElevenLabs)

struct SettingsVoiceRow: View {
    let voice: ElevenLabsVoice
    let isSelected: Bool
    let isPreviewing: Bool
    let isLoading: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Voice info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(voice.name)
                            .font(.body)
                            .fontWeight(.medium)

                        if voice.isPremium {
                            Text("PREMIUM")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AnalysisTheme.primaryGold.opacity(0.2))
                                .foregroundColor(AnalysisTheme.primaryGoldText)
                                .cornerRadius(4)
                        }
                    }

                    Text(voice.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Preview button
                Button(action: onPreview) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: isPreviewing ? "stop.circle.fill" : "play.circle.fill")
                            .font(.title2)
                            .foregroundColor(isPreviewing ? .red : AnalysisTheme.brandOrange)
                    }
                }
                .buttonStyle(.plain)

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(AnalysisTheme.accentSuccess)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Clean Secure Field Row

struct SecureFieldRow: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let hasValue: Bool

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(label)
                        .fontWeight(.medium)

                    if hasValue {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(AnalysisTheme.brandOrange)
                    }
                }

                if isVisible {
                    TextField(placeholder, text: $text)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } else {
                    SecureField(placeholder, text: $text)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
            }

            Button {
                isVisible.toggle()
            } label: {
                Image(systemName: isVisible ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
                    .font(.body)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview("Settings") {
    NavigationStack {
        SettingsView()
            .environmentObject(AppEnvironment.shared)
    }
}
