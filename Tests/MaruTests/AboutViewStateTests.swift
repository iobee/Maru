import XCTest
@testable import Maru

final class AboutViewStateTests: XCTestCase {
    func testAboutCardLayoutUsesPremiumProductCardMetrics() {
        XCTAssertEqual(AboutCardLayout.pageHorizontalPadding, 64, accuracy: 0.001)
        XCTAssertEqual(AboutCardLayout.pageTopPadding, 56, accuracy: 0.001)
        XCTAssertEqual(AboutCardLayout.titleToCardSpacing, 44, accuracy: 0.001)
        XCTAssertEqual(AboutCardLayout.cardMinHeight, 420, accuracy: 0.001)
        XCTAssertEqual(AboutCardLayout.cardPadding, 52, accuracy: 0.001)
        XCTAssertEqual(AboutCardLayout.cardCornerRadius, 32, accuracy: 0.001)
        XCTAssertEqual(AboutCardLayout.iconSize, 92, accuracy: 0.001)
        XCTAssertEqual(AboutCardLayout.titleFontSize, 50, accuracy: 0.001)
        XCTAssertEqual(AboutCardLayout.sloganFontSize, 24, accuracy: 0.001)
        XCTAssertEqual(AboutCardLayout.descriptionFontSize, 15, accuracy: 0.001)
        XCTAssertEqual(AboutCardLayout.contentColumnMaxWidth, 540, accuracy: 0.001)
        XCTAssertEqual(AboutCardLayout.centerGuideLength, 220, accuracy: 0.001)
        XCTAssertEqual(AboutCardLayout.shadowRadius, 60, accuracy: 0.001)
        XCTAssertEqual(AboutCardLayout.shadowYOffset, 24, accuracy: 0.001)
    }

    func testVersionDisplayUsesSingleReleaseLine() {
        let state = AboutViewState(
            infoDictionary: [
                "CFBundleShortVersionString": "1.2.3",
                "CFBundleVersion": "45"
            ]
        )

        XCTAssertEqual(state.releaseLineText, "版本 1.2.3 · 构建 45")

        let fieldLabels = reflectedFieldLabels(in: state)
        XCTAssertFalse(fieldLabels.contains("metaLineText"))
        XCTAssertFalse(fieldLabels.contains("updateStatusTitle"))
        XCTAssertFalse(fieldLabels.contains("updateStatusDetail"))
        XCTAssertFalse(fieldLabels.contains("localizedSloganText"))
    }

    func testProductCardMetadataUsesMaruBrandingAndGitHubLink() {
        let state = AboutViewState(infoDictionary: [:])
        let fields = reflectedFields(in: state)

        XCTAssertEqual(state.appName, "Maru")
        XCTAssertEqual(state.releaseLineText, "版本 1.0 · 构建 1")
        XCTAssertEqual(state.signatureText, "Center it beautifully.")
        XCTAssertEqual(
            state.productDescriptionText,
            "Maru 是一款 macOS 窗口管理工具，可自动将窗口居中或以呼吸窗口模式调整，让桌面始终保持整洁顺手。开源免费。"
        )
        XCTAssertEqual(fields["githubDisplayText"] as? String, "GitHub ↗")
        XCTAssertEqual((fields["githubURL"] as? URL)?.absoluteString, "https://github.com/iobee/Maru")
    }

    private func reflectedFieldLabels(in state: AboutViewState) -> Set<String> {
        Set(Mirror(reflecting: state).children.compactMap(\.label))
    }

    private func reflectedFields(in state: AboutViewState) -> [String: Any] {
        Dictionary(
            uniqueKeysWithValues: Mirror(reflecting: state).children.compactMap { child in
                guard let label = child.label else {
                    return nil
                }
                return (label, child.value)
            }
        )
    }
}
