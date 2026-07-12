import XCTest
@testable import Maru

final class NavigationTabTests: XCTestCase {
    func testApplicationActivityIsIndependentFromBackgroundLogs() {
        XCTAssertEqual(
            NavigationTab.allCases,
            [.home, .manualControl, .rules, .activity, .logs, .about]
        )
        XCTAssertEqual(NavigationTab.activity.title, "应用动态")
        XCTAssertEqual(NavigationTab.logs.title, "后台日志")
    }
}
