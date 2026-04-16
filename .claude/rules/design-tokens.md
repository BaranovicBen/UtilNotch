# Design Tokens

All values sourced from `Helpers/Constants.swift` — `UNConstants` enum and `ScreenGeometry` struct.
**Never use magic numbers in views.** Reference these tokens or add new ones to `UNConstants`.

---

## Panel Dimensions

| Token | Value | Use |
|---|---|---|
| `UNConstants.panelWidth` | 622pt | Full panel width |
| `UNConstants.panelHeight` | 382pt | Full panel height |
| `UNConstants.panelCornerRadius` | 20pt | Outer panel corners |
| `UNConstants.invertedCornerRadius` | 10pt | Inverted corner pieces |
| `UNConstants.innerCornerRadius` | 12pt | Inner content corner |
| `UNConstants.sidebarWidth` | 48pt | Left icon rail |
| `UNConstants.headerHeight` | 60pt | Shell header |
| `UNConstants.footerHeight` | 38pt | Shell footer |
| `UNConstants.contentHeight` | 282pt | Module content area height |
| Content VStack width | **574pt** | panelWidth(622) − sidebarWidth(48). Sidebar is on the RIGHT. This is what header/footer frames span. |
| **Module content canvas** | **542 × 266pt** | 574 − 16×2 horizontal padding = 542pt wide. contentHeight(282) − 8×2 vertical padding = 266pt tall. **This is your actual drawing area inside a module view.** |

---

## Spacing / Padding

| Token | Value | Use |
|---|---|---|
| `UNConstants.headerPaddingH` | 24pt | Header horizontal padding |
| `UNConstants.footerPaddingH` | 16pt | Footer horizontal padding |

Unspecified spacing: use multiples of 4. Common values: 4, 8, 12, 16, 24.

---

## Colors

| Token | Value | Use |
|---|---|---|
| `UNConstants.panelBackground` | `.black` | Panel window background |
| `UNConstants.accentHighlight` | `white.opacity(0.08)` | Active state fill |
| `UNConstants.iconTint` | `white.opacity(0.35)` | Inactive icon tint |
| `UNConstants.iconActiveTint` | `#0A84FF` | Active / selected icon |
| `UNConstants.successTint` | `green.opacity(0.10)` | Success background fill |
| `UNConstants.successBorder` | `green.opacity(0.25)` | Success border |
| `UNConstants.errorTint` | `amber.opacity(0.10)` | Error/warning fill (amber, not red) |
| `UNConstants.errorBorder` | `amber.opacity(0.25)` | Error/warning border |
| `UNConstants.focusTint` | `blue.opacity(0.08)` | Focused field background |
| `UNConstants.focusBorder` | `blue.opacity(0.50)` | Focused field border |
| `UNConstants.panelGlowOpacity` | 0.05 | Ambient glow behind panel |
| `UNConstants.activeStateOpacity` | 0.08 | Active/selected background opacity |
| `UNConstants.hoverStateOpacity` | 0.05 | Hover background opacity |

### Inline color patterns (used in views, not in UNConstants)
```swift
// Text hierarchy
Color.white.opacity(0.85)    // primary text
Color.white.opacity(0.50)    // secondary text
Color.white.opacity(0.35)    // tertiary / timestamps
Color.white.opacity(0.25)    // placeholders

// Row backgrounds
Color.white.opacity(0.07)    // editing state
Color.white.opacity(0.05)    // hover state
Color.white.opacity(0.03)    // resting state

// Borders / strokes
Color.white.opacity(0.30)    // unchecked circle stroke
Color.white.opacity(0.12)    // subtle divider

// Done/success green (inline)
Color(hex: "32D74B")         // checkmark fill, iOS system green

// Danger red (delete only)
Color(hex: "FF453A")         // trash icon — destructive actions only
```

---

## Typography

No custom fonts — system only.

| Style | SwiftUI | Use |
|---|---|---|
| Module title | `.system(size: 13, weight: .semibold)` | Shell header |
| Body | `.system(size: 14, weight: .regular)` | List items, input fields |
| Caption | `.system(size: 11)` | Timestamps, subtitles |
| Monospaced | `.system(size: 11, design: .monospaced)` | Counts, timestamps |
| Footer label | `.system(size: 10, weight: .medium)` | Footer status text |

---

## Timing Constants

| Token | Value | Use |
|---|---|---|
| `UNConstants.animationDuration` | 0.28s | Standard spring response |
| `UNConstants.contentFadeDelay` | 0.08s | Cross-fade delay on module switch |
| `UNConstants.hoverOpenDelay` | 0.3s | Delay before panel opens on hover |
| `UNConstants.defaultInactivityTimeout` | 8.0s | Auto-close after inactivity |

### Spring presets
```swift
// Standard UI response (buttons, selections)
.spring(response: 0.28, dampingFraction: 0.72)

// Item add/remove (lists)
.spring(response: 0.35, dampingFraction: 0.74)

// Drag displacement (rows sliding apart)
.spring(response: 0.35, dampingFraction: 0.70)

// Drag lift (the item being dragged)
.spring(response: 0.25, dampingFraction: 0.65)

// Hover state (the only easeInOut allowed)
.easeInOut(duration: 0.15)
```

---

## Icons

SF Symbols only. Do not use custom image assets unless a symbol genuinely doesn't exist.

| Context | Symbol |
|---|---|
| Add action | `plus` |
| Confirm | `checkmark` |
| Cancel / close | `xmark` |
| Edit | `pencil` |
| Delete | `trash` |
| Drag handle | `line.3.horizontal` |
| Done state | `checkmark` (inside filled circle) |
| Module sidebar icons | defined per-module in `UtilityModule.icon` |
