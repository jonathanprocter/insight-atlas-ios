import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage(PremiumUI.themeStorageKey) private var themePreference = PremiumTheme.system.rawValue
    @AppStorage(PremiumUI.accentStorageKey) private var accentPreference = PremiumAccent.gold.rawValue

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
            PremiumUI.background
                .ignoresSafeArea()

            if isIPad {
                NavigationSplitView {
                    List {
                        NavigationLink(destination: LibraryView()) {
                            Label("Library", systemImage: "books.vertical.fill")
                                .foregroundStyle(PremiumUI.ink)
                        }

                        NavigationLink(destination: SettingsView()) {
                            Label("Settings", systemImage: "gearshape.fill")
                                .foregroundStyle(PremiumUI.ink)
                        }
                    }
                    .navigationTitle("Insight Atlas")
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                    .background(PremiumUI.background)
                } detail: {
                    LibraryView()
                }
                .tint(accentColor)
            } else {
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
                .tint(accentColor)
                .toolbarBackground(.ultraThinMaterial, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
            }
        }
        .preferredColorScheme(preferredColorScheme)
    }
}

enum PremiumUI {
    static let themeStorageKey = "insight_atlas_theme_preference"
    static let accentStorageKey = "insight_atlas_accent_preference"

    /// Light/dark adaptive color from two hex strings, resolved per trait
    /// collection so the whole chrome follows the system (and the Theme setting).
    private static func adaptive(_ light: String, _ dark: String) -> Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    // Accents — brand hues, lightened in dark for contrast on dark surfaces.
    static let gold      = adaptive("#CBA135", "#D9B84A")
    static let goldDark  = adaptive("#A9801F", "#D9B84A")
    static let burgundy  = adaptive("#7B203D", "#C56B82")
    static let coral     = adaptive("#EF7058", "#F0876F")
    static let teal      = adaptive("#3B7C78", "#5FA9A4")

    // Surfaces & text — adaptive so dark mode renders correctly.
    static let background    = adaptive("#F7F4EC", "#1A1816")
    static let card          = adaptive("#FFFDFC", "#2A2725")
    static let searchFill    = adaptive("#EEECEF", "#242120")
    static let chipFill      = adaptive("#ECEBE9", "#33302E")
    static let ink           = adaptive("#171717", "#F5F3ED")
    static let secondaryText = adaptive("#6E6A67", "#B8B0A3")
    static let divider       = adaptive("#E3DDD1", "#3D3A38")
    static let softGold      = adaptive("#F5EEDC", "#332B1A")

    static let cardShadow = Color.black.opacity(0.10)

    static func accent(from rawValue: String) -> Color {
        PremiumAccent(rawValue: rawValue)?.color ?? gold
    }

    // MARK: - Typography (bundled brand fonts, Dynamic Type–scalable)

    /// Display serif (Cormorant Garamond) — screen titles, book/card titles.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold, relativeTo style: Font.TextStyle = .title) -> Font {
        let name: String
        switch weight {
        case .bold:     name = "CormorantGaramond-Bold"
        case .semibold: name = "CormorantGaramond-SemiBold"
        case .medium:   name = "CormorantGaramond-Medium"
        default:        name = "CormorantGaramond-Regular"
        }
        return .custom(name, size: size, relativeTo: style)
    }

    /// UI sans (Inter) — labels, metadata, body chrome.
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        let name: String
        switch weight {
        case .bold:     name = "Inter-Bold"
        case .semibold: name = "Inter-SemiBold"
        case .medium:   name = "Inter-Medium"
        default:        name = "Inter-Regular"
        }
        return .custom(name, size: size, relativeTo: style)
    }
}

enum PremiumTheme: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "iphone"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

enum PremiumAccent: String, CaseIterable, Identifiable {
    case gold = "Gold"
    case burgundy = "Burgundy"
    case coral = "Coral"
    case teal = "Teal"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .gold: return PremiumUI.gold
        case .burgundy: return PremiumUI.burgundy
        case .coral: return PremiumUI.coral
        case .teal: return PremiumUI.teal
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
