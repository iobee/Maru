import Sparkle

@MainActor
final class UpdateService: NSObject, ObservableObject {
    static let shared = UpdateService()

    @Published private(set) var probeState: UpdateProbeState = .idle
    @Published private(set) var canCheckForUpdates = false

    private lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: self,
        userDriverDelegate: nil
    )

    private var probeCoordinator = UpdateProbeCoordinator()
    private var canCheckForUpdatesObservation: NSKeyValueObservation?

    private override init() {
        super.init()
        configureUpdaterStateObservation()
    }

    func checkForUpdates() {
        refreshCanCheckForUpdates()

        guard canCheckForUpdates else {
            AppLogger.shared.log("跳过手动更新检查: Sparkle 当前不允许检查更新", level: .warning)
            return
        }

        AppLogger.shared.log("开始手动检查更新", level: .info)
        updaterController.checkForUpdates(nil)
    }

    func checkForUpdatesFromAboutIfNeeded() {
        let updater = updaterController.updater
        let sessionInProgress = updater.sessionInProgress
        let didStart = probeCoordinator.startAboutProbeIfNeeded(canStart: sessionInProgress == false)
        publishProbeState()

        guard didStart else {
            let reason = sessionInProgress ? "Sparkle 更新会话正在进行" : "本次应用会话已执行过关于页更新探测"
            AppLogger.shared.log("跳过关于页更新探测: \(reason)", level: .info)
            return
        }

        AppLogger.shared.log("开始关于页更新探测", level: .info)
        updater.checkForUpdateInformation()
    }

    private func configureUpdaterStateObservation() {
        refreshCanCheckForUpdates()

        canCheckForUpdatesObservation = updaterController.updater.observe(
            \.canCheckForUpdates,
            options: [.new]
        ) { [weak self] _, change in
            guard let canCheckForUpdates = change.newValue else {
                return
            }

            Task { @MainActor in
                self?.canCheckForUpdates = canCheckForUpdates
            }
        }
    }

    private func refreshCanCheckForUpdates() {
        canCheckForUpdates = updaterController.updater.canCheckForUpdates
    }

    private func publishProbeState() {
        probeState = probeCoordinator.state
    }

    private func markProbeUpdateFound(versionDescription: String) {
        guard probeCoordinator.state == .checking else {
            return
        }

        probeCoordinator.markUpdateFound()
        publishProbeState()
        AppLogger.shared.log("关于页更新探测发现可用更新: \(versionDescription)", level: .info)
    }

    private func markProbeNoUpdateFound() {
        guard probeCoordinator.state == .checking else {
            return
        }

        probeCoordinator.markNoUpdateFound()
        publishProbeState()
        AppLogger.shared.log("关于页更新探测未发现可用更新", level: .info)
    }

    private func markProbeFailed(error: Error) {
        guard probeCoordinator.state == .checking else {
            return
        }

        probeCoordinator.markFailed()
        publishProbeState()
        AppLogger.shared.log("关于页更新探测失败: \(error.localizedDescription)", level: .warning)
    }
}

extension UpdateService: SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        markProbeUpdateFound(versionDescription: item.displayVersionString)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        markProbeNoUpdateFound()
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        markProbeNoUpdateFound()
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        markProbeFailed(error: error)
    }
}
