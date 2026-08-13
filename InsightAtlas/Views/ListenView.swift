import SwiftUI

// MARK: - Listen tab (narrated listening queue)

/// Listen — a private queue of narrated guides plus a premium player.
///
/// Shares the app's visual DNA but reserves Metallic Gold strictly for the
/// active audio state (the scrubber fill), per the specification. Deep Slate
/// carries the playback structure; Graphite carries secondary detail.
struct ListenView: View {
    @EnvironmentObject private var dataManager: DataManager
    @State private var playingItem: LibraryItem?

    /// Guides that have generated narration, most recent first.
    private var narratedItems: [LibraryItem] {
        dataManager.libraryItems
            .filter { $0.hasAudio }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    if narratedItems.isEmpty {
                        PremiumComingSoonPanel(
                            icon: "headphones",
                            title: "Nothing in your queue yet",
                            message: "Generate narration for a guide and it will appear here, ready to continue where comprehension left off."
                        )
                        .padding(.horizontal, 18)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(narratedItems) { item in
                                Button {
                                    playingItem = item
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                } label: {
                                    ListenQueueRow(item: item)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("listen_item_\(item.id.uuidString)")
                            }
                        }
                        .padding(.horizontal, 18)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(PremiumUI.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .fullScreenCover(item: $playingItem) { item in
            ListenPlayerView(item: item)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Listen")
                .font(PremiumUI.display(34, .bold, relativeTo: .largeTitle))
                .foregroundStyle(PremiumUI.ink)
            Text("Continue your narrated guides.")
                .font(PremiumUI.ui(15, .regular, relativeTo: .subheadline))
                .foregroundStyle(PremiumUI.secondaryText)
        }
        .padding(.horizontal, 18)
    }
}

/// A row in the listening queue: cover, title/author, duration, play glyph.
private struct ListenQueueRow: View {
    let item: LibraryItem

    var body: some View {
        HStack(spacing: 12) {
            LibraryCoverImageView(
                title: item.title,
                author: item.author,
                coverImagePath: item.coverImagePath,
                fallbackColor: PremiumUI.slate
            )
            .frame(width: 44, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(PremiumUI.display(16, .semibold))
                    .foregroundStyle(PremiumUI.ink)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(item.author)
                        .font(PremiumUI.ui(13))
                        .foregroundStyle(PremiumUI.secondaryText)
                        .lineLimit(1)
                    if let duration = item.formattedAudioDuration {
                        Text("· \(duration)")
                            .font(PremiumUI.ui(13))
                            .foregroundStyle(PremiumUI.secondaryText)
                    }
                }
            }

            Spacer(minLength: 6)

            Image(systemName: "play.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(PremiumUI.slate)
        }
        .padding(.horizontal, 13)
        .frame(minHeight: 68)
        .background(AnalysisTheme.bgCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(PremiumUI.divider.opacity(0.7), lineWidth: 0.7)
        }
        .shadow(color: Color.black.opacity(0.1).opacity(0.7), radius: 5, x: 0, y: 2)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Player

struct ListenPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var player: ListenPlayerViewModel
    @State private var showTranscript = false

    init(item: LibraryItem) {
        _player = StateObject(wrappedValue: ListenPlayerViewModel(item: item))
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            Spacer(minLength: 12)

            LibraryCoverImageView(
                title: player.item.title,
                author: player.item.author,
                coverImagePath: player.item.coverImagePath,
                fallbackColor: PremiumUI.slate
            )
            .frame(width: 208, height: 288)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 10)

            VStack(spacing: 6) {
                Text(player.item.title)
                    .font(PremiumUI.display(24, .semibold, relativeTo: .title2))
                    .foregroundStyle(PremiumUI.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(player.item.author)
                    .font(PremiumUI.ui(14))
                    .foregroundStyle(PremiumUI.secondaryText)
            }
            .padding(.top, 22)
            .padding(.horizontal, 32)

            Spacer(minLength: 20)

            scrubber
            controls
            secondaryControls

            if let error = player.loadError {
                Text(error)
                    .font(PremiumUI.ui(12))
                    .foregroundStyle(PremiumUI.coral)
                    .padding(.top, 12)
            }

            Spacer(minLength: 24)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AnalysisTheme.bgCard.ignoresSafeArea())
        .onAppear { player.start() }
        .onDisappear { player.stop() }
        .sheet(isPresented: $showTranscript) {
            ListenTranscriptSheet(item: player.item)
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(PremiumUI.slate)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("Close player")

            Spacer()

            Text("NOW PLAYING")
                .font(PremiumUI.ui(11, .semibold))
                .tracking(1.4)
                .foregroundStyle(PremiumUI.secondaryText)

            Spacer()

            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.top, 8)
    }

    // MARK: Scrubber (gold = active audio)

    private var scrubber: some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { player.progress },
                    set: { player.progress = $0 }
                ),
                in: 0...1
            ) { editing in
                player.isScrubbing = editing
                if !editing { player.seek(toProgress: player.progress) }
            }
            .tint(PremiumUI.gold)

