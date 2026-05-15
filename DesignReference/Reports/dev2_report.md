# UtilityNotch — Dev 2 Emotional Design Audit
**Date:** 2026-05-07  
**Scope:** Full shell chrome, all 7 active modules, animation system, typography, negative space, copy voice  
**Method:** Full source review (all `.swift` files, `Constants.swift`, `DESIGN.md`, `CanonicalShellView`, each module view) + cross-reference against emotional design frameworks  
**Prior report:** `mid-dev-report.md` (2026-04-21) — issues from that report that remain open are flagged below with `[CARRIED FORWARD]`

Issues are ranked: `[CRITICAL]` `[HIGH]` `[MEDIUM]` `[LOW]`

---

## Affective Audit

### Visceral Level — First-Impression Sensory Impact

The visceral identity is defined and intentional. The "Glass Monolith" concept — pure black panel, radial blue glow at top-left, ultraThinMaterial blur, white opacity hierarchy, single structural divider — creates a coherent premium HUD aesthetic that reads as both native macOS and categorically distinct from it.

**What works viscerally:**
- The panel-from-notch morphing animation (spring 0.38 / 0.78) is the app's single most impressive moment. The concave inverted-corner clip shape (10pt `invertedCornerRadius`) against the notch pill is technically and visually exceptional.
- The 3D wheel carousel in Music Control (perspective 0.35, 28% scale reduction per slot, 55% opacity fade) is the only true show-piece interaction in the app. It signals that this product takes craft seriously.
- The sidebar fade mask (LinearGradient at top/bottom of icon scroll) is a quiet premium detail that would be invisible if absent but is definitely felt.
- The ambient blue glow (`radialGradient` from `topLeading`) prevents the black surface from reading as dead. This is correctly implemented.

**Visceral weaknesses:**
1. **Collapsed pill is anonymizing.** The idle state shows "Utility Notch" in white 65% opacity beside a generic `rectangle.expand.vertical` glyph. This is a missed identity moment that repeats indefinitely. The pill is the only thing users see between interactions — it should signal something alive.
2. **Calendar module's 52pt/Black day number** creates a typographic step-change the system wasn't designed to accommodate. Everywhere else in the app, the largest type is 17pt (music track title). The 52pt weight reads as intrusive — it fits a standalone clock app, not a utility panel where it competes with the shell header's 16pt title for dominance.
3. **Files Tray drop zone uses `height: 208`** — this hard-codes the zone to 208pt in a 266pt available canvas, leaving 58pt of bare content-slot floor below the grid. On an otherwise tightly composed panel, this unused space reads as a layout error.
4. **Sound wave animation conflict still present.** `MusicWaveView` runs a `Timer` at 0.13s interval and wraps updates in `withAnimation(.easeInOut(duration: 0.11))`. The mid-dev report correctly identified this as a conflict; the current code is the post-fix version and appears to be correctly implemented (timer only, no `repeatForever` modifier on bars). This is resolved — mark as closed.

**Weakest visceral link:** The collapsed pill. It is the face of the app in ambient use and it says almost nothing.

---

### Behavioral Level — Empowerment and Feedback Loops

The interaction vocabulary is largely correct and consistent. Spring physics govern user-initiated actions. Hover states use easeInOut(0.12–0.15) exclusively. Dismissal locks are correctly implemented across drag sessions, text input, and picker states. The shell never reconstructs during module switches — only the content slot updates.

**What works behaviorally:**
- **Todo drag-to-reorder** is the most behaviorally complete interaction in the app. The blue capsule drop indicator, ghost border on the dragged row, opacity dimming (0.62), scale reduction (0.985), spring reordering, and cleanup path are all correct.
- **Hover-reveal actions** (edit/delete/drag-handle) in Todo and Quick Notes follow a consistent pattern that respects the HUD aesthetic without always-visible clutter.
- **Clipboard flash feedback** (white 8% for 150ms) exists but registers below the cognitive perception threshold — the minimum for a visual flash to be consciously noticed is approximately 200–250ms.
- **Calendar week navigation** (±7 days per chevron tap) is a correct pattern for a week-strip UI, but there is no month-level navigation. Users who want to look ahead more than a week have no path.

