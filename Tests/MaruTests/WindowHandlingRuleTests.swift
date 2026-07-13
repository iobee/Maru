import XCTest
@testable import Maru

final class WindowHandlingRuleTests: XCTestCase {
    func testUserFacingRuleNamesUseCurrentProductTerminology() {
        XCTAssertEqual(WindowHandlingRule.center.rawValue, "居中")
        XCTAssertEqual(WindowHandlingRule.almostMaximize.rawValue, "呼吸窗口")
        XCTAssertEqual(WindowHandlingRule.ignore.rawValue, "忽略")
    }

    func testLegacyCustomRuleDecodesAsAlmostMaximize() throws {
        let data = #""自定义""#.data(using: .utf8)!

        let rule = try JSONDecoder().decode(WindowHandlingRule.self, from: data)

        XCTAssertEqual(rule, .almostMaximize)
    }

    func testUnknownRuleDecodesAsAlmostMaximize() throws {
        let data = #""未知规则""#.data(using: .utf8)!

        let rule = try JSONDecoder().decode(WindowHandlingRule.self, from: data)

        XCTAssertEqual(rule, .almostMaximize)
    }
}
