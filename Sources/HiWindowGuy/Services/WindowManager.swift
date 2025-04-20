import Cocoa
import Combine
import ApplicationServices

class WindowManager: ObservableObject {
    // 延迟时间（秒）
    private let debounceTime: TimeInterval = 0.1
    
    @Published private(set) var isMonitoring = false
    
    private var workspaceNotificationObserver: NSObjectProtocol?
    private var debounceTimer: Timer?
    
    init() {
        requestAccessibilityPermission()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // 请求辅助功能权限
    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !accessEnabled {
            AppLogger.shared.log("需要辅助功能权限来管理窗口", level: .warning)
            // 显示权限请求对话框
            let alert = NSAlert()
            alert.messageText = "需要辅助功能权限"
            alert.informativeText = "请在系统偏好设置中启用辅助功能权限以允许窗口管理。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "打开系统设置")
            alert.addButton(withTitle: "取消")
            
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        }
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
        
        isMonitoring = true
        AppLogger.shared.log("窗口管理器已启动监控", level: .info)
    }
    
    func stopMonitoring() {
        if let observer = workspaceNotificationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            workspaceNotificationObserver = nil
        }
        
        debounceTimer?.invalidate()
        debounceTimer = nil
        
        isMonitoring = false
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
            if let window = getFrontmostWindow(for: app) {
            AppLogger.shared.log("管理应用: \(appName) (\(bundleId)) - 居中处理", level: .info)
                centerWindow(window)
            } else {
                AppLogger.shared.log("应用 \(appName) 没有活动窗口，无法执行居中操作", level: .debug)
            }
            
        case .almostMaximize:
            if let window = getFrontmostWindow(for: app) {
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
    
    // 获取应用的前台窗口
    private func getFrontmostWindow(for app: NSRunningApplication) -> AXUIElement? {
        let appRef = AXUIElementCreateApplication(app.processIdentifier)
        
        // 首先尝试获取焦点窗口
        var windowRef: AnyObject?
        var result = AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &windowRef)
        
        if result == .success, let window = windowRef {
            AppLogger.shared.log("获取到焦点窗口", level: .debug)
            return (window as! AXUIElement)
        }
        
        // 如果获取焦点窗口失败，尝试获取所有窗口
        var windowsRef: AnyObject?
        result = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsRef)
        
        if result == .success, let windowArray = windowsRef as? [AXUIElement], !windowArray.isEmpty {
            AppLogger.shared.log("获取到窗口列表，使用第一个窗口", level: .debug)
            return windowArray.first
        }
        
