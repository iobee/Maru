import AppKit

enum MainWindowChrome {
    static func applyProductStandard(to window: NSWindow) {
        window.collectionBehavior = [.managed, .participatesInCycle, .fullScreenPrimary]
        window.isOpaque = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
    }
}
