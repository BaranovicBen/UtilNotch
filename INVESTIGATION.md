# Utility Notch — Diagnostic Investigation

**Date:** 2026-03-27
**Branch:** v1-beta
**Scope:** Read-only. No code was changed.

---

## Issue 1 — Expanded Panel Y Position Mismatch

### Symptom
In **Expanded Panel** mode the panel top edge sits below the menu bar, not flush with the physical screen top. The hover trigger zone is placed at the physical screen top, creating a gap between where the user hovers and where the panel actually appears.

### Root Cause

**Trigger zone origin** — `HoverTriggerZone.swift` line 27:
```swift
let y = screenFrame.maxY - zoneHeight   // top 12pt of physical screen
```
The invisible hover window occupies `screenFrame.maxY - 12` → `screenFrame.maxY`. Its top edge is the physical top of the display.

**Panel origin (Expanded Panel branch)** — `NotchPanelController.swift` line 131:
```swift
y = visibleFrame.maxY - UNConstants.panelHeight
```
`visibleFrame.maxY` is the top of the usable screen area — i.e., the bottom edge of the macOS menu bar, which is approximately `screenFrame.maxY - 24` on a standard display.

**Result:** The panel's top edge is ~24pt below the physical screen top, while the trigger zone spans the top 12pt. There is a ~12pt dead zone between where hover is detected and where the panel actually opens.

**Contrast — DI branch** (same file, lines 128–129): correctly uses `screenFrame.maxY`:
```swift
if appState.panelStyle == .dynamicIsland {
    y = screenFrame.maxY - UNConstants.panelHeight   // ✓ anchored to physical top
} else {
    y = visibleFrame.maxY - UNConstants.panelHeight  // ✗ below menu bar
}
```

### Files / Lines
| File | Line | Relevant code |
|------|------|---------------|
| `UtilityNotch/Helpers/HoverTriggerZone.swift` | 27 | `let y = screenFrame.maxY - zoneHeight` |
| `UtilityNotch/App/NotchPanelController.swift` | 128–132 | `y = visibleFrame.maxY - UNConstants.panelHeight` |

---

## Issue 2 — Double Header in Dynamic Island Mode

### Symptom
When the Dynamic Island panel expands, the top of the content shows **two** drag-handle capsules and a full header row (icon + module title) that duplicates the DI's own pill bar.

### Root Cause

`DynamicIslandView.swift` renders its own drag capsule inside `expandedContent` (lines 154–160):
```swift
// DynamicIslandView.swift:154-160
VStack(spacing: 0) {
    // Notch pill at top (same as NotchPanelView)
    Capsule()
        .fill(Color.white.opacity(0.1))
        .frame(width: 36, height: 5)
        .padding(.top, 8)
        .padding(.bottom, 4)

    HStack(spacing: 0) {
        ActiveModuleContainerView()
            .environment(\.showModuleSidebar, false)   // sidebar suppressed ✓
            ...
```

`ActiveModuleContainerView` routes to whichever module is active. Every module (Todo, Calendar, Music, Quick Notes, Active Apps, etc.) wraps itself in `ModuleShellView`. `ModuleShellView.swift` unconditionally renders `dragHandle` + `headerRow` as the first two items in its left column (lines 63–65):
```swift
// ModuleShellView.swift:63-65
VStack(spacing: 0) {
    dragHandle    // Capsule 36×5, padding(.top, 8) — always rendered
    headerRow     // HStack 44pt, icon + title + action button — always rendered
    contentSlot
    footerBar
}
```

`dragHandle` definition (lines 84–92):
```swift
private var dragHandle: some View {
    HStack {
        Capsule()
            .fill(Color.white.opacity(0.2))
            .frame(width: 36, height: 5)
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 8)
}
```

The `showModuleSidebar` environment key suppresses only the `sidebarRail` (lines 73–76). There is no equivalent key to suppress `dragHandle` or `headerRow` from within DI mode.

