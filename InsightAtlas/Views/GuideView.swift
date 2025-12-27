import SwiftUI

struct GuideView: View {
    
    // MARK: - Properties
    
    let item: LibraryItem
    
    // MARK: - Environment
    
    @EnvironmentObject var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    @State private var searchText = ""
    @State private var isPlayingAudio = false
    @State private var audioPlaybackProgress: Double = 0
    @State private var isGeneratingAudio = false
    @State private var tableOfContents: [TOCEntry] = []
    
    // MARK: - Computed Properties
    
    private var hasPlayableAudio: Bool {
        item.audioFileURL != nil
    }
    
    private var canGenerateAudio: Bool {
        item.summaryContent != nil && !item.audioGenerationAttempted
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        GuideHeaderView(item: item)
                        
                        // Table of Contents
                        if !tableOfContents.isEmpty {
                            tableOfContentsSection(proxy: proxy)
                        }
                        
                        // Content
                        if let content = item.summaryContent {
                            InsightAtlasContentView(content: content, searchQuery: searchText)
                        } else {
                            emptyContentView
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, hasPlayableAudio || canGenerateAudio ? 120 : 20)
                    .frame(maxWidth: 800, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .background(Color(.systemGroupedBackground))
            
            // Sticky Audio Player
            if hasPlayableAudio || canGenerateAudio {
                StickyAudioPlayer(
                    item: item,
                    isPlaying: $isPlayingAudio,
                    progress: $audioPlaybackProgress,
                    isGenerating: $isGeneratingAudio,
                    onPlayPause: toggleAudioPlayback,
                    onGenerate: generateAudioOnly
                )
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)
            }
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search in guide")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        // Export guide
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    
                    Button {
                        // Share guide
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        deleteGuide()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            generateTableOfContents()
        }
    }
    
    // MARK: - Table of Contents
    
    private func tableOfContentsSection(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Table of Contents")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(tableOfContents) { entry in
                Button {
                    withAnimation {
                        proxy.scrollTo(entry.id, anchor: .top)
                    }
                } label: {
                    HStack {
                        Text(entry.title)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(8)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    
    private func generateTableOfContents() {
        guard let content = item.summaryContent else { return }
        
        // Parse markdown headers
        let lines = content.components(separatedBy: .newlines)
        var toc: [TOCEntry] = []
        
        for (index, line) in lines.enumerated() {
            if line.hasPrefix("# ") || line.hasPrefix("## ") {
                let title = line.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
                toc.append(TOCEntry(id: "heading-\(index)", title: title))
            }
        }
        
        tableOfContents = toc
    }
    
    // MARK: - Empty State
    
    private var emptyContentView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Content Available")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Generate content for this guide to view it here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Actions
    
    private func toggleAudioPlayback() {
        isPlayingAudio.toggle()
        // Implement actual audio playback logic
    }
    
    private func generateAudioOnly() {
        isGeneratingAudio = true
        // Implement audio generation logic
        Task {
            // Simulate generation
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            isGeneratingAudio = false
        }
    }
    
    private func deleteGuide() {
        environment.deleteLibraryItem(item)
        dismiss()
    }
}

// MARK: - Guide Header View

struct GuideHeaderView: View {
    let item: LibraryItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Cover Image
            if let imageData = item.loadCoverImageData(),
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 220)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            }
            
            // Title and Author
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Based on the work of \(item.author)")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            // Metadata
            HStack(spacing: 24) {
                if let readTime = item.readTime {
                    InfoPill(label: readTime, icon: "clock")
                }
                if let pageCount = item.pageCount {
                    InfoPill(label: "\(pageCount) pages", icon: "doc")
                }
                InfoPill(label: item.mode, icon: "sparkles")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            Divider()
        }
    }
}

struct InfoPill: View {
    let label: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(label)
        }
    }
}

// MARK: - Sticky Audio Player

struct StickyAudioPlayer: View {
    let item: LibraryItem
    @Binding var isPlaying: Bool
    @Binding var progress: Double
    @Binding var isGenerating: Bool
    
    let onPlayPause: () -> Void
    let onGenerate: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            if isPlaying {
                ProgressView(value: progress)
                    .tint(.accentColor)
            }
            
            HStack {
                // Album art/icon
                Image(systemName: "headphones")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .frame(width: 44, height: 44)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(6)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(item.author)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isGenerating {
                    ProgressView()
                } else if item.audioFileURL != nil {
                    Button(action: onPlayPause) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                    }
                } else {
                    Button(action: onGenerate) {
                        Image(systemName: "speaker.wave.2.circle")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5)
    }
}

// MARK: - TOC Entry

struct TOCEntry: Identifiable {
    let id: String
    let title: String
}

// MARK: - Content View Placeholder

struct InsightAtlasContentView: View {
    let content: String
    let searchQuery: String
    
    var body: some View {
        // This is a placeholder - implement your actual content rendering
        Text(content)
            .font(.body)
            .padding()
    }
}
