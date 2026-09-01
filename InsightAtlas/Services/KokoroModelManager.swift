//
//  KokoroModelManager.swift
//  InsightAtlas
//
//  Lifecycle management for FluidAudio's ANE-optimized Kokoro model.
//

import Combine
import FluidAudio
import Foundation

struct KokoroModelManifest: Equatable, Sendable {
    let version: String
    let minimumAvailableCapacity: Int64

    static let production = KokoroModelManifest(
        version: "kokoro-ane-fluid-0.15.6",
        minimumAvailableCapacity: 750 * 1_024 * 1_024
    )
}

enum KokoroModelStore {
    private static let readyMarkerName = ".insightatlas-kokoro-ane-ready-v1"

    static func modelsRoot(fileManager: FileManager = .default) -> URL {
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        return applicationSupport
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent("KokoroANE", isDirectory: true)
    }

    static func modelDirectory(
        manifest: KokoroModelManifest = .production,
        fileManager: FileManager = .default
    ) -> URL {
        modelsRoot(fileManager: fileManager)
            .appendingPathComponent(manifest.version, isDirectory: true)
    }

    static func readyMarker(
        manifest: KokoroModelManifest = .production,
        fileManager: FileManager = .default
    ) -> URL {
        modelDirectory(manifest: manifest, fileManager: fileManager)
            .appendingPathComponent(readyMarkerName)
    }

    static var isInstalled: Bool {
        KokoroModelInstallationValidator.isInstalled(at: modelDirectory())
    }
}

enum KokoroModelInstallationValidator {
    private static let readyMarkerName = ".insightatlas-kokoro-ane-ready-v1"

    static func isInstalled(
        at directory: URL,
        fileManager: FileManager = .default
    ) -> Bool {
        let marker = directory.appendingPathComponent(readyMarkerName)
        guard fileManager.fileExists(atPath: marker.path),
              let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: nil
              ) else { return false }
        return enumerator.contains { item in
            (item as? URL)?.pathExtension == "mlmodelc"
        }
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
        case .preparing, .downloading, .verifying, .extracting: return true
        case .notInstalled, .installed, .failed: return false
        }
    }
}

enum KokoroModelError: LocalizedError {
    case insufficientStorage(required: Int64, available: Int64)
    case incompleteInstallation

    var errorDescription: String? {
        switch self {
        case .insufficientStorage(let required, let available):
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return "Kokoro needs at least \(formatter.string(fromByteCount: required)) free. This device currently reports \(formatter.string(fromByteCount: available))."
        case .incompleteInstallation:
            return "The Kokoro Neural Engine model could not be loaded completely. Please try the download again."
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
        let directory = KokoroModelStore.modelDirectory(
            manifest: manifest,
            fileManager: fileManager
        )
        self.state = KokoroModelInstallationValidator.isInstalled(
            at: directory,
            fileManager: fileManager
        ) ? .installed : .notInstalled
    }

    var modelDirectory: URL {
        KokoroModelStore.modelDirectory(manifest: manifest, fileManager: fileManager)
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
        let directory = modelDirectory

        installTask = Task { [weak self] in
            do {
                try Self.requireAvailableCapacity(
                    manifest.minimumAvailableCapacity,
                    at: directory,
                    fileManager: fileManager
                )
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

                try await KokoroAneResourceDownloader.ensureModels(
                    directory: directory,
                    progressHandler: { progress in
                        Task { @MainActor [weak self] in
                            self?.state = .downloading(
                                progress: min(max(progress.fractionCompleted * 0.85, 0), 0.85)
                            )
                        }
                    }
                )
                try Task.checkCancellation()

                try await KokoroAneResourceDownloader.ensureG2PAssets(
                    progressHandler: { progress in
                        Task { @MainActor [weak self] in
                            self?.state = .downloading(
                                progress: 0.85 + min(max(progress.fractionCompleted, 0), 1) * 0.10
                            )
                        }
                    }
                )
                try Task.checkCancellation()

                self?.state = .extracting
                let manager = KokoroAneManager(directory: directory)
                let selectedVoiceID = Self.selectedVoiceID()
                try await manager.initialize(
                    preloadVoices: [selectedVoiceID]
                )
                await manager.cleanup()
                try Task.checkCancellation()

                try Data(manifest.version.utf8).write(
                    to: KokoroModelStore.readyMarker(
                        manifest: manifest,
                        fileManager: fileManager
                    ),
                    options: .atomic
                )
                guard KokoroModelInstallationValidator.isInstalled(
                    at: directory,
                    fileManager: fileManager
                ) else { throw KokoroModelError.incompleteInstallation }

                await KokoroAudioService.shared.reset()
                self?.state = .installed
            } catch is CancellationError {
                self?.refreshState()
            } catch {
                self?.state = .failed(message: error.localizedDescription)
            }
            self?.installTask = nil
        }
    }

    private static func selectedVoiceID() -> String {
        guard let voiceID = UserDefaults.standard.string(
            forKey: KokoroVoiceRegistry.selectedVoiceStorageKey
        ), KokoroVoiceRegistry.voice(byVoiceID: voiceID) != nil else {
            return KokoroVoiceRegistry.defaultVoice.voiceID
        }
        return voiceID
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

    private static func requireAvailableCapacity(
        _ required: Int64,
        at directory: URL,
        fileManager: FileManager
    ) throws {
        let parent = directory.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        let values = try parent.resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey]
        )
        let available = values.volumeAvailableCapacityForImportantUsage ?? 0
        guard available >= required else {
            throw KokoroModelError.insufficientStorage(required: required, available: available)
        }
    }
}
