import Cocoa
import Combine
import ApplicationServices

class WindowManager: ObservableObject {
    // 延迟时间（秒）
    private let debounceTime: TimeInterval = 0.3
    
    @Published private(set) var isMonitoring = false
    
    private var workspaceNotificationObserver: NSObjectProtocol?
    private var debounceTimer: Timer?
    
    // 简化防重机制
    // 记录最近处理的窗口信息
    private var lastProcessedWindowInfo: (bundleId: String, timestamp: Date)?
    // 防重处理的最小时间间隔（秒）
    private let minProcessingInterval: TimeInterval = 1.5
    // 窗口操作状态标记
    private var isWindowOperationInProgress = false

    init() {
        requestAccessibilityPermission()
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
        // 先停止当前监控（如果有的话）
        stopMonitoring()
        
        // 重置所有状态变量
        lastProcessedWindowInfo = nil
        isWindowOperationInProgress = false
        
        // 监听窗口焦点变化
        workspaceNotificationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            
            // 如果窗口操作正在进行中，跳过处理
            if self.isWindowOperationInProgress {
                return
            }
            
            // 获取当前活动的应用
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                AppLogger.shared.log("检测到应用切换: \(app.localizedName ?? "未知")", level: .debug)
                self.debounceWindowManagement(for: app)
            }
        }
        
        // 延迟处理当前活动窗口，避免启动时的混乱
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self, self.isMonitoring else { return }
            if let activeApp = NSWorkspace.shared.frontmostApplication {
                AppLogger.shared.log("延迟处理初始应用: \(activeApp.localizedName ?? "unknown")", level: .info)
                self.debounceWindowManagement(for: activeApp)
            }
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
        
        // 验证应用信息
        guard let appName = app.localizedName,
              let bundleId = app.bundleIdentifier else { return }
        
        // 检查是否在冷却期内
        if let lastInfo = lastProcessedWindowInfo,
           lastInfo.bundleId == bundleId,
           Date().timeIntervalSince(lastInfo.timestamp) < minProcessingInterval {
            AppLogger.shared.log("应用 \(appName) 处于冷却期，跳过处理", level: .debug)
            return
        }
        
        // 创建新的延迟计时器
        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceTime, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.manageWindow(for: app)
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
        case .center, .almostMaximize:
            processWindowWithRule(app: app, bundleId: bundleId, appName: appName, rule: rule)
            
        case .ignore:
            AppLogger.shared.log("忽略应用: \(appName) (\(bundleId))", level: .debug)
            
        case .custom:
            AppLogger.shared.log("应用 \(appName) (\(bundleId)) 使用自定义规则，暂未实现", level: .warning)
        }
    }
    
    /// 处理需要调整位置的窗口
    private func processWindowWithRule(app: NSRunningApplication, bundleId: String, appName: String, rule: WindowHandlingRule) {
        // 获取窗口
        guard let window = getFrontmostWindow(for: app) else {
            AppLogger.shared.log("应用 \(appName) 没有活动窗口，无法执行操作", level: .debug)
            return
        }
        
        // 获取窗口特征
        guard let signature = getWindowSignature(window) else {
            AppLogger.shared.log("无法获取窗口特征", level: .warning)
            return
        }
        
        // 记录处理信息
        AppLogger.shared.log("处理应用: \(appName) (\(bundleId)), 规则: \(rule)", level: .info)
        AppLogger.shared.log("窗口位置: (\(signature.position.x), \(signature.position.y)), 大小: \(signature.size.width) x \(signature.size.height)", level: .debug)
        
        // 标记窗口操作开始
        isWindowOperationInProgress = true
        
        // 执行窗口操作
        switch rule {
        case .center:
            centerWindow(window)
        case .almostMaximize:
            almostMaximizeWindow(window)
        default:
            break // 不会发生，因为调用方已过滤
        }
        
        // 更新处理记录，仅记录bundleId和时间戳
        lastProcessedWindowInfo = (bundleId: bundleId, timestamp: Date())
        
        // 延迟重置操作标志
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isWindowOperationInProgress = false
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
    
    // 获取窗口特征，用于标识窗口
    private func getWindowSignature(_ window: AXUIElement) -> (position: CGPoint, size: CGSize)? {
        var positionRef: AnyObject?
        var sizeRef: AnyObject?
        
        let positionResult = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef)
        let sizeResult = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef)
        
        if positionResult == .success && sizeResult == .success,
           let positionValue = positionRef,
           let sizeValue = sizeRef {
            
            var position = CGPoint.zero
            var size = CGSize.zero
            
            if AXValueGetValue(positionValue as! AXValue, .cgPoint, &position) &&
               AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) {
                return (position, size)
            }
        }
        
        return nil
    }
    
    // MARK: - 窗口屏幕匹配方法
    
    /// 获取窗口所在的屏幕
    private func getScreenForWindow(_ window: AXUIElement) -> NSScreen {
        AppLogger.shared.log("开始查找窗口所在屏幕", level: .debug)
        
        // 1. 获取窗口位置和大小
        guard let (position, size) = getWindowPositionAndSize(window) else {
            return getFallbackScreen()
        }
        
        // 2. 尝试通过坐标范围匹配屏幕
        if let screen = findScreenByCoordinates(position: position, size: size) {
            return screen
        }
        
        // 3. 尝试通过显示器边界匹配
        if let screen = findScreenByDisplayBounds(position: position, size: size) {
            return screen
        }
        
        // 4. 尝试通过重叠区域匹配
        if let screen = findScreenByOverlap(position: position, size: size) {
            return screen
        }
        
        // 5. 尝试通过距离找到最近的屏幕
        if let screen = findNearestScreen(position: position, size: size) {
            return screen
        }
        
        // 6. 使用备用方法
        return getFallbackScreen()
    }
    
    /// 获取窗口位置和大小
    private func getWindowPositionAndSize(_ window: AXUIElement) -> (CGPoint, CGSize)? {
        // 获取窗口位置
        var positionRef: AnyObject?
        let positionResult = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef)
        
        // 获取窗口大小
        var sizeRef: AnyObject?
        let sizeResult = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef)
        
        if positionResult == .success && sizeResult == .success,
           let positionValue = positionRef,
           let sizeValue = sizeRef {
            
            var position = CGPoint.zero
            var size = CGSize.zero
            
            // 转换AXValue到CGPoint和CGSize
            if AXValueGetValue(positionValue as! AXValue, .cgPoint, &position) &&
               AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) {
                
                AppLogger.shared.log("窗口位置(AX坐标系): (\(position.x), \(position.y)), 大小: \(size.width) x \(size.height)", level: .debug)
                return (position, size)
            }
        }
        
        return nil
    }
    
    /// 通过坐标范围查找屏幕
    private func findScreenByCoordinates(position: CGPoint, size: CGSize) -> NSScreen? {
        // 获取主屏幕尺寸，用于坐标系转换
        guard let mainScreen = NSScreen.screens.first else {
            AppLogger.shared.log("无法获取主屏幕", level: .error)
            return nil
        }
        
        // 记录所有屏幕
        AppLogger.shared.log("系统有 \(NSScreen.screens.count) 个屏幕", level: .debug)
        for (index, screen) in NSScreen.screens.enumerated() {
            let frame = screen.frame
            AppLogger.shared.log("屏幕\(index): \(screen.localizedName), 坐标: \(frame.origin.x), \(frame.origin.y), 大小: \(frame.width) x \(frame.height)", level: .debug)
        }
        
        // 计算窗口中心点（在AX坐标系中）
        let centerPoint = CGPoint(x: position.x + size.width/2, y: position.y + size.height/2)
        AppLogger.shared.log("窗口中心点(AX坐标系): \(centerPoint)", level: .debug)
        
        // 检查窗口是否在任一屏幕的坐标范围内
        for screen in NSScreen.screens {
            // 计算屏幕在AX坐标系中的边界
            let screenFrame = screen.frame
            let mainScreenHeight = mainScreen.frame.height
            
            // 将屏幕坐标从NSScreen坐标系转换为AX坐标系
            let screenMinX = screenFrame.origin.x
            let screenMaxX = screenFrame.origin.x + screenFrame.width
            
            // 计算屏幕在AX坐标系中的Y坐标范围
            let screenMinY = mainScreenHeight - (screenFrame.origin.y + screenFrame.height)
            let screenMaxY = mainScreenHeight - screenFrame.origin.y
            
            AppLogger.shared.log("检查屏幕: \(screen.localizedName), AX坐标系 - X范围: \(screenMinX)..\(screenMaxX), Y范围: \(screenMinY)..\(screenMaxY)", level: .debug)
            
            if centerPoint.x >= screenMinX && centerPoint.x <= screenMaxX &&
               centerPoint.y >= screenMinY && centerPoint.y <= screenMaxY {
                AppLogger.shared.log("找到窗口所在屏幕: \(screen.localizedName) (通过坐标系匹配)", level: .info)
                return screen
            }
        }
        
        return nil
    }
    
    /// 通过显示器边界查找屏幕
    private func findScreenByDisplayBounds(position: CGPoint, size: CGSize) -> NSScreen? {
        AppLogger.shared.log("通过坐标系未找到匹配屏幕，尝试使用边界匹配", level: .debug)
        
        // 使用屏幕ID和边界检查
        for screen in NSScreen.screens {
            // 获取屏幕描述信息
            let deviceDescription = screen.deviceDescription
            if let screenNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
                // 创建CGDirectDisplayID
                let displayID = CGDirectDisplayID(screenNumber.uint32Value)
                
                // 获取显示器边界
                let displayBounds = CGDisplayBounds(displayID)
                
                // 创建窗口矩形
                let windowRect = CGRect(x: position.x, y: position.y, width: size.width, height: size.height)
                
                // 检查窗口是否与显示器边界有重叠
                if windowRect.intersects(displayBounds) {
                    AppLogger.shared.log("找到窗口所在屏幕: \(screen.localizedName) (通过边界匹配)", level: .info)
                    return screen
                }
            }
        }
        
        return nil
    }
    
    /// 通过计算重叠区域查找屏幕
    private func findScreenByOverlap(position: CGPoint, size: CGSize) -> NSScreen? {
        AppLogger.shared.log("通过边界匹配未找到屏幕，尝试使用重叠区域匹配", level: .debug)
        
        // 获取主屏幕
        guard let mainScreen = NSScreen.screens.first else {
            AppLogger.shared.log("无法获取主屏幕", level: .error)
            return nil
        }
        
        // 计算窗口区域
        let windowRect = CGRect(x: position.x, y: position.y, width: size.width, height: size.height)
        
        var bestScreen: NSScreen? = nil
        var maxOverlapArea: CGFloat = 0
        
        for screen in NSScreen.screens {
            // 转换屏幕区域到AX坐标系
            let screenRect = convertToAXRect(screen.frame)
            
            // 计算与每个屏幕的重叠区域
            let intersection = windowRect.intersection(screenRect)
            if !intersection.isNull && intersection.width > 0 && intersection.height > 0 {
                let overlapArea = intersection.width * intersection.height
                if overlapArea > maxOverlapArea {
                    maxOverlapArea = overlapArea
                    bestScreen = screen
                }
            }
        }
        
        if let screen = bestScreen {
            AppLogger.shared.log("通过重叠区域计算，窗口最匹配的屏幕是: \(screen.localizedName)", level: .info)
            return screen
        }
        
        return nil
    }
    
    /// 查找离窗口中心点最近的屏幕
    private func findNearestScreen(position: CGPoint, size: CGSize) -> NSScreen? {
        AppLogger.shared.log("通过重叠区域未找到屏幕，尝试查找最近屏幕", level: .debug)
        
        // 计算窗口中心点
        let centerPoint = CGPoint(x: position.x + size.width/2, y: position.y + size.height/2)
        
        var closestScreen = NSScreen.screens.first
        var minDistance = CGFloat.greatestFiniteMagnitude
        
        for screen in NSScreen.screens {
            // 转换屏幕中心点到AX坐标系
            let screenRect = convertToAXRect(screen.frame)
            let screenCenter = CGPoint(
                x: screenRect.origin.x + screenRect.width / 2,
                y: screenRect.origin.y + screenRect.height / 2
            )
            
            let distance = hypot(centerPoint.x - screenCenter.x, centerPoint.y - screenCenter.y)
            AppLogger.shared.log("屏幕 \(screen.localizedName) 在AX坐标系中距离窗口中心点距离: \(distance)", level: .debug)
            
            if distance < minDistance {
                minDistance = distance
                closestScreen = screen
            }
        }
        
        if let screen = closestScreen {
            AppLogger.shared.log("使用距离窗口中心点最近的屏幕: \(screen.localizedName)", level: .info)
            return screen
        }
        
        return nil
    }
    
    /// 获取备用屏幕（当其他方法都失败时）
    private func getFallbackScreen() -> NSScreen {
        // 获取当前应用活动窗口所在的屏幕
        if let mainWindow = NSApplication.shared.mainWindow, let screen = mainWindow.screen {
            AppLogger.shared.log("返回主窗口所在屏幕: \(screen.localizedName)", level: .info)
            return screen
        }
        
        // 如果找不到，优先返回主屏幕（通常是内置显示器）
        let defaultScreen = NSScreen.main ?? NSScreen.screens.first!
        AppLogger.shared.log("返回默认屏幕: \(defaultScreen.localizedName)", level: .info)
        return defaultScreen
    }
    
    // MARK: - 坐标系转换工具方法
    
    /// 将NSScreen坐标系（左下角为原点，Y轴向上）转换为AXUIElement坐标系（左上角为原点，Y轴向下）
    private func convertToAXCoordinates(_ point: CGPoint, size: CGSize? = nil) -> CGPoint {
        guard let mainScreen = NSScreen.screens.first else {
            AppLogger.shared.log("无法获取主屏幕进行坐标转换", level: .error)
            return point
        }
        
        let mainScreenHeight = mainScreen.frame.height
        
        // 如果提供了尺寸，需要考虑元素高度
        if let size = size {
            // Y坐标需要考虑元素高度: AX_Y = MainScreenHeight - NS_Y - Height
            return CGPoint(x: point.x, y: mainScreenHeight - point.y - size.height)
        } else {
            // 点坐标转换（不考虑高度）: AX_Y = MainScreenHeight - NS_Y
            return CGPoint(x: point.x, y: mainScreenHeight - point.y)
        }
    }
    
    /// 将AXUIElement坐标系（左上角为原点，Y轴向下）转换为NSScreen坐标系（左下角为原点，Y轴向上）
    private func convertToNSScreenCoordinates(_ point: CGPoint, size: CGSize? = nil) -> CGPoint {
        guard let mainScreen = NSScreen.screens.first else {
            AppLogger.shared.log("无法获取主屏幕进行坐标转换", level: .error)
            return point
        }
        
        let mainScreenHeight = mainScreen.frame.height
        
        // 如果提供了尺寸，需要考虑元素高度
        if let size = size {
            // Y坐标需要考虑元素高度: NS_Y = MainScreenHeight - AX_Y - Height
            return CGPoint(x: point.x, y: mainScreenHeight - point.y - size.height)
        } else {
            // 点坐标转换（不考虑高度）: NS_Y = MainScreenHeight - AX_Y
            return CGPoint(x: point.x, y: mainScreenHeight - point.y)
        }
    }
    
    /// 将NSScreen矩形转换为AXUIElement坐标系的矩形
    private func convertToAXRect(_ rect: CGRect) -> CGRect {
        let axPoint = convertToAXCoordinates(rect.origin, size: rect.size)
        return CGRect(x: axPoint.x, y: axPoint.y, width: rect.width, height: rect.height)
    }
    
    /// 将AXUIElement坐标系的矩形转换为NSScreen矩形
    private func convertToNSScreenRect(_ rect: CGRect) -> CGRect {
        let nsPoint = convertToNSScreenCoordinates(rect.origin, size: rect.size)
        return CGRect(x: nsPoint.x, y: nsPoint.y, width: rect.width, height: rect.height)
    }
    
    private func centerWindow(_ window: AXUIElement) {
        AppLogger.shared.log("开始居中窗口操作", level: .debug)
        
        // 直接获取窗口所在的屏幕
        let currentScreen = getScreenForWindow(window)
        AppLogger.shared.log("使用屏幕: \(currentScreen.localizedName), frame: \(currentScreen.frame)", level: .debug)
        
        // 使用 frame 而不是 visibleFrame，因为在 Stage Manager 下，visibleFrame 可能不准确
        let screenFrame = currentScreen.frame

        let statusBarHeight = getStatusBarHeight(for: currentScreen)
        
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
        
        // 计算新位置 (NSScreen坐标系，原点在左下角，Y轴向上)
        let nsScreenX = screenFrame.origin.x + stageManagerSideMargin + (usableScreenWidth - windowSize.width) / 2
        let nsScreenY = screenFrame.origin.y + (screenFrame.height - statusBarHeight - windowSize.height) / 2
        let nsPosition = CGPoint(x: nsScreenX, y: nsScreenY)
        
        // 将NSScreen坐标系转换为AXUIElement坐标系
        let newPosition = convertToAXCoordinates(nsPosition, size: windowSize)
        
        AppLogger.shared.log("计算的新位置 - NSScreen坐标: \(nsPosition)", level: .debug)
        AppLogger.shared.log("转换后的AX坐标: \(newPosition)", level: .debug)
        
        // 创建新位置的 AXValue
        var axPosition = newPosition
        guard let axPositionValue = AXValueCreate(.cgPoint, &axPosition) else {
            AppLogger.shared.log("创建位置 AXValue 失败", level: .error)
            return
        }
        
        // 设置新位置
        let setPositionResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axPositionValue)
        
        if setPositionResult == .success {
            AppLogger.shared.log("窗口已成功居中，新位置(AX坐标系): \(newPosition)", level: .info)
        } else {
            AppLogger.shared.log("设置窗口位置失败: \(setPositionResult.rawValue)", level: .error)
        }
    }
    
    // MARK: - 屏幕和状态栏相关方法
    
    /// 获取指定屏幕的状态栏高度
    /// - Parameter screen: 目标屏幕
    /// - Returns: 状态栏高度（像素）
    private func getStatusBarHeight(for screen: NSScreen) -> CGFloat {
        // 状态栏高度是屏幕总高度减去可见区域高度
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        
        let statusBarHeight = screenFrame.height - visibleFrame.height
        
        // 考虑多显示器情况: 只有主显示器会有状态栏，其他显示器状态栏高度可能为0
        // 但也可能因为系统设置，多个显示器都有状态栏
        if statusBarHeight > 0 {
            AppLogger.shared.log("屏幕 \(screen.localizedName) 的状态栏高度: \(statusBarHeight)", level: .debug)
        } else {
            AppLogger.shared.log("屏幕 \(screen.localizedName) 无状态栏", level: .debug)
        }
        
        return statusBarHeight
    }
    
    /// 获取指定屏幕可用的内容区域（不包含状态栏）
    /// - Parameter screen: 目标屏幕
    /// - Returns: 可用内容区域的矩形
    private func getContentArea(for screen: NSScreen) -> CGRect {
        return screen.visibleFrame
    }
    
    private func almostMaximizeWindow(_ window: AXUIElement) {
        AppLogger.shared.log("开始几乎最大化窗口操作", level: .debug)
        
        // 直接获取窗口所在的屏幕
        let currentScreen = getScreenForWindow(window)
        AppLogger.shared.log("使用屏幕: \(currentScreen.localizedName), frame: \(currentScreen.frame)", level: .debug)
        
        // 使用 frame，但需要考虑状态栏高度
        let screenFrame = currentScreen.frame
        
        // 获取状态栏高度
        let statusBarHeight = getStatusBarHeight(for: currentScreen)
        AppLogger.shared.log("状态栏高度: \(statusBarHeight)", level: .debug)
        
        // 从配置获取窗口比例参数 (0.0-1.0)
        let scaleFactor = CGFloat(AppConfig.shared.windowScaleFactor)
        
        // 基于比例计算边距
        let horizontalMargin = (screenFrame.width * (1.0 - scaleFactor)) / 2
        let verticalMargin = ((screenFrame.height - statusBarHeight) * (1.0 - scaleFactor)) / 2
        
        AppLogger.shared.log("使用比例系数: \(scaleFactor), 计算得到边距 - 水平: \(horizontalMargin), 垂直: \(verticalMargin)", level: .debug)
        
        // 计算新的框架，Y坐标从状态栏下方开始 (NSScreen坐标系)
        let nsFrameX = screenFrame.origin.x + horizontalMargin
        let nsFrameY = screenFrame.origin.y + verticalMargin
        let nsFrameWidth = screenFrame.width - (horizontalMargin * 2)
        let nsFrameHeight = screenFrame.height - statusBarHeight - (verticalMargin * 2)
        
        // 创建NSScreen坐标系中的矩形
        let nsRect = CGRect(
            x: nsFrameX,
            y: nsFrameY,
            width: nsFrameWidth,
            height: nsFrameHeight
        )
        
        // 将矩形从NSScreen坐标系转换为AXUIElement坐标系
        let axRect = convertToAXRect(nsRect)
        
        // 创建新位置的 AXValue (AXUIElement坐标系)
        var newPosition = axRect.origin
        guard let axPosition = AXValueCreate(.cgPoint, &newPosition) else {
            AppLogger.shared.log("创建位置 AXValue 失败", level: .error)
            return
        }
        
        // 创建新大小的 AXValue
        var newSize = axRect.size
        guard let axSize = AXValueCreate(.cgSize, &newSize) else {
            AppLogger.shared.log("创建大小 AXValue 失败", level: .error)
            return
        }
        
        AppLogger.shared.log("NSScreen坐标系矩形: \(nsRect)", level: .debug)
        AppLogger.shared.log("转换后的AX坐标系矩形: \(axRect)", level: .debug)
        
        // 设置新位置和大小
        let setPositionResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axPosition)
        let setSizeResult = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, axSize)
        
        if setPositionResult == .success && setSizeResult == .success {
            AppLogger.shared.log("窗口已成功几乎最大化，比例: \(scaleFactor)，新位置(AX坐标系): \(newPosition)，新大小: \(newSize)", level: .info)
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