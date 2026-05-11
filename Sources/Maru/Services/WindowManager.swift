import Cocoa
import Combine
import ApplicationServices

// MARK: - 增加辅助功能相关常量定义
// 系统没有公开kAXEnhancedUserInterfaceAttribute常量，所以我们需要自己定义
let kAXEnhancedUserInterfaceAttribute = "AXEnhancedUserInterface" as CFString

struct AccessibilityPermissionFlowState {
    private(set) var hasRequestedPermission = false
    private(set) var hasHandledPermissionGrant = false

    mutating func reservePermissionRequest() -> Bool {
        guard !hasRequestedPermission else {
            return false
        }

        hasRequestedPermission = true
        return true
    }

    mutating func reservePermissionGrantHandling() -> Bool {
        guard !hasHandledPermissionGrant else {
            return false
        }

        hasHandledPermissionGrant = true
        return true
    }
}

enum AccessibilityPermissionGrantedAlertContent {
    static let title = "辅助功能权限已开启"
    static let message = "Maru 已开始管理窗口。"
    static let confirmButtonTitle = "知道了"
}

class WindowManager: ObservableObject {
    // 延迟时间（秒）
    private let debounceTime: TimeInterval = 0.3
    
    @Published private(set) var isMonitoring = false
    
    private var workspaceNotificationObserver: NSObjectProtocol?
    private var manualWindowActionObserver: NSObjectProtocol?
    private var debounceTimer: Timer?
    
    // 简化防重机制
    // 记录最近处理的窗口信息
    private var lastProcessedWindowInfo: (bundleId: String, timestamp: Date)?
    // 防重处理的最小时间间隔（秒）
    private let minProcessingInterval: TimeInterval = 1.5
    // 窗口操作状态标记
    private var isWindowOperationInProgress = false
    private var activationMouseLocation: CGPoint?  // 激活通知时的鼠标位置,避免300ms防抖后移动
    private var accessibilityPermissionFlowState = AccessibilityPermissionFlowState()
    private var accessibilityPermissionPollingTimer: Timer?
    private var accessibilityPermissionPollingAttemptsRemaining = 0
    private let maxAccessibilityPermissionPollingAttempts = 120
    private let runningApplicationResolver: (pid_t) -> NSRunningApplication?

    init(runningApplicationResolver: @escaping (pid_t) -> NSRunningApplication? = { NSRunningApplication(processIdentifier: $0) }) {
        self.runningApplicationResolver = runningApplicationResolver
        // Don't request permissions during init - wait for app to launch
    }
    
    deinit {
        accessibilityPermissionPollingTimer?.invalidate()
        stopMonitoring()
    }
    
    // 检查并请求辅助功能权限
    func checkAccessibilityPermission() -> Bool {
        let accessEnabled = AXIsProcessTrusted()
        
        if !accessEnabled {
            AppLogger.shared.log("需要辅助功能权限来管理窗口", level: .warning)
            return false
        }
        return true
    }
    
    // 显示系统辅助功能权限请求（在主线程安全调用）
    func showAccessibilityPermissionAlert() {
        guard accessibilityPermissionFlowState.reservePermissionRequest() else {
            AppLogger.shared.log("辅助功能权限提示已显示过，跳过重复提示", level: .debug)
            return
        }

        DispatchQueue.main.async { [weak self] in
            AppLogger.shared.log("请求系统辅助功能权限提示", level: .info)
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
            self?.beginAccessibilityPermissionGrantPolling()
        }
    }

