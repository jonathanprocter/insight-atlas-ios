import XCTest
@testable import InsightAtlas

final class MegaTranscriptNarrationTests: XCTestCase {
    private let voiceJSON = """
    {
      "status": true,
      "total": 2,
      "voices": [
        {
          "id": 22,
          "name": "Arthur",
          "language_code": "en",
          "gender": "male",
          "provider": "chatterbox",
          "emotion_aware": true
        },
        {
          "id": 1,
          "name": "Mia",
          "language_code": "en",
          "gender": "female",
          "provider": "chatterbox",
          "emotion_aware": true
        }
      ]
    }
    """

    private let ttsJSON = """
    {
      "id": "job-id",
      "status": "complete",
      "task_name": "TTS API Sync: Arthur",
      "task_type": "tts",
      "created_at": 1763306175,
      "total_chars": 1000,
      "results": {
        "data": "path/to/generated.wav",
        "cost": 0.015,
        "msg": "success",
        "status": 0,
        "user_id": 123,
        "file_url": "https://cdn.example.test/generated-audio.wav"
      }
    }
    """

    override func tearDown() {
        MegaTranscriptURLProtocol.handler = nil
        super.tearDown()
    }

    func testVoiceListDecoding() throws {
        let response = try JSONDecoder().decode(
            MegaTranscriptVoiceListResponse.self,
            from: Data(voiceJSON.utf8)
        )

        XCTAssertTrue(response.status)
        XCTAssertEqual(response.total, 2)
        XCTAssertEqual(response.voices.first?.name, "Arthur")
        XCTAssertEqual(response.voices.first?.languageCode, "en")
        XCTAssertEqual(response.voices.first?.emotionAware, true)
    }

    func testTTSResponseDecodingExtractsFileURL() throws {
        let response = try JSONDecoder().decode(
            MegaTranscriptTTSResponse.self,
            from: Data(ttsJSON.utf8)
        )

        XCTAssertEqual(response.results.fileURL, "https://cdn.example.test/generated-audio.wav")
        XCTAssertEqual(response.results.cost, 0.015)
    }

