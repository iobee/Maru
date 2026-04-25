import Foundation
import Combine
import AppKit

// 窗口处理规则枚举
enum WindowHandlingRule: String, Codable, CaseIterable, Identifiable {
    case center = "居中"
    case almostMaximize = "呼吸窗口"
    case ignore = "忽略"
    case custom = "自定义"

    var id: String { self.rawValue }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "居中": self = .center
        case "呼吸窗口", "几乎最大化": self = .almostMaximize
        case "忽略": self = .ignore
        case "自定义": self = .custom
        default: self = .almostMaximize
        }
    }
}

// 应用规则结构体
struct AppRule: Codable, Identifiable, Equatable {
    var id: String { bundleId }
    let bundleId: String
    let appName: String
    var rule: WindowHandlingRule
    var lastUsed: Date
    var useCount: Int
    
    static func == (lhs: AppRule, rhs: AppRule) -> Bool {
        return lhs.bundleId == rhs.bundleId
    }
}

class AppConfig: ObservableObject {
    // 发布的应用规则列表
    @Published var appRules: [AppRule] = []
    
    // 用于手动触发视图刷新的 ID
    @Published var refreshID = UUID()
    
    // 日志级别
    @Published var logLevel: LogLevel = .info

    // 手动窗口快捷键
    @Published private(set) var manualCenterShortcut: ShortcutBinding? = ManualWindowAction.center.defaultShortcut
    @Published private(set) var manualAlmostMaximizeShortcut: ShortcutBinding? = ManualWindowAction.almostMaximize.defaultShortcut
    @Published private(set) var manualMoveToNextDisplayShortcut: ShortcutBinding? = ManualWindowAction.moveToNextDisplay.defaultShortcut
    
    // 窗口缩放比例 (0.0-1.0)，控制几乎最大化时窗口的大小
    @Published var windowScaleFactor: Double = 0.92 {
        didSet {
            // 当值变化时保存配置
            if !isLoadingGeneralConfig {
                saveGeneralConfig()
            }
        }
    }
    
    // 配置文件路径
    private let configFilePath: URL
    private let generalConfigFilePath: URL
    private var isLoadingGeneralConfig = false
    
    // 单例实例
    static let shared = AppConfig()
    
    init(storageDirectoryURL: URL? = nil) {
        // 获取应用支持目录
        let appDir: URL
        if let storageDirectoryURL {
            appDir = storageDirectoryURL
        } else {
            let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            appDir = appSupportDir.appendingPathComponent("Maru")
        }
        
        // 创建应用目录（如果不存在）
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        
        // 设置配置文件路径
        configFilePath = appDir.appendingPathComponent("config.json")
        generalConfigFilePath = appDir.appendingPathComponent("general.json")
        
        // 加载配置
        loadConfig()
        loadGeneralConfig()
        
        // 设置默认规则（如果尚未设置）
        setupDefaultRules()

        // 确保一般配置文件包含当前默认值和快捷键字段
        saveGeneralConfig()
    }
    
    // 保存一般配置
    func saveGeneralConfig() {
        do {
            // 创建配置数据结构
            let configData: [String: Any] = [
                "windowScaleFactor": windowScaleFactor,
                "logLevel": logLevel.rawValue,
                "manualCenterShortcut": manualCenterShortcut?.asJSONObject() ?? NSNull(),
                "manualAlmostMaximizeShortcut": manualAlmostMaximizeShortcut?.asJSONObject() ?? NSNull(),
                "manualMoveToNextDisplayShortcut": manualMoveToNextDisplayShortcut?.asJSONObject() ?? NSNull()
            ]
            
            // 转换为JSON
            let data = try JSONSerialization.data(withJSONObject: configData, options: .prettyPrinted)
            try data.write(to: generalConfigFilePath)
            AppLogger.shared.log("一般配置已保存", level: .debug)
        } catch {
            AppLogger.shared.log("保存一般配置失败: \(error.localizedDescription)", level: .error)
        }
    }
    
