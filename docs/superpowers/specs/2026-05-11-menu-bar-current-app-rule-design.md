# Maru Menu Bar Current App Rule Design

Date: 2026-05-11
Status: Draft for review
Scope: Add a native menu bar quick configuration entry for the current foreground application's window rule.

## 1. Goal

Maru should let users configure the currently used application's window rule directly from the menu bar, without opening the main configuration window.

The intended workflow:

1. User is working in another app, for example Codex.
2. User clicks the Maru menu bar icon.
3. Maru shows a top menu item named `配置当前应用：Codex`.
4. The submenu lets the user choose `居中窗口`, `呼吸窗口`, or `忽略此应用`.
5. Choosing a layout rule saves the app rule and immediately applies it to the current app window.

This is a quick configuration feature, not a replacement for the full rules page.

## 2. Confirmed Product Decisions

- First version targets only the current foreground app.
- The menu should use a native `MenuBarExtra` submenu, similar to macOS input source menus.
- The submenu top-level title is `配置当前应用：<AppName>`.
- The UI shows only the app name, not the bundle identifier.
- Maru itself can be configured; there is no app blacklist.
- The target app is the app the user was using before opening Maru's menu, not Maru after the menu opens.
- Opening the menu does not write a new rule.
- Selecting a rule writes the rule.
- Selecting `居中窗口` or `呼吸窗口` immediately applies that action to the current window.
- Selecting `忽略此应用` only saves the ignore rule and does not move the current window.
- First version does not include `恢复默认`.

## 3. Menu Structure

The menu structure should place the current app rule submenu at the top:

```text
配置当前应用：Codex >
    ✓ 呼吸窗口
      居中窗口
      忽略此应用
----------
窗口自动管理
居中窗口
呼吸窗口
移到下一显示器
----------
应用配置
应用规则
检查更新…
----------
退出
```

Rules:

- The current rule is marked with the system menu checkmark.
- If the app has no explicit saved rule, the selected rule displays as `呼吸窗口`, matching Maru's default behavior.
- Long app names may be truncated by the native menu system; Maru should not add bundle IDs as fallback visible text.
- If no usable target app can be resolved, replace the top-level current-app submenu with a disabled top-level item:

```text
当前应用不可用
```

Do not show an empty submenu in this state.

## 4. Current App Resolution

The core product requirement is to configure the app the user was using before they clicked Maru's menu bar item.

Implementation must not rely on `NSWorkspace.shared.frontmostApplication` at the moment a rule menu item is clicked, because opening the Maru menu can change focus. The source of truth should be a captured app activation history from `NSWorkspace.didActivateApplicationNotification`.

Maintain two related snapshots:

- `lastActivatedApp`: latest app activation with a usable app name and bundle identifier.
- `menuTargetApp`: the target frozen for the currently rendered menu/action cycle.

The target resolver follows these rules:

1. Normal app case: if the latest activated app before Maru's menu interaction is Codex, the target is Codex.
2. Menu-caused Maru activation: if Maru becomes frontmost only because the menu opens, retain the previously captured `menuTargetApp`.
3. Genuine Maru target case: if Maru was already the real active app before the menu opened, Maru remains configurable and is the target.
4. Missing app data: if no captured app has both app name and bundle identifier, show the disabled unavailable state.

The state layer should maintain a "current menu target app" snapshot:

- app name
- bundle identifier
- process identifier

The process identifier is required for immediate window actions. Bundle identifier alone is not precise enough when multiple instances of an app exist.

No app blacklist is needed. If an app has a name and bundle identifier, it is configurable.

## 5. Rule Persistence

`AppConfig.updateRule(for:rule:)` only updates existing rules. The quick menu needs an upsert operation.

Add an API with behavior equivalent to:

```swift
setRule(for bundleId: String, appName: String, rule: WindowHandlingRule)
```

Behavior:

- If a rule exists for `bundleId`, update its rule and `lastUsed`.
- If no rule exists, create a new `AppRule` with the selected rule, app name, current date, and an initial usage count.
- Save `config.json`.
- Update `refreshID`.
- Post the same rule update notification used by the rules page.

