import AppKit

enum MainWindowChrome {
    static func applyProductStandard(to window: NSWindow) {
        window.level = .normal
        window.collectionBehavior = [.managed, .participatesInCycle, .primary]
        window.isOpaque = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
    }
}
