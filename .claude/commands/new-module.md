---
allowed-tools: Read, Edit, Write, Glob, Grep, Bash, AskUserQuestion
description: Scaffold a new UtilityNotch module — reads the real contract before generating any file
---

You are scaffolding a new module for UtilityNotch. Before writing a single line of code, you must read the actual contract files from this project.

## Step 1 — Read the contract (do this first, always)

Read all three of these files before generating anything:

- `.claude/rules/module-contract.md` — exact protocol, file layout, registration steps
- `.claude/rules/architecture.md` — state, concurrency, dimension, color, animation rules
- `.claude/rules/design-tokens.md` — every token you'll need (colors, spacing, typography, springs)

Also read:
- `UtilityNotch/Modules/UtilityModule.swift` — the live protocol definition
- `UtilityNotch/Modules/ModuleRegistry.swift` — the live registration list
- `UtilityNotch/App/AppState.swift` lines 1–50 — to see init and persistence pattern

## Step 2 — Parse the user's request

Extract from the user's prompt:
- **Module name** (human label, e.g. "Habit Tracker")
- **Module id** (camelCase, stable, e.g. "habitTracker") — derive from name if not given
- **SF Symbol** — ask if not obvious
- **What the module displays** — its core data and UI
- **Does it need persisted state?** — if yes, what data?
- **Does it need background work?** — if yes, `supportsBackground: true` and explain
- **Action button?** — the `+` / primary action in the header

If anything is ambiguous, ask before generating.

## Step 3 — Generate exactly these files

### File 1: `UtilityNotch/Modules/<Name>/<Name>Module.swift`

```swift
import SwiftUI

struct <Name>Module: UtilityModule {
    let id = "<camelCaseID>"
    let name = "<Human Name>"
    let icon = "<sf.symbol>"
    var isEnabled = true

    func makeMainView() -> AnyView {
        AnyView(<Name>ModuleView())
    }
    // Only add makeSettingsView() if the module genuinely needs per-module settings
}
```

### File 2: `UtilityNotch/Modules/<Name>/<Name>ModuleView.swift`

Wrap content in `ModuleShellView` — look at `TodoModuleView.swift` for the exact call signature.
Key rules from the contract:
- `@Environment(AppState.self) private var appState` — never pass appState as init param
- Two-way binding: `@Bindable var state = appState` then `$state.property`
- Call `appState.setModuleActionButton(nil)` in `.onAppear` (or register the button)
- Content area is 574pt wide × 282pt tall (panelWidth 622 − sidebar 48)
- Animations: spring only (see design-tokens.md spring presets)
- Colors: `UNConstants.*` or the inline opacity patterns from design-tokens.md
- Empty state: never blank — provide a meaningful placeholder

### Do NOT generate:
- A ViewModel file (state lives in AppState)
- A separate Model file unless the model is non-trivial (more than 3 fields with methods)
- Any file not listed above

## Step 4 — Update two existing files

### `UtilityNotch/Modules/ModuleRegistry.swift`
Append to `allModules`:
```swift
<Name>Module()
```

### `UtilityNotch/App/AppState.swift`
If enabled by default, add `"<camelCaseID>"` to `_enabledModuleIDs` default array.
If the module needs persisted state:
1. Add a `PersistenceKey` case in `Helpers/PersistenceManager.swift`
2. Add the stored property + computed var with `persistence.save(...)` setter in AppState
3. Load it in `AppState.init()` with `persistence.load(...)`

## Step 5 — Report

After generating all files, print a summary:
```
## Module scaffolded: <Name>

Files created:
- UtilityNotch/Modules/<Name>/<Name>Module.swift
- UtilityNotch/Modules/<Name>/<Name>ModuleView.swift

Files modified:
- UtilityNotch/Modules/ModuleRegistry.swift — added <Name>Module()
- UtilityNotch/App/AppState.swift — added "<id>" to enabledModuleIDs
  [+ PersistenceKey if applicable]

Next steps:
- Build: xcodebuild -scheme UtilityNotch -configuration Debug -quiet
- The module will appear in the sidebar rail automatically
```
