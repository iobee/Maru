import Foundation
import Combine

protocol StageManagerSystemControlling {
    func readEnabled() throws -> Bool
    func writeEnabled(_ isEnabled: Bool) throws
}

struct DefaultsStageManagerController: StageManagerSystemControlling {
    private static let stageManagerDomain = "com.apple.WindowManager"
    private static let globallyEnabledKey = "GloballyEnabled"

    private let store: StageManagerPreferencesStoring

    init(store: StageManagerPreferencesStoring? = nil) {
        if let store {
            self.store = store
        } else if let userDefaults = UserDefaults(suiteName: Self.stageManagerDomain) {
            self.store = userDefaults
        } else {
            self.store = StageManagerNullStore()
        }
    }

    func readEnabled() throws -> Bool {
        guard let rawValue = store.object(forKey: Self.globallyEnabledKey) else {
            return false
        }

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
                throw StageManagerSettingsError.unexpectedReadValue(stringValue)
            }
        default:
            throw StageManagerSettingsError.unexpectedReadValue(String(describing: rawValue))
        }
    }

    func writeEnabled(_ isEnabled: Bool) throws {
        store.set(isEnabled, forKey: Self.globallyEnabledKey)
        if !store.synchronize() {
            throw StageManagerSettingsError.commandFailed("synchronize returned false")
        }
    }
}

protocol StageManagerPreferencesStoring {
    func object(forKey defaultName: String) -> Any?
    func set(_ value: Any?, forKey defaultName: String)
    func synchronize() -> Bool
}

extension UserDefaults: StageManagerPreferencesStoring {}

private final class StageManagerNullStore: StageManagerPreferencesStoring {
    func object(forKey defaultName: String) -> Any? {
        nil
    }

    func set(_ value: Any?, forKey defaultName: String) {}

    func synchronize() -> Bool {
        false
    }
}

enum StageManagerSettingsError: LocalizedError {
    case commandFailed(String)
    case unexpectedReadValue(String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            return "写入 Stage Manager 系统设置失败: \(message)"
        case .unexpectedReadValue(let value):
            return "无法解析 Stage Manager 当前状态: \(value)"
        }
    }
}

final class StageManagerSettings: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var lastErrorMessage: String?

    private let controller: StageManagerSystemControlling

    init(controller: StageManagerSystemControlling = DefaultsStageManagerController()) {
        self.controller = controller
        reload()
    }

    func reload() {
        do {
            isEnabled = try controller.readEnabled()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
            AppLogger.shared.log("读取 Stage Manager 状态失败: \(error.localizedDescription)", level: .warning)
        }
    }

    func setEnabled(_ isEnabled: Bool) {
        do {
            try controller.writeEnabled(isEnabled)
            self.isEnabled = isEnabled
            lastErrorMessage = nil
            AppLogger.shared.log("Stage Manager 已\(isEnabled ? "开启" : "关闭")", level: .info)
        } catch {
            lastErrorMessage = error.localizedDescription
            AppLogger.shared.log("切换 Stage Manager 失败: \(error.localizedDescription)", level: .error)
            reload()
        }
    }
}
