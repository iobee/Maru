import AppKit

enum AppIconProvider {
    private static let swiftPMResourceBundleName = "Maru_Maru.bundle"

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
        guard let url = resourceURL(named: "MaruIcon",
                                    withExtension: "icns",
                                    subdirectory: "Resources"),
              let icon = NSImage(contentsOf: url) else { return }
        NSApp.applicationIconImage = icon
    }

    static func resourceURL(
        named name: String,
        withExtension fileExtension: String,
        subdirectory: String,
        mainBundle: Bundle = .main,
        moduleBundleProvider: () -> Bundle? = { Bundle.module }
    ) -> URL? {
        if let url = mainBundle.url(forResource: name, withExtension: fileExtension) {
            return url
        }

        if let url = mainBundle.url(
            forResource: name,
            withExtension: fileExtension,
            subdirectory: subdirectory
        ) {
            return url
        }

        if let resourceURL = mainBundle.resourceURL {
            let resourceBundleURL = resourceURL.appendingPathComponent(
                swiftPMResourceBundleName,
                isDirectory: true
            )

            if let resourceBundle = Bundle(path: resourceBundleURL.path),
               let url = resourceBundle.url(
                   forResource: name,
                   withExtension: fileExtension,
                   subdirectory: subdirectory
               ) {
                return url
            }
        }

        return moduleBundleProvider()?.url(
            forResource: name,
            withExtension: fileExtension,
            subdirectory: subdirectory
        )
    }

    private static func menuBarImage() -> NSImage? {
        if let url = resourceURL(named: "MaruIconMenubar",
                                 withExtension: "png",
                                 subdirectory: "Resources") {
            return NSImage(contentsOf: url)
        }
        return nil
    }
}
