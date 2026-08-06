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

    // Accents — CMV-blended palette; hero gold plus supporting hues.
    // Dark variants are lightened for contrast on dark surfaces.
    static let gold       = adaptive("#D4B820", "#E0C645")   // Sunny Gold (hero)
    static let goldDark   = adaptive("#A8901A", "#E0C645")
    static let burgundy   = adaptive("#7B203D", "#C56B82")
    static let coral      = adaptive("#E8553A", "#F0876F")   // Coral Arrow
    static let teal       = adaptive("#3B7C78", "#5FA9A4")
    static let skyBlue    = adaptive("#4BA3C8", "#6FC0DF")   // Sky Blue
    static let forest     = adaptive("#3D5840", "#7BAE80")   // Forest
    static let warmOrange = adaptive("#D87520", "#E89B5A")   // Warm Orange

    // Surfaces & text — "Warm Mist" cool-neutral base (2026 quiet-interface),
    // adaptive so dark mode renders correctly.
    static let background    = adaptive("#F3F4F1", "#16181A")
    static let card          = adaptive("#FAFCFD", "#24262A")
    static let searchFill    = adaptive("#ECEFF2", "#23262A")
    static let chipFill      = adaptive("#E7EAEE", "#2E3237")
    static let ink           = adaptive("#1E1E1E", "#F2F4F5")
    static let secondaryText = adaptive("#555555", "#B4B8BC")
    static let divider       = adaptive("#E1E4E8", "#33373B")
    static let softGold      = adaptive("#F5EFD6", "#332B18")

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
