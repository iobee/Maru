import XCTest
import ApplicationServices
@testable import Maru

final class WindowAccessibilityCompatibilityTests: XCTestCase {
    func testNonDisabledAXErrorKeepsNormalWindowResolutionPath() {
        let decision = WindowAccessibilityCompatibilityPolicy.decision(
            for: .success,
            activationRequestedAt: nil
        )

        XCTAssertEqual(decision, .proceed)
    }

    func testDisabledAPIRequestsManualAccessibilityOnFirstEncounter() {
        let decision = WindowAccessibilityCompatibilityPolicy.decision(
            for: .apiDisabled,
            activationRequestedAt: nil
        )

        XCTAssertEqual(decision, .requestActivation)
    }

    func testDisabledAPIWaitsDuringActivationGracePeriod() {
        let now = Date(timeIntervalSince1970: 10)
        let decision = WindowAccessibilityCompatibilityPolicy.decision(
            for: .apiDisabled,
            activationRequestedAt: now.addingTimeInterval(-1),
            now: now,
            graceInterval: 1.5
        )

        XCTAssertEqual(decision, .awaitActivation)
    }

    func testDisabledAPIBecomesUnavailableAfterGracePeriod() {
        let now = Date(timeIntervalSince1970: 10)
        let decision = WindowAccessibilityCompatibilityPolicy.decision(
            for: .apiDisabled,
            activationRequestedAt: now.addingTimeInterval(-2),
            now: now,
            graceInterval: 1.5
        )

        XCTAssertEqual(decision, .unavailable)
    }
}
