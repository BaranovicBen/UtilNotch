# Utility Notch — Project Context

> Generated 2026-03-28 for AI handoff.
> Branch: v1-beta. Do not modify this file manually — regenerate from codebase.

---

## 1. Project Identity

**Utility Notch** is a native macOS menu-bar/notch utility app written entirely in Swift and SwiftUI. It lives in the notch area (or top-center of the screen on non-notched Macs) and presents a floating dark-glass panel containing a set of modular utility tools: Todo, Quick Notes, Clipboard History, Music Control, File Converter, Live Activities, Calendar, Files Tray, Active Apps, Recent Files, Downloads.

- macOS only. No web, no cross-platform.
- No cloud, no backend. Local-first. All data persisted to local JSON via `PersistenceManager`.
- Agent-style dock-hidden app — no Dock icon, no standard menu bar.
- Two visual modes: **Expanded Panel** (full 620×380 panel below/at screen top) and **Dynamic Island** (collapses to a small pill that morphs into the full panel on hover).
- Demo tag target: `v1-demo`.

---

## 2. Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 6 (strict concurrency) |
| UI | SwiftUI + AppKit interop (NSPanel, NSWindow, NSScreen) |
| State | `@Observable` macro (Swift Observation framework) |
| Persistence | Custom `PersistenceManager` wrapping `JSONEncoder/Decoder` to `~/Application Support/UtilityNotch/` |
| Calendar | EventKit (`EKEventStore`) — requires entitlement |
| Music | Mock data only (MediaPlayer/MusicKit not yet integrated) |
| Clipboard | NSPasteboard (read: mock only; write: real) |
| Active Apps | `NSWorkspace.shared.runningApplications` (real, live) |
| Files Tray | Security-scoped bookmarks — requires `com.apple.security.files.bookmarks.app-scope` |
| Build | Xcode, `xcodebuild -scheme UtilityNotch -destination 'platform=macOS'` |

---

## 3. Full Git History (chronological, oldest first)

```
3500928 Initial Commit
init commit
af6e0c5 init commit
73fdf01 initial: Xcode template
5a5e958 feat: segment 1 - app lifecycle and dock hiding
9db292c feat: segment 2 - utility module protocol and registry
6d4a4dd feat: segment 3 - floating NSPanel and panel controller
1a61552 feat: segment 4 - shell UI with panel view, utility rail, and module container
9077e34 feat: segment 5 - open and close triggers with hover zone, hotkey, click-outside, escape, and inactivity timer
099e2c5 feat: segment 6 - four mock utility modules with full views
225fb06 feat: segment 7 - settings window with general, modules, and permissions tabs
f730840 feat: segment 8 - visual polish, animations, notch pill, and final cleanup
1bbd1bc fix: panel reopen bug - race-free hide animation, robust observation loops
e64e6c1 fix: complete UX bug report - close behavior, drag-and-drop, layout, tooltips, todo reorder, converter UI
c9f8f4e beta MVP-checkpoint
7f1da2d Initial plan
14e326b feat: segment 1 - settings architecture cleanup
57a79f1 feat: segment 2 - fix close behavior and click-outside dismiss bug
33c8813 feat: segment 3 - Command+drag module reordering in utility rail
6d1bd87 feat: segment 4 - redesign Quick Notes with compact cards, hover actions, click-to-expand
bfa10ef feat: segment 5 - UI polish, remove artifacts, reduce rail weight, improve alignment
c50e9be fix: address code review - fix event monitor leak, add accessibility label
434f719 Merge pull request #1 from BaranovicBen/copilot/refactor-settings-architecture
31907cb feat: segment 1 - persistent storage for todos, notes, module order, settings
eadef09 feat: segment 2 - reliable click-outside close behavior
cfbfec7 feat: segment 3 - module reorder fix and visual reorder sheet in settings
bd38cd0 feat: segment 4 - clipboard copy action, inline editing, exact creation time
342c2cd feat: segment 5 - file converter UI redesign with pill selectors and cleaner drop zone
0a37e34 feat: segment 6 - compact music module redesign with animated sound wave visualization
7765484 feat: segment 7 - timer module with presets, system sounds, and progress ring UI
d71e7be feat: segment 8 - fix todo drag reorder with native onMove, remove legacy drop delegate
939896f fix: resolve build errors - editMode unavailable on macOS, ShapeStyle ternary types
d7bb990 fix: segment 1 - remove spurious menu bar box
878ae62 feat: segment 2 - todo done item moves to bottom
9a3b0ea feat: segment 3 - music module UI redesign
43b6ac7 feat: segment 4 - active apps module with force quit
0ca2d0f feat: segment 5 - timer native integration and layout redesign
b589789 feat: segment 6 - dynamic island UI style option
7780e8a fix: resolve ShapeStyle type mismatch in timer control button
79fc3c1 feat: segment 6 - calendar module with EventKit
7f2a064 feat: segment 7 - files tray module
4900c9c feat: segment 8 - live activities module with notch split animation
47bb2ed feat: segment 9 - register new modules, clean settings
c6ffbf3 fix: segment 1 - dynamic island origin and auto-expand on show
5ad458f feat: segment 2 - dynamic island content clip and delayed fade-in
038406e feat: segment 3 - sidebar redesign with scroll, fade mask, gear button
6ed83ca feat: segment 4 - music module compact layout with circular controls
58de8b0 feat: segment 5 - DismissalLock OptionSet replaces boolean flags
7a9a957 feat: segment 6 - live activities type enum, demo data, animation fix
62015b8 feat: segment 7 - placeholder demo data for empty modules
5b710ce chore: segment 8 - build clean, zero errors, zero warnings
50392e5 fix: segment 0 - app icon asset catalog wiring
2992d01 feat: ui - segment 1 - module shell view
2497ff1 feat: ui - segment 2 - music module
db28c2d feat: ui - segment 3 - todo module
d0b88f1 feat: ui - segment 4 - clipboard module
9579dee feat: ui - segment 5 - quick notes module
3961867 feat: ui - segment 6 - converter module
8420177 feat: ui - segment 7 - active apps module
0efef3e feat: ui - segments 8+9 - recent files and downloads modules
279bab5 feat: ui - segment 10 - files tray module
d74025f feat: ui - segment 11 - calendar module
94cd1d1 feat: ui - segment 12 - live activities module
58fdb22 chore: segment 13 - build clean, zero errors, zero warnings
66871a6 fix: calendar content height constraint and element scaling
7cb84c1 fix: calendar remove extra top padding on date row
b1cf781 fix: calendar date row top padding nudge
b644cea fix: calendar date row top padding nudge
d941348 fix: calendar top padding and header separator
b071f10 fix: calendar top spacing
50ee341 fix: calendar and files tray top spacing matched to live activities
346974b fix: segment 1 - remove duplicate sidebar in dynamic island mode
25b38f8 fix: segment 3 - todo interactivity restored
b41f7b8 fix: segment 4 - quick notes interactivity restored
e0b6e46 fix: segment 5 - clipboard interactivity restored
bd38cd0 fix: segment 6 - converter interactivity restored (duplicate SHA shown)
172bb6a fix: segment 7 - dummy data fallback for permission-gated modules
79b1dad fix: segment 8 - active apps and files tray interactivity
a9df113 fix: segment 8 - active apps and files tray interactivity (cont.)
8402e45 fix: segment 9 - build clean and smoke test pass
766329a feat: segment 1 - music sound wave, larger controls and progress bar
cf4f3e5 feat: segment 2 - todo delete + description field in add row and card
cf3e5... feat: segment 3 - quick notes body TextEditor wired to note creation
621eef5 feat: segment 4 - active apps real NSWorkspace icons replace placeholders
4fe87b5 feat: segment 5 - wire quick notes NEW NOTE button to focus input field
67fc27b fix: music wave moved into artwork row right column
c6e2c07 fix: segment 1 - remove todo description completely
a76c783 fix: segment 2 - quick notes popup flow and card actions
2d52eb8 fix: segment 3 - music layout rebuilt, full-width wave with 30 bars
712d002 fix: segment 4 - build clean iteration 10 fixes
c26aaf5 fix: segment 2 - todo tap complete, hold reorder, edit, delete
5037e76 fix: segment 3 - build clean
ed9da79 docs: notch position and double header investigation
af5aff3 fix: segment 1 - expanded panel Y uses screenFrame not visibleFrame
1c2c5f0 fix: segment 2 - suppress drag handle and header in DI mode via env keys
060f84b fix: segment 3 - DI pill pinned to window top to emerge from notch
83425a4 fix: segment 4 - build clean notch position and DI fixes
72c756c fix: extended panel sidebar mask and active state matches DI
```

