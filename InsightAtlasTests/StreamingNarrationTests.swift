import AVFoundation
import XCTest
@testable import InsightAtlas

/// Streaming playback plays a narration as a queue of chunks while later chunks
/// are still rendering. The risk is bookkeeping: a segment that is not actually
/// playable, or position arithmetic that treats per-chunk time as whole-guide
/// time.
@MainActor
final class StreamingNarrationTests: XCTestCase {

    private var scratch: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("streaming-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let scratch { try? FileManager.default.removeItem(at: scratch) }
        scratch = nil
        try super.tearDownWithError()
    }

    /// Writes `seconds` of silence as a 24 kHz mono WAV, matching Kokoro output.
    @discardableResult
    private func writeSegment(named name: String, seconds: Double) throws -> URL {
        let url = scratch.appendingPathComponent(name)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 24_000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        var file: AVAudioFile? = try AVAudioFile(forWriting: url, settings: settings)
        guard let format = file?.processingFormat else { return url }
        let frames = AVAudioFrameCount(24_000 * seconds)
        if let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) {
            buffer.frameLength = frames
            if let channel = buffer.floatChannelData?[0] {
                for i in 0..<Int(frames) { channel[i] = 0 }
            }
            try file?.write(from: buffer)
        }
        file = nil
        return url
    }

    /// Each streamed chunk must be an independently playable file the moment it
    /// is handed over — a half-written one would stall the queue.
    func testStreamedSegmentIsImmediatelyPlayable() throws {
        let url = try writeSegment(named: "seg_0000.wav", seconds: 1.5)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let file = try AVAudioFile(forReading: url)
        let duration = Double(file.length) / file.fileFormat.sampleRate
        XCTAssertEqual(duration, 1.5, accuracy: 0.05)
    }

    /// The controller must report position across the whole narration, not
    /// within the current chunk, or a 16-minute guide would appear to restart
    /// its timer every chunk.
    func testQueuePositionAccumulatesAcrossSegments() throws {
        let controller = NarrationPlaybackController.shared
        controller.stop()

        let first = try writeSegment(named: "seg_0000.wav", seconds: 2.0)
        let second = try writeSegment(named: "seg_0001.wav", seconds: 3.0)

        try controller.beginStreaming(
            title: "T", author: "A", coverImagePath: nil, expectedSegments: 2
        )
        XCTAssertTrue(controller.isStreaming)

        controller.appendStreamingSegment(url: first)
        XCTAssertEqual(controller.streamedSegments, 1)
        XCTAssertEqual(controller.duration, 2.0, accuracy: 0.1)

        controller.appendStreamingSegment(url: second)
        XCTAssertEqual(controller.streamedSegments, 2)
        XCTAssertEqual(
            controller.duration, 5.0, accuracy: 0.1,
            "duration must be the sum of every rendered chunk"
        )

        controller.stop()
        XCTAssertFalse(controller.isStreaming)
    }

    /// Scrubbing cannot be honored until the full asset exists, because the
    /// queue is still incomplete.
    func testSeekIsIgnoredWhileStreaming() throws {
        let controller = NarrationPlaybackController.shared
        controller.stop()
        let first = try writeSegment(named: "seg_0000.wav", seconds: 2.0)

        try controller.beginStreaming(
            title: "T", author: "A", coverImagePath: nil, expectedSegments: 1
        )
        controller.appendStreamingSegment(url: first)
        controller.seek(to: 1.0)
        XCTAssertEqual(controller.currentTime, 0, accuracy: 0.001)

        controller.stop()
    }

    /// Handing over the combined asset ends streaming without stopping audio.
    func testFinishStreamingAdoptsTheCombinedAsset() throws {
        let controller = NarrationPlaybackController.shared
        controller.stop()

        let segment = try writeSegment(named: "seg_0000.wav", seconds: 2.0)
        let combined = try writeSegment(named: "audio_combined.wav", seconds: 6.0)

        try controller.beginStreaming(
            title: "T", author: "A", coverImagePath: nil, expectedSegments: 1
        )
        controller.appendStreamingSegment(url: segment)
        controller.finishStreaming(finalURL: combined, duration: 6.0)

        XCTAssertFalse(controller.isStreaming, "streaming must end")
        XCTAssertEqual(controller.currentURL, combined, "later plays use the durable asset")
        XCTAssertEqual(controller.duration, 6.0, accuracy: 0.1)

        controller.stop()
    }

    /// Segment files live in a per-item directory that is cleared between runs.
    func testSegmentDirectoryIsPerItemAndClearable() throws {
        let itemId = UUID()
        let dir = NarrationService.segmentDirectory(for: itemId)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let marker = dir.appendingPathComponent("seg_0000.wav")
        try Data([0x52, 0x49, 0x46, 0x46]).write(to: marker)
        XCTAssertTrue(FileManager.default.fileExists(atPath: marker.path))

        NarrationService.clearSegments(for: itemId)
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: dir.path),
            "a finished or abandoned render must not leave chunks behind"
        )
        XCTAssertTrue(dir.path.contains(itemId.uuidString), "directories must not collide across guides")
    }
}
