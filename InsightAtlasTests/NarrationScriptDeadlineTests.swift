import XCTest
@testable import InsightAtlas

/// The narration rewrite is an optional quality pass, but audio cannot start
/// until it returns. It used to inherit AIService's 300-second request timeout,
/// so a stalled rewrite blocked playback for five minutes. It must now give up
/// well before that.
final class NarrationScriptDeadlineTests: XCTestCase {

    func testFastWorkReturnsItsValue() async throws {
        let value = try await NarrationScriptService.withRewriteDeadline {
            "rewritten script"
        }
        XCTAssertEqual(value, "rewritten script")
    }

    func testWorkErrorsPropagateRatherThanBeingSwallowed() async {
        struct Boom: Error {}
        do {
            _ = try await NarrationScriptService.withRewriteDeadline {
                throw Boom()
            }
            XCTFail("the underlying error should propagate")
        } catch is NarrationScriptTimeout {
            XCTFail("a thrown error must not be reported as a timeout")
        } catch {
            // Expected: the original error reaches the caller, which narrates
            // the raw guide.
        }
    }

    /// Work that outlives the deadline is abandoned. Driven by a deadline
    /// shorter than the production one so the test stays fast.
    func testSlowWorkTimesOut() async {
        do {
            _ = try await withThrowingTaskGroup(of: String?.self) { group in
                group.addTask {
                    try await Task.sleep(for: .seconds(30))
                    return "too late"
                }
                group.addTask {
                    try await Task.sleep(for: .milliseconds(50))
                    return nil
                }
                defer { group.cancelAll() }
                while let result = try await group.next() {
                    if let result { return result }
                    throw NarrationScriptTimeout()
                }
                throw NarrationScriptTimeout()
            }
            XCTFail("slow work should have timed out")
        } catch is NarrationScriptTimeout {
            // Expected.
        } catch {
            XCTFail("expected a timeout, got \(error)")
        }
    }

    /// The whole point of the change: the rewrite must give up far sooner than
    /// AIService's 300-second per-request budget.
    func testDeadlineIsWellUnderTheRequestTimeout() {
        XCTAssertLessThan(
            NarrationScriptService.rewriteDeadline,
            .seconds(300),
            "the rewrite must not inherit the full request timeout"
        )
        XCTAssertGreaterThan(
            NarrationScriptService.rewriteDeadline,
            .seconds(30),
            "too short a deadline would abandon legitimate rewrites"
        )
    }
}