        AppLogger.shared.log("无法获取应用窗口", level: .warning)
        return nil
    }
    
    private func centerWindow(_ window: AXUIElement) {
        AppLogger.shared.log("开始居中窗口操作", level: .debug)
        
        // 获取窗口当前所在的屏幕
        var positionRef: AnyObject?
        let positionResult = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef)
        
        if positionResult != .success {
            AppLogger.shared.log("获取窗口位置失败: \(positionResult.rawValue)", level: .warning)
            return
        }
        
        // 转换 AXValue 到 CGPoint
        var currentPosition = CGPoint.zero
        guard let axValue = positionRef else { return }
        if AXValueGetType(axValue as! AXValue) == .cgPoint,
           AXValueGetValue(axValue as! AXValue, .cgPoint, &currentPosition) {
            AppLogger.shared.log("当前窗口位置: \(currentPosition)", level: .debug)
        } else {
            AppLogger.shared.log("无法转换窗口位置", level: .warning)
            return
        }
        
        // 获取当前窗口所在的屏幕
        let currentScreen = NSScreen.screens.first { screen in
            screen.frame.contains(currentPosition)
        } ?? NSScreen.main ?? NSScreen.screens.first!
        
        AppLogger.shared.log("使用屏幕: \(currentScreen.localizedName), frame: \(currentScreen.frame)", level: .debug)
        
        // 使用 frame 而不是 visibleFrame，因为在 Stage Manager 下，visibleFrame 可能不准确
        let screenFrame = currentScreen.frame
        
        // 获取窗口当前大小
        var sizeRef: AnyObject?
        let sizeResult = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef)
        
        if sizeResult != .success {
            AppLogger.shared.log("获取窗口大小失败: \(sizeResult.rawValue)", level: .warning)
            return
        }
        
        // 转换 AXValue 到 CGSize
        var windowSize = CGSize.zero
        guard let sizeValue = sizeRef else { return }
        if AXValueGetType(sizeValue as! AXValue) == .cgSize,
           AXValueGetValue(sizeValue as! AXValue, .cgSize, &windowSize) {
            AppLogger.shared.log("当前窗口大小: \(windowSize)", level: .debug)
        } else {
            AppLogger.shared.log("无法转换窗口大小", level: .warning)
            return
        }
        
        // 计算居中位置，考虑 Stage Manager 的情况
        // Stage Manager 通常会在左右两侧预留空间，我们估计大约是屏幕宽度的 15%
        let stageManagerSideMargin = screenFrame.width * 0.15
        let usableScreenWidth = screenFrame.width - (stageManagerSideMargin * 2)
        
        // 计算新位置
        var newPosition = CGPoint(
            x: screenFrame.origin.x + stageManagerSideMargin + (usableScreenWidth - windowSize.width) / 2,
            y: screenFrame.origin.y + (screenFrame.height - windowSize.height) / 2
        )
        
        AppLogger.shared.log("计算的新位置 - X: \(newPosition.x), Y: \(newPosition.y)", level: .debug)
        
        // 创建新位置的 AXValue
        guard let axPosition = AXValueCreate(.cgPoint, &newPosition) else {
            AppLogger.shared.log("创建位置 AXValue 失败", level: .error)
            return
        }
        
        // 设置新位置
        let setPositionResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axPosition)
        
        if setPositionResult == .success {
            AppLogger.shared.log("窗口已成功居中，新位置: (\(newPosition.x), \(newPosition.y))，考虑了 Stage Manager", level: .info)
        } else {
            AppLogger.shared.log("设置窗口位置失败: \(setPositionResult.rawValue)", level: .error)
        }
    }
    
    private func almostMaximizeWindow(_ window: AXUIElement) {
        AppLogger.shared.log("开始几乎最大化窗口操作", level: .debug)
        
        // 获取窗口当前所在的屏幕
        var positionRef: AnyObject?
        let positionResult = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef)
        
        if positionResult != .success {
            AppLogger.shared.log("获取窗口位置失败: \(positionResult.rawValue)", level: .warning)
            return
        }
        
        // 转换 AXValue 到 CGPoint
        var currentPosition = CGPoint.zero
        guard let axValue = positionRef else { return }
        if AXValueGetType(axValue as! AXValue) == .cgPoint,
           AXValueGetValue(axValue as! AXValue, .cgPoint, &currentPosition) {
            AppLogger.shared.log("当前窗口位置: \(currentPosition)", level: .debug)
        } else {
            AppLogger.shared.log("无法转换窗口位置", level: .warning)
            return
        }
        
        // 获取当前窗口所在的屏幕
        let currentScreen = NSScreen.screens.first { screen in
            screen.frame.contains(currentPosition)
        } ?? NSScreen.main ?? NSScreen.screens.first!
        
        AppLogger.shared.log("使用屏幕: \(currentScreen.localizedName), frame: \(currentScreen.frame)", level: .debug)
        
        // 使用 frame，但需要考虑状态栏高度
        let screenFrame = currentScreen.frame
        let visibleFrame = currentScreen.visibleFrame
        
        // 计算状态栏高度
        let statusBarHeight = screenFrame.height - visibleFrame.height
        AppLogger.shared.log("状态栏高度: \(statusBarHeight)", level: .debug)
        
        // 从配置获取窗口比例参数 (0.0-1.0)
        let scaleFactor = CGFloat(AppConfig.shared.windowScaleFactor)
        
        // 基于比例计算边距
        let horizontalMargin = (screenFrame.width * (1.0 - scaleFactor)) / 2
        let verticalMargin = ((screenFrame.height - statusBarHeight) * (1.0 - scaleFactor)) / 2
        
        AppLogger.shared.log("使用比例系数: \(scaleFactor), 计算得到边距 - 水平: \(horizontalMargin), 垂直: \(verticalMargin)", level: .debug)
        
        // 计算新的框架，Y坐标从状态栏下方开始
        let newFrame = CGRect(
            x: screenFrame.origin.x + horizontalMargin,
            y: screenFrame.origin.y + statusBarHeight + verticalMargin, // 上边距减半，考虑状态栏
            width: screenFrame.width - (horizontalMargin * 2),
            height: screenFrame.height - statusBarHeight - (verticalMargin * 2) // 下边距保持不变，上边距减半
        )
        
        AppLogger.shared.log("新的窗口框架: \(newFrame)", level: .debug)
        
        // 创建新位置的 AXValue
        var newPosition = newFrame.origin
        guard let axPosition = AXValueCreate(.cgPoint, &newPosition) else {
            AppLogger.shared.log("创建位置 AXValue 失败", level: .error)
            return
        }
        
        // 创建新大小的 AXValue
        var newSize = newFrame.size
        guard let axSize = AXValueCreate(.cgSize, &newSize) else {
            AppLogger.shared.log("创建大小 AXValue 失败", level: .error)
            return
        }
        
        // 设置新位置和大小
        let setPositionResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axPosition)
        let setSizeResult = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, axSize)
        
        if setPositionResult == .success && setSizeResult == .success {
            AppLogger.shared.log("窗口已成功几乎最大化，比例: \(scaleFactor)，新位置: \(newFrame.origin)，新大小: \(newFrame.size)", level: .info)
        } else {
            AppLogger.shared.log("设置窗口位置或大小失败 - 位置: \(setPositionResult.rawValue), 大小: \(setSizeResult.rawValue)", level: .error)
        }
    }
    
    // 添加窗口动画支持
    private func animateWindow(_ window: AXUIElement, to frame: CGRect, duration: TimeInterval = 0.3) {
        var currentPosition: AnyObject?
        var currentSize: AnyObject?
        
        AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &currentPosition)
        AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &currentSize)
        
        guard let startPosition = currentPosition as? CGPoint,
              let startSize = currentSize as? CGSize else { return }
        
        let frameCount = Int(duration * 60) // 60fps
        let deltaX = (frame.origin.x - startPosition.x) / CGFloat(frameCount)
        let deltaY = (frame.origin.y - startPosition.y) / CGFloat(frameCount)
        let deltaWidth = (frame.width - startSize.width) / CGFloat(frameCount)
        let deltaHeight = (frame.height - startSize.height) / CGFloat(frameCount)
        
        for i in 0...frameCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration * Double(i) / Double(frameCount)) {
                let currentX = startPosition.x + deltaX * CGFloat(i)
                let currentY = startPosition.y + deltaY * CGFloat(i)
                let currentWidth = startSize.width + deltaWidth * CGFloat(i)
                let currentHeight = startSize.height + deltaHeight * CGFloat(i)
                
                AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, CGPoint(x: currentX, y: currentY) as CFTypeRef)
                AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, CGSize(width: currentWidth, height: currentHeight) as CFTypeRef)
            }
        }
    }
}

// 用于表示窗口的简单结构
struct CGWindow {
    let bounds: CGRect
} 