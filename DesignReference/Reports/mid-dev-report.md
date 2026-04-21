# Mid-Development Design + Animation Audit
**UtilityNotch — Combined UI/UX Pro Max & Emotional Design Report**
Date: 2026-04-21
Scope: All modules, shell chrome, panel lifecycle, animation system

This report is written for an AI agent performing fixes. Each section is structured as:
**What is good** (preserve this), **What needs to change** (exact file, line context, instruction).
Issues are ranked by severity: `[CRITICAL]` `[HIGH]` `[MEDIUM]` `[LOW]`.

---

## Section 1 — Animation System

### What is good — preserve this

- **Spring physics on list interactions.** `TodoModuleView` uses `.spring(response: 0.35, dampingFraction: 0.74)` for add/delete and `.spring(response: 0.38, dampingFraction: 0.74)` for toggle. These feel physically correct. Do not change.
- **Panel close is faster than panel open.** `NotchPanelController.hidePanel` uses `duration * 0.8` — correct application of the exit-faster-than-enter rule. Do not change.
- **Sidebar module select spring.** `SidebarRailView` wraps `appState.selectModule` in `.spring(duration: 0.28, bounce: 0.16)`. Correct. Do not change.
- **Hover timing.** `SidebarButton`, `CircularControlButton`, `LiveTaskRowView` all use `.easeInOut(duration: 0.12–0.15)` for hover states. This is the one permitted exception to the spring rule. Correct. Do not change.
- **Asymmetric module insertion transition.** `ActiveModuleContainerView` uses `.opacity.combined(with: .offset(y: 4))` for insertion and `.opacity` for removal — giving directionality to entry without competing with removal. The concept is correct; only the curve and offset value need adjustment (see fixes below).
- **Waveform timer interval at 0.28s.** The cadence is correct for a musical breathing rhythm. Only the internal animation conflict needs fixing (see below).
- **Drag lift spring on Todo rows.** `.spring(response: 0.25, dampingFraction: 0.65)` on drag opacity. Correct.
- **Sidebar fade mask on scroll.** The `LinearGradient` mask at top/bottom of sidebar icon scroll is a polished detail. Do not change.

---

### Fixes required

#### `[CRITICAL]` No `accessibilityReduceMotion` check anywhere
**Files affected:** Every animated view in the app.
**Problem:** Users who enable Reduce Motion in macOS System Settings → Accessibility get the full animation stack including continuous `SoundWaveView` bar animations running indefinitely.
**Fix:** Add `@Environment(\.accessibilityReduceMotion) var reduceMotion` to any view that drives animation, and gate every `withAnimation` and continuous timer behind it.

Priority targets in order:
1. `SoundWaveView` — stop the timer entirely and show static mid-height bars when `reduceMotion == true`
2. `NotchPanelController.showPanel/hidePanel` — skip `NSAnimationContext` animation, set alpha directly
3. `ActiveModuleContainerView` — replace animated transition with `.animation(reduceMotion ? .none : ..., value:)`
4. `TodoModuleView` — gate all `.spring` animations on `withAnimation(reduceMotion ? .none : .spring(...))`
5. `SidebarRailView` — gate hover and module-select animations

Pattern to use in SwiftUI views:
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

// Replace:
.animation(.spring(response: 0.35, dampingFraction: 0.74), value: items)
// With:
.animation(reduceMotion ? .none : .spring(response: 0.35, dampingFraction: 0.74), value: items)
```

---

#### `[CRITICAL]` `SoundWaveView` — conflicting animation layers
**File:** `UtilityNotch/Modules/MusicControl/MusicControlView.swift`
**Location:** `SoundWaveView` struct, `body` and `startAnimating()`
**Problem:** Each bar has `.animation(.easeInOut(...).repeatForever(autoreverses: true), value: heights[i])` applied as a view modifier. Simultaneously, a `Timer` fires every 0.28s and calls `withAnimation { heights = randomHeights() }`. These two animation layers conflict: the `repeatForever` is already animating toward its current target when the timer forces a new target height. The bars stutter and fight between two animation sources.
**Fix:** Remove the `.animation(... .repeatForever ...)` modifier from each bar entirely. Keep the `Timer`. Apply a single `withAnimation(.easeInOut(duration: 0.25))` inside the timer callback only:

```swift
// In startAnimating():
animationTimer = Timer.scheduledTimer(withTimeInterval: 0.28, repeats: true) { _ in
    Task { @MainActor in
        withAnimation(.easeInOut(duration: 0.25)) {
            heights = randomHeights()
        }
    }
}

