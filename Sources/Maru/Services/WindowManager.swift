import Cocoa
import Combine
import ApplicationServices

// MARK: - 增加辅助功能相关常量定义
// 系统没有公开kAXEnhancedUserInterfaceAttribute常量，所以我们需要自己定义
let kAXEnhancedUserInterfaceAttribute = "AXEnhancedUserInterface" as CFString
let kAXManualAccessibilityAttribute = "AXManualAccessibility" as CFString

struct WindowTargetCandidate: Equatable {
    let index: Int
    let role: String?
    let subrole: String?
    let isMinimized: Bool
    let isModal: Bool?
    let isMain: Bool?
    let isFocused: Bool
    let parentRole: String?
    let isPositionSettable: Bool
    let isSizeSettable: Bool
    let hasReadableFrame: Bool

    var isManageableBusinessWindow: Bool {
        guard role == (kAXWindowRole as String),
              !isMinimized,
              isModal != true,
              isMain != false,
              (isMain == true || isFocused),
              isPositionSettable,
              hasReadableFrame else {
            return false
        }

        if let parentRole, parentRole != (kAXApplicationRole as String) {
            return false
        }

        if subrole == (kAXStandardWindowSubrole as String) {
            return true
        }

        // 少数应用不公开 subrole；只有当前 Main/Focused 的顶层窗口才保守接纳。
        return subrole == nil && (isMain == true || isFocused)
    }

    /// 应用刚启动时，AXMain/AXFocused 可能晚于标准窗口本身就绪。
    /// 这里只用于决定“继续等一下”，不会直接把它选作操作目标。
    var isPotentialBusinessWindowAwaitingFocus: Bool {
        guard role == (kAXWindowRole as String),
              !isMinimized,
              isModal != true,
              isPositionSettable,
              hasReadableFrame else {
            return false
        }

        if let parentRole, parentRole != (kAXApplicationRole as String) {
            return false
        }

        return subrole == (kAXStandardWindowSubrole as String) || subrole == nil
    }
}

enum WindowTargetSkipReason: String, Equatable {
    case auxiliaryWindow = "明确命中辅助窗口"
    case ambiguousWindow = "无法唯一确定目标窗口"
    case noManageableWindow = "没有合格的业务窗口"
}

enum WindowTargetDecision: Equatable {
    case select(index: Int)
    case skip(reason: WindowTargetSkipReason)
    case retry
}

enum WindowTargetPolicy {
    static func resolve(
        candidates: [WindowTargetCandidate],
        clickedIndex: Int?,
        pointerHitTargetApplication: Bool,
        focusedIndex: Int?,
        mainIndex: Int?
    ) -> WindowTargetDecision {
        let byIndex = Dictionary(uniqueKeysWithValues: candidates.map { ($0.index, $0) })

        // 鼠标只负责定位；一旦明确命中辅助窗口，本次操作立即终止，不能提升背后的主窗口。
        if pointerHitTargetApplication {
            guard let clickedIndex, let clicked = byIndex[clickedIndex] else {
                return .skip(reason: .ambiguousWindow)
            }
            return clicked.isManageableBusinessWindow
                ? .select(index: clickedIndex)
                : .skip(reason: .auxiliaryWindow)
        }

        // 键盘、Dock、Stage Manager 等非窗口点击激活，以当前焦点窗口为准。
        if let focusedIndex, let focused = byIndex[focusedIndex] {
            return focused.isManageableBusinessWindow
                ? .select(index: focusedIndex)
                : .skip(reason: .auxiliaryWindow)
        }

        if let mainIndex, let main = byIndex[mainIndex], main.isManageableBusinessWindow {
            return .select(index: mainIndex)
        }

        let manageable = candidates.filter(\.isManageableBusinessWindow)
        switch manageable.count {
        case 0:
            // 非点击激活时，标准顶层窗口可能已经出现，但 Main/Focused 关系尚未同步。
            // 此时只重试解析，不提升它；明确点击/聚焦到辅助窗口的分支已在上方终止。
            return candidates.isEmpty || candidates.contains(where: \.isPotentialBusinessWindowAwaitingFocus)
                ? .retry
                : .skip(reason: .noManageableWindow)
        case 1:
            return .select(index: manageable[0].index)
        default:
            return .skip(reason: .ambiguousWindow)
        }
    }
}

struct WindowActionCapabilities: Equatable {
    let isPositionSettable: Bool
    let isSizeSettable: Bool
}

enum WindowActionMutationPlan: Equatable {
    case unavailable
    case positionOnly
    case resizeThenCenter
}

enum WindowActionPolicy {
    static func mutationPlan(
        for rule: WindowHandlingRule,
        capabilities: WindowActionCapabilities
    ) -> WindowActionMutationPlan {
        guard capabilities.isPositionSettable else {
            return .unavailable
        }

        switch rule {
        case .center:
            return .positionOnly
        case .almostMaximize:
            return capabilities.isSizeSettable ? .resizeThenCenter : .positionOnly
        case .ignore:
            return .unavailable
        }
    }
}

enum WindowResizeSettlingPolicy {
    static func shouldRetry(
        originalSize: CGSize,
        actualSize: CGSize,
        requestedSize: CGSize,
        retriesRemaining: Int,
        tolerance: CGFloat = 1
    ) -> Bool {
        guard retriesRemaining > 0 else { return false }

        let requestIsMaterial = abs(requestedSize.width - originalSize.width) > tolerance ||
            abs(requestedSize.height - originalSize.height) > tolerance
        let windowResponded = abs(actualSize.width - originalSize.width) > tolerance ||
            abs(actualSize.height - originalSize.height) > tolerance

        // AX setter 返回成功但尺寸完全没动，通常是新窗口仍在完成初始化。
        // 一旦窗口有任何实际响应，就接受应用约束后的尺寸并按它居中。
        return requestIsMaterial && !windowResponded
    }
}

enum WindowAccessibilityCompatibilityDecision: Equatable {
    case proceed
    case requestActivation
    case awaitActivation
    case unavailable
}

