import Cocoa
import Combine
import ApplicationServices

class WindowManager: ObservableObject {
    // 延迟时间（秒）- 增加延迟时间以防止重复处理
    private let debounceTime: TimeInterval = 0.3
    
    @Published private(set) var isMonitoring = false
    
    private var workspaceNotificationObserver: NSObjectProtocol?
    private var debounceTimer: Timer?
    // 记录最近处理的应用ID和时间
    private var lastProcessedAppInfo: (bundleId: String, timestamp: Date)?
    // 记录最近处理的窗口位置和大小，用于识别窗口
    private var lastProcessedWindowSignature: (position: CGPoint, size: CGSize)?
    // 处理操作锁，防止并发处理
    private var isProcessing = false
    // 防重处理的最小时间间隔（秒）
    private let minProcessingInterval: TimeInterval = 2.0
    // 锁定机制，防止循环触发
    private var isOperatingWindow = false
    // 操作后冷却期
    private var cooldownEndTime: Date?
    
    init() {
        requestAccessibilityPermission()
        // 不再在初始化时自动启动监控
        // startMonitoring()
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
        lastProcessedAppInfo = nil
        lastProcessedWindowSignature = nil
        isProcessing = false
        isOperatingWindow = false
        cooldownEndTime = nil
        
        // 监听窗口焦点变化
        workspaceNotificationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            
            AppLogger.shared.log("检测到应用切换:", level: .debug)
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            AppLogger.shared.log("应用切换事件时间: \(Date().timeIntervalSince1970), 应用信息: \(app?.localizedName ?? "未知")", level: .info)
            // 检查是否在冷却期内
            if let cooldownTime = self.cooldownEndTime, Date() < cooldownTime {
                AppLogger.shared.log("窗口管理器处于冷却期，跳过处理", level: .debug)
                return
            }
            
            // 检查是否在窗口操作中
            if self.isOperatingWindow {
                AppLogger.shared.log("窗口正在被操作中，跳过处理", level: .debug)
                return
            }
            
            // 获取当前活动的应用
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
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
        
        // 防止并发处理
        if isProcessing {
            AppLogger.shared.log("【防重处理】跳过应用 \(appName) (\(bundleId))：已有窗口处理任务在执行", level: .info)
            return
        }
        
        // 检查是否最近刚处理过该应用 - 使用更严格的时间限制
        if let lastInfo = lastProcessedAppInfo,
           lastInfo.bundleId == bundleId,
           Date().timeIntervalSince(lastInfo.timestamp) < minProcessingInterval {
            AppLogger.shared.log("【防重处理】跳过应用 \(appName) (\(bundleId))：距离上次处理时间不足 \(minProcessingInterval) 秒", level: .info)
            return
        }
        
        // 标记正在处理中
        isProcessing = true
        
        // 立即更新最近处理的应用信息，防止在debounce期间多次触发
        lastProcessedAppInfo = (bundleId: bundleId, timestamp: Date())
        AppLogger.shared.log("【防重处理】标记应用 \(appName) (\(bundleId)) 为处理中", level: .debug)
        
        // 创建新的延迟计时器
        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceTime, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.manageWindow(for: app)
            // 处理完成后重置处理标志
            self.isProcessing = false
        }
    }
    
    private func manageWindow(for app: NSRunningApplication) {
        guard let appName = app.localizedName,
              let bundleId = app.bundleIdentifier else {
            AppLogger.shared.log("无法获取应用信息", level: .warning)
            isProcessing = false
            return
        }
        
        // 获取应用规则
        let rule = AppConfig.shared.getRule(for: bundleId, appName: appName)
        
        // 根据规则处理窗口
        switch rule {
        case .center:
            if let window = getFrontmostWindow(for: app) {
                // 生成窗口特征（位置+大小作为唯一标识）
                let windowSignature = getWindowSignature(window)
                
                if let signature = windowSignature {
                    // 检查是否与上次处理的窗口特征相同
                    if let lastSignature = lastProcessedWindowSignature,
                       abs(lastSignature.position.x - signature.position.x) < 5 &&
                       abs(lastSignature.position.y - signature.position.y) < 5 &&
                       abs(lastSignature.size.width - signature.size.width) < 5 &&
                       abs(lastSignature.size.height - signature.size.height) < 5 {
                        AppLogger.shared.log("跳过窗口：已处理过相同位置和大小的窗口", level: .info)
                        return
                    }
                    
                    // 记录窗口特征
                    lastProcessedWindowSignature = signature
                    AppLogger.shared.log("处理窗口，位置: (\(signature.position.x), \(signature.position.y)), 大小: \(signature.size.width) x \(signature.size.height)", level: .debug)
                }
                
                AppLogger.shared.log("管理应用: \(appName) (\(bundleId)) - 居中处理", level: .info)
                
                // 标记窗口正在被操作，防止操作过程中的事件触发新的处理
                isOperatingWindow = true
                
                // 执行窗口操作
                centerWindow(window)
                
                // 设置冷却期，避免操作完窗口后立即被再次处理
                cooldownEndTime = Date().addingTimeInterval(minProcessingInterval)
                
                // 延迟重置操作标志，给系统时间处理可能的事件
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.isOperatingWindow = false
                }
            } else {
                AppLogger.shared.log("应用 \(appName) 没有活动窗口，无法执行居中操作", level: .debug)
            }
            
        case .almostMaximize:
            if let window = getFrontmostWindow(for: app) {
                // 生成窗口特征（位置+大小作为唯一标识）
                let windowSignature = getWindowSignature(window)
                
                if let signature = windowSignature {
                    // 检查是否与上次处理的窗口特征相同
                    if let lastSignature = lastProcessedWindowSignature,
                       abs(lastSignature.position.x - signature.position.x) < 5 &&
                       abs(lastSignature.position.y - signature.position.y) < 5 &&
                       abs(lastSignature.size.width - signature.size.width) < 5 &&
                       abs(lastSignature.size.height - signature.size.height) < 5 {
                        AppLogger.shared.log("跳过窗口：已处理过相同位置和大小的窗口", level: .info)
                        return
                    }
                    
                    // 记录窗口特征
                    lastProcessedWindowSignature = signature
                    AppLogger.shared.log("处理窗口，位置: (\(signature.position.x), \(signature.position.y)), 大小: \(signature.size.width) x \(signature.size.height)", level: .debug)
                }
                
                AppLogger.shared.log("管理应用: \(appName) (\(bundleId)) - 几乎最大化处理", level: .info)
                
                // 标记窗口正在被操作，防止操作过程中的事件触发新的处理
                isOperatingWindow = true
                
                // 执行窗口操作
                almostMaximizeWindow(window)
                
                // 设置冷却期，避免操作完窗口后立即被再次处理
                cooldownEndTime = Date().addingTimeInterval(minProcessingInterval)
                
                // 延迟重置操作标志，给系统时间处理可能的事件
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.isOperatingWindow = false
                }
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
    
    // 获取窗口所在的屏幕的简单方法
    private func getScreenForWindow(_ window: AXUIElement) -> NSScreen {
        AppLogger.shared.log("开始查找窗口所在屏幕", level: .debug)
        
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
                
                // 获取主屏幕尺寸，用于坐标系转换
                guard let mainScreen = NSScreen.screens.first else {
                    AppLogger.shared.log("无法获取主屏幕", level: .error)
                    return NSScreen.main ?? NSScreen.screens.first!
                }
                
                // 记录所有屏幕
                AppLogger.shared.log("系统有 \(NSScreen.screens.count) 个屏幕", level: .debug)
                for (index, screen) in NSScreen.screens.enumerated() {
                    let frame = screen.frame
                    AppLogger.shared.log("屏幕\(index): \(screen.localizedName), 坐标: \(frame.origin.x), \(frame.origin.y), 大小: \(frame.width) x \(frame.height)", level: .debug)
                }
                
                // 转换坐标系 - AXUIElement使用左上角为原点，Y轴向下；NSScreen使用左下角为原点，Y轴向上
                // 先将AX坐标转换为flipped坐标（相对于主屏幕左上角）
                let flippedYCoordinate = position.y
                
                // 计算窗口中心点（在flipped坐标系中）
                let centerPoint = CGPoint(x: position.x + size.width/2, y: flippedYCoordinate + size.height/2)
                
                AppLogger.shared.log("窗口中心点(flipped坐标系): (\(centerPoint.x), \(centerPoint.y))", level: .debug)
                
                // 创建一个NSPoint用于坐标系转换
                var nsPoint = NSPoint(x: centerPoint.x, y: centerPoint.y)
                
                // 检查窗口是否在任一屏幕的坐标范围内
                // 注意：我们需要为每个屏幕单独计算坐标
                for screen in NSScreen.screens {
                    // 计算屏幕在flipped坐标系中的边界
                    let screenFrame = screen.frame
                    
                    // 计算屏幕在flipped坐标系中的坐标范围
                    let flippedScreenMinY = mainScreen.frame.height - (screenFrame.origin.y + screenFrame.height)
                    let flippedScreenMaxY = mainScreen.frame.height - screenFrame.origin.y
                    
                    // 在flipped坐标系中的屏幕坐标范围
                    let screenMinX = screenFrame.origin.x
                    let screenMaxX = screenFrame.origin.x + screenFrame.width
                    let screenMinY = flippedScreenMinY
                    let screenMaxY = flippedScreenMaxY
                    
                    AppLogger.shared.log("检查屏幕: \(screen.localizedName), flipped坐标系 - X范围: \(screenMinX)..\(screenMaxX), Y范围: \(screenMinY)..\(screenMaxY)", level: .debug)
                    
                    if centerPoint.x >= screenMinX && centerPoint.x <= screenMaxX &&
                       centerPoint.y >= screenMinY && centerPoint.y <= screenMaxY {
                        AppLogger.shared.log("找到窗口所在屏幕: \(screen.localizedName) (通过flipped坐标系匹配)", level: .info)
                        return screen
                    }
                }
                
                // 如果找不到精确匹配，使用更健壮的方法 - 将AX坐标转换为屏幕坐标系
                AppLogger.shared.log("通过flipped坐标系未找到匹配屏幕，尝试使用边界匹配", level: .debug)
                
                // 使用屏幕ID和边界检查
                for screen in NSScreen.screens {
                    // 获取屏幕描述信息 - 注意deviceDescription不是可选类型
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
                
                // 如果仍然无法找到，则使用备选方法
                // 如果找不到精确匹配，改进最接近屏幕算法
                var bestScreen: NSScreen? = nil
                var maxOverlapArea: CGFloat = 0
                
                // 计算窗口区域
                let windowRect = CGRect(x: position.x, y: flippedYCoordinate, width: size.width, height: size.height)
                
                for screen in NSScreen.screens {
                    // 转换屏幕区域到flipped坐标系
                    let screenOriginY = mainScreen.frame.height - (screen.frame.origin.y + screen.frame.height)
                    let flippedScreenRect = CGRect(
                        x: screen.frame.origin.x,
                        y: screenOriginY,
                        width: screen.frame.width,
                        height: screen.frame.height
                    )
                    
                    // 计算与每个屏幕的重叠区域
                    let intersection = windowRect.intersection(flippedScreenRect)
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
                
                // 如果仍然没有匹配，则根据窗口位置选择屏幕
                // 查找与窗口中心点最近的屏幕
                var closestScreen = NSScreen.screens.first!
                var minDistance = CGFloat.greatestFiniteMagnitude
                
                for screen in NSScreen.screens {
                    // 转换屏幕中心点到flipped坐标系
                    let screenOriginY = mainScreen.frame.height - (screen.frame.origin.y + screen.frame.height)
                    let screenCenterFlipped = CGPoint(
                        x: screen.frame.origin.x + screen.frame.width / 2,
                        y: screenOriginY + screen.frame.height / 2
                    )
                    
                    let distance = hypot(centerPoint.x - screenCenterFlipped.x, centerPoint.y - screenCenterFlipped.y)
                    AppLogger.shared.log("屏幕 \(screen.localizedName) 在flipped坐标系中距离窗口中心点距离: \(distance)", level: .debug)
                    if distance < minDistance {
                        minDistance = distance
                        closestScreen = screen
                    }
                }
                
                AppLogger.shared.log("使用距离窗口中心点最近的屏幕: \(closestScreen.localizedName)", level: .info)
                return closestScreen
            }
        }
        
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
    
    private func centerWindow(_ window: AXUIElement) {
        AppLogger.shared.log("开始居中窗口操作", level: .debug)
        
        // 直接获取窗口所在的屏幕
        let currentScreen = getScreenForWindow(window)
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
        
        // 获取主屏幕高度（用于坐标系转换）
        guard let mainScreen = NSScreen.screens.first else {
            AppLogger.shared.log("无法获取主屏幕", level: .error)
            return
        }
        let mainScreenHeight = mainScreen.frame.height
        
        // 计算居中位置，考虑 Stage Manager 的情况
        // Stage Manager 通常会在左右两侧预留空间，我们估计大约是屏幕宽度的 15%
        let stageManagerSideMargin = screenFrame.width * 0.15
        let usableScreenWidth = screenFrame.width - (stageManagerSideMargin * 2)
        
        // 计算新位置 (NSScreen坐标系，原点在左下角，Y轴向上)
        let nsScreenX = screenFrame.origin.x + stageManagerSideMargin + (usableScreenWidth - windowSize.width) / 2
        let nsScreenY = screenFrame.origin.y + (screenFrame.height - windowSize.height) / 2
        
        // 将NSScreen坐标系转换为AXUIElement坐标系（原点在左上角，Y轴向下）
        // 只需要转换Y坐标: AX_Y = MainScreenHeight - NSScreen_Y - WindowHeight
        // 对于多显示器情况，我们需要考虑相对于主屏幕的位置
        var newPosition = CGPoint(
            x: nsScreenX,
            y: mainScreenHeight - nsScreenY - windowSize.height
        )
        
        AppLogger.shared.log("计算的新位置 - NSScreen坐标: (\(nsScreenX), \(nsScreenY))", level: .debug)
        AppLogger.shared.log("转换后的AX坐标: (\(newPosition.x), \(newPosition.y))", level: .debug)
        
        // 创建新位置的 AXValue
        guard let axPosition = AXValueCreate(.cgPoint, &newPosition) else {
            AppLogger.shared.log("创建位置 AXValue 失败", level: .error)
            return
        }
        
        // 设置新位置
        let setPositionResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axPosition)
        
        if setPositionResult == .success {
            AppLogger.shared.log("窗口已成功居中，新位置(AX坐标系): (\(newPosition.x), \(newPosition.y))", level: .info)
        } else {
            AppLogger.shared.log("设置窗口位置失败: \(setPositionResult.rawValue)", level: .error)
        }
    }
    
    private func almostMaximizeWindow(_ window: AXUIElement) {
        AppLogger.shared.log("开始几乎最大化窗口操作", level: .debug)
        
        // 直接获取窗口所在的屏幕
        let currentScreen = getScreenForWindow(window)
        AppLogger.shared.log("使用屏幕: \(currentScreen.localizedName), frame: \(currentScreen.frame)", level: .debug)
        
        // 获取主屏幕高度（用于坐标系转换）
        guard let mainScreen = NSScreen.screens.first else {
            AppLogger.shared.log("无法获取主屏幕", level: .error)
            return
        }
        let mainScreenHeight = mainScreen.frame.height
        
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
        
        // 计算新的框架，Y坐标从状态栏下方开始 (NSScreen坐标系)
        let nsFrameX = screenFrame.origin.x + horizontalMargin
        let nsFrameY = screenFrame.origin.y + statusBarHeight + verticalMargin
        let nsFrameWidth = screenFrame.width - (horizontalMargin * 2)
        let nsFrameHeight = screenFrame.height - statusBarHeight - (verticalMargin * 2)
        
        // 将位置从NSScreen坐标系转换为AXUIElement坐标系
        let axPositionX = nsFrameX
        let axPositionY = mainScreenHeight - nsFrameY - nsFrameHeight
        
        // 创建新位置的 AXValue (AXUIElement坐标系)
        var newPosition = CGPoint(x: axPositionX, y: axPositionY)
        guard let axPosition = AXValueCreate(.cgPoint, &newPosition) else {
            AppLogger.shared.log("创建位置 AXValue 失败", level: .error)
            return
        }
        
        // 创建新大小的 AXValue
        var newSize = CGSize(width: nsFrameWidth, height: nsFrameHeight)
        guard let axSize = AXValueCreate(.cgSize, &newSize) else {
            AppLogger.shared.log("创建大小 AXValue 失败", level: .error)
            return
        }
        
        AppLogger.shared.log("NSScreen坐标系位置: (\(nsFrameX), \(nsFrameY)), 大小: \(nsFrameWidth) x \(nsFrameHeight)", level: .debug)
        AppLogger.shared.log("转换后的AX坐标系位置: (\(axPositionX), \(axPositionY)), 大小: \(nsFrameWidth) x \(nsFrameHeight)", level: .debug)
        
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