// On each Capsule in body — remove this entirely:
// .animation(isPlaying ? .easeInOut(...).repeatForever(...) : .easeOut(duration: 0.25), value: heights[i])
// Replace with nothing — the withAnimation wrapper in the timer drives all movement.
```

When `isPlaying` becomes false, call `stopAnimating()` and set heights to static mid-values inside a `withAnimation(.easeOut(duration: 0.25))`.

---

#### `[HIGH]` Inconsistent animation vocabulary — easeInOut where spring should be
**Problem:** The design system specifies spring physics for all user-facing interactions, `easeInOut(0.15)` for hover only. Multiple modules use `easeInOut` for selection/navigation actions.

**Fix each location:**

**`ActiveModuleContainerView.swift`** — line with `.animation(.easeInOut(duration: 0.22), value: appState.activeModuleID)`:
```swift
// Change to:
.animation(.spring(response: 0.28, dampingFraction: 0.72), value: appState.activeModuleID)
```
Also increase the insertion offset from `y: 4` to `y: 8` for perceptible directionality:
```swift
insertion: .opacity.combined(with: .offset(y: 8)),
```

**`CanonicalShellView.swift`** — header title and footer text crossfade animations (three instances of `.animation(.easeInOut(duration: 0.22), value: ...)`):
```swift
// Change all three to:
.animation(.spring(response: 0.28, dampingFraction: 0.72), value: appState.activeModuleID)
.animation(.spring(response: 0.28, dampingFraction: 0.72), value: appState.moduleActionButtonRevision)
.animation(.spring(response: 0.28, dampingFraction: 0.72), value: appState.moduleFooterLeft)
// etc.
```

**`CalendarView.swift`** — `shiftDay` function:
```swift
// Change:
withAnimation(.easeInOut(duration: 0.18)) { selectedDate = d }
// To:
withAnimation(.spring(response: 0.25, dampingFraction: 0.72)) { selectedDate = d }
```

**`CalendarView.swift`** — week strip button:
```swift
// Change:
Button { withAnimation(.spring(response: 0.25)) { selectedDate = day } }
// To (add damping):
Button { withAnimation(.spring(response: 0.25, dampingFraction: 0.72)) { selectedDate = day } }
```

**`FileConverterView.swift`** — format pill selection:
```swift
// Change:
withAnimation(.easeOut(duration: 0.12)) { selection.wrappedValue = fmt }
// To:
withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) { selection.wrappedValue = fmt }
```

**`MusicControlView.swift`** — `nextTrack()` and `previousTrack()`:
```swift
// Change both:
withAnimation(.easeInOut(duration: 0.2)) { ... }
// To:
withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) { ... }
```

**`SidebarRailView.swift`** — `SidebarDropDelegate.dropEntered`:
```swift
// Change:
withAnimation(.easeInOut(duration: 0.15)) { ... }
// To:
withAnimation(.spring(response: 0.25, dampingFraction: 0.70)) { ... }
```

---

#### `[HIGH]` Panel open/close missing scale — the app's most important first impression
**File:** `UtilityNotch/App/NotchPanelController.swift`
**Location:** `showPanel()` and `hidePanel()`
**Problem:** The panel reveals with a pure alpha fade (`panel.animator().alphaValue`). No scale, no positional bloom. This is a flat, clinical appearance for the single most-seen animation in the app.
**Fix:** Add a `CABasicAnimation` on the panel's layer transform alongside the existing alpha animation. On open: scale 0.96→1.0. On close: scale 1.0→0.97.

```swift
// In showPanel(), after setting alphaValue = 0:
let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
scaleAnim.fromValue = 0.96
scaleAnim.toValue = 1.0
scaleAnim.duration = UNConstants.animationDuration
scaleAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
scaleAnim.fillMode = .forwards
scaleAnim.isRemovedOnCompletion = false
panel.contentView?.layer?.add(scaleAnim, forKey: "panelOpen")