**Behavioral weaknesses:**
1. **Keyboard navigation is absent.** There is no tab-through between modules, no arrow-key navigation within lists, no keyboard shortcut to dismiss the popup in Quick Notes (Escape would be expected). This is a significant accessibility and power-user gap.
2. **The copy-flash duration (150ms) is below the perceptual threshold.** It fires but users may not register it. The `easeOut(duration: 0.05)` fade-in is particularly too fast.
3. **Todo task completion has no peak micro-moment.** The checkmark fill + strikethrough transition is functionally correct but emotionally flat. There is no micro-celebration at the moment of completion — the single most important emotional moment in a productivity tool.
4. **Clipboard polling (1s Timer)** is a functional approach but means there is always up to a 1-second lag between a clipboard event and the module reflecting it. On macOS, `NSPasteboard.general.changeCount` can be observed more responsively via `NSPasteboard` `didChange` notifications.
5. **Quick Notes note body in the popup uses a raw `TextEditor`** with a `scrollContentBackground(.hidden)` fix. The TextEditor's height is `minHeight: 72` but there is no `maxHeight` cap — on long content it will expand and push the button row off-screen inside the popup.
6. **Module switch uses `easeInOut(0.22)`** in `ActiveModuleContainerView`, where the design system specifies spring physics for all user-facing interactions. This is the one place the spring rule is systematically violated at the shell level.

**Weakest behavioral link:** Keyboard navigation absence and the flat todo completion moment.

---

### Reflective Level — Identity Extension

The "Glass Monolith / Ethereal Utility" positioning is clearly defined. The app is for users who want utility without clutter — a developer/designer aesthetic that values quiet precision over expressive personality.

**What works reflectively:**
- The "Calm Expert" voice is consistently implemented in footer strings: `NOW PLAYING`, `SAVED LOCALLY`, `CLIPBOARD SYNC ACTIVE`. These read as system metadata, not copy.
- The design system correctly uses amber for errors (never red), which signals calm competence over alarm.
- The music module's deterministic gradient palette for unknown album art is a thoughtful detail — it means the module never looks broken, only anonymous.

**Reflective weaknesses:**
1. **`DEMO` badges on Clipboard dummy items break the calm expert identity.** Per `DESIGN.md §7`, "placeholder copy is wireframe scaffolding — it must never appear in a production build." The DEMO capsule badge directly violates this rule and signals to users that they are looking at something unfinished.
2. **Footer voice inconsistency.** Footer-left strings vary between descriptive state (`PERMISSION REQUIRED`, `NOW PLAYING`), instructional (`DROP TO ADD`), and contextual label (`SAVED LOCALLY`). This inconsistency prevents users from building a mental model of what the footer zone represents.
3. **Empty state quality varies widely across modules.** Music has an excellent empty state (icon + semantic copy + context about supported apps). Todo/QuickNotes/Clipboard use dummy data at 50–60% opacity as implicit empty states — this is visually adequate but emotionally doesn't address the user, it just shows them an example. Files Tray has the best dummy state (4-column grid, full visual demo) but the inline opacity-fade approach doesn't distinguish "empty state" from "real content in bad light."

---

## Heuristic Recommendations

### Peak-End Rule

