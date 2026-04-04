# Design System: The Glass Monolith

## 1. Overview & Creative North Star

**Creative North Star: The Ethereal Utility**

This design system moves away from the "utility-as-a-tool" aesthetic and toward "utility-as-an-atmosphere." It is designed to feel like an integrated part of the macOS Ventura/Sonoma ecosystem — a high-end, editorial HUD (Heads-Up Display) that feels carved from a single block of dark, frosted glass.

The system rejects the "flat" web-standard look. Instead, it embraces **Atmospheric Depth**. By using intentional asymmetry (the 48px right-aligned sidebar), high-contrast typography scales (SF Mono vs. SF Pro), and layered opacities, we create an experience that feels premium, quiet, and authoritative.

---

## 2. Canonical Shell Dimensions

These dimensions are fixed and non-negotiable. They must match ARCHITECTURE_RULES.md exactly.

| Zone | Value |
|---|---|
| Outer container | 622 × 382 |
| Main area | 572 × 380 |
| Sidebar | 48 × 380 |
| Header height | 60px |
| Content height | 282px |
| Footer height | 38px |
| Sidebar top blank area | 60px |
| Sidebar icon area | 282px |
| Sidebar settings footer | 38px |

The sidebar is on the **right side** of the shell.

---

## 3. Colors & Surface Logic

The palette is built on a foundation of "True Dark" (`#000000`) and monochromatic white opacities. Colors like `primary` (`#0A84FF`) are used sparingly as surgical strikes of intent.

### The "No-Line" Rule

Traditional 1px solid borders are strictly prohibited for internal sectioning. Structural boundaries must be defined by background shifts. The only exception is the sidebar left border, which is the single allowed structural divider in the app.

### Allowed borders

- **Outer container ghost border:** `1px solid rgba(255, 255, 255, 0.10)` — a specular edge treatment, not a divider
- **Sidebar left border:** `1px solid rgba(255, 255, 255, 0.15)` — the only structural divider allowed in the app

Everything else must be separated by background color shifts, not lines.

### Surface Hierarchy & Nesting

Treat the interface as a physical stack of semi-transparent materials:

- **Base layer:** `#000000` with `backdrop-filter: blur(20px)`
- **Content area subtle lift:** `rgba(255, 255, 255, 0.02)` background on the content zone
- **In-set containers:** `rgba(255, 255, 255, 0.04)` — use to "recede" elements like search fields
- **Raised elements / hover states:** `rgba(255, 255, 255, 0.08)` — use to "lift" hovered items

### The Glass & Gradient Rule

The main panel **must** have an ambient blue glow: a radial gradient at `5% opacity #0A84FF` positioned at the top-left corner of the panel. This provides the "visual soul" that prevents the surface from feeling dead — it mimics the way light catches the edge of real glass.

Implementation: `background: radial-gradient(ellipse at top left, rgba(10, 132, 255, 0.05) 0%, transparent 60%), #000000`

This is required, not optional. A panel without it will read as flat and lifeless. It must never be implemented as a border or line.

---

## 4. Typography

The typography system uses a "Modern Editorial" approach, pairing the humanist curves of **SF Pro** with the technical precision of **SF Mono**.

| Role | Font | Size | Weight | Color |
|---|---|---|---|---|
| Header / Module title | SF Pro | 16px | Semibold (500) | `rgba(255, 255, 255, 1.0)` |
| Secondary body | SF Pro | 14px | Regular (400) | `rgba(255, 255, 255, 0.85)` |
| Technical / metadata | SF Mono | 10px | Regular (400) | `rgba(255, 255, 255, 0.60)` |
| Micro-labels / sidebar | SF Mono | 11px | Regular (400) | `rgba(255, 255, 255, 0.55)` |

Footer text uses SF Mono 10px, uppercase, `letter-spacing: 0.08em`.

Micro-labels (sidebar) use SF Mono 11px, uppercase, `letter-spacing: 0.05em`.

---

## 5. Elevation & Depth

Depth is a result of **Tonal Layering**, not shadows.

- **The Layering Principle:** To indicate an active state, increase the background opacity of the element from `rgba(255,255,255,0.05)` to `rgba(255,255,255,0.12)`. Do not add a shadow.
- **Ambient "Shadows":** If an element must float (e.g. a detached tooltip), use a 40px blur shadow at 8% opacity tinted with `#0A84FF`, not black.
- **The Ghost Border:** The main panel uses `1px solid rgba(255, 255, 255, 0.10)`. This is a specular highlight that defines the edge of the glass. Never use this for internal dividers.
- **Glassmorphism:** All panels must use `backdrop-filter: blur(20px)`. This ensures the user's wallpaper bleeds through, making the app feel native to their desktop environment.

---

## 6. Components

### Header

- **Height:** 60px
- **Title:** SF Pro Semibold 16px, left-aligned, vertically centered, padding-left 24px
- **Optional action button:** right-aligned, vertically centered, padding-right 24px
- **Background:** inherits shell background — no separate fill
- **No divider line below the header**

### Footer (main)

- **Height:** 38px
- **Text:** SF Mono Regular, 10px, uppercase, `rgba(255, 255, 255, 0.60)`, `letter-spacing: 0.08em`
- **Layout:** left text at padding-left 16px, right text at padding-right 16px, both vertically centered
- **Both slots optional** — a module may provide one, both, or neither
- **No icons or controls** — text only
- **No divider line above the footer**

### Sidebar (right column)