// In hidePanel(), inside NSAnimationContext.runAnimationGroup:
let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
scaleAnim.fromValue = 1.0
scaleAnim.toValue = 0.97
scaleAnim.duration = UNConstants.animationDuration * 0.8
scaleAnim.timingFunction = CAMediaTimingFunction(name: .easeIn)
panel.contentView?.layer?.add(scaleAnim, forKey: "panelClose")
```

---

#### `[HIGH]` Task completion has no spring bounce — the app's peak dopamine moment is flat
**File:** `UtilityNotch/Modules/TodoList/TodoModuleView.swift`
**Location:** `LiveTaskRowView`, the done-circle `ZStack` inside `Button(action: onToggle)`
**Problem:** When a task is marked done, the green circle fills instantly. No physics, no spring pop. The highest-value interaction in the app has the flattest animation.
**Fix:** Add a `@State private var completionScale: CGFloat = 1.0` to `LiveTaskRowView`. Apply `.scaleEffect(completionScale)` to the done-circle `ZStack`. Trigger the animation in an `.onChange(of: item.isDone)` handler:

```swift
@State private var completionScale: CGFloat = 1.0

// On the done-circle ZStack:
ZStack {
    Circle().fill(Color(hex: "32D74B")).frame(width: 20, height: 20)
    Image(systemName: "checkmark")
        .font(.system(size: 9, weight: .bold))
        .foregroundStyle(Color.white)
}
.scaleEffect(completionScale)
.onChange(of: item.isDone) { _, isDone in
    guard isDone else { return }
    completionScale = 1.0
    withAnimation(.spring(response: 0.22, dampingFraction: 0.52)) {
        completionScale = 1.22
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.17) {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
            completionScale = 1.0
        }
    }
}
```

---

#### `[HIGH]` `SoundWaveView` must stop when not active
**File:** `UtilityNotch/Modules/MusicControl/MusicControlView.swift`
**Problem:** The waveform timer runs whenever the view is mounted. If `MusicModuleView` stays in the SwiftUI view hierarchy while another module is active, the timer continues firing every 0.28s invisibly, consuming CPU and battery.
**Fix:** This is already partially handled by `.onDisappear { animationTimer?.invalidate() }`. Verify that `MusicModuleView` is not kept alive in the background. If the module view is retained (lazy caching), add a check in the timer callback: guard the update behind an `isVisible` flag set by `onAppear`/`onDisappear`.

---

#### `[MEDIUM]` Calendar `EventRow` hover has no animation — instant background snap
**File:** `UtilityNotch/Modules/Calendar/CalendarView.swift`
**Location:** `EventRow.body`, `.onHover { isHovering = $0 }`
**Problem:** Every other hover state in the app uses `withAnimation(.easeInOut(duration: 0.12-0.15))`. `EventRow` snaps instantly, breaking consistency.
**Fix:**
```swift
// Change:
.onHover { isHovering = $0 }
// To:
.onHover { h in withAnimation(.easeInOut(duration: 0.12)) { isHovering = h } }
```

---

#### `[MEDIUM]` Sidebar tooltip transition has no explicit animation wrapper
**File:** `UtilityNotch/Shell/SidebarRailView.swift`
**Location:** `SidebarButton.body`, tooltip `.overlay` block
**Problem:** The tooltip appears inside `if showTooltip { ... }` with `.transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .trailing)))`. The `showTooltip = true` assignment inside `MainActor.run` has no `withAnimation` wrapper. The transition may fire without an animation context, causing an instant snap.
**Fix:**
```swift
// Change:
await MainActor.run { showTooltip = true }
// To:
await MainActor.run {
    withAnimation(.easeOut(duration: 0.12)) { showTooltip = true }
}
// And on dismiss (in the else branch of onHover):
withAnimation(.easeIn(duration: 0.08)) { showTooltip = false }
```

---

#### `[MEDIUM]` Music progress bar visible tick every 1 second
**File:** `UtilityNotch/Modules/MusicControl/MusicControlView.swift`
**Location:** `startProgressSimulation()` timer and progress bar `GeometryReader`
**Problem:** The timer fires every 1.0s with a full second's step, and the bar has `.animation(.linear(duration: 0.5), value: progress)`. The 0.5s animation can't smooth a 1s gap — users see a visible lurch every second.
**Fix:** Reduce the timer interval to 0.1s and the step size proportionally:
```swift
// Change:
simulatedPlayTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
    ...
    let step = 1.0 / currentTrack.duration
    progress = min(1.0, progress + step)