**The peak moment** — the highest-value delivery point — differs by module:
- **Todo:** The moment a task is checked done. Currently: green circle fill + strikethrough. This is the right visual vocabulary but it needs a micro-beat (see Priority Actions #1).
- **Music:** The album art carousel slide. Already strong. The one place where the app feels genuinely premium.
- **Files Tray:** The file drop acceptance. Currently: border opacity increases (0.15→0.35) and dash thickens (1→1.5pt). This is too subtle for a high-value moment.
- **Calendar:** No clear peak. The module is primarily read-only.
- **Quick Notes / Clipboard:** The confirmation flash on save/copy. Currently below perceptual threshold.

**The ending** — the panel auto-closes after 8s inactivity (`defaultInactivityTimeout = 8.0`). This is a completely abrupt ending. There is no summary, no acknowledgment. The app disappears. For a productivity tool that handles tasks, notes, and clipboard — the closing moment is a missed reinforcement opportunity.

**Recommendation:** Add a 0.3s gentle content fade-out before the panel collapses. Add a subtle "session summary" label to the DI collapsed pill after an active session (e.g., "3 tasks done" for 500ms, then fades). This costs nothing architecturally and closes every session with positive reinforcement.

### Halo Effect

The current hero element is **the panel-from-notch morphing animation**. It is excellent and performs its role correctly — users who see the first expand/collapse are primed for quality. 

The risk: the halo fades after 3 days of use, and what remains is the behavioral layer. The behavioral layer's weakest point is the flat todo completion moment (no peak celebration) and the 1-second clipboard lag. These will erode the trust established by the opening animation.

**Recommendation:** The second hero element should be the todo completion micro-animation. It is touched daily by the target user and should be the second thing that makes users think "this is thoughtful."

### Friction Paradox

The app has essentially zero intentional friction. This is mostly correct for a utility tool. The one case where friction was implemented correctly is the **Clear All confirm pattern** in Clipboard History (2-second confirm window). This is a good application of the paradox for a destructive action.

**Under-friction area:** File removal in Files Tray uses a hover `×` button with no confirmation. For a file manager (even a tray), removing a file feels destructive enough to warrant a 1.5s confirm window similar to Clipboard's clear pattern.

**Over-friction area:** Calendar permission request has no call-to-action. When `authStatus != .fullAccess`, the footer shows `PERMISSION REQUIRED` / `DEMO DATA` — but there is no button to request permission. The user must know to go to System Settings themselves. This is unnecessary friction that blocks the module's core value.

---

## Engagement Design

### Reward Loop Analysis

**The Hunt (discovery reward):** Absent. The app delivers utility on demand but never surprises the user with new information, insights, or suggestions. A missed opportunity: if a clipboard item contains a URL, suggest opening it. If the todo list has 5+ overdue items, subtly surface it in the collapsed pill.

**The Self (mastery reward):** Partially present. The Todo footer shows completed count and remaining count — this is a mastery signal. The Calendar shows upcoming event count. The Clipboard shows items stored count. These are functional counters but not emotionally framed as achievements.

**The Tribe (social reward):** Not applicable. Utility tool — solo use. Correct omission.

### Ethical Assessment

There are no dopamine traps, anxiety-inducing streaks, or vulnerability-window notifications in the current design. The inactivity auto-close (8s) could theoretically create mild anxiety if users feel their data is unstable, but all data is persisted locally so this is a non-issue functionally. The design is ethically clean.

**One note:** The `musicPlayingTint` color (emerald green, rgba 0.8 opacity) on the footer status dot when music is playing is the most vivid ongoing signal in the app. It is correctly used as a live indicator, not as a notification or urgency signal.

---

## Visual & Linguistic Strategy

### Tone of Voice Analysis

**Current profile:**
- Warmth: 2/10 (machine metadata, not human)
- Energy: 1/10 (calm to the point of silent)

The Calm Expert voice is well-executed in the footer strings. The problem is that this same machine-metadata register is used everywhere, including in places that should address the user as a person (empty states, error states).

**Target profile:**
- Footer strings: Warmth 1/10, Energy 1/10 — correct as-is. These are system readouts.
- Empty states and instructional copy: Warmth 5/10, Energy 2/10 — should be slightly warmer without losing the expert register.

**Current copy rewrites needed:**

| Location | Current | Target | Why |
|---|---|---|---|
| Clipboard DEMO badge | `DEMO` (capsule badge) | Remove entirely, replace with inline dim opacity | Violates Calm Expert. Machine scaffolding in production |
| Files Tray footer-right | `DROP TO ADD` | `DRAG FILES IN` or remove | Instructional = novice register. Descriptive = expert |
| Music empty state secondary | `Start playback in Spotify, Apple Music, or any media app — it will appear here automatically.` | Keep exactly as-is | Best copy in the app |
| Calendar permission state | No action CTA | Add a plain-text link button: `Grant access` (SF Pro 12pt, white 50%) | Missing escalation path |
| Todo empty dummy items | 50% opacity dummy rows | Lower to 40% opacity + add hairline bottom label "your tasks appear here" | Makes the dummy/real distinction clearer |

**Micro-interaction Rhythm:**

| Moment | Current | Assessment | Target |
|---|---|---|---|
| Entry (panel expand) | spring(0.38, 0.78) shape first → easeIn(0.12) content fade after 380ms | Excellent. Do not change | Keep |
| Module switch | easeInOut(0.22) with opacity + y:4 offset | Spring should replace easeInOut | spring(0.28, 0.72) |
| Task completion | Fill + strikethrough, spring reorder | Missing peak beat | Add scale(1.12)→scale(1.0) spring pulse on the checkmark circle at completion |
| Note/clipboard copy | 150ms opacity flash | Below perceptual threshold | Extend to 250ms, use spring(0.20, 0.80) for fade-in |
| Panel collapse | showContent easeOut(0.10) → spring(0.34, 0.86) shape collapse | Good. Exit faster than entry. Keep | Keep |
| File drop accepted | Border opacity/dash change | Too subtle for a high-value moment | Add brief scale(1.02)→scale(1.0) spring on the drop zone container |

### Color Journey Map

| Phase | Current | Assessment | Gap |
|---|---|---|---|
| Collapsed pill (ambient) | White 65% text, generic icon | Flat — no context or warmth | Add module-specific color signal (e.g., music note in emerald, calendar date in blue) |
| Panel open (entry) | Radial blue glow, black glass | Excellent — trust, focus, premium | Keep |
| Core module use | White opacity hierarchy on black | Correct — focus state | Keep |
| Active/selected state | White 8% fill + #0A84FF icon | Correct | Keep |
| Task completion / success | iOS green #32D74B fill | Good — growth, done | Missing: a brief scale pulse |
| Error/amber state | `rgba(255,159,10,0.10)` fill + `rgba(255,159,10,0.25)` border | Correct per spec | Keep |
| Panel collapse | Abrupt content fade + shape collapse | Missing: a closing note | Add 0.3s content-level fade before collapse |

---

## Measurement & Optimization

### GEW 2.0 Emotion Mapping

| Screen / Flow | Current Quadrant | Target Quadrant | Design Change |
|---|---|---|---|
| First open (panel expand) | I (High control / Positive — awe) | I (amplify) | Already excellent. Protect this animation at all costs |
| Idle collapsed pill | IV (Low control / Positive — mild interest) | I (Low-medium control / Positive — anticipation) | Show module-specific ambient signal in collapsed pill |
| Todo task completion | IV (Low / Positive — satisfaction) | I (High / Positive — pride) | Add micro-celebration pulse on checkmark circle |
| Empty module first view | III→IV (uncertain, mild discomfort at blank state) | IV (Low / Positive — invitation) | Improve dummy-data-to-empty-state communication |
| Clipboard DEMO badge | II (High / Negative — contempt at scaffolding) | Remove | Delete DEMO badge entirely |
| Calendar permission state | III (Low / Negative — helplessness) | IV (Low / Positive — agency) | Add inline "Grant access" CTA |
| Panel auto-close | II (mild — abrupt, no closure) | IV (relief + closure) | Add content fade + session summary in pill |
| Music with no source | IV (Low / Positive — interest, good copy) | I (amplify) | Keep copy, add a tiny pulsing dot indicator when a source is detected |

### A/B Testing Hypotheses

```
Hypothesis: [Adding a scale pulse on todo checkmark completion] will shift users from
            flat satisfaction (Q4) to active pride (Q1)
Metric:     Task completion rate, return session rate within 24h
Test design: Variant A — current (fill + strikethrough only)
             Variant B — fill + strikethrough + scaleEffect 1.12→1.0 spring pulse
Success threshold: ≥8% increase in tasks completed per session on days 2–7
```

```
Hypothesis: [Replacing the generic collapsed pill with a module-context ambient signal]
            will increase hover-trigger rate (active use) by reducing the "I forgot
            this is here" effect
Metric:     Daily hover opens per user (panel expansion rate)
Test design: Variant A — current generic pill ("Utility Notch" + expand.vertical icon)
             Variant B — pill shows most recently active module's icon + last status string
Success threshold: ≥15% increase in daily opens on days 4–14
```

```
Hypothesis: [Raising copy flash duration to 250ms with spring fade-in] will reduce
            "did that work?" re-taps in Clipboard History
Metric:     Duplicate copy actions within 500ms (double-taps on same item)
Test design: Variant A — current 150ms easeOut
             Variant B — 250ms spring(0.20, 0.80) fade-in, 300ms total lifetime
Success threshold: ≥20% reduction in double-tap rate
```

### Competitor Emotional Audit

**Nearest functional competitor: Raycast (macOS launcher/utility)**

| Dimension | Raycast | UtilityNotch | Assessment |
|---|---|---|---|
| Visceral | Search-first, strong empty-state illustration, high animation quality | Panel-first, glass aesthetic, strong on music/carousel | UtilityNotch wins on ambient design; Raycast wins on first-launch clarity |
| Behavioral | Keyboard-native, extensible, deep third-party integrations | Mouse-primary, self-contained, notch-anchored | Raycast wins significantly — keyboard absence in UtilityNotch is the biggest gap |
| Reflective | "Power user's best friend" — identity as productivity multiplier | "Ethereal utility" — identity as ambient companion | Different positioning; UtilityNotch wins on visual identity but Raycast wins on efficacy narrative |

**Where Raycast is stronger:** Keyboard navigation, discoverability, extensibility narrative, onboarding.  
**Where UtilityNotch is stronger:** Aesthetic premium, notch integration, ambient always-there experience, music control quality.  
**Exploitable emotional differentiator UtilityNotch can own:** "The panel that feels like part of your Mac" — the notch-anchored expanding panel is genuinely unique and emotionally resonant for MacBook users. Raycast floats over everything. UtilityNotch *grows from* the machine. This is a strong identity claim that no competitor can match.

---

## Priority Actions

Ranked by emotional impact × implementation cost:

### Priority 1 — `[CRITICAL]` Remove DEMO badges from Clipboard History
**File:** `UtilityNotch/Modules/ClipboardHistory/ClipboardModuleView.swift`  
**Location:** `clipCard()` body, the `.overlay(alignment: .topTrailing)` block, lines ~183–195  
**Change:** Delete the entire overlay block that renders the `DEMO` capsule badge.  
**Emotional mechanism:** Eliminates the Quadrant II contempt signal. Per `DESIGN.md §7`, production UI must not contain wireframe scaffolding copy. The DEMO badge breaks the "Calm Expert" brand contract every time the clipboard is empty.  
**Expected outcome:** Module reads as polished and intentional rather than unfinished. Users in the empty state see a clean product, not a prototype indicator.

---

### Priority 2 — `[CRITICAL]` Add `accessibilityReduceMotion` gate across all animated views
**`[CARRIED FORWARD]` from mid-dev-report Priority 1**  
**Files:** Every view with animations — `SidebarRailView`, `ActiveModuleContainerView`, `TodoModuleView`, `MusicWaveView`, `DynamicIslandView`, `NotchPanelController`  
**Change:** Add `@Environment(\.accessibilityReduceMotion) var reduceMotion` and gate animations.  
**Emotional mechanism:** Trust signal. Users who need reduced motion have a right to a working experience. Ignoring this signals indifference to accessibility.  
**Expected outcome:** Full macOS Accessibility compliance. No ongoing animation for users with vestibular disorders.

---

### Priority 3 — `[HIGH]` Add todo task completion micro-celebration
**File:** `UtilityNotch/Modules/TodoList/TodoModuleView.swift`  
**Location:** `LiveTaskRowView`, the checkmark `Button` action in the done branch, and the `toggleTask()` function  
**Change:** When `isDone` transitions `false → true`, add a `scaleEffect` keyframe or spring that pulses the green circle from `1.0 → 1.14 → 1.0` over ~0.32s. Use `.spring(response: 0.32, dampingFraction: 0.55)` for a light bounce feel.  
**Emotional mechanism:** Peak-End Rule — the completion moment is the emotional peak of the Todo module. A micro-beat elevates it from Q4 (satisfaction) to Q1 (pride). This is the most emotionally leveraged single change in the entire app.  
**Expected outcome:** Task completion feels rewarding. Users feel a distinct moment of achievement rather than a mechanical state change.

---

### Priority 4 — `[HIGH]` Add Calendar permission CTA
**File:** `UtilityNotch/Modules/Calendar/CalendarModuleView.swift`  
**Location:** The `body` view builder, inside the `!isAuthorized` branch, inside the `ScrollView`  
**Change:** Below the event rows (which show dummy data), add a centered `Button` labeled `"Grant calendar access"` in SF Pro 12pt at white 55% opacity. On tap, call `EKEventStore.requestFullAccessToEvents(completion:)`.  
**Emotional mechanism:** Removes helplessness (Q3) — gives the user a clear path from demo to real data.  
**Expected outcome:** Conversion from demo to authorized state increases. Users who want real calendar data are no longer blocked by a UI that shows "PERMISSION REQUIRED" with no action.

---

### Priority 5 — `[HIGH]` Fix Files Tray hard-coded height + extend drop zone
**File:** `UtilityNotch/Modules/FilesTray/FilesTrayModuleView.swift`  
**Location:** The `.frame(height: 208)` on the ZStack container (drop zone), line ~133  
**Change:** Replace `height: 208` with `maxHeight: .infinity` or a calculated value that fills the 266pt canvas. The 4-column grid adapts naturally. Add a `minHeight: 120` to ensure minimum usable drop target.  
**Emotional mechanism:** Eliminates the visual gap that signals a layout error. The Files Tray is a frequent entry point (files drag onto the collapsed pill) — a polished first impression here matters.  
**Expected outcome:** Drop zone fills the content area proportionally. No unexplained whitespace below the grid.

---

### Priority 6 — `[MEDIUM]` Extend Clipboard copy flash to 250ms + fix easing
**File:** `UtilityNotch/Modules/ClipboardHistory/ClipboardModuleView.swift`  
**Location:** `copyItem()` function, the `withAnimation` and `asyncAfter` chain  
**Change:**
```swift
// Replace:
withAnimation(.easeOut(duration: 0.05)) { flashingID = item.id }
DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
    withAnimation(.easeOut(duration: 0.1)) { flashingID = nil }
}

// With:
withAnimation(.spring(response: 0.20, dampingFraction: 0.80)) { flashingID = item.id }
DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
    withAnimation(.easeOut(duration: 0.15)) { flashingID = nil }
}
```
**Emotional mechanism:** Raises the flash above the ~200ms cognitive threshold. Users consciously register that the copy action worked.  
**Expected outcome:** Reduced "did that copy?" uncertainty. Fewer double-tap re-copies.

---

### Priority 7 — `[MEDIUM]` Fix module switch animation to use spring
**File:** `UtilityNotch/Shell/ActiveModuleContainerView.swift`  
**Location:** `.animation(.easeInOut(duration: 0.22), value: appState.activeModuleID)`, line 23  
**Change:** Replace with `.animation(.spring(response: 0.28, dampingFraction: 0.72), value: appState.activeModuleID)`.  
**Emotional mechanism:** Consistency with the design system's spring rule for user-facing interactions. Currently this is the only major user-facing animation in the shell that uses easeInOut. Every sidebar tap triggers this animation — it is felt frequently.  
**Expected outcome:** Module switching feels physically consistent with the rest of the interaction vocabulary.

---

### Priority 8 — `[MEDIUM]` Standardize footer-left voice to descriptive state format
**Files:** All module views, `statusLeft:` parameter to `ModuleShellView`

**Inconsistency map:**

| Module | Current statusLeft | Target |
|---|---|---|
| Todo | `"\(n) COMPLETED TODAY"` | Keep — already descriptive state |
| Quick Notes | `"SAVED LOCALLY"` | Keep — system state |
| Clipboard | `"CLIPBOARD SYNC ACTIVE"` | Keep — system state |
| Music | `"NOW PLAYING"` / `"NO SOURCE"` | Keep — system state |
| Calendar | `currentMonthYear.uppercased()` / `"PERMISSION REQUIRED"` | Keep |
| Files Tray | `"\(n) FILES"` | Keep |
| Files Tray | **statusRight: `"DROP TO ADD"`** | Change to `"DRAG TO ADD"` — more accurate (drag not drop) or simply `"\(n) FILES"` to match left |

The only actionable change: Files Tray `statusRight` should be `"DRAG FILES IN"` rather than `"DROP TO ADD"` to match macOS terminology (drag is the gesture, drop is the completion).  
**Emotional mechanism:** Precision language reinforces the Calm Expert brand.

---

### Priority 9 — `[LOW]` Enrich collapsed DI pill with module-context ambient signal
**File:** `UtilityNotch/Shell/DynamicIslandView.swift`  
**Location:** `ambientIndicator` computed property, lines 213–219  
**Change:** Extend the ambient indicator beyond just `musicControl`. Show the active module's icon (SF Symbol, 10pt, white 40%) for all modules. For music, keep the current music.note + emerald tint. For others, show their sidebar icon in white 40%.  
**Emotional mechanism:** Transforms the collapsed pill from anonymous "Utility Notch" branding into a live-context signal. Users see something happening, not just a static label.  
**Expected outcome:** Higher return hover rate as users see the pill as dynamic rather than a static launcher button.

---

## Summary Table

| # | Priority | File | Change | Emotional Mechanism |
|---|---|---|---|---|
| 1 | CRITICAL | ClipboardModuleView | Remove DEMO badge overlay | Eliminates Q2 contempt signal |
| 2 | CRITICAL | All animated views | Add reduceMotion gate | Trust + Accessibility |
| 3 | HIGH | TodoModuleView / LiveTaskRowView | Checkmark completion pulse | Peak moment → Q1 pride |
| 4 | HIGH | CalendarModuleView | Add permission CTA button | Remove Q3 helplessness |
| 5 | HIGH | FilesTrayModuleView | Replace height:208 with maxHeight | Eliminate layout error signal |
| 6 | MEDIUM | ClipboardModuleView | Extend copy flash to 250ms | Cognitive feedback registration |
| 7 | MEDIUM | ActiveModuleContainerView | Switch to spring animation | System-wide consistency |
| 8 | MEDIUM | FilesTrayModuleView | Rename footer-right "DROP TO ADD" | Calm Expert language precision |
| 9 | LOW | DynamicIslandView | Enrich collapsed pill ambient | Live vs static identity signal |
