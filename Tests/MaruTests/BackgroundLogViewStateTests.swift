import XCTest
@testable import Maru

final class BackgroundLogViewStateTests: XCTestCase {
    func testFilteringUsesMinimumLevelAndSearchText() {
        let logs = [
            entry(time: 1, message: "窗口候选", level: .debug, file: "WindowManager.swift"),
            entry(time: 2, message: "Safari 执行成功", level: .info, file: "WindowManager.swift"),
            entry(time: 3, message: "Dock 写入失败", level: .error, file: "DockSettings.swift")
        ]

        let state = BackgroundLogViewState(logs: logs, minimumLevel: .info, searchText: "windowmanager")

        XCTAssertEqual(state.filteredLogs.map(\.message), ["Safari 执行成功"])
    }

    func testFilteredLogsAreNewestFirstButCopiedTextIsChronological() {
        let older = entry(time: 1, message: "较早", level: .info, file: "A.swift")
        let newer = entry(time: 2, message: "较新", level: .warning, file: "B.swift")
        let state = BackgroundLogViewState(logs: [newer, older], minimumLevel: nil, searchText: "")

        XCTAssertEqual(state.filteredLogs.map(\.message), ["较新", "较早"])
        XCTAssertEqual(state.completeLogText, [older.formatted, newer.formatted].joined(separator: "\n"))
        XCTAssertEqual(state.filteredLogText, [older.formatted, newer.formatted].joined(separator: "\n"))
    }

    private func entry(
        time: TimeInterval,
        message: String,
        level: LogLevel,
        file: String
    ) -> LogEntry {
        LogEntry(
            timestamp: Date(timeIntervalSince1970: time),
            message: message,
            level: level,
            sourceFile: file,
            sourceLine: 10
        )
    }
}
