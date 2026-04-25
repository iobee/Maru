import XCTest
@testable import Maru

final class RuleConfigStateTests: XCTestCase {
    func testSearchMatchesAppNameAndBundleIdentifierBeforeSorting() {
        let olderDate = Date(timeIntervalSince1970: 100)
        let newerDate = Date(timeIntervalSince1970: 200)
        let rules: [AppRule] = [
            AppRule(bundleId: "com.apple.MobileSMS", appName: "Messages", rule: .center, lastUsed: olderDate, useCount: 4),
            AppRule(bundleId: "org.telegram.desktop", appName: "Telegram", rule: .center, lastUsed: newerDate, useCount: 2),
            AppRule(bundleId: "com.tencent.xinWeChat", appName: "WeChat", rule: .center, lastUsed: olderDate, useCount: 8)
        ]

        XCTAssertEqual(
            RuleConfigState.visibleRules(from: rules, searchText: "message", sortOption: .lastUsed).map(\.bundleId),
            ["com.apple.MobileSMS"]
        )

        XCTAssertEqual(
            RuleConfigState.visibleRules(from: rules, searchText: "TELEGRAM", sortOption: .lastUsed).map(\.bundleId),
            ["org.telegram.desktop"]
        )

        XCTAssertEqual(
            RuleConfigState.visibleRules(from: rules, searchText: "com.", sortOption: .useCount).map(\.bundleId),
            ["com.tencent.xinWeChat", "com.apple.MobileSMS"]
        )
    }

    func testBlankSearchReturnsAllRulesSortedBySelectedOption() {
        let oldestDate = Date(timeIntervalSince1970: 100)
        let middleDate = Date(timeIntervalSince1970: 200)
        let newestDate = Date(timeIntervalSince1970: 300)
        let rules: [AppRule] = [
            AppRule(bundleId: "com.example.beta", appName: "Beta", rule: .center, lastUsed: middleDate, useCount: 2),
            AppRule(bundleId: "com.example.alpha", appName: "Alpha", rule: .center, lastUsed: oldestDate, useCount: 10),
            AppRule(bundleId: "com.example.gamma", appName: "Gamma", rule: .center, lastUsed: newestDate, useCount: 1)
        ]

        XCTAssertEqual(
            RuleConfigState.visibleRules(from: rules, searchText: "   ", sortOption: .name).map(\.appName),
            ["Alpha", "Beta", "Gamma"]
        )
    }

    func testOpeningSearchRequestsApplicationActivationAndFocus() {
        let transition = RuleConfigState.searchTransition(isActive: false, searchText: "")

        XCTAssertTrue(transition.isSearchActive)
        XCTAssertTrue(transition.shouldActivateApplication)
        XCTAssertTrue(transition.shouldFocusSearchField)
        XCTAssertEqual(transition.searchText, "")
    }

    func testClosingSearchClearsTextWithoutActivationRequest() {
        let transition = RuleConfigState.searchTransition(isActive: true, searchText: "WeChat")

        XCTAssertFalse(transition.isSearchActive)
        XCTAssertFalse(transition.shouldActivateApplication)
        XCTAssertFalse(transition.shouldFocusSearchField)
        XCTAssertEqual(transition.searchText, "")
    }
}
