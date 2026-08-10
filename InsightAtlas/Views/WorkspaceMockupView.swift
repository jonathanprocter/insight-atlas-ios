import SwiftUI

// MARK: - Shared Library Chrome
//
// These components were extracted from the original standalone "Workspace
// Mockup" screen and are now composed directly into the functional Library
// (see `LibraryView`). The mockup screen itself has been removed — the Library
// is the single, real implementation of that design.

/// Deep-slate brand footer shown at the bottom of the Library. Mirrors the
/// editorial footer from the original design: brand mark, tagline, and a
/// monospaced system/version line.
struct LibraryFooterView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isWide: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        Group {
            if isWide {
                HStack(alignment: .top, spacing: 48) {
                    brandBlock
                    Spacer()
                    HStack(spacing: 36) {
                        footerLink("Library")
                        footerLink("Index")
                        footerLink("Settings")
                    }
                    copyright
                }
                .padding(.horizontal, 56)
                .padding(.top, 56)
                .padding(.bottom, 36)
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    brandBlock
                    copyright
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.top, 36)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity)
        .background(ChromePalette.deepSlate)
    }

    private var brandBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "safari")
                    .font(.system(size: isWide ? 22 : 18, weight: .regular))
                    .foregroundStyle(ChromePalette.coral)
                Text("Insight Atlas")
                    .font(PremiumUI.ui(isWide ? 17 : 14, .bold, relativeTo: .caption))
                    .tracking(isWide ? 2.5 : 2)
                    .textCase(.uppercase)
                    .foregroundStyle(.white)
            }

            Text("Where understanding illuminates the world.")
                .font(PremiumUI.display(isWide ? 20 : 17, .regular, relativeTo: .body).italic())
                .foregroundStyle(ChromePalette.gold)
        }
    }

    private func footerLink(_ title: String) -> some View {
        Text(title)
            .font(PremiumUI.ui(12, .bold, relativeTo: .caption))
            .tracking(1.8)
            .textCase(.uppercase)
            .foregroundStyle(Color.white.opacity(0.6))
    }

    private var copyright: some View {
        Text("© 2026 INSIGHT ATLAS · SYS.VER.4.0.3")
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(2)
            .foregroundStyle(Color.white.opacity(0.35))
    }
}

/// Decorative compass illustration used behind the Library hero.
struct CompassMark: View {
    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = size * 0.45

            ZStack {
                Circle()
                    .stroke(ChromePalette.deepSlate, lineWidth: 1.2)
                    .frame(width: radius * 2, height: radius * 2)
                Circle()
                    .stroke(ChromePalette.gold.opacity(0.45), lineWidth: 0.6)
                    .frame(width: radius * 1.96, height: radius * 1.96)
                Circle()
                    .stroke(ChromePalette.deepSlate.opacity(0.6), lineWidth: 0.6)
                    .frame(width: radius * 1.33, height: radius * 1.33)

                ForEach(0..<8) { index in
                    Rectangle()
                        .fill(ChromePalette.deepSlate.opacity(index.isMultiple(of: 2) ? 1 : 0.5))
                        .frame(width: index.isMultiple(of: 2) ? 2 : 1.2, height: index.isMultiple(of: 2) ? 16 : 11)
                        .offset(y: -radius + 8)
                        .rotationEffect(.degrees(Double(index) * 45))
                }

                Path { path in
                    path.move(to: CGPoint(x: center.x, y: center.y - radius + 6))
                    path.addLine(to: CGPoint(x: center.x + 5, y: center.y - 15))
                    path.addLine(to: CGPoint(x: center.x, y: center.y - 22))
                    path.addLine(to: CGPoint(x: center.x - 5, y: center.y - 15))
                    path.closeSubpath()
                }
                .fill(ChromePalette.deepSlate.opacity(0.55))

                Path { path in
                    path.move(to: CGPoint(x: center.x, y: center.y + radius - 6))
                    path.addLine(to: CGPoint(x: center.x + 5, y: center.y + 15))
                    path.addLine(to: CGPoint(x: center.x, y: center.y + 22))
                    path.addLine(to: CGPoint(x: center.x - 5, y: center.y + 15))
                    path.closeSubpath()
                }
                .fill(ChromePalette.deepSlate.opacity(0.18))

                Path { path in
                    path.move(to: CGPoint(x: center.x - radius * 0.9, y: center.y + radius * 0.6))
                    path.addCurve(
                        to: CGPoint(x: center.x + radius * 0.92, y: center.y - radius * 0.08),
                        control1: CGPoint(x: center.x - radius * 0.4, y: center.y + radius * 0.35),
                        control2: CGPoint(x: center.x + radius * 0.35, y: center.y + radius * 0.15)
                    )
                }
                .stroke(ChromePalette.deepSlate.opacity(0.25), style: StrokeStyle(lineWidth: 0.8, dash: [3, 5]))

                Circle()
                    .fill(ChromePalette.gold.opacity(0.1))
                    .frame(width: 28, height: 28)
                Circle()
                    .fill(ChromePalette.gold.opacity(0.85))
                    .frame(width: 14, height: 14)
                Circle()
                    .fill(ChromePalette.ivory)
                    .frame(width: 6, height: 6)

                cardinal("N", y: -radius - 8)
                cardinal("S", y: radius + 8)
                cardinal("W", x: -radius - 9)
                cardinal("E", x: radius + 9)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func cardinal(_ text: String, x: CGFloat = 0, y: CGFloat = 0) -> some View {
        Text(text)
            .font(PremiumUI.ui(7, .bold, relativeTo: .caption2))
            .foregroundStyle(ChromePalette.deepSlate.opacity(0.4))
            .offset(x: x, y: y)
    }
}

/// Fixed brand palette for the Library chrome (footer + compass). These are the
/// signature editorial tones and are intentionally non-adaptive.
private enum ChromePalette {
    static let ivory = Color(hex: "#FAF9F6")
    static let deepSlate = Color(hex: "#2C3E50")
    static let gold = Color(hex: "#B8962E")
    static let coral = Color(hex: "#E8553A")
}

#Preview("Library Footer") {
    LibraryFooterView()
}

#Preview("Compass Mark") {
    CompassMark()
        .frame(width: 240, height: 240)
        .padding()
}
