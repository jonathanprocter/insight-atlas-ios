//
//  AudioVisualBridge.swift
//  InsightAtlas
//
//  Audio-Visual Meaning Bridging Service.
//
//  When a visual exists and audio is active, this service generates
//  narrative bridges that convey the same MEANING as the visual
//  without describing the visual literally.
//
//  CRITICAL RULES:
//  - NEVER reference "diagram", "chart", "image", "figure"
//  - NEVER say "as you can see" or "this shows"
//  - USE abstract conceptual language
//  - CONVEY the thinking model, not the visual representation
//
//  GOVERNANCE:
//  - Bridges are inserted at the semantic block level
//  - No visual logic in SwiftUI views
//  - Audio listeners receive equivalent understanding
//
//  VERSION: 1.0.0
//

import Foundation
import CryptoKit

// MARK: - Audio Visual Bridge

/// Represents a narrative bridge that replaces a visual's meaning in audio
enum AudioVisualBridge: Codable, Equatable {
    /// No bridge needed (block has no visual)
    case none

    /// Insert a narrative summary of the visual's meaning
    case summarizeMeaning(String)

    /// The bridge text, if any
    var bridgeText: String? {
        switch self {
        case .none:
            return nil
        case .summarizeMeaning(let text):
            return text
        }
    }

    /// Whether this bridge requires insertion
    var requiresInsertion: Bool {
        switch self {
        case .none:
            return false
        case .summarizeMeaning:
            return true
        }
    }
}

// MARK: - Audio Visual Bridge Generator

/// Generates narrative bridges for visual content in audio narration
final class AudioVisualBridgeGenerator {

    // MARK: - Bridge Generation

    /// Generate a narrative bridge for a block with a visual
    ///
    /// - Parameters:
    ///   - block: The editorial block
    ///   - visualType: The type of visual associated with the block
    /// - Returns: A narrative bridge that conveys the visual's meaning
    func generateBridge(
        for block: EditorialBlock,
        visualType: GuideVisualType?
    ) -> AudioVisualBridge {
        guard let visualType = visualType else {
            return .none
        }

        // Generate bridge based on block type and visual type
        let bridgeText = generateBridgeText(
            blockType: block.type,
            visualType: visualType,
            block: block
        )

        guard let text = bridgeText else {
            return .none
        }

        return .summarizeMeaning(text)
    }

    // MARK: - Bridge Text Generation

    private func generateBridgeText(
        blockType: EditorialBlockType,
        visualType: GuideVisualType,
        block: EditorialBlock
    ) -> String? {
        switch (blockType, visualType) {

        // MARK: - Decision Tree Bridges
        case (.decisionTree, .flowDiagram):
            return generateDecisionTreeBridge(block)

        // MARK: - Process Flow Bridges
        case (.processFlow, .timeline):
            return generateProcessFlowBridge(block)

        // MARK: - Framework Bridges
        case (.framework, .conceptMap):
            return generateFrameworkBridge(block)

        // MARK: - Concept Map Bridges
        case (.conceptMap, .conceptMap):
            return generateConceptMapBridge(block)

        // MARK: - Comparison Bridges
        case (.comparisonBeforeAfter, .comparisonMatrix):
            return generateComparisonBridge(block)

        // MARK: - Research Insight Bridges
        case (.researchInsight, .barChart):
            return generateResearchBridge(block)

        // MARK: - Other combinations
        default:
            return generateGenericBridge(blockType: blockType, visualType: visualType, block: block)
        }
    }

    // MARK: - Specific Bridge Generators

    /// Generate bridge for decision tree
    /// Conveys: branching paths and choices
    private func generateDecisionTreeBridge(_ block: EditorialBlock) -> String? {
        guard let branches = block.branches, !branches.isEmpty else {
            return "At this point, there are multiple possible paths, each leading to different outcomes."
        }

        let pathCount = branches.count
        if pathCount == 2 {
            return "At this point, there are two possible paths. " +
                   "One leads in one direction, the other takes you somewhere different. " +
                   "The choice depends on your specific situation."
        } else {
            return "Here, you face \(pathCount) distinct options. " +
                   "Each path leads to a different outcome. " +
                   "Consider which best fits your circumstances."
        }
    }

    /// Generate bridge for process flow
    /// Conveys: sequential steps
    private func generateProcessFlowBridge(_ block: EditorialBlock) -> String? {
        guard let steps = block.steps, !steps.isEmpty else {
            if let items = block.listItems, !items.isEmpty {
                return "This unfolds in \(items.count) sequential stages, each building on the previous."
            }
            return "This follows a clear sequence of stages, each one preparing you for the next."
        }

        let stepCount = steps.count
        return "This unfolds in \(stepCount) sequential steps. " +
               "Each stage builds on the previous, creating a natural progression."
    }

