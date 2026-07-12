import XCTest
@testable import Maru

final class DockSettingsTests: XCTestCase {
    func testReloadReflectsSystemAutohideState() {
        let controller = DockSystemControllerStub(readEnabledResult: .success(true))
        let settings = DockSettings(controller: controller)

        settings.reload()

        XCTAssertTrue(settings.isAutohideEnabled)
        XCTAssertEqual(controller.readCallCount, 2)
    }

    func testSetAutohideEnabledWritesUpdatedValueAndRefreshesPublishedState() {
        let controller = DockSystemControllerStub(readEnabledResult: .success(false))
        let settings = DockSettings(controller: controller)

        settings.setAutohideEnabled(true)

        XCTAssertEqual(controller.writeCalls, [true])
        XCTAssertTrue(settings.isAutohideEnabled)
    }

    func testSetAutohideEnabledKeepsWriteErrorVisibleWhenRefreshSucceeds() {
        let controller = DockSystemControllerStub(
            readEnabledResult: .success(false),
            writeError: DockSettingsError.commandFailed("not allowed")
        )
        let settings = DockSettings(controller: controller)

        settings.setAutohideEnabled(true)

        XCTAssertEqual(controller.writeCalls, [true])
        XCTAssertFalse(settings.isAutohideEnabled)
        XCTAssertEqual(settings.lastErrorMessage, "Dock 系统设置操作失败: not allowed")
    }

    func testAppleScriptControllerReadsBooleanAutohideValue() throws {
        let runner = DockAutomationRunnerStub(results: [.success(NSAppleEventDescriptor(boolean: true))])
        let controller = AppleScriptDockController(runner: runner)

        let isEnabled = try controller.readAutohideEnabled()

        XCTAssertTrue(isEnabled)
        XCTAssertEqual(
            runner.scripts,
            ["tell application \"System Events\" to get autohide of dock preferences"]
        )
    }

    func testAppleScriptControllerWritesAutohideValue() throws {
        let runner = DockAutomationRunnerStub(results: [.success(NSAppleEventDescriptor(boolean: true))])
        let controller = AppleScriptDockController(runner: runner)

        try controller.writeAutohideEnabled(true)

        XCTAssertEqual(
            runner.scripts,
            ["tell application \"System Events\" to set autohide of dock preferences to true"]
        )
    }

    func testDefaultsControllerReadsAutohideKeyWithoutAutomation() throws {
        let store = DockPreferencesStoreStub(values: ["autohide": true])
        let writer = DockSystemControllerStub(readEnabledResult: .success(false))
        let controller = DefaultsDockController(store: store, writer: writer)

        let isEnabled = try controller.readAutohideEnabled()

        XCTAssertTrue(isEnabled)
        XCTAssertEqual(store.lastRequestedKey, "autohide")
        XCTAssertTrue(writer.writeCalls.isEmpty)
    }

    func testDefaultsControllerReadsDockLayoutOrientationWithoutAutomation() throws {
        let store = DockPreferencesStoreStub(values: [
            "autohide": false,
            "orientation": "left"
        ])
        let writer = DockSystemControllerStub(readEnabledResult: .success(true))
        let controller = DefaultsDockController(store: store, writer: writer)

        let layout = try controller.readDockLayout()

        XCTAssertEqual(layout, DockLayoutState(isAutohideEnabled: false, screenEdge: .left))
        XCTAssertEqual(store.requestedKeys, ["autohide", "orientation"])
        XCTAssertTrue(writer.writeCalls.isEmpty)
    }
}

private final class DockSystemControllerStub: DockSystemControlling {
    var readEnabledResult: Result<Bool, Error>
    var writeError: Error?
    private(set) var writeCalls: [Bool] = []
    private(set) var readCallCount = 0

    init(readEnabledResult: Result<Bool, Error>, writeError: Error? = nil) {
        self.readEnabledResult = readEnabledResult
        self.writeError = writeError
    }

    func readAutohideEnabled() throws -> Bool {
        readCallCount += 1
        return try readEnabledResult.get()
    }

    func writeAutohideEnabled(_ isEnabled: Bool) throws {
        writeCalls.append(isEnabled)
        if let writeError {
            throw writeError
        }
        readEnabledResult = .success(isEnabled)
    }
}

private final class DockAutomationRunnerStub: DockAutomationRunning {
    private var results: [Result<NSAppleEventDescriptor, Error>]
    private(set) var scripts: [String] = []

    init(results: [Result<NSAppleEventDescriptor, Error>]) {
        self.results = results
    }

    func execute(_ script: String) throws -> NSAppleEventDescriptor {
        scripts.append(script)
        return try results.removeFirst().get()
    }
}

private final class DockPreferencesStoreStub: DockPreferencesStoring {
    var values: [String: Any]
    private(set) var lastRequestedKey: String?
    private(set) var requestedKeys: [String] = []

    init(values: [String: Any?]) {
        self.values = values.compactMapValues { $0 }
    }

    func object(forKey defaultName: String) -> Any? {
        lastRequestedKey = defaultName
        requestedKeys.append(defaultName)
        return values[defaultName]
    }

    func synchronize() -> Bool {
        true
    }
}
