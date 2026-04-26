# Sparkle Update Check Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Sparkle 2 update checking to Maru with a status bar menu entry, a passive About-page probe, and the confirmed menu ordering.

**Architecture:** Keep Sparkle behind a small `UpdateService` so Maru does not own download, signature verification, or install UI. Put testable logic in pure model types, then let `UpdateService` bridge those models to `SPUStandardUpdaterController` and `SPUUpdaterDelegate`. Keep About page visual changes minimal: a tiny spinner near the existing version line only while probing.

**Tech Stack:** Swift 5.8, SwiftUI, Combine, AppKit, Swift Package Manager, Sparkle 2.9.1.

---

## Source Documents

- Spec: `docs/superpowers/specs/2026-04-26-sparkle-update-check-design.md`
- UI standard: `docs/PRODUCT-UI-DESIGN-STANDARD.md`
- Sparkle programmatic setup: `https://sparkle-project.org/documentation/programmatic-setup/`
- Sparkle `SPUUpdater`: `https://sparkle-project.org/documentation/api-reference/Classes/SPUUpdater.html`
- Sparkle `SPUStandardUpdaterController`: `https://sparkle-project.org/documentation/api-reference/Classes/SPUStandardUpdaterController.html`

## File Structure

- Create `Sources/Maru/Models/StatusBarMenuLayout.swift`
  - Pure model for the confirmed status bar menu order and labels.
- Create `Tests/MaruTests/StatusBarMenuLayoutTests.swift`
  - Verifies menu groups, order, labels, and that `查看日志` is absent.
- Create `Sources/Maru/Models/UpdateProbeState.swift`
  - Pure model for About-page update probe state and presentation.
- Create `Tests/MaruTests/UpdateProbeStateTests.swift`
  - Verifies one-shot About probing, spinner visibility, update-available copy, and failure handling.
- Create `Sources/Maru/Services/UpdateService.swift`
  - Sparkle bridge using `SPUStandardUpdaterController`, `SPUUpdaterDelegate`, and Combine KVO for `canCheckForUpdates`.
- Modify `Package.swift`
  - Add Sparkle dependency and link the `Sparkle` product into the `Maru` target.
- Modify `Sources/Maru/Info.plist`
  - Add `SUFeedURL`, `SUPublicEDKey`, and `SUEnableAutomaticChecks`.
- Modify `Sources/Maru/MaruApp.swift`
  - Inject `UpdateService`, add `检查更新…`, reorder the status bar menu, and rename `配置` to `应用配置`.
- Modify `Sources/Maru/Views/AboutView.swift`
  - Add small spinner/status presentation next to the existing version line and trigger one passive probe on appear.
- Optional create `docs/UPDATE-RELEASE-CHECKLIST.md`
  - Operational notes for generating Sparkle keys, appcast, release artifacts, and validating old-version updates.

## Implementation Notes

- Use Sparkle 2.9.1, currently the latest production release checked on 2026-04-26.
- `SPUStandardUpdaterController` and `SPUUpdater` are main-thread APIs. Keep `UpdateService` on `@MainActor`.
- Sparkle delegates are weak. `UpdateService` must stay alive for the full app lifetime via `@StateObject` and/or `static let shared`.
- Use `SPUStandardUpdaterController.checkForUpdates(_:)` for manual menu checks.
- Use `SPUUpdater.checkForUpdateInformation()` for About-page probing. Do not use `checkForUpdatesInBackground()` from About.
- `SUPublicEDKey` is public and belongs in `Info.plist`; the private EdDSA key must never be committed.

### Task 1: Status Bar Menu Layout Model

**Files:**
- Create: `Sources/Maru/Models/StatusBarMenuLayout.swift`
- Create: `Tests/MaruTests/StatusBarMenuLayoutTests.swift`
- Later modify: `Sources/Maru/MaruApp.swift`

- [ ] **Step 1: Write failing menu layout tests**

Create `Tests/MaruTests/StatusBarMenuLayoutTests.swift`:

