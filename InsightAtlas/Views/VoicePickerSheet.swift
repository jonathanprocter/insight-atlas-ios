//
//  VoicePickerSheet.swift
//  InsightAtlas
//
//  Sheet wrapper for voice selection when regenerating audio.
//

import SwiftUI

private struct VoicePickerOption: Identifiable {
    let id: String
    let name: String
    let description: String
}

struct VoicePickerSheet: View {
    let currentVoiceID: String?
    let onSelectVoice: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var environment: AppEnvironment

    @State private var selectedVoiceID: String = ""
    @State private var previewingVoiceID: String?
    @State private var isLoadingPreview = false

    private var provider: VoiceProvider {
        environment.userSettings.voiceProvider
    }

    private var profile: ReaderProfile {
        environment.userSettings.preferredReaderProfile
    }

    private var recommendedVoices: [VoicePickerOption] {
        switch provider {
        case .chatgptVoice:
            return ChatGPTVoiceRegistry.allVoices.map {
                VoicePickerOption(id: $0.voiceID, name: $0.name, description: $0.description)
            }
        case .openai:
            return OpenAIVoiceRegistry.allVoices.map {
                VoicePickerOption(id: $0.voiceID, name: $0.name, description: $0.description)
            }
        case .elevenlabs:
            return ElevenLabsVoiceRegistry.allVoices
                .filter { $0.recommendedProfiles.contains(profile) }
                .map { VoicePickerOption(id: $0.voiceID, name: $0.name, description: $0.description) }
        }
    }

    private var otherVoices: [VoicePickerOption] {
        guard provider == .elevenlabs else { return [] }
        return ElevenLabsVoiceRegistry.allVoices
            .filter { !$0.recommendedProfiles.contains(profile) }
            .map { VoicePickerOption(id: $0.voiceID, name: $0.name, description: $0.description) }
    }

    private var primarySectionTitle: String {
        switch provider {
        case .chatgptVoice:
            return "CHATGPT VOICES · EXPERIMENTAL"
        case .openai:
            return "OPENAI VOICES"
        case .elevenlabs:
            return "RECOMMENDED FOR YOU"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Select a \(provider.displayName) voice for manual provider previews. Full-guide narration uses Mega Transcript first, OpenAI second, and Liam last.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(primarySectionTitle)
                            .font(.caption)
                            .fontWeight(.bold)
                            .tracking(1)
                            .foregroundColor(AnalysisTheme.primaryGold)
                            .padding(.horizontal)

                        ForEach(recommendedVoices) { voice in
                            VoiceSelectionRow(
                                voice: voice,
                                isSelected: selectedVoiceID == voice.id,
                                isPreviewing: previewingVoiceID == voice.id,
                                isLoadingPreview: isLoadingPreview && previewingVoiceID == voice.id,
                                isPreviewEnabled: provider.isConfigured(),
                                onSelect: { selectVoice(voice) },
                                onPreview: { previewVoice(voice) }
                            )
                        }
                    }

                    if !otherVoices.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("OTHER VOICES")
                                .font(.caption)
                                .fontWeight(.bold)
                                .tracking(1)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)

                            ForEach(otherVoices) { voice in
                                VoiceSelectionRow(
                                    voice: voice,
                                    isSelected: selectedVoiceID == voice.id,
                                    isPreviewing: previewingVoiceID == voice.id,
                                    isLoadingPreview: isLoadingPreview && previewingVoiceID == voice.id,
                                    isPreviewEnabled: provider.isConfigured(),
                                    onSelect: { selectVoice(voice) },
                                    onPreview: { previewVoice(voice) }
                                )
                            }
                        }
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
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Generate") {
                        dismiss()
                        onSelectVoice(selectedVoiceID)
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedVoiceID.isEmpty)
                }
            }
        }
        .onAppear {
            let preferred = currentVoiceID ?? environment.userSettings.selectedVoiceID
            selectedVoiceID = isValidVoiceID(preferred)
                ? preferred!
                : provider.defaultVoiceID
        }
    }

    private func isValidVoiceID(_ voiceID: String?) -> Bool {
        guard let voiceID else { return false }
        return (recommendedVoices + otherVoices).contains { $0.id == voiceID }
    }

    private func selectVoice(_ voice: VoicePickerOption) {
        selectedVoiceID = voice.id
    }

    private func previewVoice(_ voice: VoicePickerOption) {
        guard !isLoadingPreview, provider.isConfigured() else { return }

        if previewingVoiceID == voice.id {
            AudioPlaybackManager.shared.stop()
            previewingVoiceID = nil
            return
        }

        AudioPlaybackManager.shared.stop()
        isLoadingPreview = true
        previewingVoiceID = voice.id

        Task {
            do {
                let previewText = "This is how I sound when narrating your InsightAtlas guide. My voice will accompany you through key concepts and practical applications."
                let result = try await VoiceServiceManager.shared.generateAudio(
                    text: previewText,
                    voiceID: voice.id,
                    provider: provider
                )

                try AudioPlaybackManager.shared.play(result) {
                    previewingVoiceID = nil
                }
                isLoadingPreview = false
            } catch {
                isLoadingPreview = false
                previewingVoiceID = nil
            }
        }
    }
}

// MARK: - Voice Selection Row

private struct VoiceSelectionRow: View {
    let voice: VoicePickerOption
    let isSelected: Bool
    let isPreviewing: Bool
    let isLoadingPreview: Bool
    let isPreviewEnabled: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? AnalysisTheme.primaryGold : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(voice.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(voice.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: onPreview) {
                    if isLoadingPreview {
                        ProgressView()
                            .frame(width: 32, height: 32)
                    } else {
                        Image(systemName: isPreviewing ? "stop.fill" : "play.fill")
                            .font(.body)
                            .foregroundColor(AnalysisTheme.accentTeal)
                            .frame(width: 32, height: 32)
                            .background(AnalysisTheme.accentTealSubtle.opacity(0.3))
                            .cornerRadius(16)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!isPreviewEnabled)
                .opacity(isPreviewEnabled ? 1 : 0.45)
            }
            .padding()
            .background(isSelected ? AnalysisTheme.primaryGoldSubtle.opacity(0.2) : Color(.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AnalysisTheme.primaryGold : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
}
