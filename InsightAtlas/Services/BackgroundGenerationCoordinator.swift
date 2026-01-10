//
//  BackgroundGenerationCoordinator.swift
//  InsightAtlas
//
//  Coordinates guide generation with iOS background task support.
//
//  This service enables guide generation to continue when the app is backgrounded,
//  using iOS-approved background execution patterns:
//  - BGProcessingTask for extended background time
//  - State persistence for recovery after termination
//
//  IMPORTANT: This service does NOT modify:
//  - Rendering/export pipelines
//  - Layout scoring logic
//  - Formatting invariants
//
//  It only provides background-safe orchestration of existing AIService generation.
//

import Foundation
import BackgroundTasks
import Combine
import UIKit
import AVFoundation
import os.log

// MARK: - Logger

private let logger = Logger(subsystem: "com.insightatlas", category: "BackgroundGeneration")

// MARK: - Background Task Identifiers

/// Registered background task identifiers (must match Info.plist)
enum BackgroundTaskIdentifier {
    static let guideGeneration = "com.insightatlas.guide-generation"
}

// MARK: - Governor Debug Logging

/// Debug logging for Summary Type Governors v1.0 verification
private func governorLog(_ message: String) {
    #if DEBUG
    logger.debug("[Governor] \(message)")
    #endif
}

/// Debug logging for audio generation
private func audioLog(_ message: String) {
    #if DEBUG
    logger.debug("[Audio] \(message)")
    #endif
}

// MARK: - Generation State

/// Persisted state for in-progress generation
struct GenerationState: Codable {
    let id: UUID
    let title: String
    let author: String
    let fileType: FileType
    let mode: GenerationMode
    let tone: ToneMode
    let format: OutputFormat
    let provider: AIProvider
    let startedAt: Date
    var phase: GenerationPhase
    var accumulatedContent: String
    var lastUpdated: Date
    var existingItemId: UUID?

    // MARK: - Summary Type Governor v1.0

    /// Summary type for governor enforcement
    var summaryType: SummaryType

    /// Source word count for budget calculation
    var sourceWordCount: Int?

    /// Book text is stored separately due to size
    var bookTextStorageKey: String {
        "generation_booktext_\(id.uuidString)"
    }

    enum GenerationPhase: String, Codable {
        case pending
        case processing
        case streaming
        case completed
        case failed
        case cancelled
    }
}

// MARK: - Generation Progress

/// Observable progress for UI updates
struct GenerationProgress: Equatable {
    let phase: String
    let percentComplete: Double
    let wordCount: Int
    let model: String
    let content: String

    static let initial = GenerationProgress(
        phase: "Preparing...",
        percentComplete: 0,
        wordCount: 0,
        model: "",
        content: ""
    )
}

// MARK: - Generation Output

/// Output from a successful generation, including content and cover image path
struct GenerationOutput {
    let content: String
    let coverImagePath: String?
    let metadata: GenerationMetadata?
    let resolvedTitle: String
    let resolvedAuthor: String
}

// MARK: - Generation Result

/// Result of a completed generation
enum GenerationResult {
    case success(content: String, itemId: UUID?, metadata: GenerationMetadata?, coverImagePath: String?)
    case failure(Error)
    case cancelled
}

/// Metadata from governor enforcement and audio generation
struct GenerationMetadata {
    let summaryType: SummaryType
    let governedWordCount: Int
    let cutPolicyActivated: Bool
    let cutEventCount: Int
    let audioFileURL: String?
    let audioVoiceID: String?
    let audioDuration: TimeInterval?
}

// MARK: - Background Generation Coordinator

/// Coordinates guide generation with background task support.
///
/// Usage:
/// ```swift
/// let coordinator = BackgroundGenerationCoordinator.shared
/// try await coordinator.startGeneration(...)
/// ```
///
/// This service:
/// - Persists generation state for recovery
/// - Registers background tasks for extended execution
/// - Publishes progress for UI observation
/// - Handles app lifecycle transitions
@MainActor
final class BackgroundGenerationCoordinator: ObservableObject {

    // MARK: - Singleton

    static let shared = BackgroundGenerationCoordinator()

    // MARK: - Published State

    @Published private(set) var isGenerating: Bool = false
    @Published internal var progress: GenerationProgress = .initial
    @Published private(set) var currentGenerationId: UUID?
    @Published private(set) var lastResult: GenerationResult?

    // MARK: - Private Properties

    private let aiService = AIService()
    private let bookProcessor = BookProcessor()
    private let fileManager = FileManager.default
    private var generationTask: Task<String, Error>?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    /// Selected voice ID for audio generation (user-selected or nil for profile default)
    private var selectedVoiceID: String?

    /// Storage keys for UserDefaults
    private let stateStorageKey = "background_generation_state"

    // MARK: - Initialization

    private init() {
        // Check for interrupted generation on init
        Task {
            await checkForInterruptedGeneration()
        }
    }

    // MARK: - Public Methods