**Stack seen at runtime (DI expanded):**
1. DI's own `Capsule` 36×5 + `padding(.top, 8)` (from `DynamicIslandView.expandedContent`)
2. Module shell `dragHandle`: another `Capsule` 36×5 + `padding(.top, 8)` (from `ModuleShellView`)
3. Module shell `headerRow`: 44pt icon + title bar (from `ModuleShellView`)

### Files / Lines
| File | Lines | Relevant code |
|------|-------|---------------|
| `UtilityNotch/Shell/DynamicIslandView.swift` | 154–160 | DI renders its own capsule before `ActiveModuleContainerView` |
| `UtilityNotch/Shell/ModuleShellView.swift` | 63–65 | `dragHandle` + `headerRow` always rendered |
| `UtilityNotch/Shell/ModuleShellView.swift` | 73–76 | `showModuleSidebar` suppresses only the sidebar, nothing else |
| `UtilityNotch/Shell/ModuleShellView.swift` | 84–92 | `dragHandle` definition |
| `UtilityNotch/Shell/ModuleShellView.swift` | 101–129 | `headerRow` definition |

---

## Issue 3 — Dynamic Island Animation Origin

### Symptom
In DI mode the collapsed pill appears vertically centered in the panel window instead of at the top (notch position). When the panel opens, the pill animates in from the center of the screen rather than from the notch, making it look detached from the physical notch.

### Root Cause

**Panel window is full 380pt tall.** `NotchPanelController.swift` line 104 sizes `NSHostingView` to the full panel bounds:
```swift
hostingView.frame = panel.contentView?.bounds ?? .zero   // 620 × 380
hostingView.autoresizingMask = [.width, .height]
```

**SwiftUI centers content by default.** `DynamicIslandView` body uses a `ZStack(alignment: .top)` for its child layers, but the outermost `.frame` constrains the view to the collapsed size when collapsed (lines 66–69):
```swift
.frame(
    width:  isExpanded ? expandedWidth  : collapsedWidth,   // 180 when collapsed
    height: isExpanded ? expandedHeight : collapsedHeight   // 36 when collapsed
)
```

A 36pt-tall view placed inside a 380pt `NSHostingView` with SwiftUI's default `.center` alignment renders at:
```
vertical offset = (380 - 36) / 2 = 172pt from window top
```

The notch cutout is at the physical top of the screen, which corresponds to the top of the 380pt window. The pill appears 172pt below that — roughly in the middle of the window, not at the notch.

**Expand animation trigger** — `DynamicIslandView.swift` lines 101–113:
```swift
.onChange(of: appState.isPanelVisible) { _, visible in
    if visible {
        isExpanded = false          // start collapsed (pill at window center)
        showContent = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                isExpanded = true   // expand from window center, not notch
            }
        }
    }
}
```

Because the pill originates from window center (~172pt below notch), the spring morph from collapsed → expanded visually starts in empty space rather than appearing to emerge from the notch cutout.

### Files / Lines
| File | Lines | Relevant code |
|------|-------|---------------|
| `UtilityNotch/App/NotchPanelController.swift` | 104–105 | `hostingView.frame = panel.contentView?.bounds` — fills full 380pt |
| `UtilityNotch/Shell/DynamicIslandView.swift` | 20–21 | `ZStack(alignment: .top)` — body container |
| `UtilityNotch/Shell/DynamicIslandView.swift` | 66–69 | `.frame(width: collapsedWidth, height: collapsedHeight)` = 180×36 |
| `UtilityNotch/Shell/DynamicIslandView.swift` | 101–113 | Expand triggered after panel is already ordered front |

---

## Summary Table

| # | Issue | Root file | Root cause |
|---|-------|-----------|------------|
| 1 | Expanded panel Y mismatch | `NotchPanelController.swift:131` | Uses `visibleFrame.maxY` instead of `screenFrame.maxY` |
| 2 | Double header in DI | `DynamicIslandView.swift:154-160` + `ModuleShellView.swift:63-65` | DI renders its own capsule; no environment key suppresses ModuleShellView's `dragHandle`/`headerRow` |
| 3 | DI pill at window center | `NotchPanelController.swift:104` + `DynamicIslandView.swift:66-69` | NSHostingView is full 380pt; collapsed 36pt pill centers in it, placing it ~172pt below notch |
