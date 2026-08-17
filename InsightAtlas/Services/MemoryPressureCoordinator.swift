//
//  MemoryPressureCoordinator.swift
//  InsightAtlas
//
//  Releases large, reconstructible memory when iOS reports pressure.
//
//  The Kokoro model is roughly 109 MB of weights plus 26 MB of voices, and once
//  loaded it stayed resident for the life of the process: `reset()` was only
//  called when the model was deleted or reinstalled. iOS terminates backgrounded
//  apps in descending order of footprint, so holding a large ONNX arena made the
//  app a prime jetsam candidate — narration that "stops when you leave the app"
//  can be the process being killed, not merely suspended.
//
//  Nothing here is load-bearing: the model reloads on next use and the markdown
//  cache repopulates. Only work that is not in flight is released.
//

import Foundation
import UIKit
import os.log

private let memoryLog = Logger(subsystem: "com.insightatlas", category: "MemoryPressure")

@MainActor
final class MemoryPressureCoordinator {

    static let shared = MemoryPressureCoordinator()

    /// Set while narration synthesis is running so the model in active use is
    /// never pulled out from under it.
    private var synthesisInFlight = 0
    private var observers: [NSObjectProtocol] = []

    private init() {}

    func start() {
        guard observers.isEmpty else { return }

        observers.append(
            NotificationCenter.default.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in MemoryPressureCoordinator.shared.releaseReclaimableMemory(reason: "memory warning") }
            }
        )

        // Backgrounding is when footprint decides whether the app survives.
        observers.append(
            NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in MemoryPressureCoordinator.shared.releaseReclaimableMemory(reason: "entered background") }
            }
        )
    }

    /// Mark synthesis boundaries so the loaded model is retained while in use.
    func beginSynthesis() { synthesisInFlight += 1 }
    func endSynthesis() { synthesisInFlight = max(0, synthesisInFlight - 1) }

    private func releaseReclaimableMemory(reason: String) {
        AnalysisDetailView.clearMarkdownCache()

        guard synthesisInFlight == 0 else {
            memoryLog.info("\(reason, privacy: .public): synthesis in flight, keeping the voice model loaded")
            return
        }

        memoryLog.info("\(reason, privacy: .public): releasing the on-device voice model")
        Task { await KokoroAudioService.shared.reset() }
    }
}
