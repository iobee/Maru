import XCTest
@testable import Maru

final class WindowManagerTargetedActionTests: XCTestCase {
    func testTargetedManualActionResolvesCapturedProcessIdentifierBeforeWindowWork() {
        let target = CurrentAppRuleTarget(
            appName: "Codex",
            bundleId: "com.openai.codex",
            processIdentifier: 4242
        )
        var requestedProcessIdentifier: pid_t?
        let activityStore = AppActivityStore(
            storageURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("Maru-TargetedAction-\(UUID().uuidString)")
                .appendingPathComponent("app_activity.json")
        )
        let manager = WindowManager(
            runningApplicationResolver: { processIdentifier in
                requestedProcessIdentifier = processIdentifier
                return nil
            },
            activityStore: activityStore
        )

        manager.performManualWindowAction(.center, target: target, triggerSource: "test")

        XCTAssertEqual(requestedProcessIdentifier, target.processIdentifier)
        XCTAssertEqual(activityStore.events.first?.bundleIdentifier, target.bundleId)
        XCTAssertEqual(activityStore.events.first?.kind, .failure)
    }
}
