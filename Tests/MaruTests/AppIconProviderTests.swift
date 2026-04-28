import XCTest
@testable import Maru

final class AppIconProviderTests: XCTestCase {
    func testMenuBarIconIsManagedByAssetCatalog() {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let assetCatalogIcon = projectRoot
            .appendingPathComponent("Sources/Maru/Assets.xcassets/MaruIconMenubar.imageset/Contents.json")
        let legacyLooseIcon = projectRoot
            .appendingPathComponent("Sources/Maru/Resources/MaruIconMenubar.png")

        XCTAssertTrue(FileManager.default.fileExists(atPath: assetCatalogIcon.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyLooseIcon.path))
    }

    func testMenuBarIconUsesNamedAsset() {
        XCTAssertEqual(AppIconProvider.menuBarIconName, "MaruIconMenubar")
    }

    func testLoadAppIconReturnsImage() {
        let image = AppIconProvider.loadAppIcon(size: 32)
        XCTAssertEqual(image.size.width, 32)
        XCTAssertEqual(image.size.height, 32)
    }
}
