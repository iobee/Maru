import XCTest
@testable import Maru

final class CurrentAppRuleMenuStateTests: XCTestCase {
    func testTitleUsesCurrentApplicationName() {
        let target = CurrentAppRuleTarget(
            appName: "Codex",
            bundleId: "com.openai.codex",
            processIdentifier: 123
        )

        let state = CurrentAppRuleMenuState(target: target, appRules: [])

        XCTAssertEqual(state.title, "配置当前应用：Codex")
    }

    func testDisabledTitleWhenCurrentApplicationIsUnavailable() {
        let state = CurrentAppRuleMenuState(target: nil, appRules: [])

        XCTAssertEqual(state.title, "当前应用不可用")
        XCTAssertNil(state.selectedRule)
    }

    func testUnsavedApplicationDefaultsToAlmostMaximizeWithoutMutatingConfig() {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Maru-CurrentAppRuleMenuState-\(UUID().uuidString)", isDirectory: true)
        let config = AppConfig(storageDirectoryURL: temporaryDirectory)
        let target = CurrentAppRuleTarget(
            appName: "Codex",
            bundleId: "com.openai.codex",
            processIdentifier: 123
        )

        let state = CurrentAppRuleMenuState(target: target, appRules: config.appRules)

        XCTAssertEqual(state.selectedRule, .almostMaximize)
        XCTAssertFalse(config.appRules.contains { $0.bundleId == "com.openai.codex" })
    }

    func testRuleOptionsUseQuickConfigurationOrderAndTitles() {
        let target = CurrentAppRuleTarget(
            appName: "Codex",
            bundleId: "com.openai.codex",
            processIdentifier: 123
        )

        let state = CurrentAppRuleMenuState(target: target, appRules: [])

        XCTAssertEqual(state.ruleOptions, [.almostMaximize, .center, .ignore])
        XCTAssertEqual(
            state.ruleOptions.map(\.currentAppRuleMenuTitle),
            ["呼吸窗口", "居中窗口", "忽略此应用"]
        )
    }

    func testSavedRuleDrivesSelectedRule() {
        let target = CurrentAppRuleTarget(
            appName: "Codex",
            bundleId: "com.openai.codex",
            processIdentifier: 123
        )
        let rules = [
            AppRule(
                bundleId: "com.openai.codex",
                appName: "Codex",
                rule: .ignore,
                lastUsed: Date(timeIntervalSince1970: 100),
                useCount: 3
            )
        ]

        let state = CurrentAppRuleMenuState(target: target, appRules: rules)

        XCTAssertEqual(state.selectedRule, .ignore)
    }
}