    func testTTSResponseIgnoresUnneededVendorMetadataTypeDrift() throws {
        let json = """
        {
          "id": 51,
          "status": "complete",
          "task_name": null,
          "created_at": "1763306175",
          "total_chars": "1000",
          "results": {
            "data": null,
            "cost": "0.015",
            "msg": { "text": "success" },
            "status": "0",
            "user_id": "tenant-5480896007076446",
            "file_url": "https://cdn.example.test/runtime-audio.wav",
            "new_vendor_field": "ignored"
          }
        }
        """

        let response = try JSONDecoder().decode(
            MegaTranscriptTTSResponse.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(response.id, "51")
        XCTAssertEqual(response.createdAt, 1_763_306_175)
        XCTAssertEqual(response.totalChars, 1_000)
        XCTAssertEqual(response.results.cost, 0.015)
        XCTAssertEqual(response.results.status, 0)
        XCTAssertNil(response.results.userID)
        XCTAssertEqual(response.results.fileURL, "https://cdn.example.test/runtime-audio.wav")
        XCTAssertTrue(response.indicatesCompletedAudio)
    }

    func testTTSResponseAcceptsCompletedJobLevelFileURL() throws {
        let json = """
        {
          "id": "job-id",
          "status": "completed",
          "cost": "0.02",
          "file_url": "https://cdn.example.test/job-level-audio.wav"
        }
        """

        let response = try JSONDecoder().decode(
            MegaTranscriptTTSResponse.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(response.results.fileURL, "https://cdn.example.test/job-level-audio.wav")
        XCTAssertEqual(response.results.cost, 0.02)
        XCTAssertTrue(response.indicatesCompletedAudio)
    }

    func testVoiceListToleratesNullableDisplayMetadataAndScalarStrings() throws {
        let json = """
        {
          "status": "true",
          "total": "1",
          "voices": [
            {
              "id": "22",
              "name": "Arthur",
              "language_code": "en",
              "gender": null,
              "emotion_aware": "true"
            }
          ]
        }
        """

        let response = try JSONDecoder().decode(
            MegaTranscriptVoiceListResponse.self,
            from: Data(json.utf8)
        )

        XCTAssertTrue(response.status)
        XCTAssertEqual(response.total, 1)
        XCTAssertEqual(response.voices.first?.id, 22)
        XCTAssertEqual(response.voices.first?.name, "Arthur")
        XCTAssertEqual(response.voices.first?.gender, "unspecified")
        XCTAssertEqual(response.voices.first?.provider, "Mega Transcript")
        XCTAssertEqual(response.voices.first?.emotionAware, true)
    }

    func testPreferredNarratorOrder() {
        let arthur = voice(id: 22, name: "  ARTHUR  ", emotionAware: true)
        let mia = voice(id: 1, name: "Mia", emotionAware: true)
        let emotive = voice(id: 3, name: "Emotive", emotionAware: true)
        let plain = voice(id: 4, name: "Plain", emotionAware: false)

        XCTAssertEqual(MegaTranscriptVoice.preferred(in: [plain, mia, arthur])?.id, arthur.id)
        XCTAssertEqual(MegaTranscriptVoice.preferred(in: [plain, emotive, mia])?.id, mia.id)
        XCTAssertEqual(MegaTranscriptVoice.preferred(in: [plain, emotive])?.id, emotive.id)
        XCTAssertEqual(MegaTranscriptVoice.preferred(in: [plain])?.id, plain.id)
    }

    func testPreferredNarratorIgnoresNonEnglishVoices() {
        let nonEnglishArthur = MegaTranscriptVoice(
            id: 22,
            name: "Arthur",
            languageCode: "fr",
            gender: "male",
            provider: "test",
            emotionAware: true
        )
        let english = voice(id: 7, name: "English", emotionAware: false)
        XCTAssertEqual(MegaTranscriptVoice.preferred(in: [nonEnglishArthur, english])?.id, english.id)
    }

    func testHTTPErrorMapping() async {
        let expectations: [(Int, (MegaTranscriptError) -> Bool)] = [
            (401, { if case .unauthorized = $0 { return true }; return false }),
            (403, { if case .forbidden = $0 { return true }; return false }),
            (408, { if case .generationTimedOut = $0 { return true }; return false }),
            (429, { if case .rateLimited = $0 { return true }; return false }),
            (500, { if case .serverError(statusCode: 500, detail: _) = $0 { return true }; return false })
        ]

        for (statusCode, matches) in expectations {
            MegaTranscriptURLProtocol.handler = { request in
                guard let url = request.url,
                      let response = HTTPURLResponse(
                    url: url,
                    statusCode: statusCode,
                    httpVersion: nil,
                    headerFields: nil
                ) else { throw URLError(.badURL) }
                return (response, Data("{\"detail\":\"test detail\"}".utf8))
            }

            do {
                _ = try await makeService().listEnglishVoices()
                XCTFail("Expected HTTP \(statusCode) to throw")
            } catch let error as MegaTranscriptError {
                XCTAssertTrue(matches(error), "Unexpected mapping for HTTP \(statusCode): \(error)")
            } catch {
                XCTFail("Unexpected error type for HTTP \(statusCode): \(error)")
            }
        }
    }

    func testMissingFileURLIsRejectedBeforeDownload() async throws {
        let service = MegaTranscriptMockService()
        service.generatedResponse = response(fileURL: nil)
        let fixture = try makeCoordinator(service: service)
        defer { fixture.cleanup() }

        do {
            _ = try await fixture.coordinator.synthesize(text: "Summary", itemID: UUID())
            XCTFail("Expected missingAudioURL")
        } catch MegaTranscriptError.missingAudioURL {
            XCTAssertEqual(service.downloadCount, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCredentialStoreAbstractionRoundTrip() throws {
        let store = InMemoryMegaTranscriptCredentialStore()
        XCTAssertFalse(store.hasAPIKey)
        try store.saveAPIKey("replacement-test-value")
        XCTAssertTrue(store.hasAPIKey)
        XCTAssertEqual(try store.loadAPIKey(), "replacement-test-value")
        try store.deleteAPIKey()
        XCTAssertFalse(store.hasAPIKey)
    }

    func testCacheKeyIsStableAndSensitiveToTextAndVoice() {
        let key = MegaTranscriptNarrationCache.cacheKey(text: "Exact summary", voiceID: 22)
        XCTAssertEqual(key, MegaTranscriptNarrationCache.cacheKey(text: "Exact summary", voiceID: 22))
        XCTAssertNotEqual(key, MegaTranscriptNarrationCache.cacheKey(text: "Exact summary ", voiceID: 22))
        XCTAssertNotEqual(key, MegaTranscriptNarrationCache.cacheKey(text: "Exact summary", voiceID: 1))
        XCTAssertEqual(key.count, 64)
    }

    func testCachedNarrationAvoidsSecondVendorRequest() async throws {
        let service = MegaTranscriptMockService()
        let fixture = try makeCoordinator(service: service)
        defer { fixture.cleanup() }

        let first = try await fixture.coordinator.synthesize(text: "Exact summary", itemID: UUID())
        let second = try await fixture.coordinator.synthesize(text: "Exact summary", itemID: UUID())

        XCTAssertFalse(first.cacheHit)
        XCTAssertTrue(second.cacheHit)
        XCTAssertEqual(service.listCount, 1)
        XCTAssertEqual(service.generateCount, 1)
        XCTAssertEqual(service.downloadCount, 1)
    }

    func testCancellationStopsGeneration() async throws {
        let service = MegaTranscriptMockService()
        service.generationDelayNanoseconds = 5_000_000_000
        let fixture = try makeCoordinator(service: service)
        defer { fixture.cleanup() }

        let task = Task {
            try await fixture.coordinator.synthesize(text: "Exact summary", itemID: UUID())
        }
        while service.generateCount == 0 { await Task.yield() }
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            // Expected: the coordinator does not start a download or fallback.
        } catch MegaTranscriptError.cancelled {
            // Also acceptable when cancellation is mapped by the concrete client.
        } catch {
            XCTFail("Unexpected cancellation error: \(error)")
        }
        XCTAssertEqual(service.downloadCount, 0)
    }

    private func makeService() -> MegaTranscriptService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MegaTranscriptURLProtocol.self]
        return MegaTranscriptService(
            baseURL: URL(string: "https://api.megatranscript.test")
                ?? MegaTranscriptService.productionBaseURL,
            session: URLSession(configuration: configuration),
            credentialStore: InMemoryMegaTranscriptCredentialStore(key: "test-only-placeholder")
        )
    }

    private func makeCoordinator(service: MegaTranscriptMockService) throws -> CoordinatorFixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MegaTranscriptTests-\(UUID().uuidString)", isDirectory: true)
        let cache = MegaTranscriptNarrationCache(
            rootDirectory: root.appendingPathComponent("cache", isDirectory: true),
            playbackDirectory: root.appendingPathComponent("playback", isDirectory: true)
        )
        let suiteName = "MegaTranscriptTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw NSError(domain: "MegaTranscriptTests", code: 1)
        }
        let preferences = MegaTranscriptNarratorPreferences(defaults: defaults)
        return CoordinatorFixture(
            coordinator: MegaTranscriptNarrationCoordinator(
                service: service,
                cache: cache,
                preferences: preferences
            ),
            root: root,
            defaults: defaults,
            suiteName: suiteName
        )
    }

