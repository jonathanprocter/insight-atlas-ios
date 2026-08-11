//
//  KokoroModelManager.swift
//  InsightAtlas
//
//  Secure lifecycle management for the optional Kokoro offline voice model.
//

import Combine
import CryptoKit
import Foundation
import SWCompression

struct KokoroModelManifest: Equatable, Sendable {
    let version: String
    let archiveRootName: String
    let downloadURL: URL
    let archiveByteCount: Int64
    let sha256: String
    let minimumAvailableCapacity: Int64

    static let production = KokoroModelManifest(
        version: "kokoro-int8-multi-lang-v1_0",
        archiveRootName: "kokoro-int8-multi-lang-v1_0",
        downloadURL: URL(
            string: "https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-int8-multi-lang-v1_0.tar.bz2"
        )!,
        archiveByteCount: 131_839_838,
        sha256: "75654a84864be26f345f020f4070c2c019e96dd1b7f9bf6e2ffd59efac6aa5a3",
        minimumAvailableCapacity: 450 * 1_024 * 1_024
    )
}

enum KokoroModelStore {
    static func modelsRoot(fileManager: FileManager = .default) -> URL {
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory

        return applicationSupport
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent("Kokoro", isDirectory: true)
    }

    static func modelDirectory(
        manifest: KokoroModelManifest = .production,
        fileManager: FileManager = .default
    ) -> URL {
        modelsRoot(fileManager: fileManager)
            .appendingPathComponent(manifest.version, isDirectory: true)
    }

    static var isInstalled: Bool {
        KokoroModelInstallationValidator.isInstalled(
            at: modelDirectory()
        )
    }
}

enum KokoroModelInstallationValidator {
    static let requiredRelativePaths = [
        "model.int8.onnx",
        "voices.bin",
        "tokens.txt",
        "lexicon-us-en.txt",
        "lexicon-gb-en.txt",
        "LICENSE",
        "espeak-ng-data/phondata"
    ]

    static func isInstalled(
        at directory: URL,
        fileManager: FileManager = .default
    ) -> Bool {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(
            atPath: directory.path,
            isDirectory: &isDirectory
        ), isDirectory.boolValue else {
            return false
        }

        return requiredRelativePaths.allSatisfy { relativePath in
            let fileURL = directory.appendingPathComponent(relativePath)
            guard fileManager.fileExists(atPath: fileURL.path),
                  let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                  let size = attributes[.size] as? NSNumber else {
                return false
            }
            return size.int64Value > 0
        }
    }
}

enum KokoroArchivePathPolicy {
    private static let exactAllowedPaths: Set<String> = [
        "model.int8.onnx",
        "voices.bin",
        "tokens.txt",
        "lexicon-us-en.txt",
        "lexicon-gb-en.txt",
        "LICENSE"
    ]

    static func destinationRelativePath(
        for entryName: String,
        archiveRoot: String
    ) -> String? {
        let normalized = entryName.replacingOccurrences(of: "\\", with: "/")
        guard !normalized.hasPrefix("/") else { return nil }

        let components = normalized.split(
            separator: "/",
            omittingEmptySubsequences: false
        ).map(String.init)

        guard components.count > 1,
              components.first == archiveRoot,
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            return nil
        }

        let relativeComponents = Array(components.dropFirst())
        let relativePath = relativeComponents.joined(separator: "/")

        if exactAllowedPaths.contains(relativePath) {
            return relativePath
        }

        if relativeComponents.first == "espeak-ng-data", relativeComponents.count > 1 {
            return relativePath
        }

        return nil
    }
}

enum KokoroModelInstallState: Equatable, Sendable {
    case notInstalled
    case preparing
    case downloading(progress: Double)
    case verifying
    case extracting
    case installed
    case failed(message: String)

    var isBusy: Bool {
        switch self {
        case .preparing, .downloading, .verifying, .extracting:
            return true
        case .notInstalled, .installed, .failed:
            return false
        }
    }
}

enum KokoroModelError: LocalizedError {
    case insufficientStorage(required: Int64, available: Int64)
    case invalidResponse
    case unexpectedArchiveSize(expected: Int64, actual: Int64)
    case checksumMismatch
    case extractionFailed
    case incompleteInstallation

    var errorDescription: String? {
        switch self {
        case .insufficientStorage(let required, let available):
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return "Kokoro needs at least \(formatter.string(fromByteCount: required)) free. This device currently reports \(formatter.string(fromByteCount: available))."
        case .invalidResponse:
            return "The Kokoro model download did not return a valid response."
        case .unexpectedArchiveSize:
            return "The Kokoro model download was incomplete. Please try again."
        case .checksumMismatch:
            return "The downloaded Kokoro model failed its integrity check and was discarded."
        case .extractionFailed:
            return "The Kokoro model archive could not be safely extracted."
        case .incompleteInstallation:
            return "The Kokoro model is missing one or more required files."
        }
    }
}

@MainActor
final class KokoroModelManager: ObservableObject {
    static let shared = KokoroModelManager()

