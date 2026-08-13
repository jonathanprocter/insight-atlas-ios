//
//  OnDeviceInsightPreviewView.swift
//  InsightAtlas
//
//  SPIKE / PROTOTYPE UI — drives `OnDeviceInsightService` so we can *feel* the
//  ceiling of the on-device model: quality of the TL;DR/themes/tags, and the
//  generation latency, right on device. Also demos the offline narration
//  fallback (`AVSpeechSynthesizer`).
//
//  This is a self-contained diagnostic card. It is not yet wired into the main
//  navigation — present it from anywhere with a title/author/body, e.g. a
//  LibraryItem's `summaryContent`.
//

import SwiftUI

struct OnDeviceInsightPreviewView: View {
    let title: String
    let author: String
    let bodyText: String

    private let service = OnDeviceInsightService()
    @StateObject private var narrator = OfflineNarrator()

    @State private var status: OnDeviceInsightStatus = .unknownUnavailable
    @State private var preview: OnDeviceInsightPreview?
    @State private var isGenerating = false
    @State private var elapsedMilliseconds: Int?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                availabilityRow
                generateButton

                if let preview {
                    resultCard(preview)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                }

                ceilingNote
            }
            .padding()
        }
        .navigationTitle("Offline Preview")
        .task { status = service.status() }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title2.bold())
            Text(author).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var availabilityRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(status == .available ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(status.userMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var generateButton: some View {
        Button {
            Task { await generate() }
        } label: {
            HStack {
                if isGenerating { ProgressView().controlSize(.small) }
                Text(isGenerating ? "Generating on device…" : "Generate offline preview")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isGenerating || status != .available || bodyText.isEmpty)
    }

    private func resultCard(_ p: OnDeviceInsightPreview) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let elapsedMilliseconds {
                Text("Generated on device in \(elapsedMilliseconds) ms · \(min(bodyText.count, OnDeviceInsightService.maxInputCharacters)) chars in")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Text(p.headline)
                .font(.title3.weight(.semibold))

            Text(p.tldr)
                .font(.body)
                .foregroundStyle(.primary)

            if !p.themes.isEmpty {
                labeledChips("Themes", p.themes)
            }
            if !p.tags.isEmpty {
                labeledChips("Tags", p.tags.map { "#\($0)" })
            }

            Label("~\(p.estimatedReadingMinutes) min read", systemImage: "clock")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Divider()

            Button {
                if narrator.isSpeaking {
                    narrator.stop()
                } else {
                    narrator.speak("\(p.headline). \(p.tldr)")
                }
            } label: {
                Label(
                    narrator.isSpeaking ? "Stop" : "Read aloud (offline voice)",
                    systemImage: narrator.isSpeaking ? "stop.fill" : "speaker.wave.2.fill"
                )
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func labeledChips(_ label: String, _ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            FlowChips(items: items)
        }
    }

    private var ceilingNote: some View {
        Text("""
        Spike: this runs entirely on device via Apple's Foundation Models \
        (4,096-token window). It's built for short, bounded output — TL;DRs, \
        themes, tags — not the full 15,000-word guide. The read-aloud button \
        uses the on-device AVSpeechSynthesizer voice, a labeled fallback for \
        the Kokoro/Liam pipeline.
        """)
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .padding(.top, 8)
    }

    // MARK: Actions

    private func generate() async {
        errorMessage = nil
        preview = nil
        isGenerating = true
        let start = Date()
        defer { isGenerating = false }

        do {
            let result = try await service.generatePreview(title: title, author: author, body: bodyText)
            elapsedMilliseconds = Int(Date().timeIntervalSince(start) * 1000)
            preview = result
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - Simple wrapping chip layout

private struct FlowChips: View {
    let items: [String]

    var body: some View {
        // Lightweight wrap using the native flexible layout.
        FlexibleWrap(items: items) { item in
            Text(item)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.quaternary, in: Capsule())
        }
    }
}

/// Minimal wrapping container so chips flow onto multiple lines.
private struct FlexibleWrap<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    @State private var totalHeight: CGFloat = .zero

    var body: some View {
        GeometryReader { geo in
            self.generateContent(in: geo)
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in geo: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            ForEach(items, id: \.self) { item in
                content(item)
                    .alignmentGuide(.leading) { dimension in
                        if abs(width - dimension.width) > geo.size.width {
                            width = 0
                            height -= dimension.height + 6
                        }
                        let result = width
                        if item == items.last {
                            width = 0
                        } else {
                            width -= dimension.width + 6
                        }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if item == items.last {
                            height = 0
                        }
                        return result
                    }
            }
        }
        .background(heightReader)
    }

    private var heightReader: some View {
        GeometryReader { geo -> Color in
            Task { @MainActor in self.totalHeight = geo.size.height }
            return Color.clear
        }
    }
}
