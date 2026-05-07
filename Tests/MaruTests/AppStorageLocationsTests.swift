import XCTest
import Foundation
@testable import Maru

final class AppStorageLocationsTests: XCTestCase {
    private let homeDirectory = URL(fileURLWithPath: "/Users/tester", isDirectory: true)
    private let applicationSupportDirectory = URL(
        fileURLWithPath: "/Users/tester/Library/Application Support",
        isDirectory: true
    )

    func testXDGConfigHomeSelectsConfigurationDirectory() {
        let locations = AppStorageLocations.resolve(
            environment: ["XDG_CONFIG_HOME": "/tmp/xdg-config"],
            homeDirectory: homeDirectory,
            applicationSupportDirectory: applicationSupportDirectory
        )

        XCTAssertEqual(locations.configurationDirectory.path, "/tmp/xdg-config/Maru")
    }

    func testRelativeXDGConfigHomeFallsBackToApplicationSupport() {
        let locations = AppStorageLocations.resolve(
            environment: ["XDG_CONFIG_HOME": "relative-config"],
            homeDirectory: homeDirectory,
            applicationSupportDirectory: applicationSupportDirectory
        )

        XCTAssertEqual(locations.configurationDirectory.path, "/Users/tester/Library/Application Support/Maru")
    }

    func testXDGStateHomeSelectsLogDirectory() {
        let locations = AppStorageLocations.resolve(
            environment: ["XDG_STATE_HOME": "/tmp/xdg-state"],
            homeDirectory: homeDirectory,
            applicationSupportDirectory: applicationSupportDirectory
        )

        XCTAssertEqual(locations.logDirectory.path, "/tmp/xdg-state/Maru/Logs")
    }

    func testRelativeXDGStateHomeFallsBackToApplicationSupportLogs() {
        let locations = AppStorageLocations.resolve(
            environment: ["XDG_STATE_HOME": "relative-state"],
            homeDirectory: homeDirectory,
            applicationSupportDirectory: applicationSupportDirectory
        )

        XCTAssertEqual(locations.logDirectory.path, "/Users/tester/Library/Application Support/Maru/Logs")
    }

    func testAppConfigWritesConfigurationFilesToResolvedXDGDirectory() {
        let baseURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("Maru-XDGConfig-\(UUID().uuidString)", isDirectory: true)
        let locations = AppStorageLocations.resolve(
            environment: ["XDG_CONFIG_HOME": baseURL.path],
            homeDirectory: homeDirectory,
            applicationSupportDirectory: applicationSupportDirectory
        )

        _ = AppConfig(storageLocations: locations)

        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: locations.configurationDirectory.appendingPathComponent("config.json").path
            )
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: locations.configurationDirectory.appendingPathComponent("general.json").path
            )
        )
    }
}
