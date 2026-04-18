import XCTest
@testable import HiWindowGuy

final class HomeDashboardStateTests: XCTestCase {
    func testSummaryItemsReflectRuleCounts() {
        let rules: [AppRule] = [
            AppRule(bundleId: "com.example.center-1", appName: "Center 1", rule: .center, lastUsed: .now, useCount: 1),
            AppRule(bundleId: "com.example.center-2", appName: "Center 2", rule: .center, lastUsed: .now, useCount: 1),
            AppRule(bundleId: "com.example.maximize", appName: "Maximize", rule: .almostMaximize, lastUsed: .now, useCount: 1),
            AppRule(bundleId: "com.example.ignore", appName: "Ignore", rule: .ignore, lastUsed: .now, useCount: 1)
        ]

        let state = HomeDashboardState(appRules: rules, isEnabled: true, windowScaleFactor: 0.92)

        XCTAssertEqual(
            state.summaryItems.map(\.count),
            [4, 2, 1, 1]
        )
    }

    func testStatusTitleTracksEnabledState() {
        let enabledState = HomeDashboardState(appRules: [], isEnabled: true, windowScaleFactor: 0.92)
        let disabledState = HomeDashboardState(appRules: [], isEnabled: false, windowScaleFactor: 0.92)

        XCTAssertEqual(enabledState.statusTitle, "已启用")
        XCTAssertEqual(disabledState.statusTitle, "已停用")
    }
}
