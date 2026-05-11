import AppKit
import Combine

final class CurrentAppRuleTargetTracker: ObservableObject {
    @Published private(set) var menuTargetApp: CurrentAppRuleTarget?

    private let appBundleIdentifier: String
    private let workspaceNotificationCenter: NotificationCenter
    private let windowNotificationCenter: NotificationCenter
    private var workspaceActivationObserver: NSObjectProtocol?
    private var ownWindowKeyObserver: NSObjectProtocol?

    init(
        appBundleIdentifier: String,
        workspaceNotificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        windowNotificationCenter: NotificationCenter = NotificationCenter.default,
        observesNotifications: Bool = true
    ) {
        self.appBundleIdentifier = appBundleIdentifier
        self.workspaceNotificationCenter = workspaceNotificationCenter
        self.windowNotificationCenter = windowNotificationCenter

        guard observesNotifications else {
            return
        }

        workspaceActivationObserver = workspaceNotificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleWorkspaceActivation(notification)
        }

        ownWindowKeyObserver = windowNotificationCenter.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleWindowDidBecomeKey(notification)
        }
    }

    deinit {
        if let workspaceActivationObserver {
            workspaceNotificationCenter.removeObserver(workspaceActivationObserver)
        }
        if let ownWindowKeyObserver {
            windowNotificationCenter.removeObserver(ownWindowKeyObserver)
        }
    }

    func recordWorkspaceActivation(_ target: CurrentAppRuleTarget) {
        guard target.bundleId != appBundleIdentifier else {
            return
        }

        menuTargetApp = target
    }

    func recordOwnAppWindowTarget(_ target: CurrentAppRuleTarget) {
        menuTargetApp = target
    }

    private func handleWorkspaceActivation(_ notification: Notification) {
        guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let target = CurrentAppRuleTarget(application: application) else {
            return
        }

        recordWorkspaceActivation(target)
    }

    private func handleWindowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window.title == "Maru",
              let target = CurrentAppRuleTarget(application: NSRunningApplication.current) else {
            return
        }

        recordOwnAppWindowTarget(target)
    }
}