// To:
simulatedPlayTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
    ...
    let step = 0.1 / currentTrack.duration
    progress = min(1.0, progress + step)
```
With 10 updates per second, the `.animation(.linear(duration: 0.5))` on the bar can be removed entirely — continuous small steps look smooth without it.

---

#### `[MEDIUM]` Dummy Todo rows are double-dimmed — opacity below threshold
**File:** `UtilityNotch/Modules/TodoList/TodoModuleView.swift`
**Location:** `dummyRow()` function, final `.opacity(0.5)` modifier
**Problem:** The entire dummy row has `.opacity(0.5)` applied. Inside the row, done-state text already uses `Color.white.opacity(0.3)`. Multiplied: 0.3 × 0.5 = 0.15 effective opacity — invisible on a dark background. Undone primary text lands at 0.85 × 0.5 = 0.425, which is below the 0.5 minimum for legible secondary text.
**Fix:** Remove the blanket `.opacity(0.5)` from `dummyRow`. Instead, reduce all individual color values inside `dummyRow` by roughly 50% to achieve the same "faded placeholder" effect while maintaining internal opacity hierarchy:
```swift
// In dummyRow, change text opacity values:
// Undone text: Color.white.opacity(0.85) → Color.white.opacity(0.45)
// Done text: Color.white.opacity(0.3) → Color.white.opacity(0.20)
// Timestamp: Color.white.opacity(0.35) → Color.white.opacity(0.20)
// Remove: .opacity(0.5) at the row level
```

---

#### `[LOW]` Module switch has no directional memory
**File:** `UtilityNotch/Shell/ActiveModuleContainerView.swift`
**Problem:** Module insertion always animates from `y: +8` (below) regardless of whether the user tapped a module above or below the current one in the sidebar. Per the hierarchy-motion rule, direction should encode the user's navigation direction.
**Fix:** Pass the navigation direction as a parameter. In `AppState`, track the previous and current module index. If the new index is higher (further down the sidebar), enter from below (+8); if lower (further up), enter from above (-8). This requires knowing the module order, which is available via `appState.enabledModuleIDs`.

This is a `[LOW]` item — implement after all `[HIGH]` fixes are complete.

---

#### `[LOW]` No stagger on list item entrance
**File:** `UtilityNotch/Modules/TodoList/TodoModuleView.swift`
**Problem:** When the todo list first renders, all items appear simultaneously. Per the stagger-sequence rule, items should entrance with a 30-50ms offset per item.
**Fix:** Add `.animation(.spring(response: 0.35, dampingFraction: 0.74).delay(Double(index) * 0.04), value: appState.todoItems.count)` to each item in the `ForEach`. Cap the stagger at 5 items max (index beyond 5 gets the same delay as item 5) to avoid slow renders on large lists.

---

## Section 2 — UI Structure & Layout

### What is good — preserve this

- **Shell chrome separation.** `CanonicalShellView` correctly places `SidebarRailView` on the right with `maxWidth: .infinity` for the content VStack. The sidebar left-border overlay is the single permitted structural divider.
- **Content padding.** `contentSlot` applies `.padding(.horizontal, 16).padding(.vertical, 8)` consistently across all modules. Do not change.
- **Panel background.** True black `Color.black` with `panelGlowOpacity` ambient blue — correct per DESIGN.md §3.
- **Typography hierarchy.** SF Pro Semibold 16pt for header, SF Mono 10pt uppercase for footer, 14pt regular for body. Correct throughout.
- **State colors.** Amber error (`FF9F0A`), green success (`34C759`), blue focus (`0A84FF`) — all consistent with DESIGN.md §6.
- **No horizontal dividers inside content.** All modules correctly use background opacity shifts rather than lines for separation.
- **Sidebar fade mask.** The `LinearGradient` mask on the sidebar scroll zone (clear → black → black → clear) is polished and correct.
- **Music album art color palette.** The deterministic 6-gradient palette keyed on track ID hash in `UNConstants.musicArtPalette` is smart and visually rich.
- **Calendar relative time badge.** The `"in 2h"` / `"now"` badge on `EventRow` using accent color at 0.2 opacity background is a strong, contextually useful detail.
- **File Converter drop zone.** The dashed-to-solid stroke transition on drag-target with icon swap (`arrow.down.doc` → `arrow.down.circle.fill`) is a correct and clear affordance.

---

### Fixes required

#### `[HIGH]` Duplicate module title inside Calendar and File Converter content areas
**Files:**
- `UtilityNotch/Modules/Calendar/CalendarView.swift` — `Label("Calendar", systemImage: "calendar")` at the top of `body`
- `UtilityNotch/Modules/FileConverter/FileConverterView.swift` — `Label("File Converter", systemImage: "doc.badge.gearshape")` at the top of `body`

**Problem:** The shell header already displays the module title via `CanonicalShellView`. These internal `Label` headers create double-titles, waste 26pt of the 266pt content canvas height, and create a visual hierarchy conflict (two competing headings).
**Fix:** Delete the `HStack { Label(...) Spacer() }.padding(.bottom, 16)` header blocks from both files entirely. Verify the content below it reflows correctly within the available height.

---

#### `[HIGH]` Touch targets below 44pt minimum
**Files and elements:**

| File | Element | Current size | Fix |
|---|---|---|---|
| `CalendarView.swift` | Day navigation chevron buttons | 26×26pt frame | Change `.frame(width: 26, height: 26)` to `.frame(width: 44, height: 44)` on the button, keep icon size at 12pt |
| `FileConverterView.swift` | Format pills | ~26pt height | Add `.frame(minHeight: 36)` to each pill; this is a cursor-driven app so 36pt is acceptable floor |
| `FileConverterView.swift` | Clear file button (`xmark.circle.fill`) | Caption icon, no hit area | Wrap in `.frame(width: 28, height: 28)` or add `.contentShape(Circle().scale(2.0))` |
| `SidebarRailView.swift` | Sidebar icon buttons | 32×32pt | Add `.contentShape(Rectangle().size(width: 44, height: 44))` to expand hit area without changing visual size |

---

#### `[HIGH]` Missing `accessibilityLabel` on icon-only interactive elements
**Files and elements:**

| File | Element | Fix |
|---|---|---|
| `MusicControlView.swift` | `CircularControlButton` (play, pause, prev, next) | Add `.accessibilityLabel("Play")`, `.accessibilityLabel("Pause")`, `.accessibilityLabel("Previous track")`, `.accessibilityLabel("Next track")` to each button instance |
| `SidebarRailView.swift` | `SidebarGearButton` | Add `.accessibilityLabel("Settings")` to `SettingsLink` |
| `FileConverterView.swift` | Clear file button | Add `.accessibilityLabel("Remove file")` |
| `TodoModuleView.swift` | Delete button (trash icon) | Add `.accessibilityLabel("Delete task")` |
| `TodoModuleView.swift` | Edit button (pencil icon) | Add `.accessibilityLabel("Edit task")` |

---

#### `[MEDIUM]` File Converter success state is visually undersized for a flow-ending moment
**File:** `UtilityNotch/Modules/FileConverter/FileConverterView.swift`
**Location:** `if case .done(let message) = conversionStatus` block
**Problem:** A 2pt vertical offset transition on a caption-size checkmark is imperceptible. The conversion is the climax of this module's user journey.
**Fix:** Increase the offset to 8pt and use a spring. Additionally, apply a brief success-tint flash to the convert button background at the moment of completion:

```swift
// Change transition on success HStack:
.transition(.opacity.combined(with: .offset(y: 2)))
// To:
.transition(.asymmetric(
    insertion: .opacity.combined(with: .offset(y: 8)),
    removal: .opacity
))

