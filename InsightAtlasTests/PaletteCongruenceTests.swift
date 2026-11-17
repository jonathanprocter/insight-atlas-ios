//
//  PaletteCongruenceTests.swift
//  InsightAtlasTests
//
//  Guards the two palette invariants that are invisible at the call site and
//  so had both already been broken once:
//
//  1. `UIColor.ia*` must be trait-INDEPENDENT. The legacy PDF path draws with
//     these, and a PDF has no trait collection of its own — an adaptive value
//     here renders dark-mode colours into printed output.
//  2. `PremiumUI.Hex.RGB` must agree with `PremiumUI.Hex`. The exported-guide
//     CSS composes tints as `rgba(var(--x-rgb), a)`, so a triplet that drifts
//     from its hex silently re-tints every callout in every export.
//

import XCTest
import UIKit
@testable import InsightAtlas

final class PaletteCongruenceTests: XCTestCase {

    private let light = UITraitCollection(userInterfaceStyle: .light)
    private let dark = UITraitCollection(userInterfaceStyle: .dark)

    /// Every print-facing `UIColor.ia*` resolves to one value in both themes.
    func testPrintPinnedColorsDoNotAdaptToDarkMode() {
        let pinned: [(String, UIColor)] = [
            ("iaBrandOrange", .iaBrandOrange),
            ("iaBrandNavy", .iaBrandNavy),
            ("iaAccentPrimary", .iaAccentPrimary),
            ("iaAccentSuccess", .iaAccentSuccess),
            ("iaAccentHighlight", .iaAccentHighlight),
            ("iaAccentInfo", .iaAccentInfo),
            ("iaAccentPremium", .iaAccentPremium),
            ("iaGold", .iaGold),
            ("iaGoldLight", .iaGoldLight),
            ("iaGoldDark", .iaGoldDark),
            ("iaHeading", .iaHeading),
            ("iaBody", .iaBody),
            ("iaMuted", .iaMuted),
            ("iaSubtle", .iaSubtle),
            ("iaBackground", .iaBackground),
            ("iaCream", .iaCream),
            ("iaCard", .iaCard),
            ("iaIvory", .iaIvory),
            ("iaParchment", .iaParchment),
            ("iaRule", .iaRule),
            ("iaRuleLight", .iaRuleLight),
            ("iaBurgundy", .iaBurgundy),
            ("iaCoral", .iaCoral),
            ("iaTeal", .iaTeal),
            ("iaOrange", .iaOrange),
            ("iaSepia", .iaSepia),
            ("iaWarning", .iaWarning),
            ("iaError", .iaError),
            ("iaSuccess", .iaSuccess),
            ("iaHighlightBg", .iaHighlightBg)
        ]

        for (name, color) in pinned {
            let inLight = color.resolvedColor(with: light)
            let inDark = color.resolvedColor(with: dark)
            XCTAssertEqual(
                components(of: inLight),
                components(of: inDark),
                "\(name) is trait-adaptive; the legacy PDF path would print dark-mode colours with it."
            )
        }
    }

    /// `iaGoldLight` mirrors its SwiftUI counterpart rather than duplicating
    /// `iaGold` — the two were the same value, losing the distinction.
    func testGoldLightIsDistinctFromGold() {
        XCTAssertNotEqual(
            components(of: UIColor.iaGold.resolvedColor(with: light)),
            components(of: UIColor.iaGoldLight.resolvedColor(with: light))
        )
        XCTAssertEqual(
            components(of: UIColor.iaGoldLight.resolvedColor(with: light)),
            components(of: UIColor(hex: PremiumUI.Hex.emberDark))
        )
    }