```swift
import XCTest
@testable import Maru

final class StatusBarMenuLayoutTests: XCTestCase {
    func testStatusBarMenuGroupsUseConfirmedOrder() {
        XCTAssertEqual(
            StatusBarMenuLayout.groups,
            [
                [.windowManagementToggle],
                [.manualAction(.center), .manualAction(.almostMaximize), .manualAction(.moveToNextDisplay)],
                [.appConfiguration, .appRules, .checkForUpdates],
                [.quit]
            ]
        )
    }

    func testStatusBarMenuLabelsUseConfirmedCopy() {
        XCTAssertEqual(StatusBarMenuItem.windowManagementToggle.title, "窗口自动管理")
        XCTAssertEqual(StatusBarMenuItem.manualAction(.center).title, "居中窗口")
        XCTAssertEqual(StatusBarMenuItem.manualAction(.almostMaximize).title, "呼吸窗口")
        XCTAssertEqual(StatusBarMenuItem.manualAction(.moveToNextDisplay).title, "移到下一显示器")
        XCTAssertEqual(StatusBarMenuItem.appConfiguration.title, "应用配置")
        XCTAssertEqual(StatusBarMenuItem.appRules.title, "应用规则")
        XCTAssertEqual(StatusBarMenuItem.checkForUpdates.title, "检查更新…")
        XCTAssertEqual(StatusBarMenuItem.quit.title, "退出")
    }

    func testStatusBarMenuDoesNotIncludeLogViewer() {
        let allTitles = StatusBarMenuLayout.groups.flatMap { $0.map(\.title) }
        XCTAssertFalse(allTitles.contains("查看日志"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter StatusBarMenuLayoutTests
```

Expected: FAIL because `StatusBarMenuLayout` does not exist.

- [ ] **Step 3: Add menu layout model**

Create `Sources/Maru/Models/StatusBarMenuLayout.swift`:

```swift
import Foundation

extension ManualWindowAction: Equatable {}

enum StatusBarMenuItem: Equatable {
    case windowManagementToggle
    case manualAction(ManualWindowAction)
    case appConfiguration
    case appRules
    case checkForUpdates
    case quit

    var title: String {
        switch self {
        case .windowManagementToggle:
            return "窗口自动管理"
        case .manualAction(let action):
            return action.menuTitle
        case .appConfiguration:
            return "应用配置"
        case .appRules:
            return "应用规则"
        case .checkForUpdates:
            return "检查更新…"
        case .quit:
            return "退出"
        }
    }
}

enum StatusBarMenuLayout {
    static let groups: [[StatusBarMenuItem]] = [
        [.windowManagementToggle],
        [.manualAction(.center), .manualAction(.almostMaximize), .manualAction(.moveToNextDisplay)],
        [.appConfiguration, .appRules, .checkForUpdates],
        [.quit]
    ]
}

extension ManualWindowAction {
    var menuTitle: String {
        switch self {
        case .center:
            return "居中窗口"
        case .almostMaximize:
            return "呼吸窗口"
        case .moveToNextDisplay:
            return "移到下一显示器"
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
swift test --filter StatusBarMenuLayoutTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/Maru/Models/StatusBarMenuLayout.swift Tests/MaruTests/StatusBarMenuLayoutTests.swift
git commit -m "Add status bar menu layout model"
```

### Task 2: About Update Probe State Model

**Files:**
- Create: `Sources/Maru/Models/UpdateProbeState.swift`
- Create: `Tests/MaruTests/UpdateProbeStateTests.swift`
- Later modify: `Sources/Maru/Views/AboutView.swift`

- [ ] **Step 1: Write failing update probe state tests**

Create `Tests/MaruTests/UpdateProbeStateTests.swift`:

```swift
import XCTest
@testable import Maru

final class UpdateProbeStateTests: XCTestCase {
    func testAboutProbeStartsOnlyOncePerAppSession() {
        var coordinator = UpdateProbeCoordinator()

        XCTAssertTrue(coordinator.startAboutProbeIfNeeded(canStart: true))
        XCTAssertEqual(coordinator.state, .checking)

        XCTAssertFalse(coordinator.startAboutProbeIfNeeded(canStart: true))
        XCTAssertEqual(coordinator.state, .checking)
    }

    func testAboutProbeDoesNotStartDuringExistingSparkleSession() {
        var coordinator = UpdateProbeCoordinator()

        XCTAssertFalse(coordinator.startAboutProbeIfNeeded(canStart: false))
        XCTAssertEqual(coordinator.state, .idle)
    }

    func testProbeStateTransitionsForNoUpdateAndAvailableUpdate() {
        var noUpdate = UpdateProbeCoordinator()
        _ = noUpdate.startAboutProbeIfNeeded(canStart: true)
        noUpdate.markNoUpdateFound()
        XCTAssertEqual(noUpdate.state, .idle)

        var update = UpdateProbeCoordinator()
        _ = update.startAboutProbeIfNeeded(canStart: true)
        update.markUpdateFound()
        XCTAssertEqual(update.state, .updateAvailable)
    }

    func testProbeFailureStopsSpinnerWithoutSurfacingErrorText() {
        var coordinator = UpdateProbeCoordinator()
        _ = coordinator.startAboutProbeIfNeeded(canStart: true)
        coordinator.markFailed()

        let presentation = AboutUpdateStatusState(probeState: coordinator.state)
        XCTAssertEqual(coordinator.state, .failed)
        XCTAssertFalse(presentation.showsSpinner)
        XCTAssertNil(presentation.message)
    }

    func testAboutPresentationKeepsUpdateAvailableCopyLowPriority() {
        XCTAssertTrue(AboutUpdateStatusState(probeState: .checking).showsSpinner)
        XCTAssertNil(AboutUpdateStatusState(probeState: .checking).message)

        let update = AboutUpdateStatusState(probeState: .updateAvailable)
        XCTAssertFalse(update.showsSpinner)
        XCTAssertEqual(update.message, "发现新版本")

        XCTAssertFalse(AboutUpdateStatusState(probeState: .idle).showsSpinner)
        XCTAssertNil(AboutUpdateStatusState(probeState: .idle).message)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter UpdateProbeStateTests
```

