import XCTest
@testable import Maru

final class CurrentAppRuleTargetTrackerTests: XCTestCase {
    private let maru = CurrentAppRuleTarget(
        appName: "Maru",
        bundleId: "com.nick.maru",
        processIdentifier: 11
    )
    private let codex = CurrentAppRuleTarget(
        appName: "Codex",
        bundleId: "com.openai.codex",
        processIdentifier: 22
    )

    func testWorkspaceActivationSetsExternalApplicationTarget() {
        let tracker = CurrentAppRuleTargetTracker(
            appBundleIdentifier: "com.nick.maru",
            observesNotifications: false
        )

        tracker.recordWorkspaceActivation(codex)

        XCTAssertEqual(tracker.menuTargetApp, codex)
    }

    func testWorkspaceActivationIgnoresOwnAppWithoutReplacingPreviousExternalTarget() {
        let tracker = CurrentAppRuleTargetTracker(
            appBundleIdentifier: "com.nick.maru",
            observesNotifications: false
        )

        tracker.recordWorkspaceActivation(codex)
        tracker.recordWorkspaceActivation(maru)

        XCTAssertEqual(tracker.menuTargetApp, codex)
    }

    func testOwnAppWindowTargetAllowsConfiguringMaruItself() {
        let tracker = CurrentAppRuleTargetTracker(
            appBundleIdentifier: "com.nick.maru",
            observesNotifications: false
        )

        tracker.recordOwnAppWindowTarget(maru)

        XCTAssertEqual(tracker.menuTargetApp, maru)
    }
}
