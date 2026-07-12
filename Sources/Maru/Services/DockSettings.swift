import Foundation
import Combine

enum DockScreenEdge: Equatable {
    case left
    case bottom
    case right
    case unknown

    init(defaultsValue: Any?) {
        guard let rawValue = defaultsValue as? String else {
            self = .bottom
            return
        }

        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "left":
            self = .left
        case "bottom":
            self = .bottom
        case "right":
            self = .right
        default:
            self = .unknown
        }
    }
}

struct DockLayoutState: Equatable {
    let isAutohideEnabled: Bool
    let screenEdge: DockScreenEdge

    static let fallback = DockLayoutState(isAutohideEnabled: false, screenEdge: .unknown)
}

protocol DockLayoutReading {
    func readDockLayout() throws -> DockLayoutState
}

protocol DockSystemControlling {
    func readAutohideEnabled() throws -> Bool
    func writeAutohideEnabled(_ isEnabled: Bool) throws
}

struct DefaultsDockController: DockSystemControlling, DockLayoutReading {
    private static let dockDomain = "com.apple.dock"
    private static let autohideKey = "autohide"
    private static let orientationKey = "orientation"

    private let store: DockPreferencesStoring
    private let writer: DockSystemControlling

    init(store: DockPreferencesStoring? = nil, writer: DockSystemControlling? = nil) {
        if let store {
            self.store = store
        } else if let userDefaults = UserDefaults(suiteName: Self.dockDomain) {
            self.store = userDefaults
        } else {
            self.store = DockNullStore()
        }

        self.writer = writer ?? AppleScriptDockController()
    }

    func readAutohideEnabled() throws -> Bool {
        _ = store.synchronize()

        guard let rawValue = store.object(forKey: Self.autohideKey) else {
            return false
        }

        return try DockSettingsValueParser.boolValue(from: rawValue)
    }

    func readDockLayout() throws -> DockLayoutState {
        let isAutohideEnabled = try readAutohideEnabled()
        let screenEdge = DockScreenEdge(defaultsValue: store.object(forKey: Self.orientationKey))

        return DockLayoutState(
            isAutohideEnabled: isAutohideEnabled,
            screenEdge: screenEdge
        )
    }

    func writeAutohideEnabled(_ isEnabled: Bool) throws {
        try writer.writeAutohideEnabled(isEnabled)
    }
}

protocol DockPreferencesStoring {
    func object(forKey defaultName: String) -> Any?
    func synchronize() -> Bool
}

extension UserDefaults: DockPreferencesStoring {}

private final class DockNullStore: DockPreferencesStoring {
    func object(forKey defaultName: String) -> Any? {
        nil
    }

    func synchronize() -> Bool {
        false
    }
}

struct AppleScriptDockController: DockSystemControlling {
    private static let readAutohideScript = "tell application \"System Events\" to get autohide of dock preferences"

    private let runner: DockAutomationRunning

    init(runner: DockAutomationRunning = NSAppleScriptDockAutomationRunner()) {
        self.runner = runner
    }

    func readAutohideEnabled() throws -> Bool {
        let descriptor = try runner.execute(Self.readAutohideScript)
        return try DockSettingsValueParser.boolValue(from: descriptor)
    }

    func writeAutohideEnabled(_ isEnabled: Bool) throws {
        let value = isEnabled ? "true" : "false"
        try runner.execute("tell application \"System Events\" to set autohide of dock preferences to \(value)")
    }
}

private enum DockSettingsValueParser {
    static func boolValue(from descriptor: NSAppleEventDescriptor) throws -> Bool {
        if descriptor.descriptorType == typeBoolean {
            return descriptor.booleanValue
        }

        if let stringValue = descriptor.stringValue {
            switch stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "1", "true", "yes":
                return true
            case "0", "false", "no":
                return false
            default:
                throw DockSettingsError.unexpectedReadValue(stringValue)
            }
        }

        throw DockSettingsError.unexpectedReadValue(String(describing: descriptor))
    }

    static func boolValue(from rawValue: Any) throws -> Bool {
        switch rawValue {
        case let boolValue as Bool:
            return boolValue
        case let numberValue as NSNumber:
            return numberValue.boolValue
        case let stringValue as String:
            switch stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "1", "true", "yes":
                return true
            case "0", "false", "no":
                return false
            default:
                throw DockSettingsError.unexpectedReadValue(stringValue)
            }
        default:
            throw DockSettingsError.unexpectedReadValue(String(describing: rawValue))
        }
    }
}

protocol DockAutomationRunning {
    @discardableResult
    func execute(_ script: String) throws -> NSAppleEventDescriptor
}

struct NSAppleScriptDockAutomationRunner: DockAutomationRunning {
    func execute(_ script: String) throws -> NSAppleEventDescriptor {
        guard let appleScript = NSAppleScript(source: script) else {
            throw DockSettingsError.commandFailed("无法创建 AppleScript")
        }

        var errorInfo: NSDictionary?
        let result = appleScript.executeAndReturnError(&errorInfo)

        if let errorInfo {
            throw DockSettingsError.commandFailed(Self.message(from: errorInfo))
        }

        return result
    }

    private static func message(from errorInfo: NSDictionary) -> String {
        if let message = errorInfo["NSAppleScriptErrorMessage"] as? String {
            return message
        }

        if let briefMessage = errorInfo["NSAppleScriptErrorBriefMessage"] as? String {
            return briefMessage
        }

        return String(describing: errorInfo)
    }
}

enum DockSettingsError: LocalizedError {
    case commandFailed(String)
    case unexpectedReadValue(String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            return "Dock 系统设置操作失败: \(message)"
        case .unexpectedReadValue(let value):
            return "无法解析 Dock 自动隐藏当前状态: \(value)"
        }
    }
}

final class DockSettings: ObservableObject {
    @Published private(set) var isAutohideEnabled = false
    @Published private(set) var lastErrorMessage: String?

    private let controller: DockSystemControlling

    init(controller: DockSystemControlling = DefaultsDockController()) {
        self.controller = controller
        reload()
    }

    func reload() {
        do {
            isAutohideEnabled = try controller.readAutohideEnabled()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
            AppLogger.shared.log("读取 Dock 自动隐藏状态失败: \(error.localizedDescription)", level: .warning)
        }
    }

    func setAutohideEnabled(_ isEnabled: Bool) {
        do {
            try controller.writeAutohideEnabled(isEnabled)
            isAutohideEnabled = isEnabled
            lastErrorMessage = nil
            AppLogger.shared.log("Dock 自动隐藏已\(isEnabled ? "开启" : "关闭")", level: .info)
        } catch {
            let writeErrorMessage = error.localizedDescription
            lastErrorMessage = writeErrorMessage
            AppLogger.shared.log("切换 Dock 自动隐藏失败: \(writeErrorMessage)", level: .error)
            refreshStateAfterWriteFailure()
        }
    }

    private func refreshStateAfterWriteFailure() {
        do {
            isAutohideEnabled = try controller.readAutohideEnabled()
        } catch {
            AppLogger.shared.log("写入失败后刷新 Dock 自动隐藏状态也失败: \(error.localizedDescription)", level: .warning)
        }
    }
}