Expected: FAIL because the update probe model does not exist.

- [ ] **Step 3: Add update probe state model**

Create `Sources/Maru/Models/UpdateProbeState.swift`:

```swift
import Foundation

enum UpdateProbeState: Equatable {
    case idle
    case checking
    case updateAvailable
    case failed
}

struct AboutUpdateStatusState: Equatable {
    let showsSpinner: Bool
    let message: String?

    init(probeState: UpdateProbeState) {
        switch probeState {
        case .checking:
            showsSpinner = true
            message = nil
        case .updateAvailable:
            showsSpinner = false
            message = "发现新版本"
        case .idle, .failed:
            showsSpinner = false
            message = nil
        }
    }
}

struct UpdateProbeCoordinator {
    private(set) var state: UpdateProbeState = .idle
    private var hasRequestedAboutProbe = false

    mutating func startAboutProbeIfNeeded(canStart: Bool) -> Bool {
        guard canStart, !hasRequestedAboutProbe else {
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
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
swift test --filter UpdateProbeStateTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/Maru/Models/UpdateProbeState.swift Tests/MaruTests/UpdateProbeStateTests.swift
git commit -m "Add update probe state model"
```

### Task 3: Sparkle Dependency and Bundle Configuration

**Files:**
- Modify: `Package.swift`
- Modify: `Sources/Maru/Info.plist`
- Generated: `Package.resolved`

- [ ] **Step 1: Add Sparkle dependency to `Package.swift`**

Modify `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.1")
],
targets: [
    .executableTarget(
        name: "Maru",
        dependencies: [
            .product(name: "Sparkle", package: "Sparkle")
        ],
        path: "Sources/Maru",
        ...
    )
]
```

- [ ] **Step 2: Resolve packages**

Run:

```bash
swift package resolve
```

Expected: Sparkle resolves successfully and `Package.resolved` records Sparkle.

- [ ] **Step 3: Generate or retrieve Sparkle EdDSA public key**

Use Sparkle's `generate_keys` tool from the Sparkle distribution. Preserve the private key outside the repository. Do not commit private key material.

Expected output includes a base64 public key. Use that value for `SUPublicEDKey`.

If this cannot be completed during implementation, stop and ask the user to provide the Sparkle public EdDSA key. Do not commit a placeholder `SUPublicEDKey` into a build intended for manual app testing because Sparkle will report a configuration failure.

- [ ] **Step 4: Add Sparkle keys to `Info.plist`**

Modify `Sources/Maru/Info.plist` inside `<dict>`:

```xml
    <key>SUFeedURL</key>
    <string>https://iobee.github.io/Maru/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>PASTE_GENERATED_PUBLIC_ED_KEY_HERE</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
```

Replace `PASTE_GENERATED_PUBLIC_ED_KEY_HERE` with the actual generated public key before committing.

- [ ] **Step 5: Verify package and plist changes compile**

Run:

```bash
swift build
```

Expected: Build succeeds with Sparkle linked.

- [ ] **Step 6: Commit**

```bash
git add Package.swift Package.resolved Sources/Maru/Info.plist
git commit -m "Add Sparkle dependency and update feed configuration"
```

### Task 4: Update Service Sparkle Bridge

**Files:**
- Create: `Sources/Maru/Services/UpdateService.swift`

- [ ] **Step 1: Add `UpdateService` implementation**

Create `Sources/Maru/Services/UpdateService.swift`:

