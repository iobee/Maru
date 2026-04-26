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
}