    @Published private(set) var state: KokoroModelInstallState

    let manifest: KokoroModelManifest

    private let fileManager: FileManager
    private var installTask: Task<Void, Never>?

    init(
        manifest: KokoroModelManifest = .production,
        fileManager: FileManager = .default
    ) {
        self.manifest = manifest
        self.fileManager = fileManager
        self.state = KokoroModelInstallationValidator.isInstalled(
            at: KokoroModelStore.modelDirectory(
                manifest: manifest,
                fileManager: fileManager
            ),
            fileManager: fileManager
        ) ? .installed : .notInstalled
    }

    var modelDirectory: URL {
        KokoroModelStore.modelDirectory(
            manifest: manifest,
            fileManager: fileManager
        )
    }

    var isInstalled: Bool {
        if case .installed = state { return true }
        return false
    }

    func refreshState() {
        state = KokoroModelInstallationValidator.isInstalled(
            at: modelDirectory,
            fileManager: fileManager
        ) ? .installed : .notInstalled
    }

    func install() {
        guard installTask == nil, !isInstalled else { return }

        state = .preparing
        let manifest = self.manifest
        let fileManager = self.fileManager

        installTask = Task { [weak self] in
            guard let self else { return }

            do {
                try await KokoroModelInstaller.install(
                    manifest: manifest,
                    fileManager: fileManager,
                    progress: { progress in
                        Task { @MainActor in
                            self.state = .downloading(progress: progress)
                        }
                    },
                    phase: { phase in
                        Task { @MainActor in
                            self.state = phase
                        }
                    }
                )
                guard !Task.isCancelled else { throw CancellationError() }
                await KokoroAudioService.shared.reset()
                state = .installed
            } catch is CancellationError {
                refreshState()
            } catch {
                state = .failed(message: error.localizedDescription)
            }
            installTask = nil
        }
    }

    func cancelInstall() {
        installTask?.cancel()
        installTask = nil
        refreshState()
    }

    func deleteModel() throws {
        cancelInstall()
        if fileManager.fileExists(atPath: modelDirectory.path) {
            try fileManager.removeItem(at: modelDirectory)
        }
        Task { await KokoroAudioService.shared.reset() }
        state = .notInstalled
    }
}

private enum KokoroModelInstaller {
    static func install(
        manifest: KokoroModelManifest,
        fileManager: FileManager,
        progress: @escaping @Sendable (Double) -> Void,
        phase: @escaping @Sendable (KokoroModelInstallState) -> Void
    ) async throws {
        let root = KokoroModelStore.modelsRoot(fileManager: fileManager)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try requireAvailableCapacity(
            manifest.minimumAvailableCapacity,
            at: root
        )

        let stagingRoot = root.appendingPathComponent(
            ".staging-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(
            at: stagingRoot,
            withIntermediateDirectories: true
        )

        defer { try? fileManager.removeItem(at: stagingRoot) }

        let archiveURL = stagingRoot.appendingPathComponent("model.tar.bz2")
        try await download(
            manifest.downloadURL,
            to: archiveURL,
            expectedByteCount: manifest.archiveByteCount,
            progress: progress
        )
        try Task.checkCancellation()

        phase(.verifying)
        try await Task.detached(priority: .utility) {
            try verifyArchive(
                at: archiveURL,
                manifest: manifest,
                fileManager: fileManager
            )
        }.value
        try Task.checkCancellation()

        phase(.extracting)
        let stagedModel = stagingRoot.appendingPathComponent(
            manifest.version,
            isDirectory: true
        )
        try await Task.detached(priority: .userInitiated) {
            try extractArchive(
                at: archiveURL,
                to: stagedModel,
                manifest: manifest,
                fileManager: fileManager
            )
        }.value
        try Task.checkCancellation()

        guard KokoroModelInstallationValidator.isInstalled(
            at: stagedModel,
            fileManager: fileManager
        ) else {
            throw KokoroModelError.incompleteInstallation
        }

        let finalModel = KokoroModelStore.modelDirectory(
            manifest: manifest,
            fileManager: fileManager
        )
        try atomicallyReplace(
            finalModel,
            with: stagedModel,
            root: root,
            fileManager: fileManager
        )
    }

