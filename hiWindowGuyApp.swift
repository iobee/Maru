import SwiftUI
import Cocoa
import Combine

@main
struct HiWindowGuyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(HiddenTitleBarWindowStyle())
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
        
        // 显示加载通知
        showNotification(message: "窗口管理器已启动")
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "window.vertical.closed", accessibilityDescription: "窗口管理器")
            
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
            statusItem?.menu = menu
        }
    }
    
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    private func showNotification(message: String) {
        let notification = NSUserNotification()
        notification.title = "窗口管理器"
        notification.informativeText = message
        NSUserNotificationCenter.default.deliver(notification)
    }
} 