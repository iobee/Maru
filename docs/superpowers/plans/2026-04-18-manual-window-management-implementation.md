# Manual Window Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add manual window centering and almost-maximize actions to HiWindowGuy with configurable global shortcuts, matching menu entries, and a homepage settings card that stays aligned with the current product UI standard.

**Architecture:** Keep automatic window management intact, but add a separate manual trigger path. Reuse the existing low-level `centerWindow` and `almostMaximizeWindow` frame logic, while splitting out a manual target resolver that only operates on the frontmost app’s active standard window. Persist shortcut bindings in `AppConfig`, register them through a dedicated global hotkey manager, route both menus and hotkeys through the same manual action entrypoints, and surface shortcut editing inside the existing homepage card language.

**Tech Stack:** SwiftUI, AppKit, Accessibility API, Carbon hotkey APIs, Swift Package Manager, XCTest

---

## File Map

- Modify: `Sources/HiWindowGuy/Models/AppConfig.swift`
  - Add shortcut binding models, default values, persistence, clear/reset actions, and duplicate-binding validation.
- Create: `Sources/HiWindowGuy/Models/ManualWindowAction.swift`
  - Define the two fixed manual actions plus menu/display metadata.
- Create: `Sources/HiWindowGuy/Models/ShortcutBinding.swift`
  - Represent key + modifier data, default display formatting, equality/hashability, and serialization.
- Create: `Sources/HiWindowGuy/Services/GlobalHotkeyManager.swift`
  - Register/unregister Carbon global shortcuts and dispatch bound actions.
- Modify: `Sources/HiWindowGuy/Services/WindowManager.swift`
  - Add manual action entrypoints, manual target window resolution, alert feedback, and manual-action logging.
- Modify: `Sources/HiWindowGuy/hiWindowGuyApp.swift`
  - Wire menu bar entries, top app menu entries, and startup lifecycle registration for global hotkeys.
- Modify: `Sources/HiWindowGuy/Views/HomeDashboardView.swift`
  - Add the “手动窗口管理” settings card in the approved homepage card style.
- Modify: `Sources/HiWindowGuy/Models/HomeDashboardState.swift`
  - Add homepage copy and display helpers for the new shortcut card if needed.
- Create: `Tests/HiWindowGuyTests/ShortcutBindingTests.swift`
  - Cover binding formatting, equality, and duplicate detection helpers.
- Create: `Tests/HiWindowGuyTests/AppConfigShortcutTests.swift`
  - Cover default shortcut loading, clear/reset behavior, persistence-safe validation, and duplicate rejection.

## Verification Strategy

- Use unit tests for the pure shortcut/configuration layer.
- Use compile verification after each integration slice because the hotkey manager, menus, and SwiftUI card changes span multiple files.
- Finish with a fresh full test run and a fresh build.
- Manual verification in the running app is still required for:
  - global shortcuts while HiWindowGuy is backgrounded
  - manual actions targeting the frontmost app’s active standard window instead of the mouse-hover window
  - alert feedback when no standard window is available
  - homepage card visual consistency with the current UI standard

### Task 1: Build the shortcut binding model and persistence rules

**Files:**
- Create: `Sources/HiWindowGuy/Models/ManualWindowAction.swift`
- Create: `Sources/HiWindowGuy/Models/ShortcutBinding.swift`
- Modify: `Sources/HiWindowGuy/Models/AppConfig.swift`
- Test: `Tests/HiWindowGuyTests/ShortcutBindingTests.swift`
- Test: `Tests/HiWindowGuyTests/AppConfigShortcutTests.swift`

- [ ] **Step 1: Write failing tests for shortcut bindings and config defaults**

Add tests that describe the required behavior before any production code changes:

- `ShortcutBinding` can represent `Control + Command + C`
- default bindings map `center -> Ctrl+Cmd+C` and `almostMaximize -> Ctrl+Cmd+M`
- clearing one binding leaves the other intact
- resetting restores the default binding
- duplicate bindings are rejected by config validation

- [ ] **Step 2: Run tests to verify they fail for the missing shortcut/config APIs**

Run: `swift test --filter 'ShortcutBindingTests|AppConfigShortcutTests'`
Expected: FAIL with missing type/member errors such as `ShortcutBinding` or manual shortcut config accessors not existing yet

- [ ] **Step 3: Implement the minimal model and config layer**

Requirements:

