import AppKit

struct CurrentAppRuleTarget: Equatable {
    let appName: String
    let bundleId: String
    let processIdentifier: pid_t

    init(appName: String, bundleId: String, processIdentifier: pid_t) {
        self.appName = appName
        self.bundleId = bundleId
        self.processIdentifier = processIdentifier
    }

    init?(application: NSRunningApplication) {
        guard let bundleId = application.bundleIdentifier else {
            return nil
        }

        let appName = application.localizedName?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.appName = appName?.isEmpty == false
            ? appName!
            : application.bundleURL?.deletingPathExtension().lastPathComponent ?? bundleId
        self.bundleId = bundleId
        self.processIdentifier = application.processIdentifier
    }
}