```swift
import Combine
import Foundation
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

    private var coordinator = UpdateProbeCoordinator()
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        observeUpdaterState()
    }

    func checkForUpdates() {
        guard canCheckForUpdates else {
            AppLogger.shared.log("更新检查已忽略：Sparkle 当前不可检查更新", level: .info)
            return
        }

        updaterController.checkForUpdates(nil)
    }

    func checkForUpdatesFromAboutIfNeeded() {
        let updater = updaterController.updater
        let shouldStart = coordinator.startAboutProbeIfNeeded(canStart: !updater.sessionInProgress)
        syncProbeState()

        guard shouldStart else {
            return
        }

        AppLogger.shared.log("About 页面触发轻量更新探测", level: .info)
        updater.checkForUpdateInformation()
    }

    private func observeUpdaterState() {
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] canCheck in
                self?.canCheckForUpdates = canCheck
            }
            .store(in: &cancellables)
    }

    private func syncProbeState() {
        probeState = coordinator.state
    }

    private func logUpdateError(_ error: Error, context: String) {
        AppLogger.shared.log("\(context): \(error.localizedDescription)", level: .warning)
    }
}

extension UpdateService: SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        coordinator.markUpdateFound()
        syncProbeState()
        AppLogger.shared.log("发现可用更新", level: .info)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: any Error) {
        coordinator.markNoUpdateFound()
        syncProbeState()
        AppLogger.shared.log("未发现可用更新", level: .info)
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        coordinator.markFailed()
        syncProbeState()
        logUpdateError(error, context: "更新检查失败")
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        if let error {
            coordinator.markFailed()
            syncProbeState()
            logUpdateError(error, context: "更新检查结束并返回错误")
            return
        }

        if probeState == .checking {
            coordinator.markNoUpdateFound()
            syncProbeState()
        }
    }
}
```

- [ ] **Step 2: Build to catch Sparkle API signature issues**

Run:

```bash
swift build
```

Expected: Build succeeds. If Swift protocol signatures differ, adjust only to match Sparkle 2.9.1 docs.

- [ ] **Step 3: Run update-related tests**

Run:

```bash
swift test --filter UpdateProbeStateTests
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add Sources/Maru/Services/UpdateService.swift
git commit -m "Add Sparkle update service"
```

### Task 5: Wire Update Service Into App and Menus

**Files:**
- Modify: `Sources/Maru/MaruApp.swift`

- [ ] **Step 1: Add app-level service state**

In `MaruApp`, add:

```swift
@StateObject private var updateService = UpdateService.shared
```

Add `.environmentObject(updateService)` to the main `ContentView` chain.

- [ ] **Step 2: Add standard macOS app menu update entry**

In `.commands`, extend the `.appInfo` replacement group:

```swift
CommandGroup(replacing: .appInfo) {
    Button("关于 Maru") {
        showAboutPanel()
    }

    Divider()

    Button(StatusBarMenuItem.checkForUpdates.title) {
        updateService.checkForUpdates()
    }
    .disabled(!updateService.canCheckForUpdates)
}
```

- [ ] **Step 3: Rename configuration menu copy**

Replace user-facing `配置` menu copy that opens the main app configuration window with `应用配置`.

Keep existing shortcuts unless tests or build errors show conflicts:

```swift
Button(StatusBarMenuItem.appConfiguration.title) {
    openConfigurationWindow()
}
.keyboardShortcut("m", modifiers: [.command, .option])
```

- [ ] **Step 4: Reorder `MenuBarExtra`**

Update the status bar menu to this order:

```swift
Toggle(StatusBarMenuItem.windowManagementToggle.title, isOn: windowManagementBinding)

Divider()

manualWindowActionButton(for: .center)
manualWindowActionButton(for: .almostMaximize)
manualWindowActionButton(for: .moveToNextDisplay)

Divider()

Button(StatusBarMenuItem.appConfiguration.title) {
    openConfigurationWindow()
}.keyboardShortcut("m")

Button(StatusBarMenuItem.appRules.title) {
    openConfigurationWindow(show: Self.showRulesConfigNotification)
}.keyboardShortcut("r")

Button(StatusBarMenuItem.checkForUpdates.title) {
    updateService.checkForUpdates()
}
.disabled(!updateService.canCheckForUpdates)

Divider()

Button(StatusBarMenuItem.quit.title) {
    NSApp.terminate(nil)
}.keyboardShortcut("q")
```

Do not add `查看日志` to `MenuBarExtra`.

- [ ] **Step 5: Use `ManualWindowAction.menuTitle`**

Replace `manualWindowMenuTitle(for:)` switch with:

```swift
private static func manualWindowMenuTitle(for action: ManualWindowAction) -> String {
    action.menuTitle
}
```

- [ ] **Step 6: Run menu layout tests**

Run:

```bash
swift test --filter StatusBarMenuLayoutTests
```

Expected: PASS.

