import SwiftUI
import Cocoa
import Combine
import Foundation
import AppKit
import OSLog

@main
struct HiWindowGuyApp: App {
    @StateObject private var appConfig = AppConfig.shared
    @StateObject private var logger = AppLogger.shared
    @State private var isWindowManagementEnabled = true
    @Environment(\.openWindow) private var openWindow
    @State private var selectedTab: NavigationTab = .home
    @StateObject private var windowManager = WindowManager()
    
    var body: some Scene {
        WindowGroup("HiWindowGuy", id: "mainWindow") {
            ContentView(selectedTab: $selectedTab)
                .environmentObject(appConfig)
                .environmentObject(logger)
                .background(Color(NSColor.windowBackgroundColor))
        }
        .windowStyle(.titleBar)
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
                
                Toggle("启用窗口管理", isOn: $isWindowManagementEnabled)
                    .keyboardShortcut("e", modifiers: [.command, .option])
                    .onChange(of: isWindowManagementEnabled) { newValue in
                        if newValue {
                            logger.log("从菜单栏启用窗口管理", level: .info)
                            windowManager.startMonitoring()
                        } else {
                            logger.log("从菜单栏停用窗口管理", level: .info)
                            windowManager.stopMonitoring()
                        }
                    }
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
        
        MenuBarExtra("窗口管理", systemImage: "window.vertical.closed") {
            Button("显示主窗口") {
                openWindow(id: "mainWindow")
            }.keyboardShortcut("m")
            
            Button("规则配置") {
                openWindow(id: "mainWindow")
                NotificationCenter.default.post(name: Notification.Name("showRulesConfig"), object: nil)
            }.keyboardShortcut("r")
            
            Divider()
            
            Toggle("启用窗口管理", isOn: $isWindowManagementEnabled)
                .onChange(of: isWindowManagementEnabled) { newValue in
                    if newValue {
                        logger.log("窗口管理已启用", level: .info)
                        windowManager.startMonitoring()
                    } else {
                        logger.log("窗口管理已停用", level: .info)
                        windowManager.stopMonitoring()
                    }
                }
            
            Divider()
            
            Button("退出") {
                NSApp.terminate(nil)
            }.keyboardShortcut("q")
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
        // 设置未捕获异常处理
        NSSetUncaughtExceptionHandler { exception in
            AppLogger.shared.log("未捕获的异常: \(exception)", level: .error)
        }
        
        // 记录应用启动
        AppLogger.shared.log("====== 应用开始启动 ======", level: .info)
        
        // 应用启动完成的记录（原来在 AppDelegate 中的逻辑）
        NotificationCenter.default.addObserver(forName: NSApplication.didFinishLaunchingNotification, object: nil, queue: .main) { _ in
            AppLogger.shared.log("应用启动完成", level: .info)
        }
        
        // 应用退出的记录（原来在 AppDelegate 中的逻辑）
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { _ in
            AppLogger.shared.log("应用即将退出", level: .info)
        }
    }
} 