    /// Start a new guide generation
    ///
    /// - Parameters:
    ///   - bookData: Raw book data
    ///   - fileType: Type of book file
    ///   - title: Book title
    ///   - author: Book author
    ///   - settings: User settings including API keys and preferences
    ///   - existingItemId: Optional ID of existing library item to update
    ///   - summaryType: Summary type for governor enforcement
    /// - Returns: GenerationOutput containing content and cover image path
    func startGeneration(
        bookData: Data,
        fileType: FileType,
        title: String,
        author: String,
        settings: UserSettings,
        existingItemId: UUID? = nil,
        summaryType: SummaryType? = nil,
        voiceID: String? = nil
    ) async throws -> GenerationOutput {
        // Store the voice ID for audio generation
        self.selectedVoiceID = voiceID
        // Use passed summaryType or fall back to user's preferred setting
        let effectiveSummaryType = summaryType ?? settings.preferredSummaryType

        // Prevent duplicate generations
        guard !isGenerating else {
            throw GenerationError.alreadyInProgress
        }

        // Process book to extract text
        let processedBook = try await bookProcessor.processBook(from: bookData, fileType: fileType)
        let bookText = processedBook.text
        let resolvedTitle = normalizedMetadata(processedBook.title) ?? title
        let resolvedAuthor = normalizedMetadata(processedBook.author) ?? author

        // Save cover image if available
        let coverImagePath = saveCoverImage(processedBook.coverImageData, for: existingItemId ?? UUID())

        // MARK: - Governor Pre-Generation Setup

        // Calculate source word count for governor (after removing front/back matter)
        let sourceWordCount = calculateSourceWordCount(bookText)
        governorLog("SummaryType: \(effectiveSummaryType.rawValue)")
        governorLog("Source word count: \(sourceWordCount)")

        // Detect source type for synthesis templates
        let sourceTypeResult = SourceTypeDetector.detect(text: bookText)
        governorLog("Source type detected: \(sourceTypeResult.detectedType.rawValue)")

        // Get governor and calculate budget
        let governor = SummaryTypeGovernor.governor(for: effectiveSummaryType)
        let engine = SummaryGovernorEngine(governor: governor)
        let totalBudget = engine.calculateTotalBudget(sourceWordCount: sourceWordCount)
        governorLog("Total budget: \(totalBudget) words")
        governorLog("Max word ceiling: \(governor.maxWordCeiling)")
        governorLog("Max audio minutes: \(governor.maxAudioMinutes)")

        // Create generation state
        let generationId = UUID()
        var state = GenerationState(
            id: generationId,
            title: resolvedTitle,
            author: resolvedAuthor,
            fileType: fileType,
            mode: settings.preferredMode,
            tone: settings.preferredTone,
            format: settings.preferredFormat,
            provider: settings.preferredProvider,
            startedAt: Date(),
            phase: .pending,
            accumulatedContent: "",
            lastUpdated: Date(),
            existingItemId: existingItemId,
            summaryType: effectiveSummaryType,
            sourceWordCount: sourceWordCount
        )

        // Persist state and book text
        persistState(state)
        persistBookText(bookText, for: state)

        // Update UI state
        isGenerating = true
        currentGenerationId = generationId
        progress = .initial
        lastResult = nil

        // Begin background task for extended execution
        beginBackgroundTask()

        // Schedule BGProcessingTask for potential continuation
        scheduleBackgroundProcessing()

        do {
            // MARK: - Streaming Governor Context

            // Create streaming governor context for real-time enforcement
            let governorContext = StreamingGovernorContext(
                governor: governor,
                engine: engine,
                totalBudget: totalBudget,
                sourceType: sourceTypeResult.detectedType
            )

            // Perform generation with streaming governor
            let (rawResult, governorResult) = try await performGeneration(
                bookText: bookText,
                state: state,
                settings: settings,
                governorContext: governorContext
            )

            // Use governor result (streaming enforcement already applied)
            var finalResult = governorResult ?? GovernorEnforcementResult(
                content: rawResult,
                wordCount: rawResult.split(separator: " ").count,
                cutPolicyActivated: false,
                cutEventCount: 0
            )

            governorLog("Initial generation complete: \(finalResult.wordCount) words")
            governorLog("Cut policy activated: \(finalResult.cutPolicyActivated)")
            governorLog("Cut events: \(finalResult.cutEventCount)")

            // MARK: - Quality Validation & Improvement Pass

            let allowImprovementPass = settings.preferredMode == .deepResearch ||
                settings.preferredSummaryType == .deepResearch
            let improvementThreshold = Int(Double(governor.maxWordCeiling) * 0.7)
            let shouldSkipImprovementPass = !allowImprovementPass ||
                finalResult.cutPolicyActivated ||
                finalResult.wordCount >= governor.maxWordCeiling ||
                finalResult.wordCount >= improvementThreshold
            let qualityIssues = shouldSkipImprovementPass ? [] : validateOutputQuality(content: finalResult.content, governor: governor)

            if !qualityIssues.isEmpty {
                governorLog("⚠️ Quality issues detected: \(qualityIssues.count)")
                for issue in qualityIssues {
                    governorLog("  - \(issue)")
                }

                // Update status to show improvement pass
                progress = GenerationProgress(
                    phase: "Improving output...",
                    percentComplete: 0.85,
                    wordCount: finalResult.wordCount,
                    model: "\(state.provider.displayName) (Enhancement)",
                    content: finalResult.content
                )

                // Perform improvement pass
                let improvementHints = generateImprovementHints(from: qualityIssues)
                governorLog("Starting improvement pass with hints: \(improvementHints.prefix(200))...")

                // Create new governor context for improvement pass (remaining budget)
                let remainingBudget = max(governor.maxWordCeiling - finalResult.wordCount, 1000)
                let improvementGovernor = StreamingGovernorContext(
                    governor: governor,
                    engine: engine,
                    totalBudget: remainingBudget,
                    sourceType: sourceTypeResult.detectedType
                )

                // Pre-populate with existing content
                _ = improvementGovernor.processChunk(finalResult.content)

                let (improvedResult, improvedGovernorResult) = try await performGeneration(
                    bookText: bookText,
                    state: state,
                    settings: settings,
                    resumeFromContent: finalResult.content,
                    governorContext: improvementGovernor,
                    improvementHints: improvementHints
                )

                // Update with improved result
                if let improved = improvedGovernorResult {
                    finalResult = improved
                    governorLog("Improvement pass complete: \(improved.wordCount) words")
                } else {
                    finalResult = GovernorEnforcementResult(
                        content: improvedResult,
                        wordCount: improvedResult.split(separator: " ").count,
                        cutPolicyActivated: finalResult.cutPolicyActivated,
                        cutEventCount: finalResult.cutEventCount
                    )
                }
            }

            governorLog("Final word count: \(finalResult.wordCount)")

            let sanitizedContent = sanitizeGeneratedContent(finalResult.content)
            if sanitizedContent != finalResult.content {
                finalResult = GovernorEnforcementResult(
                    content: sanitizedContent,
                    wordCount: sanitizedContent.split(separator: " ").count,
                    cutPolicyActivated: finalResult.cutPolicyActivated,
                    cutEventCount: finalResult.cutEventCount
                )
                governorLog("Markdown artifacts stripped from output")
            }

            // Soft enforcement: log warning but don't throw for minor violations
            if finalResult.wordCount > governor.maxWordCeiling {
                let overagePercent = Float(finalResult.wordCount - governor.maxWordCeiling) / Float(governor.maxWordCeiling) * 100
                if overagePercent > 10 {
                    // Only throw for significant violations (>10% over)
                    let formatted = String(format: "❌ STRICT ENFORCEMENT VIOLATION: %d > %d (%.1f%% over)", finalResult.wordCount, governor.maxWordCeiling, overagePercent)
                    governorLog(formatted)
                    throw GenerationError.governorViolation(
                        wordCount: finalResult.wordCount,
                        limit: governor.maxWordCeiling
                    )
                } else {
                    governorLog("⚠️ Minor overage accepted: \(finalResult.wordCount) words (\(String(format: "%.1f", overagePercent))%% over limit)")
                }
            }

            // MARK: - Audio Generation

            let audioResult = await generateAudioIfAvailable(
                content: finalResult.content,
                title: resolvedTitle,
                generationId: generationId,
                libraryItemId: existingItemId,
                readerProfile: settings.preferredReaderProfile
            )

            // Create metadata
            let metadata = GenerationMetadata(
                summaryType: effectiveSummaryType,
                governedWordCount: finalResult.wordCount,
                cutPolicyActivated: finalResult.cutPolicyActivated,
                cutEventCount: finalResult.cutEventCount,
                audioFileURL: audioResult?.fileURL,
                audioVoiceID: audioResult?.voiceID,
                audioDuration: audioResult?.duration
            )

            // Update state to completed
            state.phase = .completed
            state.accumulatedContent = finalResult.content
            state.lastUpdated = Date()
            persistState(state)

            // Clean up
            endBackgroundTask()
            isGenerating = false
            lastResult = .success(content: finalResult.content, itemId: existingItemId, metadata: metadata, coverImagePath: coverImagePath)

            // Clear persisted state after success
            clearPersistedState()

            return GenerationOutput(
                content: finalResult.content,
                coverImagePath: coverImagePath,
                metadata: metadata,
                resolvedTitle: resolvedTitle,
                resolvedAuthor: resolvedAuthor
            )

        } catch is CancellationError {
            // Handle cancellation
            state.phase = .cancelled
            state.lastUpdated = Date()
            persistState(state)

            endBackgroundTask()
            isGenerating = false
            lastResult = .cancelled

            clearPersistedState()
            throw GenerationError.cancelled

        } catch {
            // Handle failure
            state.phase = .failed
            state.lastUpdated = Date()
            persistState(state)

            endBackgroundTask()
            isGenerating = false
            lastResult = .failure(error)

            // Keep state for potential retry
            throw error
        }
    }

