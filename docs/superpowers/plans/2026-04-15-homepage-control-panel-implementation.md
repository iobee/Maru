# Homepage Control Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the Maru homepage into the approved hero-first control panel, with light glass styling, a shared window-management toggle state, and a low-emphasis summary strip.

**Architecture:** Keep `ContentView` focused on the app shell, tab switching, and sidebar chrome. Extract homepage rendering into a dedicated `HomeDashboardView` that consumes a small, testable `HomeDashboardState` helper for copy and summary counts, while `MaruApp` remains the single source of truth for the enable/disable binding used by the homepage and menu commands.

**Tech Stack:** SwiftUI, Swift Package Manager, XCTest, AppKit

---

## File Map

- Create: `Sources/Maru/Models/HomeDashboardState.swift`
  - Pure helper that derives homepage status copy, formatted scale text, and summary metrics from `AppConfig` data plus the shared enable state.
- Create: `Sources/Maru/Views/HomeDashboardView.swift`
  - Dedicated homepage view that renders the approved `Hero Control` layout.
- Create: `Tests/MaruTests/HomeDashboardStateTests.swift`
  - Unit coverage for summary counts and enabled/disabled copy.
- Modify: `Package.swift:4-27`
  - Add the new test target.
- Modify: `Sources/Maru/Views/ContentView.swift:6-384`
  - Remove inline homepage rendering, pass through the shared enable binding, tighten sidebar styling, and host `HomeDashboardView`.
- Modify: `Sources/Maru/MaruApp.swift:17-120`
  - Pass the app-level enable binding into `ContentView` so homepage, menu commands, and menu bar extra all stay in sync.

### Task 1: Add a testable homepage state helper

**Files:**
- Create: `Sources/Maru/Models/HomeDashboardState.swift`
- Create: `Tests/MaruTests/HomeDashboardStateTests.swift`
- Modify: `Package.swift:4-27`

- [ ] **Step 1: Write the failing tests and test target**

```swift
// Tests/MaruTests/HomeDashboardStateTests.swift
import XCTest
@testable import Maru

final class HomeDashboardStateTests: XCTestCase {
    func testSummaryCountsFollowRuleBuckets() {
        let rules = [
            AppRule(bundleId: "a", appName: "A", rule: .center, lastUsed: .now, useCount: 1),
            AppRule(bundleId: "b", appName: "B", rule: .almostMaximize, lastUsed: .now, useCount: 1),
            AppRule(bundleId: "c", appName: "C", rule: .ignore, lastUsed: .now, useCount: 1)
        ]

        let state = HomeDashboardState(appRules: rules, isEnabled: true, scaleFactor: 0.93)

        XCTAssertEqual(state.summaryItems.map(\.count), [3, 1, 1, 1])
    }

    func testStatusCopyChangesWithEnableState() {
        XCTAssertEqual(
            HomeDashboardState(appRules: [], isEnabled: true, scaleFactor: 0.92).statusTitle,
            "已启用"
        )
        XCTAssertEqual(
            HomeDashboardState(appRules: [], isEnabled: false, scaleFactor: 0.92).statusTitle,
            "已停用"
        )
    }
}
```

```swift
// Package.swift
.testTarget(
    name: "MaruTests",
    dependencies: ["Maru"]
)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter HomeDashboardStateTests`
Expected: FAIL with an error like `cannot find 'HomeDashboardState' in scope`

- [ ] **Step 3: Write the minimal implementation**

```swift
// Sources/Maru/Models/HomeDashboardState.swift
import Foundation

struct HomeDashboardState {
    struct SummaryItem: Equatable {
        let title: String
        let count: Int
    }

    let appRules: [AppRule]
    let isEnabled: Bool
    let scaleFactor: Double

    var statusTitle: String { isEnabled ? "已启用" : "已停用" }
    var scaleText: String { "\(Int(scaleFactor * 100))%" }
    var summaryItems: [SummaryItem] {
        [
            SummaryItem(title: "已记录", count: appRules.count),
            SummaryItem(title: "居中", count: appRules.filter { $0.rule == .center }.count),
            SummaryItem(title: "几乎最大化", count: appRules.filter { $0.rule == .almostMaximize }.count),
            SummaryItem(title: "忽略", count: appRules.filter { $0.rule == .ignore }.count)
        ]
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter HomeDashboardStateTests`
Expected: PASS with `Executed 2 tests`

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/Maru/Models/HomeDashboardState.swift Tests/MaruTests/HomeDashboardStateTests.swift
git commit -m "test: add homepage dashboard state coverage"
```

### Task 2: Extract homepage rendering and share the enable binding

**Files:**
- Create: `Sources/Maru/Views/HomeDashboardView.swift`
- Modify: `Sources/Maru/Views/ContentView.swift:6-213`
- Modify: `Sources/Maru/MaruApp.swift:17-120`

- [ ] **Step 1: Wire the shell to a new homepage view before implementing it**

```swift
// Sources/Maru/MaruApp.swift
@State private var isWindowManagementEnabled = true

