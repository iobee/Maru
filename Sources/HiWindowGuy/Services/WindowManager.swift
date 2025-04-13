import Cocoa
import Combine

class WindowManager {
    // 延迟时间（秒）
    private let debounceTime: TimeInterval = 0.1
    
    private var workspaceNotificationObserver: NSObjectProtocol?
    private var debounceTimer: Timer?
    
    init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        // 监听窗口焦点变化
        workspaceNotificationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            
            // 获取当前活动的应用
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                self.debounceWindowManagement(for: app)
            }
        }
        
        // 处理当前活动窗口
        if let activeApp = NSWorkspace.shared.frontmostApplication {
            debounceWindowManagement(for: activeApp)
        }
        
        AppLogger.shared.log("窗口管理器已启动监控", level: .info)
    }
    
    func stopMonitoring() {
        if let observer = workspaceNotificationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            workspaceNotificationObserver = nil
        }
        
        debounceTimer?.invalidate()
        debounceTimer = nil
        
        AppLogger.shared.log("窗口管理器已停止监控", level: .info)
    }
    
    private func debounceWindowManagement(for app: NSRunningApplication) {
        // 取消之前的计时器
        debounceTimer?.invalidate()
        
        // 创建新的延迟计时器
        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceTime, repeats: false) { [weak self] _ in
            self?.manageWindow(for: app)
        }
    }
    
    private func manageWindow(for app: NSRunningApplication) {
        guard let appName = app.localizedName,
              let bundleId = app.bundleIdentifier else {
            AppLogger.shared.log("无法获取应用信息", level: .warning)
            return
        }
        
        // 获取应用规则
        let rule = AppConfig.shared.getRule(for: bundleId, appName: appName)
        
        // 根据规则处理窗口
        switch rule {
        case .center:
            if let window = getActiveWindow() {
                AppLogger.shared.log("管理应用: \(appName) (\(bundleId)) - 居中处理", level: .info)
                centerWindow(window)
            } else {
                AppLogger.shared.log("应用 \(appName) 没有活动窗口，无法执行居中操作", level: .debug)
            }
            
        case .almostMaximize:
            if let window = getActiveWindow() {
                AppLogger.shared.log("管理应用: \(appName) (\(bundleId)) - 几乎最大化处理", level: .info)
                almostMaximizeWindow(window)
            } else {
                AppLogger.shared.log("应用 \(appName) 没有活动窗口，无法执行几乎最大化操作", level: .debug)
            }
            
        case .ignore:
            AppLogger.shared.log("忽略应用: \(appName) (\(bundleId))", level: .debug)
            
        case .custom:
            AppLogger.shared.log("应用 \(appName) (\(bundleId)) 使用自定义规则，暂未实现", level: .warning)
        }
    }
    
    private func getActiveWindow() -> CGWindow? {
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        let windowsListInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]
        
        guard let windowsListInfo = windowsListInfo else {
            AppLogger.shared.log("无法获取窗口列表", level: .warning)
            return nil
        }
        
        // 找到当前活动窗口
        for windowInfo in windowsListInfo {
            if let windowLayer = windowInfo[kCGWindowLayer as String] as? Int,
               windowLayer == 0,
               let bounds = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
               let x = bounds["X"],
               let y = bounds["Y"],
               let width = bounds["Width"],
               let height = bounds["Height"] {
                
                return CGWindow(bounds: CGRect(x: x, y: y, width: width, height: height))
            }
        }
        
        AppLogger.shared.log("未找到活动窗口", level: .warning)
        return nil
    }
    
    private func centerWindow(_ window: CGWindow) {
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        
        // 保持窗口当前大小，只调整位置居中
        let newX = screenFrame.origin.x + (screenFrame.width - window.bounds.width) / 2
        let newY = screenFrame.origin.y + (screenFrame.height - window.bounds.height) / 2
        
        let newFrame = CGRect(
            x: newX,
            y: newY,
            width: window.bounds.width,
            height: window.bounds.height
        )
        
        setWindowFrame(newFrame)
    }
    
    private func almostMaximizeWindow(_ window: CGWindow) {
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        
        // 计算几乎最大化的窗口尺寸（比全屏小一点点）
        let margin: CGFloat = 50
        let newFrame = CGRect(
            x: screenFrame.origin.x + margin,
            y: screenFrame.origin.y + margin,
            width: screenFrame.width - (margin * 2),
            height: screenFrame.height - (margin * 2)
        )
        
        setWindowFrame(newFrame)
    }
    
    private func setWindowFrame(_ frame: CGRect) {
        // 使用AppleScript调整窗口大小和位置，增加错误处理
        let script = """
        tell application "System Events"
            set frontApp to first application process whose frontmost is true
            -- 检查应用是否有窗口
            if (count of windows of frontApp) > 0 then
                set frontWindow to first window of frontApp
                set position of frontWindow to {\(frame.origin.x), \(frame.origin.y)}
                set size of frontWindow to {\(frame.width), \(frame.height)}
            else
                -- 没有窗口，记录信息但不抛出错误
                log "应用没有窗口可调整"
            end if
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let result = scriptObject.executeAndReturnError(&error)
            
            if let error = error {
                // 记录错误但不中断程序流程
                AppLogger.shared.log("AppleScript错误: \(error)", level: .error)
            } else {
                AppLogger.shared.log("成功调整窗口位置和大小", level: .debug)
            }
        }
    }
}

// 用于表示窗口的简单结构
struct CGWindow {
    let bounds: CGRect
} 