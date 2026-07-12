import AppKit

enum AppIconProvider {
    static let menuBarIconName = "MaruIconMenubar"

    /// Returns the app icon from the application bundle metadata.
    static func loadAppIcon(size: CGFloat) -> NSImage {
        guard let app = NSApp else {
            return NSImage(size: NSSize(width: size, height: size))
        }
        let source = app.applicationIconImage ?? NSImage(size: NSSize(width: size, height: size))
        let icon = (source.copy() as? NSImage) ?? source
        icon.size = NSSize(width: size, height: size)
        return icon
    }

    static func loadApplicationIcon(bundleIdentifier: String, size: CGFloat) -> NSImage {
        let workspace = NSWorkspace.shared
        let source: NSImage

        if let runningIcon = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .first?.icon {
            source = runningIcon
        } else if let applicationURL = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            source = workspace.icon(forFile: applicationURL.path)
        } else {
            source = NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil)
                ?? NSImage(size: NSSize(width: size, height: size))
        }

        let icon = (source.copy() as? NSImage) ?? source
        icon.size = NSSize(width: size, height: size)
        return icon
    }
}
