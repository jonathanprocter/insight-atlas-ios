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

    private var recommendedVoices: [VoicePickerOption] {
        OnDeviceVoiceRegistry.allVoices.map {
            VoicePickerOption(id: $0.voiceID, name: $0.name, description: $0.description)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Select an on-device Kokoro voice. Previews are unavailable until local narration playback is fully wired.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("ON-DEVICE (KOKORO)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .tracking(1)
                            .foregroundColor(InsightAtlasColors.brandSepia)
                            .padding(.horizontal)

                        ForEach(recommendedVoices) { voice in
                            VoiceSelectionRow(
                                voice: voice,
                                isSelected: selectedVoiceID == voice.id,
                                onSelect: { selectVoice(voice) }
                            )
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
            selectedVoiceID = isValidVoiceID(preferred) ? preferred! : OnDeviceVoiceRegistry.defaultVoice.voiceID
        }
    }

    private func isValidVoiceID(_ voiceID: String?) -> Bool {
        guard let voiceID else { return false }
        return recommendedVoices.contains { $0.id == voiceID }
    }

    private func selectVoice(_ voice: VoicePickerOption) {
        selectedVoiceID = voice.id
    }
}

private struct VoiceSelectionRow: View {
    let voice: VoicePickerOption
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? InsightAtlasColors.goldDark : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(voice.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(voice.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(isSelected ? InsightAtlasColors.gold.opacity(0.12) : Color(.secondarySystemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
}