- `ManualWindowAction` contains the two fixed actions and their user-facing labels
- `ShortcutBinding` stores a key plus modifier flags in a codable form
- binding display text is stable and human-readable in Chinese UI
- `AppConfig` owns `manualCenterShortcut` and `manualAlmostMaximizeShortcut`
- shortcut values persist in `general.json`
- `AppConfig` exposes clear/reset/update helpers
- duplicate detection happens before save and leaves persisted state unchanged when invalid

- [ ] **Step 4: Run the targeted tests to verify they pass**

Run: `swift test --filter 'ShortcutBindingTests|AppConfigShortcutTests'`
Expected: PASS with both new test suites green

- [ ] **Step 5: Commit**

```bash
git add Sources/HiWindowGuy/Models/ManualWindowAction.swift Sources/HiWindowGuy/Models/ShortcutBinding.swift Sources/HiWindowGuy/Models/AppConfig.swift Tests/HiWindowGuyTests/ShortcutBindingTests.swift Tests/HiWindowGuyTests/AppConfigShortcutTests.swift
git commit -m "feat: add manual shortcut configuration"
```

### Task 2: Add the global hotkey manager and wire it into app lifecycle and menus

**Files:**
- Create: `Sources/HiWindowGuy/Services/GlobalHotkeyManager.swift`
- Modify: `Sources/HiWindowGuy/hiWindowGuyApp.swift`
- Modify: `Sources/HiWindowGuy/Models/AppConfig.swift`

- [ ] **Step 1: Introduce compile references to a dedicated global hotkey manager**

Plumb the app entrypoint so startup and config changes refer to a `GlobalHotkeyManager` that does not exist yet. Also add the new manual menu commands in `hiWindowGuyApp.swift` so the build breaks on the new unresolved symbols first.

- [ ] **Step 2: Run build to verify it fails on the missing hotkey manager and manual action symbols**

Run: `swift build`
Expected: FAIL with unresolved references to `GlobalHotkeyManager` or the new manual action handlers

- [ ] **Step 3: Implement the global hotkey manager and register both actions**

Requirements:

- Use Carbon `RegisterEventHotKey` / `UnregisterEventHotKey` for global shortcuts
- register current config bindings at launch
- re-register when shortcut config changes
- skip registration for cleared bindings
- route hotkey events into the same action dispatchers used by menu entries
- menus added in both:
  - menu bar extra
  - top-level `窗口管理` application menu
- menu labels match the spec exactly: `窗口居中`, `几乎最大化`

- [ ] **Step 4: Run build to verify the app compiles with the new hotkey wiring**

Run: `swift build`
Expected: PASS with `Build complete!`

- [ ] **Step 5: Commit**

```bash
git add Sources/HiWindowGuy/Services/GlobalHotkeyManager.swift Sources/HiWindowGuy/hiWindowGuyApp.swift Sources/HiWindowGuy/Models/AppConfig.swift
git commit -m "feat: wire manual window actions into hotkeys and menus"
```

### Task 3: Implement the manual window action path and target resolver

**Files:**
- Modify: `Sources/HiWindowGuy/Services/WindowManager.swift`

- [ ] **Step 1: Add new manual action entrypoints that intentionally call unresolved resolver helpers first**

Introduce `performManualCenter(triggerSource:)` and `performManualAlmostMaximize(triggerSource:)`, but initially route them through helper names like `resolveManualTargetWindow()` and `showManualWindowNotFoundAlert()` before those helpers exist.

- [ ] **Step 2: Run build to verify it fails on the missing manual resolver helpers**

Run: `swift build`
Expected: FAIL with missing helper errors for the manual target resolution path

- [ ] **Step 3: Implement the manual target resolver and alert feedback**

Requirements:

- fetch only `NSWorkspace.shared.frontmostApplication`
- prefer that app’s `AXFocusedWindow`
- fallback to the first non-minimized standard window in that same app
- do not use mouse location or the current mouse-priority search path
- reuse existing `centerWindow` and `almostMaximizeWindow`
- reuse accessibility permission checks
- show `NSAlert` with the approved “无法找到可操作的窗口” copy when no target is found
- write clear manual-action logs including trigger source and app identity

- [ ] **Step 4: Run build to verify the manual action path compiles**

Run: `swift build`
Expected: PASS with `Build complete!`

- [ ] **Step 5: Commit**

```bash
git add Sources/HiWindowGuy/Services/WindowManager.swift
git commit -m "feat: add manual window action resolver"
```

