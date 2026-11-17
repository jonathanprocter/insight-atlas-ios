import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage(PremiumUI.themeStorageKey) private var themePreference = PremiumTheme.system.rawValue
    @AppStorage(PremiumUI.accentStorageKey) private var accentPreference = PremiumAccent.gold.rawValue

    @State private var selectedTab: AppTab = .library
    @State private var showOverflowMenu = false
    @State private var showInterruptedGenerationAlert = false
    @State private var interruptedInfo: (title: String, author: String, startedAt: Date)?

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    private var preferredColorScheme: ColorScheme? {
        PremiumTheme(rawValue: themePreference)?.colorScheme
    }

    private var accentColor: Color {
        PremiumAccent(rawValue: accentPreference)?.color ?? PremiumUI.gold
    }

    var body: some View {
        ZStack {
            AnalysisTheme.bgPrimary
                .ignoresSafeArea()

            if isIPad {
                NavigationSplitView {
                    List(selection: Binding(
                        get: { selectedTab },
                        set: { if let newValue = $0 { selectedTab = newValue } }
                    )) {
                        ForEach(AppTab.displayCases) { tab in
                            NavigationLink(value: tab) {
                                Label(tab.title, systemImage: tab.icon(isSelected: selectedTab == tab))
                                    .foregroundStyle(AnalysisTheme.textHeading)
                            }
                        }
                    }
                    .navigationTitle("Insight Atlas")
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                    .background(AnalysisTheme.bgPrimary)
                } detail: {
                    activeView
                }
                .tint(accentColor)
            } else {
                VStack(spacing: 0) {
                    // Custom HTML App Nav
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "safari")
                                .foregroundColor(PremiumUI.ember)
                                .font(.system(size: 21))
                            Text("Insight Atlas".uppercased())
                                .font(PremiumUI.ui(14, .bold, relativeTo: .caption))
                                .tracking(2)
                                .foregroundColor(AnalysisTheme.textHeading)
                        }
                        Spacer()
                        Button {
                            showOverflowMenu = true
                        } label: {
                            Image(systemName: "line.horizontal.3")
                                .font(.system(size: 18))
                                .foregroundColor(AnalysisTheme.textHeading)
                        }
                        .accessibilityLabel("Menu")
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                    .background(AnalysisTheme.bgPrimary.opacity(0.82))
                    .background(AnalysisTheme.bgPrimary.opacity(0.82).ignoresSafeArea(edges: .top))
                    .overlay(Rectangle().frame(height: 1).foregroundColor(PremiumUI.divider), alignment: .bottom)
                    .zIndex(30)
                
                    activeView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AnalysisTheme.bgPrimary)
                    
                    PremiumTabBar(selection: $selectedTab)
                }
                .sheet(isPresented: $showOverflowMenu) {
                    OverflowMenuView(
                        themePreference: $themePreference,
                        accentPreference: $accentPreference,
                        onSelectTab: { selectedTab = $0 }
                    )
                }
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .task {
            let coordinator = environment.generationCoordinator
            if coordinator.hasInterruptedGeneration(),
               let info = coordinator.getInterruptedGenerationInfo() {
                interruptedInfo = info
                showInterruptedGenerationAlert = true
            }
        }
        .alert("Interrupted generation", isPresented: $showInterruptedGenerationAlert) {
            Button("Resume") {
                guard interruptedInfo != nil else { return }
                Task {
                    do {
                        // Coordinator persists LibraryItem + SourceTextStore on success.
                        _ = try await environment.generationCoordinator.resumeInterruptedGeneration(
                            settings: environment.userSettings
                        )
                        await MainActor.run {
                            interruptedInfo = nil
                            selectedTab = .library
                        }
                    } catch {
                        // Failed state stays persisted for a later retry.
                    }
                }
            }
            Button("Discard", role: .destructive) {
                environment.generationCoordinator.discardInterruptedGeneration()
                interruptedInfo = nil
            }
            Button("Later", role: .cancel) {}
        } message: {
            if let info = interruptedInfo {
                Text("“\(info.title)” by \(info.author) was interrupted. Resume where it left off, or discard the partial run.")
            } else {
                Text("A previous guide generation was interrupted.")
            }
        }
    }
    @ViewBuilder
    private var activeView: some View {
        switch selectedTab {
        case .library:
            LibraryView()
        case .listen:
            ListenView()
        case .atlas:
            AtlasView()
        case .settings:
            SettingsView()
        }
    }
}

#Preview("iPhone") {
    ContentView()
        .environmentObject(AppEnvironment.shared)
        .environmentObject(DataManager.shared)
}

#Preview("iPad") {
    ContentView()
        .environmentObject(AppEnvironment.shared)
        .environmentObject(DataManager.shared)
}

extension View {
    func border(width: CGFloat, edges: [Edge], color: Color) -> some View {
        overlay(EdgeBorder(width: width, edges: edges).foregroundColor(color))
    }
}

struct EdgeBorder: Shape {
    var width: CGFloat
    var edges: [Edge]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for edge in edges {
            var x: CGFloat {
                switch edge {
                case .top, .bottom, .leading: return rect.minX
                case .trailing: return rect.maxX - width
                }
            }
            var y: CGFloat {
                switch edge {
                case .top, .leading, .trailing: return rect.minY
                case .bottom: return rect.maxY - width
                }
            }
            var w: CGFloat {
                switch edge {
                case .top, .bottom: return rect.width
                case .leading, .trailing: return width
                }
            }
            var h: CGFloat {
                switch edge {
                case .top, .bottom: return width
                case .leading, .trailing: return rect.height
                }
            }
            path.addRect(CGRect(x: x, y: y, width: w, height: h))
        }
        return path
    }
}