    private func normalizedMetadata(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    /// Cancel any in-progress generation
    func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil

        if var state = loadPersistedState() {
            state.phase = .cancelled
            state.lastUpdated = Date()
            persistState(state)
        }

        endBackgroundTask()
        isGenerating = false
        currentGenerationId = nil
        progress = .initial
        lastResult = .cancelled

        clearPersistedState()
    }

    /// Check if there's an interrupted generation that can be resumed
    func hasInterruptedGeneration() -> Bool {
        guard let state = loadPersistedState() else { return false }
        return state.phase == .processing || state.phase == .streaming
    }

    /// Get details of interrupted generation for user display
    func getInterruptedGenerationInfo() -> (title: String, author: String, startedAt: Date)? {
        guard let state = loadPersistedState(),
              state.phase == .processing || state.phase == .streaming else {
            return nil
        }
        return (state.title, state.author, state.startedAt)
    }

    /// Resume an interrupted generation
    ///
    /// - Parameter settings: Current user settings (for API keys)
    /// - Returns: Generated content if resumption succeeds
    func resumeInterruptedGeneration(settings: UserSettings) async throws -> String {
        guard let state = loadPersistedState(),
              state.phase == .processing || state.phase == .streaming else {
            throw GenerationError.noInterruptedGeneration
        }

        guard let bookText = loadBookText(for: state) else {
            throw GenerationError.bookTextNotFound
        }

        // Update UI state
        isGenerating = true
        currentGenerationId = state.id
        progress = GenerationProgress(
            phase: "Resuming...",
            percentComplete: 0,
            wordCount: state.accumulatedContent.split(separator: " ").count,
            model: state.provider.displayName,
            content: state.accumulatedContent
        )
        lastResult = nil

        beginBackgroundTask()

        // MARK: - Resume with Governor Enforcement
        // Recreate governor context for resumed generation using persisted state
        let governor = SummaryTypeGovernor.governor(for: state.summaryType)
        let engine = SummaryGovernorEngine(governor: governor)
        let sourceWordCount = state.sourceWordCount ?? 50000 // Fallback for legacy states
        let totalBudget = engine.calculateTotalBudget(sourceWordCount: sourceWordCount)

        // Detect source type (re-detect from book text)
        let sourceTypeResult = SourceTypeDetector.detect(text: bookText)

        // Create streaming governor context for resumed generation
        let governorContext = StreamingGovernorContext(
            governor: governor,
            engine: engine,
            totalBudget: totalBudget,
            sourceType: sourceTypeResult.detectedType
        )

        // Pre-populate governor with already accumulated content
        if !state.accumulatedContent.isEmpty {
            _ = governorContext.processChunk(state.accumulatedContent)
        }

        governorLog("Resuming with governor enforcement")
        governorLog("SummaryType: \(state.summaryType.rawValue)")
        governorLog("Accumulated words: \(state.accumulatedContent.split(separator: " ").count)")

        do {
            // Resume with accumulated content as starting point WITH governor enforcement
            let (result, governorResult) = try await performGeneration(
                bookText: bookText,
                state: state,
                settings: settings,
                resumeFromContent: state.accumulatedContent,
                governorContext: governorContext
            )

            var completedState = state
            completedState.phase = .completed
            completedState.accumulatedContent = result
            completedState.lastUpdated = Date()
            persistState(completedState)

            endBackgroundTask()
            isGenerating = false

            // Build metadata from governor enforcement result
            let metadata: GenerationMetadata?
            if let govResult = governorResult {
                // Generate audio if available
                let audioResult = await generateAudioIfAvailable(
                    content: result,
                    title: state.title,
                    generationId: state.id,
                    libraryItemId: state.existingItemId,
                    readerProfile: settings.preferredReaderProfile
                )

                metadata = GenerationMetadata(
                    summaryType: state.summaryType,
                    governedWordCount: govResult.wordCount,
                    cutPolicyActivated: govResult.cutPolicyActivated,
                    cutEventCount: govResult.cutEventCount,
                    audioFileURL: audioResult?.fileURL,
                    audioVoiceID: audioResult?.voiceID,
                    audioDuration: audioResult?.duration
                )
            } else {
                metadata = nil
            }

            // For resumed generations, cover image is not available (already saved previously)
            lastResult = .success(content: result, itemId: state.existingItemId, metadata: metadata, coverImagePath: nil)

            clearPersistedState()

            return result

        } catch {
            var failedState = state
            failedState.phase = .failed
            failedState.lastUpdated = Date()
            persistState(failedState)

            endBackgroundTask()
            isGenerating = false
            lastResult = .failure(error)

            throw error
        }
    }

    /// Discard interrupted generation state
    func discardInterruptedGeneration() {
        clearPersistedState()
        isGenerating = false
        currentGenerationId = nil
        progress = .initial
    }

    // MARK: - Background Task Registration

