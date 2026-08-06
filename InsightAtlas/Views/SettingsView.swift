import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    @AppStorage(PremiumUI.themeStorageKey) private var themePreference = PremiumTheme.system.rawValue
    @AppStorage(PremiumUI.accentStorageKey) private var accentPreference = PremiumAccent.gold.rawValue

    @State private var searchText = ""

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

    private var accentColor: Color {
        PremiumUI.accent(from: accentPreference)
    }

    private var versionText: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    Text("Settings")
                        .font(PremiumUI.display(34, .bold))
                        .foregroundStyle(PremiumUI.ink)

                    PremiumSearchField(
                        text: $searchText,
                        placeholder: "Search settings"
                    )

                    if matches(["generation", "ai provider", "generation mode", "tone", "format", "summary"]) {
                        PremiumSettingsCard(
                            title: "GENERATION",
                            icon: "brain.head.profile",
                            accentColor: accentColor
                        ) {
                            PremiumSettingsNavigationRow(
                                title: "AI Provider",
                                value: environment.userSettings.preferredProvider.displayName
                            ) {
                                AIProviderSettingsView()
                            }

                            PremiumSettingsDivider()

                            PremiumSettingsNavigationRow(
                                title: "Generation Mode",
                                value: environment.userSettings.preferredMode.displayName
                            ) {
                                GenerationModeSettingsView()
                            }

                            PremiumSettingsDivider()

                            PremiumSettingsNavigationRow(
                                title: "Output Tone",
                                value: environment.userSettings.preferredTone.displayName
                            ) {
                                OutputToneSettingsView()
                            }

                            PremiumSettingsDivider()

                            PremiumSettingsNavigationRow(
                                title: "Default Format",
                                value: environment.userSettings.preferredFormat.displayName
                            ) {
                                DefaultFormatSettingsView()
                            }
                        }
                    }

                    if matches(["api", "configuration", "keys", "claude", "openai"]) {
                        PremiumSettingsCard(
                            title: "API CONFIGURATION",
                            icon: "lock.fill",
                            accentColor: accentColor
                        ) {
                            PremiumSettingsNavigationRow(
                                title: "Manage API Keys",
                                value: apiConfigurationStatus
                            ) {
                                APIConfigurationView()
                            }
                        }
                    }

                    if matches(["audio", "voice", "narration", "playback", "elevenlabs"]) {
                        PremiumSettingsCard(
                            title: "AUDIO & NARRATION",
                            icon: "waveform",
                            accentColor: accentColor
                        ) {
                            PremiumSettingsNavigationRow(
                                title: "Audio Settings",
                                value: selectedVoiceName
                            ) {
                                AudioSettingsView()
                            }

                            PremiumSettingsDivider()

                            PremiumSettingsToggleRow(
                                title: "Auto-generate Audio",
                                isOn: $environment.userSettings.autoGenerateAudio,
                                accentColor: accentColor
                            )
                            .onChange(of: environment.userSettings.autoGenerateAudio) {
                                environment.saveSettings()
                            }
                        }
                    }

                    if matches(["appearance", "theme", "light", "dark", "system", "accent", "color"]) {
                        PremiumSettingsCard(
                            title: "APPEARANCE",
                            icon: "paintpalette.fill",
                            accentColor: accentColor
                        ) {
                            PremiumSettingsNavigationRow(
                                title: "Theme",
                                value: themePreference
                            ) {
                                ThemeSettingsView()
                            }

                            PremiumSettingsDivider()

                            PremiumSettingsNavigationRow(
                                title: "Accent Color",
                                value: accentPreference
                            ) {
                                AccentColorSettingsView()
                            }
                        }
                    }

                    if matches(["about", "support", "version", "help", "tutorials", "privacy"]) {
                        PremiumSettingsCard(
                            title: "ABOUT & SUPPORT",
                            icon: "info.circle.fill",
                            accentColor: accentColor
                        ) {
                            PremiumSettingsInfoRow(
                                title: "Version",
                                value: versionText
                            )

                            PremiumSettingsDivider()

                            PremiumSettingsNavigationRow(title: "Help & Tutorials") {
                                HelpTutorialsView()
                            }

                            PremiumSettingsDivider()

                            PremiumSettingsNavigationRow(title: "Privacy Policy") {
                                PrivacyPolicySettingsView()
                            }
                        }
                    }

                    if !searchText.isEmpty && noSectionMatches {
                        ContentUnavailableView.search(text: searchText)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 44)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(PremiumUI.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .tint(accentColor)
        }
    }

    private var apiConfigurationStatus: String {
        let configuredCount = [
            KeychainService.shared.hasClaudeApiKey,
            KeychainService.shared.hasOpenAIApiKey
        ].filter { $0 }.count

        switch configuredCount {
        case 0: return "Not Configured"
        case 1: return "1 Configured"
        default: return "Configured"
        }
    }

    private var noSectionMatches: Bool {
        !matches(["generation", "ai provider", "generation mode", "tone", "format", "summary"]) &&
        !matches(["api", "configuration", "keys", "claude", "openai"]) &&
        !matches(["audio", "voice", "narration", "playback", "elevenlabs"]) &&
        !matches(["appearance", "theme", "light", "dark", "system", "accent", "color"]) &&
        !matches(["about", "support", "version", "help", "tutorials", "privacy"])
    }

    private func matches(_ terms: [String]) -> Bool {
        guard !searchText.isEmpty else { return true }
        return terms.contains { $0.localizedCaseInsensitiveContains(searchText) }
    }
}

