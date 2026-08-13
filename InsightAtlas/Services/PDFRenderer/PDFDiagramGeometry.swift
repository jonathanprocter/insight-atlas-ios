import CoreGraphics
import Foundation

// MARK: - PDF Diagram Geometry (Phase 2 — Directives §A4)
//
// COMPUTED geometry for the loop diagram. Every connector endpoint is solved
// against the circle equation (center, radius) so it lies exactly on the true
// circle, and a fixed clearance margin is enforced between arc endpoints and
// node bounding boxes. This replicates the MATH of the corrected Figure 9 SVG
// in the redesign mockup — not its literal coordinates.
//
// These are pure value-producing functions with no drawing side effects, so the
// geometry can be unit-tested independently of Core Graphics (endpoints on the
// circle within 1pt; no endpoint closer than the clearance margin to any node).

/// A node placed on the loop circle.
struct LoopNode {
    let index: Int
    let center: CGPoint
    let rect: CGRect
    /// Absolute (non-normalized) angle of the node center, radians. 0 = +x axis.
    let angle: CGFloat
}

/// A connector arc between two consecutive nodes, following the circle.
struct LoopArc {
    let fromNode: Int
    let toNode: Int
    /// Arc sweep angles (radians), monotonically increasing (clockwise in the
    /// PDF's y-down coordinate space). Endpoints below are on the circle.
    let startAngle: CGFloat
    let endAngle: CGFloat
    let startPoint: CGPoint
    let endPoint: CGPoint
}

/// The fully resolved geometry for a loop diagram.
struct LoopGeometry {
    let center: CGPoint
    let radius: CGFloat
    let nodes: [LoopNode]
    let arcs: [LoopArc]
}

enum PDFDiagramGeometry {

    /// Minimum clearance (pt) enforced between an arc endpoint/arrowhead and any
    /// node's bounding box. Directive requires ≥ 4pt.
    static let clearance: CGFloat = 6

    /// Solve the loop layout for `nodeCount` nodes on a circle.
    ///
    /// - Parameters:
    ///   - center: circle center in the target coordinate space.
    ///   - radius: circle radius.
    ///   - nodeCount: number of nodes (≥ 2).
    ///   - nodeSize: bounding box each node occupies.
    /// - Returns: node placements + connector arcs whose endpoints all lie on
    ///   the circle and clear each node box by at least `clearance`.
    static func solveLoop(
        center: CGPoint,
        radius: CGFloat,
        nodeCount: Int,
        nodeSize: CGSize
    ) -> LoopGeometry {
        let n = max(2, nodeCount)
        let step = (2 * CGFloat.pi) / CGFloat(n)

        // Nodes start at the top (-π/2) and proceed clockwise. Absolute angles
        // are kept un-normalized so arc sweeps stay monotonic across the wrap.
        var nodes: [LoopNode] = []
        for i in 0..<n {
            let angle = -CGFloat.pi / 2 + CGFloat(i) * step
            let nodeCenter = point(on: center, radius: radius, angle: angle)
            let rect = CGRect(
                x: nodeCenter.x - nodeSize.width / 2,
                y: nodeCenter.y - nodeSize.height / 2,
                width: nodeSize.width,
                height: nodeSize.height
            )
            nodes.append(LoopNode(index: i, center: nodeCenter, rect: rect, angle: angle))
        }

        // Angular clearance for a node. We require the CHORD from a node center
        // to an arc endpoint to be at least the node's circumradius (half the
        // diagonal) plus the clearance margin. Because the node rect is contained
        // in the disc of that circumradius, this guarantees the endpoint clears
        // the rect by ≥ `clearance`:
        //     |endpoint − center| ≥ halfDiagonal + clearance
        //   ⇒ distance(endpoint, rect) ≥ clearance
        // Chord = 2·R·sin(δ/2), so δ = 2·asin((halfDiagonal + clearance) / (2R)).
        let halfDiagonal = hypot(nodeSize.width / 2, nodeSize.height / 2)
        let needed = (halfDiagonal + clearance) / (2 * max(radius, 1))
        let delta = needed >= 1 ? (step / 2 - 0.001) : min(step / 2 - 0.001, 2 * asin(needed))

        var arcs: [LoopArc] = []
        for i in 0..<n {
            let baseFrom = -CGFloat.pi / 2 + CGFloat(i) * step
            let baseTo = -CGFloat.pi / 2 + CGFloat(i + 1) * step   // wraps past 2π on the last arc
            let startAngle = baseFrom + delta
            let endAngle = baseTo - delta
            arcs.append(LoopArc(
                fromNode: i,
                toNode: (i + 1) % n,
                startAngle: startAngle,
                endAngle: endAngle,
                startPoint: point(on: center, radius: radius, angle: startAngle),
                endPoint: point(on: center, radius: radius, angle: endAngle)
            ))
        }

        return LoopGeometry(center: center, radius: radius, nodes: nodes, arcs: arcs)
    }

    /// A point on the circle at `angle` — the circle equation, used everywhere so
    /// endpoints are on the circle by construction.
    static func point(on center: CGPoint, radius: CGFloat, angle: CGFloat) -> CGPoint {
        CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
    }

    // MARK: - Validation helpers (used by tests and by DEBUG assertions)

    /// Largest deviation of any node center or arc endpoint from the true circle
    /// (should be ~0 by construction; asserted < 1pt).
    static func maxRadialError(_ g: LoopGeometry) -> CGFloat {
        var worst: CGFloat = 0
        func check(_ p: CGPoint) {
            let d = hypot(p.x - g.center.x, p.y - g.center.y)
            worst = max(worst, abs(d - g.radius))
        }
        g.nodes.forEach { check($0.center) }
        g.arcs.forEach { check($0.startPoint); check($0.endPoint) }
        return worst
    }

    /// Smallest distance between any arc endpoint and any node's bounding box.
    /// Must be ≥ `clearance`.
    static func minEndpointClearance(_ g: LoopGeometry) -> CGFloat {
        var worst = CGFloat.greatestFiniteMagnitude
        for arc in g.arcs {
            for node in g.nodes {
                worst = min(worst, distance(from: arc.startPoint, to: node.rect))
                worst = min(worst, distance(from: arc.endPoint, to: node.rect))
            }
        }
        return worst
    }

    /// Euclidean distance from a point to the nearest edge of a rect (0 if inside).
    static func distance(from p: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - p.x, 0, p.x - rect.maxX)
        let dy = max(rect.minY - p.y, 0, p.y - rect.maxY)
        return hypot(dx, dy)
    }
}
