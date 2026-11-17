//
//  GuideBodyStore.swift
//  InsightAtlas
//
//  File-backed storage for guide bodies.
//
//  The whole library — including every guide's full text — was JSON-encoded
//  into UserDefaults. UserDefaults is a preferences store: it is read wholly
//  into memory at launch and kept resident, and Apple documents it for small
//  values. Two costs followed. Resident memory grew with the library, which
//  made the app a better jetsam candidate while backgrounded. And because
//  `saveLibrary()` re-encoded the entire array, changing one item's narration
//  state rewrote every guide body in the library — megabytes of work for a
//  one-field change, from twelve call sites.
//
//  Bodies now live one file per guide under Documents/guides. UserDefaults
//  keeps only metadata, so a save writes a few kilobytes.
//

import Foundation
import os.log

private let bodyLog = Logger(subsystem: "com.insightatlas", category: "GuideBodyStore")

enum GuideBodyStore {

    /// Directory holding one Markdown-ish body per guide.
    static func directory(fileManager: FileManager = .default) -> URL? {
        guard let documents = fileManager.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first else { return nil }
        let dir = documents.appendingPathComponent("guides", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private static func url(for id: UUID, fileManager: FileManager = .default) -> URL? {
        directory(fileManager: fileManager)?.appendingPathComponent("\(id.uuidString).md")
    }

    /// Read a guide body, or nil when none is stored.
    static func load(_ id: UUID, fileManager: FileManager = .default) -> String? {
        guard let url = url(for: id, fileManager: fileManager),
              let text = try? String(contentsOf: url, encoding: .utf8),
              !text.isEmpty else { return nil }
        return text
    }

    /// Whether a body file exists, without reading it.
    static func exists(_ id: UUID, fileManager: FileManager = .default) -> Bool {
        guard let url = url(for: id, fileManager: fileManager) else { return false }
        return fileManager.fileExists(atPath: url.path)
    }

    /// IDs with a body on disk, kept in memory so list UI can show "has
    /// content" without reading bodies or stat-ing files per row. Primed by
    /// `refreshKnownIDs()` at launch and maintained by `save`, `delete` and
    /// `pruneOrphans`.
    private static var knownIDs: Set<UUID> = []

    /// Cheap membership check against the in-memory index.
    static func hasBody(_ id: UUID) -> Bool {
        fingerprintLock.lock()
        defer { fingerprintLock.unlock() }
        return knownIDs.contains(id)
    }

    /// Rebuild the in-memory index from a single directory listing.
    @discardableResult
    static func refreshKnownIDs(fileManager: FileManager = .default) -> Set<UUID> {
        var ids = Set<UUID>()
        if let dir = directory(fileManager: fileManager),
           let names = try? fileManager.contentsOfDirectory(atPath: dir.path) {
            for name in names where name.hasSuffix(".md") {
                if let id = UUID(uuidString: String(name.dropLast(3))) { ids.insert(id) }
            }
        }
        fingerprintLock.lock()
        knownIDs = ids
        fingerprintLock.unlock()
        return ids
    }

    /// Fingerprints of bodies already on disk, so an unchanged body is not
    /// rewritten. Without this, saving the library rewrote every guide's file
    /// on every call — from twelve call sites, synchronously, during
    /// generation. That is enough main-thread file I/O to trip the watchdog,
    /// which the user sees as a crash.
    private static var writtenFingerprints: [UUID: Int] = [:]
    private static let fingerprintLock = NSLock()

    /// Write a guide body, staging then replacing so an interrupted write
    /// cannot leave a half-written guide behind. Unchanged bodies are skipped.
    @discardableResult
    static func save(_ body: String, for id: UUID, fileManager: FileManager = .default) -> Bool {
        let fingerprint = body.hashValue
        fingerprintLock.lock()
        let unchanged = writtenFingerprints[id] == fingerprint
        if unchanged { knownIDs.insert(id) }
        fingerprintLock.unlock()
        if unchanged { return true }

        guard let url = url(for: id, fileManager: fileManager) else { return false }
        let staging = url.deletingLastPathComponent()
            .appendingPathComponent(".\(id.uuidString).\(UUID().uuidString).partial")
        do {
            try body.write(to: staging, atomically: true, encoding: .utf8)
            if fileManager.fileExists(atPath: url.path) {
                _ = try fileManager.replaceItemAt(url, withItemAt: staging)
            } else {
                try fileManager.moveItem(at: staging, to: url)
            }
            fingerprintLock.lock()
            writtenFingerprints[id] = fingerprint
            knownIDs.insert(id)
            fingerprintLock.unlock()
            return true
        } catch {
            try? fileManager.removeItem(at: staging)
            bodyLog.error("Failed to store guide body: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    static func delete(_ id: UUID, fileManager: FileManager = .default) {
        fingerprintLock.lock()
        writtenFingerprints[id] = nil
        knownIDs.remove(id)
        fingerprintLock.unlock()
        guard let url = url(for: id, fileManager: fileManager) else { return }
        try? fileManager.removeItem(at: url)
    }

    /// Remove bodies with no matching library item, so deleting a guide outside
    /// the normal path cannot strand its text on disk forever.
    static func pruneOrphans(keeping ids: Set<UUID>, fileManager: FileManager = .default) {
        guard let dir = directory(fileManager: fileManager),
              let names = try? fileManager.contentsOfDirectory(atPath: dir.path) else { return }
        var removed = 0
        for name in names where name.hasSuffix(".md") {
            let stem = String(name.dropLast(3))
            guard let id = UUID(uuidString: stem), !ids.contains(id) else { continue }
            fingerprintLock.lock()
            writtenFingerprints[id] = nil
            knownIDs.remove(id)
            fingerprintLock.unlock()
            try? fileManager.removeItem(at: dir.appendingPathComponent(name))
            removed += 1
        }
        if removed > 0 { bodyLog.info("Pruned \(removed) orphaned guide body file(s)") }
    }
}
