# Sidebar Apple Cues Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle the left sidebar to feel Apple System Settings-inspired while preserving the existing right-side content and navigation structure.

**Architecture:** Keep the change strictly inside `ContentView.swift`. Replace the current sidebar’s web-like `List` chrome with explicit SwiftUI row composition so selection, icon plates, and container spacing can match the approved Apple-like cues without affecting the right pane. This is a presentation-only change, so verification is compile/build plus manual UI review instead of adding snapshot infrastructure.

**Tech Stack:** SwiftUI, Swift Package Manager, AppKit

---

## File Map

- Modify: `Sources/HiWindowGuy/Views/ContentView.swift:33-191`
  - Restyle only the sidebar container, brand block, navigation rows, selection highlight, footer status area, and sidebar width/padding.

## Verification Strategy

- No new automated tests are planned for this work because the approved scope is a presentation-only sidebar restyle with no new state or business logic.
- Use compile-fail/compile-pass steps to enforce incremental changes.
- Final acceptance depends on manual verification in the running app:
  - left sidebar looks Apple-like without copying System Settings structure
  - blue selected row reads as a system selection, not a web CTA
  - brand block keeps presence but tighter spacing
  - right-side home/rules/log panes stay visually unchanged

### Task 1: Rebuild the sidebar container and brand block

**Files:**
- Modify: `Sources/HiWindowGuy/Views/ContentView.swift:33-115`

- [ ] **Step 1: Rewrite `sidebarView` to reference the new shell pieces before they exist**

```swift
private var sidebarView: some View {
    VStack(spacing: 0) {
        sidebarBrandHeader
        sidebarDivider
        sidebarNavigationContent
        Spacer(minLength: 0)
        sidebarStatusFooter
    }
    .padding(.vertical, sidebarVerticalPadding)
    .padding(.horizontal, sidebarHorizontalPadding)
    .background(sidebarContainerBackground)
}
```

- [ ] **Step 2: Run build to verify it fails**

Run: `swift build`
Expected: FAIL with errors like `cannot find 'sidebarBrandHeader' in scope`

- [ ] **Step 3: Implement the new container and brand block**

```swift
private var sidebarBrandHeader: some View {
    HStack(spacing: 12) {
        sidebarBrandIcon

        VStack(alignment: .leading, spacing: 0) {
            Text("Hi Window Guy")
                .font(.system(size: 18, weight: .semibold))
        }

        Spacer(minLength: 0)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
}

private var sidebarDivider: some View {
    Divider()
        .overlay(Color.white.opacity(0.08))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
}

private var sidebarContainerBackground: some View {
    RoundedRectangle(cornerRadius: 26, style: .continuous)
        .fill(.regularMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
}
```

Implementation notes:
- Keep the brand block present, but tighten it relative to the current oversized header.
- Do not add search, account cards, or extra sections.
- Do not touch `mainContentView`, `HomeDashboardView`, `RuleConfigView`, or `LogViewer`.
- This task must also define `sidebarDivider` and `sidebarBrandIcon` in `ContentView.swift`; they are new helper surfaces, not pre-existing ones.

- [ ] **Step 4: Run build to verify it passes**

Run: `swift build`
Expected: PASS with `Build complete!`

- [ ] **Step 5: Commit**

```bash
git add Sources/HiWindowGuy/Views/ContentView.swift
git commit -m "feat: restyle sidebar container and brand block"
```

### Task 2: Replace the current list chrome with Apple-like navigation rows

**Files:**
- Modify: `Sources/HiWindowGuy/Views/ContentView.swift:76-166`

Existing glue to keep:
- `currentSection`
- `selectedSectionBinding`
- `NavigationSection.tab`
- notification handlers that already assign `selectedTab`

- [ ] **Step 1: Replace the existing `List` with explicit row composition before the row helpers exist**

```swift
private var sidebarNavigationContent: some View {
    VStack(spacing: 6) {
        ForEach(NavigationSection.allCases) { section in
            sidebarRow(for: section)
        }
    }
    .padding(.top, 8)
}
```

- [ ] **Step 2: Run build to verify it fails**

Run: `swift build`
Expected: FAIL with an error like `cannot find 'sidebarRow' in scope`

- [ ] **Step 3: Implement Apple-like navigation rows**

