import XCTest
import Foundation
@testable import Maru

final class AppConfigShortcutTests: XCTestCase {
    private var storageDirectoryURL: URL {
        let baseURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return baseURL.appendingPathComponent("Maru-ShortcutTests-\(UUID().uuidString)", isDirectory: true)
    }

    private func makeConfig() throws -> (AppConfig, URL) {
        let directoryURL = storageDirectoryURL
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let config = AppConfig(storageDirectoryURL: directoryURL)
        return (config, directoryURL)
    }

    private func readGeneralConfig(at directoryURL: URL) throws -> [String: Any] {
        let fileURL = directoryURL.appendingPathComponent("general.json")
        let data = try Data(contentsOf: fileURL)
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        return object as? [String: Any] ?? [:]
    }

    private func writeGeneralConfig(_ payload: [String: Any], to directoryURL: URL) throws {
        let fileURL = directoryURL.appendingPathComponent("general.json")
        let data = try JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)
        try data.write(to: fileURL)
    }

    func testDefaultBindingsMapCenterAndAlmostMaximize() throws {
        let (config, _) = try makeConfig()

        XCTAssertEqual(config.manualCenterShortcut?.displayText, "Ctrl+Cmd+C")
        XCTAssertEqual(config.manualAlmostMaximizeShortcut?.displayText, "Ctrl+Cmd+M")
        XCTAssertEqual(config.manualMoveToNextDisplayShortcut?.displayText, "Ctrl+Cmd+N")
    }

    func testClearingOneBindingLeavesTheOtherIntact() throws {
        let (config, _) = try makeConfig()

        config.clearManualCenterShortcut()

        XCTAssertNil(config.manualCenterShortcut)
        XCTAssertEqual(config.manualAlmostMaximizeShortcut?.displayText, "Ctrl+Cmd+M")
        XCTAssertEqual(config.manualMoveToNextDisplayShortcut?.displayText, "Ctrl+Cmd+N")
    }

    func testClearedShortcutPersistsAcrossReload() throws {
        let (config, directoryURL) = try makeConfig()

        config.clearManualCenterShortcut()
        XCTAssertNil(config.manualCenterShortcut)
        XCTAssertEqual(config.manualAlmostMaximizeShortcut?.displayText, "Ctrl+Cmd+M")
        XCTAssertEqual(config.manualMoveToNextDisplayShortcut?.displayText, "Ctrl+Cmd+N")

        let reloadedConfig = AppConfig(storageDirectoryURL: directoryURL)

        XCTAssertNil(reloadedConfig.manualCenterShortcut)
        XCTAssertEqual(reloadedConfig.manualAlmostMaximizeShortcut?.displayText, "Ctrl+Cmd+M")
        XCTAssertEqual(reloadedConfig.manualMoveToNextDisplayShortcut?.displayText, "Ctrl+Cmd+N")
    }

    func testResettingRestoresDefaultBinding() throws {
        let (config, _) = try makeConfig()

        let customBinding = ShortcutBinding(key: "n", modifierFlags: [.command])
        XCTAssertTrue(config.updateManualCenterShortcut(customBinding))
        XCTAssertEqual(config.manualCenterShortcut, customBinding)

        config.resetManualCenterShortcut()

        XCTAssertEqual(config.manualCenterShortcut?.displayText, "Ctrl+Cmd+C")
    }

    func testLoadingLegacyGeneralConfigPreservesDefaultShortcuts() throws {
        let directoryURL = storageDirectoryURL
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try writeGeneralConfig([
            "windowScaleFactor": 0.88,
            "logLevel": "信息"
        ], to: directoryURL)

        let config = AppConfig(storageDirectoryURL: directoryURL)

        XCTAssertEqual(config.manualCenterShortcut?.displayText, "Ctrl+Cmd+C")
        XCTAssertEqual(config.manualAlmostMaximizeShortcut?.displayText, "Ctrl+Cmd+M")
        XCTAssertEqual(config.manualMoveToNextDisplayShortcut?.displayText, "Ctrl+Cmd+N")
    }

    func testMalformedShortcutPayloadFallsBackToDefaults() throws {
        let directoryURL = storageDirectoryURL
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try writeGeneralConfig([
            "windowScaleFactor": 0.88,
            "logLevel": "信息",
            "manualCenterShortcut": [
                "key": "c",
                "modifierFlagsRawValue": "invalid"
            ],
            "manualAlmostMaximizeShortcut": [
                "notKey": "m"
            ]
        ], to: directoryURL)

        let config = AppConfig(storageDirectoryURL: directoryURL)

        XCTAssertEqual(config.manualCenterShortcut?.displayText, "Ctrl+Cmd+C")
        XCTAssertEqual(config.manualAlmostMaximizeShortcut?.displayText, "Ctrl+Cmd+M")
        XCTAssertEqual(config.manualMoveToNextDisplayShortcut?.displayText, "Ctrl+Cmd+N")
    }

    func testDuplicateBindingsAreRejectedByConfigValidation() throws {
        let (config, directoryURL) = try makeConfig()
        let beforeData = try Data(contentsOf: directoryURL.appendingPathComponent("general.json"))
        let duplicateBinding = ShortcutBinding(key: "c", modifierFlags: [.control, .command])

        XCTAssertFalse(config.updateManualAlmostMaximizeShortcut(duplicateBinding))
        XCTAssertEqual(config.manualAlmostMaximizeShortcut?.displayText, "Ctrl+Cmd+M")

        let afterData = try Data(contentsOf: directoryURL.appendingPathComponent("general.json"))
        XCTAssertEqual(afterData, beforeData)

        let stored = try readGeneralConfig(at: directoryURL)
        XCTAssertEqual(stored["manualCenterShortcut"] as? [String: Any] != nil, true)
        XCTAssertEqual(stored["manualAlmostMaximizeShortcut"] as? [String: Any] != nil, true)
        XCTAssertEqual(stored["manualMoveToNextDisplayShortcut"] as? [String: Any] != nil, true)
    }

    func testThirdBindingRejectsDuplicatesAgainstExistingBindings() throws {
        let (config, directoryURL) = try makeConfig()
        let beforeData = try Data(contentsOf: directoryURL.appendingPathComponent("general.json"))
        let duplicateBinding = ShortcutBinding(key: "m", modifierFlags: [.control, .command])

        XCTAssertFalse(config.updateManualMoveToNextDisplayShortcut(duplicateBinding))
        XCTAssertEqual(config.manualMoveToNextDisplayShortcut?.displayText, "Ctrl+Cmd+N")

        let afterData = try Data(contentsOf: directoryURL.appendingPathComponent("general.json"))
        XCTAssertEqual(afterData, beforeData)
    }
}
