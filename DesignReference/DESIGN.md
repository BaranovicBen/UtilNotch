# Design System: The Glass Monolith



## 1. Overview & Creative North Star

**Creative North Star: The Ethereal Utility**

This design system moves away from the "utility-as-a-tool" aesthetic and toward "utility-as-an-atmosphere." It is designed to feel like an integrated part of the macOS Ventura/Sonoma ecosystem—a high-end, editorial HUD (Heads-Up Display) that feels carved from a single block of dark, frosted glass.



The system rejects the "flat" web-standard look. Instead, it embraces **Atmospheric Depth**. By using intentional asymmetry (the 40px right-aligned sidebar), high-contrast typography scales (SF Mono vs. SF Pro), and layered opacities, we create an experience that feels premium, quiet, and authoritative.



---



### 2. Colors & Surface Logic

The palette is built on a foundation of "True Dark" (`#141414`) and monochromatic white opacities. Colors like `primary` (#0A84FF) are used sparingly as surgical strikes of intent.



**The "No-Line" Rule**

Traditional 1px solid borders are strictly prohibited for sectioning. Structural boundaries must be defined by background shifts. If you need to separate content, move from `surface_container_low` to `surface_container_highest`.



**Surface Hierarchy & Nesting**

Treat the interface as a physical stack of semi-transparent materials:

- **Base Layer:** `surface` (#141414 at 70% opacity) with a 30px-40px Backdrop Blur.

- **In-set Containers:** Use `surface_container_low` (#1C1B1B) to "recede" a section (e.g., a search field).

- **Raised Elements:** Use `surface_bright` (#393939) at low opacity to "lift" an element (e.g., a hovered menu item).



**The Glass & Gradient Rule**

To prevent the UI from feeling "dead," use a subtle radial gradient on the main panel. A 5% opacity `primary` (#0A84FF) glow in the top-left corner provides a "visual soul," mimicking the way light hits a real glass pane.



---



### 3. Typography

The typography system uses a "Modern Editorial" approach, pairing the humanist curves of **SF Pro** with the technical precision of **SF Mono**.



- **Display/Header:** `SF Pro Semibold, 17px`. Use 100% white. This is your anchor.

- **Secondary Body:** `SF Pro Regular, 14px`. Use 85% white (`on_surface`).

- **Technical/Metadata:** `SF Mono Regular, 12px`. Use 70% white.

- **Micro-Labels:** `SF Mono Regular, 11px Uppercase`. Use 55% white with 0.05em letter spacing. This provides a "system-readout" feel for sidebar icons or footer stats.



---



### 4. Elevation & Depth

Depth in this system is a result of **Tonal Layering**, not shadows.



- **The Layering Principle:** To highlight an active state, do not add a shadow. Instead, increase the background opacity of the element from 5% white to 12% white.

- **Ambient "Shadows":** If an element must float (like a detached tooltip), use a 40px blur shadow with 8% opacity, tinted with the `primary` blue color rather than black.

- **The "Ghost Border" Fallback:** The main panel uses a 0.5px border at 7% white. This is not a "line"; it is a "specular highlight" that defines the edge of the glass. Never use this for internal dividers.

- **Glassmorphism:** All panels must use `backdrop-filter: blur(20px)`. This ensures that the user's wallpaper bleeds through, making the app feel native to their specific desktop environment.



---



### 5. Components



**Buttons**

- **Primary:** Background: `primary` (#0A84FF), Text: `on_primary` (White 100%). Radius: `md` (0.75rem).

- **Secondary (Ghost):** Background: 7% white, Text: 85% white. No border.

- **Tertiary:** No background. Text: `primary` (#0A84FF).



**The Sidebar (Right Column)**

- **Dimensions:** 40px width.

- **Visuals:** A 1px vertical line at 5% white opacity on the left side. Icons should be 18px, centered, using `primary` blue for the active state and 35% white for inactive.



**Input Fields**

- **Style:** Background: `surface_container_lowest` (#0E0E0E) at 40% opacity.

- **Focus State:** No "glow." Instead, change the 0.5px ghost border from 7% white to `primary` blue at 50% opacity.



**Lists & Navigation**

- **Spacing:** Use `spacing.4` (0.9rem) between items.

- **Separation:** Strictly no horizontal dividers. Use a background hover state of 5% white opacity with a 4px corner radius to indicate interactivity.



**The Utility Header**

- **Height:** 44px.

- **Layout:** `title-sm` (SF Pro Semibold 17px) centered. Primary Blue icons for "Add" or "Settings" actions, placed in the 40px sidebar zone.



---



### 6. Do's and Don'ts



**Do:**

- Use **asymmetry**. The 40px right sidebar should feel like a distinct "control strip" compared to the wider content area.

- Use **SF Mono** for any numerical data or status strings to give it a "pro-tool" aesthetic.

- Use **white opacities** to create hierarchy. Important = 100%, Secondary = 70%, Disabled = 20%.



**Don't:**

- **No Drop Shadows:** Shadows break the "HUD" glass illusion. Use background color shifts instead.

- **No 100% Opaque Backgrounds:** The app should always feel like it is "floating" over the desktop.

- **No Sharp Corners:** Stick strictly to the `20px` radius for the main panel and `md` (12px) for internal elements. Sharp corners feel "brutalist"; we are aiming for "refined."

- **No Pure Black:** Use `#141414`. Pure `#000000` kills the glass transparency effect.