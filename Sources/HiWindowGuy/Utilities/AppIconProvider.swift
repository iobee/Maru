import AppKit

enum AppIconProvider {
    static func loadAppIcon(size: CGFloat) -> NSImage {
        let url = Bundle.module.url(forResource: "MaruIcon", withExtension: "icns")
               ?? Bundle.main.url(forResource: "MaruIcon", withExtension: "icns")
        if let url, let icon = NSImage(contentsOf: url) {
            icon.size = NSSize(width: size, height: size)
            return icon
        }
        return makeAppIcon(size: size)
    }

    static func makeAppIcon(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let bounds = NSRect(origin: .zero, size: image.size)
        let backgroundRect = bounds.insetBy(dx: size * 0.03, dy: size * 0.03)
        let cornerRadius = size * 0.24

        let shadow = NSShadow()
        shadow.shadowColor = NSColor(calibratedWhite: 0.0, alpha: 0.28)
        shadow.shadowBlurRadius = size * 0.08
        shadow.shadowOffset = NSSize(width: 0, height: -size * 0.03)
        shadow.set()

        let backgroundPath = NSBezierPath(roundedRect: backgroundRect, xRadius: cornerRadius, yRadius: cornerRadius)
        let backgroundGradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.11, alpha: 1.0),
            NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.18, alpha: 1.0),
            NSColor(calibratedRed: 0.13, green: 0.16, blue: 0.28, alpha: 1.0)
        ])!
        backgroundGradient.draw(in: backgroundPath, angle: -34)

        let glowGradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.45, green: 0.73, blue: 1.0, alpha: 0.16),
            NSColor(calibratedRed: 0.28, green: 0.49, blue: 0.95, alpha: 0.04),
            .clear
        ])!
        glowGradient.draw(in: backgroundPath, relativeCenterPosition: NSPoint(x: -0.55, y: 0.95))

        let highlightPath = NSBezierPath(
            roundedRect: bounds.insetBy(dx: size * 0.07, dy: size * 0.07),
            xRadius: cornerRadius * 0.78,
            yRadius: cornerRadius * 0.78
        )
        NSColor.white.withAlphaComponent(0.08).setStroke()
        highlightPath.lineWidth = max(2, size * 0.01)
        highlightPath.stroke()

        drawMinimalGlyph(
            in: backgroundRect,
            primary: NSColor.white,
            accent: NSColor(calibratedRed: 0.39, green: 0.77, blue: 1.0, alpha: 1.0)
        )

        image.unlockFocus()
        return image
    }

    static func makeMenuBarIcon(size: CGFloat = 18) -> NSImage {
        // Use the custom menubar icon if available
        if let url = Bundle.module.url(forResource: "MaruIconMenubar", withExtension: "png")
                ?? Bundle.main.url(forResource: "MaruIconMenubar", withExtension: "png"),
           let icon = NSImage(contentsOf: url) {
            icon.size = NSSize(width: size, height: size)
            icon.isTemplate = true
            return icon
        }

        let image = NSImage(size: NSSize(width: size, height: size))
        image.isTemplate = true
        image.lockFocus()

        NSColor.labelColor.setStroke()

        let frame = NSBezierPath(roundedRect: NSRect(
            x: size * 0.15,
            y: size * 0.17,
            width: size * 0.36,
            height: size * 0.36
        ), xRadius: size * 0.08, yRadius: size * 0.08)
        frame.lineWidth = max(1.2, size * 0.08)
        frame.stroke()

        let mark = NSBezierPath()
        mark.move(to: NSPoint(x: size * 0.42, y: size * 0.58))
        mark.line(to: NSPoint(x: size * 0.75, y: size * 0.89))
        mark.line(to: NSPoint(x: size * 0.75, y: size * 0.66))
        mark.lineWidth = max(1.65, size * 0.115)
        mark.lineCapStyle = .round
        mark.lineJoinStyle = .round
        mark.stroke()

        image.unlockFocus()
        return image
    }

    private static func drawMinimalGlyph(in bounds: NSRect, primary: NSColor, accent: NSColor) {
        let size = min(bounds.width, bounds.height)
        let majorLineWidth = max(10, size * 0.06)
        let minorLineWidth = max(6, size * 0.028)

        let frameShadow = NSShadow()
        frameShadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
        frameShadow.shadowBlurRadius = size * 0.035
        frameShadow.shadowOffset = NSSize(width: 0, height: -size * 0.015)

        NSGraphicsContext.current?.saveGraphicsState()
        frameShadow.set()
        let frame = NSBezierPath(roundedRect: NSRect(
            x: bounds.minX + size * 0.21,
            y: bounds.minY + size * 0.22,
            width: size * 0.42,
            height: size * 0.42
        ), xRadius: size * 0.11, yRadius: size * 0.11)
        frame.lineWidth = majorLineWidth
        primary.setStroke()
        frame.stroke()
        NSGraphicsContext.current?.restoreGraphicsState()

        let launch = NSBezierPath()
        launch.move(to: NSPoint(x: bounds.minX + size * 0.44, y: bounds.minY + size * 0.57))
        launch.line(to: NSPoint(x: bounds.minX + size * 0.70, y: bounds.minY + size * 0.83))
        launch.line(to: NSPoint(x: bounds.minX + size * 0.70, y: bounds.minY + size * 0.64))
        launch.lineWidth = majorLineWidth
        launch.lineCapStyle = .round
        launch.lineJoinStyle = .round
        primary.setStroke()
        launch.stroke()

        let spark = NSBezierPath()
        spark.move(to: NSPoint(x: bounds.minX + size * 0.73, y: bounds.minY + size * 0.73))
        spark.line(to: NSPoint(x: bounds.minX + size * 0.84, y: bounds.minY + size * 0.84))
        spark.lineWidth = minorLineWidth
        spark.lineCapStyle = .round
        accent.withAlphaComponent(0.95).setStroke()
        spark.stroke()
    }
}
