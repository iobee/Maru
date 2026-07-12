import Foundation

struct BackgroundLogViewState {
    let logs: [LogEntry]
    let minimumLevel: LogLevel?
    let searchText: String

    var filteredLogs: [LogEntry] {
        var result = logs

        if let minimumLevel {
            result = result.filter { $0.level.priority >= minimumLevel.priority }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            result = result.filter { entry in
                entry.message.localizedCaseInsensitiveContains(query)
                    || entry.sourceFile.localizedCaseInsensitiveContains(query)
                    || entry.level.rawValue.localizedCaseInsensitiveContains(query)
            }
        }

        return result.sorted { $0.timestamp > $1.timestamp }
    }

    var completeLogText: String {
        logs.sorted { $0.timestamp < $1.timestamp }
            .map(\.formatted)
            .joined(separator: "\n")
    }

    var filteredLogText: String {
        filteredLogs.reversed()
            .map(\.formatted)
            .joined(separator: "\n")
    }
}
