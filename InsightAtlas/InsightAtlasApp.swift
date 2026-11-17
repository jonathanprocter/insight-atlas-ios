import SwiftUI
import BackgroundTasks

@main
struct InsightAtlasApp: App {

    // MARK: - App Environment

    @StateObject private var environment = AppEnvironment()

    // MARK: - Initialization

    init() {
        // Register background task handlers BEFORE any task is submitted
        // This must happen during app initialization
        BackgroundGenerationCoordinator.registerBackgroundTasks()

        // Configure app-wide appearance
        configureAppearance()

        // Release the voice model and parsed-markdown cache under memory
        // pressure so a large resident footprint does not get the app killed
        // while it is backgrounded.
        Task { @MainActor in MemoryPressureCoordinator.shared.start() }
    }

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(environment)
                .environmentObject(environment.dataManager)
                .task {
                    #if DEBUG
                    DebugGuideSnapshot.runIfRequested(environment: environment)
                    #endif
                }
        }
    }
    
    // MARK: - Appearance Configuration

    private func configureAppearance() {
        // Use adaptive colors from asset catalog for proper dark mode support
        let bgSecondary = PremiumUI.UI.background
        let bgCard = PremiumUI.UI.card
        let textHeading = PremiumUI.UI.ink

        // Navigation Bar
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = bgSecondary
        navAppearance.titleTextAttributes = [
            .foregroundColor: textHeading
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: textHeading
        ]

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = PremiumUI.UI.indigo

        // Tab Bar
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = bgCard

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
}

#if DEBUG
/// `-ia-render-guide` launch argument: render the first library guide through
/// the real reader renderer into Documents/debug-guide.png. Lets the reader be
/// reviewed headlessly in a simulator that has no Simulator.app window.
@MainActor
enum DebugGuideSnapshot {
    static func runIfRequested(environment: AppEnvironment) {
        guard ProcessInfo.processInfo.arguments.contains("-ia-render-guide"),
              let item = environment.dataManager.libraryItems.first,
              let content = item.summaryContent ?? GuideBodyStore.load(item.id) else { return }

        let view = EditorialContentRenderer(
            content: content,
            searchQuery: "",
            title: item.title,
            author: item.author
        )
        .padding(.horizontal, 20)
        .frame(width: 430, alignment: .leading)
        .background(AnalysisTheme.paper)
        .environment(\.colorScheme, .light)
        .environmentObject(environment)
        .environmentObject(environment.dataManager)

        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(width: 430, height: 16_000)
        renderer.scale = 2
        guard let image = renderer.uiImage,
              let data = image.pngData(),
              let documents = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask
              ).first else {
            print("[DebugGuideSnapshot] render failed")
            return
        }
        let url = documents.appendingPathComponent("debug-guide.png")
        try? data.write(to: url)
        print("[DebugGuideSnapshot] wrote \(Int(image.size.width))x\(Int(image.size.height)) to \(url.path)")
    }
}
#endif
