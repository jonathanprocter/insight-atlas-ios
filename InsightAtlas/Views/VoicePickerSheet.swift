//
//  VoicePickerSheet.swift
//  InsightAtlas
//
//  Sheet wrapper for voice selection when regenerating audio.
//

import SwiftUI

struct VoicePickerSheet: View {
    let currentVoiceID: String?
    let onSelectVoice: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var environment: AppEnvironment

    @State private var selectedVoiceID: String = ""
    @State private var previewingVoiceID: String?
    @State private var isLoadingPreview = false

    private var profile: ReaderProfile {
        environment.userSettings.preferredReaderProfile
    }

    private var recommendedVoices: [ElevenLabsVoice] {
        ElevenLabsVoiceRegistry.allVoices.filter {
            $0.recommendedProfiles.contains(profile)
        }
    }

    private var otherVoices: [ElevenLabsVoice] {
        ElevenLabsVoiceRegistry.allVoices.filter {
            !$0.recommendedProfiles.contains(profile)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header description
                    Text("Select a voice for your audio narration. The audio will be regenerated with the selected voice.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    // Recommended voices
                    VStack(alignment: .leading, spacing: 12) {
                        Text("RECOMMENDED FOR YOU")
                            .font(.caption)
                            .fontWeight(.bold)
                            .tracking(1)
                            .foregroundColor(AnalysisTheme.primaryGold)
                            .padding(.horizontal)

                        ForEach(recommendedVoices) { voice in
                            VoiceSelectionRow(
                                voice: voice,
                                isSelected: selectedVoiceID == voice.voiceID,
                                isPreviewing: previewingVoiceID == voice.id,
                                isLoadingPreview: isLoadingPreview && previewingVoiceID == voice.id,
                                onSelect: { selectVoice(voice) },
                                onPreview: { previewVoice(voice) }
                            )
                        }
                    }

                    // Other voices
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
                                    isSelected: selectedVoiceID == voice.voiceID,
                                    isPreviewing: previewingVoiceID == voice.id,
                                    isLoadingPreview: isLoadingPreview && previewingVoiceID == voice.id,
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
            selectedVoiceID = currentVoiceID ?? environment.userSettings.selectedVoiceID ?? recommendedVoices.first?.voiceID ?? ""
        }
    }

    private func selectVoice(_ voice: ElevenLabsVoice) {
        selectedVoiceID = voice.voiceID
    }

    private func previewVoice(_ voice: ElevenLabsVoice) {
        guard !isLoadingPreview else { return }

        isLoadingPreview = true
        previewingVoiceID = voice.id

        Task {
            do {
                let previewText = "This is how I sound when narrating your Insight Atlas guide. My voice will accompany you through key concepts and practical applications."

                let result = try await environment.audioService.generateAudio(
                    text: previewText,
                    voiceID: voice.id
                )

                try AudioPlaybackManager.shared.play(result)

                await MainActor.run {
                    isLoadingPreview = false
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

// MARK: - Voice Selection Row

struct VoiceSelectionRow: View {
    let voice: ElevenLabsVoice
    let isSelected: Bool
    let isPreviewing: Bool
    let isLoadingPreview: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? AnalysisTheme.primaryGold : .secondary)

                // Voice info
                VStack(alignment: .leading, spacing: 4) {
                    Text(voice.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(voice.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Preview button
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
