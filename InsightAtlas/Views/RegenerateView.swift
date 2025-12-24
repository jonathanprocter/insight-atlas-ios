//
//  RegenerateView.swift
//  InsightAtlas
//
//  View for regenerating guide content with quality audit and iteration.
//

import SwiftUI

struct RegenerateView: View {

    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss

    let item: LibraryItem
    let onComplete: (String, Int) -> Void

    @State private var isGenerating = false
    @State private var currentContent = ""
    @State private var iterationCount = 0
    @State private var currentScore = 0
    @State private var phase: RegeneratePhase = .ready
    @State private var auditReport: QualityAuditService.AuditReport?
    @State private var errorMessage: String?
    @State private var showingError = false

    // User-selectable generation options
    @State private var selectedProvider: AIProvider = .both
    @State private var selectedMode: GenerationMode = .deepResearch
    @State private var selectedTone: ToneMode = .professional

    private let aiService = AIService()
    private let bookProcessor = BookProcessor()

    private let maxIterations = 3
    private let passingThreshold = 95

    enum RegeneratePhase: String {
        case ready = "Ready to Regenerate"
        case extracting = "Extracting Book Content..."
        case generating = "Generating Guide..."
        case auditing = "Running Quality Audit..."
        case improving = "Improving Content..."
        case complete = "Generation Complete"
        case failed = "Generation Failed"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Status Header
                    statusHeader

                    // Generation Options (shown when ready or failed)
                    if phase == .ready || phase == .failed {
                        generationOptionsSection
                    }

                    // Progress Section
                    progressSection

                    // Audit Results (when available)
                    if let report = auditReport {
                        auditResultsSection(report: report)
                    }

                    // Content Preview
                    if !currentContent.isEmpty {
                        contentPreview
                    }

                    Spacer(minLength: 20)

