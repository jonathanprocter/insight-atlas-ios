//
//  VoicePickerView.swift
//  InsightAtlas
//
//  Editorial Voice Selection Interface.
//
//  Voice selection feels like an editorial decision, not a technical setting.
//  Users understand why a voice is recommended, when to use it,
//  and how it will feel over long listening sessions.
//
//  GOVERNANCE:
//  - Uses VoicePickerCopy for all micro-copy
//  - Groups by editorial intent, not demographics
//  - Preview uses canonical script (voice differences come from voice itself)
//  - No audio/rendering logic changes
//
//  VERSION: 1.0.0
//

import SwiftUI

// MARK: - Voice Picker View

/// Main voice selection screen.
/// Displays recommended voices based on reader profile with editorial grouping.
struct VoicePickerView: View {

    // MARK: - Properties

    /// Current reader profile for voice recommendations
    let profile: ReaderProfile

    /// Currently selected voice ID
    @Binding var selectedVoiceID: String

    /// Callback when voice selection changes
    var onVoiceSelected: ((ElevenLabsVoice) -> Void)?

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var showOtherVoices = false
    @State private var previewingVoiceID: String?
    @State private var isLoadingPreview = false
    @State private var previewError: String?
    @State private var currentPreviewAudio: GeneratedAudio?

    // MARK: - Computed Properties

    /// Voices recommended for the current profile
    private var recommendedVoices: [ElevenLabsVoice] {
        ElevenLabsVoiceRegistry.allVoices.filter {
            $0.recommendedProfiles.contains(profile)
        }
    }

    /// Other available voices (not recommended for profile)
    private var otherVoices: [ElevenLabsVoice] {
        ElevenLabsVoiceRegistry.allVoices.filter {
            !$0.recommendedProfiles.contains(profile)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Subtitle
                    Text(VoicePickerCopy.screenSubtitle)
                        .font(.system(size: 15))
                        .foregroundColor(InsightAtlasColors.muted)
                        .padding(.horizontal)

                    // Recommended Section
                    VoiceSection(
                        header: VoicePickerCopy.recommendedSectionHeader(for: profile),
                        voices: recommendedVoices,
                        selectedVoiceID: selectedVoiceID,
                        previewingVoiceID: previewingVoiceID,
                        isLoadingPreview: isLoadingPreview,
                        onSelect: selectVoice,
                        onPreview: previewVoice
                    )

                    // Other Voices Section (collapsed by default)
                    if !otherVoices.isEmpty {
                        OtherVoicesSection(
                            isExpanded: $showOtherVoices,
                            voices: otherVoices,
                            selectedVoiceID: selectedVoiceID,
                            previewingVoiceID: previewingVoiceID,
                            isLoadingPreview: isLoadingPreview,
                            onSelect: selectVoice,
                            onPreview: previewVoice
                        )
                    }

                    // Footer helper
                    Text(VoicePickerCopy.playbackSpeedHelper)
                        .font(.system(size: 13))
                        .foregroundColor(InsightAtlasColors.muted)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // Error display
                    if let error = previewError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(InsightAtlasColors.muted)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(InsightAtlasColors.background)
            .navigationTitle(VoicePickerCopy.screenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        stopPreview()
                        dismiss()
                    }
                }
            }
            .onDisappear {
                stopPreview()
            }
        }
    }

    // MARK: - Actions

    private func selectVoice(_ voice: ElevenLabsVoice) {
        selectedVoiceID = voice.voiceID
        onVoiceSelected?(voice)
    }

    private func previewVoice(_ voice: ElevenLabsVoice) {
        // Stop any existing preview
        if previewingVoiceID != nil {
            stopPreview()
            // If tapping the same voice, just stop
            if previewingVoiceID == voice.voiceID {
                previewingVoiceID = nil
                return
            }
        }

        previewingVoiceID = voice.voiceID
        isLoadingPreview = true
        previewError = nil

        Task {
            do {
                // Check for API key first
                guard KeychainService.shared.hasElevenLabsApiKey else {
                    await MainActor.run {
                        previewError = "ElevenLabs API key not configured"
                        isLoadingPreview = false
                        previewingVoiceID = nil
                    }
                    return
                }

                // Generate preview audio using ElevenLabs
                let audioService = ElevenLabsAudioService()
                let audio = try await audioService.generateAudio(
                    text: VoicePreviewScript.primary,
                    voiceID: voice.voiceID
                )

                await MainActor.run {
                    currentPreviewAudio = audio
                    isLoadingPreview = false

                    // Play the generated audio
                    do {
                        try AudioPlaybackManager.shared.play(audio) {
                            // Playback completed - reset state
                            Task { @MainActor in
                                self.previewingVoiceID = nil
                                self.currentPreviewAudio = nil
                            }
                        }
                    } catch {
                        previewError = "Failed to play audio: \(error.localizedDescription)"
                        previewingVoiceID = nil
                    }
                }
            } catch let error as ElevenLabsAudioError {
                await MainActor.run {
                    previewError = error.localizedDescription
                    isLoadingPreview = false
                    previewingVoiceID = nil
                }
            } catch {
                await MainActor.run {
                    previewError = "Preview failed: \(error.localizedDescription)"
                    isLoadingPreview = false
                    previewingVoiceID = nil
                }
            }
        }
    }

    private func stopPreview() {
        AudioPlaybackManager.shared.stop()
        previewingVoiceID = nil
        isLoadingPreview = false
        currentPreviewAudio = nil
    }
}

