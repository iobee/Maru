# Menu Bar Current App Rule Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a native Maru menu bar submenu that quickly configures the captured current application's window rule.

**Architecture:** Keep display and rule-selection logic testable with pure models. Track the pre-menu target from app activation history, persist rules through `AppConfig`, and apply layout actions through a pid-targeted `WindowManager` API so quick-menu actions do not accidentally operate on Maru or the wrong frontmost app.

**Tech Stack:** Swift 5.8, SwiftUI `MenuBarExtra`, AppKit `NSWorkspace` / `NSRunningApplication`, XCTest.

---

## Relevant Specs And Existing Files

- Spec: `docs/superpowers/specs/2026-05-11-menu-bar-current-app-rule-design.md`
- Current menu wiring: `Sources/Maru/MaruApp.swift`
- Menu layout model: `Sources/Maru/Models/StatusBarMenuLayout.swift`
- Rule persistence: `Sources/Maru/Models/AppConfig.swift`
- Manual window actions: `Sources/Maru/Services/WindowManager.swift`
- Existing menu tests: `Tests/MaruTests/StatusBarMenuLayoutTests.swift`

## File Structure

- Create `Sources/Maru/Models/CurrentAppRuleTarget.swift`
  - Value type for app name, bundle id, and process id.

- Create `Sources/Maru/Models/CurrentAppRuleMenuState.swift`
  - Pure menu presentation state: title, enabled/unavailable state, selected rule, ordered rule options.

- Create `Sources/Maru/Services/CurrentAppRuleTargetTracker.swift`
  - `ObservableObject` that tracks app activation notifications and resolves the target shown in the menu.
  - Uses a small pure reducer internally so target edge cases are unit-testable.

- Modify `Sources/Maru/Models/AppConfig.swift`
  - Add `setRule(for:appName:rule:)` upsert API.

- Modify `Sources/Maru/Services/WindowManager.swift`
  - Add a pid-targeted manual action API used by quick menu rule application.

- Modify `Sources/Maru/Models/StatusBarMenuLayout.swift`
  - Add a stable layout item for the current app rule submenu.

- Modify `Sources/Maru/MaruApp.swift`
  - Render the top current-app submenu and wire rule selection.

- Tests:
  - Create `Tests/MaruTests/CurrentAppRuleMenuStateTests.swift`
  - Create `Tests/MaruTests/CurrentAppRuleTargetTrackerTests.swift`
  - Create `Tests/MaruTests/AppConfigRuleUpsertTests.swift`
  - Create `Tests/MaruTests/WindowManagerTargetedActionTests.swift`
  - Create `Tests/MaruTests/CurrentAppRuleMenuSelectionTests.swift`
  - Update `Tests/MaruTests/StatusBarMenuLayoutTests.swift`

## Task 1: Current App Rule Menu State

**Files:**
- Create: `Sources/Maru/Models/CurrentAppRuleTarget.swift`
- Create: `Sources/Maru/Models/CurrentAppRuleMenuState.swift`
- Test: `Tests/MaruTests/CurrentAppRuleMenuStateTests.swift`

- [ ] **Step 1: Write failing tests for menu presentation**

Create `Tests/MaruTests/CurrentAppRuleMenuStateTests.swift`:

