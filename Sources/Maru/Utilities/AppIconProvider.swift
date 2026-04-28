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
}