// Wrap the conversionStatus assignment in mockConvert with animation:
withAnimation(.spring(response: 0.3, dampingFraction: 0.68)) {
    self.conversionStatus = .done(...)
}
```

---

#### `[MEDIUM]` Press feedback absent on all tappable rows and interactive cards
**Files:** `TodoModuleView.swift` (`LiveTaskRowView`), `CalendarView.swift` (`EventRow`)
**Problem:** Rows respond to hover (opacity background) but have no press-state scale feedback. Tapping a todo row has zero immediate visual response — the state change (done/undone + re-sort) is the only feedback, and on fast machines this can be imperceptible.
**Fix for `LiveTaskRowView`:** Add `@State private var isPressed = false`. Apply `.scaleEffect(isPressed ? 0.98 : 1.0)` with `.animation(.spring(response: 0.18, dampingFraction: 0.7), value: isPressed)`. Use a `DragGesture(minimumDistance: 0)` with `onChanged` (set `isPressed = true`) and `onEnded` (set `isPressed = false`, then call `onToggle()`). Remove the current `.onTapGesture`.

**Fix for `EventRow`:** Same pattern — `.scaleEffect(isPressed ? 0.98 : 1.0)` on the row container. This is especially valuable here since `EventRow` currently has no tap action (hovering only) — it should open the event in Calendar app on click, with press feedback signalling the action is registered.

---

#### `[MEDIUM]` Copy rule violations — all-caps content strings in production UI
**File:** `UtilityNotch/Modules/TodoList/TodoModuleView.swift`
**Location:** `makeAddActionButton(icon: "plus", label: "ADD TASK")` in the action button
**Problem:** DESIGN.md §7 explicitly states: "all-caps prohibited in production UI." The action button renders "ADD TASK" in uppercase via the `makeAddActionButton` helper.
**Note:** Footer text is exempt (SF Mono metadata). The action button pill is not footer text.
**Fix:** Change `label: "ADD TASK"` to `label: "Add Task"` in `TodoModuleView`.
Also audit other modules for `makeAddActionButton` / `makeDestructiveActionButton` calls using all-caps labels and update them to sentence/title case.

---

#### `[LOW]` Calendar `CalendarView` internal header duplicates design pattern
**File:** `UtilityNotch/Modules/Calendar/CalendarView.swift`
**Problem:** Beyond the duplicate title (addressed above), the `dayHeader` component uses a 28pt bold rounded font for the day number (`dayNumberString`). This is visually strong and intentional. However, the surrounding `HStack` chevron buttons are 26×26pt — fix those hit areas as noted in the touch target section above, and ensure the day number remains centered when the button frames expand.

---

## Section 3 — Emotional Design & Reward Architecture

### What is good — preserve this

- **Ethical reward model.** No streaks, no push-notification anxiety loops, no social comparison. The app is purely progress-first (The Self reward type). This is intentional and correct.
- **Deterministic album art palette.** Tracks always show the same gradient, creating visual familiarity with frequently played songs. Keep.
- **Music waveform concept.** The animated waveform is the one genuinely living, ambient element in the app. The concept is correct; only the implementation needs fixing (see Section 1).
- **Relative time badges on calendar events.** `"in 2h"` and `"now"` badges are a strong contextual hook that creates useful urgency without anxiety.
- **Hover-driven action reveal in TodoList.** Showing pencil/trash/handle only on hover is clean. It rewards exploration without cluttering the passive state.

---

### Fixes required

#### `[HIGH]` No peak moment anywhere — task completion is the app's highest-value dopamine trigger and is currently flat
See Section 1 — task completion spring bounce fix. The checkmark circle filling green with no spring is the single largest emotional design gap in the app. After applying the scale animation fix from Section 1, the peak moment will exist.

#### `[MEDIUM]` File Converter has no satisfying ending
See Section 2 — success state fix. The conversion flow climax should feel conclusive. After applying that fix, the peak-end loop is closed for this module.

#### `[MEDIUM]` No spatial memory in module navigation
See Section 1 — directional module switch fix `[LOW]`. When a user navigates between modules, the content should reflect which direction they moved. This creates a spatial mental model — modules feel like places the user navigates through, not random swaps.

#### `[LOW]` Empty state in `ActiveModuleContainerView` is too sparse
**File:** `UtilityNotch/Shell/ActiveModuleContainerView.swift`
**Location:** `placeholder` computed property
**Problem:** `"No utility selected"` with a dashed square icon is a developer-facing message. Per DESIGN.md §6 copy rules, empty states should address the user.
**Fix:**
```swift
private var placeholder: some View {
    VStack(spacing: 8) {
        Image(systemName: "square.grid.2x2")
            .font(.system(size: 24, weight: .light))
            .foregroundStyle(.quaternary)
        Text("select a module")
            .font(.system(size: 13))
            .foregroundStyle(.tertiary)
    }
}
```
Lowercase, no exclamation, addresses the user's next action.

---

## Section 4 — Priority Order for an AI Agent

Execute fixes in this order. Later items may depend on earlier ones.

| Order | Severity | Fix | File(s) |
|---|---|---|---|
| 1 | CRITICAL | Add `accessibilityReduceMotion` gating to all animated views | All view files |
| 2 | CRITICAL | Fix `SoundWaveView` conflicting animation layers | `MusicControlView.swift` |
| 3 | HIGH | Add scale transform to panel open/close | `NotchPanelController.swift` |
| 4 | HIGH | Task completion spring bounce on checkmark circle | `TodoModuleView.swift` |
| 5 | HIGH | Replace `easeInOut` with springs across all modules | See table in Section 1 |
| 6 | HIGH | Delete duplicate in-content module titles (Calendar, FileConverter) | `CalendarView.swift`, `FileConverterView.swift` |
| 7 | HIGH | Add `accessibilityLabel` to all icon-only buttons | Multiple files |
| 8 | HIGH | Fix touch targets for chevrons, pills, clear button | `CalendarView.swift`, `FileConverterView.swift` |
| 9 | MEDIUM | Fix `EventRow` hover animation (add `withAnimation`) | `CalendarView.swift` |
| 10 | MEDIUM | Fix sidebar tooltip `withAnimation` wrapper | `SidebarRailView.swift` |
| 11 | MEDIUM | Smooth music progress bar (0.1s timer interval) | `MusicControlView.swift` |
| 12 | MEDIUM | Fix double-dimmed dummy Todo rows | `TodoModuleView.swift` |
| 13 | MEDIUM | Upgrade File Converter success state animation | `FileConverterView.swift` |
| 14 | MEDIUM | Add press scale feedback to Todo rows | `TodoModuleView.swift` |
| 15 | MEDIUM | Fix "ADD TASK" copy to title case | `TodoModuleView.swift` |
| 16 | LOW | Directional module switch (track navigation direction) | `ActiveModuleContainerView.swift`, `AppState.swift` |
| 17 | LOW | List item entrance stagger on Todo | `TodoModuleView.swift` |
| 18 | LOW | Fix empty state copy in `ActiveModuleContainerView` | `ActiveModuleContainerView.swift` |

---

## Section 5 — Do Not Change

These are intentional design decisions that should not be modified:

- `UNConstants.animationDuration = 0.28` — correct spring response base
- `UNConstants.hoverOpenDelay = 0.3` — intentional friction against accidental panel triggers
- Panel close at `duration * 0.8` — correct exit-faster-than-enter implementation
- Sidebar on the right at 48pt — non-negotiable per DESIGN.md
- No horizontal divider lines inside content — non-negotiable per DESIGN.md
- Amber error color, not red — intentional, per DESIGN.md §6
- SF Mono for footer text — intentional design language, not a consistency error
- `DismissalLock` OptionSet system — correct, do not simplify to booleans
- `@Observable` + `@Environment(AppState.self)` pattern — do not revert to `ObservableObject`
- `withAnimation` on `appState.selectModule` calls in module views — correct, matches shell animation
