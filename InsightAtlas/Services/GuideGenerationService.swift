//
//  GuideGenerationService.swift
//  InsightAtlas
//
//  Service for orchestrating guide generation via the optional backend API.
//
//  NOTE: This service uses the optional backend API integration.
//  The main app uses direct AI provider APIs via BackgroundGenerationCoordinator.
//  This service is only used for the "Generate via Backend" feature.
//

import Foundation

@MainActor
final class GuideGenerationService: ObservableObject {

    @Published var isGenerating: Bool = false
    @Published var lastResult: GenerateGuideResponse?
    @Published var lastError: String?

    /// Check if backend API is available
    var isBackendConfigured: Bool {
        InsightAtlasAPI.shared.isConfigured
    }

    func generate(
        sourceText: String,
        readerProfile: ReaderProfile = .executive,
        editorialStance: EditorialStance = .neutralAnalyst,
        model: LLMProvider = .anthropic
    ) async {
        // Check if backend is configured
        guard isBackendConfigured else {
            lastError = "Backend API is not configured. Use the standard generation flow instead."
            return
        }

        isGenerating = true
        lastError = nil
        defer { isGenerating = false }

        let request = GenerateGuideRequest(
            sourceType: .uploadedText,
            sourceValue: sourceText,
            readerProfile: readerProfile,
            editorialStance: editorialStance,
            model: model
        )

        do {
            let response = try await InsightAtlasAPI.shared.generateGuide(request: request)
            self.lastResult = response
        } catch let error as InsightAtlasAPIError {
            lastError = error.localizedDescription
        } catch {
            lastError = "Backend generation failed: \(error.localizedDescription)"
        }
    }
}
