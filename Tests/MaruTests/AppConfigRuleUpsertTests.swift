import XCTest
@testable import Maru

final class AppConfigRuleUpsertTests: XCTestCase {
    func testSetRuleCreatesMissingApplicationRuleAndPersistsIt() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Maru-AppConfigRuleUpsert-\(UUID().uuidString)", isDirectory: true)
        let config = AppConfig(storageDirectoryURL: temporaryDirectory)
        let originalRefreshID = config.refreshID

        let notification = expectation(description: "RuleUpdated notification")
        let token = NotificationCenter.default.addObserver(
            forName: Notification.Name("RuleUpdated"),
            object: nil,
            queue: nil
        ) { _ in
            notification.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        config.setRule(for: "com.openai.codex", appName: "Codex", rule: .center)

        wait(for: [notification], timeout: 1.0)
        XCTAssertNotEqual(config.refreshID, originalRefreshID)

        let rule = try XCTUnwrap(config.appRules.first { $0.bundleId == "com.openai.codex" })
        XCTAssertEqual(rule.appName, "Codex")
        XCTAssertEqual(rule.rule, .center)
        XCTAssertEqual(rule.useCount, 0)

        let persistedConfig = AppConfig(storageDirectoryURL: temporaryDirectory)
        let persistedRule = try XCTUnwrap(persistedConfig.appRules.first { $0.bundleId == "com.openai.codex" })
        XCTAssertEqual(persistedRule.rule, .center)
    }

    func testSetRuleUpdatesExistingApplicationRule() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Maru-AppConfigRuleUpdate-\(UUID().uuidString)", isDirectory: true)
        let config = AppConfig(storageDirectoryURL: temporaryDirectory)
        config.appRules.append(
            AppRule(
                bundleId: "com.openai.codex",
                appName: "Codex Beta",
                rule: .ignore,
                lastUsed: Date(timeIntervalSince1970: 100),
                useCount: 7
            )
        )

        config.setRule(for: "com.openai.codex", appName: "Codex", rule: .almostMaximize)

        let rule = try XCTUnwrap(config.appRules.first { $0.bundleId == "com.openai.codex" })
        XCTAssertEqual(rule.appName, "Codex")
        XCTAssertEqual(rule.rule, .almostMaximize)
        XCTAssertEqual(rule.useCount, 7)
        XCTAssertGreaterThan(rule.lastUsed.timeIntervalSince1970, 100)
    }
}
