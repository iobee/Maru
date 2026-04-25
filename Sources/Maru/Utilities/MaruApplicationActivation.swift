import AppKit

enum MaruApplicationActivation {
    static let launchPolicy: NSApplication.ActivationPolicy = .accessory

    static func applyLaunchPolicy(to application: NSApplication = .shared) {
        application.setActivationPolicy(launchPolicy)
    }

    static func activateForTextInput(_ application: NSApplication = .shared) {
        application.activate(ignoringOtherApps: true)
    }
}
