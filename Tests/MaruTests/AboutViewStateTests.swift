import XCTest
@testable import Maru

final class AboutViewStateTests: XCTestCase {
    func testVersionDisplayUsesShortAndBuildVersions() {
        let state = AboutViewState(
            infoDictionary: [
                "CFBundleShortVersionString": "1.2.3",
                "CFBundleVersion": "45"
            ]
        )

        XCTAssertEqual(state.versionText, "版本 1.2.3")
        XCTAssertEqual(state.buildText, "构建 45")
        XCTAssertEqual(state.releaseLineText, "版本 1.2.3 · 构建 45")
        XCTAssertEqual(state.metaLineText, "版本 1.2.3 · 构建 45 · 版本检查稍后开放")
    }

    func testMissingVersionInfoFallsBackToDefaults() {
        let state = AboutViewState(infoDictionary: [:])

        XCTAssertEqual(state.appName, "Maru")
        XCTAssertEqual(state.versionText, "版本 1.0")
        XCTAssertEqual(state.buildText, "构建 1")
        XCTAssertEqual(state.updateStatusTitle, "版本检查即将支持")
        XCTAssertEqual(state.signatureText, "Center it beautifully.")
        XCTAssertEqual(state.localizedSloganText, "一键居中，让日常更优雅。")
        XCTAssertEqual(
            state.productDescriptionText,
            "Maru 是一款 macOS 开源工具，可自动将窗口优雅地移动到屏幕中央，让桌面始终简洁、平衡、顺手。"
        )
    }
}
