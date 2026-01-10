import SwiftUI

// MARK: - Analysis Detail View

struct AnalysisDetailView: View {
    let analysis: BookAnalysis
    @Environment(\.dismiss) private var dismiss
    @State private var showingExportSheet = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.xl2) {
                // Header with logo, title, author
                AnalysisHeaderView(analysis: analysis)
                
                // Quick Glance section
                if let atAGlance = analysis.atAGlance {
                    QuickGlanceView(
                        coreMessage: atAGlance.coreThesis,
                        keyPoints: atAGlance.keyInsights,
                        readingTime: 12
                    )
                }
                
                // Main content sections
                ForEach(analysis.contentSections) { section in
                    renderSection(section)
                }
                
                // Footer
                AnalysisFooterView()
            }
            .padding(AnalysisTheme.Spacing.base)
        }
        .background(AnalysisTheme.bgPrimary)
        .navigationTitle(analysis.bookTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingExportSheet = true }) {
                        Label("Export as PDF", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: { toggleFavorite() }) {
                        Label(
                            analysis.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                            systemImage: analysis.isFavorite ? "star.fill" : "star"
                        )
                    }
                    
                    Button(action: { shareAnalysis() }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(AnalysisTheme.primaryGold)
                }
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportOptionsView(analysis: analysis)
        }
    }
    
    @ViewBuilder
    private func renderSection(_ section: AnalysisSection) -> some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.lg) {
            // Section heading
            if let heading = section.heading {
                Text(heading)
                    .font(.analysisDisplayH2())
                    .foregroundColor(AnalysisTheme.textHeading)
                    .padding(.top, AnalysisTheme.Spacing.md)
            }
            
            // Section content blocks
            ForEach(section.blocks) { block in
                renderBlock(block)
            }
            
            // Section divider if not last
            if section.id != analysis.contentSections.last?.id {
                SectionDivider()
            }
        }
    }
    
    @ViewBuilder
    private func renderBlock(_ block: ContentBlock) -> some View {
        switch block.type {
        case .paragraph:
            Text(block.content)
                .font(.analysisBody())
                .foregroundColor(AnalysisTheme.textBody)
                .lineSpacing(6)
            
        case .heading3:
            Text(block.content)
                .font(.analysisDisplayH3())
                .foregroundColor(AnalysisTheme.textHeading)
                .padding(.top, AnalysisTheme.Spacing.md)
            
        case .heading4:
            Text(block.content)
                .font(.analysisDisplayH4())
                .foregroundColor(AnalysisTheme.textHeading)
                .padding(.top, AnalysisTheme.Spacing.sm)
            
        case .blockquote:
            BlockquoteView(
                text: block.content,
                cite: block.metadata?["cite"]
            )
            
        case .insightNote:
            InsightNoteView(
                title: block.metadata?["title"] ?? "Insight Atlas Note",
                content: block.content
            )
            
        case .actionBox:
            if let steps = block.listItems {
                ActionBoxView(
                    title: block.metadata?["title"] ?? "Apply It",
                    steps: steps
                )
            }
            
        case .keyTakeaways:
            if let takeaways = block.listItems {
                KeyTakeawaysView(takeaways: takeaways)
            }
            
        case .foundationalNarrative:
            FoundationalNarrativeView(
                title: block.metadata?["title"] ?? "The Insight Atlas Philosophy",
                content: block.content
            )
            
        case .bulletList:
            if let items = block.listItems {
                VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.sm) {
                    ForEach(items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .font(.analysisBody())
                                .foregroundColor(AnalysisTheme.primaryGold)
                            Text(item)
                                .font(.analysisBody())
                                .foregroundColor(AnalysisTheme.textBody)
                        }
                    }
                }
            }
            
        case .numberedList:
            if let items = block.listItems {
                VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.sm) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1).")
                                .font(.analysisBody())
                                .foregroundColor(AnalysisTheme.primaryGold)
                                .frame(width: 20, alignment: .leading)
                            Text(item)
                                .font(.analysisBody())
                                .foregroundColor(AnalysisTheme.textBody)
                        }
                    }
                }
            }
        }
    }
    
    private func toggleFavorite() {
        // Implementation to toggle favorite status
    }
    
    private func shareAnalysis() {
        // Implementation to share analysis
    }
}