    private func beginAccessibilityPermissionGrantPolling() {
        accessibilityPermissionPollingTimer?.invalidate()
        accessibilityPermissionPollingAttemptsRemaining = maxAccessibilityPermissionPollingAttempts

        accessibilityPermissionPollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            guard self.accessibilityPermissionPollingAttemptsRemaining > 0 else {
                AppLogger.shared.log("辅助功能权限授权轮询超时，等待用户下次启动", level: .debug)
                timer.invalidate()
                self.accessibilityPermissionPollingTimer = nil
                return
            }

            self.accessibilityPermissionPollingAttemptsRemaining -= 1

            guard AXIsProcessTrusted() else {
                return
            }

            timer.invalidate()
            self.accessibilityPermissionPollingTimer = nil
            self.handleAccessibilityPermissionGranted()
        }
    }

    private func handleAccessibilityPermissionGranted() {
        guard accessibilityPermissionFlowState.reservePermissionGrantHandling() else {
            AppLogger.shared.log("辅助功能权限授权后处理已执行过，跳过重复处理", level: .debug)
            return
        }

        AppLogger.shared.log("辅助功能权限已开启，开始窗口管理", level: .info)
        startMonitoring()
        showAccessibilityPermissionGrantedAlert()
    }

    private func showAccessibilityPermissionGrantedAlert() {
        MaruApplicationActivation.activateForTextInput()

        let alert = NSAlert()
        alert.messageText = AccessibilityPermissionGrantedAlertContent.title
        alert.informativeText = AccessibilityPermissionGrantedAlertContent.message
        alert.alertStyle = .informational
        alert.addButton(withTitle: AccessibilityPermissionGrantedAlertContent.confirmButtonTitle)
        alert.runModal()
    }
    
    func startMonitoring() {
        // 检查辅助功能权限
        if !checkAccessibilityPermission() {
            showAccessibilityPermissionAlert()
            return
        }
        
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

        manualWindowActionObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("manualWindowActionRequested"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard let action = notification.object as? ManualWindowAction else {
                AppLogger.shared.log("收到手动窗口操作通知，但缺少有效动作对象", level: .warning)
                return
            }

            let triggerSource = (notification.userInfo?["triggerSource"] as? String) ?? "NotificationCenter.manualWindowActionRequested"
            switch action {
            case .center:
                self.performManualCenter(triggerSource: triggerSource)
            case .almostMaximize:
                self.performManualAlmostMaximize(triggerSource: triggerSource)
            case .moveToNextDisplay:
                self.performManualMoveToNextDisplay(triggerSource: triggerSource)
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

        if let observer = manualWindowActionObserver {
            NotificationCenter.default.removeObserver(observer)
            manualWindowActionObserver = nil
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
        
        // 在通知到达时捕获鼠标位置(避免300ms防抖后鼠标已移走)
        let capturedMouseLocation = NSEvent.mouseLocation

        // 创建新的延迟计时器
        let scheduledAt = Date()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceTime, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.activationMouseLocation = capturedMouseLocation
            let elapsedMs = Int(Date().timeIntervalSince(scheduledAt) * 1000)
            AppLogger.shared.log("防抖结束(\(elapsedMs)ms),开始处理 \(appName)", level: .debug)
            self.manageWindow(for: app)
        }
    }
    
    private func manageWindow(for app: NSRunningApplication) {
        guard let appName = app.localizedName,
              let bundleId = app.bundleIdentifier else {
            AppLogger.shared.log("无法获取应用信息", level: .warning)
            return
        }

        let runningDuration = Date().timeIntervalSince(app.launchDate ?? Date())
        AppLogger.shared.log("应用 \(appName) 已运行 \(String(format: "%.1f", runningDuration))s", level: .debug)
        
        // 获取应用规则
        let rule = AppConfig.shared.getRule(for: bundleId, appName: appName)
        
        // 根据规则处理窗口
        switch rule {
        case .center, .almostMaximize:
            processWindowWithRule(app: app, bundleId: bundleId, appName: appName, rule: rule)
            
        case .ignore:
            AppLogger.shared.log("忽略应用: \(appName) (\(bundleId))", level: .debug)
        }
    }
    
    /// 处理需要调整位置的窗口
    private func processWindowWithRule(app: NSRunningApplication, bundleId: String, appName: String, rule: WindowHandlingRule) {
        let windows = findWindowsToManage(for: app)
        guard !windows.isEmpty else {
            AppLogger.shared.log("应用 \(appName) 没有活动窗口，无法执行操作", level: .debug)
            scheduleWindowRetry(for: app, bundleId: bundleId, appName: appName, rule: rule, attempt: 1)
            return
        }

        if windows.count > 1 {
            AppLogger.shared.log("将依次处理 \(windows.count) 个同屏窗口", level: .info)
        }
        AppLogger.shared.log("处理应用: \(appName) (\(bundleId)), 规则: \(rule)", level: .info)

        isWindowOperationInProgress = true
        processWindowsSequentially(windows, at: 0, app: app, bundleId: bundleId, appName: appName, rule: rule)
    }

    /// 顺序处理一批窗口,只在最后一个完成时调 handleWindowOperationCompletion
    private func processWindowsSequentially(_ windows: [AXUIElement], at index: Int, app: NSRunningApplication, bundleId: String, appName: String, rule: WindowHandlingRule) {
        let appIdentity = "\(appName) (\(bundleId), pid: \(app.processIdentifier))"
        let actionLabel = rule == .center ? "居中" : "几乎最大化"

        guard index < windows.count else {
            // 全部处理完毕
            handleWindowOperationCompletion(success: true, bundleId: bundleId, triggerSource: "automatic", actionLabel: actionLabel, appIdentity: appIdentity)
            return
        }

        let window = windows[index]
        guard let signature = getWindowSignature(window) else {
            AppLogger.shared.log("窗口[\(index)] 无法获取特征,跳过", level: .warning)
            processWindowsSequentially(windows, at: index + 1, app: app, bundleId: bundleId, appName: appName, rule: rule)
            return
        }
        AppLogger.shared.log("处理窗口[\(index)]: pos=(\(signature.position.x),\(signature.position.y)) size=(\(signature.size.width)x\(signature.size.height))", level: .debug)

        let onComplete: (Bool) -> Void = { [weak self] _ in
            self?.processWindowsSequentially(windows, at: index + 1, app: app, bundleId: bundleId, appName: appName, rule: rule)
        }

        switch rule {
        case .center:
            centerWindow(window, completion: onComplete)
        case .almostMaximize:
            almostMaximizeWindow(window, completion: onComplete)
        default:
            // 不会发生,直接进入下一个
            onComplete(false)
        }
    }

    private func scheduleWindowRetry(for app: NSRunningApplication, bundleId: String, appName: String, rule: WindowHandlingRule, attempt: Int) {
        let delays = [0.3, 0.5, 0.8, 1.2]
        guard attempt <= delays.count else {
            AppLogger.shared.log("[重试] \(appName) 全部 \(delays.count) 次重试失败,放弃", level: .debug)
            return
        }

        let delay = delays[attempt - 1]
        let pid = app.processIdentifier
        AppLogger.shared.log("[重试] \(appName) 将在 \(String(format: "%.1f", delay))s 后重试 (第 \(attempt)/\(delays.count) 次)", level: .debug)

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, self.isMonitoring else { return }

            // 用户已切换到其他应用则取消
            guard let frontmost = NSWorkspace.shared.frontmostApplication,
                  frontmost.processIdentifier == pid else {
                AppLogger.shared.log("[重试#\(attempt)] \(appName) 取消: 用户已切换到其他应用", level: .debug)
                return
            }

            // 有其他窗口操作进行中则放弃本轮
            guard !self.isWindowOperationInProgress else {
                AppLogger.shared.log("[重试#\(attempt)] \(appName) 跳过: 其他窗口操作进行中", level: .debug)
                return
            }

            // 尝试获取窗口
            let windows = self.findWindowsToManage(for: frontmost)
            guard !windows.isEmpty else {
                AppLogger.shared.log("[重试#\(attempt)] \(appName) 仍无窗口,进入下一轮", level: .debug)
                self.scheduleWindowRetry(for: app, bundleId: bundleId, appName: appName, rule: rule, attempt: attempt + 1)
                return
            }

            AppLogger.shared.log("[重试#\(attempt)] \(appName) 成功获取窗口 (\(windows.count) 个,距首次激活已 \(String(format: "%.1f", Date().timeIntervalSince(app.launchDate ?? Date())))s)", level: .info)
            if windows.count > 1 {
                AppLogger.shared.log("将依次处理 \(windows.count) 个同屏窗口", level: .info)
            }
            AppLogger.shared.log("处理应用: \(appName) (\(bundleId)), 规则: \(rule)", level: .info)

            self.isWindowOperationInProgress = true
            self.processWindowsSequentially(windows, at: 0, app: frontmost, bundleId: bundleId, appName: appName, rule: rule)
        }
    }

    func performManualCenter(triggerSource: String) {
        performManualWindowAction(.center, triggerSource: triggerSource)
    }

    func performManualAlmostMaximize(triggerSource: String) {
        performManualWindowAction(.almostMaximize, triggerSource: triggerSource)
    }

    func performManualMoveToNextDisplay(triggerSource: String) {
        performManualWindowAction(.moveToNextDisplay, triggerSource: triggerSource)
    }

    func performManualWindowAction(_ action: ManualWindowAction, target: CurrentAppRuleTarget, triggerSource: String) {
        guard let app = runningApplicationResolver(target.processIdentifier) else {
            AppLogger.shared.log(
                "定向手动窗口操作跳过: 目标进程不可用, 来源=\(triggerSource), 动作=\(action.label), 应用=\(target.appName) (\(target.bundleId), pid: \(target.processIdentifier))",
                level: .warning
            )
            return
        }

        performManualWindowAction(
            action,
            app: app,
            triggerSource: triggerSource,
            showsMissingWindowAlert: false
        )
    }
    
    private func performManualWindowAction(_ action: ManualWindowAction, triggerSource: String) {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            AppLogger.shared.log("手动窗口操作失败: 无法获取前台应用, 来源=\(triggerSource), 动作=\(action.label)", level: .warning)
            showManualWindowNotFoundAlert(triggerSource: triggerSource, appIdentity: nil, action: action)
            return
        }

        performManualWindowAction(
            action,
            app: app,
            triggerSource: triggerSource,
            showsMissingWindowAlert: true
        )
    }

    private func performManualWindowAction(
        _ action: ManualWindowAction,
        app: NSRunningApplication,
        triggerSource: String,
        showsMissingWindowAlert: Bool
    ) {
        guard checkAccessibilityPermission() else {
            showAccessibilityPermissionAlert()
            return
        }

        guard !isWindowOperationInProgress else {
            AppLogger.shared.log("手动窗口操作被跳过: 当前已有窗口操作进行中, 来源=\(triggerSource), 动作=\(action.label)", level: .debug)
            return
        }

        let appIdentity = describeApplication(app)
        AppLogger.shared.log("手动窗口操作请求: 来源=\(triggerSource), 动作=\(action.label), 应用=\(appIdentity)", level: .info)

        guard let window = resolveManualTargetWindow(for: app, triggerSource: triggerSource, action: action) else {
            if showsMissingWindowAlert {
                showManualWindowNotFoundAlert(triggerSource: triggerSource, appIdentity: appIdentity, action: action)
            } else {
                AppLogger.shared.log("定向手动窗口操作未找到可操作窗口: 来源=\(triggerSource), 动作=\(action.label), 应用=\(appIdentity)", level: .warning)
            }
            return
        }

        // 只有在手动操作真正要执行窗口变更时，才取消排队中的自动处理
        debounceTimer?.invalidate()
        debounceTimer = nil

        isWindowOperationInProgress = true

        switch action {
        case .center:
            centerWindow(window, completion: { [weak self] success in
                self?.handleWindowOperationCompletion(success: success, bundleId: app.bundleIdentifier, triggerSource: triggerSource, actionLabel: action.label, appIdentity: appIdentity)
            })
        case .almostMaximize:
            almostMaximizeWindow(window, completion: { [weak self] success in
                self?.handleWindowOperationCompletion(success: success, bundleId: app.bundleIdentifier, triggerSource: triggerSource, actionLabel: action.label, appIdentity: appIdentity)
            })
        case .moveToNextDisplay:
            moveWindowToNextDisplayUsingAppRule(window, app: app, appIdentity: appIdentity, completion: { [weak self] success in
                self?.handleWindowOperationCompletion(success: success, bundleId: app.bundleIdentifier, triggerSource: triggerSource, actionLabel: action.label, appIdentity: appIdentity)
            })
        }
    }

    private func handleWindowOperationCompletion(success: Bool, bundleId: String?, triggerSource: String, actionLabel: String, appIdentity: String) {
        if success, let bundleId {
            lastProcessedWindowInfo = (bundleId: bundleId, timestamp: Date())
            AppLogger.shared.log("窗口操作成功并已写入冷却: 来源=\(triggerSource), 动作=\(actionLabel), 应用=\(appIdentity)", level: .info)
        } else {
            AppLogger.shared.log("窗口操作未成功，未写入冷却: 来源=\(triggerSource), 动作=\(actionLabel), 应用=\(appIdentity)", level: .warning)
        }

        AppLogger.shared.log("手动窗口操作完成: 来源=\(triggerSource), 动作=\(actionLabel), 应用=\(appIdentity)", level: .info)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isWindowOperationInProgress = false
        }
    }

    private func resolveManualTargetWindow(for app: NSRunningApplication, triggerSource: String, action: ManualWindowAction) -> AXUIElement? {
        let appIdentity = describeApplication(app)
        let appRef = AXUIElementCreateApplication(app.processIdentifier)

        var focusedWindowRef: AnyObject?
        if AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &focusedWindowRef) == .success,
           let focusedWindowRef {
            let focusedWindow = focusedWindowRef as! AXUIElement
            if isStandardWindow(focusedWindow) {
                AppLogger.shared.log("手动目标解析成功: 来源=\(triggerSource), 动作=\(action.label), 应用=\(appIdentity), 使用 AXFocusedWindow", level: .info)
                return focusedWindow
            } else {
                AppLogger.shared.log("手动目标解析: 来源=\(triggerSource), 动作=\(action.label), 应用=\(appIdentity), AXFocusedWindow 不可操作，尝试同应用窗口列表", level: .debug)
            }
        } else {
            AppLogger.shared.log("手动目标解析: 来源=\(triggerSource), 动作=\(action.label), 应用=\(appIdentity), 未获取到 AXFocusedWindow，尝试同应用窗口列表", level: .debug)
        }

        var windowsRef: AnyObject?
        guard AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windowArray = windowsRef as? [AXUIElement] else {
            AppLogger.shared.log("手动目标解析失败: 来源=\(triggerSource), 动作=\(action.label), 应用=\(appIdentity), 无法获取窗口列表", level: .warning)
            return nil
        }

        for window in windowArray {
            guard isStandardWindow(window) else { continue }

            AppLogger.shared.log("手动目标解析成功: 来源=\(triggerSource), 动作=\(action.label), 应用=\(appIdentity), 使用同应用第一个非最小化标准窗口", level: .info)
            return window
        }

        AppLogger.shared.log("手动目标解析失败: 来源=\(triggerSource), 动作=\(action.label), 应用=\(appIdentity), 未找到可操作窗口", level: .warning)
        return nil
    }

    private func isStandardWindow(_ window: AXUIElement) -> Bool {
        guard !isWindowMinimized(window) else {
            return false
        }

        var subroleRef: AnyObject?
        if AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subroleRef) == .success,
           let subrole = subroleRef as? String {
            return subrole == (kAXStandardWindowSubrole as String)
        }

        return false
    }

    private func isWindowMinimized(_ window: AXUIElement) -> Bool {
        var minimizedRef: AnyObject?
        guard AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedRef) == .success else {
            return false
        }

        return (minimizedRef as? Bool) == true
    }

    private func describeApplication(_ app: NSRunningApplication) -> String {
        let appName = app.localizedName ?? "未知"
        let bundleId = app.bundleIdentifier ?? "未知BundleID"
        return "\(appName) (\(bundleId), pid: \(app.processIdentifier))"
    }

    private func describePid(_ pid: pid_t) -> String {
        if let app = NSRunningApplication(processIdentifier: pid) {
            return "\(pid)(\(app.localizedName ?? app.bundleIdentifier ?? "?"))"
        }
        return "\(pid)(已退出或不可见)"
    }

    private func axErrorDescription(_ error: AXError) -> String {
        switch error {
        case .success: return "success"
        case .failure: return "failure"
        case .illegalArgument: return "illegalArgument"
        case .invalidUIElement: return "invalidUIElement"
        case .invalidUIElementObserver: return "invalidUIElementObserver"
        case .cannotComplete: return "cannotComplete"
        case .attributeUnsupported: return "attributeUnsupported"
        case .actionUnsupported: return "actionUnsupported"
        case .notificationUnsupported: return "notificationUnsupported"
        case .notImplemented: return "notImplemented"
        case .notificationAlreadyRegistered: return "notificationAlreadyRegistered"
        case .notificationNotRegistered: return "notificationNotRegistered"
        case .apiDisabled: return "apiDisabled"
        case .noValue: return "noValue"
        case .parameterizedAttributeUnsupported: return "parameterizedAttributeUnsupported"
        case .notEnoughPrecision: return "notEnoughPrecision"
        @unknown default: return "unknown(\(error.rawValue))"
        }
    }

    private func showManualWindowNotFoundAlert(triggerSource: String, appIdentity: String?, action: ManualWindowAction) {
        DispatchQueue.main.async {
            AppLogger.shared.log("手动窗口操作未找到可操作窗口: 来源=\(triggerSource), 动作=\(action.label), 应用=\(appIdentity ?? "未知应用")", level: .warning)

            let alert = NSAlert()
            alert.messageText = "无法找到可操作的窗口"
            alert.informativeText = "当前前台应用没有活动窗口，或该窗口不支持窗口管理。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
    }
    
    // 获取应用要处理的窗口列表(返回空数组表示未找到,绝大多数路径返回单元素数组)
    // 策略:
    //   1. 查 kAXWindowsAttribute 数标准窗口
    //      - 0 个 → 尝试 focusedWindow / 鼠标 fallback(冷启动或 Finder 类)
    //      - 1 个 → 直接返回(单窗口,最可靠)
    //      - >1 个 → mouseHit → 几何匹配 → 同屏匹配(可返回多个) → focusedWindow → 第一个标准窗口
    //   2. kAXWindowsAttribute 失败(cannotComplete) → focusedWindow + 鼠标 fallback,仍失败则走重试链
    private func findWindowsToManage(for app: NSRunningApplication) -> [AXUIElement] {
        AppLogger.shared.log("开始查找应用 \(describeApplication(app)) 的前台窗口", level: .debug)

        if let bundleId = app.bundleIdentifier {
            let allInstances = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            if allInstances.count > 1 {
                let pids = allInstances.map { String($0.processIdentifier) }.joined(separator: ", ")
                AppLogger.shared.log("注意:\(app.localizedName ?? "?") 有 \(allInstances.count) 个实例 (PIDs: \(pids))", level: .debug)
            }
        }

        let appRef = AXUIElementCreateApplication(app.processIdentifier)

        // 查询窗口列表
        var windowsRef: AnyObject?
        let windowsErr = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsRef)

        if windowsErr == .success, let windowArray = windowsRef as? [AXUIElement] {
            let standardWindows = windowArray.filter { isStandardWindow($0) }

            // 日志: 所有窗口的 subrole
            for (idx, window) in windowArray.enumerated() {
                var subroleRef: AnyObject?
                let subrole = (AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subroleRef) == .success ? subroleRef as? String : nil) ?? "nil"
                AppLogger.shared.log("窗口[\(idx)]: subrole=\(subrole), isStandard=\(standardWindows.contains(where: { $0 === window }))", level: .debug)
            }

            switch standardWindows.count {
            case 0:
                // 无标准窗口(Finder Desktop 等) → 尝试 focusedWindow + 鼠标
                AppLogger.shared.log("0 个标准窗口,尝试 focusedWindow/鼠标 fallback", level: .debug)
                return findWindowViaFocusedAndMouse(app: app, appRef: appRef)

            case 1:
                // 单窗口,直接使用,不需要纠结焦点或鼠标
                AppLogger.shared.log("单窗口应用,直接使用", level: .info)
                return [standardWindows[0]]

            default:
                // 多窗口: 鼠标定位优先,因为焦点窗口不可信
                AppLogger.shared.log("多窗口应用(\(standardWindows.count)个),鼠标定位优先", level: .info)

                // 1) 鼠标 hit-test
                if let mouseWindow = windowOfAppAtMouse(app) {
                    AppLogger.shared.log("鼠标 hit-test 成功", level: .info)
                    return [mouseWindow]
                }

                // 2) 几何匹配: 鼠标是否在某个窗口范围内(用激活时的鼠标位置)
                let mouseLocation = activationMouseLocation ?? NSEvent.mouseLocation
                let axMouseLocation = convertToAXCoordinates(mouseLocation)
                AppLogger.shared.log("几何匹配: 鼠标 AX=\(axMouseLocation)", level: .debug)
                for (idx, window) in standardWindows.enumerated() {
                    if let (pos, size) = getWindowPositionAndSize(window) {
                        let frame = CGRect(x: pos.x, y: pos.y, width: size.width, height: size.height)
                        let contains = frame.contains(axMouseLocation)
                        AppLogger.shared.log("几何匹配 窗口[\(idx)]: pos=(\(pos.x),\(pos.y)) size=(\(size.width)x\(size.height)) frame=\(frame), containsMouse=\(contains)", level: .debug)
                        if contains {
                            AppLogger.shared.log("几何匹配成功 [\(idx)]", level: .info)
                            return [window]
                        }
                    } else {
                        AppLogger.shared.log("几何匹配 窗口[\(idx)]: 无法获取位置/大小", level: .debug)
                    }
                }
                AppLogger.shared.log("几何匹配也失败,尝试同屏匹配", level: .debug)

                // 3) 同屏匹配: 找出鼠标所在屏幕上的所有 standardWindows(可能多个)
                let sameScreenWindows = windowsOnSameScreenAsMouse(standardWindows: standardWindows, mouseLocation: mouseLocation)
                if !sameScreenWindows.isEmpty {
                    return sameScreenWindows
                }

                // 4) focusedWindow
                var focusedRef: AnyObject?
                if AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &focusedRef) == .success,
                   let focused = focusedRef, isStandardWindow(focused as! AXUIElement) {
                    AppLogger.shared.log("回退到 focusedWindow", level: .info)
                    return [focused as! AXUIElement]
                }

                // 5) 第一个标准窗口
                AppLogger.shared.log("focusedWindow 也失败,使用窗口列表第一个标准窗口", level: .debug)
                return [standardWindows[0]]
            }
        }

        // kAXWindowsAttribute 失败(cannotComplete 等) → focusedWindow + 鼠标,仍失败则走重试链
        AppLogger.shared.log("kAXWindowsAttribute 失败 (Error: \(axErrorDescription(windowsErr))),尝试 focusedWindow/鼠标 fallback", level: .debug)
        return findWindowViaFocusedAndMouse(app: app, appRef: appRef)
    }

    /// 同屏匹配: 找出鼠标所在屏幕上的所有 standardWindows(命中可能多个)
    private func windowsOnSameScreenAsMouse(standardWindows: [AXUIElement], mouseLocation: CGPoint) -> [AXUIElement] {
        guard let mouseScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) else {
            AppLogger.shared.log("同屏匹配: 无法确定鼠标所在屏幕", level: .debug)
            return []
        }
        AppLogger.shared.log("同屏匹配: 鼠标在屏幕 \(mouseScreen.localizedName)", level: .debug)

        // 把 mouseScreen 边界换算到 AX 坐标系(Y 轴翻转,以主屏高度为基准)
        guard let mainScreenHeight = NSScreen.screens.first?.frame.height else {
            return []
        }
        let axScreenMinX = mouseScreen.frame.origin.x
        let axScreenMaxX = mouseScreen.frame.origin.x + mouseScreen.frame.width
        let axScreenMinY = mainScreenHeight - (mouseScreen.frame.origin.y + mouseScreen.frame.height)
        let axScreenMaxY = mainScreenHeight - mouseScreen.frame.origin.y

        let matched = standardWindows.filter { window in
            guard let (pos, size) = getWindowPositionAndSize(window) else { return false }
            let cx = pos.x + size.width / 2
            let cy = pos.y + size.height / 2
            return cx >= axScreenMinX && cx <= axScreenMaxX && cy >= axScreenMinY && cy <= axScreenMaxY
        }
        if !matched.isEmpty {
            AppLogger.shared.log("同屏匹配成功: \(mouseScreen.localizedName) 上找到 \(matched.count) 个窗口", level: .info)
        } else {
            AppLogger.shared.log("同屏匹配: \(mouseScreen.localizedName) 上无该应用窗口", level: .debug)
        }
        return matched
    }

    /// kAXWindowsAttribute 不可用时(failed/0-window)的兜底: focusedWindow → 鼠标 hit-test → 几何匹配
    private func findWindowViaFocusedAndMouse(app: NSRunningApplication, appRef: AXUIElement) -> [AXUIElement] {
        var focusedRef: AnyObject?
        if AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &focusedRef) == .success,
           let focused = focusedRef, isStandardWindow(focused as! AXUIElement) {
            AppLogger.shared.log("focusedWindow fallback 成功", level: .info)
            return [focused as! AXUIElement]
        }

        // 鼠标 hit-test
        let mouseLocation = NSEvent.mouseLocation
        let axMouseLocation = convertToAXCoordinates(mouseLocation)
        AppLogger.shared.log("鼠标 fallback: 屏幕(\(mouseLocation)), AX(\(axMouseLocation))", level: .debug)

        var elementRef: AXUIElement?
        if AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(axMouseLocation.x), Float(axMouseLocation.y), &elementRef) == .success,
           let topElement = elementRef {
            // 向上遍历找标准窗口
            var current = topElement
            for _ in 0..<15 {
                var roleRef: AnyObject?
                AXUIElementCopyAttributeValue(current, kAXRoleAttribute as CFString, &roleRef)
                if let role = roleRef as? String, role == (kAXWindowRole as String), isStandardWindow(current) {
                    var pid: pid_t = 0
                    if AXUIElementGetPid(current, &pid) == .success, pid == app.processIdentifier {
                        AppLogger.shared.log("鼠标 hit-test fallback 成功", level: .info)
                        return [current]
                    }
                    break
                }
                var parentRef: AnyObject?
                guard AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parentRef) == .success,
                      let parent = parentRef else { break }
                current = parent as! AXUIElement
            }
        }

        // 几何匹配(仅当之前窗口列表成功但无标准窗口时重试)
        var retryRef: AnyObject?
        if AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &retryRef) == .success,
           let windows = retryRef as? [AXUIElement] {
            for window in windows where isStandardWindow(window) {
                if let (pos, size) = getWindowPositionAndSize(window) {
                    if CGRect(x: pos.x, y: pos.y, width: size.width, height: size.height).contains(axMouseLocation) {
                        AppLogger.shared.log("几何匹配 fallback 成功", level: .info)
                        return [window]
                    }
                }
            }
        }

        return []
    }

    /// 返回鼠标位置下属于指定应用的标准窗口,或 nil
    private func windowOfAppAtMouse(_ app: NSRunningApplication) -> AXUIElement? {
        let mouseLocation = activationMouseLocation ?? NSEvent.mouseLocation
        let axMouseLocation = convertToAXCoordinates(mouseLocation)

        var elementRef: AXUIElement?
        let hitTestErr = AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(axMouseLocation.x), Float(axMouseLocation.y), &elementRef)
        guard hitTestErr == .success, let topElement = elementRef else {
            AppLogger.shared.log("mouseHit: AXUIElementCopyElementAtPosition 失败 (\(axErrorDescription(hitTestErr)))", level: .debug)
            return nil
        }

        // 记录鼠标下顶层元素
        var topRole: AnyObject?
        AXUIElementCopyAttributeValue(topElement, kAXRoleAttribute as CFString, &topRole)
        AppLogger.shared.log("mouseHit: 顶层 Role=\(topRole as? String ?? "nil"), AX=\(axMouseLocation)", level: .debug)

        var current: AXUIElement = topElement
        for i in 0..<15 {
            var roleRef: AnyObject?
            var subroleRef: AnyObject?
            AXUIElementCopyAttributeValue(current, kAXRoleAttribute as CFString, &roleRef)
            AXUIElementCopyAttributeValue(current, kAXSubroleAttribute as CFString, &subroleRef)
            let roleStr = roleRef as? String ?? "nil"
            let subroleStr = subroleRef as? String ?? "nil"

            if roleStr == (kAXWindowRole as String) {
                if !isStandardWindow(current) {
                    AppLogger.shared.log("mouseHit: [层级 \(i)] 找到窗口但非标准 (subrole=\(subroleStr))", level: .debug)
                    break
                }
                var pid: pid_t = 0
                AXUIElementGetPid(current, &pid)
                if pid == app.processIdentifier {
                    AppLogger.shared.log("mouseHit: [层级 \(i)] 找到目标窗口 PID=\(describePid(pid))", level: .debug)
                    return current
                }
                AppLogger.shared.log("mouseHit: [层级 \(i)] 窗口 PID 不匹配 (窗口=\(describePid(pid)), 目标=\(describePid(app.processIdentifier)))", level: .debug)
                break
            }
            var parentRef: AnyObject?
            guard AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parentRef) == .success,
                  let parent = parentRef else {
                AppLogger.shared.log("mouseHit: [层级 \(i)] \(roleStr)/\(subroleStr) → 无法获取父元素", level: .debug)
                break
            }
            current = parent as! AXUIElement
        }
        AppLogger.shared.log("mouseHit: 遍历结束,未找到目标窗口", level: .debug)
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
        if NSScreen.screens.isEmpty {
            AppLogger.shared.log("无法获取主屏幕", level: .error)
            return nil
        }
        let mainScreen = NSScreen.screens.first!
        
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
        guard NSScreen.screens.first != nil else {
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
    
    // MARK: - 窗口操作方法

    /// 增强型设置窗口位置和大小，解决调整不完全问题
    /// 参考Rectangle的实现，先设置大小、再设置位置、然后再次设置大小
    /// - Parameters:
    ///   - window: 目标窗口
    ///   - frame: 目标位置和大小
    ///   - adjustSizeFirst: 是否先调整大小，默认为true
    ///   - skipVerify: 跳过 100ms 后的验证步骤，直接以 success=true 触发 completion。用于多阶段操作的中间步骤。
    private func enhancedSetFrame(_ window: AXUIElement, _ frame: CGRect, adjustSizeFirst: Bool = true, skipVerify: Bool = false, completion: ((Bool) -> Void)? = nil) {
        AppLogger.shared.log("开始增强型设置窗口位置和大小: \(frame)", level: .debug)
        
        // 为防止系统增强型UI干扰窗口调整，尝试暂时禁用它（如果有）
        var appElement: AXUIElement?
        var enhancedUI: Bool? = nil

        // 获取应用的AXUIElement以操作enhancedUserInterface属性
        if let pid = getPidForWindow(window) {
            appElement = AXUIElementCreateApplication(pid)
            
            // 检查并禁用enhancedUserInterface
            var value: AnyObject?
            if AXUIElementCopyAttributeValue(appElement!, kAXEnhancedUserInterfaceAttribute as CFString, &value) == .success,
               let boolValue = value as? Bool, boolValue == true {
                enhancedUI = true
                AppLogger.shared.log("暂时禁用应用的增强型UI", level: .debug)
                AXUIElementSetAttributeValue(appElement!, kAXEnhancedUserInterfaceAttribute as CFString, false as CFTypeRef)
            }
        }
        
        // 记录窗口当前状态
        var currentPosition: CGPoint? = nil
        var currentSize: CGSize? = nil
        
        // 获取窗口当前位置
        var positionRef: AnyObject?
        if AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef) == .success,
           let positionValue = positionRef {
            var position = CGPoint.zero
            if AXValueGetValue(positionValue as! AXValue, .cgPoint, &position) {
                currentPosition = position
            }
        }
        
        // 获取窗口当前大小
        var sizeRef: AnyObject?
        if AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success,
           let sizeValue = sizeRef {
            var size = CGSize.zero
            if AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) {
                currentSize = size
            }
        }
        
        AppLogger.shared.log("窗口当前位置: \(currentPosition?.debugDescription ?? "未知"), 大小: \(currentSize?.debugDescription ?? "未知")", level: .debug)
        
        // 1. 如果需要，先调整大小
        if adjustSizeFirst {
            if let axSize = createAXValue(frame.size, type: .cgSize) {
                let result = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, axSize)
                AppLogger.shared.log("初始大小调整结果: \(result == .success ? "成功" : "失败(\(result.rawValue))")", level: .debug)
            }
        }
        
        // 2. 调整位置
        if let axPosition = createAXValue(frame.origin, type: .cgPoint) {
            let result = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axPosition)
            AppLogger.shared.log("位置调整结果: \(result == .success ? "成功" : "失败(\(result.rawValue))")", level: .debug)
        }
        
        // 3. 再次调整大小以确保正确应用
        if let axSize = createAXValue(frame.size, type: .cgSize) {
            let result = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, axSize)
            AppLogger.shared.log("最终大小调整结果: \(result == .success ? "成功" : "失败(\(result.rawValue))")", level: .debug)
        }
        
        // 4. 验证调整结果
        if skipVerify {
            completion?(true)
        } else {
            verifyWindowChange(window, expectedFrame: frame, completion: completion)
        }
        
        // 如果增强型UI之前是开启的，恢复它
        if let appElement = appElement, enhancedUI == true {
            // 延迟恢复增强型UI，给窗口调整时间完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                AppLogger.shared.log("恢复应用的增强型UI", level: .debug)
                AXUIElementSetAttributeValue(appElement, kAXEnhancedUserInterfaceAttribute as CFString, true as CFTypeRef)
            }
        }
    }
    
    /// 创建AXValue，安全处理类型转换
    private func createAXValue<T>(_ value: T, type: AXValueType) -> AXValue? {
        switch type {
        case .cgPoint:
            guard let pointValue = value as? CGPoint else { return nil }
            var copy = pointValue
            return AXValueCreate(type, &copy)
        case .cgSize:
            guard let sizeValue = value as? CGSize else { return nil }
            var copy = sizeValue
            return AXValueCreate(type, &copy)
        case .cgRect:
            guard let rectValue = value as? CGRect else { return nil }
            var copy = rectValue
            return AXValueCreate(type, &copy)
        default:
            AppLogger.shared.log("不支持的AXValue类型", level: .warning)
            return nil
        }
    }
    
    /// 获取窗口所属应用的进程ID
    private func getPidForWindow(_ window: AXUIElement) -> pid_t? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(window, &pid) == .success else {
            return nil
        }
        return pid
    }
    
    /// 验证窗口变化是否成功应用
    private func verifyWindowChange(_ window: AXUIElement, expectedFrame: CGRect, completion: ((Bool) -> Void)? = nil) {
        // 短暂延迟后检查窗口实际状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let (actualPosition, actualSize) = self.getWindowPositionAndSize(window) else {
                AppLogger.shared.log("无法获取窗口实际状态进行验证", level: .warning)
                completion?(false)
                return
            }
            
            let actualFrame = CGRect(origin: actualPosition, size: actualSize)
            
            // 检查位置和大小是否在可接受的误差范围内
            let positionTolerance: CGFloat = 1.0 // 1像素的容差
            let sizeTolerance: CGFloat = 1.0 // 1像素的容差
            
            let positionMatch = abs(actualFrame.origin.x - expectedFrame.origin.x) <= positionTolerance &&
                               abs(actualFrame.origin.y - expectedFrame.origin.y) <= positionTolerance
            
            let sizeMatch = abs(actualFrame.size.width - expectedFrame.size.width) <= sizeTolerance &&
                           abs(actualFrame.size.height - expectedFrame.size.height) <= sizeTolerance
            
            if positionMatch && sizeMatch {
                AppLogger.shared.log("窗口调整验证成功，实际位置和大小符合预期", level: .debug)
                completion?(true)
            } else {
                AppLogger.shared.log("窗口调整验证警告 - 预期: \(expectedFrame), 实际: \(actualFrame)", level: .warning)
                completion?(false)
            }
        }
    }
    
    private func centerWindow(_ window: AXUIElement, completion: ((Bool) -> Void)? = nil) {
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
            completion?(false)
            return
        }
        
        // 转换 AXValue 到 CGSize
        var windowSize = CGSize.zero
        guard let sizeValue = sizeRef else {
            completion?(false)
            return
        }
        if AXValueGetType(sizeValue as! AXValue) == .cgSize,
           AXValueGetValue(sizeValue as! AXValue, .cgSize, &windowSize) {
            AppLogger.shared.log("当前窗口大小: \(windowSize)", level: .debug)
        } else {
            AppLogger.shared.log("无法转换窗口大小", level: .warning)
            completion?(false)
            return
        }
        
        // 计算居中位置，考虑 Stage Manager 的情况
        // Stage Manager 通常会在左右两侧预留空间，我们估计大约是屏幕宽度的 15%
        let stageManagerSideMargin = screenFrame.width * 0.15
        let usableScreenWidth = screenFrame.width - (stageManagerSideMargin * 2)
        
        // 计算新位置 (NSScreen坐标系，原点在左下角，Y轴向上)
        let nsScreenX = screenFrame.origin.x + stageManagerSideMargin + (usableScreenWidth - windowSize.width) / 2
        let nsScreenY = screenFrame.origin.y + (screenFrame.height - statusBarHeight - windowSize.height) / 2
        
        // 将NSScreen坐标系转换为AXUIElement坐标系
        let newPosition = convertToAXCoordinates(CGPoint(x: nsScreenX, y: nsScreenY), size: windowSize)
        
        // 创建目标框架
        let targetFrame = CGRect(origin: newPosition, size: windowSize)
        
        // 使用增强型setFrame方法应用变更
        enhancedSetFrame(window, targetFrame, completion: completion)
    }

    private func almostMaximizeWindow(_ window: AXUIElement, completion: ((Bool) -> Void)? = nil) {
        AppLogger.shared.log("开始几乎最大化窗口操作", level: .debug)
        
        // 直接获取窗口所在的屏幕
        let currentScreen = getScreenForWindow(window)
        AppLogger.shared.log("使用屏幕: \(currentScreen.localizedName), frame: \(currentScreen.frame)", level: .debug)
        almostMaximizeWindow(window, on: currentScreen, completion: completion)
    }

    private func moveWindowToNextDisplayUsingAppRule(_ window: AXUIElement, app: NSRunningApplication, appIdentity: String, completion: ((Bool) -> Void)? = nil) {
        guard let appName = app.localizedName,
              let bundleId = app.bundleIdentifier else {
            AppLogger.shared.log("移动到下一个显示器失败: 无法获取应用规则, 应用=\(appIdentity)", level: .warning)
            completion?(false)
            return
        }

        let rule = AppConfig.shared.getRule(for: bundleId, appName: appName)
        moveWindowToNextDisplay(window, rule: rule, completion: completion)
    }

    private func moveWindowToNextDisplay(_ window: AXUIElement, rule: WindowHandlingRule, completion: ((Bool) -> Void)? = nil) {
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            AppLogger.shared.log("移动到下一个显示器失败: 未检测到可用屏幕", level: .warning)
            completion?(false)
            return
        }

        let currentScreen = getScreenForWindow(window)
        let currentIndex = screens.firstIndex(where: { $0 == currentScreen }) ?? 0
        let nextIndex = (currentIndex + 1) % screens.count
        let targetScreen = screens[nextIndex]

        AppLogger.shared.log("准备按应用规则移动窗口到下一个显示器: 规则=\(rule.rawValue), 当前=\(currentScreen.localizedName), 目标=\(targetScreen.localizedName)", level: .info)

        switch rule {
        case .center:
            moveWindowOnly(window, from: currentScreen, to: targetScreen, skipVerify: true) { [weak self] _ in
                guard let self else { completion?(false); return }
                self.centerWindow(window, on: targetScreen, completion: completion)
            }
        case .almostMaximize:
            moveWindowOnly(window, from: currentScreen, to: targetScreen, skipVerify: true) { [weak self] _ in
                guard let self else { completion?(false); return }
                self.almostMaximizeWindow(window, on: targetScreen, completion: completion)
            }
        case .ignore:
            moveWindowOnly(window, from: currentScreen, to: targetScreen, completion: completion)
        }
    }

    private func centerWindow(_ window: AXUIElement, on screen: NSScreen, completion: ((Bool) -> Void)? = nil) {
        guard let (_, size) = getWindowPositionAndSize(window) else {
            AppLogger.shared.log("移动后居中失败: 无法获取窗口大小", level: .warning)
            completion?(false)
            return
        }

        let statusBarHeight = getStatusBarHeight(for: screen)
        let screenFrame = screen.frame
        let stageManagerSideMargin = screenFrame.width * 0.15
        let usableScreenWidth = screenFrame.width - (stageManagerSideMargin * 2)
        let nsScreenX = screenFrame.origin.x + stageManagerSideMargin + (usableScreenWidth - size.width) / 2
        let nsScreenY = screenFrame.origin.y + (screenFrame.height - statusBarHeight - size.height) / 2
        let newPosition = convertToAXCoordinates(CGPoint(x: nsScreenX, y: nsScreenY), size: size)
        let targetFrame = CGRect(origin: newPosition, size: size)

        enhancedSetFrame(window, targetFrame, completion: completion)
    }

    private func moveWindowOnly(_ window: AXUIElement, from currentScreen: NSScreen, to targetScreen: NSScreen, skipVerify: Bool = false, completion: ((Bool) -> Void)? = nil) {
        guard let (position, size) = getWindowPositionAndSize(window) else {
            AppLogger.shared.log("只移动到下一个显示器失败: 无法获取窗口位置和大小", level: .warning)
            completion?(false)
            return
        }

        let windowFrame = CGRect(origin: position, size: size)
        let currentScreenFrame = convertToAXRect(currentScreen.frame)
        let targetScreenFrame = convertToAXRect(targetScreen.visibleFrame)
        let targetFrame = Self.moveOnlyTargetFrame(for: windowFrame, from: currentScreenFrame, to: targetScreenFrame)

        AppLogger.shared.log("只移动窗口到下一个显示器: 目标Frame=\(targetFrame)", level: .info)
        enhancedSetFrame(window, targetFrame, adjustSizeFirst: false, skipVerify: skipVerify, completion: completion)
    }

    private func almostMaximizeWindow(_ window: AXUIElement, on screen: NSScreen, completion: ((Bool) -> Void)? = nil) {
        let axRect = almostMaximizedAXRect(for: screen)
        enhancedSetFrame(window, axRect, completion: completion)
    }

    static func moveOnlyTargetFrame(for windowFrame: CGRect, from currentScreenFrame: CGRect, to targetScreenFrame: CGRect) -> CGRect {
        guard currentScreenFrame.width > 0, currentScreenFrame.height > 0 else {
            return CGRect(origin: targetScreenFrame.origin, size: windowFrame.size)
        }

        let relativeCenterX = (windowFrame.midX - currentScreenFrame.minX) / currentScreenFrame.width
        let relativeCenterY = (windowFrame.midY - currentScreenFrame.minY) / currentScreenFrame.height
        let proposedCenterX = targetScreenFrame.minX + (relativeCenterX * targetScreenFrame.width)
        let proposedCenterY = targetScreenFrame.minY + (relativeCenterY * targetScreenFrame.height)
        let proposedOrigin = CGPoint(
            x: proposedCenterX - windowFrame.width / 2,
            y: proposedCenterY - windowFrame.height / 2
        )

        return CGRect(
            x: clamp(proposedOrigin.x, min: targetScreenFrame.minX, max: targetScreenFrame.maxX - windowFrame.width),
            y: clamp(proposedOrigin.y, min: targetScreenFrame.minY, max: targetScreenFrame.maxY - windowFrame.height),
            width: windowFrame.width,
            height: windowFrame.height
        )
    }

    private static func clamp(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        guard maximum >= minimum else {
            return minimum
        }

        return Swift.min(Swift.max(value, minimum), maximum)
    }

    private func almostMaximizedAXRect(for screen: NSScreen) -> CGRect {
        let screenFrame = screen.frame
        let statusBarHeight = getStatusBarHeight(for: screen)
        AppLogger.shared.log("状态栏高度: \(statusBarHeight)", level: .debug)

        let scaleFactor = CGFloat(AppConfig.shared.windowScaleFactor)
        let horizontalMargin = (screenFrame.width * (1.0 - scaleFactor)) / 2
        let verticalMargin = ((screenFrame.height - statusBarHeight) * (1.0 - scaleFactor)) / 2

        AppLogger.shared.log("使用比例系数: \(scaleFactor), 计算得到边距 - 水平: \(horizontalMargin), 垂直: \(verticalMargin)", level: .debug)

        let nsRect = CGRect(
            x: screenFrame.origin.x + horizontalMargin,
            y: screenFrame.origin.y + verticalMargin,
            width: screenFrame.width - (horizontalMargin * 2),
            height: screenFrame.height - statusBarHeight - (verticalMargin * 2)
        )

        return convertToAXRect(nsRect)
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
    
    /// 测试函数：验证窗口调整优化
    func testEnhancedWindowFrameUpdate() {
        AppLogger.shared.log("开始测试窗口调整优化", level: .info)
        
        guard let app = NSWorkspace.shared.frontmostApplication,
              let window = findWindowsToManage(for: app).first else {
            AppLogger.shared.log("无法获取当前窗口进行测试", level: .error)
            return
        }
        
        // 获取当前窗口信息
        guard let (position, size) = getWindowPositionAndSize(window) else {
            AppLogger.shared.log("无法获取窗口位置和大小", level: .error)
            return
        }
        
        let currentFrame = CGRect(origin: position, size: size)
        AppLogger.shared.log("当前窗口位置和大小: \(currentFrame)", level: .info)
        
        // 获取窗口所在屏幕
        let screen = getScreenForWindow(window)
        let screenFrame = screen.frame
        let statusBarHeight = getStatusBarHeight(for: screen)
        
        // 计算测试位置（屏幕中央）
        let centerX = screenFrame.origin.x + (screenFrame.width - size.width) / 2
        let centerY = screenFrame.origin.y + (screenFrame.height - statusBarHeight - size.height) / 2
        let centerPosition = convertToAXCoordinates(CGPoint(x: centerX, y: centerY), size: size)
        
        // 创建测试框架（原始大小，居中位置）
        let testFrame = CGRect(origin: centerPosition, size: size)
        
        // 使用增强型方法执行调整
        enhancedSetFrame(window, testFrame)
        
        // 查询调整后的状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, let (newPosition, newSize) = self.getWindowPositionAndSize(window) else {
                return
            }
            
            let resultFrame = CGRect(origin: newPosition, size: newSize)
            AppLogger.shared.log("调整后窗口位置和大小: \(resultFrame)", level: .info)
            
            // 计算误差
            let positionError = hypot(
                abs(resultFrame.origin.x - testFrame.origin.x),
                abs(resultFrame.origin.y - testFrame.origin.y)
            )
            
            let sizeError = hypot(
                abs(resultFrame.size.width - testFrame.size.width),
                abs(resultFrame.size.height - testFrame.size.height)
            )
            
            AppLogger.shared.log("位置误差: \(positionError)，大小误差: \(sizeError)", level: .info)
            
            // 评估结果
            if positionError < 2.0 && sizeError < 2.0 {
                AppLogger.shared.log("窗口调整优化测试结果：成功 ✅", level: .info)
            } else {
                AppLogger.shared.log("窗口调整优化测试结果：失败 ❌", level: .warning)
            }
            
            // 恢复原始位置（如果需要的话）
            self.enhancedSetFrame(window, currentFrame)
        }
    }
}

// 用于表示窗口的简单结构
struct CGWindow {
    let bounds: CGRect
} 
