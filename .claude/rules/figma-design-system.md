# Figma Design System Rules

UtilityNotch is a **native macOS SwiftUI + AppKit** app (macOS 14+, Swift 6). There is no HTML, CSS, React, or Tailwind in this codebase. When implementing a Figma design, every output from the Figma MCP server (which is React + Tailwind) must be fully translated into SwiftUI patterns, tokens, and conventions before any code is written.

---

## Required Figma-to-Code Workflow

**Follow this order exactly. Do not skip steps.**

1. Run `get_design_context` for the target node(s) to get the structured design representation.
2. If the response is too large, run `get_metadata` first to get the node map, then re-fetch only the needed nodes with `get_design_context`.
3. Run `get_screenshot` for a visual reference of the exact variant being implemented.
4. Download any assets the MCP server provides via its localhost endpoint — use those sources directly.
5. Translate React + Tailwind output into SwiftUI using the mappings below. Do **not** copy web code verbatim.
6. Validate the final SwiftUI view visually against the Figma screenshot before marking the task done.

---

## Platform Reality: SwiftUI Translation Guide

The Figma MCP server outputs React + Tailwind. Every concept maps to a SwiftUI equivalent:

| Figma/React/Tailwind concept | SwiftUI equivalent |
|---|---|
| `<div className="flex flex-col">` | `VStack(spacing: N)` |
| `<div className="flex flex-row">` | `HStack(spacing: N)` |
| `<div className="relative">` | `ZStack` |
| `className="text-white/85 text-sm"` | `.foregroundStyle(Color.white.opacity(0.85))` + `.font(.system(size: 14))` |
| `rounded-lg` / `rounded-xl` | `.clipShape(RoundedRectangle(cornerRadius: 8/12, style: .continuous))` |
| `bg-white/5` | `.fill(Color.white.opacity(0.05))` |
| `px-4 py-2` | `.padding(.horizontal, 16).padding(.vertical, 8)` |
| `hover:` states | `.onHover { h in ... }` + `withAnimation(.easeInOut(duration: 0.15))` |
| `transition` / CSS animations | `.animation(.spring(...), value: ...)` |
| `onClick` | `Button(action:)` with `.buttonStyle(.plain)` |
| `<img src="...">` | `Image(...)` or Figma MCP localhost asset |
| `<svg>` icons | SF Symbols via `Image(systemName:)` |
| Inline hex color | `Color(hex: "XXXXXX")` or a `UNConstants.*` token — never inline hex in views |

---

## Design Token Reference (`Helpers/Constants.swift`)

**IMPORTANT: Never use inline hex or magic numbers in views. Always use `UNConstants.*` tokens or the inline patterns listed below.**

### Panel Dimensions

```swift
UNConstants.panelWidth          // 622pt — full panel
UNConstants.panelHeight         // 382pt — full panel
UNConstants.panelCornerRadius   // 20pt  — outer panel corners
UNConstants.invertedCornerRadius // 10pt — inverted corner pieces
UNConstants.innerCornerRadius   // 12pt  — inner content corners
UNConstants.sidebarWidth        // 48pt  — RIGHT sidebar
UNConstants.headerHeight        // 60pt
UNConstants.footerHeight        // 38pt
UNConstants.contentHeight       // 282pt
// Module canvas = 542pt wide × 266pt tall
// (panelWidth 622 − sidebarWidth 48 = 574pt content VStack)
// (574 − 16pt padding × 2 = 542pt inner width)
// (contentHeight 282 − 8pt padding × 2 = 266pt inner height)
```

### Colors

```swift
UNConstants.panelBackground     // Color.black
UNConstants.accentHighlight     // Color.white.opacity(0.08)  — active state fill
UNConstants.iconTint            // Color.white.opacity(0.35)  — inactive icon
UNConstants.iconActiveTint      // Color(hex: "0A84FF")       — active/selected
UNConstants.successTint         // green 10% opacity          — success background
UNConstants.successBorder       // green 25% opacity          — success border
UNConstants.errorTint           // amber 10% opacity          — error background (amber, never red)
UNConstants.errorBorder         // amber 25% opacity          — error border
UNConstants.focusTint           // blue 8% opacity            — focused field background
UNConstants.focusBorder         // blue 50% opacity           — focused field border
```