```swift
import XCTest
@testable import Maru

final class CurrentAppRuleMenuStateTests: XCTestCase {
    func testBuildsEnabledMenuTitleFromAppName() {
        let target = CurrentAppRuleTarget(
            appName: "Codex",
            bundleId: "com.openai.codex",
            processIdentifier: 123
        )

        let state = CurrentAppRuleMenuState(target: target, appRules: [])

        XCTAssertTrue(state.isEnabled)
        XCTAssertEqual(state.title, "配置当前应用：Codex")
    }

    func testMissingTargetBuildsDisabledUnavailableState() {
        let state = CurrentAppRuleMenuState(target: nil, appRules: [])

        XCTAssertFalse(state.isEnabled)
        XCTAssertEqual(state.title, "当前应用不可用")
    }

    func testUnsavedAppDisplaysDefaultAlmostMaximizeRule() {
        let target = CurrentAppRuleTarget(
            appName: "Codex",
            bundleId: "com.openai.codex",
            processIdentifier: 123
        )

        let state = CurrentAppRuleMenuState(target: target, appRules: [])

        XCTAssertEqual(state.selectedRule, .almostMaximize)
        XCTAssertEqual(state.ruleOptions, [.almostMaximize, .center, .ignore])
        XCTAssertEqual(state.ruleOptions.map(\.currentAppRuleMenuTitle), ["呼吸窗口", "居中窗口", "忽略此应用"])
    }

    func testRenderingStateForUnsavedAppDoesNotMutateConfig() throws {
        let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("Maru-MenuState-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let config = AppConfig(storageDirectoryURL: directoryURL)
        let target = CurrentAppRuleTarget(
            appName: "Codex",
            bundleId: "com.openai.codex",
            processIdentifier: 123
        )

        _ = CurrentAppRuleMenuState(target: target, appRules: config.appRules)

        XCTAssertFalse(config.appRules.contains(where: { $0.bundleId == "com.openai.codex" }))
    }

    func testSavedRuleDrivesSelectedRule() {
        let target = CurrentAppRuleTarget(
            appName: "Codex",
            bundleId: "com.openai.codex",
            processIdentifier: 123
        )
        let rule = AppRule(
            bundleId: "com.openai.codex",
            appName: "Codex",
            rule: .center,
            lastUsed: Date(timeIntervalSince1970: 0),
            useCount: 2
        )

        let state = CurrentAppRuleMenuState(target: target, appRules: [rule])

        XCTAssertEqual(state.selectedRule, .center)
    }
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run: `swift test --filter CurrentAppRuleMenuStateTests`

Expected: build failure because `CurrentAppRuleTarget` and `CurrentAppRuleMenuState` do not exist.

- [ ] **Step 3: Implement minimal models**

Create `Sources/Maru/Models/CurrentAppRuleTarget.swift`:

```swift
import Foundation

struct CurrentAppRuleTarget: Equatable {
    let appName: String
    let bundleId: String
    let processIdentifier: pid_t
}
```

Create `Sources/Maru/Models/CurrentAppRuleMenuState.swift`:

```swift
import Foundation

struct CurrentAppRuleMenuState: Equatable {
    let target: CurrentAppRuleTarget?
    let selectedRule: WindowHandlingRule
    let ruleOptions: [WindowHandlingRule]

    init(target: CurrentAppRuleTarget?, appRules: [AppRule]) {
        self.target = target
        self.ruleOptions = [.almostMaximize, .center, .ignore]

        guard let target,
              let existingRule = appRules.first(where: { $0.bundleId == target.bundleId }) else {
            self.selectedRule = .almostMaximize
            return
        }

        self.selectedRule = existingRule.rule
    }

    var isEnabled: Bool {
        target != nil
    }

    var title: String {
        guard let target else {
            return "当前应用不可用"
        }
        return "配置当前应用：\(target.appName)"
    }
}

extension WindowHandlingRule {
    var currentAppRuleMenuTitle: String {
        switch self {
        case .almostMaximize:
            return "呼吸窗口"
        case .center:
            return "居中窗口"
        case .ignore:
            return "忽略此应用"
        }
    }
}
```

- [ ] **Step 4: Run tests and verify they pass**

Run: `swift test --filter CurrentAppRuleMenuStateTests`

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Maru/Models/CurrentAppRuleTarget.swift Sources/Maru/Models/CurrentAppRuleMenuState.swift Tests/MaruTests/CurrentAppRuleMenuStateTests.swift
git commit -m "Add current app rule menu state"
```

## Task 2: AppConfig Rule Upsert

**Files:**
- Modify: `Sources/Maru/Models/AppConfig.swift`
- Test: `Tests/MaruTests/AppConfigRuleUpsertTests.swift`

- [ ] **Step 1: Write failing tests for rule upsert**

Create `Tests/MaruTests/AppConfigRuleUpsertTests.swift`:

