//
//  AnalysisExportOptionsView.swift
//  InsightAtlas
//
//  Export sheet extracted from AnalysisDetailView.
//

import SwiftUI
import UIKit

// MARK: - Export Options View

struct AnalysisExportOptionsView: View {
    let item: LibraryItem
    let parsedContent: ParsedAnalysisContent?
    let layoutScore: LayoutScore?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    @State private var isExporting = false
    @State private var exportError: String?

    var body: some View {
        NavigationView {
            List {
                Section("Export Format") {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Button(action: { exportAs(format) }) {
                            HStack {
                                Label(format.rawValue, systemImage: iconFor(format))
                                Spacer()
                                // Show warning icon for low layout scores
                                if let score = layoutScore {
                                    let formatScore = scoreFor(format: format, from: score)
                                    if formatScore < 0.85 {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(PremiumUI.emberDeep)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                        .disabled(isExporting)
                    }
                }

                // Layout quality warning
                if let score = layoutScore {
                    let pdfScore = score.pdf
                    if pdfScore < 0.85 {
                        Section {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(PremiumUI.emberDeep)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Layout quality may be reduced")
                                        .font(.subheadline.weight(.medium))
                                    Text("PDF score: \(Int(pdfScore * 100))%. Some sections may need adjustment.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if let error = exportError {
                    Section {
                        Text(error)
                            .foregroundColor(PremiumUI.destructive)
                    }
                }
            }
            .navigationTitle("Export Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if isExporting {
                    ProgressView("Exporting...")
                        .padding()
                        .background(PremiumUI.card)
                        .cornerRadius(10)
                        .shadow(radius: 10)
                }
            }
        }
    }

    private func iconFor(_ format: ExportFormat) -> String {
        switch format {
        case .markdown: return "doc.text"
        case .plainText: return "doc.plaintext"
        case .html: return "globe"
        case .pdf: return "doc.fill"
        case .docx: return "doc.richtext"
        }
    }

    private func scoreFor(format: ExportFormat, from score: LayoutScore) -> Double {
        switch format {
        case .pdf: return score.pdf
        case .docx: return score.docx
        case .html: return score.html
        case .markdown, .plainText: return score.overall
        }
    }

    private func exportAs(_ format: ExportFormat) {
        isExporting = true
        exportError = nil

        Task { @MainActor in
            do {
                // For PDF export, prefetch all visual images to ensure they're cached locally
                if format == .pdf, InsightAtlasConfig.visualsEnabled, let content = parsedContent {
                    let visualURLs = content.allVisualURLs()
                    if !visualURLs.isEmpty {
                        await VisualAssetCache.shared.prefetchAll(urls: visualURLs)
                    }
                }

                // Rasterize the structured visuals so the PDF embeds them as images.
                if format == .pdf, let rawContent = item.summaryContent {
                    await PDFVisualPrerenderer.prerender(content: rawContent)
                }

                // Generate the export file (DataManager is @MainActor so this is safe)
                let url = try dataManager.exportGuide(item, format: format)

                // Verify file exists and is readable before sharing
                guard FileManager.default.fileExists(atPath: url.path),
                      FileManager.default.isReadableFile(atPath: url.path) else {
                    isExporting = false
                    exportError = "Failed to create export file"
                    return
                }

                // Copy to a more stable location to prevent ShareKit background thread issues
                guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                    isExporting = false
                    exportError = "Unable to access documents directory for sharing."
                    return
                }
                let shareURL = documentsDir.appendingPathComponent(url.lastPathComponent)

                // Remove existing file if present
                try? FileManager.default.removeItem(at: shareURL)
                try FileManager.default.copyItem(at: url, to: shareURL)

                isExporting = false

                // Present share sheet with the stable URL
                let activityVC = UIActivityViewController(
                    activityItems: [shareURL],
                    applicationActivities: nil
                )

                // Set completion handler to clean up the copied file after sharing
                activityVC.completionWithItemsHandler = { _, _, _, _ in
                    try? FileManager.default.removeItem(at: shareURL)
                }

                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootVC = window.rootViewController {
                    var topController = rootVC
                    while let presented = topController.presentedViewController {
                        topController = presented
                    }
                    // Configure popover for iPad - required to prevent crash
                    if let popover = activityVC.popoverPresentationController {
                        popover.sourceView = topController.view
                        popover.sourceRect = CGRect(
                            x: topController.view.bounds.midX,
                            y: topController.view.bounds.midY,
                            width: 0,
                            height: 0
                        )
                        popover.permittedArrowDirections = []
                    }
                    topController.present(activityVC, animated: true)
                }
            } catch {
                isExporting = false
                exportError = error.localizedDescription
            }
        }
    }
}
