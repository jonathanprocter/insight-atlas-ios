import XCTest
@testable import InsightAtlas

/// Exercises the pure scale-to-fit decision — the measure==draw contract lives
/// in `target`: when the renderer scales a diagram it draws to exactly `target`
/// AND the paginator advances currentY by exactly `target`, so a scaled draw can
/// never diverge from its measure. Real observed content (gaps 458–510pt against
/// ~526pt diagrams) yields s≈0.87–0.97, comfortably above the 0.70 floor.
final class DiagramScaleToFitTests: XCTestCase {

    private let r = PDFContentBlockRenderer()

    func testFitsWhenDiagramSmallerThanRemaining() {
        XCTAssertEqual(r.diagramScaleDecision(naturalHeight: 300, remaining: 400), .fits)
    }

    func testScalesToFillRemainingAboveFloor() {
        // The p10 case: 526pt diagram into a 458pt remainder.
        let d = r.diagramScaleDecision(naturalHeight: 526, remaining: 458)
        guard case let .scale(factor, target) = d else { return XCTFail("expected .scale, got \(d)") }
        XCTAssertEqual(target, 458, accuracy: 0.001, "target == remaining (measure==draw)")
        XCTAssertEqual(factor, 458.0 / 526.0, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(factor, PDFContentBlockRenderer.diagramLegibilityFloor)
    }

    func testWorstObservedGapStillScales() {
        // The p69 case: 526pt diagram, 510pt remainder → s≈0.97.
        let d = r.diagramScaleDecision(naturalHeight: 526, remaining: 510)
        if case .scale = d {} else { XCTFail("worst observed gap must still scale, got \(d)") }
    }

    func testPushesWholeBelowFloor() {
        // A monstrous diagram into a tiny remainder → s far below floor.
        XCTAssertEqual(r.diagramScaleDecision(naturalHeight: 600, remaining: 200), .pushWhole)
    }

    func testFloorBoundaryIsInclusive() {
        // Exactly at the floor scales; a hair below pushes whole.
        let atFloor = r.diagramScaleDecision(naturalHeight: 1000, remaining: 700)   // s = 0.70
        if case .scale = atFloor {} else { XCTFail("s == floor must scale") }
        let belowFloor = r.diagramScaleDecision(naturalHeight: 1000, remaining: 699) // s = 0.699
        XCTAssertEqual(belowFloor, .pushWhole)
    }
}