ContentView(
    selectedTab: $selectedTab,
    isWindowManagementEnabled: $isWindowManagementEnabled
)

// Sources/Maru/Views/ContentView.swift
struct ContentView: View {
    @Binding var selectedTab: NavigationTab
    @Binding var isWindowManagementEnabled: Bool

    private var mainContentView: some View {
        switch selectedTab {
        case .home:
            HomeDashboardView(isWindowManagementEnabled: $isWindowManagementEnabled)
        case .rules:
            RuleConfigView()
        case .logs:
            LogViewer()
        }
    }
}
```

Implementation notes:
- Keep `@State private var isWindowManagementEnabled = true` in `MaruApp` as the single source of truth for enable state.
- Migrate the existing `.commands` toggle and `MenuBarExtra` toggle to that same binding instead of introducing a second homepage-specific state.
- `ContentView` and the sidebar footer must consume only the passed binding, never define their own running-state storage.

- [ ] **Step 2: Run build to verify it fails**

Run: `swift build`
Expected: FAIL with an error like `cannot find 'HomeDashboardView' in scope`

- [ ] **Step 3: Add the minimal homepage view shell**

```swift
// Sources/Maru/Views/HomeDashboardView.swift
import SwiftUI

struct HomeDashboardView: View {
    @Binding var isWindowManagementEnabled: Bool
    @EnvironmentObject private var appConfig: AppConfig

    var body: some View {
        Text("Home dashboard placeholder")
    }
}

// Sources/Maru/MaruApp.swift
private func applyWindowManagementState(_ isEnabled: Bool, source: String) {
    if isEnabled {
        logger.log("\(source)启用窗口管理", level: .info)
        windowManager.startMonitoring()
    } else {
        logger.log("\(source)停用窗口管理", level: .info)
        windowManager.stopMonitoring()
    }
}
```

Implementation notes:
- `isWindowManagementEnabled` changes should own monitoring side effects in exactly one place: a single app-level `.onChange(of: isWindowManagementEnabled)` observer plus initial startup sync in `onAppear`.
- `.commands`, `MenuBarExtra`, and `HomeDashboardView` should only mutate the binding; they must not call `startMonitoring()`, `stopMonitoring()`, or log toggle transitions directly.
- `applyWindowManagementState` exists only to centralize the startup/onChange side effect path in `MaruApp`.

- [ ] **Step 4: Run build to verify it passes**

Run: `swift build`
Expected: PASS with `Build complete!`

- [ ] **Step 5: Commit**

```bash
git add Sources/Maru/Views/HomeDashboardView.swift Sources/Maru/Views/ContentView.swift Sources/Maru/MaruApp.swift
git commit -m "refactor: extract homepage dashboard shell"
```

### Task 3: Implement the hero control card and scale control card

**Files:**
- Modify: `Sources/Maru/Views/HomeDashboardView.swift`
- Modify: `Sources/Maru/Models/HomeDashboardState.swift`

- [ ] **Step 1: Replace the placeholder with the target structure before helpers exist**

```swift
var body: some View {
    ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            headerSection
            heroControlCard
            scaleControlCard
        }
        .padding(28)
    }
}
```

- [ ] **Step 2: Run build to verify it fails**

Run: `swift build`
Expected: FAIL with an error like `cannot find 'heroControlCard' in scope`

- [ ] **Step 3: Implement the approved layout**

```swift
private var state: HomeDashboardState {
    HomeDashboardState(
        appRules: appConfig.appRules,
        isEnabled: isWindowManagementEnabled,
        scaleFactor: appConfig.windowScaleFactor
    )
}

private var heroControlCard: some View {
    HStack(alignment: .center, spacing: 20) {
        VStack(alignment: .leading, spacing: 8) {
            Text(state.statusTitle).font(.title2.weight(.semibold))
            Text("自动调整窗口大小和位置").foregroundStyle(.secondary)
        }
        Spacer()
        Toggle("", isOn: $isWindowManagementEnabled)
            .labelsHidden()
            .toggleStyle(.switch)
    }
    .padding(24)
    .background(heroMaterialBackground)
}

