import XCTest
@testable import InsightAtlas

/// Drives the real Kokoro model through real synthesis.
///
/// Every other narration test uses a spy, so a broken model configuration
/// passes them all and fails only on a device. This one loads the actual
/// downloaded model and asserts audio comes out.
///
/// The simulator shares the host filesystem, so the model is read from a path
/// supplied by `KOKORO_MODEL_DIR`. Without it the test skips rather than fails,
/// so CI (which has no model) stays green.
final class KokoroLiveSynthesisTests: XCTestCase {

    /// Well-known location checked when the environment variable is absent.
    /// xcodebuild does not reliably forward the shell environment into the
    /// simulator test process, and the simulator shares the host filesystem,
    /// so a fixed path is the dependable channel.
    private static let conventionalPath = "/private/tmp/insightatlas-kokoro-model"

    private var modelDirectory: URL? {
        if let path = ProcessInfo.processInfo.environment["KOKORO_MODEL_DIR"], !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: Self.conventionalPath, isDirectory: &isDirectory),
              isDirectory.boolValue else { return nil }
        return URL(fileURLWithPath: Self.conventionalPath, isDirectory: true)
    }

    func testModelDirectoryPassesInstallationValidation() throws {
        guard let directory = modelDirectory else {
            throw XCTSkip("Set KOKORO_MODEL_DIR to run live synthesis tests")
        }
        XCTAssertTrue(
            KokoroModelInstallationValidator.isInstalled(at: directory),
            "the downloaded model should satisfy the installation validator"
        )
    }

    /// The load-bearing test: does the shipped configuration actually produce
    /// audio from the shipped model?
    func testRealSynthesisProducesAudio() async throws {
        guard let directory = modelDirectory else {
            throw XCTSkip("Set KOKORO_MODEL_DIR to run live synthesis tests")
        }

        let engine = KokoroSynthesisEngine()
        var progressReports: [(Int, Int)] = []

        let result = try await engine.generate(
            text: "Willingness is not resignation. It is a choice made in the presence of discomfort.",
            speakerID: KokoroVoiceRegistry.defaultVoice.speakerID,
            modelDirectory: directory,
            onModelLoadStart: nil,
            onProgress: { completed, total in
                progressReports.append((completed, total))
            }
        )

        XCTAssertFalse(result.data.isEmpty, "synthesis produced no audio data")
        XCTAssertGreaterThan(result.duration, 0, "synthesis produced zero-length audio")
        XCTAssertFalse(progressReports.isEmpty, "no progress was reported")
        XCTAssertEqual(
            progressReports.last?.0, progressReports.last?.1,
            "the final progress report should be complete"
        )
    }

    /// Every registered voice must exist in the model. A speaker id beyond the
    /// model's range yields empty samples, which surfaces as a generation
    /// failure rather than anything diagnosable.
    func testEveryRegisteredVoiceSynthesizes() async throws {
        guard let directory = modelDirectory else {
            throw XCTSkip("Set KOKORO_MODEL_DIR to run live synthesis tests")
        }

        let engine = KokoroSynthesisEngine()
        var failures: [String] = []

        for voice in KokoroVoiceRegistry.allVoices {
            do {
                let result = try await engine.generate(
                    text: "Testing one two three.",
                    speakerID: voice.speakerID,
                    modelDirectory: directory,
                    onModelLoadStart: nil,
                    onProgress: nil
                )
                if result.data.isEmpty {
                    failures.append("\(voice.name) (id \(voice.speakerID)): empty audio")
                }
            } catch {
                failures.append("\(voice.name) (id \(voice.speakerID)): \(error)")
            }
        }

        XCTAssertTrue(failures.isEmpty, "voices failed to synthesize: \(failures.joined(separator: "; "))")
    }
}