- [ ] **Step 7: Build**

Run:

```bash
swift build
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add Sources/Maru/MaruApp.swift
git commit -m "Wire update checks into app menus"
```

### Task 6: About Page Passive Probe UI

**Files:**
- Modify: `Sources/Maru/Views/AboutView.swift`
- Existing tests: `Tests/MaruTests/AboutViewStateTests.swift`
- New tests already added: `Tests/MaruTests/UpdateProbeStateTests.swift`

- [ ] **Step 1: Add environment object**

In `AboutView`:

```swift
@EnvironmentObject private var updateService: UpdateService
```

- [ ] **Step 2: Trigger one passive probe on appear**

Add to the root view chain:

```swift
.onAppear {
    updateService.checkForUpdatesFromAboutIfNeeded()
}
```

- [ ] **Step 3: Add minimal status presentation near version line**

In the existing bottom `HStack`, replace the version `Text` with a compact group:

```swift
HStack(spacing: 8) {
    Text(state.releaseLineText)
        .font(.system(size: 13, weight: .regular))
        .foregroundStyle(.tertiary)

    let updateStatus = AboutUpdateStatusState(probeState: updateService.probeState)

    if updateStatus.showsSpinner {
        ProgressView()
            .controlSize(.small)
            .scaleEffect(0.55)
            .frame(width: 12, height: 12)
    }

    if let message = updateStatus.message {
        Text(message)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(.tertiary)
    }
}
```

Keep `GitHubCapsuleLink` in its current place. Do not add any button or toggle to About.

- [ ] **Step 4: Verify About view state tests still pass**

Run:

```bash
swift test --filter AboutViewStateTests
swift test --filter UpdateProbeStateTests
```

Expected: PASS.

- [ ] **Step 5: Build**

Run:

```bash
swift build
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/Maru/Views/AboutView.swift
git commit -m "Show passive update probe state on About page"
```

### Task 7: Release Checklist Documentation

**Files:**
- Create: `docs/UPDATE-RELEASE-CHECKLIST.md`

- [ ] **Step 1: Create release checklist**

Create `docs/UPDATE-RELEASE-CHECKLIST.md`:

```markdown
# Maru Update Release Checklist

## Sparkle Keys

- `SUPublicEDKey` is committed in `Sources/Maru/Info.plist`.
- The private EdDSA key is stored outside the repository.
- Never commit private key material.

## Release Steps

1. Update `CFBundleShortVersionString`.
2. Increment `CFBundleVersion`.
3. Build release app bundle.
4. Sign the app.
5. Notarize and staple.
6. Package as `.dmg` or `.zip`.
7. Generate Sparkle appcast and EdDSA signatures.
8. Upload package to GitHub Releases.
9. Publish `appcast.xml` to GitHub Pages at `https://iobee.github.io/Maru/appcast.xml`.
10. Verify an older Maru build detects the new version.

## Validation

- `检查更新…` opens Sparkle's manual update check UI.
- About page probe does not open an update install window.
- Missing or invalid appcast logs an error but does not crash Maru.
```

- [ ] **Step 2: Commit**

```bash
git add docs/UPDATE-RELEASE-CHECKLIST.md
git commit -m "Document Sparkle release checklist"
```

### Task 8: Full Verification

**Files:**
- All modified files from previous tasks.

- [ ] **Step 1: Run full test suite**

Run:

```bash
swift test
```

Expected: PASS.

- [ ] **Step 2: Run debug build**

Run:

```bash
swift build
```

Expected: PASS.

- [ ] **Step 3: Search for rejected menu copy**

Run:

```bash
rg -n "查看日志|Button\\(\"配置\"|https://github.com/iobee/hiWindowGuy|hiWindowGuy\\.git" Sources Tests docs Package.swift
```

Expected:

- No `hiWindowGuy` matches.
- No `查看日志` match inside `MenuBarExtra`.
- No user-facing status bar `Button("配置"` remains.

If `查看日志` still appears in app menu commands or docs, verify it is unrelated to `MenuBarExtra` before changing it.

- [ ] **Step 4: Manual app smoke test**

Run:

```bash
swift run Maru
```

Expected:

- Status bar menu order is:

```text
窗口自动管理

居中窗口
呼吸窗口
移到下一显示器

应用配置
应用规则
检查更新…

退出
```

- `检查更新…` opens Sparkle's standard manual update UI or a Sparkle error if the appcast is not yet published.
- About page keeps the same card design and shows only a small spinner during passive probing.
- About page does not add a check-update button or automatic-update toggle.

- [ ] **Step 5: Final status**

Run:

```bash
git status --short
```

Expected: clean working tree after all commits.
