import AppKit
import XCTest
@testable import Maru

final class MaruApplicationActivationTests: XCTestCase {
    func testLaunchPolicyAllowsKeyWindowInputWithoutDockIcon() {
        XCTAssertEqual(MaruApplicationActivation.launchPolicy, .accessory)
    }
}