```swift
import XCTest
@testable import Maru

final class AppConfigRuleUpsertTests: XCTestCase {
    private var storageDirectoryURL: URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("Maru-RuleUpsert-\(UUID().uuidString)", isDirectory: true)
    }

    private func makeConfig() throws -> AppConfig {
        let directoryURL = storageDirectoryURL
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return AppConfig(storageDirectoryURL: directoryURL)
    }

    func testSetRuleCreatesRuleForNewApp() throws {
        let config = try makeConfig()

        config.setRule(for: "com.openai.codex", appName: "Codex", rule: .center)

        let rule = try XCTUnwrap(config.appRules.first(where: { $0.bundleId == "com.openai.codex" }))
        XCTAssertEqual(rule.appName, "Codex")
        XCTAssertEqual(rule.rule, .center)
        XCTAssertEqual(rule.useCount, 0)
    }

    func testSetRuleUpdatesExistingRule() throws {
        let config = try makeConfig()
        config.setRule(for: "com.openai.codex", appName: "Codex", rule: .center)

        config.setRule(for: "com.openai.codex", appName: "Codex", rule: .ignore)

        let matchingRules = config.appRules.filter { $0.bundleId == "com.openai.codex" }
        XCTAssertEqual(matchingRules.count, 1)
        XCTAssertEqual(matchingRules.first?.rule, .ignore)
    }
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run: `swift test --filter AppConfigRuleUpsertTests`

Expected: build failure because `setRule(for:appName:rule:)` does not exist.

- [ ] **Step 3: Implement `setRule` in `AppConfig`**

In `Sources/Maru/Models/AppConfig.swift`, add this near `updateRule(for:rule:)`:

```swift
func setRule(for bundleId: String, appName: String, rule: WindowHandlingRule) {
    if let index = appRules.firstIndex(where: { $0.bundleId == bundleId }) {
        var updatedRule = appRules[index]
        updatedRule.rule = rule
        updatedRule.lastUsed = Date()
        appRules[index] = updatedRule
    } else {
        let newRule = AppRule(
            bundleId: bundleId,
            appName: appName,
            rule: rule,
            lastUsed: Date(),
            useCount: 0
        )
        appRules.append(newRule)
    }

    saveConfig()
    refreshID = UUID()
    NotificationCenter.default.post(name: Notification.Name("RuleUpdated"), object: nil)
}
```

Do not change `getRule(for:appName:)`; it should continue to record app usage for automatic management.

- [ ] **Step 4: Run tests and verify they pass**

Run: `swift test --filter AppConfigRuleUpsertTests`

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Maru/Models/AppConfig.swift Tests/MaruTests/AppConfigRuleUpsertTests.swift
git commit -m "Add app rule upsert API"
```

## Task 3: Current App Target Tracker

**Files:**
- Create: `Sources/Maru/Services/CurrentAppRuleTargetTracker.swift`
- Test: `Tests/MaruTests/CurrentAppRuleTargetTrackerTests.swift`

- [ ] **Step 1: Write failing tests for target resolution**

Create `Tests/MaruTests/CurrentAppRuleTargetTrackerTests.swift`:

```swift
import XCTest
@testable import Maru

final class CurrentAppRuleTargetTrackerTests: XCTestCase {
    private let codex = CurrentAppRuleTarget(appName: "Codex", bundleId: "com.openai.codex", processIdentifier: 101)
    private let maru = CurrentAppRuleTarget(appName: "Maru", bundleId: "com.nick.maru", processIdentifier: 202)

    func testNonMaruWorkspaceActivationBecomesMenuTarget() {
        var state = CurrentAppRuleTargetTrackerState(appBundleIdentifier: "com.nick.maru")

        state.recordWorkspaceActivation(codex)

        XCTAssertEqual(state.menuTargetApp, codex)
    }

    func testOwnAppWorkspaceActivationKeepsPreviousTarget() {
        var state = CurrentAppRuleTargetTrackerState(appBundleIdentifier: "com.nick.maru")
        state.recordWorkspaceActivation(codex)

        state.recordWorkspaceActivation(maru)

        XCTAssertEqual(state.menuTargetApp, codex)
    }

    func testOwnAppKeyWindowActivationCanBeTarget() {
        var state = CurrentAppRuleTargetTrackerState(appBundleIdentifier: "com.nick.maru")
        state.recordWorkspaceActivation(codex)

        state.recordOwnAppWindowTarget(maru)

        XCTAssertEqual(state.menuTargetApp, maru)
    }
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run: `swift test --filter CurrentAppRuleTargetTrackerTests`

Expected: build failure because tracker types do not exist.

- [ ] **Step 3: Implement pure tracker state and observable tracker**

Create `Sources/Maru/Services/CurrentAppRuleTargetTracker.swift`:

```swift
import AppKit
import Combine

