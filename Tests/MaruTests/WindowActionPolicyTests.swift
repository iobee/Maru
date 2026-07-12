import XCTest
@testable import Maru

final class WindowActionPolicyTests: XCTestCase {
    func testBreathingResizableWindowUsesResizeThenCenterPlan() {
        let plan = WindowActionPolicy.mutationPlan(
            for: .almostMaximize,
            capabilities: WindowActionCapabilities(isPositionSettable: true, isSizeSettable: true)
        )

        XCTAssertEqual(plan, .resizeThenCenter)
    }

    func testBreathingFixedSizeWindowUsesPositionOnlyPlan() {
        let plan = WindowActionPolicy.mutationPlan(
            for: .almostMaximize,
            capabilities: WindowActionCapabilities(isPositionSettable: true, isSizeSettable: false)
        )

        XCTAssertEqual(plan, .positionOnly)
    }

    func testCenterNeverRequiresSizeMutation() {
        let plan = WindowActionPolicy.mutationPlan(
            for: .center,
            capabilities: WindowActionCapabilities(isPositionSettable: true, isSizeSettable: true)
        )

        XCTAssertEqual(plan, .positionOnly)
    }

    func testPositionUnavailableRejectsBeforeResize() {
        let plan = WindowActionPolicy.mutationPlan(
            for: .almostMaximize,
            capabilities: WindowActionCapabilities(isPositionSettable: false, isSizeSettable: true)
        )

        XCTAssertEqual(plan, .unavailable)
    }

    func testResizeRetriesWhenSetterReportsSuccessButWindowDidNotMoveAtAll() {
        XCTAssertTrue(
            WindowResizeSettlingPolicy.shouldRetry(
                originalSize: CGSize(width: 900, height: 700),
                actualSize: CGSize(width: 900, height: 700),
                requestedSize: CGSize(width: 1200, height: 800),
                retriesRemaining: 2
            )
        )
    }

    func testResizeAcceptsApplicationConstrainedSizeAfterAnyActualResponse() {
        XCTAssertFalse(
            WindowResizeSettlingPolicy.shouldRetry(
                originalSize: CGSize(width: 900, height: 700),
                actualSize: CGSize(width: 1050, height: 740),
                requestedSize: CGSize(width: 1200, height: 800),
                retriesRemaining: 2
            )
        )
    }

    func testResizeDoesNotRetryWhenAlreadyAtRequestedSizeOrBudgetIsExhausted() {
        XCTAssertFalse(
            WindowResizeSettlingPolicy.shouldRetry(
                originalSize: CGSize(width: 1200, height: 800),
                actualSize: CGSize(width: 1200, height: 800),
                requestedSize: CGSize(width: 1200, height: 800),
                retriesRemaining: 2
            )
        )

        XCTAssertFalse(
            WindowResizeSettlingPolicy.shouldRetry(
                originalSize: CGSize(width: 900, height: 700),
                actualSize: CGSize(width: 900, height: 700),
                requestedSize: CGSize(width: 1200, height: 800),
                retriesRemaining: 0
            )
        )
    }

}
