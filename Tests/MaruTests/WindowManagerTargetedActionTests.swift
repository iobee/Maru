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
        let manager = WindowManager(runningApplicationResolver: { processIdentifier in
            requestedProcessIdentifier = processIdentifier
            return nil
        })

        manager.performManualWindowAction(.center, target: target, triggerSource: "test")

        XCTAssertEqual(requestedProcessIdentifier, target.processIdentifier)
    }
}
