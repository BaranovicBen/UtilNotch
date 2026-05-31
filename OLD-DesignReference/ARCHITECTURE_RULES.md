## Purpose

This document defines the non-negotiable architectural and UI rules for **Utility Notch**.

Its purpose is to prevent shell duplication, layout drift, AI-generated inconsistencies, and mode-specific UI forks.

From this point forward, any implementation that violates these rules is considered incorrect.

---

## 1. Product Definition

**Utility Notch is one application with one shared architecture.**

It supports two presentation modes:

- **Dynamic Island**
- **Extended Panel**

These are **not** two separate app layouts.

They are two presentation modes of the **same app**, with:

- the same data model
- the same module logic
- the same icons
- the same button actions
- the same shell structure
- the same sidebar structure
- the same layout system

### Rule

The only allowed differences between the two modes are:

- open / close animation
- top anchoring / notch attachment behavior
- idle live-activity presentation

Everything else must remain shared.

---

## 2. Visual Source of Truth

**Dynamic Island is the visual source of truth.**

This means:

- spacing
- paddings
- sidebar behavior
- scroll behavior
- title visibility
- footer placement
- icon treatment
- cleanliness of layout
- absence of helper lines

must all be defined by the Dynamic Island implementation and then reused by Extended Panel.

### Rule

If Extended Panel differs from Dynamic Island in structure or component behavior, Extended Panel is wrong.

---

## 3. Single Source of Truth

There must be **one shared source of truth** for the app.

### Shared across both modes

- app state
- module registry
- active module
- enabled modules
- persisted data
- icons
- button actions
- close rules
- module content logic
- footer text logic
- empty-state rules

### Rule

Mode selection must never create separate data, separate actions, or separate module layouts.

---

## 4. Canonical Shell Rule

There must be exactly **one canonical shell layout** used by both modes.

This shell is the only valid structural template for the application.

### Canonical shell dimensions

- **Outer container:** `622 x 382`
- **Main area:** `572 x 380`
- **Sidebar:** `48 x 380`

### Main area zones

- **Header:** `60`
- **Content:** `282`
- **Footer:** `38`

### Sidebar zones

- **Top blank area:** `60`
- **Scrollable icon area:** `282`
- **Settings footer area:** `38`

### Outer container visual treatment

- **Border radius:** `20px`
- **Border:** `1px solid rgba(255, 255, 255, 0.10)` — this is a ghost specular highlight, not a structural divider
- **Background:** black glass — `#000000` with `backdrop-filter: blur(20px)`
- **Overflow:** hidden — no content may bleed outside the outer container

### Rule

No module may redefine the shell structure.

No mode may define an alternate shell structure.

---

## 5. Module Ownership Rule

Modules do **not** own layout.

Modules may only provide:

- module title
- optional header action button
- main content
- footer left text (optional)
- footer right text (optional)

### Rule

Modules must not:
- create their own outer panel shell
- create their own sidebar shell
- create their own header/footer system
- introduce mode-specific spacing systems
- introduce alternate divider logic

Modules are content plugs, not layout roots.

---

## 6. Sidebar Rule

There must be exactly **one shared sidebar implementation**.

The sidebar is positioned on the **right side** of the shell.

### Sidebar requirements

- fixed width: `48px`
- positioned on the right
- internal scrolling only
- settings gear pinned to bottom footer zone (38px)
- top blank area: 60px (aligns with header zone, contains nothing)
- scrollable icon area: 282px
- same icon sizing across modes: `15px`
- active icon color: `#0A84FF`
- inactive icon color: `rgba(255, 255, 255, 0.35)`
- same active state across modes
- same spacing across modes
- same scroll masking behavior across modes
- left border: `1px solid rgba(255, 255, 255, 0.15)` — this is the only allowed structural divider in the app
- hover tooltip: module name appears to the left of the icon after a 150ms delay — SF Pro Regular, 12px, `rgba(255, 255, 255, 0.85)`, no border, `rgba(0, 0, 0, 0.60)` background, 8px border-radius, 8px horizontal padding
- tooltip must dismiss instantly on cursor exit — no linger delay
- tooltip must not appear for the settings gear icon

### Rule

Dynamic Island and Extended Panel must use the same sidebar component.

No duplicate sidebars.
No alternate sidebar variants.
No mode-specific sidebar behaviors.

---

## 7. Divider Rule

The app uses **vertical dominance**.

### Allowed divider

- one visible divider only:
  - **sidebar left border** — `1px solid rgba(255, 255, 255, 0.15)`

### Not allowed

- horizontal dividers between header / content / footer
- helper layout lines
- mode-specific decorative separators
- leftover design scaffolding in production UI

