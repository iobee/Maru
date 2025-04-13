import Foundation
import Combine

// 窗口处理规则枚举
enum WindowHandlingRule: String, Codable, CaseIterable, Identifiable {
    case center = "居中"
    case almostMaximize = "几乎最大化"
    case ignore = "忽略"
    case custom = "自定义"
    
    var id: String { self.rawValue }
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
    
    // 日志级别
    @Published var logLevel: LogLevel = .info
    
    // 配置文件路径
    private let configFilePath: URL
    
    // 单例实例
    static let shared = AppConfig()
    
    private init() {
        // 获取应用支持目录
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupportDir.appendingPathComponent("HiWindowGuy")
        
        // 创建应用目录（如果不存在）
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        
        // 设置配置文件路径
        configFilePath = appDir.appendingPathComponent("config.json")
        
        // 加载配置
        loadConfig()
        
        // 设置默认规则（如果尚未设置）
        setupDefaultRules()
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
            appRules[index].rule = rule
            saveConfig()
        }
    }
    
    // 记录应用使用
    func recordAppUsage(bundleId: String, appName: String) {
        if let index = appRules.firstIndex(where: { $0.bundleId == bundleId }) {
            // 更新现有记录
            appRules[index].lastUsed = Date()
            appRules[index].useCount += 1
        } else {
            // 创建新记录，默认使用几乎最大化规则
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
    }
    
    // 获取应用规则
    func getRule(for bundleId: String, appName: String) -> WindowHandlingRule {
        // 记录应用使用
        recordAppUsage(bundleId: bundleId, appName: appName)
        
        // 查找规则
        if let rule = appRules.first(where: { $0.bundleId == bundleId }) {
            return rule.rule
        }
        
        // 默认使用几乎最大化规则
        return .almostMaximize
    }
} 