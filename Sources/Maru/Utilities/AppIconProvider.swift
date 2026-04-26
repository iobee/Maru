import AppKit

enum AppIconProvider {
    /// Returns the app icon (from the already-set dock icon).
    static func loadAppIcon(size: CGFloat) -> NSImage {
        let icon = (NSApp.applicationIconImage ?? NSImage()).copy() as! NSImage
        icon.size = NSSize(width: size, height: size)
        return icon
    }

    /// Returns the menu bar icon from the resource bundle.
    static func makeMenuBarIcon(size: CGFloat = 18) -> NSImage {
        let icon = (menuBarImage() ?? NSImage()).copy() as! NSImage
        icon.size = NSSize(width: size, height: size)
        icon.isTemplate = true
        return icon
    }

    /// Sets the dock icon from the .icns file in the resource bundle.
    static func setDockIcon() {
        guard let url = Bundle.module.url(forResource: "MaruIcon",
                                           withExtension: "icns",
                                           subdirectory: "Resources"),
              let icon = NSImage(contentsOf: url) else { return }
        NSApp.applicationIconImage = icon
    }

    private static func menuBarImage() -> NSImage? {
        if let url = Bundle.module.url(forResource: "MaruIconMenubar",
                                        withExtension: "png",
                                        subdirectory: "Resources") {
            return NSImage(contentsOf: url)
        }
        return nil
    }
}
