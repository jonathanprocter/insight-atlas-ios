import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage(PremiumUI.themeStorageKey) private var themePreference = PremiumTheme.system.rawValue
    @AppStorage(PremiumUI.accentStorageKey) private var accentPreference = PremiumAccent.gold.rawValue

    @State private var selectedTab: AppTab = .library

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
                                .foregroundColor(Color(hex: "#E8553A"))
                                .font(.system(size: 21))
                            Text("Insight Atlas".uppercased())
                                .font(PremiumUI.ui(14, .bold, relativeTo: .caption))
                                .tracking(2)
                                .foregroundColor(AnalysisTheme.textHeading)
                        }
                        Spacer()
                        Image(systemName: "line.horizontal.3")
                            .font(.system(size: 18))
                            .foregroundColor(AnalysisTheme.textHeading)
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
            }
        }
        // Locked to light mode per user preference (overrides the Theme setting).
        .preferredColorScheme(preferredColorScheme)
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
