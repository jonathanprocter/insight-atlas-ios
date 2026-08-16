//
//  NarrationControlsView.swift
//  InsightAtlas
//
//  The Listen panel shown over a guide. Narration is on-device Kokoro first,
//  with the hosted Kokoro voice ("Liam") as the fallback.
//
//  The panel floats above the guide text, so it can be collapsed to a small
//  pill when it gets in the way of reading. Collapsing never interrupts
//  playback or an in-flight synthesis -- it only changes how much room the
//  controls take up.
//

import SwiftUI

// MARK: - View model

@MainActor
final class NarrationControlViewModel: ObservableObject {
    @Published private(set) var progress: NarrationPreparationProgress?
    @Published private(set) var isPreparing = false
    @Published private(set) var fallbackMessage: String?
    @Published var errorMessage: String?
    @Published private(set) var canRetry = false

    private var generationTask: Task<Void, Never>?

    var progressLabel: String {
        progress?.statusDescription ?? "Preparing narration…"
    }

    /// Whole-percent synthesis progress when the current stage knows it.
    var percentComplete: Int? {
        progress?.percentComplete
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
                if Task.isCancelled { throw CancellationError() }

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
                canRetry = KokoroModelStore.isInstalled
                    || KokoroTTSClient.currentAPIKey() != nil
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
        var updated = item
        updated.audioFileURL = nil
        updated.audioVoiceID = nil
        updated.audioDuration = nil
        updated.audioGenerationAttempts = 0
        updated.narrationState = .notGenerated
        DataManager.shared.updateLibraryItem(updated)
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
        if voiceID == KokoroTTSClient.voice { return "Liam" }
        return KokoroVoiceRegistry.voice(byVoiceID: voiceID)?.name ?? voiceID
    }

    static func audioURL(for filename: String) -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(filename)
    }
}

// MARK: - Controls

struct NarrationControlsView: View {
    let item: LibraryItem

    @EnvironmentObject private var dataManager: DataManager
    @StateObject private var model = NarrationControlViewModel()
    @ObservedObject private var playback = NarrationPlaybackController.shared

    /// Persisted so the panel stays out of the way across guides and launches
    /// once the reader has dismissed it.
    @AppStorage("narration_controls_collapsed") private var isCollapsed = false

    private let speeds: [Float] = [0.75, 1, 1.25, 1.5, 2]

    private var currentItem: LibraryItem {
        dataManager.libraryItems.first(where: { $0.id == item.id }) ?? item
    }

    private var hasAudio: Bool {
        guard let filename = currentItem.audioFileURL,
              let url = NarrationControlViewModel.audioURL(for: filename) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    private var kokoroConfigured: Bool { KokoroModelStore.isInstalled }
    private var liamConfigured: Bool { KokoroTTSClient.currentAPIKey() != nil }

    var body: some View {
        Group {
            if isCollapsed {
                collapsedPill
            } else {
                expandedPanel
            }
        }
        .animation(.snappy(duration: 0.22), value: isCollapsed)
    }

    // MARK: Collapsed

    /// A small pill that keeps narration reachable without covering the guide.
    /// Shows live state so the reader knows work is still happening underneath.
    private var collapsedPill: some View {
        HStack {
            Spacer()
            Button {
                isCollapsed = false
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: collapsedIcon)
                        .font(.subheadline.weight(.semibold))
                    if let percent = model.percentComplete, model.isPreparing {
                        Text("\(percent)%")
                            .font(.caption.monospacedDigit().weight(.semibold))
                    }
                }
                .foregroundStyle(PremiumUI.gold)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(PremiumUI.divider, lineWidth: 0.8))
            }
            .accessibilityLabel("Show narration controls")
            .accessibilityValue(collapsedAccessibilityValue)
        }
    }

    private var collapsedIcon: String {
        if model.isPreparing { return "waveform" }
        return playback.isPlaying ? "pause.circle.fill" : "headphones"
    }

    private var collapsedAccessibilityValue: String {
        if model.isPreparing {
            if let percent = model.percentComplete { return "Generating audio, \(percent) percent" }
            return "Generating audio"
        }
        return playback.isPlaying ? "Playing" : "Paused"
    }

    // MARK: Expanded

    private var expandedPanel: some View {
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

                if hasAudio {
                    Menu {
                        Button("Delete Narration", systemImage: "trash", role: .destructive) {
                            model.deleteNarration(item: currentItem)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Narration options")
                }

                // Dismiss the panel so it stops covering the guide text.
                Button {
                    isCollapsed = true
                } label: {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Hide narration controls")
                .accessibilityHint("Collapses the panel to a small button. Playback continues.")
            }

            if model.isPreparing {
                preparingRow
            } else if hasAudio {
                playbackControls
            } else if !kokoroConfigured && !liamConfigured {
                HStack {
                    Text("Download Kokoro in Settings → Audio & Narration before listening.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
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
    }

    /// Synthesis progress. Kokoro reports a real fraction per rendered text
    /// chunk, so this shows a determinate bar and percentage; stages that
    /// genuinely cannot know their progress fall back to a spinner.
    private var preparingRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                if model.percentComplete == nil {
                    ProgressView()
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.progressLabel)
                        .font(.subheadline)
                    // A long guide can sit on the same percentage for a while;
                    // the chunk count makes it obvious work is still happening.
                    if let chunks = model.progress?.chunkProgressDescription {
                        Text(chunks)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let percent = model.percentComplete {
                    Text("\(percent)%")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(PremiumUI.gold)
                }
                Button("Cancel") { model.cancel() }
            }

            if let percent = model.percentComplete {
                ProgressView(value: Double(percent), total: 100)
                    .tint(PremiumUI.gold)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(model.progressLabel)
        .accessibilityValue(model.percentComplete.map { "\($0) percent" } ?? "")
    }

    private var readySubtitle: String {
        kokoroConfigured ? "Kokoro on-device · Liam fallback" : "Liam"
    }

    private var listenButtonTitle: String {
        kokoroConfigured ? "Listen with Kokoro" : "Listen with Liam"
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
