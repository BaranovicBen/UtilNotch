# Redesign Ideas: Music Control + Calendar Modules
**Date:** 2026-05-12  
**Canvas:** 542 × 266pt (module drawing area inside the shell)  
**System:** The Glass Monolith — black ground, white opacity layers, `#0A84FF` accent, SF Pro + SF Mono  

---

## 1. Calendar Module

### What's Wrong

**The "awkward empty-yet-filled" diagnosis:**

The current layout stacks a *dominant* date headline at the top that burns through nearly 40% of the vertical canvas before a single event appears. When there are no events, the bottom half is a void — visually "empty" — but the date area above feels "filled" with large typographic weight that isn't serving the user's actual need (seeing events).

**Budget audit of the current layout** (CalendarModuleView.swift):
```
HStack(day 52px-black + month 28px-semibold)   ≈ 72pt
  + padding .bottom 8 = 8pt
weekStrip frame(height: 52) + padding .top 8   ≈ 60pt
upcomingLabel frame(height: 16) + padding 14pt ≈ 30pt
3 event rows × 44pt + 2 × 6pt gap             ≈ 144pt
─────────────────────────────────────────────────────
Total                                           ≈ 314pt  (canvas is 266pt)
```

The scrollview masks the overflow, but the *proportional weight* is the real problem:
- Date header (non-interactive, background context) = ~28% of canvas
- Week strip = ~23%
- "UPCOMING" label = ~11%
- Actual event content = ~38%

The hierarchy says "THE DATE IS THE CONTENT." The user needs "THE EVENTS ARE THE CONTENT."

