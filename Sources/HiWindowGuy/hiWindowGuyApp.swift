import SwiftUI
import Cocoa
import Combine

@main
struct HiWindowGuyApp: App {
    @StateObject private var appConfig = AppConfig.shared
    @StateObject private var logger = AppLogger.shared
    @State private var isWindowManagementEnabled = true
    @Environment(\.openWindow) private var openWindow
    
    var body: some Scene {
        WindowGroup("HiWindowGuy", id: "mainWindow") {
            ContentView()
                .environmentObject(appConfig)
                .environmentObject(logger)
                .background(Color(NSColor.windowBackgroundColor))
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 900, height: 600)
        .windowResizability(.contentSize)
        
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
                    } else {
                        logger.log("窗口管理已停用", level: .info)
                    }
                }
            
            Divider()
            
            Button("退出") {
                NSApp.terminate(nil)
            }.keyboardShortcut("q")
        }
    }
    
    init() {
        // 设置未捕获异常处理
        NSSetUncaughtExceptionHandler { exception in
            AppLogger.shared.log("未捕获的异常: \(exception)", level: .error)
        }
        
        // 记录应用启动
        AppLogger.shared.log("====== 应用开始启动 ======", level: .info)
    }
} 