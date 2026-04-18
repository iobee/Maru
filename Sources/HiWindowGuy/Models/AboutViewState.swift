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

    init(infoDictionary: [String: Any]? = Bundle.main.infoDictionary) {
        let version = (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
        let build = (infoDictionary?["CFBundleVersion"] as? String) ?? "1"
        let bundleName = (infoDictionary?["CFBundleName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

        appName = bundleName?.isEmpty == false ? bundleName! : "HiWindowGuy"
        versionText = "版本 \(version)"
        buildText = "构建 \(build)"
        releaseLineText = "版本 \(version) · 构建 \(build)"
        updateStatusTitle = "版本检查即将支持"
        updateStatusDetail = "这个入口会在后续版本接入真实的更新源，现在先保留页面位置。"
        metaLineText = "版本 \(version) · 构建 \(build) · 版本检查稍后开放"
        signatureText = "Enjoy your life!"
    }
}
