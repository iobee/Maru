import XCTest
@testable import Maru

final class StatusBarMenuLayoutTests: XCTestCase {
    func testGroupsMatchConfirmedStatusBarMenuOrder() {
        XCTAssertEqual(
            StatusBarMenuLayout.groups,
            [
                [.windowManagementToggle],
                [.manualAction(.center), .manualAction(.almostMaximize), .manualAction(.moveToNextDisplay)],
                [.appConfiguration, .appRules, .checkForUpdates],
                [.quit]
            ]
        )
    }

    func testMenuTitlesMatchConfirmedLabels() {
        XCTAssertEqual(StatusBarMenuItem.windowManagementToggle.menuTitle, "窗口自动管理")
        XCTAssertEqual(ManualWindowAction.center.menuTitle, "居中窗口")
        XCTAssertEqual(ManualWindowAction.almostMaximize.menuTitle, "呼吸窗口")
        XCTAssertEqual(ManualWindowAction.moveToNextDisplay.menuTitle, "移到下一显示器")
        XCTAssertEqual(StatusBarMenuItem.appConfiguration.menuTitle, "应用配置")
        XCTAssertEqual(StatusBarMenuItem.appRules.menuTitle, "应用规则")
        XCTAssertEqual(StatusBarMenuItem.checkForUpdates.menuTitle, "检查更新…")
        XCTAssertEqual(StatusBarMenuItem.quit.menuTitle, "退出")
    }

    func testLayoutDoesNotIncludeLogViewerItem() {
        let titles = StatusBarMenuLayout.groups.flatMap { $0 }.map(\.menuTitle)

        XCTAssertFalse(titles.contains("查看日志"))
    }
}
