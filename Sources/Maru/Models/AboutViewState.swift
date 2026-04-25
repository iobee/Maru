import Foundation

struct AboutViewState {
    let appName: String
    let versionText: String
    let buildText: String
    let releaseLineText: String
    let metaLineText: String
    let updateStatusTitle: String
    let updateStatusDetail: String
    let signatureText: String
    let localizedSloganText: String
    let productDescriptionText: String

    init(infoDictionary: [String: Any]? = Bundle.main.infoDictionary) {
        let version = (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
        let build = (infoDictionary?["CFBundleVersion"] as? String) ?? "1"
        let bundleName = (infoDictionary?["CFBundleName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

        appName = bundleName?.isEmpty == false ? bundleName! : "Maru"
        versionText = "版本 \(version)"
        buildText = "构建 \(build)"
        releaseLineText = "版本 \(version) · 构建 \(build)"
        updateStatusTitle = "版本检查即将支持"
        updateStatusDetail = "这个入口会在后续版本接入真实的更新源，现在先保留页面位置。"
        metaLineText = "版本 \(version) · 构建 \(build) · 版本检查稍后开放"
        signatureText = "Center it beautifully."
        localizedSloganText = "一键居中，让日常更优雅。"
        productDescriptionText = "Maru 是一款 macOS 开源工具，可自动将窗口优雅地移动到屏幕中央，让桌面始终简洁、平衡、顺手。"
    }
}
