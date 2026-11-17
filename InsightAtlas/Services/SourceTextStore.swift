//
//  SourceTextStore.swift
//  InsightAtlas
//
//  File-backed storage for the original manuscript / extract used to generate
//  a guide. Regenerate must re-read this source — never the guide body — or
//  each regenerate paraphrases a summary and invents provenance.
//

import Foundation
import os.log

private let sourceLog = Logger(subsystem: "com.insightatlas", category: "SourceTextStore")

enum SourceTextStore {

    static func directory(fileManager: FileManager = .default) -> URL? {
        guard let documents = fileManager.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first else { return nil }
        let dir = documents.appendingPathComponent("sources", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private static func url(for id: UUID, fileManager: FileManager = .default) -> URL? {
        directory(fileManager: fileManager)?.appendingPathComponent("\(id.uuidString).txt")
    }

    static func exists(_ id: UUID, fileManager: FileManager = .default) -> Bool {
        guard let url = url(for: id, fileManager: fileManager) else { return false }
        return fileManager.fileExists(atPath: url.path)
    }

    static func load(_ id: UUID, fileManager: FileManager = .default) -> String? {
        guard let url = url(for: id, fileManager: fileManager),
              let text = try? String(contentsOf: url, encoding: .utf8),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return text
    }

    @discardableResult
    static func save(_ body: String, for id: UUID, fileManager: FileManager = .default) -> Bool {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = url(for: id, fileManager: fileManager) else { return false }
        let staging = url.deletingLastPathComponent()
            .appendingPathComponent(".\(id.uuidString).\(UUID().uuidString).partial")
        do {
            try trimmed.write(to: staging, atomically: true, encoding: .utf8)
            if fileManager.fileExists(atPath: url.path) {
                _ = try fileManager.replaceItemAt(url, withItemAt: staging)
            } else {
                try fileManager.moveItem(at: staging, to: url)
            }
            return true
        } catch {
            try? fileManager.removeItem(at: staging)
            sourceLog.error("Failed to store source text: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    static func delete(_ id: UUID, fileManager: FileManager = .default) {
        guard let url = url(for: id, fileManager: fileManager) else { return }
        try? fileManager.removeItem(at: url)
    }

    static func pruneOrphans(keeping ids: Set<UUID>, fileManager: FileManager = .default) {
        guard let dir = directory(fileManager: fileManager),
              let names = try? fileManager.contentsOfDirectory(atPath: dir.path) else { return }
        var removed = 0
        for name in names where name.hasSuffix(".txt") {
            let stem = String(name.dropLast(4))
            guard let id = UUID(uuidString: stem), !ids.contains(id) else { continue }
            try? fileManager.removeItem(at: dir.appendingPathComponent(name))
            removed += 1
        }
        if removed > 0 {
            sourceLog.info("Pruned \(removed) orphaned source text file(s)")
        }
    }
}