### Rule

If a visible line exists outside the sidebar left border, it is a bug.

The outer container ghost border (`1px solid rgba(255, 255, 255, 0.10)`) is a surface edge treatment, not a divider. It does not violate this rule.

---

## 8. Header Rule

The current module title must always be visible.

### Header requirements

- height: `60px`
- title: left-aligned, vertically centered within the 60px zone
- title typography: SF Pro Semibold, 16px, 100% white
- optional action button: right-aligned, vertically centered, same 60px zone
- padding left: `24px`
- padding right: `24px`
- no divider line below the header
- shared placement across modes
- shared spacing across modes

### Rule

The header may be visually compact, but it must remain present.

The current module title is not optional.

If a module provides no action button, the right side of the header is empty. Nothing fills it.

---

## 9. Footer Rule

The main footer displays technical or contextual metadata provided by the active module.

The sidebar footer zone contains only the settings gear icon.

### Main footer requirements

- height: `38px`
- text vertically centered within 38px
- footer left text: optional, module-provided
- footer right text: optional, module-provided
- typography: SF Mono Regular, 10px, uppercase, `rgba(255, 255, 255, 0.60)`, `letter-spacing: 0.08em`
- padding left: `16px`
- padding right: `16px`
- no divider line above the footer
- no icons or controls in the main footer — text only

### Sidebar footer requirements

- height: `38px`
- contains only the settings gear icon
- gear icon: centered horizontally and vertically within the 38px zone
- gear icon size: `18px`
- gear icon color: `rgba(255, 255, 255, 0.50)`
- gear hover color: `rgba(255, 255, 255, 1.0)`

### Rule

Footer structure must remain shared across modules and modes.

No module-specific footer layout systems.

Both left and right footer text slots are optional. A module may provide one, both, or neither.

---

## 10. Presentation Layer Rule

Presentation is allowed to differ by mode.

Layout is not.

### Dynamic Island is responsible for

- premium open / close motion
- notch-origin presentation
- notch attachment illusion
- idle live-activity presence
- overlap with menu bar

### Extended Panel is responsible for

- minimal or no animation
- simple top-anchored display, positioned just below the menu bar
- same shell without DI morph behavior

### Extended Panel positioning

- Y origin: `visibleFrame.maxY - panelHeight` (just below the menu bar / notch)
- Dynamic Island Y origin: `screenFrame.maxY - panelHeight` (anchored to physical screen top for notch overlap)
- These are the only allowed positional differences between the two modes

### Rule

Dynamic Island and Extended Panel may differ in motion and anchoring only.

They may not differ in shell structure.

---

## 11. Animation Rule

### Dynamic Island
Dynamic Island is allowed and expected to have premium motion.

Allowed:
- premium open animation
- premium close animation
- idle live-state presentation
- clean notch-emergence effect

Required:
- animation must feel smooth, elegant, and native
- animation must not feel clunky
- animation must not reveal ghost borders, empty shell frames, or border-only render states

### Open animation sequence (required order)

1. Frame expands from notch pill to full shell size using a spring curve
2. Content fades in **80ms after the frame has reached full size** — never simultaneously
3. These two phases must never overlap — frame settles first, content appears second
4. Any implementation where content renders during frame expansion is incorrect

### Close animation sequence (required order)

1. Content fades out first
2. Frame collapses back toward notch pill or fades out
3. The shell must never show a border-only state at any point during close

### Extended Panel
Required:
- minimal animation or no animation
- no Dynamic Island morph behavior

### Module switching
Required:
- only the main content panel should transition
- module switching uses crossfade
- sidebar state must be preserved across module switches
- sidebar scroll position must not reset when opening another module
- opening a module must not visually feel like the whole app reloaded

### Rule
Dynamic Island may keep richer animation, but Extended Panel must remain simpler.
Animation must never cause shell resets, sidebar resets, or render artifacts.

---

## 11A. Sidebar State Preservation Rule

The sidebar is stateful UI and must preserve its state across module switches.

Required:
- sidebar scroll position must remain unchanged when switching modules
- the currently visible portion of the module list must stay exactly where the user left it
- only the main panel content should update when selecting a different module
- the sidebar must not jump to the top unless the app is freshly opened or explicitly reset by the user

### Rule
Module selection must not recreate or reset the sidebar view.
If the sidebar scroll position resets during normal module switching, it is a bug.

---

## 12. Close Behavior Rule

The panel closes after pointer exit according to user settings.

This may be:
- instant close
- delayed close
- no delay
- configurable timeout

### Additional requirement

Specific modules may temporarily suppress closing.

### Current required exception

- **File Converter** must keep the panel open for **10 seconds** to support drag-and-drop interaction.