struct PremiumSettingsCard<Content: View>: View {
    let title: String
    let icon: String
    let accentColor: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(accentColor)

                Text(title)
                    .font(PremiumUI.ui(13, .bold))
                    .foregroundStyle(PremiumUI.ink)
                    .tracking(0.2)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 4)

            content
        }
        .background(PremiumUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(
                topLeadingRadius: 13,
                bottomLeadingRadius: 13,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            )
            .fill(accentColor)
            .frame(width: 6)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(accentColor.opacity(0.8), lineWidth: 0.8)
        }
        .shadow(color: PremiumUI.cardShadow.opacity(0.55), radius: 5, x: 0, y: 2)
    }
}

struct PremiumSettingsNavigationRow<Destination: View>: View {
    let title: String
    var value: String?
    @ViewBuilder let destination: Destination

    init(
        title: String,
        value: String? = nil,
        @ViewBuilder destination: () -> Destination
    ) {
        self.title = title
        self.value = value
        self.destination = destination()
    }

    var body: some View {
        NavigationLink {
            destination
                .toolbar(.visible, for: .navigationBar)
        } label: {
            HStack(spacing: 10) {
                Text(title)
                    .font(PremiumUI.ui(16, .medium))
                    .foregroundStyle(PremiumUI.ink)

                Spacer(minLength: 8)

                if let value {
                    Text(value)
                        .font(PremiumUI.ui(13))
                        .foregroundStyle(PremiumUI.secondaryText)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PremiumUI.secondaryText.opacity(0.7))
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 42)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct PremiumSettingsInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(PremiumUI.ui(16, .medium))
                .foregroundStyle(PremiumUI.ink)

            Spacer()

            Text(value)
                .font(PremiumUI.ui(14))
                .foregroundStyle(PremiumUI.secondaryText)
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 42)
    }
}

struct PremiumSettingsToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    let accentColor: Color

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(PremiumUI.ui(16, .medium))
                .foregroundStyle(PremiumUI.ink)
        }
        .tint(accentColor)
        .padding(.horizontal, 18)
        .frame(minHeight: 48)
    }
}

struct PremiumSettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(PremiumUI.divider)
            .frame(height: 0.7)
            .padding(.leading, 18)
    }
}

// MARK: - Generation Settings

struct AIProviderSettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        PremiumChoiceList(
            title: "AI Provider",
            footer: "Choose the provider used by default for new guides.",
            choices: AIProvider.allCases.map {
                PremiumChoice(id: $0.rawValue, title: $0.displayName)
            },
            selectedID: environment.userSettings.preferredProvider.rawValue
        ) { id in
            guard let provider = AIProvider(rawValue: id) else { return }
            environment.userSettings.preferredProvider = provider
            environment.saveSettings()
        }
    }
}

