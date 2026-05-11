import XCTest
@testable import Maru

final class StatusBarMenuLayoutTests: XCTestCase {
    func testGroupsMatchConfirmedStatusBarMenuOrder() {
        XCTAssertEqual(
            StatusBarMenuLayout.groups,
            [
                [.currentAppRuleMenu],
                [.windowManagementToggle, .manualAction(.center), .manualAction(.almostMaximize), .manualAction(.moveToNextDisplay)],
                [.appConfiguration, .appRules, .checkForUpdates],
                [.quit]
            ]
        )
    }

    func testMenuTitlesMatchConfirmedLabels() {
        XCTAssertEqual(StatusBarMenuItem.currentAppRuleMenu.title, "配置当前应用")
        XCTAssertEqual(StatusBarMenuItem.windowManagementToggle.title, "窗口自动管理")
        XCTAssertEqual(ManualWindowAction.center.menuTitle, "居中窗口")
        XCTAssertEqual(ManualWindowAction.almostMaximize.menuTitle, "呼吸窗口")
        XCTAssertEqual(ManualWindowAction.moveToNextDisplay.menuTitle, "移到下一显示器")
        XCTAssertEqual(StatusBarMenuItem.appConfiguration.title, "应用配置")
        XCTAssertEqual(StatusBarMenuItem.appRules.title, "应用规则")
        XCTAssertEqual(StatusBarMenuItem.checkForUpdates.title, "检查更新…")
        XCTAssertEqual(StatusBarMenuItem.quit.title, "退出")
    }

    func testLayoutDoesNotIncludeLogViewerItem() {
        let titles = StatusBarMenuLayout.groups.flatMap { $0 }.map(\.title)

        XCTAssertFalse(titles.contains("查看日志"))
    }

    func testMenuItemIdentifiersAreStableForRendering() {
        XCTAssertEqual(StatusBarMenuItem.currentAppRuleMenu.id, "currentAppRuleMenu")
        XCTAssertEqual(StatusBarMenuItem.windowManagementToggle.id, "windowManagementToggle")
        XCTAssertEqual(StatusBarMenuItem.manualAction(.center).id, "manualAction.center")
        XCTAssertEqual(StatusBarMenuItem.manualAction(.almostMaximize).id, "manualAction.almostMaximize")
        XCTAssertEqual(StatusBarMenuItem.manualAction(.moveToNextDisplay).id, "manualAction.moveToNextDisplay")
        XCTAssertEqual(StatusBarMenuItem.appConfiguration.id, "appConfiguration")
        XCTAssertEqual(StatusBarMenuItem.appRules.id, "appRules")
        XCTAssertEqual(StatusBarMenuItem.checkForUpdates.id, "checkForUpdates")
        XCTAssertEqual(StatusBarMenuItem.quit.id, "quit")

        let identifiers = StatusBarMenuLayout.groups.flatMap { $0 }.map(\.id)

        XCTAssertEqual(Set(identifiers).count, identifiers.count)
    }
}
