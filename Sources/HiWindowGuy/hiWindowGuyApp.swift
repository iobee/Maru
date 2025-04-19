import SwiftUI
import Cocoa
import Combine

@main
struct HiWindowGuyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AppConfig.shared)
                .environmentObject(AppLogger.shared)
                .background(Color(NSColor.windowBackgroundColor))
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 900, height: 600)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var windowManager: WindowManager?
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLogger.shared.log("====== 应用开始启动 ======", level: .info)
        
        // 初始化必要的组件
        captureExceptions()
        windowManager = WindowManager()
        setupStatusBar()
        
        // 配置主窗口
        if let window = NSApp.windows.first {
            window.title = "HiWindowGuy"
            window.delegate = self
        }
    }
    
    private func setupStatusBar() {
        AppLogger.shared.log("开始设置状态栏图标", level: .debug)
        
        // 创建状态栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            // 设置状态栏图标
            if let image = NSImage(systemSymbolName: "window.vertical.closed", accessibilityDescription: "窗口管理器") {
                button.image = image
                button.imagePosition = .imageLeft
            } else {
                AppLogger.shared.log("无法创建状态栏图标图像", level: .error)
            }
            
            // 创建菜单
            let menu = NSMenu()
            
            // 显示主窗口菜单项 - 设置快捷键为"m"
            let showWindowItem = NSMenuItem(title: "显示主窗口", action: #selector(showMainWindow), keyEquivalent: "m")
            showWindowItem.target = self
            menu.addItem(showWindowItem)
            
            // 规则配置菜单项 - 设置快捷键为"r"
            let configItem = NSMenuItem(title: "规则配置", action: #selector(showRulesConfig), keyEquivalent: "r")
            configItem.target = self
            menu.addItem(configItem)
            
            menu.addItem(NSMenuItem.separator())
            
            // 启用/停用窗口管理
            let toggleItem = NSMenuItem(title: "启用窗口管理", action: #selector(toggleWindowManagement), keyEquivalent: "")
            toggleItem.target = self
            toggleItem.state = .on
            menu.addItem(toggleItem)
            
            menu.addItem(NSMenuItem.separator())
            
            // 退出菜单项 - 设置快捷键为"q"
            let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
            quitItem.target = self
            menu.addItem(quitItem)
            
            // 设置菜单
            statusItem?.menu = menu
            
            AppLogger.shared.log("状态栏菜单已设置，包含 \(menu.items.count) 个项目", level: .info)
        } else {
            AppLogger.shared.log("无法创建状态栏图标", level: .error)
        }
    }
    
    @objc private func toggleWindowManagement(_ sender: NSMenuItem) {
        if sender.state == .on {
            sender.state = .off
            windowManager?.stopMonitoring()
            AppLogger.shared.log("窗口管理已停用", level: .info)
        } else {
            sender.state = .on
            windowManager?.startMonitoring()
            AppLogger.shared.log("窗口管理已启用", level: .info)
        }
    }
    
    @objc private func showMainWindow() {
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    @objc private func showRulesConfig() {
        NotificationCenter.default.post(name: Notification.Name("showRulesConfig"), object: nil)
        showMainWindow()
    }
    
    @objc private func quit() {
        NSApp.terminate(nil)
    }
    
    private func captureExceptions() {
        NSSetUncaughtExceptionHandler { exception in
            AppLogger.shared.log("未捕获的异常: \(exception)", level: .error)
        }
    }
}

// MARK: - NSWindowDelegate
extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            AppLogger.shared.log("窗口即将关闭: \(window.title)", level: .debug)
        }
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            AppLogger.shared.log("窗口成为焦点: \(window.title)", level: .debug)
        }
    }
    
    func windowDidResignKey(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            AppLogger.shared.log("窗口失去焦点: \(window.title)", level: .debug)
        }
    }
} 