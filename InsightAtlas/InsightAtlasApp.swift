import SwiftUI
import SwiftData

@main
struct InsightAtlasApp: App {
    
    // MARK: - SwiftData Container
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            LibraryItem.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    // MARK: - App Environment
    
    @StateObject private var environment: AppEnvironment
    
    // MARK: - Migration State
    
    @State private var isMigrating = false
    @State private var migrationError: Error?
    
    // MARK: - Initialization
    
    init() {
        // Create the model container first
        let container = sharedModelContainer
        let context = ModelContext(container)
        
        // Initialize the environment with the model context
        let env = AppEnvironment(modelContext: context)
        _environment = StateObject(wrappedValue: env)
    }
    
    // MARK: - Scene
    
    var body: some Scene {
        WindowGroup {
            Group {
                if isMigrating {
                    MigrationView()
                } else if let error = migrationError {
                    MigrationErrorView(error: error)
                } else {
                    ContentView()
                        .environmentObject(environment)
                }
            }
            .task {
                await performMigrationIfNeeded()
            }
        }
        .modelContainer(sharedModelContainer)
    }
    
    // MARK: - Migration
    
    private func performMigrationIfNeeded() async {
        guard !MigrationService.isMigrationCompleted else { return }
        
        isMigrating = true
        
        do {
            try await MigrationService.migrate(to: environment.modelContext)
            isMigrating = false
        } catch {
            migrationError = error
            isMigrating = false
        }
    }
}

// MARK: - Migration Views

struct MigrationView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Migrating Your Library")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("This will only take a moment...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct MigrationErrorView: View {
    let error: Error
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Migration Error")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if let recoverySuggestion = (error as? LocalizedError)?.recoverySuggestion {
                Text(recoverySuggestion)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button("Contact Support") {
                // Open support email or URL
                if let url = URL(string: "mailto:support@insightatlas.com") {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