// MARK: - Content Models

struct AnalysisSection: Identifiable {
    let id = UUID()
    let heading: String?
    let blocks: [ContentBlock]
}

struct ContentBlock: Identifiable {
    let id = UUID()
    let type: BlockType
    let content: String
    let listItems: [String]?
    let metadata: [String: String]?
    
    init(type: BlockType, content: String, listItems: [String]? = nil, metadata: [String: String]? = nil) {
        self.type = type
        self.content = content
        self.listItems = listItems
        self.metadata = metadata
    }
}

enum BlockType {
    case paragraph
    case heading3
    case heading4
    case blockquote
    case insightNote
    case actionBox
    case keyTakeaways
    case foundationalNarrative
    case bulletList
    case numberedList
}

// MARK: - Export Options View

struct ExportOptionsView: View {
    let analysis: BookAnalysis
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Export Format") {
                    Button(action: { exportAsPDF() }) {
                        Label("PDF Document", systemImage: "doc.fill")
                    }
                    
                    Button(action: { exportAsHTML() }) {
                        Label("HTML File", systemImage: "globe")
                    }
                    
                    Button(action: { exportAsMarkdown() }) {
                        Label("Markdown", systemImage: "text.alignleft")
                    }
                }
                
                Section("Share") {
                    Button(action: { shareViaEmail() }) {
                        Label("Email", systemImage: "envelope.fill")
                    }
                    
                    Button(action: { shareViaMessages() }) {
                        Label("Messages", systemImage: "message.fill")
                    }
                    
                    Button(action: { copyLink() }) {
                        Label("Copy Link", systemImage: "link")
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
        }
    }
    
    private func exportAsPDF() {
        // Implementation for PDF export
    }
    
    private func exportAsHTML() {
        // Implementation for HTML export
    }
    
    private func exportAsMarkdown() {
        // Implementation for Markdown export
    }
    
    private func shareViaEmail() {
        // Implementation for email sharing
    }
    
    private func shareViaMessages() {
        // Implementation for Messages sharing
    }
    
    private func copyLink() {
        // Implementation for copying link
    }
}

// MARK: - Extended BookAnalysis Model

extension BookAnalysis {
    var subtitle: String? {
        // Optional subtitle for the book
        return nil
    }
    
    var contentSections: [AnalysisSection] {
        // This would be populated from the actual analysis data
        // For now, return sample data
        return [
            AnalysisSection(
                heading: "The Foundation of Understanding",
                blocks: [
                    ContentBlock(
                        type: .paragraph,
                        content: "This paragraph demonstrates the refined body typography. Notice the elegant serif font—a typeface that creates comfortable reading rhythm, while the sepia-toned text color reduces eye strain compared to pure black."
                    ),
                    ContentBlock(
                        type: .blockquote,
                        content: "True understanding is not merely the accumulation of information, but the weaving together of knowledge into wisdom. The classical scholars knew this—they read not to consume, but to become.",
                        metadata: ["cite": "The Art of Thoughtful Reading"]
                    ),
                    ContentBlock(
                        type: .insightNote,
                        content: "This component draws inspiration from Shortform's excellent editorial commentary boxes. Use it to add your own analysis, draw connections to other works, or provide context that enhances the reader's understanding."
                    )
                ]
            )
        ]
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        AnalysisDetailView(
            analysis: BookAnalysis(
                bookTitle: "The Extended Mind",
                bookAuthor: "Annie Murphy Paul",
                category: .science,
                status: .completed,
                atAGlance: AtAGlance(
                    coreThesis: "Our minds extend beyond our skulls, incorporating our bodies, surroundings, and relationships into our cognitive processes.",
                    keyInsights: [
                        "**Embodied Cognition:** Physical movement enhances thinking and memory",
                        "**Environmental Scaffolding:** Our surroundings shape how we think",
                        "**Social Cognition:** Other people's minds become extensions of our own"
                    ],
                    practicalApplications: [
                        "Use gestures while learning complex concepts",
                        "Design your workspace to support focused thinking",
                        "Engage in collaborative problem-solving"
                    ]
                )
            )
        )
    }
}
