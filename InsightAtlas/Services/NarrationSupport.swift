//
//  NarrationSupport.swift
//  InsightAtlas
//
//  Provider-independent narration support: the preparation-progress contract,
//  the text sanitizer that strips editorial markup before speech, and the
//  shared local playback controller.
//
//  These used to live alongside the Mega Transcript integration. That provider
//  has been retired -- narration is Kokoro on-device first, with the hosted
//  Kokoro voice ("Liam") as the fallback -- so the pieces every provider needs
//  live here instead.
//

import AVFoundation
import Combine
import Foundation
import MediaPlayer
import UIKit

// MARK: - Presentation text hygiene

/// Converts generated guide markup into reader-facing text without exposing the
/// Markdown or editorial control syntax used by the generation pipeline.
///
/// The raw manuscript remains unchanged for structural parsers. Presentation
/// boundaries call one of these pure helpers immediately before rendering,
/// speaking, or writing an exported artifact.
enum PresentationTextSanitizer {
    static func withoutEditorialMarkup(_ content: String) -> String {
        var result = content
        result = result.replacingOccurrences(
            of: #"\[/?[A-Z][A-Z0-9_]*(?::[^\]]*)?\]"#,
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"!?\[\s*\]\([^)]*\)"#,
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\[\s*\]"#,
            with: "",
            options: .regularExpression
        )
        return result
    }