---

## 4. File Structure (all Swift files)

```
UtilityNotch/
├── App/
│   ├── AppDelegate.swift              — NSApplicationDelegate, dock hiding, hotkey, event monitors
│   ├── AppState.swift                 — @Observable central state, all persisted settings, models
│   └── NotchPanelController.swift     — NSPanel lifecycle, ScreenGeometry positioning, display observer
│
├── Helpers/
│   ├── Constants.swift                — ScreenGeometry struct + UNConstants enum (design tokens)
│   ├── EventTriggerManager.swift      — Hotkey, click-outside, inactivity timer, escape key
│   ├── HoverTriggerZone.swift         — Invisible NSWindow hover zone over notch
│   └── PersistenceManager.swift       — JSON encode/decode to ~/Application Support/UtilityNotch/
│
├── Modules/
│   ├── UtilityModule.swift            — Protocol: id, name, icon, makeView(), makeSettingsView()
│   ├── ModuleRegistry.swift           — allModules array, module(for:) lookup
│   │
│   ├── TodoList/
│   │   ├── TodoListModule.swift       — Module registration metadata
│   │   ├── TodoModuleView.swift       — ModuleShellView wrapper + live/dummy task rows
│   │   └── TodoListView.swift         — Legacy simpler view (superseded by TodoModuleView)
│   │
│   ├── QuickNotes/
│   │   ├── QuickNotesModule.swift
│   │   ├── QuickNotesModuleView.swift — ModuleShellView wrapper
│   │   └── QuickNotesView.swift       — Composer + NoteCard (hover actions, expand, edit)
│   │
│   ├── ClipboardHistory/
│   │   ├── ClipboardHistoryModule.swift
│   │   ├── ClipboardModuleView.swift  — ModuleShellView wrapper
│   │   └── ClipboardHistoryView.swift — Mock entries, search, row actions
│   │
│   ├── MusicControl/
│   │   ├── MusicControlModule.swift
│   │   ├── MusicModuleView.swift      — ModuleShellView wrapper
│   │   └── MusicControlView.swift     — Album art, waveform, circular controls, progress bar
│   │
│   ├── FileConverter/
│   │   ├── FileConverterModule.swift
│   │   ├── ConverterModuleView.swift  — ModuleShellView wrapper
│   │   └── FileConverterView.swift    — Format pills, drop zone, mock convert
│   │
│   ├── LiveActivities/
│   │   ├── LiveActivitiesModule.swift
│   │   ├── LiveActivitiesModuleView.swift — ModuleShellView wrapper
│   │   └── LiveActivitiesView.swift   — ActivityCard, AddActivitySheet, demo data, timer ticker
│   │
│   ├── Calendar/
│   │   ├── CalendarModule.swift       — ENTITLEMENT_NOTE: calendars permission
│   │   ├── CalendarModuleView.swift   — ModuleShellView wrapper
│   │   └── CalendarView.swift         — EKEventStore, day/week strip, event rows, settings view
│   │
│   ├── FilesTray/
│   │   ├── FilesTrayModule.swift
│   │   ├── FilesTrayModuleView.swift  — ModuleShellView wrapper
│   │   └── FilesTrayView.swift        — Security-scoped bookmarks, thumbnail grid, AirDrop share
│   │
│   ├── ActiveApps/
│   │   ├── ActiveAppsModule.swift
│   │   ├── ActiveAppsModuleView.swift — ModuleShellView wrapper
│   │   └── ActiveAppsView.swift       — NSWorkspace polling, real icons, force-quit rows
│   │
│   ├── RecentFiles/
│   │   ├── RecentFilesModule.swift
│   │   └── RecentFilesModuleView.swift — ModuleShellView wrapper, hardcoded demo data only
│   │
│   └── Downloads/
│       ├── DownloadsModule.swift
│       └── DownloadsModuleView.swift   — ModuleShellView wrapper, hardcoded demo data only
│
├── Shell/
│   ├── ActiveModuleContainerView.swift — Routes activeModuleID → correct module view
│   ├── AmbientActivityPill.swift       — Always-on notch pill showing active Live Activity
│   ├── DynamicIslandView.swift         — Collapsed pill ↔ expanded panel morph animation
│   ├── ModuleShellView.swift           — Shared shell: drag handle, header, content slot, footer, sidebar
│   ├── NotchPanelView.swift            — Expanded Panel mode root view
│   └── UtilityRailView.swift           — 40pt icon sidebar with scroll, fade mask, command+drag reorder
│
├── Settings/
│   ├── GeneralSettingsView.swift       — Launch at login (TODO), hotkey (TODO), inactivity timeout
│   ├── ModuleReorderSheet.swift        — Drag-to-reorder sheet for module order
│   ├── ModuleSettingsView.swift        — Per-module settings panel
│   └── PermissionsInfoView.swift       — Info sheet for Calendar/Accessibility permissions
│
└── UtilityNotchApp.swift               — @main, WindowGroup + Settings scene, AppState injection
```

