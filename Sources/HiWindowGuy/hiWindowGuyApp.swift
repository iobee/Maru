import SwiftUI
import Cocoa
import Combine
import Foundation
import AppKit
import OSLog

@main
struct HiWindowGuyApp: App {
    private static let sharedWindowManager = WindowManager()

    @StateObject private var appConfig = AppConfig.shared
    @StateObject private var logger = AppLogger.shared
    @State private var isWindowManagementEnabled = true
    @Environment(\.openWindow) private var openWindow
    @State private var selectedTab: NavigationTab = .home
    private let windowManager = HiWindowGuyApp.sharedWindowManager
    
    var body: some Scene {
        Window("HiWindowGuy", id: "mainWindow") {
            ContentView(
                selectedTab: $selectedTab,
                isWindowManagementEnabled: windowManagementBinding
            )
                .environmentObject(appConfig)
                .environmentObject(logger)
                .background(Color(NSColor.windowBackgroundColor))
                .onAppear {
                    // 在下一个运行循环中配置窗口
                    DispatchQueue.main.async {
                        configureWindow()
                        
                        // 检查辅助功能权限（仅提示一次）
                        if !windowManager.checkAccessibilityPermission() {
                            windowManager.showAccessibilityPermissionAlert()
                        }
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 600)
        .windowResizability(.contentSize)
        .commands {
            // 添加自定义命令到标准菜单栏
            CommandGroup(replacing: .appInfo) {
                Button("关于 HiWindowGuy") {
                    showAboutPanel()
                }
            }
            
            CommandGroup(after: .appSettings) {
                Button("窗口规则设置") {
                    openWindow(id: "mainWindow")
                    NotificationCenter.default.post(name: Notification.Name("showRulesConfig"), object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command, .option])
                
                Toggle("启用窗口管理", isOn: windowManagementBinding)
                    .keyboardShortcut("e", modifiers: [.command, .option])
            }
            
            CommandMenu("窗口管理") {
                Button("显示主界面") {
                    openWindow(id: "mainWindow")
                }
                .keyboardShortcut("m", modifiers: [.command, .option])
                
                Button("查看日志") {
                    openWindow(id: "mainWindow")
                    NotificationCenter.default.post(name: Notification.Name("showLogs"), object: nil)
                }
                .keyboardShortcut("l", modifiers: [.command, .option])
            }
        }
        
        MenuBarExtra {
            Button("显示主窗口") {
                openWindow(id: "mainWindow")
            }.keyboardShortcut("m")
            
            Button("规则配置") {
                openWindow(id: "mainWindow")
                NotificationCenter.default.post(name: Notification.Name("showRulesConfig"), object: nil)
            }.keyboardShortcut("r")
            
            Divider()
            
            Toggle("启用窗口管理", isOn: windowManagementBinding)
            
            Divider()
            
            Button("退出") {
                NSApp.terminate(nil)
            }.keyboardShortcut("q")
        } label: {
            Image(nsImage: AppIconProvider.makeMenuBarIcon())
        }
    }
    
    private func configureWindow() {
        // 查找应用窗口
        for window in NSApplication.shared.windows {
            if window.title == "HiWindowGuy" {
                // 设置窗口的可收集性，使其在Stage Manager中正常工作
                window.collectionBehavior = [.managed, .participatesInCycle, .fullScreenPrimary]
                
                // 设置窗口特性
                window.isOpaque = false
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.styleMask.insert(.fullSizeContentView)
                
                logger.log("配置窗口: \(window.title)", level: .info)
            }
        }
        
        // 注册窗口创建通知，以便在新窗口创建时也进行配置
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { notification in
            if let window = notification.object as? NSWindow, window.title == "HiWindowGuy" {
                window.collectionBehavior = [.managed, .participatesInCycle, .fullScreenPrimary]
                window.isOpaque = false
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.styleMask.insert(.fullSizeContentView)
                logger.log("配置新窗口: \(window.title)", level: .info)
            }
        }
    }

    private var windowManagementBinding: Binding<Bool> {
        Binding(
            get: { isWindowManagementEnabled },
            set: { newValue in
                guard newValue != isWindowManagementEnabled else {
                    return
                }

                isWindowManagementEnabled = newValue
                Self.applyWindowManagementState(newValue, source: "状态变更")
            }
        )
    }

    private static func applyWindowManagementState(_ isEnabled: Bool, source: String) {
        if isEnabled {
            AppLogger.shared.log("\(source): 启用窗口管理", level: .info)
            sharedWindowManager.startMonitoring()
        } else {
            AppLogger.shared.log("\(source): 停用窗口管理", level: .info)
            sharedWindowManager.stopMonitoring()
        }
    }
    
    private func showAboutPanel() {
        let options: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: "HiWindowGuy",
            .applicationVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            .version: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1",
            .credits: NSAttributedString(
                string: "一个简单而强大的窗口管理工具\n© 2023-2024 Nick. 保留所有权利。",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12),
                    .foregroundColor: NSColor.labelColor
                ]
            )
        ]
        NSApp.orderFrontStandardAboutPanel(options: options)
        logger.log("显示关于面板", level: .info)
    }
    
    init() {
        NSApplication.shared.applicationIconImage = AppIconProvider.makeAppIcon(size: 512)

        // 设置未捕获异常处理
        NSSetUncaughtExceptionHandler { exception in
            AppLogger.shared.log("未捕获的异常: \(exception)", level: .error)
        }
        
        // 记录应用启动
        AppLogger.shared.log("====== 应用开始启动 ======", level: .info)
        
        // 应用启动完成的记录（原来在 AppDelegate 中的逻辑）
        NotificationCenter.default.addObserver(forName: NSApplication.didFinishLaunchingNotification, object: nil, queue: .main) { _ in
            AppLogger.shared.log("应用启动完成", level: .info)
            Self.applyWindowManagementState(true, source: "启动同步")
        }
        
        // 应用退出的记录（原来在 AppDelegate 中的逻辑）
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { _ in
            AppLogger.shared.log("应用即将退出", level: .info)
        }
    }
} 