enum WindowAccessibilityCompatibilityPolicy {
    static func decision(
        for windowsError: AXError,
        activationRequestedAt: Date?,
        now: Date = Date(),
        graceInterval: TimeInterval = 1.5
    ) -> WindowAccessibilityCompatibilityDecision {
        guard windowsError == .apiDisabled else {
            return .proceed
        }

        guard let activationRequestedAt else {
            return .requestActivation
        }

        return now.timeIntervalSince(activationRequestedAt) <= graceInterval
            ? .awaitActivation
            : .unavailable
    }
}

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
    private static let axWindowObserverCallback: AXObserverCallback = { _, _, notification, refcon in
        guard let refcon else { return }
        let manager = Unmanaged<WindowManager>.fromOpaque(refcon).takeUnretainedValue()
        let notificationName = notification as String

        DispatchQueue.main.async {
            manager.handleObservedWindowChange(notificationName)
        }
    }

    private struct RecentMouseDown {
        let location: CGPoint
        let timestamp: Date
    }

    private struct AXWindowCandidate {
        let element: AXUIElement
        let descriptor: WindowTargetCandidate
        let frame: CGRect?
    }

    private enum PointerHitResult {
        case noTargetApplicationHit
        case targetApplicationWithoutWindow
        case targetWindow(AXUIElement)
    }

    private enum ResolvedWindowTarget {
        case selected(AXUIElement)
        case skip(WindowTargetSkipReason)
        case retry(WindowTargetRetryReason)
        case unavailable(WindowTargetUnavailableReason)
    }

    private enum WindowTargetRetryReason: String {
        case windowNotReady = "窗口尚未准备完成"
        case accessibilityActivationPending = "正在启用应用辅助功能窗口"
    }

    private enum WindowTargetUnavailableReason: String {
        case accessibilityAPIDisabled = "应用未开放辅助功能窗口"
    }

    private enum ManualWindowAlertReason {
        case noManageableWindow
        case accessibilityUnavailable
    }

    // 延迟时间（秒）
    private let debounceTime: TimeInterval = 0.2
    private let mouseActivationIntentInterval: TimeInterval = 0.6
    
    @Published private(set) var isMonitoring = false
    
    private var workspaceNotificationObserver: NSObjectProtocol?
    private var applicationActivityObserver: NSObjectProtocol?
    private var applicationLaunchObserver: NSObjectProtocol?
    private var manualWindowActionObserver: NSObjectProtocol?
    private var debounceTimer: Timer?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var axWindowObserver: AXObserver?
    private var observedAXApplication: AXUIElement?
    private var observedProcessIdentifier: pid_t?
    private var recentMouseDown: RecentMouseDown?
    private var pendingActivationApp: NSRunningApplication?
    private var manualAccessibilityActivationRequestedAt: [pid_t: Date] = [:]
    private var pendingManualAccessibilityRetry: DispatchWorkItem?
    private let manualAccessibilityActivationGraceInterval: TimeInterval = 1.5
    
    // 简化防重机制
    // 记录最近处理的窗口信息
    private var lastProcessedWindowInfo: (processIdentifier: pid_t, windowHash: CFHashCode, timestamp: Date)?
    // 防重处理的最小时间间隔（秒）
    private let minProcessingInterval: TimeInterval = 1.5
    // 窗口操作状态标记
    private var isWindowOperationInProgress = false
    private var activationMouseLocation: CGPoint?  // 仅在激活前后存在真实鼠标按下时记录，避免把悬停误当点击
    private var accessibilityPermissionFlowState = AccessibilityPermissionFlowState()
    private var accessibilityPermissionPollingTimer: Timer?
    private var accessibilityPermissionPollingAttemptsRemaining = 0
    private let maxAccessibilityPermissionPollingAttempts = 120
    private let runningApplicationResolver: (pid_t) -> NSRunningApplication?
    private let dockLayoutReader: DockLayoutReading
    private let activityStore: AppActivityStore

    init(
        runningApplicationResolver: @escaping (pid_t) -> NSRunningApplication? = { NSRunningApplication(processIdentifier: $0) },
        dockLayoutReader: DockLayoutReading = DefaultsDockController(),
        activityStore: AppActivityStore = .shared
    ) {
        self.runningApplicationResolver = runningApplicationResolver
        self.dockLayoutReader = dockLayoutReader
        self.activityStore = activityStore
        // Don't request permissions during init - wait for app to launch
    }
    
    deinit {
        accessibilityPermissionPollingTimer?.invalidate()
        stopMonitoring()
        stopApplicationActivityMonitoring()
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
        // 应用动态用于解释“为什么没有处理”，因此不应被辅助功能权限或管理开关一起停掉。
        startApplicationActivityMonitoring()

        // 先停止当前窗口操作监控（如果有的话）；应用启动/激活记录会继续保留。
        stopMonitoring()

        // 检查辅助功能权限
        if !checkAccessibilityPermission() {
            showAccessibilityPermissionAlert()
            return
        }
        
        // 重置所有状态变量
        lastProcessedWindowInfo = nil
        isWindowOperationInProgress = false
        pendingActivationApp = nil
        recentMouseDown = nil

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            self?.recordMouseDown()
        }

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            self?.recordMouseDown()
            return event
        }
        
        // 监听应用激活；同应用内窗口变化不属于这条自动触发链。
        workspaceNotificationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            
            // 获取当前活动的应用
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                AppLogger.shared.log("检测到应用切换: \(app.localizedName ?? "未知")", level: .debug)
                self.observeWindowChanges(for: app)

                if self.isWindowOperationInProgress {
                    self.pendingActivationApp = app
                    AppLogger.shared.log("窗口操作进行中，保留最新应用切换: \(app.localizedName ?? "未知")", level: .debug)
                    return
                }

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
                self.observeWindowChanges(for: activeApp)
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

        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }

        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }

        stopObservingWindowChanges()
        
        debounceTimer?.invalidate()
        debounceTimer = nil

        pendingManualAccessibilityRetry?.cancel()
        pendingManualAccessibilityRetry = nil
        manualAccessibilityActivationRequestedAt.removeAll()
        
        isMonitoring = false
        AppLogger.shared.log("窗口管理器已停止监控", level: .info)
    }

    private func startApplicationActivityMonitoring() {
        guard applicationActivityObserver == nil, applicationLaunchObserver == nil else {
            return
        }

        applicationActivityObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  self.shouldRecordApplicationActivity(for: app) else {
                return
            }

            let trigger = self.recentMouseActivationTrigger()
            self.recordActivity(
                for: app,
                kind: .activated,
                title: "进入前台",
                detail: self.isMonitoring
                    ? "Maru 收到应用激活事件，准备按当前规则检查窗口。"
                    : "Maru 收到应用激活事件，但当前没有运行窗口操作监控。",
                trigger: trigger
            )

            guard !self.isMonitoring else {
                return
            }

            let missingPermission = !AXIsProcessTrusted()
            self.recordActivity(
                for: app,
                kind: .skipped,
                title: "未检查窗口",
                detail: missingPermission
                    ? "Maru 尚未获得辅助功能权限，因此只记录了 App 进入前台，没有读取或调整窗口。"
                    : "窗口自动管理当前未运行，因此 Maru 只记录了 App 进入前台，没有读取或调整窗口。",
                trigger: missingPermission ? "缺少辅助功能权限" : "窗口管理未运行"
            )
        }

        applicationLaunchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  self.shouldRecordApplicationActivity(for: app) else {
                return
            }

            // 新进程即使复用了旧 PID，也必须重新判断 Electron 辅助功能兼容状态。
            self.manualAccessibilityActivationRequestedAt.removeValue(forKey: app.processIdentifier)

            self.recordActivity(
                for: app,
                kind: .launched,
                title: "应用已启动",
                detail: "macOS 报告该 App 已启动；进入前台后 Maru 才会按规则检查窗口。",
                trigger: "系统启动事件"
            )
        }
    }

    private func stopApplicationActivityMonitoring() {
        if let observer = applicationActivityObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            applicationActivityObserver = nil
        }

        if let observer = applicationLaunchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            applicationLaunchObserver = nil
        }
    }

    private func shouldRecordApplicationActivity(for app: NSRunningApplication) -> Bool {
        guard app.activationPolicy == .regular,
              let bundleIdentifier = app.bundleIdentifier else {
            return false
        }

        return bundleIdentifier != Bundle.main.bundleIdentifier
    }

    private func recordMouseDown() {
        recentMouseDown = RecentMouseDown(location: NSEvent.mouseLocation, timestamp: Date())
    }

    private func observeWindowChanges(for app: NSRunningApplication) {
        guard observedProcessIdentifier != app.processIdentifier else { return }
        stopObservingWindowChanges()

        var observer: AXObserver?
        let createError = AXObserverCreate(
            app.processIdentifier,
            Self.axWindowObserverCallback,
            &observer
        )
        guard createError == .success, let observer else {
            AppLogger.shared.log("无法监听窗口变化: \(describeApplication(app)), error=\(axErrorDescription(createError))", level: .debug)
            return
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let notifications = [
            kAXFocusedWindowChangedNotification as CFString,
            kAXWindowCreatedNotification as CFString
        ]

        var registeredAny = false
        for notification in notifications {
            let addError = AXObserverAddNotification(observer, appElement, notification, refcon)
            if addError == .success || addError == .notificationAlreadyRegistered {
                registeredAny = true
            } else {
                AppLogger.shared.log("注册窗口通知失败: \(notification), error=\(axErrorDescription(addError))", level: .debug)
            }
        }

        guard registeredAny else { return }

        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .commonModes
        )
        axWindowObserver = observer
        observedAXApplication = appElement
        observedProcessIdentifier = app.processIdentifier
        AppLogger.shared.log("开始监听同应用窗口变化: \(describeApplication(app))", level: .debug)
    }

    private func stopObservingWindowChanges() {
        if let observer = axWindowObserver {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(observer),
                .commonModes
            )
        }

        axWindowObserver = nil
        observedAXApplication = nil
        observedProcessIdentifier = nil
    }

    private func handleObservedWindowChange(_ notificationName: String) {
        guard isMonitoring,
              let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier == observedProcessIdentifier else {
            return
        }

        AppLogger.shared.log("检测到同应用窗口变化: \(notificationName), 应用=\(app.localizedName ?? "未知")", level: .debug)

        let isNewWindow = notificationName == (kAXWindowCreatedNotification as String)
        recordActivity(
            for: app,
            kind: .window,
            title: isNewWindow ? "检测到新窗口" : "焦点窗口已变化",
            detail: isNewWindow
                ? "App 创建了新窗口，Maru 准备重新判断它是否适合处理。"
                : "App 内的焦点窗口发生变化，Maru 准备检查新的当前窗口。",
            trigger: "窗口事件"
        )

        if isWindowOperationInProgress {
            pendingActivationApp = app
            return
        }

        debounceWindowManagement(for: app)
    }
    
    private func debounceWindowManagement(for app: NSRunningApplication) {
        // 取消之前的计时器
        debounceTimer?.invalidate()
        
        // 验证应用信息
        guard let appName = app.localizedName,
              app.bundleIdentifier != nil else { return }

        let now = Date()
        let capturedMouseLocation: CGPoint?
        if let recentMouseDown,
           now.timeIntervalSince(recentMouseDown.timestamp) <= mouseActivationIntentInterval {
            capturedMouseLocation = recentMouseDown.location
        } else if NSEvent.pressedMouseButtons != 0 {
            capturedMouseLocation = NSEvent.mouseLocation
        } else {
            capturedMouseLocation = nil
        }

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
        
        // 规则读取保持无副作用；只有合格窗口实际处理成功后才记录应用使用。
        let rule = AppConfig.shared.getRule(for: bundleId, appName: appName)
        
        // 根据规则处理窗口
        switch rule {
        case .center, .almostMaximize:
            processWindowWithRule(app: app, bundleId: bundleId, appName: appName, rule: rule)
            
        case .ignore:
            AppLogger.shared.log("忽略应用: \(appName) (\(bundleId))", level: .debug)
            recordActivity(
                for: app,
                kind: .skipped,
                title: "按规则忽略",
                detail: "该 App 的规则是“忽略”，Maru 不会移动或缩放它的窗口。",
                trigger: "自动监控"
            )
        }
    }
    
    /// 处理需要调整位置的窗口
    private func processWindowWithRule(app: NSRunningApplication, bundleId: String, appName: String, rule: WindowHandlingRule) {
        switch resolveWindowTarget(for: app, pointerLocation: activationMouseLocation) {
        case .selected(let window):
            executeSelectedWindow(window, app: app, bundleId: bundleId, appName: appName, rule: rule, triggerSource: "automatic")

        case .skip(let reason):
            AppLogger.shared.log("跳过应用 \(appName) 的窗口处理: \(reason.rawValue)", level: .info)
            recordActivity(
                for: app,
                kind: .skipped,
                title: "未处理当前窗口",
                detail: userFacingSkipDetail(reason),
                trigger: "自动监控"
            )

        case .retry(let reason):
            AppLogger.shared.log("应用 \(appName) 需要重试目标解析: \(reason.rawValue)", level: .debug)
            recordActivity(
                for: app,
                kind: .window,
                title: reason == .accessibilityActivationPending ? "正在启用窗口接口" : "等待窗口准备",
                detail: userFacingRetryDetail(reason),
                trigger: "自动监控"
            )
            scheduleWindowRetry(
                for: app,
                bundleId: bundleId,
                appName: appName,
                rule: rule,
                attempt: 1,
                lastReason: reason
            )

        case .unavailable(let reason):
            AppLogger.shared.log("应用 \(appName) 的窗口接口不可用: \(reason.rawValue)", level: .warning)
            recordActivity(
                for: app,
                kind: .skipped,
                title: "应用窗口接口不可用",
                detail: userFacingUnavailableDetail(reason),
                trigger: "自动监控"
            )
        }
    }

    private func executeSelectedWindow(
        _ window: AXUIElement,
        app: NSRunningApplication,
        bundleId: String,
        appName: String,
        rule: WindowHandlingRule,
        triggerSource: String
    ) {
        let appIdentity = "\(appName) (\(bundleId), pid: \(app.processIdentifier))"
        let actionLabel = rule == .center ? "居中" : "呼吸窗口"
        let windowHash = CFHash(window)

        if triggerSource.hasPrefix("automatic"),
           let lastInfo = lastProcessedWindowInfo,
           lastInfo.processIdentifier == app.processIdentifier,
           lastInfo.windowHash == windowHash,
            Date().timeIntervalSince(lastInfo.timestamp) < minProcessingInterval {
            AppLogger.shared.log("同一目标窗口处于冷却期，跳过处理: \(appIdentity)", level: .debug)
            recordActivity(
                for: app,
                kind: .skipped,
                title: "避免重复处理",
                detail: "同一个窗口刚刚处理过，Maru 在冷却时间内不会再次调整。",
                windowTitle: activityWindowTitle(window),
                trigger: userFacingTrigger(triggerSource)
            )
            return
        }

        guard let signature = getWindowSignature(window) else {
            AppLogger.shared.log("目标窗口无法读取位置和尺寸，取消操作: \(appIdentity)", level: .warning)
            recordActivity(
                for: app,
                kind: .failure,
                title: "无法读取窗口",
                detail: "Maru 无法取得当前窗口的位置和尺寸，因此没有执行操作。",
                windowTitle: activityWindowTitle(window),
                trigger: userFacingTrigger(triggerSource)
            )
            return
        }

        let windowTitle = activityWindowTitle(window)
        recordActivity(
            for: app,
            kind: .action,
            title: "准备执行\(actionLabel)",
            detail: "当前规则为“\(rule.rawValue)”，操作前窗口尺寸为 \(Int(signature.size.width)) × \(Int(signature.size.height))。",
            windowTitle: windowTitle,
            trigger: userFacingTrigger(triggerSource)
        )

        AppLogger.shared.log(
            "处理唯一目标窗口: 应用=\(appIdentity), 规则=\(rule), pos=(\(signature.position.x),\(signature.position.y)), size=(\(signature.size.width)x\(signature.size.height))",
            level: .info
        )
        isWindowOperationInProgress = true

        let onComplete: (Bool) -> Void = { [weak self] success in
            if success, triggerSource.hasPrefix("automatic") {
                AppConfig.shared.recordAppUsage(bundleId: bundleId, appName: appName)
            }
            guard let self else { return }

            self.handleWindowOperationCompletion(
                success: success,
                processIdentifier: app.processIdentifier,
                windowHash: windowHash,
                triggerSource: triggerSource,
                actionLabel: actionLabel,
                appIdentity: appIdentity,
                appName: appName,
                bundleIdentifier: bundleId,
                windowTitle: windowTitle
            )
        }

        switch rule {
        case .center:
            centerWindow(window, completion: onComplete)
        case .almostMaximize:
            almostMaximizeWindow(window, completion: onComplete)
        case .ignore:
            onComplete(false)
        }
    }

    private func scheduleWindowRetry(
        for app: NSRunningApplication,
        bundleId: String,
        appName: String,
        rule: WindowHandlingRule,
        attempt: Int,
        lastReason: WindowTargetRetryReason
    ) {
        let delays = [0.15, 0.25, 0.45, 0.75, 1.2]
        guard attempt <= delays.count else {
            AppLogger.shared.log("[重试] \(appName) 全部 \(delays.count) 次重试失败,放弃", level: .debug)
            recordActivity(
                for: app,
                kind: .skipped,
                title: lastReason == .accessibilityActivationPending ? "应用窗口接口不可用" : "等待窗口超时",
                detail: lastReason == .accessibilityActivationPending
                    ? userFacingUnavailableDetail(.accessibilityAPIDisabled)
                    : "多次等待后仍无法确认可管理的主窗口，本次不执行任何窗口操作。",
                trigger: "自动重试"
            )
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
                self.recordActivity(
                    for: app,
                    kind: .skipped,
                    title: "重试已取消",
                    detail: "等待期间用户切换到了其他 App，Maru 不再操作原来的窗口。",
                    trigger: "自动重试"
                )
                return
            }

            // 临时占用不应吞掉整个重试链，继续排下一轮。
            if self.isWindowOperationInProgress {
                AppLogger.shared.log("[重试#\(attempt)] \(appName) 延后: 其他窗口操作进行中", level: .debug)
                self.scheduleWindowRetry(
                    for: app,
                    bundleId: bundleId,
                    appName: appName,
                    rule: rule,
                    attempt: attempt + 1,
                    lastReason: lastReason
                )
                return
            }

            // 用户已经主动请求某个动作时，让手动兼容重试优先，避免自动呼吸先占用窗口。
            if self.pendingManualAccessibilityRetry != nil {
                AppLogger.shared.log("[重试#\(attempt)] \(appName) 取消自动重试: 等待手动窗口操作", level: .debug)
                return
            }

            switch self.resolveWindowTarget(for: frontmost, pointerLocation: self.activationMouseLocation) {
            case .selected(let window):
                AppLogger.shared.log("[重试#\(attempt)] \(appName) 成功解析唯一目标窗口", level: .info)
                self.executeSelectedWindow(window, app: frontmost, bundleId: bundleId, appName: appName, rule: rule, triggerSource: "automatic.retry")

            case .skip(let reason):
                AppLogger.shared.log("[重试#\(attempt)] \(appName) 终止: \(reason.rawValue)", level: .info)
                self.recordActivity(
                    for: frontmost,
                    kind: .skipped,
                    title: "重试后仍未处理",
                    detail: self.userFacingSkipDetail(reason),
                    trigger: "自动重试"
                )

            case .retry(let reason):
                AppLogger.shared.log("[重试#\(attempt)] \(appName) 继续等待: \(reason.rawValue)", level: .debug)
                self.scheduleWindowRetry(
                    for: app,
                    bundleId: bundleId,
                    appName: appName,
                    rule: rule,
                    attempt: attempt + 1,
                    lastReason: reason
                )

            case .unavailable(let reason):
                AppLogger.shared.log("[重试#\(attempt)] \(appName) 终止: \(reason.rawValue)", level: .warning)
                self.recordActivity(
                    for: frontmost,
                    kind: .skipped,
                    title: "应用窗口接口不可用",
                    detail: self.userFacingUnavailableDetail(reason),
                    trigger: "自动重试"
                )
            }
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
            activityStore.record(
                AppActivityEvent(
                    appName: target.appName,
                    bundleIdentifier: target.bundleId,
                    processIdentifier: target.processIdentifier,
                    kind: .failure,
                    title: "手动操作未执行",
                    detail: "目标 App 已退出或进程不可用，无法执行“\(action.label)”。",
                    trigger: userFacingTrigger(triggerSource)
                )
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
            showManualWindowAlert(
                reason: .noManageableWindow,
                triggerSource: triggerSource,
                appName: nil,
                appIdentity: nil,
                action: action
            )
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
        showsMissingWindowAlert: Bool,
        accessibilityRetryAttempt: Int = 0
    ) {
        let appName = app.localizedName ?? "未知应用"
        let bundleIdentifier = app.bundleIdentifier ?? "pid.\(app.processIdentifier)"

        if accessibilityRetryAttempt == 0 {
            pendingManualAccessibilityRetry?.cancel()
            pendingManualAccessibilityRetry = nil
        }

        guard checkAccessibilityPermission() else {
            recordActivity(
                for: app,
                kind: .failure,
                title: "缺少辅助功能权限",
                detail: "Maru 没有权限操作窗口，因此无法执行“\(action.label)”。",
                trigger: userFacingTrigger(triggerSource)
            )
            showAccessibilityPermissionAlert()
            return
        }

        guard !isWindowOperationInProgress else {
            AppLogger.shared.log("手动窗口操作被跳过: 当前已有窗口操作进行中, 来源=\(triggerSource), 动作=\(action.label)", level: .debug)
            recordActivity(
                for: app,
                kind: .skipped,
                title: "手动操作暂未执行",
                detail: "Maru 正在处理另一个窗口，因此跳过了“\(action.label)”。",
                trigger: userFacingTrigger(triggerSource)
            )
            return
        }

        let appIdentity = describeApplication(app)
        let requestPhase = accessibilityRetryAttempt == 0 ? "请求" : "兼容重试#\(accessibilityRetryAttempt)"
        AppLogger.shared.log("手动窗口操作\(requestPhase): 来源=\(triggerSource), 动作=\(action.label), 应用=\(appIdentity)", level: .info)

        let targetResolution = resolveManualTarget(for: app, triggerSource: triggerSource, action: action)
        let window: AXUIElement
        switch targetResolution {
        case .selected(let selectedWindow):
            window = selectedWindow

        case .retry(.accessibilityActivationPending):
            scheduleManualAccessibilityRetry(
                action,
                app: app,
                triggerSource: triggerSource,
                showsMissingWindowAlert: showsMissingWindowAlert,
                attempt: accessibilityRetryAttempt + 1
            )
            return

        case .unavailable(.accessibilityAPIDisabled):
            reportManualAccessibilityUnavailable(
                action,
                app: app,
                triggerSource: triggerSource,
                showsMissingWindowAlert: showsMissingWindowAlert
            )
            return

        case .skip(_), .retry(.windowNotReady):
            recordActivity(
                for: app,
                kind: .skipped,
                title: "没有可操作窗口",
                detail: "当前前台 App 没有符合条件的主窗口，未执行“\(action.label)”。",
                trigger: userFacingTrigger(triggerSource)
            )
            if showsMissingWindowAlert {
                showManualWindowAlert(
                    reason: .noManageableWindow,
                    triggerSource: triggerSource,
                    appName: appName,
                    appIdentity: appIdentity,
                    action: action
                )
            } else {
                AppLogger.shared.log("定向手动窗口操作未找到可操作窗口: 来源=\(triggerSource), 动作=\(action.label), 应用=\(appIdentity)", level: .warning)
            }
            return
        }

        // 只有在手动操作真正要执行窗口变更时，才取消排队中的自动处理
        debounceTimer?.invalidate()
        debounceTimer = nil

        isWindowOperationInProgress = true
        let windowTitle = activityWindowTitle(window)
        recordActivity(
            for: app,
            kind: .action,
            title: "手动执行\(action.label)",
            detail: "用户主动请求 Maru 对当前窗口执行“\(action.label)”。",
            windowTitle: windowTitle,
            trigger: userFacingTrigger(triggerSource)
        )

        switch action {
        case .center:
            centerWindow(window, completion: { [weak self] success in
                self?.handleWindowOperationCompletion(success: success, processIdentifier: app.processIdentifier, windowHash: CFHash(window), triggerSource: triggerSource, actionLabel: action.label, appIdentity: appIdentity, appName: appName, bundleIdentifier: bundleIdentifier, windowTitle: windowTitle)
            })
        case .almostMaximize:
            almostMaximizeWindow(window, completion: { [weak self] success in
                self?.handleWindowOperationCompletion(success: success, processIdentifier: app.processIdentifier, windowHash: CFHash(window), triggerSource: triggerSource, actionLabel: action.label, appIdentity: appIdentity, appName: appName, bundleIdentifier: bundleIdentifier, windowTitle: windowTitle)
            })
        case .moveToNextDisplay:
            moveWindowToNextDisplayUsingAppRule(window, app: app, appIdentity: appIdentity, completion: { [weak self] success in
                self?.handleWindowOperationCompletion(success: success, processIdentifier: app.processIdentifier, windowHash: CFHash(window), triggerSource: triggerSource, actionLabel: action.label, appIdentity: appIdentity, appName: appName, bundleIdentifier: bundleIdentifier, windowTitle: windowTitle)
            })
        }
    }

    private func handleWindowOperationCompletion(
        success: Bool,
        processIdentifier: pid_t,
        windowHash: CFHashCode,
        triggerSource: String,
        actionLabel: String,
        appIdentity: String,
        appName: String,
        bundleIdentifier: String,
        windowTitle: String?
    ) {
        if success {
            lastProcessedWindowInfo = (processIdentifier: processIdentifier, windowHash: windowHash, timestamp: Date())
            AppLogger.shared.log("窗口操作成功并已写入冷却: 来源=\(triggerSource), 动作=\(actionLabel), 应用=\(appIdentity)", level: .info)
        } else {
            AppLogger.shared.log("窗口操作未成功，未写入冷却: 来源=\(triggerSource), 动作=\(actionLabel), 应用=\(appIdentity)", level: .warning)
        }

        AppLogger.shared.log("窗口操作完成: 来源=\(triggerSource), 动作=\(actionLabel), 应用=\(appIdentity)", level: .info)

        activityStore.record(
            AppActivityEvent(
                appName: appName,
                bundleIdentifier: bundleIdentifier,
                processIdentifier: processIdentifier,
                kind: success ? .success : .failure,
                title: success ? "\(actionLabel)已完成" : "\(actionLabel)未完成",
                detail: success
                    ? "Maru 已完成窗口操作。"
                    : "窗口没有接受本次调整，或操作过程中发生错误。",
                windowTitle: windowTitle,
                trigger: userFacingTrigger(triggerSource)
            )
        )

        // 完成即释放全局操作状态；同一窗口仍由按 PID+窗口身份的冷却机制防重。
        // 固定等待会让这期间新启动或切入的应用无谓排队。
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isWindowOperationInProgress = false

            guard let pendingApp = self.pendingActivationApp else { return }
            self.pendingActivationApp = nil

            guard self.isMonitoring,
                  NSWorkspace.shared.frontmostApplication?.processIdentifier == pendingApp.processIdentifier else {
                return
            }

            AppLogger.shared.log("继续处理操作期间保留的应用切换: \(pendingApp.localizedName ?? "未知")", level: .debug)
            self.debounceWindowManagement(for: pendingApp)
        }
    }

    private func resolveManualTarget(
        for app: NSRunningApplication,
        triggerSource: String,
        action: ManualWindowAction
    ) -> ResolvedWindowTarget {
        let appIdentity = describeApplication(app)
        let result = resolveWindowTarget(for: app, pointerLocation: nil)
        switch result {
        case .selected(let window):
            AppLogger.shared.log("手动目标解析成功: 来源=\(triggerSource), 动作=\(action.label), 应用=\(appIdentity)", level: .info)
            return .selected(window)
        case .skip(let reason):
            AppLogger.shared.log("手动目标解析跳过: 来源=\(triggerSource), 动作=\(action.label), 应用=\(appIdentity), 原因=\(reason.rawValue)", level: .info)
            return .skip(reason)
        case .retry(let reason):
            AppLogger.shared.log("手动目标解析需要重试: 来源=\(triggerSource), 动作=\(action.label), 应用=\(appIdentity), 原因=\(reason.rawValue)", level: .debug)
            return .retry(reason)
        case .unavailable(let reason):
            AppLogger.shared.log("手动目标解析不可用: 来源=\(triggerSource), 动作=\(action.label), 应用=\(appIdentity), 原因=\(reason.rawValue)", level: .warning)
            return .unavailable(reason)
        }
    }

    private func scheduleManualAccessibilityRetry(
        _ action: ManualWindowAction,
        app: NSRunningApplication,
        triggerSource: String,
        showsMissingWindowAlert: Bool,
        attempt: Int
    ) {
        let delays = [0.15, 0.25, 0.45, 0.75]
        guard attempt >= 1, attempt <= delays.count else {
            reportManualAccessibilityUnavailable(
                action,
                app: app,
                triggerSource: triggerSource,
                showsMissingWindowAlert: showsMissingWindowAlert
            )
            return
        }

        pendingManualAccessibilityRetry?.cancel()

        let processIdentifier = app.processIdentifier
        let delay = delays[attempt - 1]
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingManualAccessibilityRetry = nil

            guard let runningApp = self.runningApplicationResolver(processIdentifier) else {
                AppLogger.shared.log("手动兼容重试取消: 目标进程已退出, pid=\(processIdentifier)", level: .warning)
                return
            }

            if showsMissingWindowAlert,
               NSWorkspace.shared.frontmostApplication?.processIdentifier != processIdentifier {
                AppLogger.shared.log("手动兼容重试取消: 用户已切换到其他应用, pid=\(processIdentifier)", level: .debug)
                self.recordActivity(
                    for: runningApp,
                    kind: .skipped,
                    title: "兼容重试已取消",
                    detail: "等待应用开放辅助功能窗口期间，用户切换到了其他 App。",
                    trigger: self.userFacingTrigger(triggerSource)
                )
                return
            }

            self.performManualWindowAction(
                action,
                app: runningApp,
                triggerSource: triggerSource,
                showsMissingWindowAlert: showsMissingWindowAlert,
                accessibilityRetryAttempt: attempt
            )
        }

        pendingManualAccessibilityRetry = workItem
        AppLogger.shared.log("手动窗口兼容重试将在 \(String(format: "%.2f", delay))s 后执行: 应用=\(describeApplication(app)), 次数=\(attempt)", level: .debug)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func reportManualAccessibilityUnavailable(
        _ action: ManualWindowAction,
        app: NSRunningApplication,
        triggerSource: String,
        showsMissingWindowAlert: Bool
    ) {
        let appName = app.localizedName ?? "当前应用"
        let appIdentity = describeApplication(app)
        recordActivity(
            for: app,
            kind: .skipped,
            title: "应用未开放辅助功能窗口",
            detail: userFacingUnavailableDetail(.accessibilityAPIDisabled),
            trigger: userFacingTrigger(triggerSource)
        )

        if showsMissingWindowAlert {
            showManualWindowAlert(
                reason: .accessibilityUnavailable,
                triggerSource: triggerSource,
                appName: appName,
                appIdentity: appIdentity,
                action: action
            )
        } else {
            AppLogger.shared.log("定向手动窗口操作无法访问应用窗口: 来源=\(triggerSource), 动作=\(action.label), 应用=\(appIdentity)", level: .warning)
        }
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

    private func recordActivity(
        for app: NSRunningApplication,
        kind: AppActivityEventKind,
        title: String,
        detail: String,
        windowTitle: String? = nil,
        trigger: String? = nil
    ) {
        guard let bundleIdentifier = app.bundleIdentifier,
              bundleIdentifier != Bundle.main.bundleIdentifier else {
            return
        }

        activityStore.record(
            AppActivityEvent(
                appName: app.localizedName ?? bundleIdentifier,
                bundleIdentifier: bundleIdentifier,
                processIdentifier: app.processIdentifier,
                kind: kind,
                title: title,
                detail: detail,
                windowTitle: windowTitle,
                trigger: trigger
            )
        )
    }

    private func recentMouseActivationTrigger() -> String {
        if let recentMouseDown,
           Date().timeIntervalSince(recentMouseDown.timestamp) <= mouseActivationIntentInterval {
            return "鼠标激活"
        }
        return "前台切换"
    }

    private func userFacingTrigger(_ triggerSource: String) -> String {
        if triggerSource.hasPrefix("automatic.retry") {
            return "自动重试"
        }
        if triggerSource.hasPrefix("automatic") {
            return "自动监控"
        }
        if triggerSource.contains("菜单栏") {
            return "菜单栏"
        }
        return "手动操作"
    }

    private func userFacingSkipDetail(_ reason: WindowTargetSkipReason) -> String {
        switch reason {
        case .auxiliaryWindow:
            return "当前焦点位于弹窗、面板或其他辅助窗口；为避免误操作，Maru 不会改动背后的主窗口。"
        case .ambiguousWindow:
            return "同时存在多个可能的主窗口，Maru 无法安全确认唯一目标，因此没有操作。"
        case .noManageableWindow:
            return "没有找到位置可写、状态正常的标准主窗口，因此没有操作。"
        }
    }

    private func userFacingRetryDetail(_ reason: WindowTargetRetryReason) -> String {
        switch reason {
        case .windowNotReady:
            return "App 已进入前台，但主窗口信息尚未就绪；Maru 将短暂等待后重试。"
        case .accessibilityActivationPending:
            return "App 暂未开放辅助功能窗口；Maru 已按需启用兼容模式，并将在短暂等待后重试。"
        }
    }

    private func userFacingUnavailableDetail(_ reason: WindowTargetUnavailableReason) -> String {
        switch reason {
        case .accessibilityAPIDisabled:
            return "目标 App 未向 macOS 开放辅助功能窗口。Maru 已尝试启用兼容模式，但仍无法读取窗口，因此没有执行操作。"
        }
    }

    private func activityWindowTitle(_ window: AXUIElement) -> String? {
        guard let title = copyStringAttribute(window, attribute: kAXTitleAttribute as CFString)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else {
            return nil
        }

        return String(title.prefix(120))
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

    private func showManualWindowAlert(
        reason: ManualWindowAlertReason,
        triggerSource: String,
        appName: String?,
        appIdentity: String?,
        action: ManualWindowAction
    ) {
        DispatchQueue.main.async {
            AppLogger.shared.log(
                "手动窗口操作无法执行: 来源=\(triggerSource), 动作=\(action.label), 应用=\(appIdentity ?? "未知应用"), 原因=\(String(describing: reason))",
                level: .warning
            )

            let alert = NSAlert()
            switch reason {
            case .noManageableWindow:
                alert.messageText = "无法找到可操作的窗口"
                alert.informativeText = "当前前台应用没有符合条件的活动主窗口。"
            case .accessibilityUnavailable:
                alert.messageText = "无法读取应用窗口"
                alert.informativeText = "\(appName ?? "当前应用") 暂未向 macOS 开放辅助功能窗口。Maru 已尝试启用兼容模式，但仍无法读取。"
            }
            alert.alertStyle = .warning
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
    }
    
    /// 将一次触发解析成唯一目标、明确跳过或等待重试。
    private func resolveWindowTarget(for app: NSRunningApplication, pointerLocation: CGPoint?) -> ResolvedWindowTarget {
        AppLogger.shared.log("开始解析应用 \(describeApplication(app)) 的唯一目标窗口", level: .debug)

        let appRef = AXUIElementCreateApplication(app.processIdentifier)
        let focusedWindow = copyAXElementAttribute(appRef, attribute: kAXFocusedWindowAttribute as CFString)
        let mainWindow = copyAXElementAttribute(appRef, attribute: kAXMainWindowAttribute as CFString)

        var windowsRef: AnyObject?
        let windowsError = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsRef)
        let listedWindows = windowsRef as? [AXUIElement] ?? []

        let accessibilityActivationRequestedAt = manualAccessibilityActivationRequestedAt[app.processIdentifier]
        let compatibilityDecision = WindowAccessibilityCompatibilityPolicy.decision(
            for: windowsError,
            activationRequestedAt: accessibilityActivationRequestedAt,
            graceInterval: manualAccessibilityActivationGraceInterval
        )

        switch compatibilityDecision {
        case .proceed:
            if windowsError == .success {
                manualAccessibilityActivationRequestedAt.removeValue(forKey: app.processIdentifier)

                if accessibilityActivationRequestedAt != nil {
                    AppLogger.shared.log("AXManualAccessibility 已生效: 应用=\(describeApplication(app))", level: .info)
                    observeWindowChanges(for: app)
                    recordActivity(
                        for: app,
                        kind: .success,
                        title: "应用窗口接口已启用",
                        detail: "Maru 已启用该 App 的辅助功能兼容模式，现在可以继续判断和操作窗口。",
                        trigger: "Electron 兼容"
                    )
                }
            }

        case .requestActivation:
            let activationResult = AXUIElementSetAttributeValue(
                appRef,
                kAXManualAccessibilityAttribute,
                true as CFTypeRef
            )
            AppLogger.shared.log(
                "目标 App 返回 apiDisabled，尝试启用 AXManualAccessibility: 应用=\(describeApplication(app)), result=\(axErrorDescription(activationResult))",
                level: activationResult == .success ? .info : .warning
            )

            guard activationResult == .success else {
                return .unavailable(.accessibilityAPIDisabled)
            }

            manualAccessibilityActivationRequestedAt[app.processIdentifier] = Date()
            recordActivity(
                for: app,
                kind: .window,
                title: "正在启用窗口接口",
                detail: userFacingRetryDetail(.accessibilityActivationPending),
                trigger: "Electron 兼容"
            )
            return .retry(.accessibilityActivationPending)

        case .awaitActivation:
            return .retry(.accessibilityActivationPending)

        case .unavailable:
            AppLogger.shared.log(
                "启用 AXManualAccessibility 后仍收到 apiDisabled: 应用=\(describeApplication(app))",
                level: .warning
            )
            return .unavailable(.accessibilityAPIDisabled)
        }

        if windowsError != .success {
            AppLogger.shared.log("读取 AXWindows 失败: \(axErrorDescription(windowsError)); 继续检查 Main/Focused", level: .debug)
        }

        var candidates: [AXWindowCandidate] = []

        @discardableResult
        func ensureCandidate(_ window: AXUIElement) -> Int {
            if let existing = candidates.first(where: { sameAXElement($0.element, window) }) {
                return existing.descriptor.index
            }

            let candidate = makeAXWindowCandidate(
                window,
                index: candidates.count,
                focusedWindow: focusedWindow,
                mainWindow: mainWindow
            )
            candidates.append(candidate)
            return candidate.descriptor.index
        }

        listedWindows.forEach { _ = ensureCandidate($0) }
        let focusedIndex = focusedWindow.map(ensureCandidate)
        let mainIndex = mainWindow.map(ensureCandidate)

        var clickedIndex: Int?
        var pointerHitTargetApplication = false

        if let pointerLocation {
            let axPoint = convertToAXCoordinates(pointerLocation)
            switch pointerHitResult(for: app, axPoint: axPoint) {
            case .targetWindow(let window):
                pointerHitTargetApplication = true
                clickedIndex = ensureCandidate(window)

            case .targetApplicationWithoutWindow:
                pointerHitTargetApplication = true
                let containing = candidates.filter { $0.frame?.contains(axPoint) == true }

                let nonManageable = containing
                    .filter { !$0.descriptor.isManageableBusinessWindow }
                    .sorted { ($0.frame?.width ?? 0) * ($0.frame?.height ?? 0) < ($1.frame?.width ?? 0) * ($1.frame?.height ?? 0) }

                if let auxiliary = nonManageable.first {
                    // 无法从 AX 层级拿到窗口时，优先保守识别覆盖在主窗上的小型辅助窗口。
                    clickedIndex = auxiliary.descriptor.index
                } else if let focusedIndex,
                   containing.contains(where: { $0.descriptor.index == focusedIndex }) {
                    clickedIndex = focusedIndex
                } else if let mainIndex,
                          containing.contains(where: { $0.descriptor.index == mainIndex }) {
                    clickedIndex = mainIndex
                } else if containing.count == 1 {
                    clickedIndex = containing[0].descriptor.index
                }

            case .noTargetApplicationHit:
                break
            }
        }

        for candidate in candidates {
            let descriptor = candidate.descriptor
            AppLogger.shared.log(
                "候选窗口[\(descriptor.index)]: role=\(descriptor.role ?? "nil"), subrole=\(descriptor.subrole ?? "nil"), main=\(String(describing: descriptor.isMain)), focused=\(descriptor.isFocused), modal=\(String(describing: descriptor.isModal)), positionSettable=\(descriptor.isPositionSettable), sizeSettable=\(descriptor.isSizeSettable), manageable=\(descriptor.isManageableBusinessWindow)",
                level: .debug
            )
        }

        let decision = WindowTargetPolicy.resolve(
            candidates: candidates.map(\.descriptor),
            clickedIndex: clickedIndex,
            pointerHitTargetApplication: pointerHitTargetApplication,
            focusedIndex: focusedIndex,
            mainIndex: mainIndex
        )

        switch decision {
        case .select(let index):
            guard let selected = candidates.first(where: { $0.descriptor.index == index }) else {
                return .retry(.windowNotReady)
            }
            AppLogger.shared.log("唯一目标窗口解析成功: index=\(index)", level: .info)
            return .selected(selected.element)
        case .skip(let reason):
            return .skip(reason)
        case .retry:
            return .retry(.windowNotReady)
        }
    }

    private func makeAXWindowCandidate(
        _ window: AXUIElement,
        index: Int,
        focusedWindow: AXUIElement?,
        mainWindow: AXUIElement?
    ) -> AXWindowCandidate {
        let role = copyStringAttribute(window, attribute: kAXRoleAttribute as CFString)
        let subrole = copyStringAttribute(window, attribute: kAXSubroleAttribute as CFString)
        let explicitMain = copyBoolAttribute(window, attribute: kAXMainAttribute as CFString)
        let isFocused = focusedWindow.map { sameAXElement(window, $0) } ?? false
        let isApplicationMain = mainWindow.map { sameAXElement(window, $0) } ?? false
        let parent = copyAXElementAttribute(window, attribute: kAXParentAttribute as CFString)
        let parentRole = parent.flatMap { copyStringAttribute($0, attribute: kAXRoleAttribute as CFString) }
        let signature = getWindowSignature(window)
        let frame = signature.map { CGRect(origin: $0.position, size: $0.size) }

        let descriptor = WindowTargetCandidate(
            index: index,
            role: role,
            subrole: subrole,
            isMinimized: isWindowMinimized(window),
            isModal: copyBoolAttribute(window, attribute: kAXModalAttribute as CFString),
            isMain: isApplicationMain ? true : explicitMain,
            isFocused: isFocused,
            parentRole: parentRole,
            isPositionSettable: isAXAttributeSettable(window, attribute: kAXPositionAttribute as CFString),
            isSizeSettable: isAXAttributeSettable(window, attribute: kAXSizeAttribute as CFString),
            hasReadableFrame: signature != nil
        )

        return AXWindowCandidate(element: window, descriptor: descriptor, frame: frame)
    }

    private func pointerHitResult(for app: NSRunningApplication, axPoint: CGPoint) -> PointerHitResult {
        var elementRef: AXUIElement?
        let error = AXUIElementCopyElementAtPosition(
            AXUIElementCreateSystemWide(),
            Float(axPoint.x),
            Float(axPoint.y),
            &elementRef
        )

        guard error == .success, let topElement = elementRef else {
            AppLogger.shared.log("鼠标命中测试失败: \(axErrorDescription(error))", level: .debug)
            return .noTargetApplicationHit
        }

        var topPid: pid_t = 0
        guard AXUIElementGetPid(topElement, &topPid) == .success,
              topPid == app.processIdentifier else {
            return .noTargetApplicationHit
        }

        var current = topElement
        for _ in 0..<20 {
            if copyStringAttribute(current, attribute: kAXRoleAttribute as CFString) == (kAXWindowRole as String) {
                return .targetWindow(current)
            }

            guard let parent = copyAXElementAttribute(current, attribute: kAXParentAttribute as CFString) else {
                break
            }
            current = parent
        }

        return .targetApplicationWithoutWindow
    }

    private func copyAXElementAttribute(_ element: AXUIElement, attribute: CFString) -> AXUIElement? {
        var valueRef: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute, &valueRef) == .success,
              let valueRef else {
            return nil
        }
        return (valueRef as! AXUIElement)
    }

    private func copyStringAttribute(_ element: AXUIElement, attribute: CFString) -> String? {
        var valueRef: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute, &valueRef) == .success else {
            return nil
        }
        return valueRef as? String
    }

    private func copyBoolAttribute(_ element: AXUIElement, attribute: CFString) -> Bool? {
        var valueRef: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute, &valueRef) == .success else {
            return nil
        }
        return valueRef as? Bool
    }

    private func isAXAttributeSettable(_ element: AXUIElement, attribute: CFString) -> Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(element, attribute, &settable) == .success && settable.boolValue
    }

    private func sameAXElement(_ lhs: AXUIElement, _ rhs: AXUIElement) -> Bool {
        CFEqual(lhs, rhs)
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

    private func setWindowPositionOnly(
        _ window: AXUIElement,
        targetPosition: CGPoint,
        expectedSize: CGSize,
        completion: ((Bool) -> Void)? = nil
    ) {
        guard isAXAttributeSettable(window, attribute: kAXPositionAttribute as CFString) else {
            AppLogger.shared.log("窗口位置不可写，取消操作", level: .warning)
            completion?(false)
            return
        }

        guard let axPosition = createAXValue(targetPosition, type: .cgPoint) else {
            completion?(false)
            return
        }

        let appElementToRestore = temporarilyDisableEnhancedUI(for: window)
        let result = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axPosition)
        scheduleEnhancedUIRestore(appElementToRestore)

        guard result == .success else {
            AppLogger.shared.log("位置调整失败: \(axErrorDescription(result))", level: .warning)
            completion?(false)
            return
        }

        let expectedFrame = CGRect(origin: targetPosition, size: expectedSize)
        verifyWindowChange(window, expectedFrame: expectedFrame, completion: completion)
    }

    @discardableResult
    private func setWindowSize(_ window: AXUIElement, targetSize: CGSize) -> AXError {
        guard let axSize = createAXValue(targetSize, type: .cgSize) else {
            return .illegalArgument
        }

        let appElementToRestore = temporarilyDisableEnhancedUI(for: window)
        let result = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, axSize)
        scheduleEnhancedUIRestore(appElementToRestore)
        return result
    }

    private func temporarilyDisableEnhancedUI(for window: AXUIElement) -> AXUIElement? {
        guard let pid = getPidForWindow(window) else { return nil }
        let appElement = AXUIElementCreateApplication(pid)

        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXEnhancedUserInterfaceAttribute, &value) == .success,
              (value as? Bool) == true else {
            return nil
        }

        AppLogger.shared.log("暂时禁用应用的增强型UI", level: .debug)
        AXUIElementSetAttributeValue(appElement, kAXEnhancedUserInterfaceAttribute, false as CFTypeRef)
        return appElement
    }

    private func scheduleEnhancedUIRestore(_ appElement: AXUIElement?) {
        guard let appElement else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            AppLogger.shared.log("恢复应用的增强型UI", level: .debug)
            AXUIElementSetAttributeValue(appElement, kAXEnhancedUserInterfaceAttribute, true as CFTypeRef)
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
        let currentScreen = getScreenForWindow(window)
        AppLogger.shared.log("使用屏幕: \(currentScreen.localizedName), frame: \(currentScreen.frame)", level: .debug)
        centerWindow(window, on: currentScreen, completion: completion)
    }

    private func almostMaximizeWindow(_ window: AXUIElement, completion: ((Bool) -> Void)? = nil) {
        AppLogger.shared.log("开始呼吸窗口操作", level: .debug)
        
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
        guard screens.count > 1 else {
            AppLogger.shared.log("移动到下一个显示器跳过: 当前没有下一块显示器", level: .info)
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
            moveWindowOnly(window, from: currentScreen, to: targetScreen) { [weak self] success in
                guard success, let self else {
                    completion?(false)
                    return
                }
                self.centerWindow(window, on: targetScreen, completion: completion)
            }
        case .almostMaximize:
            moveWindowOnly(window, from: currentScreen, to: targetScreen) { [weak self] success in
                guard success, let self else {
                    completion?(false)
                    return
                }
                self.almostMaximizeWindow(window, on: targetScreen, completion: completion)
            }
        case .ignore:
            moveWindowOnly(window, from: currentScreen, to: targetScreen, completion: completion)
        }
    }

    private func centerWindow(_ window: AXUIElement, on screen: NSScreen, completion: ((Bool) -> Void)? = nil) {
        guard let (_, size) = getWindowPositionAndSize(window) else {
            AppLogger.shared.log("居中失败: 无法获取窗口大小", level: .warning)
            completion?(false)
            return
        }

        positionWindowAtCenter(window, on: screen, using: size, completion: completion)
    }

    private func positionWindowAtCenter(
        _ window: AXUIElement,
        on screen: NSScreen,
        using actualSize: CGSize,
        completion: ((Bool) -> Void)? = nil
    ) {
        let nsOrigin = Self.centeredNSOrigin(
            windowSize: actualSize,
            screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame,
            dockLayout: currentDockLayout(),
            stageManagerSideMarginRatio: 0.15
        )
        let newPosition = convertToAXCoordinates(nsOrigin, size: actualSize)
        setWindowPositionOnly(window, targetPosition: newPosition, expectedSize: actualSize, completion: completion)
    }

    private func moveWindowOnly(_ window: AXUIElement, from currentScreen: NSScreen, to targetScreen: NSScreen, completion: ((Bool) -> Void)? = nil) {
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
        setWindowPositionForDisplayMove(
            window,
            targetPosition: targetFrame.origin,
            targetScreen: targetScreen,
            completion: completion
        )
    }

    private func setWindowPositionForDisplayMove(
        _ window: AXUIElement,
        targetPosition: CGPoint,
        targetScreen: NSScreen,
        completion: ((Bool) -> Void)? = nil
    ) {
        guard isAXAttributeSettable(window, attribute: kAXPositionAttribute as CFString) else {
            AppLogger.shared.log("跨屏移动失败: 窗口位置不可写", level: .warning)
            completion?(false)
            return
        }

        guard let axPosition = createAXValue(targetPosition, type: .cgPoint) else {
            completion?(false)
            return
        }

        let appElementToRestore = temporarilyDisableEnhancedUI(for: window)
        let result = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axPosition)
        scheduleEnhancedUIRestore(appElementToRestore)

        guard result == .success else {
            AppLogger.shared.log("跨屏移动失败: \(axErrorDescription(result))", level: .warning)
            completion?(false)
            return
        }

        // 跨显示器时 macOS 可能主动收缩窗口以适配目标屏幕，因此这里只验证
        // 窗口中心是否真正进入目标显示器，不能再要求中间 frame 像素级不变。
        let targetScreenFrame = convertToAXRect(targetScreen.frame)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self,
                  let (actualPosition, actualSize) = self.getWindowPositionAndSize(window) else {
                AppLogger.shared.log("跨屏移动失败: 无法读取移动后的窗口", level: .warning)
                completion?(false)
                return
            }

            let actualFrame = CGRect(origin: actualPosition, size: actualSize)
            guard Self.windowFrame(actualFrame, belongsTo: targetScreenFrame) else {
                AppLogger.shared.log("跨屏落点验证失败: 目标屏幕=\(targetScreenFrame), 实际Frame=\(actualFrame)", level: .warning)
                completion?(false)
                return
            }

            AppLogger.shared.log("跨屏落点验证成功: 实际Frame=\(actualFrame)", level: .debug)
            completion?(true)
        }
    }

    private func almostMaximizeWindow(_ window: AXUIElement, on screen: NSScreen, completion: ((Bool) -> Void)? = nil) {
        let capabilities = WindowActionCapabilities(
            isPositionSettable: isAXAttributeSettable(window, attribute: kAXPositionAttribute as CFString),
            isSizeSettable: isAXAttributeSettable(window, attribute: kAXSizeAttribute as CFString)
        )

        switch WindowActionPolicy.mutationPlan(for: .almostMaximize, capabilities: capabilities) {
        case .unavailable:
            AppLogger.shared.log("呼吸窗口失败: 窗口位置不可写", level: .warning)
            completion?(false)

        case .positionOnly:
            AppLogger.shared.log("呼吸窗口使用固定尺寸分支: 保持实际尺寸并居中", level: .info)
            centerWindow(window, on: screen, completion: completion)

        case .resizeThenCenter:
            guard let originalFrame = getWindowPositionAndSize(window).map({ CGRect(origin: $0.0, size: $0.1) }) else {
                completion?(false)
                return
            }

            applyResizableWindowFrame(
                window,
                on: screen,
                originalFrame: originalFrame,
                requestedFrame: almostMaximizedAXRect(for: screen),
                completion: completion
            )
        }
    }

    private func applyResizableWindowFrame(
        _ window: AXUIElement,
        on screen: NSScreen,
        originalFrame: CGRect,
        requestedFrame: CGRect,
        completion: ((Bool) -> Void)?
    ) {
        guard let axSize = createAXValue(requestedFrame.size, type: .cgSize),
              let axPosition = createAXValue(requestedFrame.origin, type: .cgPoint) else {
            completion?(false)
            return
        }

        // 恢复旧版已经验证稳定的顺序：尺寸 -> 位置 -> 再确认尺寸。
        // 某些刚启动的应用（例如 App Store）会忽略第一次尺寸写入，
        // 但在位置写入后会接受紧接着的第二次尺寸写入。
        let appElementToRestore = temporarilyDisableEnhancedUI(for: window)
        let initialSizeResult = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, axSize)
        let positionResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axPosition)
        let confirmedSizeResult = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, axSize)
        scheduleEnhancedUIRestore(appElementToRestore)

        AppLogger.shared.log(
            "呼吸窗口一次性写入结果: 初始尺寸=\(axErrorDescription(initialSizeResult)), 位置=\(axErrorDescription(positionResult)), 确认尺寸=\(axErrorDescription(confirmedSizeResult))",
            level: .debug
        )

        guard positionResult == .success else {
            AppLogger.shared.log("呼吸窗口位置写入失败: \(axErrorDescription(positionResult))", level: .warning)
            restoreWindowFrameBestEffort(window, frame: originalFrame)
            completion?(false)
            return
        }

        guard initialSizeResult == .success || confirmedSizeResult == .success else {
            AppLogger.shared.log("窗口拒绝目标尺寸，保持实际尺寸并居中", level: .info)
            centerWindow(window, on: screen, completion: completion)
            return
        }

        // 读取应用实际接受的尺寸；受最小/最大尺寸或宽高比约束时仍按实际尺寸居中。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self,
                  let (_, actualSize) = self.getWindowPositionAndSize(window) else {
                completion?(false)
                return
            }

            let resizeDidNotRespond = WindowResizeSettlingPolicy.shouldRetry(
                originalSize: originalFrame.size,
                actualSize: actualSize,
                requestedSize: requestedFrame.size,
                retriesRemaining: 1
            )
            if resizeDidNotRespond {
                AppLogger.shared.log("尺寸-位置-尺寸写入后窗口仍未改变，按当前实际尺寸居中", level: .info)
            }

            AppLogger.shared.log("呼吸窗口实际尺寸: \(actualSize), 请求尺寸: \(requestedFrame.size)", level: .debug)
            self.positionWindowAtCenter(window, on: screen, using: actualSize) { success in
                if !success {
                    self.restoreWindowFrameBestEffort(window, frame: originalFrame)
                }
                completion?(success)
            }
        }
    }

    private func restoreWindowFrameBestEffort(_ window: AXUIElement, frame: CGRect) {
        AppLogger.shared.log("窗口操作失败，尝试恢复原始 frame: \(frame)", level: .warning)

        if isAXAttributeSettable(window, attribute: kAXSizeAttribute as CFString) {
            _ = setWindowSize(window, targetSize: frame.size)
        }

        guard isAXAttributeSettable(window, attribute: kAXPositionAttribute as CFString),
              let axPosition = createAXValue(frame.origin, type: .cgPoint) else {
            return
        }
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axPosition)
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

    static func windowFrame(_ windowFrame: CGRect, belongsTo screenFrame: CGRect) -> Bool {
        guard !windowFrame.isNull, !windowFrame.isEmpty,
              !screenFrame.isNull, !screenFrame.isEmpty else {
            return false
        }

        return screenFrame.contains(CGPoint(x: windowFrame.midX, y: windowFrame.midY))
    }

    private static func clamp(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        guard maximum >= minimum else {
            return minimum
        }

        return Swift.min(Swift.max(value, minimum), maximum)
    }

    static func centeredNSOrigin(
        windowSize: CGSize,
        screenFrame: CGRect,
        visibleFrame: CGRect,
        dockLayout: DockLayoutState,
        stageManagerSideMarginRatio: CGFloat
    ) -> CGPoint {
        let contentFrame = layoutContentFrame(
            screenFrame: screenFrame,
            visibleFrame: visibleFrame,
            dockLayout: dockLayout
        )
        let stageManagerSideMargin = contentFrame.width * stageManagerSideMarginRatio
        let usableContentWidth = contentFrame.width - (stageManagerSideMargin * 2)

        return CGPoint(
            x: contentFrame.origin.x + stageManagerSideMargin + (usableContentWidth - windowSize.width) / 2,
            y: contentFrame.origin.y + (contentFrame.height - windowSize.height) / 2
        )
    }

    static func almostMaximizedNSRect(
        screenFrame: CGRect,
        visibleFrame: CGRect,
        dockLayout: DockLayoutState,
        scaleFactor: CGFloat
    ) -> CGRect {
        let contentFrame = layoutContentFrame(
            screenFrame: screenFrame,
            visibleFrame: visibleFrame,
            dockLayout: dockLayout
        )
        let horizontalMargin = (contentFrame.width * (1.0 - scaleFactor)) / 2
        let verticalMargin = (contentFrame.height * (1.0 - scaleFactor)) / 2

        return CGRect(
            x: contentFrame.origin.x + horizontalMargin,
            y: contentFrame.origin.y + verticalMargin,
            width: contentFrame.width - (horizontalMargin * 2),
            height: contentFrame.height - (verticalMargin * 2)
        )
    }

    private static func layoutContentFrame(
        screenFrame: CGRect,
        visibleFrame: CGRect,
        dockLayout: DockLayoutState
    ) -> CGRect {
        guard visibleFrame.width > 0, visibleFrame.height > 0 else {
            return screenFrame
        }

        // visibleFrame 的横向 inset 可能来自 Stage Manager 缩略图；只有左/右 Dock 可见时才把它当作真实占用。
        var minX = screenFrame.minX
        var maxX = screenFrame.maxX

        if !dockLayout.isAutohideEnabled {
            switch dockLayout.screenEdge {
            case .left:
                minX = visibleFrame.minX
            case .right:
                maxX = visibleFrame.maxX
            case .bottom:
                break
            case .unknown:
                minX = visibleFrame.minX
                maxX = visibleFrame.maxX
            }
        }

        return CGRect(
            x: minX,
            y: visibleFrame.minY,
            width: max(0, maxX - minX),
            height: visibleFrame.height
        )
    }

    private func almostMaximizedAXRect(for screen: NSScreen) -> CGRect {
        let scaleFactor = CGFloat(AppConfig.shared.windowScaleFactor)
        let nsRect = Self.almostMaximizedNSRect(
            screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame,
            dockLayout: currentDockLayout(),
            scaleFactor: scaleFactor
        )
        AppLogger.shared.log("使用比例系数: \(scaleFactor), 目标内容区域: \(screen.visibleFrame), 目标窗口区域: \(nsRect)", level: .debug)

        return convertToAXRect(nsRect)
    }

    private func currentDockLayout() -> DockLayoutState {
        do {
            return try dockLayoutReader.readDockLayout()
        } catch {
            AppLogger.shared.log("读取 Dock 布局失败，使用保守窗口区域: \(error.localizedDescription)", level: .warning)
            return .fallback
        }
    }
    
    // MARK: - 调试工具

    /// 测试函数：验证窗口调整优化
    func testEnhancedWindowFrameUpdate() {
        AppLogger.shared.log("开始测试窗口调整优化", level: .info)
        
        guard let app = NSWorkspace.shared.frontmostApplication,
              case .selected(let window) = resolveWindowTarget(for: app, pointerLocation: nil) else {
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
        // 计算测试位置（屏幕中央）
        let centerOrigin = Self.centeredNSOrigin(
            windowSize: size,
            screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame,
            dockLayout: currentDockLayout(),
            stageManagerSideMarginRatio: 0.15
        )
        let centerPosition = convertToAXCoordinates(centerOrigin, size: size)
        
        // 创建测试框架（原始大小，居中位置）
        let testFrame = CGRect(origin: centerPosition, size: size)
        
        setWindowPositionOnly(window, targetPosition: testFrame.origin, expectedSize: testFrame.size)
        
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
            self.setWindowPositionOnly(window, targetPosition: currentFrame.origin, expectedSize: currentFrame.size)
        }
    }
}

// 用于表示窗口的简单结构
struct CGWindow {
    let bounds: CGRect
} 
