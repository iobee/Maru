import XCTest
@testable import Maru

final class AppIconProviderTests: XCTestCase {
    func testResourceLookupPrefersPackagedAppResourcesBeforeModuleBundle() throws {
        let packagedAppBundle = try makeBundle(
            named: "Packaged.app",
            resourceRelativePath: "Contents/Resources/MaruIconMenubar.png"
        )
        var moduleBundleWasRequested = false

        let url = AppIconProvider.resourceURL(
            named: "MaruIconMenubar",
            withExtension: "png",
            subdirectory: "Resources",
            mainBundle: packagedAppBundle
        ) {
            moduleBundleWasRequested = true
            return nil
        }

        XCTAssertEqual(url?.lastPathComponent, "MaruIconMenubar.png")
        XCTAssertFalse(moduleBundleWasRequested)
    }

    func testResourceLookupFallsBackToModuleBundleForSwiftRunResources() throws {
        let packagedAppBundle = try makeBundle(named: "Packaged.app")
        let moduleBundle = try makeBundle(
            named: "Maru_Maru.bundle",
            resourceRelativePath: "Resources/MaruIconMenubar.png"
        )

        let url = AppIconProvider.resourceURL(
            named: "MaruIconMenubar",
            withExtension: "png",
            subdirectory: "Resources",
            mainBundle: packagedAppBundle
        ) {
            moduleBundle
        }

        XCTAssertEqual(url?.lastPathComponent, "MaruIconMenubar.png")
        XCTAssertTrue(url?.path.contains("Maru_Maru.bundle/Resources") == true)
    }

    func testResourceLookupUsesPackagedSwiftPMBundleBeforeModuleFallback() throws {
        let packagedAppBundle = try makeBundle(
            named: "Packaged.app",
            resourceRelativePath: "Contents/Resources/Maru_Maru.bundle/Resources/MaruIconMenubar.png"
        )
        var moduleBundleWasRequested = false

        let url = AppIconProvider.resourceURL(
            named: "MaruIconMenubar",
            withExtension: "png",
            subdirectory: "Resources",
            mainBundle: packagedAppBundle
        ) {
            moduleBundleWasRequested = true
            return nil
        }

        XCTAssertEqual(url?.lastPathComponent, "MaruIconMenubar.png")
        XCTAssertTrue(url?.path.contains("Contents/Resources/Maru_Maru.bundle/Resources") == true)
        XCTAssertFalse(moduleBundleWasRequested)
    }

    private func makeBundle(
        named bundleName: String,
        resourceRelativePath: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> Bundle {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let bundleURL = rootURL.appendingPathComponent(bundleName, isDirectory: true)

        if bundleName.hasSuffix(".app") {
            try FileManager.default.createDirectory(
                at: bundleURL.appendingPathComponent("Contents/Resources", isDirectory: true),
                withIntermediateDirectories: true
            )
            let plistURL = bundleURL.appendingPathComponent("Contents/Info.plist")
            try """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>CFBundleExecutable</key>
                <string>Maru</string>
                <key>CFBundleIdentifier</key>
                <string>com.nick.maru.tests</string>
                <key>CFBundlePackageType</key>
                <string>APPL</string>
            </dict>
            </plist>
            """.write(to: plistURL, atomically: true, encoding: .utf8)
        } else {
            try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        }

        if let resourceRelativePath {
            let resourceURL = bundleURL.appendingPathComponent(resourceRelativePath)
            try FileManager.default.createDirectory(
                at: resourceURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data([0x00]).write(to: resourceURL)
        }

        guard let bundle = Bundle(path: bundleURL.path) else {
            XCTFail("Expected test bundle to load at \(bundleURL.path)", file: file, line: line)
            throw NSError(domain: "AppIconProviderTests", code: 1)
        }

        addTeardownBlock {
            try? FileManager.default.removeItem(at: rootURL)
        }

        return bundle
    }
}