### Inline color patterns (use directly in views — not in UNConstants)

```swift
// Text hierarchy
Color.white.opacity(0.85)   // primary text
Color.white.opacity(0.70)   // secondary heading (calendar date sub-label)
Color.white.opacity(0.60)   // footer / metadata text
Color.white.opacity(0.50)   // secondary text
Color.white.opacity(0.45)   // timestamp, monospaced metadata
Color.white.opacity(0.35)   // tertiary / inactive labels
Color.white.opacity(0.30)   // unchecked circle stroke, strikethrough
Color.white.opacity(0.25)   // placeholder text, section labels (uppercase mono)

// Row backgrounds
Color.white.opacity(0.07)   // editing state
Color.white.opacity(0.05)   // hover state
Color.white.opacity(0.03)   // resting state

// Borders / strokes
Color.white.opacity(0.15)   // sidebar left border (the ONLY structural divider)
Color.white.opacity(0.12)   // subtle divider (event week-strip selected cell)
Color.white.opacity(0.10)   // ghost panel border (specular edge)

// Accent / action colors (inline hex is allowed only when no UNConstants token exists)
Color(hex: "32D74B")        // checkmark fill, iOS system green
Color(hex: "FF453A")        // trash / destructive icon — only for delete actions
Color(hex: "0A84FF")        // same as iconActiveTint — use UNConstants.iconActiveTint instead
```

### Typography

**System fonts only. No custom font packages.**

```swift
// Shell header module title
.font(.system(size: 16, weight: .semibold))

// Body / list items / input fields
.font(.system(size: 14, weight: .regular))

// Section sub-labels, calendar event title
.font(.system(size: 13, weight: .semibold))

// Caption / timestamp
.font(.system(size: 11))
.font(.system(size: 11, design: .monospaced))

// Footer labels, section headers (always uppercase via .textCase(.uppercase))
.font(.system(size: 10, design: .monospaced))

// Sidebar tooltip
.font(.system(size: 12, weight: .regular))

// Sidebar icon size
UNConstants.sidebarIconSize    // 15pt (use in .font(.system(size:)))
```

### Timing / Animation

```swift
// Standard spring — buttons, selections, state changes
.spring(response: 0.28, dampingFraction: 0.72)

// Item add/remove in lists
.spring(response: 0.35, dampingFraction: 0.74)

// Drag displacement (rows sliding apart)
.spring(response: 0.35, dampingFraction: 0.70)

// Drag lift (the item being dragged)
.spring(response: 0.25, dampingFraction: 0.65)

// Hover state — the ONLY place easeInOut is acceptable
.easeInOut(duration: 0.15)

// Sidebar icon hover
.easeOut(duration: 0.14)
.easeInOut(duration: 0.12)

// Shell header/footer cross-fade on module switch
.easeInOut(duration: 0.22)

UNConstants.animationDuration      // 0.28 — standard spring response
UNConstants.contentFadeDelay       // 0.08 — cross-fade delay on module switch
UNConstants.hoverOpenDelay         // 0.3  — delay before panel opens on hover
UNConstants.defaultInactivityTimeout // 8.0 — auto-close after inactivity
UNConstants.sidebarTooltipDelay    // 0.15 — delay before sidebar tooltip appears
```

---

## Component Architecture

### Module view structure

Every module content view wraps its body in `ModuleShellView`. This pushes title, footer text, and action button into `AppState` for `CanonicalShellView` to read. Never render a header or footer yourself — they are provided by the shell.

