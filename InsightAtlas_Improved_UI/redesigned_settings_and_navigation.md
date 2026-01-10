# Redesigned Insight Atlas Navigation and Settings

This document outlines a redesigned architecture for the Insight Atlas iOS application, focusing on a more premium, intuitive, and iPhone-optimized user experience. The proposed changes address the current layout's limitations and introduce features that enhance usability and flow.

## 1. Proposed Navigation Architecture

To improve usability, the navigation is restructured into a more conventional and feature-rich layout that is common in modern iOS applications.

### Primary Navigation: Tab Bar

The main navigation will be a tab bar at the bottom of the screen, providing access to the most frequently used sections:

- **Library**: The central hub for viewing, searching, and managing all saved analyses.
- **New Analysis**: A prominent, centered button for quick access to creating a new guide.
- **Settings**: A dedicated section for all application settings and configurations.

### Secondary Navigation: Hamburger Menu

A hamburger menu (top-left) will house less frequently accessed items, keeping the main interface clean:

- **Collections**: Organize analyses into custom folders.
- **Export History**: View a log of all exported documents.
- **Help & Support**: Access tutorials and contact information.
- **About**: View app version and legal information.

### Contextual Actions

- **Search**: A search bar will be prominently displayed at the top of the Library view.
- **Filter/Sort**: Controls for filtering and sorting will be available within the Library view.

## 2. Redesigned Settings Screen

The settings screen will be reorganized into logical, scannable sections using a card-based layout. This improves clarity and makes it easier for users to find what they need.

### Settings Sections

1.  **Generation**: Core settings related to the AI's output.
    -   **Default AI Provider**: Claude, OpenAI, or Both.
    -   **Default Generation Mode**: Standard or Deep Research.
    -   **Default Tone**: Professional/Clinical or Accessible/Conversational.
    -   **Default Output Format**: Full Guide, Quick Reference, etc.

2.  **API Configuration**: A separate, secure section for API keys.
    -   This section will navigate to a new screen to maintain a clean main settings page.

3.  **Appearance**: Personalization options.
    -   **Theme**: Light, Dark, System.
    -   **Accent Color**: Allow users to choose from a predefined set of brand-compliant colors.

4.  **About & Support**: App information and help resources.

## 3. Enhanced Library View

To address the need to review and manage saved analyses, a dedicated Library view will be introduced. This view will be the default screen when the app is launched.

### Key Library Features

-   **View Modes**: Switch between a visual grid view and a detailed list view.
-   **Quick Filters**: One-tap filters for `All`, `Favorites`, `Recent`, and `Drafts`.
-   **Search**: A powerful search bar to find analyses by title, author, or content.
-   **Sorting**: Sort by date, title, or author.
-   **Swipe Actions**: Quickly perform common actions like `Favorite`, `Export`, and `Delete` by swiping on a library item.
-   **Batch Actions**: Allow users to select multiple items to export or delete at once.

## 4. "Premium" Features and Usability Enhancements

To elevate the user experience and make the app feel more premium, the following features are recommended:

-   **Haptic Feedback**: Provide tactile feedback on interactions like button presses and successful actions.
-   **Smooth Animations**: Use fluid transitions when navigating between screens and interacting with UI elements.
-   **Skeleton Loading States**: Show placeholder UI while content is loading to provide a sense of progress.
-   **Smart Collections**: Automatically group analyses by topic or author.
-   **Reading Progress**: Visually indicate which analyses have been read or are in progress.
-   **iCloud Sync**: Seamlessly sync the library across all of the user's Apple devices.

By implementing this redesigned architecture, the Insight Atlas app will not only be more visually appealing and aligned with the brand but also significantly more functional and enjoyable to use.
