enum UpdateProbeState: Equatable {
    case idle
    case checking
    case updateAvailable
    case failed
}

struct AboutUpdateStatusState: Equatable {
    let showsSpinner: Bool
    let message: String?
    let actionTitle: String?

    init(showsSpinner: Bool, message: String?, actionTitle: String?) {
        self.showsSpinner = showsSpinner
        self.message = message
        self.actionTitle = actionTitle
    }

    init(probeState: UpdateProbeState) {
        switch probeState {
        case .checking:
            self.init(showsSpinner: true, message: nil, actionTitle: nil)
        case .updateAvailable:
            self.init(showsSpinner: false, message: nil, actionTitle: "发现新版本，点击更新")
        case .idle, .failed:
            self.init(showsSpinner: false, message: nil, actionTitle: nil)
        }
    }
}

struct UpdateProbeCoordinator {
    private var hasRequestedAboutProbe = false
    private(set) var state: UpdateProbeState = .idle

    init() {}

    mutating func startAboutProbeIfNeeded(canStart: Bool) -> Bool {
        guard canStart, hasRequestedAboutProbe == false else {
            return false
        }

        hasRequestedAboutProbe = true
        state = .checking
        return true
    }

    mutating func markUpdateFound() {
        guard state == .checking else {
            return
        }

        state = .updateAvailable
    }

    mutating func markNoUpdateFound() {
        guard state == .checking else {
            return
        }

        state = .idle
    }

    mutating func markFailed() {
        guard state == .checking else {
            return
        }

        state = .failed
    }
}

enum UpdatePreviewEnvironment {
    static let forceAboutUpdateAvailableKey = "MARU_FORCE_ABOUT_UPDATE_AVAILABLE"

    static func forcesAboutUpdateAvailable(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        guard let rawValue = environment[forceAboutUpdateAvailableKey]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return false
        }

        return ["1", "true", "yes"].contains(rawValue)
    }
}
