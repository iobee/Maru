import XCTest
@testable import Maru

final class WindowMoveGeometryTests: XCTestCase {
    func testAlmostMaximizedFrameUsesVisibleAreaWhenDockIsNotHidden() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let visibleFrame = CGRect(x: 0, y: 80, width: 1440, height: 795)

        let result = WindowManager.almostMaximizedNSRect(
            screenFrame: screenFrame,
            visibleFrame: visibleFrame,
            dockLayout: DockLayoutState(isAutohideEnabled: false, screenEdge: .bottom),
            scaleFactor: 0.92
        )

        XCTAssertEqual(result.origin.x, 57.6, accuracy: 0.001)
        XCTAssertEqual(result.origin.y, 111.8, accuracy: 0.001)
        XCTAssertEqual(result.width, 1324.8, accuracy: 0.001)
        XCTAssertEqual(result.height, 731.4, accuracy: 0.001)
    }

    func testCenteredOriginUsesVisibleAreaWhenDockIsNotHidden() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let visibleFrame = CGRect(x: 0, y: 80, width: 1440, height: 795)

        let result = WindowManager.centeredNSOrigin(
            windowSize: CGSize(width: 500, height: 300),
            screenFrame: screenFrame,
            visibleFrame: visibleFrame,
            dockLayout: DockLayoutState(isAutohideEnabled: false, screenEdge: .bottom),
            stageManagerSideMarginRatio: 0
        )

        XCTAssertEqual(result.x, 470, accuracy: 0.001)
        XCTAssertEqual(result.y, 327.5, accuracy: 0.001)
    }

    func testCenteredOriginAccountsForLeftDockVisibleArea() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let visibleFrame = CGRect(x: 96, y: 0, width: 1344, height: 875)

        let result = WindowManager.centeredNSOrigin(
            windowSize: CGSize(width: 500, height: 300),
            screenFrame: screenFrame,
            visibleFrame: visibleFrame,
            dockLayout: DockLayoutState(isAutohideEnabled: false, screenEdge: .left),
            stageManagerSideMarginRatio: 0
        )

        XCTAssertEqual(result.x, 518, accuracy: 0.001)
        XCTAssertEqual(result.y, 287.5, accuracy: 0.001)
    }

    func testCenteredOriginIgnoresStageManagerSideInsetWhenDockIsBottom() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let visibleFrame = CGRect(x: 96, y: 80, width: 1344, height: 795)

        let result = WindowManager.centeredNSOrigin(
            windowSize: CGSize(width: 500, height: 300),
            screenFrame: screenFrame,
            visibleFrame: visibleFrame,
            dockLayout: DockLayoutState(isAutohideEnabled: false, screenEdge: .bottom),
            stageManagerSideMarginRatio: 0
        )

        XCTAssertEqual(result.x, 470, accuracy: 0.001)
        XCTAssertEqual(result.y, 327.5, accuracy: 0.001)
    }

    func testAlmostMaximizedFrameIgnoresStageManagerSideInsetWhenDockIsBottom() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let visibleFrame = CGRect(x: 96, y: 80, width: 1344, height: 795)

        let result = WindowManager.almostMaximizedNSRect(
            screenFrame: screenFrame,
            visibleFrame: visibleFrame,
            dockLayout: DockLayoutState(isAutohideEnabled: false, screenEdge: .bottom),
            scaleFactor: 0.92
        )

        XCTAssertEqual(result.origin.x, 57.6, accuracy: 0.001)
        XCTAssertEqual(result.origin.y, 111.8, accuracy: 0.001)
        XCTAssertEqual(result.width, 1324.8, accuracy: 0.001)
        XCTAssertEqual(result.height, 731.4, accuracy: 0.001)
    }

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

    func testDisplayMoveAcceptsSystemAdjustedGeometryWhenCenterReachedTargetScreen() {
        let targetScreen = CGRect(x: -200, y: -1080, width: 1920, height: 1080)
        let systemAdjustedWindow = CGRect(x: -69, y: -996, width: 1657, height: 943)

        XCTAssertTrue(WindowManager.windowFrame(systemAdjustedWindow, belongsTo: targetScreen))
    }

    func testDisplayMoveRejectsWindowThatRemainedOnSourceScreen() {
        let targetScreen = CGRect(x: -200, y: -1080, width: 1920, height: 1080)
        let sourceWindow = CGRect(x: 60, y: 71, width: 1391, height: 873)

        XCTAssertFalse(WindowManager.windowFrame(sourceWindow, belongsTo: targetScreen))
    }
}
