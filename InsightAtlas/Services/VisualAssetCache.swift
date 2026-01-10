//
//  VisualAssetCache.swift
//  InsightAtlas
//
//  Caches visual assets locally for offline PDF rendering.
//

import UIKit
import os.log

private let logger = Logger(subsystem: "com.insightatlas", category: "VisualAssetCache")

final class VisualAssetCache {
    static let shared = VisualAssetCache()

    private let cacheDirectory: URL
    private let fileManager = FileManager.default

    // MARK: - Cache Policy Configuration

    /// Maximum cache size in bytes (default: 100 MB)
    var maxCacheSize: Int64 = 100 * 1024 * 1024

    /// Maximum age for cached files in seconds (default: 30 days)
    var maxCacheAge: TimeInterval = 30 * 24 * 60 * 60

    /// Target size after eviction as percentage of max (default: 70%)
    var evictionTargetRatio: Double = 0.70

    private init() {
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        cacheDirectory = base.appendingPathComponent("GuideVisuals", isDirectory: true)
        try? fileManager.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true
        )

        // Run eviction on init to clean up stale files
        Task.detached(priority: .utility) { [weak self] in
            await self?.evictIfNeeded()
        }
    }

    /// Returns the local cache URL for a remote URL
    func localURL(for remoteURL: URL) -> URL {
        // Use a hash of the full URL to avoid collisions
        let filename = (remoteURL.absoluteString.data(using: .utf8) ?? Data())
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .prefix(64)
        let ext = remoteURL.pathExtension.isEmpty ? "png" : remoteURL.pathExtension
        return cacheDirectory.appendingPathComponent("\(filename).\(ext)")
    }

    /// Check if image is already cached
    func isCached(remoteURL: URL) -> Bool {
        let local = localURL(for: remoteURL)
        return fileManager.fileExists(atPath: local.path)
    }

    /// Cache image from remote URL if not already cached
    /// Returns local file URL
    @discardableResult
    func cacheIfNeeded(from remoteURL: URL) async throws -> URL {
        let local = localURL(for: remoteURL)

        if fileManager.fileExists(atPath: local.path) {
            return local
        }

        let (data, response) = try await URLSession.shared.data(from: remoteURL)

        // Verify we got image data
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CacheError.downloadFailed
        }

        try data.write(to: local, options: .atomic)
        return local
    }

    /// Synchronously get cached image (for PDF rendering)
    /// Returns nil if not cached
    func cachedImage(for remoteURL: URL) -> UIImage? {
        let local = localURL(for: remoteURL)
        guard fileManager.fileExists(atPath: local.path) else {
            return nil
        }
        return UIImage(contentsOfFile: local.path)
    }

    /// Clear all cached visuals
    func clearCache() {
        do {
            try fileManager.removeItem(at: cacheDirectory)
        } catch {
            logger.warning("Failed to remove cache directory: \(error.localizedDescription)")
        }
        do {
            try fileManager.createDirectory(
                at: cacheDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            logger.error("Failed to recreate cache directory: \(error.localizedDescription)")
        }
    }

    /// Get total cache size in bytes
    func cacheSize() -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(size)
            }
        }
        return totalSize
    }

    // MARK: - Cache Eviction

    /// Metadata for a cached file used in eviction decisions
    private struct CachedFileInfo: Comparable {
        let url: URL
        let size: Int64
        let lastAccessed: Date

        static func < (lhs: CachedFileInfo, rhs: CachedFileInfo) -> Bool {
            // Sort by last accessed time, oldest first (for LRU eviction)
            lhs.lastAccessed < rhs.lastAccessed
        }
    }

    /// Evict cached files if cache exceeds size limit or files are too old
    /// Uses LRU (Least Recently Used) strategy for size-based eviction
    @discardableResult
    func evictIfNeeded() async -> EvictionResult {
        let currentSize = cacheSize()
        let now = Date()
        var evictedCount = 0
        var evictedBytes: Int64 = 0

        // Get all cached files with metadata
        var cachedFiles: [CachedFileInfo] = []

        // Collect all file URLs first (not sendable-safe to iterate enumerator in async context)
        let fileURLs: [URL]
        if let enumerator = fileManager.enumerator(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .contentAccessDateKey, .contentModificationDateKey]
        ) {
            fileURLs = enumerator.compactMap { $0 as? URL }
        } else {
            logger.warning("Cache eviction: Unable to enumerate cache directory")
            return EvictionResult(evictedCount: 0, evictedBytes: 0, remainingSize: currentSize)
        }

        // Process the collected URLs
        for fileURL in fileURLs {
            do {
                let values = try fileURL.resourceValues(forKeys: [.fileSizeKey, .contentAccessDateKey, .contentModificationDateKey])
                let size = Int64(values.fileSize ?? 0)
                // Use access date if available, otherwise modification date
                let lastAccessed = values.contentAccessDate ?? values.contentModificationDate ?? now

                // First pass: Remove files older than maxCacheAge
                if now.timeIntervalSince(lastAccessed) > maxCacheAge {
                    try fileManager.removeItem(at: fileURL)
                    evictedCount += 1
                    evictedBytes += size
                    logger.debug("Cache eviction: Removed stale file \(fileURL.lastPathComponent, privacy: .public)")
                } else {
                    cachedFiles.append(CachedFileInfo(url: fileURL, size: size, lastAccessed: lastAccessed))
                }
            } catch {
                logger.warning("Cache eviction: Failed to process \(fileURL.lastPathComponent, privacy: .public): \(error.localizedDescription)")
            }
        }

        // Calculate remaining size after age-based eviction
        var remainingSize = currentSize - evictedBytes

        // Second pass: If still over limit, evict LRU files until under target
        if remainingSize > maxCacheSize {
            let targetSize = Int64(Double(maxCacheSize) * evictionTargetRatio)
            logger.info("Cache eviction: Size \(remainingSize) exceeds max \(self.maxCacheSize), targeting \(targetSize)")

            // Sort by last accessed time (oldest first)
            cachedFiles.sort()

            for fileInfo in cachedFiles {
                guard remainingSize > targetSize else { break }

                do {
                    try fileManager.removeItem(at: fileInfo.url)
                    evictedCount += 1
                    evictedBytes += fileInfo.size
                    remainingSize -= fileInfo.size
                    logger.debug("Cache eviction: Removed LRU file \(fileInfo.url.lastPathComponent, privacy: .public)")
                } catch {
                    logger.warning("Cache eviction: Failed to remove \(fileInfo.url.lastPathComponent, privacy: .public): \(error.localizedDescription)")
                }
            }
        }

        if evictedCount > 0 {
            logger.info("Cache eviction complete: Removed \(evictedCount) files (\(evictedBytes) bytes), remaining: \(remainingSize) bytes")
        }

        return EvictionResult(evictedCount: evictedCount, evictedBytes: evictedBytes, remainingSize: remainingSize)
    }

    /// Result of a cache eviction operation
    struct EvictionResult {
        let evictedCount: Int
        let evictedBytes: Int64
        let remainingSize: Int64

        var formattedEvictedSize: String {
            ByteCountFormatter.string(fromByteCount: evictedBytes, countStyle: .file)
        }

        var formattedRemainingSize: String {
            ByteCountFormatter.string(fromByteCount: remainingSize, countStyle: .file)
        }
    }

    /// Get cache statistics
    func cacheStats() -> CacheStats {
        let currentSize = cacheSize()
        var fileCount = 0
        var oldestFile: Date?
        var newestFile: Date?

        guard let enumerator = fileManager.enumerator(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else {
            return CacheStats(fileCount: 0, totalSize: 0, oldestFile: nil, newestFile: nil, utilizationPercent: 0)
        }

        for case let fileURL as URL in enumerator {
            fileCount += 1
            if let date = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
                // Safe optional comparison without force unwrapping
                if let oldest = oldestFile {
                    if date < oldest {
                        oldestFile = date
                    }
                } else {
                    oldestFile = date
                }
                if let newest = newestFile {
                    if date > newest {
                        newestFile = date
                    }
                } else {
                    newestFile = date
                }
            }
        }

        let utilization = maxCacheSize > 0 ? Double(currentSize) / Double(maxCacheSize) * 100 : 0

        return CacheStats(
            fileCount: fileCount,
            totalSize: currentSize,
            oldestFile: oldestFile,
            newestFile: newestFile,
            utilizationPercent: utilization
        )
    }

    /// Cache statistics for monitoring
    struct CacheStats {
        let fileCount: Int
        let totalSize: Int64
        let oldestFile: Date?
        let newestFile: Date?
        let utilizationPercent: Double

        var formattedSize: String {
            ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        }
    }

    /// Prefetch all visuals from a list of URLs concurrently
    /// Used before PDF export to ensure all images are locally cached
    /// - Parameters:
    ///   - urls: Array of remote image URLs to cache
    ///   - progress: Optional callback with (completed, total) counts
    /// - Returns: Number of successfully cached images
    @discardableResult
    func prefetchAll(
        urls: [URL],
        progress: ((Int, Int) -> Void)? = nil
    ) async -> Int {
        guard !urls.isEmpty else { return 0 }

        let total = urls.count
        var completed = 0
        var successCount = 0

        await withTaskGroup(of: Bool.self) { group in
            for url in urls {
                group.addTask {
                    do {
                        try await self.cacheIfNeeded(from: url)
                        return true
                    } catch {
                        return false
                    }
                }
            }

            for await success in group {
                completed += 1
                if success {
                    successCount += 1
                }
                progress?(completed, total)
            }
        }

        return successCount
    }

    enum CacheError: Error {
        case downloadFailed
        case invalidData
    }
}
