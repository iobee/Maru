import Foundation

struct AppActivityAppSummary: Identifiable, Equatable {
    var id: String { bundleIdentifier }

    let appName: String
    let bundleIdentifier: String
    let eventCount: Int
    let lastActivity: Date
}

struct AppActivityViewState {
    let events: [AppActivityEvent]
    let selectedBundleIdentifier: String?
    let appSearchText: String

    var appSummaries: [AppActivityAppSummary] {
        Dictionary(grouping: events, by: \AppActivityEvent.bundleIdentifier)
            .compactMap { bundleIdentifier, appEvents in
                guard let latestEvent = appEvents.max(by: { $0.timestamp < $1.timestamp }) else {
                    return nil
                }

                return AppActivityAppSummary(
                    appName: latestEvent.appName,
                    bundleIdentifier: bundleIdentifier,
                    eventCount: appEvents.count,
                    lastActivity: latestEvent.timestamp
                )
            }
            .sorted { lhs, rhs in
                if lhs.lastActivity == rhs.lastActivity {
                    return lhs.appName.localizedCaseInsensitiveCompare(rhs.appName) == .orderedAscending
                }
                return lhs.lastActivity > rhs.lastActivity
            }
    }

    var filteredAppSummaries: [AppActivityAppSummary] {
        let query = appSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return appSummaries }

        return appSummaries.filter {
            $0.appName.localizedCaseInsensitiveContains(query)
                || $0.bundleIdentifier.localizedCaseInsensitiveContains(query)
        }
    }

    var selectedAppSummary: AppActivityAppSummary? {
        guard let selectedBundleIdentifier else { return nil }
        return appSummaries.first { $0.bundleIdentifier == selectedBundleIdentifier }
    }

    var selectedEvents: [AppActivityEvent] {
        guard let selectedBundleIdentifier else { return [] }
        return events
            .filter { $0.bundleIdentifier == selectedBundleIdentifier }
            .sorted { $0.timestamp > $1.timestamp }
    }

    var suggestedBundleIdentifier: String? {
        if let selectedBundleIdentifier,
           filteredAppSummaries.contains(where: { $0.bundleIdentifier == selectedBundleIdentifier }) {
            return selectedBundleIdentifier
        }
        return filteredAppSummaries.first?.bundleIdentifier
    }
}