    private func voice(id: Int, name: String, emotionAware: Bool) -> MegaTranscriptVoice {
        MegaTranscriptVoice(
            id: id,
            name: name,
            languageCode: "en",
            gender: "test",
            provider: "test",
            emotionAware: emotionAware
        )
    }

    private func response(fileURL: String? = "https://cdn.example.test/audio.wav") -> MegaTranscriptTTSResponse {
        MegaTranscriptTTSResponse(
            id: "job",
            status: "complete",
            taskName: "test",
            taskType: "tts",
            createdAt: 1,
            totalChars: 7,
            results: MegaTranscriptTTSResponse.Results(
                data: nil,
                cost: 0.01,
                msg: "success",
                status: 0,
                userID: 1,
                fileURL: fileURL
            )
        )
    }
}

private struct CoordinatorFixture {
    let coordinator: MegaTranscriptNarrationCoordinator
    let root: URL
    let defaults: UserDefaults
    let suiteName: String

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
        defaults.removePersistentDomain(forName: suiteName)
    }
}

private final class InMemoryMegaTranscriptCredentialStore: MegaTranscriptCredentialStore {
    private var key: String?

    init(key: String? = nil) {
        self.key = key
    }

    var hasAPIKey: Bool {
        !(key?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    func loadAPIKey() throws -> String? { key }

    func saveAPIKey(_ key: String) throws {
        self.key = key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func deleteAPIKey() throws { key = nil }
}

private final class MegaTranscriptMockService: MegaTranscriptServicing {
    var voices = [
        MegaTranscriptVoice(
            id: 22,
            name: "Arthur",
            languageCode: "en",
            gender: "male",
            provider: "test",
            emotionAware: true
        )
    ]
    var generatedResponse = MegaTranscriptTTSResponse(
        id: "job",
        status: "complete",
        taskName: "test",
        taskType: "tts",
        createdAt: 1,
        totalChars: 7,
        results: .init(
            data: nil,
            cost: 0.01,
            msg: "success",
            status: 0,
            userID: 1,
            fileURL: "https://cdn.example.test/audio.wav"
        )
    )
    var generationDelayNanoseconds: UInt64 = 0
    private(set) var listCount = 0
    private(set) var generateCount = 0
    private(set) var downloadCount = 0

    var isConfigured: Bool { true }

    func listEnglishVoices() async throws -> [MegaTranscriptVoice] {
        listCount += 1
        return voices
    }

    func generateNarration(text: String, voiceID: Int) async throws -> MegaTranscriptTTSResponse {
        generateCount += 1
        if generationDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: generationDelayNanoseconds)
        }
        return generatedResponse
    }

    func downloadAudio(from url: URL) async throws -> Data {
        downloadCount += 1
        return Data("RIFF-test-audio".utf8)
    }
}

private final class MegaTranscriptURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let handler = Self.handler else {
                throw URLError(.badServerResponse)
            }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
