# Rule Config UI Standardization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle the `应用规则` 页面和其编辑弹窗，使其符合已确认的 Maru 产品级 UI 标准。

**Architecture:** Keep the navigation structure and data flow intact while replacing the current mixed web-like card styling with the approved product language: restrained tool surfaces on the right side, blue as the only primary accent, and denser, more native-feeling list and editor components. Remove the standalone search box from the page chrome for this first pass so the page matches the new standard’s “默认不引入搜索” rule; if search remains necessary later, it should return only as a justified tool-row control under the same standard.

**Tech Stack:** SwiftUI, AppKit, Swift Package Manager

---

## File Map

- Modify: `Sources/Maru/Views/RuleConfigView.swift`
  - Restyle page header, sorting/search tool row, list container, rule rows, bottom status bar, and rule edit sheet.
## Verification Strategy

- No automated tests are planned because this task is presentation-only.
- Use compile-fail/compile-pass steps when swapping major view structure.
- Final acceptance depends on manual verification in the running app:
  - `应用规则` 页与首页/左栏风格统一
  - 搜索、排序、列表、右键菜单和弹窗仍可工作
  - 页面读起来像工具面板，而不是卡片式网页后台

### Task 1: Standardize the page container and header/tool row

**Files:**
- Modify: `Sources/Maru/Views/RuleConfigView.swift:1-210`

- [ ] **Step 1: Replace the decorative header with a page-title header and standard page geometry**

Rewrite the current `headerView` so it removes the large icon block and uses the same hierarchy as the homepage:

- title: `应用规则`
- subtitle: concise explanation based on current rule count
- sort control as a compact tool button, not a floating material badge
- right-side container geometry must follow the standard defaults:
  - `maxWidth 760`
  - `padding 30`
  - top-level section spacing `24`

- [ ] **Step 2: Run build to verify the page fails if new header helper names are referenced before implementation**

Run: `swift build`
Expected: FAIL with missing helper errors

- [ ] **Step 3: Implement the new header and tool row**

Requirements:

- Header uses `largeTitle + bold` and `body + secondary`
- Remove the standalone search bar from the page
- Sort control sits inside a low-contrast tool row/surface
- Tool row reads as a stable dark surface, not a floating pill
- The top of the page must now read like the homepage/right-side standard, not like a separate feature dashboard

- [ ] **Step 4: Run build to verify it passes**

Run: `swift build`
Expected: PASS with `Build complete!`

- [ ] **Step 5: Commit**

```bash
git add Sources/Maru/Views/RuleConfigView.swift
git commit -m "feat: standardize rule config page chrome"
```

### Task 2: Rebuild the rule list into a unified tool surface

**Files:**
- Modify: `Sources/Maru/Views/RuleConfigView.swift:120-380`

- [ ] **Step 1: Replace the loose scroll/list presentation with a content surface**

Requirements:

- Wrap the rules area in a single stable surface matching the right-side content language
- Keep empty state inside the same surface instead of as a detached screen
- Bottom status bar must stop looking like a separate translucent overlay
- The rules surface must continue to honor the standard right-side geometry from Task 1

- [ ] **Step 2: Run build to verify any introduced helper names fail before implementation if applicable**

Run: `swift build`
Expected: FAIL only for the new list/surface helpers that do not exist yet

- [ ] **Step 3: Restyle `RuleRow` and list shell**

Requirements:

- Rows should feel denser and more like tool rows than marketing cards
- App icon area stays readable but less decorative
- Rule tag remains clear, but blue is the only primary accent; non-blue colors must be reduced to small semantic hints only and must not become competing visual accents
- Usage metadata should stay secondary
- Row background should be a stable dark surface with light border, not strong material
- Bottom status should merge visually with the list area

- [ ] **Step 4: Run build to verify it passes**

Run: `swift build`
Expected: PASS with `Build complete!`

- [ ] **Step 5: Commit**

```bash
git add Sources/Maru/Views/RuleConfigView.swift
git commit -m "feat: standardize rule list surfaces"
```

### Task 3: Restyle the rule edit sheet to match the product standard

**Files:**
- Modify: `Sources/Maru/Views/RuleConfigView.swift:380-520`

- [ ] **Step 1: Rework the editor layout into the same control-surface language**

Requirements:

- Header becomes quieter and more tool-like
- App summary block becomes cleaner, not oversized
- Rule option buttons become stable selection rows, not large colorful tiles
- Save/cancel actions remain obvious and system-like
- Per-rule color usage must follow the product standard: blue is the only primary accent, while other colors may only appear as restrained semantic hints

- [ ] **Step 2: Run build to verify any introduced helpers fail before implementation if applicable**

Run: `swift build`
Expected: FAIL only for new editor helper names that have not been defined yet

- [ ] **Step 3: Implement the editor restyle**

Requirements:

- Maintain existing behavior and data flow
- Reuse the same card radius, border, spacing, and blue selection language already defined by the UI standard
- Avoid adding new settings or new editor workflows

- [ ] **Step 4: Run build to verify it passes**

Run: `swift build`
Expected: PASS with `Build complete!`

- [ ] **Step 5: Commit**

```bash
git add Sources/Maru/Views/RuleConfigView.swift
git commit -m "feat: standardize rule edit sheet"
```