    /// Removes inline Markdown delimiters while preserving their semantic text.
    /// Rich renderers that retain bold/italic styles should instead call
    /// `attributedMarkupSource(_:)`.
    static func inlinePlainText(_ content: String) -> String {
        var result = withoutEditorialMarkup(content)
        result = result.replacingOccurrences(
            of: #"!\[([^\]]*)\]\([^)]*\)"#,
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\[([^\]]+)\]\([^)]*\)"#,
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"~~([^~\n]+)~~"#,
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"`([^`\n]+)`"#,
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\*\*([^*\n]+)\*\*"#,
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"__([^_\n]+)__"#,
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"(?<![\*\w])\*([^*\n]+)\*(?![\*\w])"#,
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"(?<![_\w])_([^_\n]+)_(?![_\w])"#,
            with: "$1",
            options: .regularExpression
        )
        // Malformed generation output can contain an opening delimiter with
        // no closing partner. Preserve the words, never the control glyphs.
        result = result.replacingOccurrences(of: "**", with: "")
        result = result.replacingOccurrences(of: "~~", with: "")
        result = result.replacingOccurrences(of: "`", with: "")
        result = result.replacingOccurrences(
            of: #"[ \t]{2,}"#,
            with: " ",
            options: .regularExpression
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Cleans unsupported inline constructs but retains bold/italic delimiters
    /// for native SwiftUI or DOCX styling passes.
    static func attributedMarkupSource(_ content: String) -> String {
        var result = withoutEditorialMarkup(content)
        result = result.replacingOccurrences(
            of: #"!\[([^\]]*)\]\([^)]*\)"#,
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\[([^\]]+)\]\([^)]*\)"#,
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"~~([^~\n]+)~~"#,
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"`([^`\n]+)`"#,
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(of: "~~", with: "")
        result = result.replacingOccurrences(of: "`", with: "")
        result = removingUnpairedDelimiter("**", from: result)
        result = removingUnpairedDelimiter("__", from: result)
        return result
    }

    private static func removingUnpairedDelimiter(_ delimiter: String, from text: String) -> String {
        var ranges: [Range<String.Index>] = []
        var searchStart = text.startIndex
        while searchStart < text.endIndex,
              let range = text.range(of: delimiter, range: searchStart..<text.endIndex) {
            ranges.append(range)
            searchStart = range.upperBound
        }
        guard ranges.count.isMultiple(of: 2) == false, let unmatched = ranges.last else {
            return text
        }
        var result = text
        result.removeSubrange(unmatched)
        return result
    }

    static func plainText(_ content: String, preserveListMarkers: Bool = true) -> String {
        let normalized = content.replacingOccurrences(of: "\r\n", with: "\n")
        var output: [String] = []
        var inCodeFence = false

        for rawLine in normalized.components(separatedBy: "\n") {
            var line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.range(of: #"^```"#, options: .regularExpression) != nil {
                inCodeFence.toggle()
                continue
            }

            if !inCodeFence,
               line.range(of: #"^\s*(?:-{3,}|\*{3,}|_{3,})\s*$"#, options: .regularExpression) != nil {
                continue
            }

            let pipeCount = line.filter { $0 == "|" }.count
            if !inCodeFence, pipeCount >= 2 {
                let cells = line
                    .trimmingCharacters(in: CharacterSet(charactersIn: "|"))
                    .split(separator: "|", omittingEmptySubsequences: false)
                    .map { inlinePlainText(String($0).trimmingCharacters(in: .whitespaces)) }
                let isSeparator = !cells.isEmpty && cells.allSatisfy {
                    !$0.isEmpty && $0.allSatisfy { $0 == "-" || $0 == ":" || $0.isWhitespace }
                }
                if isSeparator { continue }
                line = cells.filter { !$0.isEmpty }.joined(separator: " — ")
            } else {
                line = line.replacingOccurrences(
                    of: #"^\s{0,3}#{1,6}\s*"#,
                    with: "",
                    options: .regularExpression
                )
                line = line.replacingOccurrences(
                    of: #"^\s*>\s?"#,
                    with: "",
                    options: .regularExpression
                )
                if preserveListMarkers {
                    line = line.replacingOccurrences(
                        of: #"^\s*[-*+•]\s+"#,
                        with: "• ",
                        options: .regularExpression
                    )
                    line = line.replacingOccurrences(
                        of: #"^\s*(\d+)[.)]\s+"#,
                        with: "$1 — ",
                        options: .regularExpression
                    )
                } else {
                    line = line.replacingOccurrences(
                        of: #"^\s*(?:[-*+•]|\d+[.)])\s+"#,
                        with: "",
                        options: .regularExpression
                    )
                }
            }

            output.append(inlinePlainText(line))
        }

        return output.joined(separator: "\n")
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Preparation progress

/// Stages a narration request passes through, surfaced to the UI.
enum NarrationPreparationProgress: Sendable, Equatable {
    case checkingCache
    case generating(narrator: String)
    /// Loading the on-device model. Distinct from synthesis because a cold
    /// model load is slow and silent, and conflating the two made a stall
    /// impossible to place.
    case loadingModel(narrator: String)
    /// Real synthesis progress across the text chunks Kokoro renders.
    /// `completed`/`total` are carried so the UI can say "3 of 41" -- a large
    /// guide can sit on 0% for a while purely from rounding.
    case synthesizing(narrator: String, completed: Int, total: Int)
    case downloading
    case usingCache
    case fallingBackToLiam(reason: String)
    case ready(narrator: String)

    /// Completion as a percentage when the stage knows it, otherwise nil.
    var percentComplete: Int? {
        switch self {
        case .synthesizing(_, let completed, let total):
            guard total > 0 else { return 0 }
            let fraction = Double(completed) / Double(total)
            return Int((max(0, min(1, fraction)) * 100).rounded())
        case .ready:
            return 100
        case .checkingCache, .generating, .loadingModel, .downloading, .usingCache, .fallingBackToLiam:
            return nil
        }
    }

    /// "3 of 41" while synthesizing, so slow progress is still visibly moving
    /// even when the percentage has not ticked over yet.
    var chunkProgressDescription: String? {
        guard case .synthesizing(_, let completed, let total) = self, total > 0 else { return nil }
        return "\(completed) of \(total)"
    }

    /// Human-readable stage label for the narration UI.
    var statusDescription: String {
        switch self {
        case .checkingCache: return "Checking narration cache…"
        case .generating(let narrator): return "Preparing narration with \(narrator)…"
        case .loadingModel(let narrator): return "Loading the \(narrator) voice model…"
        case .synthesizing(let narrator, _, _): return "Generating audio with \(narrator)…"
        case .downloading: return "Downloading narration…"
        case .usingCache: return "Opening cached narration…"
        case .fallingBackToLiam: return "Switching to the Liam voice…"
        case .ready(let narrator): return "Ready with \(narrator)"
        }
    }
}

enum NarrationTextSanitizer {
    static func prepare(_ content: String) -> String {
        PresentationTextSanitizer.plainText(content, preserveListMarkers: false)
    }
}

// MARK: - Shared local playback

enum NarrationPlaybackPolicy {
    /// `.default` is the playback-compatible mode for locally generated files.
    /// Bluetooth routing is managed by iOS; recording-only Bluetooth options are
    /// deliberately omitted to avoid `paramErr` on physical devices.
    static let mode: AVAudioSession.Mode = .default
    static let options: AVAudioSession.CategoryOptions = []
}

enum NarrationPlaybackFailureMessage {
    static func message(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSOSStatusErrorDomain
            || nsError.domain == AVFoundationErrorDomain {
            return "This narration file could not be played. Regenerate the audio and try again."
        }
        return "Narration playback failed. Regenerate the audio and try again."
    }
}

@MainActor
final class NarrationPlaybackController: NSObject, ObservableObject {
    static let shared = NarrationPlaybackController()

    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var currentURL: URL?
    @Published var playbackRate: Float = 1

    /// True while narration is being played from chunks that are still being
    /// rendered. The total duration is not yet known, so the scrubber is
    /// disabled until the full asset exists.
    @Published private(set) var isStreaming = false
    @Published private(set) var streamedSegments = 0
    @Published private(set) var expectedSegments = 0

    private let player = AVQueuePlayer()
    private var timeObserver: Any?
    private var notificationObservers: [NSObjectProtocol] = []
    private var itemEndObservers: [NSObjectProtocol] = []
    private var title = ""
    private var author = ""
    private var coverImagePath: String?

    /// Duration of each enqueued segment, in queue order, and how many have
    /// finished playing — together these turn per-item time into a position
    /// within the whole narration.
    private var segmentDurations: [TimeInterval] = []
    private var finishedSegments = 0
    /// Distinguishes "the listener paused" from "the queue ran dry while the
    /// next chunk was still rendering" — only the former must stay stopped.
    private var isPausedByUser = false

    private var playedSegmentsDuration: TimeInterval {
        segmentDurations.prefix(finishedSegments).reduce(0, +)
    }

    private override init() {
        super.init()
        installTimeObserver()
        installAudioNotifications()
        installRemoteCommands()
    }

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        notificationObservers.forEach(NotificationCenter.default.removeObserver)
        itemEndObservers.forEach(NotificationCenter.default.removeObserver)
    }

    func play(url: URL, title: String, author: String, coverImagePath: String?) throws {
        try configureAudioSession()
        if currentURL != url || isStreaming {
            resetQueue()
            currentURL = url
            self.title = title
            self.author = author
            self.coverImagePath = coverImagePath
            enqueue(url: url)
            currentTime = 0
            duration = 0
        }
        player.playImmediately(atRate: playbackRate)
        isPlaying = true
        updateNowPlayingInfo()
    }

    // MARK: - Streaming playback

    /// Begin playing a narration whose chunks are still rendering. Call
    /// `appendStreamingSegment` as each chunk lands and `finishStreaming` when
    /// the complete asset has been written.
    func beginStreaming(
        title: String,
        author: String,
        coverImagePath: String?,
        expectedSegments: Int
    ) throws {
        try configureAudioSession()
        resetQueue()
        self.title = title
        self.author = author
        self.coverImagePath = coverImagePath
        self.expectedSegments = expectedSegments
        isStreaming = true
        isPausedByUser = false
        currentURL = nil
        currentTime = 0
        duration = 0
        updateNowPlayingInfo()
    }

    /// Add a freshly rendered chunk. Playback starts on the first one, and
    /// resumes here if the renderer briefly fell behind and the queue drained.
    func appendStreamingSegment(url: URL) {
        guard isStreaming else { return }
        enqueue(url: url)
        streamedSegments = segmentDurations.count
        duration = segmentDurations.reduce(0, +)

        // Start on the first chunk, and resume whenever the queue drained
        // because rendering briefly fell behind. `isPlaying` cannot gate this:
        // running dry sets it false, which would then strand playback forever
        // with chunks still arriving. Only a deliberate pause should stop it.
        if streamedSegments == 1 || (player.rate == 0 && !isPausedByUser) {
            player.playImmediately(atRate: playbackRate)
            isPlaying = true
        }
        updateNowPlayingInfo()
    }

    /// All chunks rendered. `finalURL` is the combined asset that later plays
    /// are served from; the queue keeps playing, so nothing is interrupted.
    func finishStreaming(finalURL: URL, duration totalDuration: TimeInterval) {
        guard isStreaming else { return }
        isStreaming = false
        currentURL = finalURL
        if totalDuration.isFinite, totalDuration > 0 {
            duration = totalDuration
        }
        updateNowPlayingInfo()
    }

    func cancelStreaming() {
        guard isStreaming else { return }
        isStreaming = false
        stop()
    }

    private func enqueue(url: URL) {
        let item = AVPlayerItem(url: url)
        segmentDurations.append(Self.localDuration(of: url))
        itemEndObservers.append(
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.finishedSegments = min(self.finishedSegments + 1, self.segmentDurations.count)
                }
            }
        )
        player.insert(item, after: player.items().last)
    }

    private func resetQueue() {
        isPausedByUser = false
        player.pause()
        player.removeAllItems()
        itemEndObservers.forEach(NotificationCenter.default.removeObserver)
        itemEndObservers.removeAll()
        segmentDurations.removeAll()
        finishedSegments = 0
        streamedSegments = 0
        expectedSegments = 0
        isStreaming = false
    }

    /// Duration of a local audio file, read directly rather than awaited — the
    /// queue needs it synchronously to keep the position arithmetic right.
    private static func localDuration(of url: URL) -> TimeInterval {
        guard let file = try? AVAudioFile(forReading: url), file.fileFormat.sampleRate > 0 else {
            return 0
        }
        return Double(file.length) / file.fileFormat.sampleRate
    }

    func toggle() {
        isPlaying ? pause() : resume()
    }

    func pause() {
        isPausedByUser = true
        player.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }

    func resume() {
        isPausedByUser = false
        guard player.currentItem != nil else { return }
        player.playImmediately(atRate: playbackRate)
        isPlaying = true
        updateNowPlayingInfo()
    }

    func stop() {
        resetQueue()
        currentURL = nil
        currentTime = 0
        duration = 0
        isPlaying = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func seek(to seconds: TimeInterval) {
        // While chunks are still rendering the queue is incomplete, so a
        // scrub target cannot be mapped to a position yet.
        guard !isStreaming, seconds.isFinite else { return }
        let target = max(0, min(seconds, duration > 0 ? duration : seconds))
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
        currentTime = target
        updateNowPlayingInfo()
    }

    func setRate(_ rate: Float) {
        playbackRate = max(0.75, min(rate, 2))
        if isPlaying { player.rate = playbackRate }
        updateNowPlayingInfo()
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playback,
            mode: NarrationPlaybackPolicy.mode,
            options: NarrationPlaybackPolicy.options
        )
        try session.setActive(true)
    }

    private func installTimeObserver() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                let itemTime = time.seconds.isFinite ? max(0, time.seconds) : 0
                // A streamed narration plays as a queue of chunks, so position
                // is everything already played plus the current chunk's time.
                self.currentTime = self.segmentDurations.count > 1
                    ? self.playedSegmentsDuration + itemTime
                    : itemTime
                let itemDuration = self.player.currentItem?.duration.seconds ?? 0
                if self.segmentDurations.count > 1 {
                    let known = self.segmentDurations.reduce(0, +)
                    if known > 0 { self.duration = known }
                } else if itemDuration.isFinite && itemDuration > 0 {
                    self.duration = itemDuration
                }
                if self.player.currentItem?.status == .readyToPlay,
                   self.player.rate == 0,
                   self.duration > 0,
                   self.currentTime >= self.duration - 0.25 {
                    self.isPlaying = false
                }
                self.updateNowPlayingInfo()
            }
        }
    }

    private func installAudioNotifications() {
        let center = NotificationCenter.default
        notificationObservers.append(
            center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: AVAudioSession.sharedInstance(),
                queue: .main
            ) { [weak self] note in
                Task { @MainActor in self?.handleInterruption(note) }
            }
        )
        notificationObservers.append(
            center.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: AVAudioSession.sharedInstance(),
                queue: .main
            ) { [weak self] note in
                Task { @MainActor in self?.handleRouteChange(note) }
            }
        )
    }

    private func handleInterruption(_ notification: Notification) {
        guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        switch type {
        case .began:
            pause()
        case .ended:
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            if AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume) {
                resume()
            }
        @unknown default:
            pause()
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              AVAudioSession.RouteChangeReason(rawValue: rawReason) == .oldDeviceUnavailable else { return }
        pause()
    }

    private func installRemoteCommands() {
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resume() }
            return .success
        }
        commands.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        commands.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.seek(to: event.positionTime) }
            return .success
        }
        commands.changePlaybackRateCommand.supportedPlaybackRates = [0.75, 1, 1.25, 1.5, 2]
        commands.changePlaybackRateCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackRateCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.setRate(event.playbackRate) }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard currentURL != nil else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: author,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? playbackRate : 0
        ]
        if duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration }

        if let coverImagePath,
           let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
           let image = UIImage(contentsOfFile: documents.appendingPathComponent(coverImagePath).path) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