Opening the menu must not call this API and must not create an `AppRule`.

## 6. Immediate Application

After saving a rule from the quick menu:

- `居中窗口` triggers the existing manual center window path for the captured target app.
- `呼吸窗口` triggers the existing manual almost-maximize path for the captured target app.
- `忽略此应用` does not trigger a window operation.

The existing manual action code currently operates on `NSWorkspace.shared.frontmostApplication`. This feature should extend `WindowManager` with a target-app manual action API that accepts the captured process identifier. The design intent is clear: apply to the captured app, not whatever app happens to be frontmost after menu interaction.

If the captured app no longer exists or no manageable window is found, Maru should log the failure and avoid crashing. A blocking alert is not required for this quick menu path.

## 7. Code Structure

Keep the logic small and testable:

- `CurrentAppRuleMenuState`
  - Pure state model for menu title, enabled state, selected rule, and rule options.
  - Takes an optional app target and current rules as input.
  - Does not touch AppKit directly.

- `CurrentAppRuleTarget`
  - Lightweight value type for app name, bundle identifier, and process identifier.

- `MaruApp`
  - Owns the menu target snapshot.
  - Tracks activation notifications used to resolve the pre-menu app target.
  - Renders the top-level current app submenu.
  - Handles user rule selection.
  - Delegates persistence to `AppConfig`.
  - Delegates immediate window actions to `WindowManager`.

- `AppConfig`
  - Adds the rule upsert API.

- `WindowManager`
  - Exposes a focused API for applying a manual action to a provided app target.
  - The API must resolve the target by captured process identifier and must not fall back to the current frontmost app for quick-menu actions.

Avoid redesigning the main window rules page as part of this feature.

## 8. Error Handling

Expected failure cases:

- No target app available.
- Target app has no bundle identifier.
- Target app exits before the menu action runs.
- Target app has no standard window to manage.
- Accessibility permission is missing.

Behavior:

- No target or missing bundle id: show disabled menu state.
- App exits or no manageable window: save the rule, log the failed immediate action, and leave the menu flow quiet.
- Missing Accessibility permission: reuse the existing permission request flow when a window action is attempted.
- Maru as target: treat it like any other app if it was genuinely captured before menu interaction.

## 9. Testing

Add focused tests before implementation:

- `CurrentAppRuleMenuState` builds `配置当前应用：Codex`.
- A missing target returns disabled `当前应用不可用`.
- An unsaved app displays default selected rule `呼吸窗口` without mutating config.
- Rendering/opening the current-app menu for an unsaved app does not mutate persistence.
- Existing saved rule drives the selected checkmark.
- Upserting a new app rule creates an `AppRule`.
- Upserting an existing app rule updates it.
- Selecting the checked default `呼吸窗口` for an unsaved app still creates an explicit rule and applies the action.
- `居中窗口` dispatches the immediate action to the captured target pid, not `NSWorkspace.shared.frontmostApplication`.
- `呼吸窗口` dispatches the immediate action to the captured target pid, not `NSWorkspace.shared.frontmostApplication`.
- Selecting `忽略此应用` saves without dispatching an immediate window action.
- Maru can be represented as a valid target app when it was genuinely the pre-menu app.
- Menu-caused Maru activation does not replace a previously captured non-Maru target.
- Status bar menu layout keeps stable ids and expected group ordering.

Manual verification:

- Work in Codex, open Maru menu, confirm top item is `配置当前应用：Codex`.
- Choose `居中窗口`; Codex rule is saved and current Codex window moves to center.
- Choose `呼吸窗口`; Codex rule is saved and current Codex window resizes.
- Choose `忽略此应用`; rule is saved and window does not move.
- Make Maru the genuinely active app before opening its menu and confirm `配置当前应用：Maru` is allowed.
- Open the main rules page and confirm the rule is visible there.

## 10. Out of Scope

- Recent apps list.
- Bundle id display in the menu.
- Restore default / delete rule action.
- Custom SwiftUI popover.
- Rule editing fields beyond the three existing rule types.
- Main rules page redesign.