    // 加载一般配置
    private func loadGeneralConfig() {
        do {
            if FileManager.default.fileExists(atPath: generalConfigFilePath.path) {
                let data = try Data(contentsOf: generalConfigFilePath)
                if let configData = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    isLoadingGeneralConfig = true
                    defer { isLoadingGeneralConfig = false }

                    // 加载窗口缩放比例
                    if let scaleFactor = configData["windowScaleFactor"] as? Double {
                        windowScaleFactor = scaleFactor
                    }
                    
                    // 加载日志级别
                    if let rawLogLevel = configData["logLevel"] as? String,
                       let level = LogLevel(rawValue: rawLogLevel) {
                        logLevel = level
                    }

                    let loadedCenterShortcut = Self.loadManualShortcut(
                        from: configData["manualCenterShortcut"],
                        defaultShortcut: ManualWindowAction.center.defaultShortcut
                    )
                    let loadedAlmostMaximizeShortcut = Self.loadManualShortcut(
                        from: configData["manualAlmostMaximizeShortcut"],
                        defaultShortcut: ManualWindowAction.almostMaximize.defaultShortcut
                    )
                    let loadedMoveToNextDisplayShortcut = Self.loadManualShortcut(
                        from: configData["manualMoveToNextDisplayShortcut"],
                        defaultShortcut: ManualWindowAction.moveToNextDisplay.defaultShortcut
                    )
                    let normalizedShortcuts = Self.normalizedManualShortcuts(
                        center: loadedCenterShortcut,
                        almostMaximize: loadedAlmostMaximizeShortcut,
                        moveToNextDisplay: loadedMoveToNextDisplayShortcut
                    )
                    manualCenterShortcut = normalizedShortcuts.center
                    manualAlmostMaximizeShortcut = normalizedShortcuts.almostMaximize
                    manualMoveToNextDisplayShortcut = normalizedShortcuts.moveToNextDisplay
                    
                    AppLogger.shared.log("一般配置已加载", level: .debug)
                }
            }
        } catch {
            AppLogger.shared.log("加载一般配置失败: \(error.localizedDescription)", level: .error)
        }
    }

    private static func shortcutBinding(from value: Any?) -> ShortcutBinding? {
        guard let object = value as? [String: Any] else {
            return nil
        }
        return ShortcutBinding(jsonObject: object)
    }

    private static func loadManualShortcut(from value: Any?, defaultShortcut: ShortcutBinding) -> ShortcutBinding? {
        guard let value else {
            return defaultShortcut
        }

        guard !(value is NSNull) else {
            return nil
        }

        guard let shortcut = shortcutBinding(from: value), supportsManualShortcut(shortcut) else {
            return defaultShortcut
        }

        return shortcut
    }

    private static let supportedManualShortcutKeys: Set<String> = [
        "a", "s", "d", "f", "h", "g", "z", "x", "c", "v", "b",
        "q", "w", "e", "r", "y", "t",
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
        "=", "-", "]", "[", "o", "u", "i", "p", "l", "j", "'",
        "k", ";", "\\", ",", "/", "n", "m", ".", "`", " "
    ]

    static func supportsManualShortcut(_ binding: ShortcutBinding?) -> Bool {
        guard let binding else {
            return true
        }

        return supportedManualShortcutKeys.contains(binding.key)
    }

    private static func normalizedManualShortcuts(
        center: ShortcutBinding?,
        almostMaximize: ShortcutBinding?,
        moveToNextDisplay: ShortcutBinding?
    ) -> (center: ShortcutBinding?, almostMaximize: ShortcutBinding?, moveToNextDisplay: ShortcutBinding?) {
        let normalizedCenter = center
        var normalizedAlmostMaximize = almostMaximize
        var normalizedMoveToNextDisplay = moveToNextDisplay

        if let centerBinding = normalizedCenter,
           let almostMaximizeBinding = normalizedAlmostMaximize,
           centerBinding == almostMaximizeBinding {
            AppLogger.shared.log("加载的快捷键存在重复，已保留居中快捷键并清除呼吸窗口快捷键", level: .warning)
            normalizedAlmostMaximize = nil
        }

        if let centerBinding = normalizedCenter,
           let moveBinding = normalizedMoveToNextDisplay,
           centerBinding == moveBinding {
            AppLogger.shared.log("加载的快捷键存在重复，已保留居中快捷键并清除下一显示器快捷键", level: .warning)
            normalizedMoveToNextDisplay = nil
        }

        if let almostMaximizeBinding = normalizedAlmostMaximize,
           let moveBinding = normalizedMoveToNextDisplay,
           almostMaximizeBinding == moveBinding {
            AppLogger.shared.log("加载的快捷键存在重复，已保留呼吸窗口快捷键并清除下一显示器快捷键", level: .warning)
            normalizedMoveToNextDisplay = nil
        }

        return (normalizedCenter, normalizedAlmostMaximize, normalizedMoveToNextDisplay)
    }
    
    // 保存配置
    func saveConfig() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(appRules)
            try data.write(to: configFilePath)
            AppLogger.shared.log("配置已保存", level: .info)
        } catch {
            AppLogger.shared.log("保存配置失败: \(error.localizedDescription)", level: .error)
        }
    }
    
    // 加载配置
    private func loadConfig() {
        do {
            if FileManager.default.fileExists(atPath: configFilePath.path) {
                let data = try Data(contentsOf: configFilePath)
                let decoder = JSONDecoder()
                appRules = try decoder.decode([AppRule].self, from: data)
                AppLogger.shared.log("配置已加载", level: .info)
            }
        } catch {
            AppLogger.shared.log("加载配置失败: \(error.localizedDescription)", level: .error)
        }
    }
    
    // 设置默认规则
    private func setupDefaultRules() {
        // 默认的消息应用列表
        let defaultMessageApps = [
            "com.tencent.xinWeChat": "WeChat",
            "com.apple.MobileSMS": "Messages",
            "org.telegram.desktop": "Telegram",
            "net.whatsapp.WhatsApp": "WhatsApp",
            "com.tinyspeck.slackmacgap": "Slack",
            "com.hnc.Discord": "Discord",
            "com.apple.systempreferences": "System Settings"
        ]
        
        // 默认的忽略应用列表
        let defaultIgnoreApps = [
            "com.yourcompany.HiTranslator": "HiTranslator",
            "com.raycast.macos": "Raycast",
            "com.apple.iphonesimulator": "iPhone Mirroring",
            "com.github.Electron": "Electron"
        ]
        
        // 添加默认的消息应用规则
        for (bundleId, appName) in defaultMessageApps {
            if !appRules.contains(where: { $0.bundleId == bundleId }) {
                let rule = AppRule(
                    bundleId: bundleId,
                    appName: appName,
                    rule: .center,
                    lastUsed: Date(),
                    useCount: 0
                )
                appRules.append(rule)
            }
        }
        
        // 添加默认的忽略应用规则
        for (bundleId, appName) in defaultIgnoreApps {
            if !appRules.contains(where: { $0.bundleId == bundleId }) {
                let rule = AppRule(
                    bundleId: bundleId,
                    appName: appName,
                    rule: .ignore,
                    lastUsed: Date(),
                    useCount: 0
                )
                appRules.append(rule)
            }
        }
        
        // 保存配置
        saveConfig()
    }
    
    // 更新应用规则
    func updateRule(for bundleId: String, rule: WindowHandlingRule) {
        if let index = appRules.firstIndex(where: { $0.bundleId == bundleId }) {
            // 创建规则的副本并修改它
            var updatedRule = appRules[index]
            updatedRule.rule = rule
            updatedRule.lastUsed = Date() // 更新最后使用时间
            
            // 替换原始规则
            appRules[index] = updatedRule
            
            // 保存配置
            saveConfig()
            
            // 触发刷新ID更新
            refreshID = UUID()
            
            // 发送通知
            NotificationCenter.default.post(name: Notification.Name("RuleUpdated"), object: nil)
        }
    }
    
    // 记录应用使用
    func recordAppUsage(bundleId: String, appName: String) {
        if let index = appRules.firstIndex(where: { $0.bundleId == bundleId }) {
            // 更新现有记录
            appRules[index].lastUsed = Date()
            appRules[index].useCount += 1
        } else {
            // 创建新记录，默认使用呼吸窗口规则
            let rule = AppRule(
                bundleId: bundleId,
                appName: appName,
                rule: .almostMaximize,
                lastUsed: Date(),
                useCount: 1
            )
            appRules.append(rule)
        }
        
        // 保存配置
        saveConfig()
        refreshID = UUID() // 触发视图刷新
    }
    
    // 获取应用规则
    func getRule(for bundleId: String, appName: String) -> WindowHandlingRule {
        // 记录应用使用
        recordAppUsage(bundleId: bundleId, appName: appName)
        
        // 查找规则
        if let rule = appRules.first(where: { $0.bundleId == bundleId }) {
            return rule.rule
        }
        
        // 默认使用呼吸窗口规则
        return .almostMaximize
    }

    @discardableResult
    func updateManualShortcuts(center: ShortcutBinding?, almostMaximize: ShortcutBinding?, moveToNextDisplay: ShortcutBinding?) -> Bool {
        guard Self.supportsManualShortcut(center),
              Self.supportsManualShortcut(almostMaximize),
              Self.supportsManualShortcut(moveToNextDisplay) else {
            AppLogger.shared.log("快捷键包含不支持的按键，已拒绝保存", level: .warning)
            return false
        }

        let assignedBindings = [center, almostMaximize, moveToNextDisplay].compactMap { $0 }
        if hasDuplicateShortcutBinding(in: assignedBindings) {
            AppLogger.shared.log("快捷键重复，已拒绝保存", level: .warning)
            return false
        }

        manualCenterShortcut = center
        manualAlmostMaximizeShortcut = almostMaximize
        manualMoveToNextDisplayShortcut = moveToNextDisplay
        saveGeneralConfig()
        return true
    }

    private func hasDuplicateShortcutBinding(in bindings: [ShortcutBinding]) -> Bool {
        for (index, binding) in bindings.enumerated() {
            if bindings.dropFirst(index + 1).contains(binding) {
                return true
            }
        }
        return false
    }

    func updateManualCenterShortcut(_ binding: ShortcutBinding?) -> Bool {
        updateManualShortcuts(
            center: binding,
            almostMaximize: manualAlmostMaximizeShortcut,
            moveToNextDisplay: manualMoveToNextDisplayShortcut
        )
    }

    func updateManualAlmostMaximizeShortcut(_ binding: ShortcutBinding?) -> Bool {
        updateManualShortcuts(
            center: manualCenterShortcut,
            almostMaximize: binding,
            moveToNextDisplay: manualMoveToNextDisplayShortcut
        )
    }

    func updateManualMoveToNextDisplayShortcut(_ binding: ShortcutBinding?) -> Bool {
        updateManualShortcuts(
            center: manualCenterShortcut,
            almostMaximize: manualAlmostMaximizeShortcut,
            moveToNextDisplay: binding
        )
    }

    func manualShortcut(for action: ManualWindowAction) -> ShortcutBinding? {
        switch action {
        case .center:
            return manualCenterShortcut
        case .almostMaximize:
            return manualAlmostMaximizeShortcut
        case .moveToNextDisplay:
            return manualMoveToNextDisplayShortcut
        }
    }

    @discardableResult
    func updateManualShortcut(for action: ManualWindowAction, binding: ShortcutBinding?) -> Bool {
        switch action {
        case .center:
            return updateManualCenterShortcut(binding)
        case .almostMaximize:
            return updateManualAlmostMaximizeShortcut(binding)
        case .moveToNextDisplay:
            return updateManualMoveToNextDisplayShortcut(binding)
        }
    }

    func clearManualShortcut(for action: ManualWindowAction) {
        _ = updateManualShortcut(for: action, binding: nil)
    }

    func resetManualShortcut(for action: ManualWindowAction) {
        _ = updateManualShortcut(for: action, binding: action.defaultShortcut)
    }

    func clearManualCenterShortcut() {
        _ = updateManualCenterShortcut(nil)
    }

    func clearManualAlmostMaximizeShortcut() {
        _ = updateManualAlmostMaximizeShortcut(nil)
    }

    func clearManualMoveToNextDisplayShortcut() {
        _ = updateManualMoveToNextDisplayShortcut(nil)
    }

    func resetManualCenterShortcut() {
        _ = updateManualCenterShortcut(ManualWindowAction.center.defaultShortcut)
    }

    func resetManualAlmostMaximizeShortcut() {
        _ = updateManualAlmostMaximizeShortcut(ManualWindowAction.almostMaximize.defaultShortcut)
    }

    func resetManualMoveToNextDisplayShortcut() {
        _ = updateManualMoveToNextDisplayShortcut(ManualWindowAction.moveToNextDisplay.defaultShortcut)
    }
}
