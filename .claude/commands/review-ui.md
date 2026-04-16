---
allowed-tools: Read, Grep, Glob, Bash
description: Review a module's UI against emotional design principles and native UI rules
---

You are conducting a UI quality review of a UtilityNotch module. Run both lenses — emotional design and native UI correctness — then output ranked action items.

## Step 1 — Load context

Read:
- `.claude/rules/architecture.md` — dimensions, colors, animation rules
- `.claude/rules/design-tokens.md` — the exact token values to check against

## Step 2 — Identify the target

If the user named a specific file or module, read it directly.
If not, read `UtilityNotch/Modules/ModuleRegistry.swift` and ask which module to review.

Read the module's `*ModuleView.swift` and `*Module.swift`.

## Step 3 — Emotional Design Audit (Norman's Triad)

### Visceral (first impression)
- Are colors sourced from `UNConstants.*` or the defined inline opacity palette? Flag any raw hex.
- Is there a meaningful empty/placeholder state? Flag blank views.
- Do interactive elements have a pressed state (scaleEffect, opacity change)?

### Behavioral (interaction quality)
- Does every button/tap produce a visible response?
- Are animations spring-based? Flag `.linear`, `.easeIn`, `.easeOut` on user-facing actions.
- Are hover states implemented with `.easeInOut(duration: 0.15)`?
- Are DismissalLocks correctly inserted and removed for text fields, drags, pickers?

### Reflective (meaning)
- Does the footer statusLeft/statusRight text give the user meaningful feedback about their data?
- Does the action button (if any) clearly communicate what it does?

## Step 4 — Native UI Correctness Audit

- `@Environment(AppState.self)` used (not init injection)?
- Two-way bindings use `@Bindable var state = appState`?
- No `DispatchQueue.main.async` — uses `await MainActor.run` or `@MainActor`?
- `setModuleActionButton` called in `.onAppear`?
- No `ObservableObject` / `@StateObject` / `@ObservedObject`?
- Content doesn't exceed 574pt width or 282pt height?
- All font sizes match the typography table in design-tokens.md?

## Step 5 — Output

```
## UI Review: <ModuleName>

### Visceral
[findings or "✓ clean"]

### Behavioral  
[findings or "✓ clean"]

### Reflective
[findings or "✓ clean"]

### Native UI Correctness
[findings or "✓ clean"]

### Priority Actions (ranked)
1. [Most impactful fix] — file:line
2. [Next fix] — file:line
3. ...

### No issues found in
[anything that checked out cleanly]
```