            HStack {
                Text(Self.timeLabel(player.displayedCurrentTime))
                Spacer()
                Text(Self.timeLabel(player.duration))
            }
            .font(PremiumUI.ui(12, .medium))
            .foregroundStyle(PremiumUI.secondaryText)
            .monospacedDigit()
        }
    }

    // MARK: Transport controls (slate)

    private var controls: some View {
        HStack(spacing: 44) {
            Button { player.skip(-15) } label: {
                Image(systemName: "gobackward.15")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(PremiumUI.slate)
            }
            .accessibilityLabel("Skip back 15 seconds")

            Button { player.togglePlayPause() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 68, height: 68)
                    .background(PremiumUI.slate, in: Circle())
            }
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

            Button { player.skip(15) } label: {
                Image(systemName: "goforward.15")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(PremiumUI.slate)
            }
            .accessibilityLabel("Skip forward 15 seconds")
        }
        .padding(.top, 24)
    }

    // MARK: Speed + transcript

    private var secondaryControls: some View {
        HStack {
            Button { player.cycleRate() } label: {
                Text(player.rateLabel)
                    .font(PremiumUI.ui(13, .semibold))
                    .foregroundStyle(PremiumUI.secondaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .overlay(Capsule().strokeBorder(PremiumUI.divider, lineWidth: 1))
            }
            .accessibilityLabel("Playback speed \(player.rateLabel)")

            Spacer()

            Button { showTranscript = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "text.alignleft")
                    Text("Transcript")
                }
                .font(PremiumUI.ui(13, .semibold))
                .foregroundStyle(PremiumUI.slate)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .accessibilityLabel("Show transcript")
        }
        .padding(.top, 26)
    }

    private static func timeLabel(_ time: TimeInterval) -> String {
        guard time.isFinite, time >= 0 else { return "0:00" }
        let total = Int(time)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// Synchronized-transcript stand-in: the guide's text on a porcelain sheet.
/// NOTE: not time-synced to playback yet — narration lacks per-section
/// timestamps. Shown for reading-along; highlighting the active line is a
/// later enhancement.
private struct ListenTranscriptSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: LibraryItem

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(item.summaryContent ?? "No transcript available.")
                    .font(PremiumUI.display(17, .regular, relativeTo: .body))
                    .foregroundStyle(PremiumUI.ink)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .background(PremiumUI.searchFill.ignoresSafeArea())
            .navigationTitle("Transcript")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PremiumUI.slate)
                }
            }
        }
    }
}

// MARK: - Player view model

/// Drives the Listen player over the shared `AudioPlaybackManager` singleton,
/// polling it on a timer since the manager is not itself observable.
@MainActor
final class ListenPlayerViewModel: ObservableObject {
    let item: LibraryItem

    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var rate: Float = 1.0
    @Published var loadError: String?

    /// True while the user is dragging the scrubber (suppresses timer writes).
    var isScrubbing = false

    private var started = false
    private var timer: Timer?
    private let manager = AudioPlaybackManager.shared

    private static let rateLadder: [Float] = [1.0, 1.25, 1.5, 2.0, 0.75]

    init(item: LibraryItem) {
        self.item = item
        self.duration = item.audioDuration ?? 0
    }

    /// Time shown under the scrubber — follows the drag while scrubbing.
    var displayedCurrentTime: TimeInterval {
        isScrubbing ? duration * progress : currentTime
    }

    var rateLabel: String {
        "\(String(format: "%g", rate))×"
    }

    // MARK: Intents

    func start() {
        guard let url = resolvedURL else {
            loadError = "Audio file missing. Regenerate narration."
            return
        }
        do {
            try manager.playFile(at: url, rate: rate) { [weak self] in
                Task { @MainActor in self?.handleCompletion() }
            }
            started = true
            isPlaying = true
            duration = manager.duration
            loadError = nil
            startTimer()
        } catch {
            loadError = "Audio playback failed."
        }
    }

    func togglePlayPause() {
        if isPlaying {
            manager.pause()
            isPlaying = false
            stopTimer()
        } else if started && manager.duration > 0 {
            manager.resume()
            isPlaying = true
            startTimer()
        } else {
            start()
        }
    }

    func stop() {
        manager.stop()
        isPlaying = false
        started = false
        stopTimer()
    }

    func seek(toProgress fraction: Double) {
        manager.seek(toProgress: fraction)
        progress = fraction
        currentTime = duration * fraction
    }

    func skip(_ seconds: TimeInterval) {
        manager.seek(to: manager.currentTime + seconds)
        tick()
    }

    func cycleRate() {
        let index = Self.rateLadder.firstIndex(of: rate) ?? 0
        rate = Self.rateLadder[(index + 1) % Self.rateLadder.count]
        manager.setPlaybackRate(rate)
    }

    // MARK: Internals

    private var resolvedURL: URL? {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        if let name = item.audioFileURL {
            let url = docs.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        let fallback = docs.appendingPathComponent("audio_\(item.id.uuidString).mp3")
        return FileManager.default.fileExists(atPath: fallback.path) ? fallback : nil
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        if duration == 0 { duration = manager.duration }
        if !isScrubbing {
            progress = manager.progress
            currentTime = manager.currentTime
        }
        // Manager stops on completion; if we still think we're playing, finish.
        if isPlaying && !manager.isPlaying && manager.currentTime == 0 {
            handleCompletion()
        }
    }

    private func handleCompletion() {
        isPlaying = false
        started = false
        progress = 1
        currentTime = duration
        stopTimer()
    }
}

#Preview("Listen") {
    ListenView()
        .environmentObject(DataManager.shared)
}
