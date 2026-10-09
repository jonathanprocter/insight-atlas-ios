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
