import SwiftUI

// MARK: - Analysis Header View

struct AnalysisHeaderView: View {
    let analysis: BookAnalysis
    
    var body: some View {
        VStack(spacing: AnalysisTheme.Spacing.lg) {
            // Logo
            Image("Logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 100)
                .opacity(0.9)
            
            // Brand badge
            Text("Insight Atlas")
                .font(.analysisUI())
                .foregroundColor(AnalysisTheme.brandSepia)
                .tracking(2)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AnalysisTheme.primaryGoldSubtle)
                .cornerRadius(AnalysisTheme.Radius.sm)
            
            // Book title
            Text(analysis.bookTitle)
                .font(.analysisDisplayTitle())
                .foregroundColor(AnalysisTheme.textHeading)
                .multilineTextAlignment(.center)
            
            // Subtitle/Description
            if let subtitle = analysis.subtitle {
                Text(subtitle)
                    .font(.analysisDisplayH4())
                    .foregroundColor(AnalysisTheme.textMuted)
                    .multilineTextAlignment(.center)
            }
            
            // Author
            Text("Based on the work of **\(analysis.bookAuthor)**")
                .font(.analysisBody())
                .foregroundColor(AnalysisTheme.textBody)
                .multilineTextAlignment(.center)
            
            // Tagline
            Text("Where Understanding Illuminates the World")
                .font(.analysisHandwritten())
                .foregroundColor(AnalysisTheme.textHandwritten)
                .multilineTextAlignment(.center)
                .padding(.top, AnalysisTheme.Spacing.sm)
        }
        .padding(.vertical, AnalysisTheme.Spacing.xl2)
    }
}

// MARK: - Quick Glance View

struct QuickGlanceView: View {
    let coreMessage: String
    let keyPoints: [String]
    let readingTime: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            HStack {
                Text("Quick Glance")
                    .analysisBlockHeader(accentColor: AnalysisTheme.primaryGold)
                
                Spacer()
                
                // Reading time badge
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10))
                    Text("\(readingTime) min read")
                        .font(.analysisUISmall())
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AnalysisTheme.primaryGold)
                .cornerRadius(AnalysisTheme.Radius.full)
            }
            
            Text("**Core Message:** \(coreMessage)")
                .font(.analysisBody())
                .foregroundColor(AnalysisTheme.textBody)
            
            VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.sm) {
                ForEach(keyPoints, id: \.self) { point in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.analysisBody())
                            .foregroundColor(AnalysisTheme.primaryGold)
                        Text(point)
                            .font(.analysisBody())
                            .foregroundColor(AnalysisTheme.textBody)
                    }
                }
            }
        }
        .padding(AnalysisTheme.Spacing.base)
        .background(AnalysisTheme.primaryGoldSubtle)
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.xl)
                .stroke(AnalysisTheme.primaryGold, lineWidth: 2)
        )
        .cornerRadius(AnalysisTheme.Radius.xl)
    }
}

// MARK: - Blockquote View

struct BlockquoteView: View {
    let text: String
    let cite: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.sm) {
            Text(text)
                .font(.analysisBodyLarge())
                .italic()
                .foregroundColor(AnalysisTheme.textMuted)
            
            if let cite = cite {
                Text("— \(cite)")
                    .font(.analysisBodySmall())
                    .foregroundColor(AnalysisTheme.textSubtle)
            }
        }
        .padding(.leading, AnalysisTheme.Spacing.xl)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(AnalysisTheme.primaryGold)
                .frame(width: 4)
        }
        .padding(.vertical, AnalysisTheme.Spacing.md)
    }
}

// MARK: - Insight Note View

struct InsightNoteView: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14))
                    .foregroundColor(AnalysisTheme.accentOrange)
                
                Text(title)
                    .font(.analysisUIBold())
                    .foregroundColor(AnalysisTheme.textHeading)
            }
            
            Text(content)
                .font(.analysisBody())
                .foregroundColor(AnalysisTheme.textBody)
        }
        .padding(AnalysisTheme.Spacing.base)
        .background(AnalysisTheme.accentOrangeSubtle)
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.lg)
                .stroke(AnalysisTheme.accentOrange.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(AnalysisTheme.Radius.lg)
    }
}

// MARK: - Action Box View

struct ActionBoxView: View {
    let title: String
    let steps: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(AnalysisTheme.accentTeal)
                
