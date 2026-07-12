import XCTest
@testable import Maru

final class AppActivityStoreTests: XCTestCase {
    func testStorePersistsEventsAcrossInstances() {
        let storageURL = temporaryStorageURL()
        let event = makeEvent(
            timestamp: Date(timeIntervalSince1970: 100),
            appName: "Safari",
            bundleIdentifier: "com.apple.Safari"
        )

        let writer = AppActivityStore(storageURL: storageURL)
        writer.record(event)

        let reader = AppActivityStore(storageURL: storageURL)

        XCTAssertEqual(reader.events, [event])
    }

    func testStoreKeepsOnlyNewestEventsWithinLimit() {
        let storageURL = temporaryStorageURL()
        let store = AppActivityStore(storageURL: storageURL, maximumEventCount: 2)
        let first = makeEvent(timestamp: Date(timeIntervalSince1970: 1), appName: "One", bundleIdentifier: "one")
        let second = makeEvent(timestamp: Date(timeIntervalSince1970: 2), appName: "Two", bundleIdentifier: "two")
        let third = makeEvent(timestamp: Date(timeIntervalSince1970: 3), appName: "Three", bundleIdentifier: "three")

        store.record(first)
        store.record(second)
        store.record(third)

        XCTAssertEqual(store.events, [second, third])
        XCTAssertEqual(AppActivityStore(storageURL: storageURL, maximumEventCount: 2).events, [second, third])
    }

    private func makeEvent(timestamp: Date, appName: String, bundleIdentifier: String) -> AppActivityEvent {
        AppActivityEvent(
            timestamp: timestamp,
            appName: appName,
            bundleIdentifier: bundleIdentifier,
            kind: .action,
            title: "执行呼吸窗口",
            detail: "按应用规则处理当前窗口。"
        )
    }

    private func temporaryStorageURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("Maru-AppActivity-\(UUID().uuidString)")
            .appendingPathComponent("app_activity.json")
    }
}