// MARK: - Voice Section

/// A section of voices with header
private struct VoiceSection: View {
    let header: String
    let voices: [ElevenLabsVoice]
    let selectedVoiceID: String
    let previewingVoiceID: String?
    let isLoadingPreview: Bool
    let onSelect: (ElevenLabsVoice) -> Void
    let onPreview: (ElevenLabsVoice) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            Text(header.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(InsightAtlasColors.brandSepia)
                .tracking(0.5)
                .padding(.horizontal)

            // Voice list
            VStack(spacing: 0) {
                ForEach(voices) { voice in
                    VoiceRow(
                        voice: voice,
                        isSelected: voice.voiceID == selectedVoiceID,
                        isPreviewing: voice.voiceID == previewingVoiceID,
                        isLoading: voice.voiceID == previewingVoiceID && isLoadingPreview,
                        onSelect: { onSelect(voice) },
                        onPreview: { onPreview(voice) }
                    )

                    if voice.id != voices.last?.id {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
            .background(InsightAtlasColors.card)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(InsightAtlasColors.rule.opacity(0.5), lineWidth: 1)
            )
            .padding(.horizontal)
        }
    }
}

// MARK: - Other Voices Section

/// Collapsible section for non-recommended voices
private struct OtherVoicesSection: View {
    @Binding var isExpanded: Bool
    let voices: [ElevenLabsVoice]
    let selectedVoiceID: String
    let previewingVoiceID: String?
    let isLoadingPreview: Bool
    let onSelect: (ElevenLabsVoice) -> Void
    let onPreview: (ElevenLabsVoice) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Expandable header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(VoicePickerCopy.otherVoicesHeader.uppercased())
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(InsightAtlasColors.muted)
                        .tracking(0.5)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(InsightAtlasColors.muted)
                }
                .padding(.horizontal)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(voices) { voice in
                        VoiceRow(
                            voice: voice,
                            isSelected: voice.voiceID == selectedVoiceID,
                            isPreviewing: voice.voiceID == previewingVoiceID,
                            isLoading: voice.voiceID == previewingVoiceID && isLoadingPreview,
                            onSelect: { onSelect(voice) },
                            onPreview: { onPreview(voice) }
                        )

                        if voice.id != voices.last?.id {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
                .background(InsightAtlasColors.card)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(InsightAtlasColors.rule.opacity(0.5), lineWidth: 1)
                )
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Voice Row

/// Individual voice selection row
private struct VoiceRow: View {
    let voice: ElevenLabsVoice
    let isSelected: Bool
    let isPreviewing: Bool
    let isLoading: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Preview button
            Button {
                onPreview()
            } label: {
                ZStack {
                    Circle()
                        .fill(isPreviewing ? InsightAtlasColors.gold.opacity(0.15) : InsightAtlasColors.backgroundAlt)
                        .frame(width: 40, height: 40)

                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: isPreviewing ? "stop.fill" : "play.fill")
                            .font(.system(size: 14))
                            .foregroundColor(isPreviewing ? InsightAtlasColors.gold : InsightAtlasColors.muted)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPreviewing
                ? VoiceSelectionCopy.stopPreviewAccessibility
                : VoiceSelectionCopy.playPreviewAccessibility
            )

            // Voice info
            Button {
                onSelect()
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(voice.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(InsightAtlasColors.heading)

                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(InsightAtlasColors.gold)
                        }
                    }

                    Text(voice.description)
                        .font(.system(size: 14))
                        .foregroundColor(InsightAtlasColors.muted)
                        .lineLimit(2)
                }

                Spacer()
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Per-Guide Voice Picker

/// Voice picker for changing voice on a specific guide.
/// Shows helper text about regeneration.
struct PerGuideVoicePickerView: View {

    let profile: ReaderProfile
    @Binding var selectedVoiceID: String
    var onVoiceSelected: ((ElevenLabsVoice) -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Helper text about regeneration
                Text(VoicePickerCopy.perGuideHelper)
                    .font(.system(size: 14))
                    .foregroundColor(InsightAtlasColors.muted)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(InsightAtlasColors.backgroundAlt)

                // Voice picker content
                VoicePickerView(
                    profile: profile,
                    selectedVoiceID: $selectedVoiceID,
                    onVoiceSelected: onVoiceSelected
                )
            }
            .navigationTitle(VoicePickerCopy.perGuideTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Preview

#Preview("Voice Picker - Executive") {
    VoicePickerView(
        profile: .executive,
        selectedVoiceID: .constant("pNInz6obpgDQGcFmaJgB")
    )
}

#Preview("Voice Picker - Practitioner") {
    VoicePickerView(
        profile: .practitioner,
        selectedVoiceID: .constant("21m00Tcm4TlvDq8ikWAM")
    )
}

#Preview("Per-Guide Voice Picker") {
    PerGuideVoicePickerView(
        profile: .academic,
        selectedVoiceID: .constant("flq6f7yk4E4fJM5XTYuZ")
    )
}