**Secondary issues:**
- The `52px` day number is a full-page calendar idiom — too dominant for a 266pt compact panel
- The `28px` month/year sub-label is almost body-text size, competing with event titles
- `Text("UPCOMING")` section header costs 30pt and adds no information (it's always the same word)
- Prev/next chevrons on the date row are redundant — the week strip already handles day selection
- Events are capped at 3, but with the current layout, 2 is the practical visible count before scroll
- Empty state ("No upcoming events") is plain `.callout` centered text — no depth, no warmth

---

### Redesign: Calendar v2

**Core principle shift:** *The week strip is orientation, the events are content. Shrink everything that isn't an event.*

#### Layout Blueprint (266pt canvas)

```
┌──────────────────────────────────────────────────┐
│  Week Strip (36pt)                               │  ← FIRST: orientation tool at the top
│  SUN  MON  TUE [WED] THU  FRI  SAT              │     compact, today dot, selected pill
├──────────────────────────────────────────────────┤
│  Date context bar (24pt)                         │  ← SECOND: quiet metadata, not dominant
│  WEDNESDAY, MAY 14                    3 EVENTS   │     SF Mono 10pt uppercase 35% white
├──────────────────────────────────────────────────┤
│  Event rows (fill remaining ≈ 196pt)             │  ← THIRD: the actual content
│  ▏ 09:00  Team Standup          ● video    (36pt)│     4–5 rows comfortably
│  ▏ 14:00  Design Review         ● video    (36pt)│
│  ▏ 16:30  1:1 with Manager             (36pt)   │
│  ▏ 18:00  Dinner                       (36pt)   │
│                                                  │
└──────────────────────────────────────────────────┘
```

#### Week Strip — Redesign

Current: 52pt tall, cell height: 40pt, abbrev + number stacked.  
New: **36pt tall**, tighter cells, today gets a **dot below the number** (not a full pill), selected gets a **pill background**.

```swift
// New week cell structure
VStack(spacing: 2) {
    Text(day.abbrev)                         // "WED"
        .font(.system(size: 9, weight: day.isSelected ? .medium : .regular))
        .foregroundStyle(day.isSelected ? .white : Color.white.opacity(0.30))
    
    ZStack {
        if day.isSelected {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(day.isToday ? UNConstants.iconActiveTint : Color.white.opacity(0.14))
                .frame(width: 28, height: 24)
        }
        Text("\(day.day)")
            .font(.system(size: 13, weight: day.isSelected ? .semibold : .regular))
            .foregroundStyle(day.isSelected ? .white : Color.white.opacity(0.40))
    }
    
    // Today indicator dot — only when not selected
    Circle()
        .fill(day.isToday && !day.isSelected ? UNConstants.iconActiveTint : Color.clear)
        .frame(width: 4, height: 4)
}
.frame(maxWidth: .infinity)
.frame(height: 36)
```

Key changes:
- Height: 52 → **36pt** (saves 16pt)
- Remove: outer `HStack chevron nav buttons` — week strip handles navigation by tapping a day; a swipe gesture or long-press can advance the week (or keep chevrons in the footer as text nav)
- Today indicator: dot below the number (not a large pill) so it reads as context, not "active"

#### Date Context Bar — Redesign

Replace the dominant `52px + 28px` date headline with a **single-row quiet bar**:

```swift
HStack {
    Text(day.abbrev + ", " + monthYear)     // "WED, MAY 14"
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(Color.white.opacity(0.35))
        .textCase(.uppercase)
    
    Spacer()
    
    // Optional: subtle week navigation arrows (compact)
    HStack(spacing: 4) {
        navChevron("chevron.left")  { store.shiftDay(-7) }
        navChevron("chevron.right") { store.shiftDay(7)  }
    }
}
.frame(height: 24)
.padding(.top, 4)
```

This saves **~54pt** vs the current heading — that's 2 full extra event rows.

#### Event Rows — Redesign

Current rows are 44pt with a 3pt color line. The 44pt height is fine but the internal layout is dense.

New row: **36pt** rows (saves space, allows 5 rows in remaining canvas).

```
[3pt color line] [TIME  ] [title — prominent — 13px semibold] [badge or video] 
                                                               right-align: ▶ "in 2h"
```

Specific changes:
- Color accent: **3pt vertical line at left edge** (current `width: 3, height: 20`) → extend to **full row height** (`width: 3, height: 28`). Makes the calendar color more impactful.
- Time: `11px mono, white 45%` — unchanged, correct
- Title: `13px semibold, white 85%` — bump from regular to **semibold** for better hierarchy
- `"in 2h"` badge: keep, but style as `UNConstants.iconActiveTint` background (current `.accentColor.opacity(0.2)`)
- Row background: keep `white.opacity(0.03)` resting, `white.opacity(0.05)` hover — correct
- Row height: 44 → **36pt** (saves 8pt per row; with 5 rows: 40pt saved)

#### Empty State — Redesign

The current empty state is a bare `Text("No upcoming events")` with no visual presence:

```swift
// New empty state
VStack(spacing: 8) {
    Image(systemName: "calendar.badge.checkmark")
        .font(.system(size: 20))
        .foregroundStyle(Color.white.opacity(0.14))
    
    Text("nothing scheduled")
        .font(.system(size: 13))
        .foregroundStyle(Color.white.opacity(0.35))
    
    Text("for " + store.currentDateCompact)   // "for today"
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(Color.white.opacity(0.20))
        .textCase(.uppercase)
}
.frame(maxWidth: .infinity, maxHeight: .infinity)
```

Rationale: lowercase primary text (design system copy rule), mono secondary, no borders/boxes.

#### Layout Budget After Redesign

```
Week strip (36pt)                              36pt
Date context bar (24pt + 4pt top padding)      28pt
Thin separator (1pt + 6pt vertical padding)     8pt  ← Color.white.opacity(0.08) line
Event rows: 5 × 36pt + 4 × 5pt gap           200pt
─────────────────────────────────────────────────
Total                                         272pt  (canvas 266pt — minor scroll OK)
```

If using 4 rows: `4 × 36 + 3 × 5 = 159pt` → total 231pt, 35pt breathing room at bottom.

---

## 2. Music Control Module

### What's Wrong

**The "cold" diagnosis:**

The current layout is a vertically stacked column of isolated components: carousel → text → wave → buttons → scrubber. Each element is self-contained and emotionally disconnected from the others. There is no *atmosphere* — no color from the album art bleeding into the rest of the module, no sense that the song has a personality beyond its title.

**Specific coldness factors:**
1. **The 3D Carousel**: The `rotation3DEffect` with darkening overlays and perspective transform is technically impressive but emotionally mechanical. It reads as a UI trick, not a music experience. The prev/next art is visible but blurred and scaled down — they add visual complexity without adding warmth.
2. **Centered column layout**: Everything centered in a 542pt-wide canvas means massive dead space on both sides of the controls row. The play button (34pt circle) is a tiny dot in the center of a wide dark void.
3. **White-only palette**: Controls, text, wave — all pure white opacities. No color from the music bleeds into the space. Compare Apple's NowPlaying widget, which extracts the dominant album art color for the progress bar and backgrounds.
4. **The scrubber (to be removed)**: Was the most interactive element, now leaving a gap.
5. **Wave position**: Sandwiched between info text and controls — neither decorative enough to be visual art nor large enough to be impactful.

**What "warm" means in the Glass Monolith system:**
- The `musicArtPalette` gradients already exist for exactly this purpose
- The `musicPlayingTint` (emerald green), `musicProgressStart` (purple), `musicProgressEnd` (blue) are established color tokens
- Warmth = the album art color *leaks into the space around it* (glow, ambient light effect)
- Warmth = the play button feels weighty, not tiny
- Warmth = breathing room — generous spacing between elements

---

### Redesign: Music v2 — Horizontal Split

**Core principle shift:** *Stop stacking. Split the canvas left/right. Album art owns the left. Controls own the right. Let the art's color warm the whole module.*

#### Layout Blueprint (542 × 266pt canvas)

```
┌──────────────────┬────────────────────────────────┐
│                  │                                │
│   Album Art      │  Track Title (17px bold)       │
│   160 × 160pt    │  Artist Name  (13px, 55%)      │
│                  │                                │
│   [ambient glow  │  Source badge (10px mono)      │
│    behind art]   │                                │
│                  │  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  wave (24pt) │
│                  │                                │
│                  │  ⏮   ▶   ⏭               │
│                  │  (36) (44) (36)    spacious    │
│                  │                                │
└──────────────────┴────────────────────────────────┘
  Left: 200pt           Right: 314pt (with 24pt internal padding)
```

No progress bar. No timestamps. No carousel. No scrubber.

#### Left Column — Art Tile with Ambient Glow

```swift
// Art tile: 160×160pt, cornerRadius 16
// Ambient glow: radial gradient behind the art using the track's palette

ZStack {
    // Ambient glow — the warmth
    let palette = UNConstants.musicArtPalette
    let idx = abs((np?.current?.id ?? "").hashValue) % palette.count
    let glowColor = palette[idx][1]   // dominant color from palette
    
    RadialGradient(
        colors: [glowColor.opacity(0.45), Color.clear],
        center: .center,
        startRadius: 60,
        endRadius: 120
    )
    .frame(width: 220, height: 220)
    .blur(radius: 24)
    
    // Art tile
    artTile(at: carouselCenter)
        .frame(width: 160, height: 160)
        .shadow(
            color: glowColor.opacity(0.30),
            radius: 24, y: 8
        )
}
.frame(width: 200, height: 266)
```

Key changes from current:
- **Size**: 100pt → **160pt** (60% larger — the art becomes the visual anchor)
- **Single tile**: Removes the 3D carousel entirely. Track switching = crossfade + scale spring.
- **Ambient glow**: The dominant color from the art palette radiates outward behind the tile. This is the single biggest warmth improvement.
- **Track switch animation**: `contentTransition(.identity)` + `.animation(.spring(response: 0.45, dampingFraction: 0.75))` on the art view — a gentle bloom in/out as the track changes.

#### Right Column — Info + Wave + Controls

```swift
VStack(alignment: .leading, spacing: 0) {
    Spacer()
    
    // Track info
    VStack(alignment: .leading, spacing: 5) {
        Text(np?.current?.title ?? "—")
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(Color.white.opacity(0.92))
            .lineLimit(2)                               // allow wrapping — titles matter
            .contentTransition(.numericText())
        
        Text(np?.current?.artist ?? "")
            .font(.system(size: 13))
            .foregroundStyle(Color.white.opacity(0.55))
            .lineLimit(1)
            .contentTransition(.numericText())
    }
    
    Spacer().frame(height: 16)
    
    // Source badge — replaces the cold footer "NO SOURCE / NOW PLAYING"
    if let source = np?.playbackSourceLabel {
        Text(source.uppercased())
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.28))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(Color.white.opacity(0.06))
            )
    }
    
    Spacer().frame(height: 20)
    
    // Wave — full right-column width, now serves as a visual breathing space
    MusicWaveView(
        isPlaying: np?.isPlaying ?? false,
        color: orchestrator.waveColor
    )
    .frame(maxWidth: .infinity)
    .frame(height: 28)
    
    Spacer().frame(height: 20)
    
    // Controls — left-aligned with generous spacing, feels grounded not floating
    HStack(spacing: 28) {
        controlButton(icon: "backward.fill",  size: 14, diameter: 36,
                      disabled: !caps.canSkipPrevious) { triggerTrackChange(forward: false) }
        
        controlButton(
            icon: np?.isPlaying == true ? "pause.fill" : "play.fill",
            size: 18, diameter: 44, fillOpacity: 0.18,         // larger play button
            disabled: !caps.canPlayPause
        ) { Task { await orchestrator.playPause() } }
        
        controlButton(icon: "forward.fill", size: 14, diameter: 36,
                      disabled: !caps.canSkipNext) { triggerTrackChange(forward: true) }
    }
    
    Spacer()
}
.padding(.horizontal, 20)
.padding(.vertical, 12)
.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
```

Key changes:
- **Left-aligned** (not centered) — grounds the content, more editorial, less floating
- **Play button**: 34pt → **44pt** — now a proper tap target and visual anchor
- **Spacing**: controls `spacing: 16` → **`spacing: 28`** — buttons breathe
- **Title wraps to 2 lines** — long song names like "Bohemian Rhapsody" deserve full treatment
- **Source badge** replaces the bland "NO SOURCE" / "NOW PLAYING" text with a subtle pill
- **Wave moved above controls** — acts as a visual separator between info and controls, not a buried mid-stack element

#### Track Switch Animation (Replaces Carousel)

Instead of the 3D carousel animation, use a **crossfade + bloom** on the art tile only:

```swift
artTile(at: carouselCenter)
    .frame(width: 160, height: 160)
    .id(np?.current?.id ?? "")           // forces identity transition on track change
    .transition(
        .asymmetric(
            insertion: .scale(scale: 0.88).combined(with: .opacity),
            removal:   .scale(scale: 1.06).combined(with: .opacity)
        )
    )
    .animation(.spring(response: 0.42, dampingFraction: 0.76), value: np?.current?.id)
```

When next track: current art scales up slightly and fades, new art scales in from slightly smaller. Feels like the album is "arriving" — warm, physical, not mechanical.

#### Removing the Progress Bar (scrubber)

With the progress bar removed, the right column gains ~30pt of vertical space. This should be redistributed as:
- Increase the `Spacer()` between track info and source badge
- Increase the `Spacer()` between wave and controls
- The module feels airier, not emptier

The footer (`statusLeft`/`statusRight`) still carries "NOW PLAYING" / "SPOTIFY" — those survive untouched.

#### Empty State — Redesign

The current empty state (`emptyStateView`) is adequate but slightly over-explained. A warmer version:

```swift
VStack(spacing: 12) {
    // Large art placeholder with a neutral gradient
    RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(LinearGradient(
            colors: [Color.white.opacity(0.04), Color.white.opacity(0.08)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ))
        .frame(width: 72, height: 72)
        .overlay(
            Image(systemName: "music.note")
                .font(.system(size: 24))
                .foregroundStyle(Color.white.opacity(0.18))
        )
    
    Text("nothing playing")
        .font(.system(size: 14))
        .foregroundStyle(Color.white.opacity(0.40))
    
    Text("open spotify, apple music, or any media app")
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(Color.white.opacity(0.22))
        .multilineTextAlignment(.center)
        .textCase(.uppercase)
}
.frame(maxWidth: .infinity, maxHeight: .infinity)
```

---

## 3. Summary of Changes

### Calendar

| Dimension | Before | After | Savings |
|---|---|---|---|
| Day number heading | 52px black text | Removed | — |
| Month/year heading | 28px semibold text | Compact mono 10px bar | ~48pt vertical |
| Week strip height | 52pt | 36pt | 16pt |
| "UPCOMING" section label | 30pt (16pt + 14pt padding) | Removed (thin separator instead) | 30pt |
| Event row height | 44pt | 36pt | 8pt/row |
| Visible events | 3 | **4–5** | +1–2 rows |
| Navigation chevrons | On date row (dominant) | On date bar (quiet) or removed | Less visual noise |
| Hierarchy message | DATE IS CONTENT | EVENTS ARE CONTENT | ✓ |
| Empty state | Plain text | Icon + lowercase primary + mono secondary | Warmer |

### Music

| Dimension | Before | After |
|---|---|---|
| Layout axis | Vertical column | **Horizontal split** (art left / info+controls right) |
| Album art size | 100pt | **160pt** |
| Ambient color glow | None | **Radial glow from art palette** |
| Carousel | 3D wheel (110pt) | **Single tile + crossfade bloom** |
| Play button size | 34pt | **44pt** |
| Controls spacing | 16pt | **28pt** |
| Progress bar / scrubber | Present | **Removed** |
| Track title lines | 1 (truncated) | **2 (wraps)** |
| Info alignment | Centered | **Left-aligned** |
| Wave position | Between text and controls | Between source badge and controls |
| Coldness | High | **Low** — art color radiates into the space |

---

## 4. Implementation Notes

### What Files Change

**Calendar:**
- `Modules/Calendar/CalendarModuleView.swift` — layout only, no data layer changes
- `CalendarStore.swift` — no changes needed

**Music:**
- `Modules/MusicControl/MusicModuleView.swift` — layout complete rewrite
- The `carouselView`, `wheelSlot`, `artTile` logic stays (reused for single art display)
- Remove: `progressView`, `isDraggingProgress`, `dragProgress`, `trackWidth` state, `displayTime` timer
- Remove: `carouselLocked`, `wheelOffset`, `slotDistance`, `maxRotation` carousel animation state
- Keep: `artPlaceholder`, `artTile`, `controlButton`, `trackInfoView`, `waveView`
- The `triggerCarousel` function is replaced with a direct `orchestrator.next()` / `orchestrator.previous()` call — the animation is handled by SwiftUI identity transitions on the art view

### Constraints Respected
- All tokens from `UNConstants.*`
- No inline hex except existing `Color(hex:)` patterns
- Spring animations for all state changes
- `.easeInOut(duration: 0.15)` for hover only
- No horizontal dividers in module content
- No drop shadows on UI controls (only on album art — this is the allowed ambient glow exception matching the panel's own glow rule)
- No `.linear` animations on user-facing interactions
- `ModuleShellView` wrapper structure unchanged
- `AppState.setModuleActionButton(nil)` in `.onAppear` unchanged
- Canvas dimensions (542 × 266pt) respected