struct CurrentAppRuleTargetTrackerState {
    let appBundleIdentifier: String
    private(set) var lastActivatedApp: CurrentAppRuleTarget?
    private(set) var menuTargetApp: CurrentAppRuleTarget?

    mutating func recordWorkspaceActivation(_ target: CurrentAppRuleTarget) {
        lastActivatedApp = target

        if target.bundleId == appBundleIdentifier {
            return
        }

        menuTargetApp = target
    }

    mutating func recordOwnAppWindowTarget(_ target: CurrentAppRuleTarget) {
        guard target.bundleId == appBundleIdentifier else {
            return
        }

        lastActivatedApp = target
        menuTargetApp = target
    }
}

final class CurrentAppRuleTargetTracker: ObservableObject {
    @Published private(set) var menuTargetApp: CurrentAppRuleTarget?

    private let workspaceNotificationCenter: NotificationCenter
    private let windowNotificationCenter: NotificationCenter
    private var state: CurrentAppRuleTargetTrackerState
    private var workspaceActivationObserver: NSObjectProtocol?
    private var windowKeyObserver: NSObjectProtocol?

    init(
        appBundleIdentifier: String,
        workspaceNotificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        windowNotificationCenter: NotificationCenter = .default
    ) {
        self.workspaceNotificationCenter = workspaceNotificationCenter
        self.windowNotificationCenter = windowNotificationCenter
        self.state = CurrentAppRuleTargetTrackerState(appBundleIdentifier: appBundleIdentifier)

        workspaceActivationObserver = workspaceNotificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleActivationNotification(notification)
        }

        windowKeyObserver = windowNotificationCenter.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleWindowDidBecomeKeyNotification(notification)
        }
    }

    deinit {
        if let workspaceActivationObserver {
            workspaceNotificationCenter.removeObserver(workspaceActivationObserver)
        }
        if let windowKeyObserver {
            windowNotificationCenter.removeObserver(windowKeyObserver)
        }
    }

    func recordOwnAppWindowTarget(_ target: CurrentAppRuleTarget) {
        state.recordOwnAppWindowTarget(target)
        menuTargetApp = state.menuTargetApp
    }

    private func handleActivationNotification(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let target = CurrentAppRuleTarget(app: app) else {
            return
        }

        state.recordWorkspaceActivation(target)
        menuTargetApp = state.menuTargetApp
    }

    private func handleWindowDidBecomeKeyNotification(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window.title == "Maru",
              let target = CurrentAppRuleTarget(app: NSRunningApplication.current) else {
            return
        }

        recordOwnAppWindowTarget(target)
    }
}

extension CurrentAppRuleTarget {
    init?(app: NSRunningApplication) {
        guard let appName = app.localizedName,
              let bundleId = app.bundleIdentifier else {
            return nil
        }

        self.init(appName: appName, bundleId: bundleId, processIdentifier: app.processIdentifier)
    }
}
```

The tracker owns both observer tokens and removes them in `deinit`. Do not add another `NSWindow.didBecomeKeyNotification` observer in `MaruApp.configureWindow()` for this feature. The existing window chrome observer can remain unchanged unless implementation work needs to touch it for another reason.

- [ ] **Step 4: Run tests and verify they pass**

Run: `swift test --filter CurrentAppRuleTargetTrackerTests`

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Maru/Services/CurrentAppRuleTargetTracker.swift Tests/MaruTests/CurrentAppRuleTargetTrackerTests.swift
git commit -m "Track current app rule menu target"
```

## Task 4: Pid-Targeted WindowManager Manual Actions

**Files:**
- Modify: `Sources/Maru/Services/WindowManager.swift`
- Test: `Tests/MaruTests/WindowManagerTargetedActionTests.swift`

- [ ] **Step 1: Write failing test for captured pid resolution**

Create `Tests/MaruTests/WindowManagerTargetedActionTests.swift`:

```swift
import XCTest
@testable import Maru

final class WindowManagerTargetedActionTests: XCTestCase {
    func testTargetedManualActionResolvesCapturedProcessIdentifier() {
        var requestedPid: pid_t?
        let manager = WindowManager(runningApplicationResolver: { pid in
            requestedPid = pid
            return nil
        })
        let target = CurrentAppRuleTarget(
            appName: "Codex",
            bundleId: "com.openai.codex",
            processIdentifier: 12345
        )

        manager.performManualWindowAction(.center, target: target, triggerSource: "test")

        XCTAssertEqual(requestedPid, 12345)
    }
}
```