- **Dimensions:** 48px wide, 380px tall
- **Position:** right side of the shell
- **Left border:** `1px solid rgba(255, 255, 255, 0.15)` — the only structural divider in the app
- **Top blank area:** 60px (empty, aligns with header zone)
- **Icon area:** 282px, internal scroll with fade mask
- **Settings footer:** 38px, gear icon centered
- **Icon size:** 15px
- **Active icon color:** `#0A84FF`
- **Inactive icon color:** `rgba(255, 255, 255, 0.35)`
- **Hover color:** `rgba(255, 255, 255, 1.0)`
- **Active state background:** `rgba(255, 255, 255, 0.08)` behind the active icon

### Sidebar hover tooltip

- **Trigger:** cursor rests on a sidebar icon for 150ms
- **Content:** module name only — no icon, no description
- **Position:** to the left of the icon, vertically centered with it
- **Typography:** SF Pro Regular, 12px, `rgba(255, 255, 255, 0.85)`
- **Background:** `rgba(0, 0, 0, 0.60)`
- **Border radius:** 8px
- **Padding:** 4px 8px
- **Dismiss:** instant on cursor exit — no linger delay
- **Exception:** the settings gear does not get a tooltip

### Buttons

- **Primary:** background `#0A84FF`, text white 100%, border-radius 12px
- **Secondary (ghost):** background `rgba(255, 255, 255, 0.07)`, text `rgba(255, 255, 255, 0.85)`, no border
- **Tertiary:** no background, text `#0A84FF`

### Input Fields

- **Background:** `rgba(255, 255, 255, 0.04)`
- **Border:** none by default
- **Focus state:** `0.5px` border changes from `rgba(255,255,255,0.07)` to `rgba(10,132,255,0.50)` — no glow

### Lists & Navigation

- **Item spacing:** `0.9rem` between items
- **Separation:** no horizontal dividers — use `rgba(255, 255, 255, 0.05)` hover background with 4px border-radius to indicate interactivity

### Empty States

- **Placement:** vertically and horizontally centered within the content area
- **Structure:** optional icon + primary text + secondary text
- **Primary text:** SF Pro Regular, 14px, `rgba(255, 255, 255, 0.50)`
- **Secondary text:** SF Mono Regular, 11px, uppercase, `rgba(255, 255, 255, 0.30)`
- **Gap between primary and secondary:** 8px
- **No borders, boxes, or containers around empty states**

### State Colors

These are the only colors permitted beyond the base white-opacity system and the primary blue. They apply to module-level feedback states only — never to structural elements.

| State | Background tint | Border tint | Use for |
|---|---|---|---|
| Focus | `rgba(10, 132, 255, 0.08)` | `rgba(10, 132, 255, 0.50)` at 0.5px | Input fields when focused |
| Success | `rgba(52, 199, 89, 0.10)` | `rgba(52, 199, 89, 0.25)` at 0.5px | Completion confirmation, done state |
| Error | `rgba(255, 159, 10, 0.10)` | `rgba(255, 159, 10, 0.25)` at 0.5px | Failure state, validation error |

**Rules:**
- Error state uses amber, never red. Red reads as destructive and alarming — amber communicates calm urgency.
- Success green is used only at the moment of completion. It must not persist as a permanent state color.
- These tints appear on the content element itself (a row, a field, a card) — never on the shell, header, footer, or sidebar.
- State colors must fade out within 2 seconds unless the user action is still in progress.

---

## 7. Copy Rules

### Voice: Calm Expert

The app speaks with quiet authority. It does not exclaim. It does not instruct. It states.

- **Warmth:** low — precise, not cold
- **Energy:** minimal — confident, never urgent
- **Register:** lowercase preferred, sentence case required, all-caps prohibited in production UI

### Copy by state

| State | Wrong | Right |
|---|---|---|
| Empty | `MAIN MODULE CONTENT AREA` | `nothing here yet` |
| Empty (secondary) | `NO ITEMS FOUND` | `add something to get started` |
| Success | `TASK COMPLETED SUCCESSFULLY` | `done` |
| Error | `AN ERROR HAS OCCURRED` | `couldn't do that — try again` |
| Loading | `LOADING...` | `loading` or no copy at all |

### Rules

- Placeholder copy (`SESSION_ID: 8X-921`, `MAIN MODULE CONTENT AREA`) is wireframe scaffolding — it must never appear in a production build.
- Footer strings are SF Mono uppercase — this is the one exception to the lowercase rule, because footer text is machine metadata, not human language.
- Empty state primary text is SF Pro, lowercase, human — it addresses the user, not the system state.
- No exclamation marks anywhere in the UI.
- No "successfully" — if something worked, the interface shows it; it doesn't announce it.

---

## 8. Do's and Don'ts

**Do:**

- Use **asymmetry**. The 48px right sidebar feels like a distinct "control strip" compared to the wider content area.
- Use **SF Mono** for any numerical data, status strings, or footer metadata to give it a "pro-tool" aesthetic.
- Use **white opacities** to create hierarchy. Important = 100%, Secondary = 70–85%, Disabled = 20–30%.
- Use **background shifts** to separate zones. Never lines.
- Keep the sidebar on the **right** at all times.

**Don't:**

- **No drop shadows.** Shadows break the "HUD" glass illusion. Use background color shifts instead.
- **No 100% opaque backgrounds.** The app should always feel like it is "floating" over the desktop.
- **No sharp corners.** Use `20px` radius for the main panel and `12px` for internal elements.
- **No pure black text backgrounds.** Use `#000000` for the glass surface. Pure `#000` with no blur or opacity kills the glassmorphism effect — ensure backdrop-filter is always active.
- **No horizontal divider lines.** Only the sidebar left border is permitted.
- **No sidebar on the left.** The sidebar is always on the right.
- **No 40px sidebar.** The sidebar is always 48px. Any reference to 40px is incorrect.