```swift
private func sidebarRow(for section: NavigationSection) -> some View {
    Button {
        selectedTab = section.tab
    } label: {
        HStack(spacing: 12) {
            sidebarRowIcon(for: section)

            Text(section.title)
                .font(.system(size: 15, weight: .medium))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .background(sidebarSelectionBackground(for: section))
    }
    .buttonStyle(.plain)
}

private func sidebarRowIcon(for section: NavigationSection) -> some View {
    Image(systemName: section.icon)
        .font(.system(size: 13, weight: .semibold))
        .frame(width: 24, height: 24)
        .background(sidebarRowIconPlate(for: section))
}

private func sidebarRowIconPlate(for section: NavigationSection) -> some View {
    RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(currentSection == section ? Color.white.opacity(0.16) : Color.white.opacity(0.08))
}

private func sidebarSelectionBackground(for section: NavigationSection) -> some View {
    RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(currentSection == section ? Color.blue : Color.clear)
}
```

Implementation notes:
- The selected state should read like a system-selected row, not a large website pill button.
- Keep the Apple-like blue highlight, but flatten it into the row structure.
- Icon plates must be consistent in size and placement across all rows.
- Reuse `selectedTab` as the only navigation source of truth.
- Keep the existing `currentSection` / `selectedSectionBinding` / `NavigationSection.tab` mapping instead of inventing a second local selection state.
- Keep the `.onReceive` handlers intact so notification-driven jumps to `应用规则` and `日志` still update the same selection source.
- This task must also define `sidebarRowIcon(for:)`, `sidebarSelectionBackground(for:)`, and any supporting icon-plate helper they depend on.

- [ ] **Step 4: Run build to verify it passes**

Run: `swift build`
Expected: PASS with `Build complete!`

- [ ] **Step 5: Commit**

```bash
git add Sources/HiWindowGuy/Views/ContentView.swift
git commit -m "feat: add apple-like sidebar navigation rows"
```

### Task 3: Rebalance footer, width, and final sidebar polish

**Files:**
- Modify: `Sources/HiWindowGuy/Views/ContentView.swift:33-115`

- [ ] **Step 1: Reference the final sidebar sizing/padding constants before defining them**

```swift
sidebarView
    .frame(width: sidebarWidth)
```

```swift
.padding(.vertical, sidebarVerticalPadding)
.padding(.horizontal, sidebarHorizontalPadding)
```

- [ ] **Step 2: Run build to verify it fails**

Run: `swift build`
Expected: FAIL with errors like `cannot find 'sidebarWidth' in scope`

- [ ] **Step 3: Implement the final sizing and footer restraint**

```swift
private var sidebarStatusFooter: some View {
    HStack(spacing: 8) {
        Circle()
            .fill(isWindowManagementEnabled ? Color.green : Color.secondary.opacity(0.5))
            .frame(width: 8, height: 8)

        Text(isWindowManagementEnabled ? "已启用" : "已停用")
            .font(.caption)
            .foregroundStyle(.secondary)

        Spacer(minLength: 0)
    }
    .padding(.horizontal, 12)
    .padding(.top, 14)
}

private var sidebarWidth: CGFloat { 248 }
private var sidebarHorizontalPadding: CGFloat { 12 }
private var sidebarVerticalPadding: CGFloat { 14 }
```

Implementation notes:
- Footer status must stay visible but clearly lower emphasis than the navigation rows.
- Sidebar width should feel closer to System Settings without crowding the right pane.
- Do not introduce new footer actions or new status messages.

- [ ] **Step 4: Run build to verify it passes**

Run: `swift build`
Expected: PASS with `Build complete!`

- [ ] **Step 5: Commit**

```bash
git add Sources/HiWindowGuy/Views/ContentView.swift
git commit -m "feat: finalize sidebar apple-cues styling"
```

### Task 4: Verify the sidebar-only acceptance criteria

**Files:**
- Verify: `Sources/HiWindowGuy/Views/ContentView.swift`

- [ ] **Step 1: Run the final build**

Run: `swift build`
Expected: PASS with `Build complete!`

- [ ] **Step 2: Launch the app for manual verification**

Run: `swift run HiWindowGuy`
Expected: App launches and shows the updated sidebar

- [ ] **Step 3: Manually verify the sidebar checklist**

Checklist:
- Left sidebar feels closer to macOS System Settings without adding search or extra sections.
- Brand block still has presence, but no longer reads like a page hero.
- Selected row uses a clear Apple-like blue highlight and no longer looks like a web CTA button.
- Footer status is visible but visually secondary.
- Right-side home content remains unchanged.
- Switching to `应用规则` and `日志` still works and only the sidebar styling changed.

- [ ] **Step 4: Confirm no off-scope files were changed**

Run: `git status --short`
Expected: clean working tree after the task commits, with no unrelated files modified

- [ ] **Step 5: Commit the verified result**

```bash
git status --short
git log --oneline -1
```

Expected:
- Working tree is clean
- The latest commit is either `feat: finalize sidebar apple-cues styling` or a later sidebar-only polish commit created from manual verification fixes
