import XCTest
@testable import Maru

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

    func testStageManagerCardUsesRecommendedCopyAndStatus() {
        let enabledState = HomeDashboardState(appRules: [], isEnabled: true, isStageManagerEnabled: true, windowScaleFactor: 0.92)
        let disabledState = HomeDashboardState(appRules: [], isEnabled: true, isStageManagerEnabled: false, windowScaleFactor: 0.92)

        XCTAssertEqual(enabledState.stageManagerTitle, "Stage Manager")
        XCTAssertEqual(enabledState.stageManagerStatusTitle, "已开启")
        XCTAssertEqual(disabledState.stageManagerStatusTitle, "未开启")
        XCTAssertEqual(
            enabledState.stageManagerDescription,
            "Stage Manager 已开启。macOS 会将各应用的窗口分组收纳在屏幕一侧，Maru 则在切换应用时自动居中或展开窗口——两者配合，桌面始终整洁有序。"
        )
        XCTAssertEqual(
            enabledState.stageManagerToggleSubtitle,
            "切换应用时 Stage Manager 负责窗口分组收纳，Maru 负责居中和呼吸窗口布局，桌面井然有序。"
        )
    }

    func testHeaderUsesMaruProductPositioning() {
        let state = HomeDashboardState(appRules: [], isEnabled: true, windowScaleFactor: 0.92)

        XCTAssertEqual(state.headerSubtitle, "窗口自动管理的运行状态与偏好。")
        XCTAssertEqual(
            state.heroDescription,
            "Maru 是一款 macOS 开源工具，可自动将窗口优雅地移动到屏幕中央，让桌面始终简洁、平衡、顺手。"
        )
    }
}