```swift
struct MyModuleView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ModuleShellView(
            moduleTitle: "My Module",
            moduleIcon: "star.fill",
            modules: shellNavItems(appState: appState),
            activeModuleID: appState.activeModuleID,
            onModuleSelect: { id in
                withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                    appState.selectModule(id)
                }
            },
            statusDotColor: Color.white.opacity(0.2),   // legacy param, ignored
            statusLeft: "LEFT FOOTER TEXT",
            statusRight: "RIGHT FOOTER TEXT",
            actionButton: nil   // or: { AnyView(myActionButton) }
        ) {
            // Your drawing canvas: 542pt × 266pt
            // CanonicalShellView already adds 16pt horizontal + 8pt vertical padding
            // Do NOT add outer padding here
        }
        .onAppear {
            appState.setModuleActionButton(nil)
        }
    }
}
```

### Action button helpers

```swift
makeAddActionButton(icon: "plus", label: "ADD TASK")
makeDestructiveActionButton(icon: "trash", label: "CLEAR ALL")
```

### State management rules

```swift
// CORRECT — @Observable + @Environment
@Environment(AppState.self) private var appState

// CORRECT — two-way binding
@Bindable var state = appState
TextField("", text: $state.someProperty)

// WRONG — never use these
@StateObject, @ObservedObject, ObservableObject
$appState.property   // direct binding on environment — does not work
```

### DismissalLock — always pair insert with remove

```swift
// Text field focus
appState.dismissalLocks.insert(.activeEditing)   // on focus / onAppear
appState.dismissalLocks.remove(.activeEditing)   // onSubmit / onCancelEdit

// Drag session
appState.dismissalLocks.insert(.dragDrop)        // onDrag start
appState.dismissalLocks.remove(.dragDrop)        // performDrop / cleanup

// Picker open
appState.dismissalLocks.insert(.pickerOpen)      // picker presented
appState.dismissalLocks.remove(.pickerOpen)      // picker dismissed

// Long task (conversion, export)
appState.dismissalLocks.insert(.activeConvert)
appState.dismissalLocks.remove(.activeConvert)
```

---

## Icon System

**SF Symbols only.** Do not add custom icon libraries, do not install icon packages, do not embed SVG files unless the Figma MCP server provides a localhost asset URL (use that directly).

```swift
Image(systemName: "plus")           // add
Image(systemName: "checkmark")      // confirm / done state
Image(systemName: "xmark")          // cancel / close
Image(systemName: "pencil")         // edit
Image(systemName: "trash")          // delete (red — destructive only)
Image(systemName: "line.3.horizontal") // drag handle
Image(systemName: "gearshape")      // settings
Image(systemName: "calendar")       // calendar module
Image(systemName: "checklist")      // todo module
Image(systemName: "video.fill")     // video call indicator
Image(systemName: "chevron.left")   // nav: previous
Image(systemName: "chevron.right")  // nav: next
```

---

## Surface & Depth Rules (The Glass Monolith)

These rules derive from `DesignReference/DESIGN.md`:

1. **No drop shadows** — use background opacity shifts for elevation, not `shadow()`.
2. **No horizontal divider lines** — only the sidebar left border (`Color.white.opacity(0.15)`, 1pt wide) is a structural divider.
3. **No 100% opaque backgrounds** — everything floats over the desktop; use black with glassmorph effect.
4. **No sharp corners** — 20pt for the outer panel, 12pt for internal elements, 8pt for small controls.
5. **Panel glow is required** — the main panel background must include the ambient blue glow: radial gradient at 5% `#0A84FF` at top-left (currently implemented in `NotchPanelView`; never remove it).
6. **Surface layering** (recede → lift):
   - Base: `Color.black`
   - In-set containers (search fields): `Color.white.opacity(0.04)`
   - Resting rows: `Color.white.opacity(0.03)`
   - Hover: `Color.white.opacity(0.05)`
   - Active / lifted: `Color.white.opacity(0.08)`
   - Editing: `Color.white.opacity(0.07)`
7. **Error uses amber, not red.** `UNConstants.errorTint / errorBorder`. Red (`Color(hex: "FF453A")`) is reserved exclusively for the trash/delete icon.

---

## Asset Handling

- **Images from Figma MCP**: if the server returns a `localhost:` source for an image or SVG, use it directly — do not create a placeholder.
- **Static assets**: stored in `UtilityNotch/Assets.xcassets/`. Reference with `Image("assetName")`.
- **No new CDN or remote image dependencies** — this is a native offline-first utility app.
- **No new icon packages** — SF Symbols cover all icon needs.