    /// Generate bridge for framework
    /// Conveys: conceptual grouping and relationships
    private func generateFrameworkBridge(_ block: EditorialBlock) -> String? {
        guard let items = block.listItems, !items.isEmpty else {
            return "This concept rests on several interconnected components that work together."
        }

        let itemCount = items.count
        let title = block.title ?? "This framework"

        switch itemCount {
        case 2:
            return "\(title) consists of two fundamental elements that balance each other."
        case 3:
            return "\(title) rests on three interconnected pillars. " +
                   "Together, they form a stable foundation."
        case 4:
            return "\(title) comprises four key dimensions. " +
                   "Each contributes something essential to the whole."
        default:
            return "\(title) integrates \(itemCount) distinct components. " +
                   "Understanding how they relate reveals the deeper pattern."
        }
    }

    /// Generate bridge for concept map
    /// Conveys: interconnected ideas
    private func generateConceptMapBridge(_ block: EditorialBlock) -> String? {
        let title = block.title ?? "These ideas"
        return "\(title) connect in ways that aren't immediately obvious. " +
               "Each element influences the others, creating a web of relationships."
    }

    /// Generate bridge for comparison
    /// Conveys: contrast between states
    private func generateComparisonBridge(_ block: EditorialBlock) -> String? {
        return "Consider the contrast between these two states. " +
               "The differences highlight what changes—and what remains constant."
    }

    /// Generate bridge for research insight
    /// Conveys: data-backed finding
    private func generateResearchBridge(_ block: EditorialBlock) -> String? {
        return "The research reveals a clear pattern. " +
               "The numbers tell a story that supports the central insight."
    }

    /// Generate generic bridge for other combinations
    private func generateGenericBridge(
        blockType: EditorialBlockType,
        visualType: GuideVisualType,
        block: EditorialBlock
    ) -> String? {
        switch visualType {
        case .flowDiagram:
            return "This represents a flow of decisions and their consequences."
        case .timeline:
            return "This follows a progression through distinct phases."
        case .conceptMap:
            return "These concepts connect in meaningful ways."
        case .comparisonMatrix:
            return "The comparison reveals important differences."
        case .barChart:
            return "The data reveals a significant pattern."
        case .quadrant:
            return "This maps along two important dimensions."
        }
    }
}

// MARK: - Audio Block Plan Extension

extension AudioBlockPlan {

    /// Create an enhanced plan with visual bridge
    func withVisualBridge(_ bridge: AudioVisualBridge) -> AudioBlockPlanWithBridge {
        return AudioBlockPlanWithBridge(
            basePlan: self,
            visualBridge: bridge
        )
    }
}

// MARK: - Audio Block Plan with Bridge

/// Audio block plan enhanced with visual bridge
struct AudioBlockPlanWithBridge: Identifiable, Codable {
    let id: UUID
    let basePlan: AudioBlockPlan
    let visualBridge: AudioVisualBridge

    var blockId: UUID { basePlan.blockId }
    var blockType: EditorialBlockType { basePlan.blockType }
    var behavior: AudioNarrationBehavior { basePlan.behavior }

    /// Full narration text including bridge
    var fullText: String {
        if let bridgeText = visualBridge.bridgeText {
            return bridgeText + " " + basePlan.text
        }
        return basePlan.text
    }

    /// Estimated duration including bridge
    var estimatedDuration: TimeInterval {
        var duration = basePlan.estimatedDuration

        if let bridgeText = visualBridge.bridgeText {
            // Add time for bridge (roughly 150 words per minute)
            let bridgeWords = Double(bridgeText.split(separator: " ").count)
            duration += (bridgeWords / 150.0) * 60.0
            // Add a pause before bridge
            duration += 0.5
        }

        return duration
    }

    init(id: UUID = UUID(), basePlan: AudioBlockPlan, visualBridge: AudioVisualBridge) {
        self.id = id
        self.basePlan = basePlan
        self.visualBridge = visualBridge
    }
}

// MARK: - Enhanced Audio Narration Plan

/// Complete narration plan with visual bridges
struct EnhancedAudioNarrationPlan: Identifiable, Codable {
    let id: UUID
    let documentId: UUID
    let documentTitle: String
    let profile: ReaderProfile
    let voiceConfig: VoiceSelectionConfig
    let blocks: [AudioBlockPlanWithBridge]
    let generatedAt: Date
    let version: String