                    // Action Buttons
                    actionButtons
                }
            }
            .padding()
            .background(InsightAtlasColors.background)
            .navigationTitle("Regenerate Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isGenerating)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred.")
            }
        }
        .onAppear {
            // Initialize with user's saved settings
            selectedProvider = dataManager.userSettings.preferredProvider
            selectedMode = dataManager.userSettings.preferredMode
            selectedTone = dataManager.userSettings.preferredTone
        }
    }

    // MARK: - View Components

    private var generationOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Generation Options")
                .font(InsightAtlasTypography.h4)
                .foregroundColor(InsightAtlasColors.heading)

            // AI Provider Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("AI Provider")
                    .font(InsightAtlasTypography.captionBold)
                    .foregroundColor(InsightAtlasColors.muted)

                Picker("Provider", selection: $selectedProvider) {
                    ForEach(AIProvider.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Generation Mode Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Analysis Depth")
                    .font(InsightAtlasTypography.captionBold)
                    .foregroundColor(InsightAtlasColors.muted)

                Picker("Mode", selection: $selectedMode) {
                    ForEach(GenerationMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Tone Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Writing Style")
                    .font(InsightAtlasTypography.captionBold)
                    .foregroundColor(InsightAtlasColors.muted)

                Picker("Tone", selection: $selectedTone) {
                    ForEach(ToneMode.allCases, id: \.self) { tone in
                        Text(tone.displayName).tag(tone)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding()
        .background(InsightAtlasColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var statusHeader: some View {
        VStack(spacing: 12) {
            // Phase Icon
            ZStack {
                Circle()
                    .fill(phaseColor.opacity(0.15))
                    .frame(width: 80, height: 80)

                if isGenerating {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(phaseColor)
                } else {
                    Image(systemName: phaseIcon)
                        .font(.system(size: 32))
                        .foregroundColor(phaseColor)
                }
            }

            // Phase Text
            Text(phase.rawValue)
                .font(InsightAtlasTypography.h3)
                .foregroundColor(InsightAtlasColors.heading)

            // Iteration Counter
            if iterationCount > 0 {
                Text("Iteration \(iterationCount) of \(maxIterations)")
                    .font(InsightAtlasTypography.caption)
                    .foregroundColor(InsightAtlasColors.muted)
            }
        }
    }

    private var progressSection: some View {
        VStack(spacing: 16) {
            // Score Progress
            if currentScore > 0 {
                VStack(spacing: 8) {
                    HStack {
                        Text("Quality Score")
                            .font(InsightAtlasTypography.captionBold)
                            .foregroundColor(InsightAtlasColors.muted)
                        Spacer()
                        Text("\(currentScore)%")
                            .font(InsightAtlasTypography.h3)
                            .foregroundColor(currentScore >= passingThreshold ? .green : InsightAtlasColors.coral)
                    }

                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(InsightAtlasColors.ruleLight)
                                .frame(height: 8)
                                .clipShape(Capsule())

                            Rectangle()
                                .fill(currentScore >= passingThreshold ? Color.green : InsightAtlasColors.gold)
                                .frame(width: geometry.size.width * CGFloat(currentScore) / 100, height: 8)
                                .clipShape(Capsule())

                            // Threshold marker
                            Rectangle()
                                .fill(InsightAtlasColors.burgundy)
                                .frame(width: 2, height: 12)
                                .offset(x: geometry.size.width * CGFloat(passingThreshold) / 100 - 1)
                        }
                    }
                    .frame(height: 12)

                    HStack {
                        Text("Threshold: \(passingThreshold)%")
                            .font(InsightAtlasTypography.caption)
                            .foregroundColor(InsightAtlasColors.muted)
                        Spacer()
                        if currentScore >= passingThreshold {
                            Label("Passed", systemImage: "checkmark.seal.fill")
                                .font(InsightAtlasTypography.captionBold)
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding()
                .background(InsightAtlasColors.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func auditResultsSection(report: QualityAuditService.AuditReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quality Audit Results")
                .font(InsightAtlasTypography.h4)
                .foregroundColor(InsightAtlasColors.heading)

            // Failed checks (if any)
            if !report.failedChecks.isEmpty && !report.meetsThreshold {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Issues Found:")
                        .font(InsightAtlasTypography.captionBold)
                        .foregroundColor(InsightAtlasColors.coral)

                    ForEach(report.failedChecks.prefix(5), id: \.self) { check in
                        Text(check)
                            .font(InsightAtlasTypography.caption)
                            .foregroundColor(InsightAtlasColors.muted)
                    }

                    if report.failedChecks.count > 5 {
                        Text("... and \(report.failedChecks.count - 5) more")
                            .font(InsightAtlasTypography.caption)
                            .foregroundColor(InsightAtlasColors.muted)
                            .italic()
                    }
                }
            }

            // Passed summary
            if report.meetsThreshold {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("All quality criteria met!")
                        .font(InsightAtlasTypography.uiBody)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InsightAtlasColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var contentPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Content Preview")
                .font(InsightAtlasTypography.captionBold)
                .foregroundColor(InsightAtlasColors.muted)

            ScrollView {
                Text(currentContent.prefix(1000) + (currentContent.count > 1000 ? "..." : ""))
                    .font(InsightAtlasTypography.bodySmall)
                    .foregroundColor(InsightAtlasColors.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 150)
        }
        .padding()
        .background(InsightAtlasColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if phase == .ready {
                Button {
                    startRegeneration()
                } label: {
                    Label("Start Regeneration", systemImage: "wand.and.stars")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(InsightAtlasPrimaryButtonStyle())
            } else if phase == .complete && currentScore >= passingThreshold {
                Button {
                    onComplete(currentContent, currentScore)
                } label: {
                    Label("Save & Use This Guide", systemImage: "checkmark.circle.fill")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(InsightAtlasPrimaryButtonStyle())
            } else if phase == .complete && currentScore < passingThreshold {
                VStack(spacing: 8) {
                    Text("Guide did not meet quality threshold after \(maxIterations) iterations.")
                        .font(InsightAtlasTypography.caption)
                        .foregroundColor(InsightAtlasColors.coral)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 12) {
                        Button {
                            // Try again
                            iterationCount = 0
                            startRegeneration()
                        } label: {
                            Label("Try Again", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(InsightAtlasSecondaryButtonStyle())

                        Button {
                            // Accept anyway
                            onComplete(currentContent, currentScore)
                        } label: {
                            Label("Use Anyway", systemImage: "checkmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(InsightAtlasPrimaryButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var phaseColor: Color {
        switch phase {
        case .ready:
            return InsightAtlasColors.gold
        case .extracting, .generating, .auditing, .improving:
            return InsightAtlasColors.gold
        case .complete:
            return currentScore >= passingThreshold ? .green : InsightAtlasColors.coral
        case .failed:
            return InsightAtlasColors.coral
        }
    }

    private var phaseIcon: String {
        switch phase {
        case .ready:
            return "arrow.triangle.2.circlepath"
        case .extracting:
            return "doc.text.magnifyingglass"
        case .generating:
            return "wand.and.stars"
        case .auditing:
            return "checklist"
        case .improving:
            return "arrow.up.circle"
        case .complete:
            return currentScore >= passingThreshold ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }

    // MARK: - Methods

    private func startRegeneration() {
        isGenerating = true
        phase = .generating
        iterationCount += 1

        Task {
            do {
                // Generate new content
                let newContent = try await generateContent()

                await MainActor.run {
                    currentContent = newContent
                    phase = .auditing
                }

                // Run quality audit
                let report = QualityAuditService.generateAuditReport(content: newContent)

                await MainActor.run {
                    auditReport = report
                    currentScore = report.overallScore
                }

                // Check if we need to iterate
                if report.meetsThreshold {
                    await MainActor.run {
                        phase = .complete
                        isGenerating = false
                    }
                } else if iterationCount < maxIterations {
                    await MainActor.run {
                        phase = .improving
                    }

                    // Regenerate with improvement focus
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                    startRegeneration()
                } else {
                    await MainActor.run {
                        phase = .complete
                        isGenerating = false
                    }
                }

            } catch {
                await MainActor.run {
                    phase = .failed
                    isGenerating = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }

    private func generateContent() async throws -> String {
        // Create settings with user-selected options from the UI
        var settings = dataManager.userSettings
        settings.preferredProvider = selectedProvider
        settings.preferredMode = selectedMode
        settings.preferredTone = selectedTone

        // Build improvement prompt based on failed checks
        var improvementHints: String? = nil
        var previousContentForImprovement: String? = nil

        if let report = auditReport, iterationCount > 1, !currentContent.isEmpty {
            // This is an improvement iteration - pass previous content to enhance
            previousContentForImprovement = currentContent
            improvementHints = "Previous attempt scored \(report.overallScore)%. Please ensure you include:\n"
            for section in report.missingSections {
                improvementHints! += "- \(section)\n"
            }
            for check in report.failedChecks.prefix(5) {
                improvementHints! += "- Fix: \(check)\n"
            }
        }

        // Clear current content for fresh streaming (will be replaced, not appended)
        await MainActor.run {
            currentContent = ""
        }

        // Generate using selected options
        let result = try await aiService.generateGuide(
            bookText: item.summaryContent ?? "Book content not available",
            title: item.title,
            author: item.author,
            settings: settings,
            previousContent: previousContentForImprovement,
            improvementHints: improvementHints,
            onChunk: { chunk in
                Task { @MainActor in
                    currentContent += chunk
                }
            },
            onStatus: { _ in },
            onReset: {
                Task { @MainActor in
                    currentContent = ""
                }
            }
        )

        return result
    }
}

#Preview {
    RegenerateView(
        item: LibraryItem(
            title: "Test Book",
            author: "Test Author",
            fileType: .pdf,
            summaryContent: nil,
            provider: .claude,
            mode: .standard
        ),
        onComplete: { _, _ in }
    )
    .environmentObject(DataManager())
}
