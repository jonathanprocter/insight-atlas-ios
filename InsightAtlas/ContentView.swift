import SwiftUI

struct ContentView: View {
    @EnvironmentObject var environment: AppEnvironment
    
    // MARK: - Environment
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        ZStack {
            // Modern clean background
            AnalysisTheme.bgSecondary
                .ignoresSafeArea()
            
            if isIPad {
                // iPad: Side-by-side navigation
                NavigationSplitView {
                    List {
                        NavigationLink(destination: LibraryView()) {
                            Label("Library", systemImage: "books.vertical.fill")
                                .foregroundStyle(AnalysisTheme.textHeading)
                        }
                        
                        NavigationLink(destination: SettingsView()) {
                            Label("Settings", systemImage: "gearshape.fill")
                                .foregroundStyle(AnalysisTheme.textHeading)
                        }
                    }
                    .navigationTitle("Insight Atlas")
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                    .background(AnalysisTheme.bgSecondary)
                } detail: {
                    LibraryView()
                }
                .tint(AnalysisTheme.brandOrange)
            } else {
                // iPhone: Tab bar navigation
                TabView {
                    LibraryView()
                        .tabItem {
                            Label("Library", systemImage: "books.vertical.fill")
                        }
                    
                    SettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "gearshape.fill")
                        }
                }
                .tint(AnalysisTheme.brandOrange)
            }
        }
    }
}

#Preview("iPhone") {
    ContentView()
        .environmentObject(AppEnvironment.shared)
}

#Preview("iPad") {
    ContentView()
        .environmentObject(AppEnvironment.shared)
}

