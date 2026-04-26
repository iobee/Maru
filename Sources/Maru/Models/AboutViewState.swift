import Foundation

struct AboutViewState {
    let appName: String
    let releaseLineText: String
    let signatureText: String
    let productDescriptionText: String
    let githubDisplayText: String
    let githubURL: URL

    init(infoDictionary: [String: Any]? = Bundle.main.infoDictionary) {
        let version = (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
        let build = (infoDictionary?["CFBundleVersion"] as? String) ?? "1"
        let bundleName = (infoDictionary?["CFBundleName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

        appName = bundleName?.isEmpty == false ? bundleName! : "Maru"
        releaseLineText = "版本 \(version) · 构建 \(build)"
        signatureText = "Center it beautifully."
        productDescriptionText = "Maru 是一款 macOS 窗口管理工具，可自动将窗口居中或以呼吸窗口模式调整，让桌面始终保持整洁顺手。开源免费。"
        githubDisplayText = "GitHub ↗"
        githubURL = URL(string: "https://github.com/iobee/Maru")!
    }
}
