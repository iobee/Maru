import XCTest
@testable import Maru

final class StageManagerSettingsTests: XCTestCase {
    func testReloadReflectsSystemEnabledState() {
        let controller = StageManagerSystemControllerStub(readEnabledResult: .success(true))
        let settings = StageManagerSettings(controller: controller)

        settings.reload()

        XCTAssertTrue(settings.isEnabled)
        XCTAssertEqual(controller.readCallCount, 2)
    }

    func testSetEnabledWritesUpdatedValueAndRefreshesPublishedState() {
        let controller = StageManagerSystemControllerStub(readEnabledResult: .success(false))
        let settings = StageManagerSettings(controller: controller)

        settings.setEnabled(true)

        XCTAssertEqual(controller.writeCalls, [true])
        XCTAssertTrue(settings.isEnabled)
    }

    func testSetEnabledKeepsWriteErrorVisibleWhenRefreshSucceeds() {
        let controller = StageManagerSystemControllerStub(
            readEnabledResult: .success(false),
            writeError: StageManagerSettingsError.commandFailed("not allowed")
        )
        let settings = StageManagerSettings(controller: controller)

        settings.setEnabled(true)

        XCTAssertEqual(controller.writeCalls, [true])
        XCTAssertFalse(settings.isEnabled)
        XCTAssertEqual(settings.lastErrorMessage, "写入 Stage Manager 系统设置失败: not allowed")
    }

    func testDefaultsControllerReadsGloballyEnabledKey() throws {
        let store = PreferencesStoreStub(objectValue: true)
        let controller = DefaultsStageManagerController(store: store)

        let isEnabled = try controller.readEnabled()

        XCTAssertTrue(isEnabled)
        XCTAssertEqual(store.lastRequestedKey, "GloballyEnabled")
    }

    func testDefaultsControllerWritesBoolValue() throws {
        let store = PreferencesStoreStub(objectValue: false)
        let controller = DefaultsStageManagerController(store: store)

        try controller.writeEnabled(false)

        XCTAssertEqual(store.lastWrittenKey, "GloballyEnabled")
        XCTAssertEqual(store.lastWrittenValue as? Bool, false)
    }
}

private final class StageManagerSystemControllerStub: StageManagerSystemControlling {
    var readEnabledResult: Result<Bool, Error>
    var writeError: Error?
    private(set) var writeCalls: [Bool] = []
    private(set) var readCallCount = 0

    init(readEnabledResult: Result<Bool, Error>, writeError: Error? = nil) {
        self.readEnabledResult = readEnabledResult
        self.writeError = writeError
    }

    func readEnabled() throws -> Bool {
        readCallCount += 1
        return try readEnabledResult.get()
    }

    func writeEnabled(_ isEnabled: Bool) throws {
        writeCalls.append(isEnabled)
        if let writeError {
            throw writeError
        }
        readEnabledResult = .success(isEnabled)
    }
}

private final class PreferencesStoreStub: StageManagerPreferencesStoring {
    var objectValue: Any?
    private(set) var lastRequestedKey: String?
    private(set) var lastWrittenKey: String?
    private(set) var lastWrittenValue: Any?

    init(objectValue: Any?) {
        self.objectValue = objectValue
    }

    func object(forKey defaultName: String) -> Any? {
        lastRequestedKey = defaultName
        return objectValue
    }

    func set(_ value: Any?, forKey defaultName: String) {
        lastWrittenKey = defaultName
        lastWrittenValue = value
        objectValue = value
    }

    func synchronize() -> Bool {
        true
    }
}