                Text(title)
                    .font(.analysisUIBold())
                    .foregroundColor(AnalysisTheme.textHeading)
            }
            
            VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.sm) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1).")
                            .font(.analysisUIBold())
                            .foregroundColor(AnalysisTheme.accentTeal)
                            .frame(width: 20, alignment: .leading)
                        
                        Text(step)
                            .font(.analysisBody())
                            .foregroundColor(AnalysisTheme.textBody)
                    }
                }
            }
        }
        .padding(AnalysisTheme.Spacing.base)
        .background(AnalysisTheme.accentTealSubtle)
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.lg)
                .stroke(AnalysisTheme.accentTeal.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(AnalysisTheme.Radius.lg)
    }
}

// MARK: - Key Takeaways View

struct KeyTakeawaysView: View {
    let takeaways: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundColor(AnalysisTheme.primaryGold)
                
                Text("Key Takeaways")
                    .font(.analysisUIBold())
                    .foregroundColor(AnalysisTheme.textHeading)
            }
            
            VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.sm) {
                ForEach(takeaways, id: \.self) { takeaway in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AnalysisTheme.primaryGold)
                        
                        Text(takeaway)
                            .font(.analysisBody())
                            .foregroundColor(AnalysisTheme.textBody)
                    }
                }
            }
        }
        .padding(AnalysisTheme.Spacing.base)
        .background(AnalysisTheme.primaryGoldSubtle)
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.lg)
                .stroke(AnalysisTheme.primaryGold.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(AnalysisTheme.Radius.lg)
    }
}

// MARK: - Foundational Narrative View

struct FoundationalNarrativeView: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            HStack(spacing: 8) {
                Text("📖")
                    .font(.system(size: 14))
                
                Text(title)
                    .font(.analysisUIBold())
                    .foregroundColor(AnalysisTheme.brandSepia)
            }
            .padding(.bottom, AnalysisTheme.Spacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(AnalysisTheme.borderMedium)
                    .frame(height: 1)
            }
            
            Text(content)
                .font(.analysisBody())
                .foregroundColor(AnalysisTheme.textBody)
        }
        .padding(AnalysisTheme.Spacing.base)
        .background(AnalysisTheme.bgSecondary)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(AnalysisTheme.primaryGold)
                .frame(width: 4)
        }
        .cornerRadius(AnalysisTheme.Radius.lg)
    }
}

// MARK: - Analysis Footer View

struct AnalysisFooterView: View {
    var body: some View {
        VStack(spacing: AnalysisTheme.Spacing.sm) {
            Text("INSIGHT ATLAS")
                .font(.analysisUIBold())
                .foregroundColor(AnalysisTheme.brandSepia)
                .tracking(2)
            
            Text("Where Understanding Illuminates the World")
                .font(.analysisHandwritten())
                .foregroundColor(AnalysisTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AnalysisTheme.Spacing.xl3)
        .padding(.bottom, AnalysisTheme.Spacing.xl)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AnalysisTheme.borderLight)
                .frame(height: 1)
        }
    }
}

// MARK: - Section Divider

struct SectionDivider: View {
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(AnalysisTheme.borderLight)
                .frame(height: 1)
            
            Text("✦")
                .font(.system(size: 12))
                .foregroundColor(AnalysisTheme.primaryGold)
            
            Rectangle()
                .fill(AnalysisTheme.borderLight)
                .frame(height: 1)
        }
        .padding(.vertical, AnalysisTheme.Spacing.xl)
    }
}

// MARK: - Preview Helpers

#Preview("Quick Glance") {
    ScrollView {
        QuickGlanceView(
            coreMessage: "This demonstrates the premium design system adapted from the HTML template.",
            keyPoints: [
                "**Design Philosophy:** Renaissance-inspired aesthetics meet modern iOS",
                "**Accessibility:** Native SwiftUI with full accessibility support",
                "**Performance:** Optimized for smooth scrolling and animations"
            ],
            readingTime: 12
        )
        .padding()
    }
}

#Preview("Insight Note") {
    ScrollView {
        InsightNoteView(
            title: "Insight Atlas Note",
            content: "This component draws inspiration from Shortform's excellent editorial commentary boxes. Use it to add your own analysis, draw connections to other works, or provide context that enhances the reader's understanding."
        )
        .padding()
    }
}

#Preview("Action Box") {
    ScrollView {
        ActionBoxView(
            title: "Apply It",
            steps: [
                "**Engage actively:** Read with pen in hand, annotating key insights as they arise",
                "**Question deeply:** Ask not just \"what\" but \"why\" and \"how might this apply\"",
                "**Connect broadly:** Link new information to existing knowledge structures"
            ]
        )
        .padding()
    }
}
