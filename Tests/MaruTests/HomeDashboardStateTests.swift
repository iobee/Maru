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

    func testCompanionStatusReflectsBothSystemSettings() {
        let disabledState = HomeDashboardState(
            appRules: [],
            isEnabled: true,
            windowScaleFactor: 0.92
        )
        let partialState = HomeDashboardState(
            appRules: [],
            isEnabled: true,
            isStageManagerEnabled: true,
            windowScaleFactor: 0.92
        )
        let enabledState = HomeDashboardState(
            appRules: [],
            isEnabled: true,
            isStageManagerEnabled: true,
            isDockAutohideEnabled: true,
            windowScaleFactor: 0.92
        )

        XCTAssertEqual(disabledState.companionStatus, .disabled)
        XCTAssertEqual(partialState.companionStatus, .partial)
        XCTAssertEqual(enabledState.companionStatus, .enabled)
        XCTAssertEqual(partialState.companionStatusTitle, "部分开启")
        XCTAssertEqual(
            partialState.companionToggleSubtitle,
            "Stage Manager 已开启；打开组合开关即可同时补上 Dock 自动隐藏。"
        )
        XCTAssertFalse(disabledState.isCompanionEnabled)
        XCTAssertFalse(partialState.isCompanionEnabled)
        XCTAssertTrue(enabledState.isCompanionEnabled)
    }

    func testCompanionUsesRecommendedCopyAndKeepsIndividualLabels() {
        let state = HomeDashboardState(
            appRules: [],
            isEnabled: true,
            windowScaleFactor: 0.92
        )

        XCTAssertEqual(state.companionTitle, "Maru 风格好搭子")
        XCTAssertEqual(state.companionStatusTitle, "推荐开启")
        XCTAssertEqual(state.companionToggleTitle, "一键开启推荐搭配")
        XCTAssertEqual(
            state.companionDescription,
            "一键开启 Stage Manager 和 Dock 自动隐藏，让窗口分组、居中与呼吸留白自然配合。"
        )
        XCTAssertEqual(state.individualSettingsTitle, "单独设置")
        XCTAssertEqual(state.stageManagerTitle, "Stage Manager")
        XCTAssertEqual(state.dockAutohideTitle, "自动隐藏 Dock")
    }

    func testCompanionEnablePlanOnlyWritesMissingSettings() {
        let disabledState = HomeDashboardState(
            appRules: [],
            isEnabled: true,
            windowScaleFactor: 0.92
        )
        let stageManagerOnlyState = HomeDashboardState(
            appRules: [],
            isEnabled: true,
            isStageManagerEnabled: true,
            windowScaleFactor: 0.92
        )
        let dockOnlyState = HomeDashboardState(
            appRules: [],
            isEnabled: true,
            isDockAutohideEnabled: true,
            windowScaleFactor: 0.92
        )

        XCTAssertEqual(
            disabledState.companionChangePlan(targetEnabled: true),
            HomeDashboardState.CompanionChangePlan(
                stageManagerTarget: true,
                dockAutohideTarget: true
            )
        )
        XCTAssertEqual(
            stageManagerOnlyState.companionChangePlan(targetEnabled: true),
            HomeDashboardState.CompanionChangePlan(
                stageManagerTarget: nil,
                dockAutohideTarget: true
            )
        )
        XCTAssertEqual(
            dockOnlyState.companionChangePlan(targetEnabled: true),
            HomeDashboardState.CompanionChangePlan(
                stageManagerTarget: true,
                dockAutohideTarget: nil
            )
        )
    }

    func testCompanionDisablePlanTurnsOffBothSettings() {
        let state = HomeDashboardState(
            appRules: [],
            isEnabled: true,
            isStageManagerEnabled: true,
            isDockAutohideEnabled: true,
            windowScaleFactor: 0.92
        )

        XCTAssertEqual(
            state.companionChangePlan(targetEnabled: false),
            HomeDashboardState.CompanionChangePlan(
                stageManagerTarget: false,
                dockAutohideTarget: false
            )
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
