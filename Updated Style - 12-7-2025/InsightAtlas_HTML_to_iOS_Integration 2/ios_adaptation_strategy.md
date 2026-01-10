# iOS Adaptation Strategy: HTML to SwiftUI

This document outlines the strategy for translating the premium HTML book summary template into a native SwiftUI view for displaying generated analyses within the Insight Atlas iOS app.

## 1. Core Philosophy

The goal is to achieve **native fidelity**, not a web view. We will recreate the HTML template's aesthetic and structure using pure SwiftUI to ensure optimal performance, accessibility, and platform integration. We will map the existing design system (colors, fonts, spacing) to a new `Theme.swift` file in the Xcode project.

## 2. Design System Mapping

We will translate the CSS custom properties into a SwiftUI-friendly format.

### Colors

The extensive color palette in the CSS will be mapped to a `struct` of static `Color` properties.

**CSS:**
```css
:root {
    --primary-gold: #C9A227;
    --accent-burgundy: #6B3A4A;
    --text-heading: #2D2520;
    --bg-secondary: #F5F3ED;
}
```

**SwiftUI (`Theme.swift`):**
```swift
import SwiftUI

struct InsightAtlasTheme {
    static let primaryGold = Color(hex: "#C9A227")
    static let accentBurgundy = Color(hex: "#6B3A4A")
    static let textHeading = Color(hex: "#2D2520")
    static let backgroundSecondary = Color(hex: "#F5F3ED")
    // ... and so on for all colors
}
```

### Typography

Fonts will be mapped to custom `Font` styles. The serif font (Cormorant Garamond) and sans-serif font (Inter) will be added to the project and referenced programmatically.

**CSS:**
```css
h1 {
    font-family: var(--font-display);
    font-size: clamp(var(--text-4xl), 6vw, var(--text-5xl));
    font-weight: var(--font-bold);
}
.handwritten {
    font-family: var(--font-handwritten);
}
```

**SwiftUI (`Theme.swift`):**
```swift
extension Font {
    static func displayTitle() -> Font {
        .custom("CormorantGaramond-Bold", size: 34)
    }
    static func bodyText() -> Font {
        .custom("Inter-Regular", size: 17)
    }
    static func handwritten() -> Font {
        .custom("Caveat-Regular", size: 22)
    }
}
```

### Spacing

CSS spacing variables will be mapped to static `CGFloat` properties for consistent padding and margins.

**CSS:**
```css
:root {
    --space-4: 1rem; /* 16px */
    --space-8: 2rem; /* 32px */
}
```

**SwiftUI (`Theme.swift`):**
```swift
struct InsightAtlasSpacing {
    static let base: CGFloat = 4
    static let medium: CGFloat = 16
    static let large: CGFloat = 32
}
```

## 3. Component Mapping

Each distinct section in the HTML will become a reusable SwiftUI `View`. The main analysis view will be a `ScrollView` containing these components.

| HTML Component (`class`)      | SwiftUI View (`struct`)       | Key Features                                                              |
| ----------------------------- | ----------------------------- | ------------------------------------------------------------------------- |
| `.document-header`            | `AnalysisHeaderView`          | Contains the logo, book title, author, and tagline.                       |
| `.quick-glance`               | `QuickGlanceView`             | A card with a gold border showing core message and key points.            |
| `<blockquote>`                | `BlockquoteView`              | An indented view with a vertical accent line for quoting text.            |
| `.insight-note`               | `InsightNoteView`             | A special callout box for editorial observations, with a distinct background. |
| `.action-box`                 | `ActionBoxView`               | A component for actionable steps or exercises, often with an ordered list.    |
| `.visual-flowchart`           | `VisualFlowchartView`         | A vertical series of steps connected by arrows.                           |
| `.styled-table`               | `StyledTableView`             | A custom-styled table for presenting structured data.                     |
| `.takeaways`                  | `KeyTakeawaysView`            | A list of key points, often using checkmark icons.                        |
| `.foundational-narrative`     | `FoundationalNarrativeView`   | A distinctively styled block for philosophical or core-concept text.      |
| `.document-footer`            | `AnalysisFooterView`          | The footer with brand name and tagline.                                   |

## 4. Layout and Structure

The main view, `AnalysisDetailView`, will be responsible for rendering the full book summary. It will be constructed as follows:

```swift
struct AnalysisDetailView: View {
    let analysis: BookAnalysis // The data model for the summary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: InsightAtlasSpacing.large) {
                AnalysisHeaderView(analysis: analysis)

                QuickGlanceView(summary: analysis.quickGlance)

                // The body content will be parsed and rendered.
                // We can use a simple parser to identify sections
                // and map them to the correct SwiftUI components.

                // Example of rendering different components:
                ForEach(analysis.contentBlocks) { block in
                    switch block.type {
                    case .paragraph:
                        Text(block.content)
                            .font(.bodyText())
                    case .blockquote:
                        BlockquoteView(text: block.content)
                    case .insightNote:
                        InsightNoteView(text: block.content)
                    // ... etc.
                    }
                }

                AnalysisFooterView()
            }
            .padding()
        }
        .navigationTitle(analysis.bookTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

## 5. Data Model Adaptation

The generated analysis data will need to be structured in a way that can be easily rendered by the `AnalysisDetailView`. We will define a `ContentBlock` struct that can represent the different types of content from the HTML template.

```swift
struct AnalysisContentBlock: Identifiable {
    let id = UUID()
    let type: BlockType
    let content: String
    let listItems: [String]? // For lists in action boxes, etc.
}

enum BlockType {
    case paragraph, heading2, heading3, blockquote, insightNote, actionBox, keyTakeaways
}
```

This strategy will allow us to faithfully reproduce the beautiful and functional design of the HTML template within the native iOS environment, providing a seamless and premium user experience.
