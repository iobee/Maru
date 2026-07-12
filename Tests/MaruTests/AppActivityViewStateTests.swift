import XCTest
@testable import Maru

final class AppActivityViewStateTests: XCTestCase {
    func testAppSummariesAreGroupedAndSortedByLatestActivity() {
        let state = AppActivityViewState(
            events: [
                event(time: 10, appName: "Safari", bundleIdentifier: "com.apple.Safari"),
                event(time: 20, appName: "Safari", bundleIdentifier: "com.apple.Safari"),
                event(time: 30, appName: "Notes", bundleIdentifier: "com.apple.Notes")
            ],
            selectedBundleIdentifier: nil,
            appSearchText: ""
        )

        XCTAssertEqual(state.appSummaries.map(\.bundleIdentifier), ["com.apple.Notes", "com.apple.Safari"])
        XCTAssertEqual(state.appSummaries.last?.eventCount, 2)
        XCTAssertEqual(state.suggestedBundleIdentifier, "com.apple.Notes")
    }

    func testAppSearchMatchesNameAndBundleIdentifier() {
        let events = [
            event(time: 10, appName: "Safari", bundleIdentifier: "com.apple.Safari"),
            event(time: 20, appName: "Notes", bundleIdentifier: "com.apple.Notes")
        ]

        let nameState = AppActivityViewState(events: events, selectedBundleIdentifier: nil, appSearchText: "saf")
        let bundleState = AppActivityViewState(events: events, selectedBundleIdentifier: nil, appSearchText: "apple.Notes")

        XCTAssertEqual(nameState.filteredAppSummaries.map(\.appName), ["Safari"])
        XCTAssertEqual(bundleState.filteredAppSummaries.map(\.appName), ["Notes"])
    }

    func testSelectedEventsAreNewestFirstAndScopedToApp() {
        let state = AppActivityViewState(
            events: [
                event(time: 10, appName: "Safari", bundleIdentifier: "com.apple.Safari", title: "较早"),
                event(time: 30, appName: "Notes", bundleIdentifier: "com.apple.Notes"),
                event(time: 20, appName: "Safari", bundleIdentifier: "com.apple.Safari", title: "较新")
            ],
            selectedBundleIdentifier: "com.apple.Safari",
            appSearchText: ""
        )

        XCTAssertEqual(state.selectedEvents.map(\.title), ["较新", "较早"])
    }

    private func event(
        time: TimeInterval,
        appName: String,
        bundleIdentifier: String,
        title: String = "进入前台"
    ) -> AppActivityEvent {
        AppActivityEvent(
            timestamp: Date(timeIntervalSince1970: time),
            appName: appName,
            bundleIdentifier: bundleIdentifier,
            kind: .activated,
            title: title,
            detail: "Maru 准备检查窗口。"
        )
    }
}