    /// Total estimated duration
    var totalDuration: TimeInterval {
        blocks.reduce(0) { $0 + $1.estimatedDuration }
    }

    /// Formatted duration
    var formattedDuration: String {
        let minutes = Int(totalDuration) / 60
        let seconds = Int(totalDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Content hash for caching (includes voice)
    var planHash: String {
        let combined = blocks.map { $0.basePlan.contentHash }.joined() +
                       profile.rawValue +
                       voiceConfig.voiceID +
                       version
        let data = Data(combined.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    init(
        id: UUID = UUID(),
        documentId: UUID,
        documentTitle: String,
        profile: ReaderProfile,
        voiceConfig: VoiceSelectionConfig,
        blocks: [AudioBlockPlanWithBridge],
        generatedAt: Date = Date(),
        version: String = "audio-v1.1"
    ) {
        self.id = id
        self.documentId = documentId
        self.documentTitle = documentTitle
        self.profile = profile
        self.voiceConfig = voiceConfig
        self.blocks = blocks
        self.generatedAt = generatedAt
        self.version = version
    }
}

// MARK: - Enhanced Audio Narration Service

/// Extended service that generates narration plans with visual bridges
final class EnhancedAudioNarrationService {

    private let baseService = AudioNarrationService()
    private let bridgeGenerator = AudioVisualBridgeGenerator()

    /// Generate an enhanced audio narration plan with visual bridges
    ///
    /// - Parameters:
    ///   - document: Normalized editorial document
    ///   - profile: Reader profile
    ///   - visualSelections: Visual selections for blocks (optional)
    ///   - voiceConfig: Voice configuration (optional, uses primary for profile)
    /// - Returns: Enhanced narration plan with visual bridges
    func generateEnhancedPlan(
        for document: EditorialDocument,
        profile: ReaderProfile,
        visualSelections: [UUID: VisualSelectionService.VisualSelection]? = nil,
        voiceConfig: VoiceSelectionConfig? = nil
    ) -> EnhancedAudioNarrationPlan {

        let config = voiceConfig ?? VoiceSelectionConfig.primary(for: profile)
        let basePlan = baseService.generatePlan(for: document, profile: profile)

        // Generate enhanced blocks with visual bridges
        let enhancedBlocks = basePlan.blocks.map { blockPlan -> AudioBlockPlanWithBridge in
            // Find the original block
            guard let block = document.blocks.first(where: { $0.id == blockPlan.blockId }) else {
                return blockPlan.withVisualBridge(.none)
            }

            // Check if block has a visual
            let visualType: GuideVisualType?
            if let selections = visualSelections,
               let selection = selections[block.id],
               selection.shouldHaveVisual {
                visualType = selection.visualType
            } else {
                visualType = nil
            }

            // Generate bridge if visual exists
            let bridge = bridgeGenerator.generateBridge(for: block, visualType: visualType)
            return blockPlan.withVisualBridge(bridge)
        }

        return EnhancedAudioNarrationPlan(
            documentId: document.id,
            documentTitle: document.title,
            profile: profile,
            voiceConfig: config,
            blocks: enhancedBlocks
        )
    }
}

// MARK: - Enhanced Audio Cache Key

/// Cache key for enhanced audio narration (includes voice)
struct EnhancedAudioCacheKey: Hashable, Codable {
    let textHash: String
    let profile: ReaderProfile
    let voiceID: String
    let narrationVersion: String

    init(
        blockPlan: AudioBlockPlanWithBridge,
        profile: ReaderProfile,
        voiceID: String,
        version: String = "audio-v1.1"
    ) {
        // Include bridge in hash if present
        let fullText = blockPlan.fullText
        let data = Data((fullText + blockPlan.blockType.rawValue + blockPlan.behavior.rawValue).utf8)
        let hash = SHA256.hash(data: data)
        self.textHash = hash.compactMap { String(format: "%02x", $0) }.joined()
        self.profile = profile
        self.voiceID = voiceID
        self.narrationVersion = version
    }

    /// Cache key from enhanced plan
    static func keys(from plan: EnhancedAudioNarrationPlan) -> [EnhancedAudioCacheKey] {
        plan.blocks.map { block in
            EnhancedAudioCacheKey(
                blockPlan: block,
                profile: plan.profile,
                voiceID: plan.voiceConfig.voiceID,
                version: plan.version
            )
        }
    }
}
