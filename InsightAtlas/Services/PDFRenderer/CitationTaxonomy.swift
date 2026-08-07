import UIKit

// MARK: - Citation Taxonomy (Phase 4 — Citation Spec §1)
//
// Loads the bundled `citation-taxonomy.json` (extracted verbatim from the spec)
// and exposes label / color token / render priority for each citation function.
// Falls back to embedded defaults that mirror the JSON if the resource is
// missing, so classification never crashes at runtime.

struct CitationTaxonomy {

    struct FunctionSpec: Codable {
        let label: String
        let colorToken: String
        let trigger: String
        let renderPriority: Int
    }

    struct Data: Codable {
        let functions: [String: FunctionSpec]
        let audienceLevels: [String]
    }

    static let shared = CitationTaxonomy()

    let data: Data

    private init() {
        if let url = Bundle.main.url(forResource: "citation-taxonomy", withExtension: "json"),
           let raw = try? Foundation.Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(Data.self, from: raw) {
            self.data = decoded
        } else {
            self.data = CitationTaxonomy.embeddedFallback
        }
    }

    func spec(for fn: CitationFunction) -> FunctionSpec {
        data.functions[fn.rawValue] ?? CitationTaxonomy.embeddedFallback.functions[fn.rawValue]!
    }

    /// Embedded defaults — identical to citation-taxonomy.json §1.
    private static let embeddedFallback = Data(
        functions: [
            "primary_source": .init(label: "Primary Source", colorToken: "burgundy", trigger: "", renderPriority: 1),
            "mechanism": .init(label: "The Mechanism", colorToken: "burgundy", trigger: "", renderPriority: 2),
            "evidence": .init(label: "The Evidence", colorToken: "evidence", trigger: "", renderPriority: 2),
            "counterpoint": .init(label: "The Counterpoint", colorToken: "caution", trigger: "", renderPriority: 1),
            "parallel_track": .init(label: "Parallel Track", colorToken: "burgundy", trigger: "", renderPriority: 3),
            "practitioner": .init(label: "For Practitioners", colorToken: "practice", trigger: "", renderPriority: 3)
        ],
        audienceLevels: ["Start Here", "Accessible", "For Practitioners", "Foundational", "Essential", "Primary", "Deep End"]
    )
}

// MARK: - CitationFunction metadata

extension CitationFunction {
    var label: String { CitationTaxonomy.shared.spec(for: self).label }
    var colorToken: String { CitationTaxonomy.shared.spec(for: self).colorToken }
    var renderPriority: Int { CitationTaxonomy.shared.spec(for: self).renderPriority }
    var accentColor: UIColor { PDFStyleConfiguration.Colors.semanticColor(for: colorToken) }
}

// MARK: - Color token → semantic UIColor

extension PDFStyleConfiguration.Colors {
    /// Map a taxonomy/mockup color token to its semantic PDF color.
    static func semanticColor(for token: String) -> UIColor {
        switch token {
        case "burgundy": return semanticNotes
        case "evidence": return semanticEvidence
        case "practice": return semanticPractice
        case "caution": return semanticCaution
        case "copper": return primaryGold
        default: return semanticNotes
        }
    }
}
