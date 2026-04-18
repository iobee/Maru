import XCTest
import AppKit
@testable import HiWindowGuy

final class ShortcutBindingTests: XCTestCase {
    func testShortcutBindingRepresentsControlCommandC() {
        let binding = ShortcutBinding(key: "c", modifierFlags: [.control, .command])

        XCTAssertEqual(binding.key, "c")
        XCTAssertEqual(binding.modifierFlags, [.control, .command])
        XCTAssertEqual(binding.displayText, "Ctrl+Cmd+C")
    }

    func testManualWindowActionLabelsAreStable() {
        XCTAssertEqual(ManualWindowAction.center.label, "居中")
        XCTAssertEqual(ManualWindowAction.almostMaximize.label, "几乎最大化")
        XCTAssertEqual(ManualWindowAction.moveToNextDisplay.label, "移到下一个显示器并铺满")
    }

    func testMoveToNextDisplayDefaultShortcutIsStable() {
        XCTAssertEqual(ManualWindowAction.moveToNextDisplay.defaultShortcut.displayText, "Ctrl+Cmd+N")
    }
}
