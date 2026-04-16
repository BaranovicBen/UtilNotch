# Module Contract

Every module in UtilityNotch is a struct conforming to `UtilityModule` (defined in `Modules/UtilityModule.swift`).
Registration is done in `ModuleRegistry.allModules` (defined in `Modules/ModuleRegistry.swift`).
These are the **only two files** that need to change at the infrastructure level when adding a module.

---

## Protocol Requirements

```swift
protocol UtilityModule: Identifiable {
    var id: String { get }                    // stable, camelCase, unique e.g. "myModule"
    var name: String { get }                  // human label for settings/tooltip e.g. "My Module"
    var icon: String { get }                  // SF Symbol name e.g. "star.fill"
    var isEnabled: Bool { get set }           // user toggle — default true
    var supportsBackground: Bool { get }      // default false
    var supportsNotifications: Bool { get }   // default false
    func makeMainView() -> AnyView            // @MainActor @ViewBuilder
    func makeSettingsView() -> AnyView?       // @MainActor @ViewBuilder — default nil
    var requiredPermissions: [PermissionInfo] { get } // default []
}
```

Defaults for `supportsBackground`, `supportsNotifications`, `requiredPermissions`, `makeSettingsView` are provided by the protocol extension — only override if needed.

---

## File Layout for a New Module

```
Modules/
  <Name>/
    <Name>Module.swift       ← UtilityModule struct + optional settings view
    <Name>ModuleView.swift   ← content view, wraps ModuleShellView
```

Two files. No more unless the module has genuinely distinct sub-components.

---

## Module Struct Template

```swift
// <Name>Module.swift
import SwiftUI

struct <Name>Module: UtilityModule {
    let id = "<camelCaseID>"
    let name = "<Human Name>"
    let icon = "<sf.symbol>"
    var isEnabled = true

    func makeMainView() -> AnyView {
        AnyView(<Name>ModuleView())
    }
    // makeSettingsView() → omit if no per-module settings
}
```

---

## ModuleView Template

```swift
// <Name>ModuleView.swift
import SwiftUI

struct <Name>ModuleView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ModuleShellView(
            moduleTitle: "<Short Title>",      // shown in shell header
            moduleIcon: "<sf.symbol>",
            modules: shellNavItems(appState: appState),
            activeModuleID: appState.activeModuleID,
            onModuleSelect: { id in
                withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                    appState.selectModule(id)
                }
            },
            statusDotColor: Color.white.opacity(0.2),
            statusLeft: "<LEFT FOOTER TEXT>",
            statusRight: "<RIGHT FOOTER TEXT>",
            actionButton: nil   // or: { AnyView(<ActionButtonView>()) }
        ) {
            // Module content here
            // Your module view canvas: 542pt wide × 266pt tall
            // 574pt (622−48 sidebar) − 16pt padding each side = 542pt
            // 282pt contentHeight − 8pt padding top/bottom = 266pt
            // This padding is added by CanonicalShellView.contentSlot — do NOT add it yourself
        }
        .onAppear {
            appState.setModuleActionButton(nil)   // register action button if needed
        }
    }
}
```

---

## Registration

Append to `ModuleRegistry.allModules` in `Modules/ModuleRegistry.swift`:

```swift
static var allModules: [any UtilityModule] = [
    // existing modules...
    <Name>Module()   // ← add here
]
```

Also add the id string to `AppState._enabledModuleIDs` default array if it should be on by default:
```swift
private var _enabledModuleIDs: [String] = [
    "todoList", "quickNotes", ..., "<camelCaseID>"
]
```

---

## Module-Specific State

If the module needs persisted state:
1. Add a `PersistenceKey` case in `Helpers/PersistenceManager.swift`
2. Add a stored property + computed var with setter that calls `persistence.save(...)` in `AppState`
3. Load it in `AppState.init()` alongside existing loads

If the module needs ephemeral (session-only) UI state, use `@State` inside the view — do not put it in AppState.

---

## DismissalLock Usage

| Situation | Lock to use |
|---|---|
| User is typing in a text field | `.activeEditing` |
| Drag-and-drop session in progress | `.dragDrop` |
| Picker (color, file, date) is open | `.pickerOpen` |
| Long-running task (e.g. conversion) | `.activeConvert` |
| Gesture/scroll in progress | `.moduleGesture` |

Always remove the lock when the condition ends — in `onSubmit`, `onCancelEdit`, `onDrop`, etc.

---

## Checklist Before Shipping a Module

- [ ] `id` is unique and stable (won't change — it's used as a persistence key)
- [ ] `ModuleRegistry.allModules` updated
- [ ] `AppState._enabledModuleIDs` default updated (if enabled by default)
- [ ] `makeMainView()` wraps content in `ModuleShellView`
- [ ] `setModuleActionButton` called in `.onAppear` (pass nil if no action button)
- [ ] All `@MainActor` rules respected (no NSWindow/screen access off main)
- [ ] DismissalLocks inserted and removed correctly
- [ ] Animations use spring physics (see architecture.md)
- [ ] Colors via `UNConstants.*` — no inline hex
- [ ] Empty/default state has a meaningful placeholder (not a blank view)
