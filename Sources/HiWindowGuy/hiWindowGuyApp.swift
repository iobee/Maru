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
                .background(.regularMaterial)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var windowManager: WindowManager?
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 创建窗口管理器
        windowManager = WindowManager()
        
        // 创建状态栏图标
        setupStatusBar()
        
        // 记录启动日志
        AppLogger.shared.log("应用已启动", level: .info)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // 记录关闭日志
        AppLogger.shared.log("应用已关闭", level: .info)
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "window.vertical.closed", accessibilityDescription: "窗口管理器")
            
            let menu = NSMenu()
            
            // 应用名称菜单项
            let titleItem = NSMenuItem(title: "窗口管理器", action: nil, keyEquivalent: "")
            titleItem.isEnabled = false
            titleItem.attributedTitle = NSAttributedString(
                string: "窗口管理器",
                attributes: [
                    .font: NSFont.boldSystemFont(ofSize: 12),
                    .foregroundColor: NSColor.labelColor
                ]
            )
            menu.addItem(titleItem)
            menu.addItem(NSMenuItem.separator())
            
            // 显示主窗口菜单项
            let showWindowItem = NSMenuItem(title: "显示主窗口", action: #selector(showMainWindow), keyEquivalent: "")
            menu.addItem(showWindowItem)
            
            // 规则配置菜单项
            let configItem = NSMenuItem(title: "规则配置", action: #selector(showRulesConfig), keyEquivalent: "")
            menu.addItem(configItem)
            
            // 查看日志菜单项
            let logItem = NSMenuItem(title: "查看日志", action: #selector(showLogs), keyEquivalent: "")
            menu.addItem(logItem)
            
            menu.addItem(NSMenuItem.separator())
            
            // 启用/停用菜单项
            let toggleItem = NSMenuItem(title: "启用窗口管理", action: #selector(toggleWindowManagement), keyEquivalent: "")
            toggleItem.state = .on
            menu.addItem(toggleItem)
            
            menu.addItem(NSMenuItem.separator())
            
            // 退出菜单项
            menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
            
            statusItem?.menu = menu
        }
    }
    
    @objc private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }
    
    @objc private func showRulesConfig() {
        NSApp.activate(ignoringOtherApps: true)
        
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
            
            // 通知ContentView切换到规则配置标签
            NotificationCenter.default.post(
                name: Notification.Name("showRulesConfig"),
                object: nil
            )
        }
    }
    
    @objc private func showLogs() {
        NSApp.activate(ignoringOtherApps: true)
        
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
            
            // 通知ContentView切换到日志查看标签
            NotificationCenter.default.post(
                name: Notification.Name("showLogs"),
                object: nil
            )
        }
    }
    
    @objc private func toggleWindowManagement(_ sender: NSMenuItem) {
        if sender.state == .on {
            sender.state = .off
            windowManager?.stopMonitoring()
            logNotification("窗口管理已停用")
        } else {
            sender.state = .on
            windowManager?.startMonitoring()
            logNotification("窗口管理已启用")
        }
    }
    
    private func logNotification(_ message: String) {
        AppLogger.shared.log(message, level: .info)
    }
    
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
} 