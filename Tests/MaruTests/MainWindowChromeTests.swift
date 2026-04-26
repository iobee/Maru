import XCTest
import AppKit
@testable import Maru

final class MainWindowChromeTests: XCTestCase {
    func testApplyProductStandardRestoresTitlebarIntegration() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = true
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        window.level = .floating

        MainWindowChrome.applyProductStandard(to: window)

        XCTAssertFalse(window.isOpaque)
        XCTAssertTrue(window.titlebarAppearsTransparent)
        XCTAssertEqual(window.titleVisibility, .hidden)
        XCTAssertEqual(window.level, .normal)
        XCTAssertTrue(window.styleMask.contains(.fullSizeContentView))
        XCTAssertTrue(window.collectionBehavior.contains(.managed))
        XCTAssertTrue(window.collectionBehavior.contains(.participatesInCycle))
        XCTAssertTrue(window.collectionBehavior.contains(.primary))
        XCTAssertFalse(window.collectionBehavior.contains(.fullScreenPrimary))
    }
}
