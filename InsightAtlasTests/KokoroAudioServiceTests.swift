import XCTest
@testable import InsightAtlas

final class KokoroAudioServiceTests: XCTestCase {
    func testProviderAndConfigurationReflectInjectedModelAvailability() async throws {
        let unavailable = KokoroAudioService(
            engine: KokoroSynthesisSpy(),
            isModelInstalled: { false }
        )
        let available = KokoroAudioService(
            engine: KokoroSynthesisSpy(),
            isModelInstalled: { true }
        )

        let unavailableValidation = try await unavailable.validateApiKey()
        let availableValidation = try await available.validateApiKey()

        XCTAssertEqual(unavailable.provider, .kokoro)
        XCTAssertFalse(unavailable.isConfigured)
        XCTAssertFalse(unavailableValidation)
        XCTAssertTrue(available.isConfigured)
        XCTAssertTrue(availableValidation)
    }

    func testBlankTextFailsBeforeModelOrEngineWork() async {
        let engine = KokoroSynthesisSpy()
        let service = KokoroAudioService(
            engine: engine,
            isModelInstalled: { false }
        )

        do {
            _ = try await service.generateAudio(text: "  \n ", voiceID: "af_heart")
            XCTFail("Expected empty text to fail")
        } catch KokoroAudioError.emptyText {
            let callCount = await engine.callCount
            XCTAssertEqual(callCount, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testUnavailableModelFailsWithoutCallingEngine() async {
        let engine = KokoroSynthesisSpy()
        let service = KokoroAudioService(
            engine: engine,
            isModelInstalled: { false }
        )

        do {
            _ = try await service.generateAudio(text: "Hello", voiceID: "af_heart")
            XCTFail("Expected unavailable model to fail")
        } catch KokoroAudioError.modelNotInstalled {
            let callCount = await engine.callCount
            XCTAssertEqual(callCount, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testUnknownVoiceFailsWithoutCallingEngine() async {
        let engine = KokoroSynthesisSpy()
        let service = KokoroAudioService(
            engine: engine,
            isModelInstalled: { true }
        )

        do {
            _ = try await service.generateAudio(text: "Hello", voiceID: "not-a-voice")
            XCTFail("Expected invalid voice to fail")
        } catch KokoroAudioError.invalidVoiceID {
            let callCount = await engine.callCount
            XCTAssertEqual(callCount, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testGenerateRoutesHeartToSpeakerThreeAndPreservesMetadata() async throws {
        let expectedData = Data([0x52, 0x49, 0x46, 0x46])
        let modelDirectory = URL(fileURLWithPath: "/tmp/kokoro-test-model", isDirectory: true)
        let engine = KokoroSynthesisSpy(
            result: KokoroSynthesisResult(data: expectedData, duration: 2.5)
        )
        let service = KokoroAudioService(
            engine: engine,
            isModelInstalled: { true },
            modelDirectoryProvider: { modelDirectory }
        )

        let audio = try await service.generateAudio(
            text: "  Hello world  ",
            voiceID: "af_heart"
        )

        XCTAssertEqual(audio.data, expectedData)
        XCTAssertEqual(audio.duration, 2.5, accuracy: 0.001)
        XCTAssertEqual(audio.characterCount, 11)
        XCTAssertEqual(audio.voiceID, "af_heart")

        let call = await engine.lastCall
        XCTAssertEqual(call?.text, "Hello world")
        XCTAssertEqual(call?.speakerID, 3)
        XCTAssertEqual(call?.modelDirectory, modelDirectory)
    }

    func testCancellationPropagatesBeforeEngineStarts() async {
        let engine = KokoroSynthesisSpy()
        let service = KokoroAudioService(
            engine: engine,
            isModelInstalled: { true }
        )

        let error = await Task { () -> Error? in
            withUnsafeCurrentTask { $0?.cancel() }
            do {
                _ = try await service.generateAudio(text: "Hello", voiceID: "af_heart")
                return nil
            } catch {
                return error
            }
        }.value

        XCTAssertTrue(error is CancellationError)
        let callCount = await engine.callCount
        XCTAssertEqual(callCount, 0)
    }

    func testResetForwardsToEngine() async {
        let engine = KokoroSynthesisSpy()
        let service = KokoroAudioService(
            engine: engine,
            isModelInstalled: { true }
        )

        await service.reset()

        let resetCount = await engine.resetCount
        XCTAssertEqual(resetCount, 1)
    }
}

private actor KokoroSynthesisSpy: KokoroSynthesizing {
    struct Call: Equatable {
        let text: String
        let speakerID: Int
        let modelDirectory: URL
    }

    private(set) var calls: [Call] = []
    private(set) var resetCount = 0
    private let result: KokoroSynthesisResult

    init(
        result: KokoroSynthesisResult = KokoroSynthesisResult(
            data: Data([0x52, 0x49, 0x46, 0x46]),
            duration: 1
        )
    ) {
        self.result = result
    }

    var callCount: Int { calls.count }
    var lastCall: Call? { calls.last }

    func generate(
        text: String,
        speakerID: Int,
        modelDirectory: URL
    ) async throws -> KokoroSynthesisResult {
        calls.append(
            Call(
                text: text,
                speakerID: speakerID,
                modelDirectory: modelDirectory
            )
        )
        return result
    }

    func reset() async {
        resetCount += 1
    }
}