---

## 5. Architecture Overview

### AppState

`@Observable final class AppState` — singleton via `AppState.shared`.

**Panel state:**
- `isPanelVisible: Bool` — drives show/hide in both modes
- `isPointerInsidePanel: Bool` — set by `.onHover` in DI; prevents close while hovering
- `dismissalLocks: DismissalLock` — composable OptionSet with cases: `.dragDrop`, `.pickerOpen`, `.activeConvert`, `.activeEditing`, `.moduleGesture`
- `shouldSuppressClose` / `shouldSuppressClickOutside` — computed from above

**Module state:**
- `activeModuleID: String` — persisted; drives `ActiveModuleContainerView`
- `enabledModuleIDs: [String]` — persisted ordered list; defines rail order
- `defaultModuleID: String?` — persisted; fallback module

**Settings (all persisted via `PersistenceManager`):**
- `panelStyle: PanelStyle` — `.expandedPanel` or `.dynamicIsland`
- `showHoverLabels`, `inactivityTimeout`, `menuBarSummaryMode`
- `showMusicWaveform`, `showAmbientPill`, `ambientPillDisplay`

**Data (persisted):**
- `todoItems: [TodoItem]` — `{id, title, description?, isDone}`
- `quickNotes: [QuickNote]` — `{id, title, body, createdAt}`

**Session-scoped (not persisted):**
- `liveActivities: [LiveActivity]` — cleared on relaunch by design
- `pendingFileURL: URL?` — set by drag-drop into DI panel

**Key models defined in AppState.swift:**
- `DismissalLock` (OptionSet)
- `TodoSummaryMode` (enum with `render()`)
- `PanelStyle` (enum: expandedPanel / dynamicIsland)
- `LiveActivity`, `LiveActivityType`, `AmbientPillDisplay`
- `QuickNote`

---

### ModuleRegistry

`enum ModuleRegistry` in `Modules/ModuleRegistry.swift`.

Single `static var allModules: [any UtilityModule]` array — the only place modules are registered. Contains 11 modules in default order:
`todoList, quickNotes, clipboardHistory, musicControl, fileConverter, liveActivities, calendar, filesTray, activeApps, recentFiles, downloads`

`module(for id: String) -> (any UtilityModule)?` — lookup by ID.

The `UtilityModule` protocol (in `UtilityModule.swift`) requires:
- `id: String`, `name: String`, `icon: String` (SF Symbol)
- `@ViewBuilder func makeView() -> some View`
- `@ViewBuilder func makeSettingsView() -> some View`

---

### NotchPanelController

`@MainActor final class NotchPanelController` — owns the floating `NSPanel`.

**Key behaviors:**
- `createPanel()` — builds `NotchPanel` (NSPanel subclass) with `contentRect` from `ScreenGeometry`. Window level set to `CGWindowLevelForKey(.mainMenuWindow) + 2` so it renders above the menu bar / inside the notch.
- `repositionPanel()` — uses `ScreenGeometry.panelOriginX/Y` fresh each call.
- `showPanel()` / `hidePanel()` — fade in/out via `NSAnimationContext`. `hideWorkItem` pattern prevents race condition on rapid show→hide.
- `rebuildPanel()` — called after `panelStyle` changes; tears down and lazily rebuilds on next show.
- `register(hoverTriggerZone:)` — stores weak ref to `HoverTriggerZone`.
- `repositionTriggerZone()` — calls `hoverTriggerZone?.reinstall()`.
- `screenObserver` — listens for `NSApplication.didChangeScreenParametersNotification`; calls `repositionPanel()` + `repositionTriggerZone()` when display config changes.