- [ ] **Step 2: Run test and verify it fails**

Run: `swift test --filter WindowManagerTargetedActionTests`

Expected: build failure because `WindowManager` does not accept `runningApplicationResolver` and has no target action API.

- [ ] **Step 3: Refactor manual action code behind the existing API**

In `WindowManager`, keep these existing public methods unchanged:

```swift
func performManualCenter(triggerSource: String)
func performManualAlmostMaximize(triggerSource: String)
func performManualMoveToNextDisplay(triggerSource: String)
```

Add a target API:

```swift
func performManualWindowAction(_ action: ManualWindowAction, target: CurrentAppRuleTarget, triggerSource: String)
```

Then refactor the existing private `performManualWindowAction(_ action:triggerSource:)` so both paths call a shared private implementation:

```swift
private func performManualWindowAction(_ action: ManualWindowAction, app: NSRunningApplication, triggerSource: String, showsMissingWindowAlert: Bool)
```

Add a resolver dependency to `WindowManager`:

```swift
private let runningApplicationResolver: (pid_t) -> NSRunningApplication?

init(runningApplicationResolver: @escaping (pid_t) -> NSRunningApplication? = { pid in
    NSRunningApplication(processIdentifier: pid)
}) {
    self.runningApplicationResolver = runningApplicationResolver
    // Don't request permissions during init - wait for app to launch
}
```

The new target API should resolve the app with:

```swift
guard let app = runningApplicationResolver(target.processIdentifier) else {
    AppLogger.shared.log("快速规则窗口操作失败: 目标应用已退出, 应用=\(target.appName) (\(target.bundleId), pid: \(target.processIdentifier))", level: .warning)
    return
}
```

For quick-menu target actions, pass `showsMissingWindowAlert: false` so no blocking alert appears if the target app has no manageable window. The existing frontmost-app manual action path must continue to use `NSWorkspace.shared.frontmostApplication`; only the new quick-menu path uses the captured pid resolver.

- [ ] **Step 4: Run focused tests**

Run: `swift test --filter WindowManagerTargetedActionTests`

Expected: all tests pass.

Run: `swift test --filter CurrentAppRuleMenuStateTests`

Expected: build succeeds and existing tests still pass.

- [ ] **Step 5: Run full tests**

Run: `swift test`

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/Maru/Services/WindowManager.swift Tests/MaruTests/WindowManagerTargetedActionTests.swift
git commit -m "Add targeted manual window actions"
```

## Task 5: Current App Menu Selection Handler

**Files:**
- Create: `Sources/Maru/Models/CurrentAppRuleMenuSelection.swift`
- Test: `Tests/MaruTests/CurrentAppRuleMenuSelectionTests.swift`

- [ ] **Step 1: Write failing tests for rule selection handling**

Create `Tests/MaruTests/CurrentAppRuleMenuSelectionTests.swift`:

```swift
import XCTest
@testable import Maru

final class CurrentAppRuleMenuSelectionTests: XCTestCase {
    private let target = CurrentAppRuleTarget(
        appName: "Codex",
        bundleId: "com.openai.codex",
        processIdentifier: 123
    )

    func testCenterSelectionSavesAndAppliesCenterActionToCapturedTarget() {
        var saved: (CurrentAppRuleTarget, WindowHandlingRule)?
        var performed: (CurrentAppRuleTarget, ManualWindowAction)?

        CurrentAppRuleMenuSelection.apply(
            rule: .center,
            to: target,
            saveRule: { saved = ($0, $1) },
            performManualAction: { performed = ($0, $1) }
        )

        XCTAssertEqual(saved?.0, target)
        XCTAssertEqual(saved?.1, .center)
        XCTAssertEqual(performed?.0, target)
        XCTAssertEqual(performed?.1, .center)
    }