    /// Register background task handler with the system
    /// Call this from app initialization
    static func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTaskIdentifier.guideGeneration,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else { return }
            Task { @MainActor in
                await BackgroundGenerationCoordinator.shared.handleBackgroundTask(processingTask)
            }
        }
    }

    // MARK: - Private Methods

    /// Perform the actual generation with streaming governor enforcement
    private func performGeneration(
        bookText: String,
        state: GenerationState,
        settings: UserSettings,
        resumeFromContent: String? = nil,
        governorContext: StreamingGovernorContext? = nil,
        improvementHints: String? = nil
    ) async throws -> (content: String, governorResult: GovernorEnforcementResult?) {

        // Update state to processing
        var processingState = state
        processingState.phase = .processing
        processingState.lastUpdated = Date()
        persistState(processingState)

        // Use a dedicated state container to manage streaming updates safely
        // This avoids race conditions from multiple concurrent Task creations
        let streamState = StreamingState(
            initialContent: resumeFromContent ?? "",
            governor: governorContext,
            state: state,
            coordinator: self
        )

        // Determine hints - use provided hints (resume uses a continuation prompt in AIService)
        let effectiveHints = improvementHints

        // Generate guide using AIService
        var result: String
        do {
            result = try await aiService.generateGuide(
                bookText: bookText,
                title: state.title,
                author: state.author,
                settings: settings,
                previousContent: resumeFromContent,
                improvementHints: effectiveHints,
                onChunk: { [weak self, weak streamState] chunk in
                    // Process on MainActor to avoid race conditions
                    // The StreamingState class is @MainActor isolated
                    Task { @MainActor in
                        guard let self = self, let streamState = streamState else { return }
                        streamState.processChunk(chunk, coordinator: self)
                    }
                },
                onStatus: { [weak self, weak streamState] status in
                    Task { @MainActor in
                        guard let self = self, let streamState = streamState else { return }
                        streamState.processStatus(status, coordinator: self)
                    }
                },
                onReset: { [weak self, weak streamState] in
                    Task { @MainActor in
                        guard let self = self, let streamState = streamState else { return }
                        streamState.processReset(coordinator: self)
                        self.progress = GenerationProgress(
                        phase: "Refining with secondary model...",
                        percentComplete: 0.0,
                        wordCount: 0,
                        model: "OpenAI",
                        content: ""
                    )
                }
            },
            shouldTerminate: { [weak streamState] in
                streamState?.shouldTerminate ?? false
            }
        )
        } catch {
            if streamState.shouldTerminate {
                let finalContent = streamState.governor?.finalize() ?? streamState.displayContent
                return (finalContent, streamState.governor?.enforcementResult)
            }
            throw error
        }

        // Handle reset recovery
        let resetState = streamState.getResetState()
        if resetState.didReset,
           (streamState.governor?.accumulatedContent.isEmpty ?? true),
           let preserved = resetState.preservedContent,
           !preserved.isEmpty {
            streamState.governor?.restoreFromContent(preserved)
            streamState.setDisplayContent(preserved)
            result = preserved
        }

        // Finalize governor context if present
        let finalContent: String
        let governorResult: GovernorEnforcementResult?

        if let gov = streamState.governor {
            finalContent = sanitizeGeneratedContent(gov.finalize())
            governorResult = gov.enforcementResult
            governorLog("Generation complete with governor enforcement")
        } else {
            finalContent = sanitizeGeneratedContent(result)
            governorResult = nil
        }

        // Final progress update
        progress = GenerationProgress(
            phase: "Complete",
            percentComplete: 1.0,
            wordCount: finalContent.split(separator: " ").count,
            model: state.provider.displayName,
            content: finalContent
        )

        return (finalContent, governorResult)
    }

    private func sanitizeGeneratedContent(_ content: String) -> String {
        let lines = content.components(separatedBy: "\n")
        var output: [String] = []
        var openTagStack: [String] = []
        let closableTags: Set<String> = [
            "QUICK_GLANCE",
            "INSIGHT_NOTE",
            "ACTION_BOX",
            "FOUNDATIONAL_NARRATIVE",
            "TAKEAWAYS",
            "PREMIUM_QUOTE",
            "AUTHOR_SPOTLIGHT",
            "ALTERNATIVE_PERSPECTIVE",
            "RESEARCH_INSIGHT",
            "PREMIUM_H1",
            "PREMIUM_H2",
            "STRUCTURE_MAP"
        ]
        let knownTags: Set<String> = closableTags.union([
            "PREMIUM_DIVIDER",
            "PROCESS_TIMELINE",
            "CONCEPT_MAP"
        ])

        func parseOpenTagName(_ line: String) -> String? {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("[") && trimmed.hasSuffix("]") else { return nil }
            guard !trimmed.hasPrefix("[/") else { return nil }
            let raw = trimmed.dropFirst().dropLast()
            let tag = raw.split(separator: ":", maxSplits: 1).first.map { String($0) } ?? String(raw)
            return tag.uppercased()
        }

        func parseCloseTagName(_ line: String) -> String? {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("[/") && trimmed.hasSuffix("]") else { return nil }
            let raw = trimmed.dropFirst(2).dropLast()
            return String(raw).uppercased()
        }

        func isBareTagLine(_ line: String) -> Bool {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.range(of: #"^\[[A-Z_]+(:[^\]]+)?\]$"#, options: .regularExpression) != nil {
                return true
            }
            if trimmed.range(of: #"^\[/[A-Z_]+\]$"#, options: .regularExpression) != nil {
                return true
            }
            return false
        }

        func isNewBlockStart(_ line: String) -> Bool {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") {
                return true
            }
            return parseOpenTagName(trimmed) != nil
        }

        func convertMarkdownHeader(_ line: String) -> String? {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("### ") {
                let title = trimmed.dropFirst(4).trimmingCharacters(in: .whitespaces)
                return "[PREMIUM_H2]\(title)[/PREMIUM_H2]"
            }
            if trimmed.hasPrefix("## ") {
                let title = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
                return "[PREMIUM_H2]\(title)[/PREMIUM_H2]"
            }
            if trimmed.hasPrefix("# ") {
                let title = trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)
                return "[PREMIUM_H1]\(title)[/PREMIUM_H1]"
            }
            return nil
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if let open = openTagStack.last, isNewBlockStart(trimmed) {
                output.append("[/\(open)]")
                openTagStack.removeLast()
            }

            if !openTagStack.isEmpty, trimmed.hasPrefix("#") {
                continue
            }

            if openTagStack.isEmpty, let headerLine = convertMarkdownHeader(trimmed) {
                output.append(headerLine)
                continue
            }

            if let tagName = parseOpenTagName(trimmed) {
                if isBareTagLine(trimmed), !knownTags.contains(tagName), !tagName.hasPrefix("EXERCISE_") {
                    continue
                }
                if tagName.hasPrefix("EXERCISE_") || closableTags.contains(tagName) {
                    if isBareTagLine(trimmed) {
                        openTagStack.append(tagName)
                    }
                }
            } else if let tagName = parseCloseTagName(trimmed) {
                if isBareTagLine(trimmed), !knownTags.contains(tagName), !tagName.hasPrefix("EXERCISE_") {
                    continue
                }
                if let top = openTagStack.last, top == tagName {
                    openTagStack.removeLast()
                } else if let matchIndex = openTagStack.lastIndex(of: tagName) {
                    // Auto-close any nested tags before this closing tag.
                    while openTagStack.count - 1 > matchIndex {
                        let orphan = openTagStack.removeLast()
                        output.append("[/\(orphan)]")
                    }
                    openTagStack.removeLast()
                } else {
                    // Drop stray closing tags to avoid breaking downstream parsers.
                    if isBareTagLine(trimmed) {
                        continue
                    }
                }
            }

            output.append(line)
        }

        while let open = openTagStack.popLast() {
            output.append("[/\(open)]")
        }

        var sanitized = output.joined(separator: "\n")
        sanitized = sanitized.replacingOccurrences(
            of: "```[\\s\\S]*?```",
            with: "",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: #"(?m)^\s{0,3}>\s?"#,
            with: "",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: #"!?\[([^\]]+)\]\([^)]+\)"#,
            with: "$1",
            options: .regularExpression
        )
        return sanitized
    }

    /// Begin a UIKit background task for extended execution
    private func beginBackgroundTask() {
        guard backgroundTask == .invalid else { return }

        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "GuideGeneration") { [weak self] in
            // Expiration handler - save state and end task
            Task { @MainActor in
                self?.handleBackgroundTaskExpiration()
            }
        }
    }

    /// End the UIKit background task
    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    /// Handle background task expiration
    private func handleBackgroundTaskExpiration() {
        // Persist current state before suspension
        if var state = loadPersistedState() {
            state.accumulatedContent = progress.content
            state.lastUpdated = Date()
            persistState(state)
        }

        endBackgroundTask()
    }

    /// Schedule a BGProcessingTask for potential continuation
    private func scheduleBackgroundProcessing() {
        let request = BGProcessingTaskRequest(identifier: BackgroundTaskIdentifier.guideGeneration)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false

        // Request earliest execution
        request.earliestBeginDate = Date(timeIntervalSinceNow: 1)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            logger.error("Failed to schedule background task: \(error.localizedDescription)")
        }
    }

    /// Handle a scheduled BGProcessingTask
    private func handleBackgroundTask(_ task: BGProcessingTask) async {
        // Set expiration handler
        task.expirationHandler = { [weak self] in
            Task { @MainActor in
                self?.handleBackgroundTaskExpiration()
            }
        }

        // Check if we have interrupted generation to resume
        guard let state = loadPersistedState(),
              state.phase == .processing || state.phase == .streaming,
              let bookText = loadBookText(for: state) else {
            task.setTaskCompleted(success: true)
            return
        }

        // Attempt to resume generation
        // Note: We need valid API keys from persisted settings
        // This is a best-effort continuation
        do {
            // Load settings - this requires the keys to be accessible
            let settingsData = UserDefaults.standard.data(forKey: "insight_atlas_settings")
            guard let data = settingsData,
                  let settings = try? JSONDecoder().decode(UserSettings.self, from: data) else {
                task.setTaskCompleted(success: false)
                return
            }

            _ = try await performGeneration(
                bookText: bookText,
                state: state,
                settings: settings,
                resumeFromContent: state.accumulatedContent
            )

            task.setTaskCompleted(success: true)

        } catch {
            logger.error("Background task failed: \(error.localizedDescription)")
            task.setTaskCompleted(success: false)
        }
    }

    /// Check for interrupted generation on startup
    private func checkForInterruptedGeneration() async {
        guard let state = loadPersistedState() else { return }

        switch state.phase {
        case .processing, .streaming:
            // There's an interrupted generation
            // Update UI to reflect this
            currentGenerationId = state.id
            progress = GenerationProgress(
                phase: "Interrupted",
                percentComplete: 0,
                wordCount: state.accumulatedContent.split(separator: " ").count,
                model: state.provider.displayName,
                content: state.accumulatedContent
            )

        case .completed:
            // Generation completed but wasn't acknowledged
            lastResult = .success(content: state.accumulatedContent, itemId: state.existingItemId, metadata: nil, coverImagePath: nil)
            clearPersistedState()

        case .failed, .cancelled, .pending:
            // Clear stale state
            clearPersistedState()
        }
    }

    // MARK: - State Persistence

    /// Tracks whether state persistence has failed, to avoid repeated failures
    private var statePersistenceHealthy = true

    /// Persists generation state to UserDefaults.
    /// Logs errors and tracks persistence health for monitoring.
    /// Returns true if persistence succeeded, false otherwise.
    @discardableResult
    internal func persistState(_ state: GenerationState) -> Bool {
        do {
            let data = try JSONEncoder().encode(state)
            UserDefaults.standard.set(data, forKey: stateStorageKey)
            UserDefaults.standard.synchronize() // Force immediate write
            statePersistenceHealthy = true
            return true
        } catch {
            logger.error("State persistence failed: \(error.localizedDescription). Generation ID: \(state.id.uuidString)")
            statePersistenceHealthy = false

            // Post notification so UI can warn user if needed
            NotificationCenter.default.post(
                name: .generationPersistenceWarning,
                object: nil,
                userInfo: [
                    "generationId": state.id,
                    "error": error.localizedDescription,
                    "wordCount": state.accumulatedContent.split(separator: " ").count
                ]
            )
            return false
        }
    }

    private func loadPersistedState() -> GenerationState? {
        guard let data = UserDefaults.standard.data(forKey: stateStorageKey) else {
            return nil
        }
        do {
            return try JSONDecoder().decode(GenerationState.self, from: data)
        } catch {
            logger.error("Failed to decode persisted state: \(error.localizedDescription)")
            // State is corrupted, clear it
            UserDefaults.standard.removeObject(forKey: stateStorageKey)
            return nil
        }
    }

    private func clearPersistedState() {
        if let state = loadPersistedState() {
            // Clear book text storage
            let bookTextURL = bookTextStorageURL(for: state)
            do {
                try fileManager.removeItem(at: bookTextURL)
            } catch {
                logger.warning("Failed to remove cached book text: \(error.localizedDescription)")
                // Continue anyway - not critical
            }
        }
        UserDefaults.standard.removeObject(forKey: stateStorageKey)
        UserDefaults.standard.synchronize()
    }

    /// Persists book text to cache directory.
    /// Returns true if persistence succeeded, false otherwise.
    @discardableResult
    private func persistBookText(_ text: String, for state: GenerationState) -> Bool {
        let url = bookTextStorageURL(for: state)
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            logger.error("Failed to persist book text: \(error.localizedDescription). Generation ID: \(state.id.uuidString)")

            // Post notification so UI can warn user
            NotificationCenter.default.post(
                name: .generationPersistenceWarning,
                object: nil,
                userInfo: [
                    "generationId": state.id,
                    "error": error.localizedDescription,
                    "type": "bookText"
                ]
            )
            return false
        }
    }

    private func loadBookText(for state: GenerationState) -> String? {
        let url = bookTextStorageURL(for: state)
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            logger.error("Failed to load book text: \(error.localizedDescription). Generation ID: \(state.id.uuidString)")
            return nil
        }
    }

    private func bookTextStorageURL(for state: GenerationState) -> URL {
        let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return cachesDir.appendingPathComponent(state.bookTextStorageKey)
    }

    // MARK: - Governor Enforcement (Summary Type Governors v1.0)

    /// Calculate source word count after removing front/back matter
    private func calculateSourceWordCount(_ text: String) -> Int {
        // Remove common front matter patterns
        var cleanedText = text

        // Remove table of contents
        if let tocRange = cleanedText.range(of: "table of contents", options: .caseInsensitive) {
            if let endRange = cleanedText.range(of: "\n\n", range: tocRange.upperBound..<cleanedText.endIndex) {
                cleanedText.removeSubrange(tocRange.lowerBound..<endRange.upperBound)
            }
        }

        // Remove copyright/dedication pages (first 500 words typically)
        let words = cleanedText.split(separator: " ")
        let startIndex = min(500, words.count)

        // Remove bibliography/index (last 10% typically)
        let endIndex = max(startIndex, Int(Double(words.count) * 0.90))

        let contentWords = Array(words[startIndex..<endIndex])
        return contentWords.count
    }

    // NOTE: Post-hoc enforceGovernor method removed.
    // Governor enforcement now happens during streaming via StreamingGovernorContext.
    // See performGeneration() and StreamingGovernorContext class.

    // MARK: - Quality Validation

    /// Validates output quality and returns list of issues requiring improvement.
    /// Delegates to the centralized OutputQualityValidator for consistent validation.
    private func validateOutputQuality(content: String, governor: SummaryTypeGovernor) -> [String] {
        let result = OutputQualityValidator.validate(
            content: content,
            summaryType: governor.summaryType
        )
        governorLog("Quality validation complete: \(result.issues.count) issues found, score: \(String(format: "%.2f", result.score))")
        return result.issues
    }

    /// Generates improvement hints from quality issues
    private func generateImprovementHints(from issues: [String]) -> String {
        var hints = """
        The previous generation has quality issues that need to be addressed. Please improve the output by adding the following missing elements:

        """

        for (index, issue) in issues.enumerated() {
            hints += "\n\(index + 1). \(issue)"
        }

        hints += """


        IMPORTANT INSTRUCTIONS FOR IMPROVEMENT:
        - DO NOT regenerate the entire guide from scratch
        - Keep ALL existing content that is already good
        - Only add visuals when they materially improve clarity (do NOT add visuals to hit a quota)
        - ADD cross-discipline INSIGHT_NOTEs with Key Distinction, Practical Implication, and Go Deeper
        - Ensure visual variety - use different visual types in consecutive sections
        - Insert new elements at appropriate locations within the existing structure

        For visuals, choose the type that best matches the content:
        - VISUAL_COMPARISON_MATRIX for contrasts
        - VISUAL_TIMELINE for phases or sequences
        - VISUAL_CONCEPT_MAP for relationships
        - VISUAL_BAR_CHART / VISUAL_PIE_CHART for distributions
        - VISUAL_QUADRANT for trade-offs
        - VISUAL_FLOWCHART only when branching logic is essential

        For INSIGHT_NOTEs, connect to authors like:
        - Kahneman (thinking/decision-making)
        - Clear/Duhigg (habits)
        - Rosenberg (communication)
        - Brown (vulnerability)
        - Dweck (mindset)
        - Cialdini (influence)
        """

        return hints
    }

    // MARK: - Audio Generation

    /// Generate audio if ElevenLabs API key is available
    /// - Parameters:
    ///   - content: The text content to convert to audio
    ///   - title: Title for logging purposes
    ///   - generationId: UUID for unique file naming
    ///   - readerProfile: Reader profile to select appropriate voice
    private func generateAudioIfAvailable(
        content: String,
        title: String,
        generationId: UUID,
        libraryItemId: UUID? = nil,
        readerProfile: ReaderProfile = .practitioner
    ) async -> AudioGenerationResult? {

        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let audioContent = sanitizeAudioContent(trimmedContent)
        guard !audioContent.isEmpty else {
            audioLog("⚠️ Skipping audio generation: empty content")
            return nil
        }

        let wordCount = audioContent.split(whereSeparator: { $0.isWhitespace }).count
        if wordCount < 200 {
            audioLog("⚠️ Skipping audio generation: content too short (\(wordCount) words)")
            return nil
        }

        // Check for ElevenLabs API key
        guard let apiKey = KeychainService.shared.elevenLabsApiKey,
              !apiKey.isEmpty else {
            audioLog("⚠️ ElevenLabs API key not found - skipping audio generation")
            return nil
        }

        audioLog("Starting audio generation for: \(title)")

        // Determine voice to use: user-selected or profile default
        var voiceConfig: VoiceSelectionConfig
        if let userSelectedVoiceID = selectedVoiceID,
           let selectedVoice = ElevenLabsVoiceRegistry.voice(byVoiceID: userSelectedVoiceID) {
            // Use user-selected voice
            voiceConfig = .custom(profile: readerProfile, voice: selectedVoice)
            audioLog("Using user-selected voice: \(selectedVoice.name) (\(selectedVoice.voiceID))")
        } else {
            // Fall back to profile-based premium voice
            voiceConfig = VoiceSelectionConfig.premium(for: readerProfile)
            if !ElevenLabsVoiceRegistry.isPremiumVoiceID(voiceConfig.voiceID) {
                let fallback = ElevenLabsVoiceRegistry.premiumPrimaryVoice(for: readerProfile)
                voiceConfig = .custom(profile: readerProfile, voice: fallback)
            }
            audioLog("Reader profile: \(readerProfile.rawValue)")
            audioLog("Using profile voice: \(voiceConfig.voiceName) (\(voiceConfig.voiceID))")
        }

        do {
            // Create audio service (retrieves API key from Keychain internally)
            let audioService = ElevenLabsAudioService()

            // Generate audio for the content
            // For now, generate a single audio file for the entire summary
            let result = try await audioService.generateAudio(
                text: audioContent,
                voiceID: voiceConfig.voiceID
            )

            // Save audio to documents directory
            guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                audioLog("❌ Unable to access documents directory for audio file storage")
                return nil
            }
            let audioOwnerId = libraryItemId ?? generationId
            let audioFileName = "audio_\(audioOwnerId.uuidString).mp3"
            let audioFileURL = documentsDir.appendingPathComponent(audioFileName)

            try result.data.write(to: audioFileURL)
            audioLog("Audio file written to: \(audioFileURL.path)")

            // Verify file exists
            guard FileManager.default.fileExists(atPath: audioFileURL.path) else {
                audioLog("❌ Audio file write verification failed - file does not exist")
                return nil
            }
            audioLog("Audio file verified on disk")

            // Calculate duration from audio data
            let duration = try await calculateAudioDuration(from: audioFileURL)

            audioLog("✅ Audio generated successfully")
            audioLog("Duration: \(String(format: "%.1f", duration)) seconds")
            audioLog("File: \(audioFileName)")

            return AudioGenerationResult(
                fileURL: audioFileName,
                voiceID: voiceConfig.voiceID,
                duration: duration
            )

        } catch {
            audioLog("❌ Audio generation failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Calculate audio duration from file
    private func calculateAudioDuration(from url: URL) async throws -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }

    private func sanitizeAudioContent(_ content: String) -> String {
        var cleaned = content
        // Remove bracketed tags (e.g., [PREMIUM_H1], [VISUAL_FLOWCHART], [/VISUAL_FLOWCHART])
        cleaned = cleaned.replacingOccurrences(
            of: "\\[[^\\]]+\\]",
            with: "",
            options: .regularExpression
        )
        // Collapse excessive whitespace
        cleaned = cleaned.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Cover Image Saving

    /// Save cover image data to documents directory
    /// - Parameters:
    ///   - imageData: The image data to save
    ///   - itemId: The library item ID to associate with the cover
    /// - Returns: The relative path to the saved cover image, or nil if saving failed
    private func saveCoverImage(_ imageData: Data?, for itemId: UUID) -> String? {
        guard let data = imageData, !data.isEmpty else {
            logger.info("No cover image data to save")
            return nil
        }

        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            logger.error("Unable to access documents directory for cover image storage")
            return nil
        }

        // Create covers directory if needed
        let coversDir = documentsDir.appendingPathComponent("covers", isDirectory: true)
        if !fileManager.fileExists(atPath: coversDir.path) {
            do {
                try fileManager.createDirectory(at: coversDir, withIntermediateDirectories: true)
            } catch {
                logger.error("Failed to create covers directory: \(error.localizedDescription)")
                return nil
            }
        }

        // Save cover image with item ID as filename
        let coverFileName = "cover_\(itemId.uuidString).jpg"
        let coverURL = coversDir.appendingPathComponent(coverFileName)

        do {
            try data.write(to: coverURL)
            logger.info("Cover image saved to: \(coverURL.path)")

            // Return relative path (from documents directory)
            return "covers/\(coverFileName)"
        } catch {
            logger.error("Failed to save cover image: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Generation Errors

enum GenerationError: LocalizedError {
    case alreadyInProgress
    case noInterruptedGeneration
    case bookTextNotFound
    case cancelled
    case governorViolation(wordCount: Int, limit: Int)

    var errorDescription: String? {
        switch self {
        case .alreadyInProgress:
            return "A generation is already in progress"
        case .noInterruptedGeneration:
            return "No interrupted generation to resume"
        case .bookTextNotFound:
            return "Book text not found for resumption"
        case .cancelled:
            return "Generation was cancelled"
        case .governorViolation(let wordCount, let limit):
            return "Summary exceeded word limit (\(wordCount) > \(limit)). Strict enforcement halted generation."
        }
    }
}

// MARK: - Governor Enforcement Result

private struct GovernorEnforcementResult {
    let content: String
    let wordCount: Int
    let cutPolicyActivated: Bool
    let cutEventCount: Int
}

// MARK: - Audio Generation Result

private struct AudioGenerationResult {
    let fileURL: String
    let voiceID: String
    let duration: TimeInterval
}

// MARK: - Streaming Governor Context

// MARK: - Streaming State Actor

/// Thread-safe container for streaming generation state.
/// Uses actor isolation to prevent race conditions from concurrent callback execution.
@MainActor
private final class StreamingState {
    // MARK: - Properties

    private(set) var displayContent: String
    let governor: StreamingGovernorContext?
    private let generationState: GenerationState
    private weak var coordinator: BackgroundGenerationCoordinator?

    private(set) var shouldTerminate: Bool = false
    private var didResetForNewPass: Bool = false
    private var preservedGovernorContent: String?
    private var lastPersistWordCount: Int = 0

    // MARK: - Initialization

    init(initialContent: String, governor: StreamingGovernorContext?, state: GenerationState, coordinator: BackgroundGenerationCoordinator) {
        self.displayContent = initialContent
        self.governor = governor
        self.generationState = state
        self.coordinator = coordinator
    }

    // MARK: - Chunk Processing

    func processChunk(_ chunk: String, coordinator: BackgroundGenerationCoordinator) {
        // Check if we should stop
        guard !shouldTerminate else { return }

        // Process chunk through governor if available
        if let gov = governor {
            _ = gov.processChunk(chunk)

            // Check if governor signals termination
            if gov.shouldTerminate {
                shouldTerminate = true
                governorLog("Early termination signaled by governor")
            }

            // Use governor's accumulated content for display
            displayContent = gov.accumulatedContent
        } else {
            // No governor - accumulate directly
            displayContent += chunk
        }

        // Update progress
        let wordCount = displayContent.split(separator: " ").count
        let budget = governor?.totalBudget ?? 8000
        coordinator.progress = GenerationProgress(
            phase: governor != nil ? "Generating (governed)..." : "Generating...",
            percentComplete: min(Double(wordCount) / Double(budget), 0.95),
            wordCount: wordCount,
            model: generationState.provider.displayName,
            content: displayContent
        )

        // Persist accumulated content periodically (every 500 words)
        // Use threshold comparison to avoid multiple persists at same word count
        let persistThreshold = (wordCount / 500) * 500
        if persistThreshold > lastPersistWordCount && persistThreshold > 0 {
            lastPersistWordCount = persistThreshold
            var updatedState = generationState
            updatedState.phase = .streaming
            updatedState.accumulatedContent = displayContent
            updatedState.lastUpdated = Date()
            coordinator.persistState(updatedState)
        }
    }

    // MARK: - Status Processing

    func processStatus(_ status: GenerationStatus, coordinator: BackgroundGenerationCoordinator) {
        coordinator.progress = GenerationProgress(
            phase: status.phase.rawValue,
            percentComplete: status.progress,
            wordCount: status.wordCount,
            model: status.model,
            content: displayContent
        )
    }

    // MARK: - Reset Processing

    func processReset(coordinator: BackgroundGenerationCoordinator) {
        preservedGovernorContent = governor?.accumulatedContent
        didResetForNewPass = true
        displayContent = ""
        shouldTerminate = false
        lastPersistWordCount = 0
        governor?.resetForNewPass()
    }

    // MARK: - State Access

    func setDisplayContent(_ content: String) {
        displayContent = content
    }

    func getResetState() -> (didReset: Bool, preservedContent: String?) {
        return (didResetForNewPass, preservedGovernorContent)
    }
}

/// Manages governor enforcement during streaming generation.
///
/// Tracks word count, activates cut policy when thresholds are met,
/// and signals early termination when budget is exhausted.
@MainActor
private final class StreamingGovernorContext {

    // MARK: - Configuration

    let governor: SummaryTypeGovernor
    let engine: SummaryGovernorEngine
    let totalBudget: Int
    let sourceType: GovernorSourceType

    // MARK: - State

    private(set) var accumulatedContent: String = ""
    private(set) var wordCount: Int = 0
    private(set) var cutPolicyActivated: Bool = false
    private(set) var cutEventCount: Int = 0
    private(set) var shouldTerminate: Bool = false

    /// Buffer for incomplete sentences at chunk boundaries
    private var pendingBuffer: String = ""

    /// Tracks which sections have had syntheses applied
    private var synthesesPerSection: [Int: Int] = [:]
    private var currentSectionIndex: Int = 0

    // MARK: - Initialization

    init(
        governor: SummaryTypeGovernor,
        engine: SummaryGovernorEngine,
        totalBudget: Int,
        sourceType: GovernorSourceType
    ) {
        self.governor = governor
        self.engine = engine
        self.totalBudget = totalBudget
        self.sourceType = sourceType

        governorLog("StreamingGovernorContext initialized")
        governorLog("Budget: \(totalBudget) words, Ceiling: \(governor.maxWordCeiling)")
        governorLog("Cut trigger threshold: \(String(format: "%.0f", governor.cutPolicy.triggerThreshold * 100))%")
    }

    // MARK: - Reset

    func resetForNewPass() {
        accumulatedContent = ""
        wordCount = 0
        cutPolicyActivated = false
        cutEventCount = 0
        shouldTerminate = false
        pendingBuffer = ""
        synthesesPerSection.removeAll()
        currentSectionIndex = 0
        governorLog("StreamingGovernorContext reset for new pass")
    }

    func restoreFromContent(_ content: String) {
        accumulatedContent = content
        wordCount = content.split(whereSeparator: { $0.isWhitespace }).count
        cutPolicyActivated = false
        cutEventCount = 0
        shouldTerminate = false
        pendingBuffer = ""
        synthesesPerSection.removeAll()
        currentSectionIndex = 0
    }

    // MARK: - Chunk Processing

    /// Process an incoming chunk from the streaming response.
    ///
    /// - Parameter chunk: New text chunk from AI
    /// - Returns: The processed chunk (may be modified or empty if suppressed)
    func processChunk(_ chunk: String) -> String {
        // If we should terminate, reject all further content
        if shouldTerminate {
            return ""
        }

        // Combine with pending buffer
        let fullText = pendingBuffer + chunk

        // Find the last complete sentence boundary
        let (completeContent, remainder) = splitAtSentenceBoundary(fullText)
        pendingBuffer = remainder

        // If no complete sentences yet, just buffer
        if completeContent.isEmpty {
            return ""
        }

        // Check current utilization before processing
        let projectedWordCount = wordCount + completeContent.split(separator: " ").count

        // Check if we've hit the hard ceiling
        if projectedWordCount >= governor.maxWordCeiling {
            governorLog("⚠️ Approaching ceiling (\(projectedWordCount)/\(governor.maxWordCeiling)) - terminating")
            shouldTerminate = true

            // Accept only what fits within ceiling
            let remainingBudget = governor.maxWordCeiling - wordCount
            if remainingBudget > 0 {
                let truncated = truncateToWordCount(completeContent, maxWords: remainingBudget)
                accumulatedContent += truncated
                wordCount = accumulatedContent.split(separator: " ").count
                governorLog("Final content accepted: \(wordCount) words")
                return truncated
            }
            return ""
        }

        // Check if cut policy should activate
        let utilizationRatio = Float(projectedWordCount) / Float(totalBudget)
        if utilizationRatio >= governor.cutPolicy.triggerThreshold && !cutPolicyActivated {
            cutPolicyActivated = true
            governorLog("Cut policy ACTIVATED at \(String(format: "%.1f", utilizationRatio * 100))% utilization")
        }

        // If cut policy is active, filter content
        var processedContent = completeContent
        if cutPolicyActivated {
            processedContent = applyStreamingCuts(to: completeContent)
        }

        // Update section tracking (detect section headers)
        updateSectionTracking(content: processedContent)

        // Add to accumulated content
        accumulatedContent += processedContent
        wordCount = accumulatedContent.split(separator: " ").count

        // Log periodic updates
        if wordCount % 500 == 0 {
            governorLog("Progress: \(wordCount)/\(totalBudget) words (\(String(format: "%.1f", Float(wordCount) / Float(totalBudget) * 100))%)")
        }

        return processedContent
    }

    /// Finalize the context and return any remaining buffered content.
    func finalize() -> String {
        // Process any remaining buffer
        if !pendingBuffer.isEmpty && !shouldTerminate {
            let remainingBudget = governor.maxWordCeiling - wordCount
            if remainingBudget > 0 {
                var finalContent = pendingBuffer
                if cutPolicyActivated {
                    finalContent = applyStreamingCuts(to: finalContent)
                }
                finalContent = truncateToWordCount(finalContent, maxWords: remainingBudget)
                accumulatedContent += finalContent
                wordCount = accumulatedContent.split(separator: " ").count
            }
            pendingBuffer = ""
        }

        governorLog("Finalized: \(wordCount) words, cuts: \(cutEventCount)")
        return accumulatedContent
    }

    /// Get the current enforcement result
    var enforcementResult: GovernorEnforcementResult {
        GovernorEnforcementResult(
            content: accumulatedContent,
            wordCount: wordCount,
            cutPolicyActivated: cutPolicyActivated,
            cutEventCount: cutEventCount
        )
    }

    // MARK: - Private Methods

    /// Split text at the last sentence boundary
    private func splitAtSentenceBoundary(_ text: String) -> (complete: String, remainder: String) {
        // Find last sentence-ending punctuation followed by space or end
        let sentenceEnders: [Character] = [".", "!", "?"]

        var lastEndIndex: String.Index?
        var index = text.startIndex

        while index < text.endIndex {
            let char = text[index]
            if sentenceEnders.contains(char) {
                let nextIndex = text.index(after: index)
                if nextIndex == text.endIndex || text[nextIndex].isWhitespace {
                    lastEndIndex = nextIndex
                }
            }
            index = text.index(after: index)
        }

        if let endIndex = lastEndIndex {
            return (String(text[..<endIndex]), String(text[endIndex...]))
        }

        // No complete sentence found
        return ("", text)
    }

    /// Truncate text to a maximum word count at sentence boundary
    private func truncateToWordCount(_ text: String, maxWords: Int) -> String {
        let words = text.split(separator: " ")
        if words.count <= maxWords {
            return text
        }

        let truncated = words.prefix(maxWords).joined(separator: " ")

        // Find last sentence end
        if let lastEnd = truncated.lastIndex(where: { [".", "!", "?"].contains($0) }) {
            return String(truncated[...lastEnd])
        }

        return truncated
    }

    /// Apply streaming cuts for expansion types per cut order
    private func applyStreamingCuts(to content: String) -> String {
        var modifiedContent = content

        // Apply cuts in priority order
        for expansionType in governor.cutPolicy.cutOrder {
            if expansionType == .coreArgument {
                continue // Never cut core argument
            }

            let (newContent, didCut) = applyCutForType(
                content: modifiedContent,
                expansionType: expansionType
            )

            if didCut {
                modifiedContent = newContent
            }
        }

        return modifiedContent
    }

    /// Apply cut for a specific expansion type
    private func applyCutForType(content: String, expansionType: ExpansionType) -> (String, Bool) {
        let lowercased = content.lowercased()
        var didCut = false
        var result = content

        // Detect and suppress based on expansion type patterns
        switch expansionType {
        case .exercise:
            if lowercased.contains("exercise:") || lowercased.contains("try this:") ||
               lowercased.contains("practice:") || lowercased.contains("your turn:") {
                result = suppressExpansion(content, type: expansionType)
                didCut = true
            }

        case .adjacentDomainComparison:
            if lowercased.contains("similarly in") || lowercased.contains("just like in") ||
               lowercased.contains("analogous to") || lowercased.contains("much like") {
                result = suppressExpansion(content, type: expansionType)
                didCut = true
            }

        case .extendedCommentary:
            // Only cut if we have multiple commentary markers
            let markers = ["furthermore", "moreover", "in addition", "interestingly", "notably"]
            let matchCount = markers.filter { lowercased.contains($0) }.count
            if matchCount >= 2 {
                result = suppressExpansion(content, type: expansionType)
                didCut = true
            }

        case .secondaryExample:
            if lowercased.contains("another example") || lowercased.contains("for instance") ||
               lowercased.contains("consider also") || lowercased.contains("likewise,") {
                result = suppressExpansion(content, type: expansionType)
                didCut = true
            }

        case .stylisticElaboration:
            if lowercased.contains("in other words") || lowercased.contains("put simply") ||
               lowercased.contains("to put it another way") || lowercased.contains("essentially") {
                result = suppressExpansion(content, type: expansionType)
                didCut = true
            }

        case .coreArgument:
            // Never cut
            break
        }

        if didCut {
            cutEventCount += 1
            governorLog("Suppressed \(expansionType.rawValue) content (event #\(cutEventCount))")
        }

        return (result, didCut)
    }

    /// Suppress expansion content, optionally replacing with synthesis
    private func suppressExpansion(_ content: String, type: ExpansionType) -> String {
        // Check if we can add a synthesis for this section
        let currentCount = synthesesPerSection[currentSectionIndex, default: 0]

        if currentCount < governor.maxSynthesisPerSection {
            // Replace with synthesis
            synthesesPerSection[currentSectionIndex] = currentCount + 1
            return generateSynthesis(for: type)
        } else {
            // Synthesis cap reached - omit entirely
            return ""
        }
    }

    /// Generate a synthesis paragraph for suppressed content
    private func generateSynthesis(for expansionType: ExpansionType) -> String {
        switch sourceType {
        case .argumentative:
            return "\n\n*[Additional supporting material condensed. Core argument preserved.]*\n\n"
        case .narrative:
            return "\n\n*[Extended narrative elements condensed. Essential story preserved.]*\n\n"
        case .technical:
            return "\n\n*[Supplementary technical details condensed. Core procedures documented.]*\n\n"
        }
    }

    /// Update section tracking based on content headers
    private func updateSectionTracking(content: String) {
        // Detect section boundaries (Part headers, ## headers, etc.)
        let patterns = [
            "## Part",
            "# Part",
            "PART ",
            "## Chapter",
            "# Chapter",
            "Synthesis Arc"
        ]

        for pattern in patterns {
            if content.contains(pattern) {
                currentSectionIndex += 1
                governorLog("New section detected: \(currentSectionIndex)")
                break
            }
        }
    }
}

// MARK: - Notification Names
// Centralized notification names for app-wide events

extension Notification.Name {
    /// Posted when generation persistence encounters a non-fatal warning
    static let generationPersistenceWarning = Notification.Name("generationPersistenceWarning")

    /// Posted when library data fails to load
    static let libraryLoadFailed = Notification.Name("libraryLoadFailed")

    /// Posted when audio playback finishes
    static let audioPlaybackDidFinish = Notification.Name("audioPlaybackDidFinish")

    /// Posted when audio generation completes
    static let audioGenerationDidComplete = Notification.Name("audioGenerationDidComplete")

    /// Posted when bulk export completes
    static let bulkExportDidComplete = Notification.Name("bulkExportDidComplete")
}
