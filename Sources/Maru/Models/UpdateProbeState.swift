enum UpdateProbeState: Equatable {
    case idle
    case checking
    case updateAvailable
    case failed
}

struct AboutUpdateStatusState: Equatable {
    let showsSpinner: Bool
    let message: String?

    init(showsSpinner: Bool, message: String?) {
        self.showsSpinner = showsSpinner
        self.message = message
    }

    init(probeState: UpdateProbeState) {
        switch probeState {
        case .checking:
            self.init(showsSpinner: true, message: nil)
        case .updateAvailable:
            self.init(showsSpinner: false, message: "发现新版本")
        case .idle, .failed:
            self.init(showsSpinner: false, message: nil)
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
        state = .updateAvailable
    }

    mutating func markNoUpdateFound() {
        state = .idle
    }

    mutating func markFailed() {
        state = .failed
    }
}
