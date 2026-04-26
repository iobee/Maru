import XCTest
@testable import Maru

final class AccessibilityPermissionAlertStateTests: XCTestCase {
    func testReservePermissionRequestOnlyAllowsFirstSystemPrompt() {
        var state = AccessibilityPermissionFlowState()

        XCTAssertTrue(state.reservePermissionRequest())
        XCTAssertFalse(state.reservePermissionRequest())
    }

    func testReservePermissionGrantHandlingOnlyAllowsFirstPostGrantAction() {
        var state = AccessibilityPermissionFlowState()

        XCTAssertTrue(state.reservePermissionGrantHandling())
        XCTAssertFalse(state.reservePermissionGrantHandling())
    }

    func testPermissionRequestAndGrantHandlingReservationsAreIndependent() {
        var state = AccessibilityPermissionFlowState()

        XCTAssertTrue(state.reservePermissionRequest())
        XCTAssertTrue(state.reservePermissionGrantHandling())
        XCTAssertFalse(state.reservePermissionRequest())
        XCTAssertFalse(state.reservePermissionGrantHandling())
    }

    func testGrantedAlertCopyConfirmsMonitoringStartedWithoutRestart() {
        XCTAssertEqual(AccessibilityPermissionGrantedAlertContent.title, "辅助功能权限已开启")
        XCTAssertEqual(AccessibilityPermissionGrantedAlertContent.message, "Maru 已开始管理窗口。")
        XCTAssertEqual(AccessibilityPermissionGrantedAlertContent.confirmButtonTitle, "知道了")
    }
}