**Panel geometry (from `ScreenGeometry`):**
- Width: `UNConstants.panelWidth` = 620pt (fixed design dimension)
- Height: `UNConstants.panelHeight` = 380pt (fixed design dimension)
- X: `screen.frame.midX - 310` (horizontally centered on screen)
- Y: `screen.frame.maxY - 380` (top edge = physical screen top, covering notch)

The panel content (`hostingView`) fills the full 380pt. In DI mode, `DynamicIslandView` uses a `VStack(alignment: .top)` + `Spacer()` to pin the collapsed pill to window top so it emerges from the notch.

---

### ModuleShellView

`struct ModuleShellView<Content: View>` — the shared layout shell used by every module in Expanded Panel mode (and optionally DI expanded mode).

**Parameters:**
```swift
moduleTitle: String
moduleIcon: String          // SF Symbol
modules: [ModuleNavItem]    // for sidebar rail
activeModuleID: String
onModuleSelect: (String) -> Void
statusDotColor: Color
statusLeft: String          // footer left text
statusRight: String         // footer right text
actionButton: (() -> AnyView)?
@ViewBuilder content: () -> Content
```

**Layout (left to right):**
- Left column (fills remaining width):
  1. `dragHandle` — 36×5 capsule, `padding(.top, 8)` — **conditional on `showDragHandle` env key**
  2. `headerRow` — 44pt, icon + title + optional action button — **conditional on `showModuleHeader` env key**
  3. `contentSlot` — `content()` padded 16h/8v
  4. `footerBar` — 28pt, dot + left/right monospaced text
- Right column (40pt fixed, **suppressed when `showModuleSidebar == false`**):
  - Scrollable icon buttons with scroll fade mask (stops: 0/0.06/0.94/1)
  - Divider + settings gear pinned at bottom

**Active icon background:** `UNConstants.accentHighlight` = `Color.white.opacity(0.12)`, `cornerRadius: 8`

**Environment keys** (defined in ModuleShellView.swift):
- `showModuleSidebar` (default `true`) — suppress sidebar in DI mode
- `showDragHandle` (default `true`) — suppress capsule in DI mode
- `showModuleHeader` (default `true`) — suppress header row in DI mode

---

### ScreenGeometry

`struct ScreenGeometry` — all `static var` (computed fresh each call, never cached).

```swift
screen          → NSScreen.main ?? NSScreen.screens[0]
screenTop       → screen.frame.maxY
notchHeight     → screen.safeAreaInsets.top   // ~38pt on 14" MBP, ~32pt on others, 0 on non-notched
panelOriginY    → screenTop - UNConstants.panelHeight
panelOriginX    → screen.frame.midX - (UNConstants.panelWidth / 2)
triggerZoneHeight → notchHeight > 0 ? notchHeight : 12   // matches physical notch exactly
triggerZoneWidth  → 200 (fixed, covers notch with margin)
triggerZoneOriginY → screenTop - triggerZoneHeight
triggerZoneOriginX → screen.frame.midX - (triggerZoneWidth / 2)
hasNotch        → notchHeight > 0
```

`UNConstants` (in same file, design tokens only):
- `panelWidth: CGFloat = 620`
- `panelHeight: CGFloat = 380`
- `railWidthFraction: CGFloat = 0.18` (legacy reference, unused in layout)
- `railWidth: CGFloat = 40`
- `panelCornerRadius: CGFloat = 20`
- `innerCornerRadius: CGFloat = 12`
- `animationDuration: Double = 0.28`
- `hoverOpenDelay: Double = 0.3`
- `defaultInactivityTimeout: Double = 8.0`
- `panelBackground = Color(white: 0.08)`
- `railBackground = Color(white: 0.12)`
- `accentHighlight = Color.white.opacity(0.12)`
- `iconTint = Color.white.opacity(0.7)`
- `iconActiveTint = Color.white`
- `globalHotkeyKeyCode: UInt16 = 49` (Space), `globalHotkeyModifiers = .option`

---

### Panel Modes (Expanded vs Dynamic Island)

#### EXPANDED PANEL MODE

**Trigger:** `appState.isPanelVisible` becomes `true` via:
- Hover over trigger zone (after `hoverOpenDelay = 0.3s`)
- Global hotkey Option+Space
- Drop of file URL onto trigger zone

**Panel window:**
- Full 620×380 NSPanel, `level = mainMenuWindow + 2`
- Y origin = `ScreenGeometry.panelOriginY` = `screen.frame.maxY - 380`
- Panel top edge = physical screen top = notch top
- `collectionBehavior: [.canJoinAllSpaces, .fullScreenAuxiliary]`

**Root view:** `NotchPanelView` — renders drag capsule at top, then `HStack` with `ActiveModuleContainerView` (full width) + `UtilityRailView` (40pt). Standard drag handle and header are shown (env keys at default `true`).

**Sidebar:** `UtilityRailView` — real live sidebar with command+drag reorder, fade mask stops at 0/0.06/0.94/1, `UNConstants.accentHighlight` for active state.

#### DYNAMIC ISLAND MODE

**Trigger:** Same as expanded panel — `appState.isPanelVisible` becomes `true`, then `DynamicIslandView` internally handles the collapse ↔ expand morph.

**Root view:** `DynamicIslandView` — full 620×380 window, but content is a `VStack(spacing: 0) { ZStack(alignment: .top) { ... }; Spacer() }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)`. This pins the morphing pill to window top (= physical notch top).