### Rule

Temporary hold-open behavior must be implemented via shared dismissal logic, not hacked into layout code.

---

## 13. Empty State Rule

All empty states must follow a consistent structure.

### Empty state requirements

- placement: vertically and horizontally centered within the content area
- structure: icon (optional) + primary text + secondary text
- primary text: SF Pro Regular, 14px, `rgba(255, 255, 255, 0.50)`
- secondary text: SF Mono Regular, 11px, uppercase, `rgba(255, 255, 255, 0.30)`
- no borders, no boxes, no decorative containers around empty states
- spacing between primary and secondary text: `8px`

### Rule

Empty states must feel like one system, not per-module inventions.

Each module writes its own copy (primary and secondary strings), but the visual structure — placement, typography, opacity — is fixed by this rule and must not be overridden per module.

---

## 14. v1 Scope Rule

### Keep in first stable release

- Todo
- Quick Notes
- Clipboard
- Music
- File Converter
- Calendar
- Files Tray

### Remove from first stable release path

- Live Activities
- Active Apps
- Recent Files
- Downloads

### Handling of removed modules

Removed modules must be moved to a `FutureModules/` folder within the project.

They must not be registered in `ModuleRegistry.allModules`.

They must not be imported or referenced by any active shell, presenter, or AppState code.

Their code must be preserved intact for future re-integration.

### Rule

Unstable modules must not complicate shell unification or presentation cleanup.

Do not delete the code. Do not connect it. Move it and leave it dormant.

---

## 15. Refactor Rule

When choosing between preserving broken duplicate code and removing it:

**prefer simplification**

### Allowed
- medium refactor
- shell rewrite
- presenter cleanup
- duplicate layout removal
- deprecating legacy views

### Not allowed
- full project scrap
- unnecessary business-logic rewrite
- preserving duplicate shell ownership "just in case"

---

## 16. File Responsibility Rule

The architecture must converge toward this ownership model:

### AppState
Owns shared state, settings, data, active module, dismissal rules.

### CanonicalShellView
Owns:
- outer frame (622 x 382, border-radius 20px, ghost border, black glass background)
- header zone (60px, title left-aligned, action button right-aligned)
- content slot (282px)
- footer zone (38px, text only, vertically centered)
- sidebar placement (48px, right side)
- border policy (sidebar left border only)
- padding
- background treatment

### SidebarRailView
Owns:
- icon list
- active state (blue icon)
- inactive state (35% white icon)
- internal scroll
- settings gear (sidebar footer, 38px zone)
- scroll masking
- hover tooltips (module name, 150ms delay, left of icon)

### DynamicIslandPresenter
Owns:
- DI animation
- notch attachment
- idle live-state presentation
- Y origin at `screenFrame.maxY - panelHeight`

### ExtendedPanelPresenter
Owns:
- simple anchored presentation
- minimal/no animation
- Y origin at `visibleFrame.maxY - panelHeight`

### Modules
Own only:
- content
- actions
- footer left string (optional)
- footer right string (optional)
- optional header action button

---

## 17. Anti-Slop Rule

This app must not become:

- AI-generated layout soup
- duplicated shell logic
- visually inconsistent
- structurally buggy
- over-animated
- non-native feeling
- ugly
- insecure
- dysfunctional

### Design target

The app should feel:

- native to the notch
- Apple-like
- elegant
- minimalist
- clean
- helpful
- personal
- functional

### Rule

Any implementation that makes the app feel hacked together, bloated, inconsistent, or fake-native must be rejected.

---

## 18. Final Enforcement Summary

Non-negotiable:

- one app
- one shell
- one sidebar (right side, 48px)
- one shared data model
- one shared module template
- Dynamic Island is visual truth
- Extended Panel is same shell, different presentation, sits just below menu bar
- outer container: 622 x 382, border-radius 20px, ghost border, black glass
- header: 60px, title left-aligned at 24px padding, action button right-aligned at 24px padding
- content: 282px
- footer: 38px, text only, vertically centered, SF Mono 10px uppercase
- sidebar: 48px wide, right side, left border only divider
- no horizontal divider lines anywhere
- title always visible
- settings gear only in sidebar footer zone
- internal sidebar scroll only
- crossfade on module switch
- sidebar scroll position preserved on module switch
- minimal/no Extended Panel animation
- DI open: frame expands first, content fades in 80ms after frame settles — never simultaneously
- sidebar hover tooltip: module name, 150ms delay, left of icon, instant dismiss on exit
- File Converter hold-open 10 seconds
- removed modules moved to FutureModules/, not deleted, not registered

Any deviation from these rules is a bug, not a design alternative.