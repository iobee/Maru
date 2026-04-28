import AppKit

enum MaruApplicationActivation {
    static func activateForConfigurationWindow(_ application: NSApplication = .shared) {
        application.activate(ignoringOtherApps: true)
    }

    static func activateForTextInput(_ application: NSApplication = .shared) {
        application.activate(ignoringOtherApps: true)
    }
}