**Collapsed pill:** 180×36pt `RoundedRectangle(cornerRadius: 18)` with `ultraThinMaterial` + `panelBackground.opacity(0.92)`. Shows app name + ambient indicator (music note glyph if `activeModuleID == "musicControl"`).

**Expand sequence:**
1. `appState.isPanelVisible` → `true`
2. `isExpanded = false`, delay 50ms
3. `withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { isExpanded = true }`
4. 180ms delay → `showContent = true` (content fade-in after shape morph is ~80% done)

**Expanded content (DI):**
- DI renders its own 36×5 capsule + `padding(.top, 8)`
- `ActiveModuleContainerView` with `.environment(\.showModuleSidebar, false)` + `.environment(\.showDragHandle, false)` + `.environment(\.showModuleHeader, false)` — suppresses shell chrome
- Separator `Rectangle(0.5pt)`
- `UtilityRailView()` at 40pt width

**Sidebar:** `UtilityRailView` — same component as expanded panel. This is the canonical reference sidebar implementation.

---

## 6. Design System (DESIGN.md)

### The Glass Monolith

**Creative North Star: The Ethereal Utility**

Moves away from "utility-as-a-tool" toward "utility-as-an-atmosphere." High-end editorial HUD carved from a single block of dark frosted glass, integrated with macOS Ventura/Sonoma ecosystem.

Rejects flat web-standard look. Embraces **Atmospheric Depth**: intentional asymmetry (40px right sidebar), high-contrast typography scales (SF Mono vs SF Pro), layered opacities.

---

### Colors & Surface Logic

