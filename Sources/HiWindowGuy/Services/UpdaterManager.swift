import AppKit
import Combine
import Foundation
import Sparkle

@MainActor
final class UpdaterManager: NSObject, ObservableObject {
    enum UpdateCheckSource: String {
        case automatic = "自动"
        case manual = "手动"
    }

    enum UpdateCheckStatus: Equatable {
        case idle
        case unavailable(String)
        case checking(UpdateCheckSource)
        case updateAvailable(version: String)
        case noUpdateFound
        case failed(String)
    }

    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var lastCheckDate: Date?
    @Published private(set) var lastCheckStatus: UpdateCheckStatus = .idle

    private let logger: AppLogger
    private var didStartUpdater = false
    private var didPerformLaunchCheck = false
    private lazy var standardUpdaterController = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: self,
        userDriverDelegate: nil
    )

    private enum Configuration {
        static let defaultAppcastURL = "https://iobee.github.io/hiWindowGuy/appcast.xml"
        static let publicKeyPlaceholder = "REPLACE_WITH_SPARKLE_PUBLIC_ED25519_PUBLIC_KEY"
    }

    override init() {
        logger = AppLogger.shared
        super.init()
        refreshAvailability()
    }

    func start() {
        guard !didStartUpdater else {
            maybePerformLaunchCheck()
            return
        }

        guard let configuration = validateConfiguration() else {
            refreshAvailability()
            return
        }

        do {
            try standardUpdaterController.updater.start()
            didStartUpdater = true
            logger.log("Sparkle 更新器已启动，更新地址: \(configuration.feedURL.absoluteString)", level: .info)
            refreshAvailability()
            maybePerformLaunchCheck()
        } catch {
            lastCheckStatus = .failed(error.localizedDescription)
            logger.log("启动 Sparkle 更新器失败: \(error.localizedDescription)", level: .error)
            refreshAvailability()
        }
    }

    func checkForUpdates() {
        guard ensureUpdaterReadyForManualCheck() else {
            return
        }

        lastCheckDate = Date()
        lastCheckStatus = .checking(.manual)
        logger.log("开始手动检查更新", level: .info)

        standardUpdaterController.checkForUpdates(nil)
        refreshAvailability()
    }

    private func maybePerformLaunchCheck() {
        guard didStartUpdater, !didPerformLaunchCheck else {
            return
        }

        let updater = standardUpdaterController.updater
        guard updater.automaticallyChecksForUpdates else {
            logger.log("自动检查更新未启用，跳过启动检查", level: .debug)
            refreshAvailability()
            return
        }

        didPerformLaunchCheck = true
        lastCheckDate = Date()
        lastCheckStatus = .checking(.automatic)
        logger.log("应用启动后开始自动检查更新", level: .info)

        updater.checkForUpdatesInBackground()
        refreshAvailability()
    }

    private func ensureUpdaterReadyForManualCheck() -> Bool {
        if !didStartUpdater {
            start()
        }

        guard didStartUpdater else {
            if case .unavailable(let reason) = lastCheckStatus {
                showConfigurationAlert(message: reason)
            } else if case .failed(let message) = lastCheckStatus {
                showConfigurationAlert(message: message)
            }

            return false
        }

        guard standardUpdaterController.updater.canCheckForUpdates else {
            logger.log("当前无法发起新的更新检查", level: .warning)
            refreshAvailability()
            return false
        }

        return true
    }

    private func validateConfiguration() -> (feedURL: URL, publicKey: String)? {
        let feedURLString = configuredFeedURLString()

        guard let feedURL = URL(string: feedURLString),
              let scheme = feedURL.scheme?.lowercased(),
              scheme == "https" else {
            let message = "Sparkle 更新地址无效，请检查 SUFeedURL 配置"
            lastCheckStatus = .unavailable(message)
            logger.log(message, level: .error)
            return nil
        }

        let publicKey = configuredPublicKey()
        guard !publicKey.isEmpty, publicKey != Configuration.publicKeyPlaceholder else {
            let message = "Sparkle 公钥未配置，请在 Info.plist 中设置 SUPublicEDKey"
            lastCheckStatus = .unavailable(message)
            logger.log(message, level: .error)
            return nil
        }

        return (feedURL, publicKey)
    }

    private func configuredFeedURLString() -> String {
        if let infoPlistValue = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
           !infoPlistValue.isEmpty {
            return infoPlistValue
        }

        return Configuration.defaultAppcastURL
    }

    private func configuredPublicKey() -> String {
        (Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func refreshAvailability() {
        canCheckForUpdates = didStartUpdater && standardUpdaterController.updater.canCheckForUpdates
    }

    private func showConfigurationAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "无法检查更新"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
}

extension UpdaterManager: SPUUpdaterDelegate {
    func feedURLString(for updater: SPUUpdater) -> String? {
        configuredFeedURLString()
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        lastCheckStatus = .updateAvailable(version: item.displayVersionString)
        logger.log("发现新版本: \(item.displayVersionString)", level: .info)
        refreshAvailability()
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: any Error) {
        let nsError = error as NSError
        let reason = String(describing: nsError.userInfo[SPUNoUpdateFoundReasonKey] ?? "unknown")
        lastCheckStatus = .noUpdateFound
        logger.log("未发现可用更新，原因: \(reason)", level: .info)
        refreshAvailability()
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        lastCheckStatus = .failed(error.localizedDescription)
        logger.log("更新流程中止: \(error.localizedDescription)", level: .error)
        refreshAvailability()
    }

    func updater(_ updater: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: any Error) {
        lastCheckStatus = .failed(error.localizedDescription)
        logger.log("下载更新失败 (\(item.displayVersionString)): \(error.localizedDescription)", level: .error)
        refreshAvailability()
    }

    func userDidCancelDownload(_ updater: SPUUpdater) {
        lastCheckStatus = .idle
        logger.log("用户已取消更新下载", level: .info)
        refreshAvailability()
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        if let error {
            logger.log("更新检查流程完成，状态: \(error.localizedDescription)", level: .debug)
        } else {
            logger.log("更新检查流程完成", level: .debug)
        }

        refreshAvailability()
    }
}
