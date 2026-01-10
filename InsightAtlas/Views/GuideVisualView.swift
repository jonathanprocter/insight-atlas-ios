//
//  GuideVisualView.swift
//  InsightAtlas
//
//  View for displaying AI-generated visuals in guide sections.
//

import SwiftUI

struct GuideVisualView: View {
    let visual: GuideVisual

    @State private var cachedImage: UIImage?
    @State private var isLoading = true
    @State private var loadFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: VisualTheme.captionSpacing) {
            // Image display
            Group {
                if let image = cachedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(VisualTheme.cornerRadius)
                        .shadow(
                            color: .black.opacity(VisualTheme.shadowOpacity),
                            radius: 4,
                            y: 2
                        )
                } else if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if loadFailed {
                    VStack(spacing: 12) {
                        Image(systemName: iconForVisualType(visual.type))
                            .font(.system(size: 40))
                            .foregroundColor(AnalysisTheme.primaryGoldMuted)
                        Text("Unable to load visual")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 150)
                    .background(VisualTheme.background.opacity(0.5))
                    .cornerRadius(VisualTheme.cornerRadius)
                }
            }

            // Caption
            if let caption = visual.caption {
                Text(caption)
                    .font(VisualTheme.captionFont)
                    .foregroundStyle(.secondary)
                    .italic()
            }

            // Type label
            HStack {
                Image(systemName: iconForVisualType(visual.type))
                    .font(.caption2)
                Text(labelForVisualType(visual.type))
                    .font(.caption2)
            }
            .foregroundColor(AnalysisTheme.primaryGoldMuted)

            // Debug: AI rationale (only in DEBUG builds)
            #if DEBUG
            if let rationale = visual.rationale {
                Text("AI rationale: \(rationale)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            #endif
        }
        .padding(.vertical, 12)
        .task {
            await loadAndCacheImage()
        }
    }

    private func loadAndCacheImage() async {
        isLoading = true
        loadFailed = false

        // Check if already cached locally
        if let cached = VisualAssetCache.shared.cachedImage(for: visual.imageURL) {
            cachedImage = cached
            isLoading = false
            return
        }

        // Download and cache
        do {
            let localURL = try await VisualAssetCache.shared.cacheIfNeeded(from: visual.imageURL)
            if let image = UIImage(contentsOfFile: localURL.path) {
                cachedImage = image
            } else {
                loadFailed = true
            }
        } catch {
            loadFailed = true
        }

        isLoading = false
    }

    private func iconForVisualType(_ type: GuideVisualType) -> String {
        switch type {
        case .timeline:
            return "calendar.day.timeline.left"
        case .flowDiagram:
            return "arrow.triangle.branch"
        case .comparisonMatrix:
            return "square.grid.2x2"
        case .barChart:
            return "chart.bar"
        case .quadrant:
            return "square.split.2x2"
        case .conceptMap:
            return "point.3.connected.trianglepath.dotted"
        }
    }

    private func labelForVisualType(_ type: GuideVisualType) -> String {
        switch type {
        case .timeline:
            return "Timeline"
        case .flowDiagram:
            return "Flow Diagram"
        case .comparisonMatrix:
            return "Comparison Matrix"
        case .barChart:
            return "Bar Chart"
        case .quadrant:
            return "Quadrant Analysis"
        case .conceptMap:
            return "Concept Map"
        }
    }
}

#Preview {
    let previewURL = URL(string: "https://example.com/diagram.png") ?? URL(fileURLWithPath: "/")
    GuideVisualView(visual: GuideVisual(
        type: .flowDiagram,
        imageURL: previewURL,
        caption: "A flow diagram showing the process",
        rationale: "This section describes a causal sequence, so a flow diagram improves comprehension."
    ))
    .padding()
}