private var scaleControlCard: some View {
    VStack(alignment: .leading, spacing: 18) {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("窗口缩放比例").font(.headline.weight(.semibold))
                Text("控制「几乎最大化」时窗口的大小").foregroundStyle(.secondary)
            }
            Spacer()
            Text(state.scaleText)
                .font(.system(.headline, design: .rounded))
                .monospacedDigit()
        }

        Slider(value: $appConfig.windowScaleFactor, in: 0.7...0.97, step: 0.01)

        HStack {
            Text("更紧凑")
            Spacer()
            Text("更宽敞")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(24)
    .background(scaleCardBackground)
}
```

Implementation notes:
- Header should drop the current blue icon tile and keep only title + subtitle.
- Hero card gets the light glass surface, thin stroke, and restrained highlight.
- Scale card uses a more solid surface than the hero card.
- The scale card must bind `Slider` directly to `$appConfig.windowScaleFactor` so existing persistence in `AppConfig.didSet` continues to work.
- Reuse `state.scaleText` for the percentage display so formatting stays in one place.

- [ ] **Step 4: Run build to verify it passes**

Run: `swift build`
Expected: PASS with `Build complete!`

- [ ] **Step 5: Commit**

```bash
git add Sources/Maru/Models/HomeDashboardState.swift Sources/Maru/Views/HomeDashboardView.swift
git commit -m "feat: redesign homepage hero controls"
```

### Task 4: Replace the stat grid with a summary strip and calm down the sidebar

**Files:**
- Modify: `Sources/Maru/Views/HomeDashboardView.swift`
- Modify: `Sources/Maru/Views/ContentView.swift:66-155`

- [ ] **Step 1: Swap the legacy stats section for a summary strip skeleton**

```swift
var body: some View {
    ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            headerSection
            heroControlCard
            scaleControlCard
            summaryStrip
        }
        .padding(28)
    }
}
```

```swift
sidebarView
    .frame(width: 196)
```

- [ ] **Step 2: Run build to verify it fails**

Run: `swift build`
Expected: FAIL with an error like `cannot find 'summaryStrip' in scope`

- [ ] **Step 3: Implement the summary strip and sidebar restraint**

```swift
private var summaryStrip: some View {
    HStack(spacing: 12) {
        ForEach(state.summaryItems, id: \.title) { item in
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).foregroundStyle(.secondary)
                Text("\(item.count)").font(.headline.monospacedDigit())
            }
            if item.title != state.summaryItems.last?.title { Divider() }
        }
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 14)
    .background(summaryBackground)
}
```

Implementation notes:
- Keep the summary strip low-contrast and compact; no colorful icon cards.
- Sidebar selected state should move from a large bright blue slab to a subtler capsule or tinted row background.
- The sidebar footer status dot and label must read from the shared `isWindowManagementEnabled` binding instead of local `@State`.
- In `ContentView`, explicitly remove the local `@State private var isRunning = true`, narrow the sidebar width, update `navigationLink(for:)` colors/background, and wire the footer to the shared binding before marking the task done.

- [ ] **Step 4: Run build to verify it passes**

Run: `swift build`
Expected: PASS with `Build complete!`

- [ ] **Step 5: Commit**

```bash
git add Sources/Maru/Views/HomeDashboardView.swift Sources/Maru/Views/ContentView.swift
git commit -m "feat: add homepage summary strip and sidebar polish"
```

### Task 5: Verify behavior and visual acceptance criteria

**Files:**
- Verify: `Sources/Maru/Models/HomeDashboardState.swift`
- Verify: `Sources/Maru/Views/HomeDashboardView.swift`
- Verify: `Sources/Maru/Views/ContentView.swift`
- Verify: `Sources/Maru/MaruApp.swift`

- [ ] **Step 1: Run the unit tests**

Run: `swift test --filter HomeDashboardStateTests`
Expected: PASS

- [ ] **Step 2: Run the app build**

Run: `swift build`
Expected: PASS with `Build complete!`

- [ ] **Step 3: Launch the app for manual verification**

Run: `swift run Maru`
Expected: App launches and the homepage opens with the redesigned control panel

- [ ] **Step 4: Manually verify the acceptance checklist**

Checklist:
- Homepage reads as a control panel within 2 seconds.
- The hero card is the first visual anchor; the scale card is clearly second.
- Toggling the homepage switch updates the sidebar footer status and stays in sync with menu/menu-bar toggles.
- Slider percentage updates live and still persists through `AppConfig.windowScaleFactor`.
- Summary strip is visibly lower emphasis than the two main controls.
- Rules and Logs tabs still render without layout regressions.

- [ ] **Step 5: Commit the verified result**

```bash
git add Package.swift Sources/Maru/Models/HomeDashboardState.swift Sources/Maru/Views/HomeDashboardView.swift Sources/Maru/Views/ContentView.swift Sources/Maru/MaruApp.swift Tests/MaruTests/HomeDashboardStateTests.swift
git commit -m "feat: redesign homepage as a control panel"
```