    private static func requireAvailableCapacity(
        _ required: Int64,
        at directory: URL
    ) throws {
        let values = try directory.resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey]
        )
        let available = values.volumeAvailableCapacityForImportantUsage ?? 0
        guard available >= required else {
            throw KokoroModelError.insufficientStorage(
                required: required,
                available: available
            )
        }
    }

    private static func download(
        _ sourceURL: URL,
        to destinationURL: URL,
        expectedByteCount: Int64,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let delegate = KokoroDownloadDelegate(
            destinationURL: destinationURL,
            expectedByteCount: expectedByteCount,
            progress: progress
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 900
        let session = URLSession(
            configuration: configuration,
            delegate: delegate,
            delegateQueue: nil
        )
        defer { session.finishTasksAndInvalidate() }

        try await withTaskCancellationHandler {
            try await delegate.download(
                using: session,
                from: sourceURL
            )
        } onCancel: {
            session.invalidateAndCancel()
        }
    }

    private static func verifyArchive(
        at archiveURL: URL,
        manifest: KokoroModelManifest,
        fileManager: FileManager
    ) throws {
        let attributes = try fileManager.attributesOfItem(atPath: archiveURL.path)
        let actualSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        guard actualSize == manifest.archiveByteCount else {
            throw KokoroModelError.unexpectedArchiveSize(
                expected: manifest.archiveByteCount,
                actual: actualSize
            )
        }

        let handle = try FileHandle(forReadingFrom: archiveURL)
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            try Task.checkCancellation()
            guard let data = try handle.read(upToCount: 1_048_576),
                  !data.isEmpty else {
                break
            }
            hasher.update(data: data)
        }

        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        guard digest == manifest.sha256 else {
            throw KokoroModelError.checksumMismatch
        }
    }

    private static func extractArchive(
        at archiveURL: URL,
        to destinationDirectory: URL,
        manifest: KokoroModelManifest,
        fileManager: FileManager
    ) throws {
        var compressedData: Data? = try Data(
            contentsOf: archiveURL,
            options: [.mappedIfSafe]
        )
        guard let sourceData = compressedData else {
            throw KokoroModelError.extractionFailed
        }

        let tarData = try BZip2.decompress(data: sourceData)
        compressedData = nil
        let entries = try TarContainer.open(container: tarData)

        try fileManager.createDirectory(
            at: destinationDirectory,
            withIntermediateDirectories: true
        )
        let destinationRoot = destinationDirectory.standardizedFileURL.path + "/"

        for entry in entries {
            try Task.checkCancellation()
            guard case .regular = entry.info.type,
                  let relativePath = KokoroArchivePathPolicy.destinationRelativePath(
                    for: entry.info.name,
                    archiveRoot: manifest.archiveRootName
                  ),
                  let data = entry.data else {
                continue
            }

            let destination = destinationDirectory
                .appendingPathComponent(relativePath)
                .standardizedFileURL
            guard destination.path.hasPrefix(destinationRoot) else {
                throw KokoroModelError.extractionFailed
            }

            try fileManager.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: destination, options: .atomic)
        }
    }

    private static func atomicallyReplace(
        _ finalModel: URL,
        with stagedModel: URL,
        root: URL,
        fileManager: FileManager
    ) throws {
        let backup = root.appendingPathComponent(
            ".backup-\(UUID().uuidString)",
            isDirectory: true
        )
        let hadExistingModel = fileManager.fileExists(atPath: finalModel.path)

        if hadExistingModel {
            try fileManager.moveItem(at: finalModel, to: backup)
        }

        do {
            try fileManager.moveItem(at: stagedModel, to: finalModel)
            try? fileManager.removeItem(at: backup)
        } catch {
            if hadExistingModel,
               fileManager.fileExists(atPath: backup.path),
               !fileManager.fileExists(atPath: finalModel.path) {
                try? fileManager.moveItem(at: backup, to: finalModel)
            }
            throw error
        }
    }

}

private final class KokoroDownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let destinationURL: URL
    private let expectedByteCount: Int64
    private let progress: @Sendable (Double) -> Void
    private let lock = NSLock()

    private var continuation: CheckedContinuation<Void, Error>?
    private var task: URLSessionDownloadTask?
    private var result: Result<Void, Error>?

    init(
        destinationURL: URL,
        expectedByteCount: Int64,
        progress: @escaping @Sendable (Double) -> Void
    ) {
        self.destinationURL = destinationURL
        self.expectedByteCount = expectedByteCount
        self.progress = progress
    }

    func download(
        using session: URLSession,
        from sourceURL: URL
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            lock.withLock {
                self.continuation = continuation
                let task = session.downloadTask(with: sourceURL)
                self.task = task
                task.resume()
            }
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let denominator = totalBytesExpectedToWrite > 0
            ? totalBytesExpectedToWrite
            : expectedByteCount
        guard denominator > 0 else { return }
        progress(min(max(Double(totalBytesWritten) / Double(denominator), 0), 1))
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            try? FileManager.default.removeItem(at: destinationURL)
            try FileManager.default.moveItem(at: location, to: destinationURL)
            finish(.success(()))
        } catch {
            finish(.failure(error))
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error {
            finish(.failure(error))
        }
    }

    private func finish(_ result: Result<Void, Error>) {
        let continuation: CheckedContinuation<Void, Error>? = lock.withLock {
            guard self.result == nil else { return nil }
            self.result = result
            let continuation = self.continuation
            self.continuation = nil
            self.task = nil
            return continuation
        }

        guard let continuation else { return }
        switch result {
        case .success:
            continuation.resume()
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}

private extension NSLock {
    func withLock<T>(_ operation: () -> T) -> T {
        lock()
        defer { unlock() }
        return operation()
    }
}
