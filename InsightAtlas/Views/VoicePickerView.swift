//
//  VoicePickerView.swift
//  InsightAtlas
//
//  Editorial Voice Selection Interface for on-device Kokoro voices.
//

import SwiftUI

struct VoicePickerView: View {
    let profile: ReaderProfile
    @Binding var selectedVoiceID: String
    var onVoiceSelected: ((OnDevicePlaceholderVoice) -> Void)?

    @Environment(\.dismiss) private var dismiss

    private var recommendedVoices: [OnDevicePlaceholderVoice] {
        OnDeviceVoiceRegistry.allVoices
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Choose an on-device Kokoro voice for \(profile.displayName.lowercased()) listening. Voice previews will arrive with the local synthesis engine.")
                        .font(.system(size: 15))
                        .foregroundColor(InsightAtlasColors.muted)
                        .padding(.horizontal)

                    VoiceSection(
                        header: "On-Device (Kokoro)",
                        voices: recommendedVoices,
                        selectedVoiceID: selectedVoiceID,
                        onSelect: selectVoice
                    )

                    Text("Your selected voice will be used when Kokoro narration is available on-device.")
                        .font(.system(size: 13))
                        .foregroundColor(InsightAtlasColors.muted)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
                .padding(.vertical)
            }
            .background(InsightAtlasColors.background)
            .navigationTitle("Choose Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("voice_picker_done_button")
                }
            }
        }
    }

    private func selectVoice(_ voice: OnDevicePlaceholderVoice) {
        selectedVoiceID = voice.voiceID
        onVoiceSelected?(voice)
    }
}

private struct VoiceSection: View {
    let header: String
    let voices: [OnDevicePlaceholderVoice]
    let selectedVoiceID: String
    let onSelect: (OnDevicePlaceholderVoice) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(header.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(InsightAtlasColors.brandSepia)
                .tracking(0.5)
                .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(voices) { voice in
                    VoiceRow(
                        voice: voice,
                        isSelected: voice.voiceID == selectedVoiceID,
                        onSelect: { onSelect(voice) }
                    )

                    if voice.id != voices.last?.id {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
            .background(InsightAtlasColors.card)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
            .padding(.horizontal)
        }
    }
}

private struct VoiceRow: View {
    let voice: OnDevicePlaceholderVoice
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(InsightAtlasColors.gold.opacity(0.12))
                        .frame(width: 44, height: 44)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "waveform")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isSelected ? InsightAtlasColors.goldDark : InsightAtlasColors.brandSepia)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(voice.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(InsightAtlasColors.heading)

                        if voice.voiceID == OnDeviceVoiceRegistry.defaultVoice.voiceID {
                            Text("DEFAULT")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(InsightAtlasColors.brandSepia)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(InsightAtlasColors.gold.opacity(0.16))
                                .cornerRadius(999)
                        }
                    }

                    Text(voice.description)
                        .font(.system(size: 14))
                        .foregroundColor(InsightAtlasColors.muted)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? InsightAtlasColors.gold.opacity(0.05) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("voice_row_\(voice.voiceID)")
    }
}

struct PerGuideVoicePickerView: View {
    let profile: ReaderProfile
    @Binding var selectedVoiceID: String
    var onVoiceSelected: ((OnDevicePlaceholderVoice) -> Void)?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Choose the on-device Kokoro voice to use when regenerating narration.")
                    .font(.system(size: 14))
                    .foregroundColor(InsightAtlasColors.muted)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(InsightAtlasColors.backgroundAlt)

                VoicePickerView(
                    profile: profile,
                    selectedVoiceID: $selectedVoiceID,
                    onVoiceSelected: onVoiceSelected
                )
            }
            .navigationTitle("Choose Voice")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
