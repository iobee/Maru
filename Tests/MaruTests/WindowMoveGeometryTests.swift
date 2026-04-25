import XCTest
@testable import Maru

final class WindowMoveGeometryTests: XCTestCase {
    func testMoveOnlyFramePreservesSizeAndRelativeCenterOnTargetScreen() {
        let currentScreen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let targetScreen = CGRect(x: 1000, y: 0, width: 2000, height: 1000)
        let windowFrame = CGRect(x: 200, y: 120, width: 200, height: 160)

        let result = WindowManager.moveOnlyTargetFrame(
            for: windowFrame,
            from: currentScreen,
            to: targetScreen
        )

        XCTAssertEqual(result.size, windowFrame.size)
        XCTAssertEqual(result.origin.x, 1500)
        XCTAssertEqual(result.origin.y, 170)
    }

    func testMoveOnlyFrameClampsToTargetScreenBounds() {
        let currentScreen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let targetScreen = CGRect(x: 1000, y: 0, width: 500, height: 400)
        let windowFrame = CGRect(x: 850, y: 700, width: 300, height: 260)

        let result = WindowManager.moveOnlyTargetFrame(
            for: windowFrame,
            from: currentScreen,
            to: targetScreen
        )

        XCTAssertEqual(result.size, windowFrame.size)
        XCTAssertGreaterThanOrEqual(result.minX, targetScreen.minX)
        XCTAssertGreaterThanOrEqual(result.minY, targetScreen.minY)
        XCTAssertLessThanOrEqual(result.maxX, targetScreen.maxX)
        XCTAssertLessThanOrEqual(result.maxY, targetScreen.maxY)
    }
}