    /// Each RGB triplet equals the channels of the hex it is named for.
    func testRGBTripletsMatchTheirHexValues() {
        let pairs: [(String, String, String)] = [
            ("ember", PremiumUI.Hex.RGB.emberLight, PremiumUI.Hex.emberLight),
            ("emberDark", PremiumUI.Hex.RGB.emberDark, PremiumUI.Hex.emberDark),
            ("emberMark", PremiumUI.Hex.RGB.emberMarkLight, PremiumUI.Hex.emberMarkLight),
            ("emberMarkDark", PremiumUI.Hex.RGB.emberMarkDark, PremiumUI.Hex.emberMarkDark),
            ("indigo", PremiumUI.Hex.RGB.indigoLight, PremiumUI.Hex.indigoLight),
            ("indigoDark", PremiumUI.Hex.RGB.indigoDark, PremiumUI.Hex.indigoDark),
            ("celadon", PremiumUI.Hex.RGB.celadonLight, PremiumUI.Hex.celadonLight),
            ("celadonDark", PremiumUI.Hex.RGB.celadonDark, PremiumUI.Hex.celadonDark),
            ("destructive", PremiumUI.Hex.RGB.destructiveLight, PremiumUI.Hex.destructiveLight),
            ("destructiveDark", PremiumUI.Hex.RGB.destructiveDark, PremiumUI.Hex.destructiveDark),
            ("ink", PremiumUI.Hex.RGB.inkLight, PremiumUI.Hex.inkLight),
            ("inkDark", PremiumUI.Hex.RGB.inkDark, PremiumUI.Hex.inkDark)
        ]

        for (name, triplet, hex) in pairs {
            XCTAssertEqual(triplet, expectedTriplet(for: hex), "--\(name)-rgb drifted from \(hex)")
        }
    }

    /// The semantic PDF accents stay mutually distinguishable: a caution drawn
    /// in the brand accent is indistinguishable from ordinary brand chrome.
    func testPDFSemanticAccentsAreDistinct() {
        let accents: [(String, UIColor)] = [
            ("semanticNotes", PDFStyleConfiguration.Colors.semanticNotes),
            ("semanticEvidence", PDFStyleConfiguration.Colors.semanticEvidence),
            ("semanticCaution", PDFStyleConfiguration.Colors.semanticCaution),
            ("accentPrimary", PDFStyleConfiguration.Colors.accentPrimary)
        ]

        for i in accents.indices {
            for j in accents.indices where j > i {
                XCTAssertNotEqual(
                    components(of: accents[i].1),
                    components(of: accents[j].1),
                    "\(accents[i].0) and \(accents[j].0) resolve to the same colour"
                )
            }
        }
    }

    /// `borderMedium` is a heavier step than `borderLight`, so the structural
    /// strokes that ask for it do not draw hairlines.
    func testPDFBorderRampHasThreeSteps() {
        let steps = [
            PDFStyleConfiguration.Colors.borderLight,
            PDFStyleConfiguration.Colors.borderMedium,
            PDFStyleConfiguration.Colors.borderDark
        ].map { components(of: $0) }

        XCTAssertNotEqual(steps[0], steps[1])
        XCTAssertNotEqual(steps[1], steps[2])
    }

    /// Legacy accent preferences stored by an earlier build still decode.
    func testLegacyAccentPreferencesStillDecode() {
        XCTAssertEqual(PremiumAccent(rawValue: "Gold"), .ember)
        XCTAssertEqual(PremiumAccent(rawValue: "Burgundy"), .ember)
        XCTAssertEqual(PremiumAccent(rawValue: "Coral"), .ember)
        XCTAssertEqual(PremiumAccent(rawValue: "Teal"), .celadon)
        XCTAssertEqual(PremiumAccent(rawValue: "Ember"), .ember)
        XCTAssertNil(PremiumAccent(rawValue: "Chartreuse"))
        // One swatch per hue — no duplicate-looking rows in the picker.
        XCTAssertEqual(PremiumAccent.allCases.count, 3)
    }

    // MARK: - Helpers

    private func components(of color: UIColor) -> [Int] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b, a].map { Int(($0 * 255).rounded()) }
    }

    private func expectedTriplet(for hex: String) -> String {
        var value: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
            .scanHexInt64(&value)
        return "\(value >> 16 & 0xFF), \(value >> 8 & 0xFF), \(value & 0xFF)"
    }
}