    func testAlmostMaximizeSelectionSavesAndAppliesActionToCapturedTarget() {
        var performed: (CurrentAppRuleTarget, ManualWindowAction)?

        CurrentAppRuleMenuSelection.apply(
            rule: .almostMaximize,
            to: target,
            saveRule: { _, _ in },
            performManualAction: { performed = ($0, $1) }
        )

        XCTAssertEqual(performed?.0, target)
        XCTAssertEqual(performed?.1, .almostMaximize)
    }

    func testIgnoreSelectionSavesButDoesNotApplyManualAction() {
        var savedRule: WindowHandlingRule?
        var performedAction: ManualWindowAction?

        CurrentAppRuleMenuSelection.apply(
            rule: .ignore,
            to: target,
            saveRule: { _, rule in savedRule = rule },
            performManualAction: { _, action in performedAction = action }
        )

        XCTAssertEqual(savedRule, .ignore)
        XCTAssertNil(performedAction)
    }
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run: `swift test --filter CurrentAppRuleMenuSelectionTests`

Expected: build failure because selection model does not exist.

- [ ] **Step 3: Implement selection handler**

Create `Sources/Maru/Models/CurrentAppRuleMenuSelection.swift`:

```swift
import Foundation

enum CurrentAppRuleMenuSelection {
    static func apply(
        rule: WindowHandlingRule,
        to target: CurrentAppRuleTarget,
        saveRule: (CurrentAppRuleTarget, WindowHandlingRule) -> Void,
        performManualAction: (CurrentAppRuleTarget, ManualWindowAction) -> Void
    ) {
        saveRule(target, rule)

        if let manualAction = manualAction(for: rule) {
            performManualAction(target, manualAction)
        }
    }

    private static func manualAction(for rule: WindowHandlingRule) -> ManualWindowAction? {
        switch rule {
        case .center:
            return .center
        case .almostMaximize:
            return .almostMaximize
        case .ignore:
            return nil
        }
    }
}
```

- [ ] **Step 4: Run tests and verify they pass**

Run: `swift test --filter CurrentAppRuleMenuSelectionTests`

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Maru/Models/CurrentAppRuleMenuSelection.swift Tests/MaruTests/CurrentAppRuleMenuSelectionTests.swift
git commit -m "Model current app rule selection handling"
```

## Task 6: Status Bar Menu Layout Update

**Files:**
- Modify: `Sources/Maru/Models/StatusBarMenuLayout.swift`
- Test: `Tests/MaruTests/StatusBarMenuLayoutTests.swift`

- [ ] **Step 1: Update failing layout tests**

Modify `Tests/MaruTests/StatusBarMenuLayoutTests.swift` so the confirmed order includes a first group with `.currentAppRuleMenu`:

```swift
XCTAssertEqual(
    StatusBarMenuLayout.groups,
    [
        [.currentAppRuleMenu],
        [.windowManagementToggle, .manualAction(.center), .manualAction(.almostMaximize), .manualAction(.moveToNextDisplay)],
        [.appConfiguration, .appRules, .checkForUpdates],
        [.quit]
    ]
)
```

Add id/title assertions:

```swift
XCTAssertEqual(StatusBarMenuItem.currentAppRuleMenu.id, "currentAppRuleMenu")
XCTAssertEqual(StatusBarMenuItem.currentAppRuleMenu.title, "配置当前应用")
```

- [ ] **Step 2: Run tests and verify they fail**

Run: `swift test --filter StatusBarMenuLayoutTests`

Expected: build failure because `.currentAppRuleMenu` does not exist.

- [ ] **Step 3: Add layout item**

Modify `Sources/Maru/Models/StatusBarMenuLayout.swift`:

```swift
case currentAppRuleMenu
```

Add id and title cases:

```swift
case .currentAppRuleMenu:
    return "currentAppRuleMenu"
```

```swift
case .currentAppRuleMenu:
    return "配置当前应用"
```

Update `StatusBarMenuLayout.groups` with the new first group.

- [ ] **Step 4: Run tests and verify they pass**

Run: `swift test --filter StatusBarMenuLayoutTests`

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Maru/Models/StatusBarMenuLayout.swift Tests/MaruTests/StatusBarMenuLayoutTests.swift
git commit -m "Add current app rule menu layout item"
```

## Task 7: Wire Menu UI In MaruApp

**Files:**
- Modify: `Sources/Maru/MaruApp.swift`

- [ ] **Step 1: Add tracker state object**

In `MaruApp`, add:

```swift
@StateObject private var currentAppRuleTargetTracker = CurrentAppRuleTargetTracker(
    appBundleIdentifier: Bundle.main.bundleIdentifier ?? "com.nick.maru"
)
```

If Swift property initialization order rejects this because it references `Bundle`, move construction into `init()` with `_currentAppRuleTargetTracker = StateObject(wrappedValue: ...)`.

- [ ] **Step 2: Render current-app menu item**

In `statusBarMenuItem(for:)`, add:

```swift
case .currentAppRuleMenu:
    currentAppRuleMenu()
```

Add:

```swift
@ViewBuilder
private func currentAppRuleMenu() -> some View {
    let state = CurrentAppRuleMenuState(
        target: currentAppRuleTargetTracker.menuTargetApp,
        appRules: appConfig.appRules
    )

    if let target = state.target {
        Menu(state.title) {
            ForEach(state.ruleOptions) { rule in
                Button {
                    applyCurrentAppRule(rule, to: target)
                } label: {
                    if state.selectedRule == rule {
                        Label(rule.currentAppRuleMenuTitle, systemImage: "checkmark")
                    } else {
                        Text(rule.currentAppRuleMenuTitle)
                    }
                }
            }
        }
    } else {
        Button(state.title) {}
            .disabled(true)
    }
}
```

Use `Button` rows instead of `Picker`. This keeps the currently checked default `呼吸窗口` clickable for unsaved apps, so selecting it still creates a rule and applies the action. The checkmark is rendered with `Label(..., systemImage: "checkmark")` for the selected row. Keep labels Chinese and do not show bundle ids. Maru-as-target recording is owned by `CurrentAppRuleTargetTracker`, so do not add menu-target observer code to `configureWindow()`.

- [ ] **Step 3: Wire rule selection**

Add:

```swift
private func applyCurrentAppRule(_ rule: WindowHandlingRule, to target: CurrentAppRuleTarget) {
    CurrentAppRuleMenuSelection.apply(
        rule: rule,
        to: target,
        saveRule: { target, rule in
            appConfig.setRule(for: target.bundleId, appName: target.appName, rule: rule)
        },
        performManualAction: { target, manualAction in
            windowManager.performManualWindowAction(
                manualAction,
                target: target,
                triggerSource: "menuBarCurrentAppRule"
            )
        }
    )
}
```

- [ ] **Step 4: Run build/tests**

Run: `swift test --filter StatusBarMenuLayoutTests`

Expected: build succeeds and menu layout tests pass.

Run: `swift test`

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Maru/MaruApp.swift
git commit -m "Wire current app rule menu"
```

## Task 8: Manual Verification

**Files:**
- No code files unless manual testing reveals defects.

- [ ] **Step 1: Build the app**

Run: `swift build`

Expected: build succeeds.

- [ ] **Step 2: Run the app**

Run: `swift run`

Expected: Maru launches as a menu bar app.

- [ ] **Step 3: Verify Codex current-app menu**

Manual steps:

1. Make Codex the active app.
2. Click Maru menu bar icon.
3. Confirm the top menu item is `配置当前应用：Codex`.
4. Confirm no bundle id is visible.

- [ ] **Step 4: Verify rule selection behavior**

Manual steps:

1. Choose `居中窗口`; Codex rule is saved and Codex window moves to center.
2. Choose `呼吸窗口`; Codex rule is saved and Codex window resizes.
3. Choose `忽略此应用`; Codex rule is saved and the window does not move.
4. Open the main rules page and confirm the saved rule appears.
5. Remove the Codex rule, reopen the menu, then click the checked default `呼吸窗口`; confirm it still saves a new explicit rule and applies the action.

- [ ] **Step 5: Verify Maru-as-target behavior**

Manual steps:

1. Make Maru's main window the genuinely active app.
2. Open the Maru menu.
3. Confirm the menu can show `配置当前应用：Maru`.
4. Select a rule and confirm it is saved.

- [ ] **Step 6: Final test run**

Run: `swift test`

Expected: all tests pass.

- [ ] **Step 7: Final commit if manual fixes were needed**

If manual testing required fixes:

```bash
git add <changed-files>
git commit -m "Fix current app rule menu verification issues"
```

If no fixes were needed, do not create an empty commit.
