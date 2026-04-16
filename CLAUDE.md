# UtilityNotch

macOS notch-panel / menubar app. SwiftUI + AppKit. macOS 14+. Swift 6 concurrency.

---

## Rules (read before coding)

| File | What's in it |
|---|---|
| `.claude/rules/architecture.md` | Layer map, state rules, concurrency rules, exact dimensions, color/animation rules |
| `.claude/rules/module-contract.md` | How to add a module — protocol, file layout, registration, persistence, checklist |
| `.claude/rules/design-tokens.md` | All UNConstants values, inline color palette, typography, spring presets |

**Read the relevant rule file before touching any code.** These are derived from the live source — they are authoritative.

---

## Slash Commands

| Command | What it does |
|---|---|
| `/pe` | Prompt enhancer — spec any task before starting |
| `/new-module` | Scaffold a new module (reads contract first) |
| `/review-ui` | Emotional + native UI audit on a named module |
| `/build` | Build and surface only errors |
| `/security-review` | Security audit of branch changes |

---

## Skills

| Skill | Invoke | Purpose |
|---|---|---|
| `prompt-enhancer` | `/pe` or `/enhance` | Clarify task, confirm scope, wait for go |
| `emotional-design` | `/emotional-design` | 5-stage audit: Norman triad, Peak-End, Hooked Model, GEW |
| `build-native-ui` | `/build-native-ui` | SwiftUI/AppKit patterns for this project |
| `ios-simulator-skill` | `/ios-simulator-skill` | Build/test/automate simulator |
| `ui-ux-pro-max` | `/ui-ux-pro-max` | Design system, palettes, typography |
| `humanizer` | `/humanizer` | Remove AI writing patterns from text |

---

## Key Files

| File | Role |
|---|---|
| `UtilityNotch/App/AppState.swift` | `@Observable` singleton — all persistent and panel state lives here |
| `UtilityNotch/App/NotchPanelController.swift` | `@MainActor` NSPanel controller |
| `UtilityNotch/Helpers/Constants.swift` | `UNConstants` (all dimensions, colors, timing) + `ScreenGeometry` |
| `UtilityNotch/Helpers/PersistenceManager.swift` | JSON-to-disk, `PersistenceKey` enum |
| `UtilityNotch/Modules/UtilityModule.swift` | Protocol every module must conform to |
| `UtilityNotch/Modules/ModuleRegistry.swift` | **Only** registration point — append new modules here |
| `UtilityNotch/Shell/ModuleShellView.swift` | Wrapper every module's content view uses |
| `UtilityNotch/Shell/CanonicalShellView.swift` | Outermost chrome — reads `AppState.module*` metadata |

---

## Existing Modules

| ID | Name | Files |
|---|---|---|
| `todoList` | Todo List | `Modules/TodoList/` |
| `quickNotes` | Quick Notes | `Modules/QuickNotes/` |
| `clipboardHistory` | Clipboard History | `Modules/ClipboardHistory/` |
| `musicControl` | Music Control | `Modules/MusicControl/` + `Modules/Music/` |
| `fileConverter` | File Converter | `Modules/FileConverter/` |
| `calendar` | Calendar | `Modules/Calendar/` |
| `filesTray` | Files Tray | `Modules/FilesTray/` |

---

## Workflow (ALWAYS follow these)

**Plan before acting**: Read all relevant files → write a plan → wait for `go` before touching code. No exceptions on multi-file tasks.

**UI/Backend separation**: `*ModuleView.swift` is never deleted or structurally changed. Real data goes in `*Store.swift`. The view reads from the store, never calls EventKit/disk/network directly.

## Non-Negotiable Rules (summary)

- State: `@Observable` + `@Environment(AppState.self)` — never `ObservableObject`
- Bindings: `@Bindable var state = appState` — never `$appState.property` directly
- Main actor: all NSWindow/NSScreen access must be `@MainActor`
- Content width: sidebar is on the **right** (48pt). Content VStack = 574pt. With contentSlot's 16pt horizontal padding → **542pt** inner. A commit message references "268pt" — this is stale, ignore it.
- Colors: `UNConstants.*` only — no inline hex in views
- Animations: spring physics — no `.linear` or plain `.easeIn/Out` on user-facing interactions
- Hover: `.easeInOut(duration: 0.15)` — the only exception
- Persistence: `PersistenceManager.shared` + `PersistenceKey` case — no UserDefaults for new data
- DismissalLocks: insert on focus/drag start, remove on dismiss/cancel — never raw booleans

---

## Build

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme UtilityNotch -configuration Debug \
  -destination 'platform=macOS' build
```

Or just: `/build`