Palette foundation: "True Dark" `#141414` and monochromatic white opacities. `primary` (#0A84FF) used sparingly as surgical strikes of intent.

**The "No-Line" Rule:** Traditional 1px solid borders are strictly prohibited for sectioning. Structural boundaries must be defined by background shifts. Separate content by moving from `surface_container_low` (#1C1B1B) to `surface_container_highest`.

**Surface Hierarchy:**
- Base Layer: `surface` (#141414 at 70% opacity) with 30–40px Backdrop Blur
- In-set Containers: `surface_container_low` (#1C1B1B) — recedes sections (e.g. search field)
- Raised Elements: `surface_bright` (#393939) at low opacity — lifts elements (e.g. hovered item)

**The Glass & Gradient Rule:** Use subtle radial gradient on the main panel. 5% opacity `primary` (#0A84FF) glow in top-left corner provides "visual soul," mimicking light on real glass.

---

### Typography

"Modern Editorial" pairing SF Pro with SF Mono:
- **Display/Header:** SF Pro Semibold 17px. 100% white.
- **Secondary Body:** SF Pro Regular 14px. 85% white.
- **Technical/Metadata:** SF Mono Regular 12px. 70% white.
- **Micro-Labels:** SF Mono Regular 11px Uppercase. 55% white, 0.05em letter-spacing. "System-readout" feel.

---

### Elevation & Depth

Depth via **Tonal Layering**, not shadows.

- Active state: increase background opacity from 5% white to 12% white (not shadow).
- Floating elements (tooltips): 40px blur shadow at 8% opacity, tinted with `primary` blue (not black).
- **Ghost Border Fallback:** Main panel uses 0.5px border at 7% white. Not a line — a specular highlight on the glass edge. Never for internal dividers.
- **Glassmorphism:** All panels must use `backdrop-filter: blur(20px)`.

---

### Components

**Buttons:**
- Primary: bg `#0A84FF`, text white 100%, radius 12px
- Secondary (Ghost): bg 7% white, text 85% white, no border
- Tertiary: no bg, text `#0A84FF`

**The Sidebar (Right Column):**
- 40px width. 1px vertical line at 5% white on left side. Icons 18px centered. `primary` blue for active, 35% white for inactive.

**Input Fields:**
- bg `#0E0E0E` at 40% opacity. Focus: change 0.5px ghost border from 7% white to `primary` blue at 50%.

**Lists & Navigation:**
- Spacing: `0.9rem` between items. No horizontal dividers. Hover bg 5% white at 4px radius.

**The Utility Header:**
- Height: 44px. `SF Pro Semibold 17px` title. Primary Blue icons for "Add"/"Settings" in 40px sidebar zone.

---

### Do's and Don'ts

**Do:**
- Use asymmetry. 40px right sidebar = distinct control strip.
- Use SF Mono for any numerical data or status strings.
- Use white opacities for hierarchy: Important = 100%, Secondary = 70%, Disabled = 20%.

**Don't:**
- **No Drop Shadows.** Breaks HUD glass illusion. Use background color shifts instead.
- **No 100% Opaque Backgrounds.** App must always feel like it's "floating."
- **No Sharp Corners.** 20px radius for main panel, 12px for internal elements.
- **No Pure Black.** Use `#141414`. Pure `#000000` kills glass transparency.

---

## 7. Investigation Report (INVESTIGATION.md — 2026-03-27)

### Issue 1 — Expanded Panel Y Position Mismatch (FIXED in v1-beta)

**Symptom:** In Expanded Panel mode, panel top sat below menu bar. Trigger zone at physical screen top. Gap between hover detection and panel appearance.

**Root Cause:** `NotchPanelController.swift:131` used `visibleFrame.maxY - panelHeight` (below menu bar by ~24pt) while trigger zone used `screenFrame.maxY`. DI branch correctly used `screenFrame.maxY`.

**Fix applied:** Both branches now use `ScreenGeometry.panelOriginY = screenFrame.maxY - panelHeight` via `repositionPanel()`.

---

### Issue 2 — Double Header in Dynamic Island Mode (FIXED in v1-beta)

**Symptom:** DI expanded mode showed two drag-handle capsules and a full header row (DI's own capsule + ModuleShellView's).

**Root Cause:** `DynamicIslandView.expandedContent` rendered its own 36×5 capsule. `ModuleShellView` unconditionally rendered `dragHandle` + `headerRow`. Only `showModuleSidebar` env key existed to suppress the sidebar; no equivalent keys for handle/header.

**Fix applied:** Added `showDragHandle` and `showModuleHeader` `EnvironmentKey`s. DI sets both to `false`.

---

### Issue 3 — Dynamic Island Animation Origin (FIXED in v1-beta)

**Symptom:** Collapsed pill appeared vertically centered (172pt below notch) inside the 380pt window, not at the physical notch.

**Root Cause:** `NSHostingView` fills full 380pt. SwiftUI's default `.center` alignment placed 36pt collapsed pill at `(380-36)/2 = 172pt` from top.

**Fix applied:** `DynamicIslandView` body uses `VStack(spacing: 0) { ZStack(alignment: .top) { ... }; Spacer() }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)` to anchor content to window top.

---

## 8. All Modules

### TodoList

- **File:** `Modules/TodoList/TodoModuleView.swift` (shell wrapper), `TodoListView.swift` (legacy view)
- **What it does:** Create, toggle, edit, delete, drag-reorder tasks. Completed tasks move to bottom with animation. Incomplete tasks move back before first done item on uncheck.
- **Data source:** `appState.todoItems: [TodoItem]` (persisted). Demo fallback: 5 hardcoded tasks at 50% opacity when list is empty.
- **Shell:** Uses `ModuleShellView`. Title: "Todo", icon: "checklist". Footer: "\(completed) COMPLETED TODAY" / "\(remaining) REMAINING". ActionButton: ADD TASK pill.
- **Known issues / bugs:**
  - `TodoModuleView` `liveRow()` uses `.onTapGesture { onToggle() }` on the whole row. This means tapping the title area **toggles the item** instead of entering edit mode. Double-tap to edit (via `onTapGesture(count: 2)`) is not present on the live row — edit is only accessible via the pencil icon on hover.
  - `TodoListView.swift` (older view) still exists alongside `TodoModuleView.swift` — dead file, never shown to user now that `TodoModuleView` is the registered view.

### QuickNotes

- **File:** `Modules/QuickNotes/QuickNotesModuleView.swift` (shell wrapper), `QuickNotesView.swift`
- **What it does:** Compact note composer (title + optional body). Cards show title, truncated body, creation timestamp. Hover: copy / convert-to-todo / delete. Single tap: expand/collapse. Double tap: inline edit. Demo fallback: 2 notes at 50% opacity.
- **Data source:** `appState.quickNotes: [QuickNote]` (persisted).
- **Shell:** Uses `ModuleShellView`. Title: "Quick Notes", icon: "note.text". Footer: "\(count) NOTES" / "LOCAL ONLY".
- **Known issues:** None visible in code.

### ClipboardHistory

- **File:** `Modules/ClipboardHistory/ClipboardModuleView.swift` (shell wrapper), `ClipboardHistoryView.swift`
- **What it does:** Displays mock clipboard entries with search. Click to "copy" (writes to real NSPasteboard). Hover: copy icon + delete. Footer hint about Accessibility permission requirement.
- **Data source:** Hardcoded `ClipboardEntry.mockEntries` (7 entries). **No real NSPasteboard monitoring.** Comment: `// MARK: TODO — replace with real pasteboard write` (though write already uses real NSPasteboard; the TODO refers to monitoring).
- **Shell:** Uses `ModuleShellView`. Title: "Clipboard", icon: "doc.on.clipboard". Footer: "\(count) ENTRIES" / "BETA MOCK".
- **Known issues:** The module comment says "Replace with real NSPasteboard monitoring later." Real clipboard history requires Accessibility permission. Currently entirely mock data.

### MusicControl

- **File:** `Modules/MusicControl/MusicModuleView.swift` (shell wrapper), `MusicControlView.swift`
- **What it does:** Shows album art (gradient placeholder), track title/artist, 4-bar animated sound wave (toggleable), circular prev/play/next controls, full-width progress bar. Simulated playback timer advances progress every 1 second. Cycles through 4 mock tracks.
- **Data source:** Hardcoded `MockTrack.sampleTracks` (4 tracks). `appState.showMusicWaveform` setting.
- **Shell:** Uses `ModuleShellView`. Title: "Music", icon: "music.note". Footer: track title / artist.
- **Known issues:** Entirely mock. No MediaPlayer/MusicKit integration. Play/pause/skip do not control real system music.

### FileConverter

- **File:** `Modules/FileConverter/ConverterModuleView.swift` (shell wrapper), `FileConverterView.swift`
- **What it does:** Format pills (PNG/JPG/HEIC/PDF/WEBP) for input and output. Dashed drop zone accepts file drops and updates `selectedFile`. Convert button runs a 1.5s mock delay then shows success. Dismiss locks for drag and conversion.
- **Data source:** Local `@State`. `appState.pendingFileURL` sets initial file from drag-into-DI.
- **Shell:** Uses `ModuleShellView`. Title: "File Converter", icon: "doc.badge.gearshape". Footer: selected format / "CONVERT".
- **Known issues:** Entirely mock. No actual file I/O. The `mockConvert()` function delays 1.5s and shows a success message without touching any file.

### LiveActivities

- **File:** `Modules/LiveActivities/LiveActivitiesModuleView.swift` (shell wrapper), `LiveActivitiesView.swift`
- **What it does:** Shows timed activity cards (icon, name, elapsed/remaining time, progress bar). + button opens `AddActivitySheet` with presets and custom entry. Activities are session-scoped (not persisted). Demo: 2 activities (Focus Session, Team Meeting) injected on first appear if list is empty.
- **Data source:** `appState.liveActivities: [LiveActivity]` (session-scoped). 1-second `Timer.publish` ticker updates time displays.
- **Shell:** Uses `ModuleShellView`. Title: "Live Activities", icon: "clock.badge.checkmark". Footer: "\(count) ACTIVE" / "LIVE".
- **Known issues:**
  - `LIVEACTIVITY_NOTE` in code: `matchedGeometryEffect` across windows is not supported on macOS. The "split from notch pill" animation is approximated with `.asymmetric` transition.
  - `AmbientActivityPill.swift` notes: `true cross-window matchedGeometryEffect is not supported on macOS`.

### Calendar

- **File:** `Modules/Calendar/CalendarModuleView.swift` (shell wrapper), `CalendarView.swift`
- **What it does:** Shows a day-number header with prev/next navigation, 7-day week strip (tap to select day), scrollable event list for selected day. Handles calendar permission: request / denied states. Configurable lookahead (today/3 days/7 days) and per-calendar enable/disable via settings view.
- **Data source:** `EKEventStore` (real calendar data after permission). Settings: `@AppStorage` keys `cal.lookaheadDays`, `cal.enabledCalIDs`.
- **Entitlement required:** `com.apple.security.personal-information.calendars`
- **Shell:** Uses `ModuleShellView`. Title: "Calendar", icon: "calendar". Footer: current date / "CALENDAR".
- **Known issues:** `ENTITLEMENT_NOTE` documented in `CalendarModule.swift`. Without the entitlement in the .entitlements file, `EKEventStore` access will fail silently or show permission denied.

### FilesTray

- **File:** `Modules/FilesTray/FilesTrayModuleView.swift` (shell wrapper), `FilesTrayView.swift`
- **What it does:** Drag-and-drop file staging area. Accepts files via drop, stores security-scoped bookmarks, shows 64×64 thumbnail grid (NSWorkspace icon). AirDrop share button (all items). Configurable max capacity (6/12/24). Persists to `~/Application Support/UtilityNotch/filesTray.json`.
- **Data source:** `TrayPersistence` (custom JSON file), `@AppStorage("filesTray.maxCapacity")`.
- **Entitlement required:** `com.apple.security.files.bookmarks.app-scope` for security-scoped bookmarks (documented in code with `ENTITLEMENT_NOTE`).
- **Shell:** Uses `ModuleShellView`. Title: "Files Tray", icon: "tray". Footer: "\(count) FILES" / "DRAG TO REORDER".
- **Known issues:** Without the bookmarks entitlement, bookmarkData will always be nil and file access falls back to plain path (which only works in same session).

### ActiveApps

- **File:** `Modules/ActiveApps/ActiveAppsModuleView.swift` (shell wrapper), `ActiveAppsView.swift`
- **What it does:** Lists all running user-facing apps (`.activationPolicy == .regular`, excluding self) with their real NSWorkspace icons. Polled every 3 seconds. Hover reveals Force Quit button; secondary hover on button shows confirm state. Force quit calls `NSRunningApplication.forceTerminate()`.
- **Data source:** `NSWorkspace.shared.runningApplications` (real, live). No AppState needed.
- **Shell:** Uses `ModuleShellView`. Title: "Active Apps", icon: "app.badge". Footer: "\(count) RUNNING" / "LIVE".
- **Known issues:** None visible in code.

### RecentFiles

- **File:** `Modules/RecentFiles/RecentFilesModuleView.swift`
- **What it does:** Shows a list of 5 hardcoded "recent" files with type icon (colored), filename, meta (type + size), and relative time. Pure display, no interactions.
- **Data source:** Hardcoded `[FileEntry]` — 5 demo files (PDF, PNG, SWIFT, FIGMA, JSON).
- **Shell:** Uses `ModuleShellView`. Title: "Recent Files", icon: "doc.text.magnifyingglass". Footer: "RECENT FILES" / "LOCAL ONLY". ActionButton: nil.
- **Known issues:** Entirely hardcoded demo data. No connection to `NSDocumentController`, `NSMetadataQuery`, or any real recent files API.

### Downloads

- **File:** `Modules/Downloads/DownloadsModuleView.swift`
- **What it does:** Shows a list of 4 hardcoded "completed" downloads with icon, filename, status, size, relative time. "Clear All" destructive action button in header (no-op — does nothing when tapped, button label renders but action closure is empty).
- **Data source:** Hardcoded `[DownloadEntry]` — 4 demo downloads.
- **Shell:** Uses `ModuleShellView`. Title: "Downloads", icon: "arrow.down.circle". Footer: "4 DOWNLOADS" / "FINDER → CLEAR". ActionButton: `makeDestructiveActionButton(icon: "trash", label: "CLEAR ALL")`.
- **Known issues:** Entirely hardcoded demo data. The CLEAR ALL button calls `makeDestructiveActionButton` which returns a view but has no `action` closure wired to it (the returned `AnyView` is a display-only `ShellActionButton` with no tap handler unless wrapped in a `Button` — check `ConverterModuleView.swift` for comparison). No connection to real downloads directory or `NSMetadataQuery`.

---

## 9. Known Issues and TODO Items

From `grep -r "TODO|FIXME|HACK|// NOTE|LIVEACTIVITY_NOTE|ENTITLEMENT_NOTE" . --include="*.swift"`:

| File | Line | Tag | Content |
|---|---|---|---|
| `Settings/GeneralSettingsView.swift` | 28 | TODO | `Wire to SMAppService.mainApp.register() in production` |
| `Settings/GeneralSettingsView.swift` | 33 | TODO | `Make configurable with a shortcut recorder` |
| `App/AppState.swift` | 256 | NOTE | `does NOT block click-outside — clicking outside naturally unfocuses the field` |
| `Shell/AmbientActivityPill.swift` | 9 | LIVEACTIVITY_NOTE | `True cross-window matchedGeometryEffect is not supported on macOS` |
| `Modules/ClipboardHistory/ClipboardHistoryView.swift` | 69 | TODO | `replace with real pasteboard write` |
| `Modules/Calendar/CalendarModule.swift` | 4 | ENTITLEMENT_NOTE | `requires com.apple.security.personal-information.calendars` |
| `Modules/FilesTray/FilesTrayView.swift` | 15 | ENTITLEMENT_NOTE | `requires com.apple.security.files.bookmarks.app-scope` |
| `Modules/LiveActivities/LiveActivitiesView.swift` | 104 | LIVEACTIVITY_NOTE | `asymmetric transition — spring-scale in from top (implies "split from notch pill"), fade-scale out` |

**Additional undocumented issues visible in code:**
- `GeneralSettingsView.swift`: Launch-at-login toggle is wired to `appState.launchAtLogin` but `launchAtLogin` setter does nothing (`_launchAtLogin = newValue` only) — `SMAppService` never called.
- `DownloadsModuleView.swift`: CLEAR ALL button uses `makeDestructiveActionButton` which returns a display-only view with no tap handler. Tapping does nothing.
- `RecentFilesModuleView.swift` + `DownloadsModuleView.swift`: Entirely hardcoded demo data, no real file system integration.

---

## 10. Current Bugs Visible in UI

1. **Todo tap-to-toggle vs tap-to-edit:** In `TodoModuleView`, the live row has `.onTapGesture { onToggle() }` on the entire row. Tapping the task title toggles `isDone` instead of selecting for editing. Edit is only via hover pencil icon. This may or may not be intended behavior — review needed.

2. **Sidebar inconsistency (Expanded Panel vs DI):** The expanded panel uses `ModuleShellView`'s internal `ShellRailButton` sidebar. DI uses `UtilityRailView`. These are separate implementations. `ShellRailButton` uses icon size 15pt; `UtilityRailView.RailButton` uses 18pt. Active state background is now aligned (`UNConstants.accentHighlight` in both) after recent fix, but icon color and spacing differ.

3. **Expanded panel header visible in some DI transitions:** After the `showDragHandle`/`showModuleHeader` env key fix, DI correctly suppresses the shell header. However if the panel is rebuilt via `rebuildPanel()` and re-shown before the env is properly propagated, the header may flash. This is a timing edge case.

4. **Expanded panel Y position:** Currently `panelOriginY = screenFrame.maxY - 380`. This places the panel top at the physical screen top. On a notched MacBook, the panel content renders **behind** the notch for the top ~38pt. This is intentional for DI mode (pill in notch) but may not be ideal for Expanded Panel mode where the content should sit **below** the notch. The original correct behavior for Expanded Panel was `visibleFrame.maxY - panelHeight` (just below menu bar). This was changed to `screenFrame.maxY` as a unified fix. Consider making `panelOriginY` mode-aware: DI → `screenFrame.maxY - 380`, Expanded Panel → `visibleFrame.maxY - 380`.

5. **DI module titles and action buttons missing:** Because `showModuleHeader = false` in DI mode, the module title and action button (e.g. "ADD TASK") are suppressed. The DI expanded content shows only the content area with no contextual title or primary action. This is the current state after the double-header fix.

---

## 11. User Preferences and Product Rules

| Rule | Detail |
|---|---|
| Platform | macOS only. Native Swift/SwiftUI. No Catalyst, no web. |
| Architecture | No backend, no cloud. Local-first. All data in `~/Application Support/UtilityNotch/`. |
| Modularity | Never rewrite the shell (`ModuleShellView`, `UtilityRailView`, `NotchPanelController`). Add modules by conforming to `UtilityModule` and appending to `ModuleRegistry.allModules`. |
| Module isolation | Module settings must stay inside their module's `makeSettingsView()`. Never put module-specific state in AppState unless it's cross-module (todo count for menu bar, active module ID). |
| Design language | Dark, compact, Apple-like, professional. "The Glass Monolith" design system (see §6). |
| Display support | Must work on all Mac display sizes: non-notched (iMac, external), notched 14"/16" MBP, non-retina. Use `ScreenGeometry` for all positioning. |
| Notch detection | Always use `NSScreen.main?.safeAreaInsets.top` via `ScreenGeometry.notchHeight`. Never hardcode notch height. |
| Expanded Panel Y | Should sit just below the notch / menu bar: `visibleFrame.maxY - panelHeight`. Currently using `screenFrame.maxY` (unified with DI). Consider making mode-aware. |
| Dynamic Island Y | Must anchor to physical screen top (`screenFrame.maxY`) so collapsed pill renders inside the notch area. |
| Sidebar reference | `UtilityRailView` is the canonical sidebar implementation (used by DI). `ModuleShellView.ShellRailButton` sidebar must be kept in sync with it. |
| Demo data | All permission-gated modules (Calendar, Clipboard, Files Tray) must show plausible demo data when permission is not granted or list is empty. |
| Demo tag | `v1-demo` — demo branch target. |
| Window level | Both panel and trigger zone must use `CGWindowLevelForKey(.mainMenuWindow) + 2` to appear above the menu bar and inside the notch. |