### Task 4: Add the homepage shortcut settings card in the approved UI language

**Files:**
- Modify: `Sources/HiWindowGuy/Views/HomeDashboardView.swift`
- Modify: `Sources/HiWindowGuy/Models/HomeDashboardState.swift`
- Modify: `Sources/HiWindowGuy/Models/AppConfig.swift`

- [ ] **Step 1: Add new homepage state references and view helper names before implementing the card**

Update `HomeDashboardView` to refer to a new manual shortcut settings card and any supporting state text so the build breaks before the card exists.

- [ ] **Step 2: Run build to verify it fails on the missing homepage card helpers**

Run: `swift build`
Expected: FAIL with missing helper/view/state symbols for the manual shortcut settings card

- [ ] **Step 3: Implement the shortcut settings card**

Requirements:

- place it on the existing homepage below the current cards, not in a new page
- use the same standard “常规设置卡” surface language already used by the homepage
- no new glass-heavy panel, no colorful dashboard styling, no gradient decorations
- each action row shows:
  - action title
  - current binding
  - modify / clear / restore default controls
- include a restrained recording/edit state for capturing a new shortcut
- show duplicate-binding validation inline with semantic warning styling only
- preserve existing homepage spacing, card radius, border, and typography hierarchy

- [ ] **Step 4: Run build to verify the homepage compiles with the new card**

Run: `swift build`
Expected: PASS with `Build complete!`

- [ ] **Step 5: Commit**

```bash
git add Sources/HiWindowGuy/Views/HomeDashboardView.swift Sources/HiWindowGuy/Models/HomeDashboardState.swift Sources/HiWindowGuy/Models/AppConfig.swift
git commit -m "feat: add homepage manual shortcut settings"
```

### Task 5: Run the full verification pass and complete manual QA

**Files:**
- Verify: `Sources/HiWindowGuy/Models/AppConfig.swift`
- Verify: `Sources/HiWindowGuy/Services/GlobalHotkeyManager.swift`
- Verify: `Sources/HiWindowGuy/Services/WindowManager.swift`
- Verify: `Sources/HiWindowGuy/Views/HomeDashboardView.swift`
- Verify: `Sources/HiWindowGuy/hiWindowGuyApp.swift`
- Verify: `Tests/HiWindowGuyTests/ShortcutBindingTests.swift`
- Verify: `Tests/HiWindowGuyTests/AppConfigShortcutTests.swift`

- [ ] **Step 1: Run the full automated test suite**

Run: `swift test`
Expected: PASS with all test suites green and no new failures

- [ ] **Step 2: Run a fresh build of the app**

Run: `swift build`
Expected: PASS with `Build complete!`

- [ ] **Step 3: Manually verify the manual action workflow in the running app**

Run: `swift run HiWindowGuy`

Manual checks:

- menu bar extra shows `窗口居中` and `几乎最大化`
- top `窗口管理` menu shows the same two actions
- `Control + Command + C` centers the frontmost app’s active standard window
- `Control + Command + M` almost-maximizes the frontmost app’s active standard window
- while another app is frontmost, the hotkeys still work
- mouse position does not change which window is targeted
- if the frontmost app has no usable standard window, the alert appears
- homepage shortcut card visually matches the current product UI standard
- duplicate shortcut entry is blocked in the UI
- clear and restore default work end-to-end

- [ ] **Step 4: Review the diff against the spec**

Checklist:

- automatic rule path still exists
- manual path is separate
- menus and hotkeys route through the same actions
- homepage UI stays within `docs/PRODUCT-UI-DESIGN-STANDARD.md`
- no new navigation or standalone settings page was introduced

- [ ] **Step 5: Commit**

```bash
git add Sources/HiWindowGuy/Models/AppConfig.swift Sources/HiWindowGuy/Models/ManualWindowAction.swift Sources/HiWindowGuy/Models/ShortcutBinding.swift Sources/HiWindowGuy/Services/GlobalHotkeyManager.swift Sources/HiWindowGuy/Services/WindowManager.swift Sources/HiWindowGuy/Views/HomeDashboardView.swift Sources/HiWindowGuy/Models/HomeDashboardState.swift Sources/HiWindowGuy/hiWindowGuyApp.swift Tests/HiWindowGuyTests/ShortcutBindingTests.swift Tests/HiWindowGuyTests/AppConfigShortcutTests.swift
git commit -m "feat: add manual window management controls"
```