---

## Project File Structure

```
UtilityNotch/
  App/
    AppDelegate.swift           — NSApplication lifecycle, menubar item, hotkey
    AppState.swift              — @Observable singleton, single source of truth
    NotchPanelController.swift  — @MainActor NSPanel controller
  Helpers/
    Constants.swift             — UNConstants (tokens), ScreenGeometry
    PersistenceManager.swift    — JSON-to-disk, PersistenceKey enum
    EventTriggerManager.swift   — hover/inactivity routing
    HoverTriggerZone.swift      — notch hover detection
    FileDragReceiverZone.swift  — drag-to-notch detection
  Modules/
    UtilityModule.swift         — protocol contract
    ModuleRegistry.swift        — ONLY registration point
    <Name>/
      <Name>Module.swift        — UtilityModule conformance struct
      <Name>ModuleView.swift    — content view (wraps ModuleShellView)
      <Name>Store.swift         — data layer, @Observable (if needed)
      <Name>View.swift          — sub-views (if complex enough to split out)
  Shell/
    CanonicalShellView.swift    — header + content slot + footer chrome
    ModuleShellView.swift       — metadata pusher (title, footer, action button)
    NotchPanelView.swift        — root SwiftUI view in NSPanel
    ActiveModuleContainerView.swift — cross-fade module switcher
    SidebarRailView.swift       — right icon rail (48pt)
    UtilityRailView.swift       — right utility strip
    DynamicIslandView.swift     — Dynamic Island panel style
  Settings/
    GeneralSettingsView.swift
    ModuleSettingsView.swift
    ModuleReorderSheet.swift
    PermissionsInfoView.swift
DesignReference/
  DESIGN.md                     — Authoritative design system spec ("The Glass Monolith")
  Reports/                      — Periodic design audits
```

---

## Persistence

New module data requires a `PersistenceKey` case — no `UserDefaults` for new data.

```swift
// 1. Add to PersistenceKey enum in Helpers/PersistenceManager.swift
enum PersistenceKey: String {
    case myModule = "myModule"   // ← add here
}

// 2. Save
PersistenceManager.shared.save(myValue, key: .myModule)

// 3. Load (in AppState.init)
let saved = persistence.load(MyModel.self, key: .myModule)
```

---

## Copy Voice Rules (from `DesignReference/DESIGN.md`)

- Footer strings: SF Mono, uppercase — this is the one exception to lowercase
- Body / empty state primary text: lowercase, human-facing
- No exclamation marks anywhere
- No "successfully" — the UI shows success; it does not announce it
- Error: "couldn't do that — try again" not "AN ERROR HAS OCCURRED"
- Empty state: "nothing here yet" not "NO ITEMS FOUND"

---

## Non-Negotiable Rules Summary

| Rule | Correct | Wrong |
|---|---|---|
| State | `@Observable` + `@Environment(AppState.self)` | `@StateObject`, `ObservableObject` |
| Bindings | `@Bindable var state = appState` then `$state.prop` | `$appState.prop` directly |
| Main actor | All NSWindow/NSScreen access `@MainActor` | Any off-main window access |
| Sidebar position | **Right** (HStack: content first, `SidebarRailView()` second) | Left |
| Sidebar width | 48pt | Any other value |
| Colors | `UNConstants.*` or listed inline patterns | Inline hex in views |
| Animations | Spring physics | `.linear`, plain `.easeIn/Out` on user interactions |
| Hover | `.easeInOut(duration: 0.15)` | Any spring for hover |
| Persistence | `PersistenceManager.shared` + `PersistenceKey` | `UserDefaults` for new data |
| DismissalLocks | Insert on focus/drag, remove on dismiss/cancel | Raw booleans |
| Icons | SF Symbols | Custom SVGs, icon packages |
| Error color | Amber (`UNConstants.errorTint`) | Red for errors |
| Dividers | None (background shifts) | Horizontal lines in content |
| Shadows | None | `shadow()` for elevation |
