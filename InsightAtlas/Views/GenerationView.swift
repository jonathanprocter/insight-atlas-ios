import SwiftUI

struct GenerationView: View {
    
    // MARK: - Environment
    
    @EnvironmentObject var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    @State private var generationState: GenerationState = .idle
    @State private var generatedItem: LibraryItem?
    @State private var progress: Double = 0
    @State private var statusMessage = ""
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Group {
                switch generationState {
                case .idle:
                    setupView
                case .generating:
                    generatingView
                case .completed:
                    completedView
                case .error(let message):
                    errorView(message: message)
                }
            }
            .navigationTitle("Generate Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Setup View
    
    private var setupView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Upload a book or document to generate your guide")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Button {
                    // Implement file picker
                } label: {
                    Label("Choose File", systemImage: "doc.badge.plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding()
        }
    }
    
    // MARK: - Generating View
    
    private var generatingView: some View {
        VStack(spacing: 24) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .padding(.horizontal)
            
            Text(statusMessage)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text("This may take a few minutes...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    // MARK: - Completed View
    
    private var completedView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Success Icon
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                }
                .padding(.top, 40)
                
                // Title
                Text("Guide Generated!")
                    .font(.title)
                    .fontWeight(.bold)
                
                // Preview Card
                if let item = generatedItem {
                    GuidePreviewCard(item: item)
                        .padding(.horizontal)
                }
                
                // Actions
                VStack(spacing: 12) {
                    NavigationLink(destination: GuideView(item: generatedItem!)) {
                        Label("View Guide", systemImage: "book.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    
                    Button {
                        dismiss()
                    } label: {
                        Label("Save to Library", systemImage: "square.and.arrow.down")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Generation Failed")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                generationState = .idle
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Generation State

enum GenerationState {
    case idle
    case generating
    case completed
    case error(String)
}

// MARK: - Guide Preview Card

struct GuidePreviewCard: View {
    let item: LibraryItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Cover Image
            if let imageData = item.loadCoverImageData(),
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 180)
                    .clipped()
                    .cornerRadius(12)
            }
            
            // Title and Author
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)
                
                Text(item.author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Metadata
            HStack(spacing: 16) {
                if let readTime = item.readTime {
                    Label(readTime, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let wordCount = item.governedWordCount {
                    Label("\(wordCount) words", systemImage: "doc.text")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}