struct GenerationModeSettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        PremiumChoiceList(
            title: "Generation Mode",
            footer: "Deep Research creates a longer, more thoroughly sourced guide.",
            choices: GenerationMode.allCases.map {
                PremiumChoice(id: $0.rawValue, title: $0.displayName)
            },
            selectedID: environment.userSettings.preferredMode.rawValue
        ) { id in
            guard let mode = GenerationMode(rawValue: id) else { return }
            environment.userSettings.preferredMode = mode
            environment.saveSettings()
        }
    }
}

struct OutputToneSettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        PremiumChoiceList(
            title: "Output Tone",
            footer: "This controls the default language style used in generated guides.",
            choices: ToneMode.allCases.map {
                PremiumChoice(id: $0.rawValue, title: $0.displayName)
            },
            selectedID: environment.userSettings.preferredTone.rawValue
        ) { id in
            guard let tone = ToneMode(rawValue: id) else { return }
            environment.userSettings.preferredTone = tone
            environment.saveSettings()
        }
    }
}

struct DefaultFormatSettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        List {
            Section("Output Format") {
                ForEach(OutputFormat.allCases, id: \.self) { format in
                    Button {
                        environment.userSettings.preferredFormat = format
                        environment.saveSettings()
                        PremiumHaptics.selection()
                    } label: {
                        PremiumChoiceRow(
                            title: format.displayName,
                            subtitle: format.description,
                            isSelected: environment.userSettings.preferredFormat == format
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(PremiumUI.card)
                }
            }

            Section("Summary Length") {
                ForEach(SummaryType.allCases, id: \.self) { summaryType in
                    Button {
                        environment.userSettings.preferredSummaryType = summaryType
                        environment.saveSettings()
                        PremiumHaptics.selection()
                    } label: {
                        PremiumChoiceRow(
                            title: summaryType.displayName,
                            isSelected: environment.userSettings.preferredSummaryType == summaryType
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(PremiumUI.card)
                }
            }
        }
        .premiumSettingsList(title: "Default Format")
    }
}

struct PremiumChoice: Identifiable {
    let id: String
    let title: String
    var subtitle: String?
}

struct PremiumChoiceList: View {
    let title: String
    let footer: String
    let choices: [PremiumChoice]
    let selectedID: String
    let onSelect: (String) -> Void

    var body: some View {
        List {
            Section {
                ForEach(choices) { choice in
                    Button {
                        onSelect(choice.id)
                        PremiumHaptics.selection()
                    } label: {
                        PremiumChoiceRow(
                            title: choice.title,
                            subtitle: choice.subtitle,
                            isSelected: selectedID == choice.id
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(PremiumUI.card)
                }
            } footer: {
                Text(footer)
            }
        }
        .premiumSettingsList(title: title)
    }
}

struct PremiumChoiceRow: View {
    let title: String
    var subtitle: String?
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(PremiumUI.ui(16, .medium))
                    .foregroundStyle(PremiumUI.ink)

                if let subtitle {
                    Text(subtitle)
                        .font(PremiumUI.ui(13))
                        .foregroundStyle(PremiumUI.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 19))
                    .foregroundStyle(PremiumUI.gold)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - API Configuration

struct APIConfigurationView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @ObservedObject private var chatgpt = ChatGPTOAuthService.shared
    @AppStorage("insight_atlas_use_chatgpt_oauth") private var useChatGPTOAuth = false
    @State private var showChatGPTSignIn = false

    var body: some View {
        List {
            Section {
                SecureFieldRow(
                    label: "Claude",
                    placeholder: "Anthropic API Key",
                    text: Binding(
                        get: { KeychainService.shared.claudeApiKey ?? "" },
                        set: { environment.updateClaudeApiKey($0.isEmpty ? nil : $0) }
                    ),
                    hasValue: KeychainService.shared.hasClaudeApiKey
                )
                .listRowBackground(PremiumUI.card)

                SecureFieldRow(
                    label: "OpenAI",
                    placeholder: "OpenAI API Key",
                    text: Binding(
                        get: { KeychainService.shared.openaiApiKey ?? "" },
                        set: { environment.updateOpenAIApiKey($0.isEmpty ? nil : $0) }
                    ),
                    hasValue: KeychainService.shared.hasOpenAIApiKey
                )
                .listRowBackground(PremiumUI.card)
            } header: {
                Text("AI Providers")
            } footer: {
                Text("API keys are stored in the iOS Keychain and are not included in app settings backups.")
            }

            Section {
                SecureFieldRow(
                    label: "ElevenLabs",
                    placeholder: "ElevenLabs API Key",
                    text: Binding(
                        get: { KeychainService.shared.elevenLabsApiKey ?? "" },
                        set: { KeychainService.shared.elevenLabsApiKey = $0.isEmpty ? nil : $0 }
                    ),
                    hasValue: KeychainService.shared.hasElevenLabsApiKey
                )
                .listRowBackground(PremiumUI.card)
            } header: {
                Text("Optional Narration Provider")
            }

            Section {
                if chatgpt.isSignedIn {
                    HStack {
                        Text("ChatGPT")
                        Spacer()
                        Text("Signed in")
                            .foregroundStyle(PremiumUI.forest)
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(PremiumUI.forest)
                    }
                    .listRowBackground(PremiumUI.card)

                    Toggle("Use for guide generation", isOn: $useChatGPTOAuth)
                        .tint(PremiumUI.gold)
                        .listRowBackground(PremiumUI.card)

                    Button(role: .destructive) {
                        chatgpt.signOut()
                        useChatGPTOAuth = false
                        PremiumHaptics.notification(.warning)
                    } label: {
                        Text("Sign out of ChatGPT")
                    }
                    .listRowBackground(PremiumUI.card)
                } else {
                    Button {
                        showChatGPTSignIn = true
                    } label: {
                        Label("Sign in with ChatGPT", systemImage: "person.crop.circle")
                    }
                    .listRowBackground(PremiumUI.card)
                }
            } header: {
                Text("ChatGPT Subscription (Beta)")
            } footer: {
                Text("Unofficial: routes guide generation through your ChatGPT subscription via the Codex backend. This is not supported by OpenAI, may violate its Terms of Service, and could rate-limit or ban your account. Use at your own risk.")
            }
        }
        .premiumSettingsList(title: "API Configuration")
        .sheet(isPresented: $showChatGPTSignIn) {
            ChatGPTSignInSheet()
        }
    }
}

// MARK: - Audio Settings

struct AudioSettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment

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
        List {
            Section {
                Picker("Voice Provider", selection: $environment.userSettings.voiceProvider) {
                    ForEach(VoiceProvider.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .onChange(of: environment.userSettings.voiceProvider) {
                    environment.updateVoiceProvider(environment.userSettings.voiceProvider)
                    environment.userSettings.selectedVoiceID =
                        environment.userSettings.voiceProvider == .openai
                        ? "alloy"
                        : ElevenLabsVoiceRegistry.adam.voiceID
                    environment.saveSettings()
                }

                NavigationLink {
                    VoiceSelectionSettingsView()
                        .environmentObject(environment)
                } label: {
                    HStack {
                        Text("Voice")
                        Spacer()
                        Text(selectedVoiceName)
                            .foregroundStyle(PremiumUI.secondaryText)
                    }
                }

                Picker("Playback Speed", selection: $environment.userSettings.playbackSpeed) {
                    ForEach(PlaybackSpeed.allCases, id: \.self) { speed in
                        Text(speed.displayName).tag(speed)
                    }
                }
                .onChange(of: environment.userSettings.playbackSpeed) {
                    environment.saveSettings()
                }
            } header: {
                Text("Narration")
            }

            Section {
                Toggle(
                    "Auto-generate Audio",
                    isOn: $environment.userSettings.autoGenerateAudio
                )
                .tint(PremiumUI.gold)
                .onChange(of: environment.userSettings.autoGenerateAudio) {
                    environment.saveSettings()
                }
            } footer: {
                Text("Audio generation requires a configured key for the selected voice provider.")
            }
        }
        .premiumSettingsList(title: "Audio & Narration")
    }
}

// MARK: - Appearance Settings

struct ThemeSettingsView: View {
    @AppStorage(PremiumUI.themeStorageKey) private var selection = PremiumTheme.system.rawValue

    var body: some View {
        List {
            ForEach(PremiumTheme.allCases) { theme in
                Button {
                    selection = theme.rawValue
                    PremiumHaptics.selection()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: theme.icon)
                            .frame(width: 24)
                            .foregroundStyle(PremiumUI.gold)

                        Text(theme.rawValue)
                            .foregroundStyle(PremiumUI.ink)

                        Spacer()

                        if selection == theme.rawValue {
                            Image(systemName: "checkmark")
                                .fontWeight(.semibold)
                                .foregroundStyle(PremiumUI.gold)
                        }
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(PremiumUI.card)
            }
        }
        .premiumSettingsList(title: "Theme")
    }
}

struct AccentColorSettingsView: View {
    @AppStorage(PremiumUI.accentStorageKey) private var selection = PremiumAccent.gold.rawValue

    var body: some View {
        List {
            ForEach(PremiumAccent.allCases) { accent in
                Button {
                    selection = accent.rawValue
                    PremiumHaptics.selection()
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(accent.color)
                            .frame(width: 24, height: 24)

                        Text(accent.rawValue)
                            .foregroundStyle(PremiumUI.ink)

                        Spacer()

                        if selection == accent.rawValue {
                            Image(systemName: "checkmark")
                                .fontWeight(.semibold)
                                .foregroundStyle(accent.color)
                        }
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(PremiumUI.card)
            }
        }
        .premiumSettingsList(title: "Accent Color")
    }
}

// MARK: - Help and Privacy

struct HelpTutorialsView: View {
    var body: some View {
        List {
            PremiumHelpRow(
                icon: "doc.badge.plus",
                title: "Create a Guide",
                text: "Open Library, tap the plus button, then select a PDF or EPUB."
            )
            PremiumHelpRow(
                icon: "line.3.horizontal.decrease",
                title: "Find Saved Guides",
                text: "Search by title, author, or guide content. Use filters for favorites, recent guides, and drafts."
            )
            PremiumHelpRow(
                icon: "hand.draw",
                title: "Quick Actions",
                text: "In list view, swipe a guide to favorite, export, or delete it."
            )
            PremiumHelpRow(
                icon: "square.and.arrow.up",
                title: "Export",
                text: "Export a completed guide as a PDF from its swipe action or context menu."
            )
        }
        .premiumSettingsList(title: "Help & Tutorials")
    }
}

struct PrivacyPolicySettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Label("Privacy by Design", systemImage: "hand.raised.fill")
                    .font(PremiumUI.display(24, .bold))
                    .foregroundStyle(PremiumUI.ink)

                Text("Insight Atlas stores API keys in the iOS Keychain. Saved guides and generated media remain in the app’s local storage unless you choose to export or share them.")

                Text("When you generate a guide, the selected AI provider receives the source content required to fulfill that request under that provider’s terms and privacy policy.")

                Text("Insight Atlas does not display, log, or intentionally transmit your API keys outside the provider requests you initiate.")
            }
            .font(PremiumUI.ui(16))
            .foregroundStyle(PremiumUI.secondaryText)
            .padding(20)
        }
        .background(PremiumUI.background.ignoresSafeArea())
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

struct PremiumHelpRow: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(PremiumUI.gold)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(PremiumUI.ui(16, .semibold))
                    .foregroundStyle(PremiumUI.ink)

                Text(text)
                    .font(PremiumUI.ui(14))
                    .foregroundStyle(PremiumUI.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(PremiumUI.card)
    }
}

private extension View {
    func premiumSettingsList(title: String) -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(PremiumUI.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .tint(PremiumUI.gold)
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
                            .foregroundColor(isPreviewing ? .red : PremiumUI.gold)
                    }
                }
                .buttonStyle(.plain)

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(PremiumUI.gold)
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
                                .background(PremiumUI.gold.opacity(0.2))
                                .foregroundColor(PremiumUI.goldDark)
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
                            .foregroundColor(isPreviewing ? .red : PremiumUI.gold)
                    }
                }
                .buttonStyle(.plain)

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(PremiumUI.gold)
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
                            .foregroundStyle(PremiumUI.gold)
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
