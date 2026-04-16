# Architecture Rules

## Workflow Rules (NON-NEGOTIABLE)

### Rule: Plan Before Acting
Before touching any file on any non-trivial task:
1. Read ALL files relevant to the task
2. Output a written plan: files to create, files to modify, files left untouched, approach steps
3. **Wait for explicit user approval** (`go`, `yes`, `proceed`) before writing code
4. If the user pushes back, revise the plan — never start implementing without a green light

Applies to: any task touching more than one file, new features, refactors, module work.
Does not apply to: single-line fixes, git commands, typo corrections.

### Rule: UI / Backend Separation in Module Folders
Module folders follow this structure:
```
Modules/<Name>/
  <Name>ModuleView.swift   ← UI only. NEVER deleted. NEVER structurally modified.
  <Name>Module.swift       ← UtilityModule conformance. Minimal.
  <Name>Store.swift        ← Data layer: fetching, auth, state, business logic. @Observable.
  <Name>Model.swift        ← Data models (only if non-trivial, optional).
```

Rules:
- `*ModuleView.swift` is the UI source of truth. Its layout and visual structure are preserved.
- Dummy/placeholder data is replaced by **wiring the view to a Store** — not by editing the view's structure.
- The Store owns: external API calls, permission requests, data models, @Observable state, persistence.
- The View owns: layout, animations, colors, user interaction handlers.
- The View reads from the Store — it never calls EventKit, disk, or network directly.
- The Store is instantiated as `@State private var store = <Name>Store()` inside the module view.

---

## Layer Map

```
App/
  AppDelegate.swift          — NSApplication lifecycle, menubar status item, hotkey
  AppState.swift             — @Observable singleton, single source of truth
  NotchPanelController.swift — NSPanel management, @MainActor

Helpers/
  Constants.swift            — UNConstants (all dimensions/colors), ScreenGeometry
  EventTriggerManager.swift  — hover/inactivity event routing
  HoverTriggerZone.swift     — transparent NSWindow that detects notch hover
  PersistenceManager.swift   — JSON-to-disk, Codable only, no cloud

Modules/
  UtilityModule.swift        — protocol contract (READ THIS BEFORE ADDING A MODULE)
  ModuleRegistry.swift       — ONLY registration point, allModules array
  <Name>/
    <Name>Module.swift       — UtilityModule conformance struct + optional settings view
    <Name>ModuleView.swift   — content view passed to ModuleShellView

Shell/
  CanonicalShellView.swift   — outermost panel chrome, reads AppState.module* metadata
  ModuleShellView.swift      — per-module shell wrapper (header title, footer, action button)
  NotchPanelView.swift       — root SwiftUI view mounted in NSPanel
  ActiveModuleContainerView.swift — cross-fade switcher between modules
  SidebarRailView.swift      — left icon rail
  UtilityRailView.swift      — right utility strip
  DynamicIslandView.swift    — alternate Dynamic Island panel style

Settings/
  GeneralSettingsView.swift
  ModuleSettingsView.swift   — routes to each module's makeSettingsView()
  ModuleReorderSheet.swift
  PermissionsInfoView.swift
```

## Strict Rules

### State
- `AppState` is `@Observable`, accessed via `@Environment(AppState.self)`
- Two-way bindings use `@Bindable var state = appState` then `$state.property`
- Never use `@StateObject` / `ObservableObject` — project is fully on Swift Observation
- Persistent data goes through `PersistenceManager.shared` with a `PersistenceKey` case
- If a module needs its own persisted data, add a `PersistenceKey` case and store it in AppState

### Concurrency
- All `NSWindow`, `NSPanel`, `NSScreen` access → `@MainActor`
- `NotchPanelController` is `@MainActor final class`
- No `DispatchQueue.main.async` — use `await MainActor.run { }` or `@MainActor` annotation
- Module views are always constructed on the main actor (`@MainActor` on `makeMainView()`)

### Panel Dismissal
- Use `DismissalLock` OptionSet — never raw booleans for "panel should stay open"
- Text field focus → `.activeEditing`; drag session → `.dragDrop`; picker open → `.pickerOpen`
- Always `remove` the lock in `onCancelEdit`, `onSubmit`, `onDrop`, picker `onDismiss`

### Dimensions (from UNConstants)
- Panel: 622 × 382pt, cornerRadius 20pt
- Sidebar: 48pt wide
- Header: 60pt tall | Footer: 38pt tall | Content: 282pt tall
- Sidebar is on the **RIGHT** — `CanonicalShellView` puts the content VStack first (`maxWidth: .infinity`), then `SidebarRailView()` (48pt)
- Left content VStack width = **574pt** (622 − 48)
- `contentSlot` adds `.padding(.horizontal, 16)` → inner module content = **542pt** wide
- A git commit (`5d6728b`) references "268pt content zone" — does not match current constants, likely from an older panel dimension. Do not use 268pt.
- headerPaddingH: 24pt | footerPaddingH: 16pt

### Colors (from UNConstants)
- Panel background: `Color.black`
- Accent (active): `Color(hex: "0A84FF")`
- Icon tint (inactive): `Color.white.opacity(0.35)`
- Active state fill: `Color.white.opacity(0.08)`
- Hover state fill: `Color.white.opacity(0.05)`
- Success: `Color(red: 52/255, green: 199/255, blue: 89/255)` — use the `UNConstants.successTint/successBorder`
- Error (amber, not red): `UNConstants.errorTint / errorBorder`
- Focus border: `UNConstants.focusBorder`
- Never hardcode hex inline in views — use `UNConstants.*` or `Color(hex:)` with a comment

### Animations
- Standard spring: `.spring(response: 0.28, dampingFraction: ~0.72)` (matches `UNConstants.animationDuration`)
- Add/remove items: `.spring(response: 0.35, dampingFraction: 0.74)`
- Drag lift: `scaleEffect(1.03)`, `opacity(0.85)`, `shadow(radius: 8, y: 4)`
- Hover: `.easeInOut(duration: 0.15)` — the only place linear/ease is acceptable
- Module switch: handled by `ActiveModuleContainerView` — do not add competing transitions in module views
- Never use `.animation(.linear)` for anything user-facing except hover bg
