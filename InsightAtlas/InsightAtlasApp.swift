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
        let bgSecondary = UIColor { t in t.userInterfaceStyle == .dark ? UIColor(hex: "#111111") : UIColor(hex: "#FAF9F6") }
        let bgCard = UIColor { t in t.userInterfaceStyle == .dark ? UIColor(hex: "#242424") : UIColor(hex: "#FFFFFF") }
        let textHeading = UIColor { t in t.userInterfaceStyle == .dark ? UIColor(hex: "#FAF9F6") : UIColor(hex: "#111111") }

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
        UINavigationBar.appearance().tintColor = UIColor(hex: "#2C3E50")

        // Tab Bar
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = bgCard

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
}
