---
name: build-native-ui
version: 1.0.0
description: |
  Native macOS UI development patterns for UtilityNotch using SwiftUI + AppKit bridging.
  Covers panel architecture, notch integration, NSWindow management, SwiftUI layout
  constraints for the 268pt content zone, Swift 6 concurrency safety, and macOS 14+
  best practices. Invoke whenever building or modifying any UI component in this project.
license: MIT
compatibility: claude-code
allowed-tools:
  - Read
  - Edit
  - Write
  - Grep
  - Glob
  - Bash
---

# Build Native UI — UtilityNotch (macOS SwiftUI + AppKit)

This skill captures the architecture patterns, layout rules, and macOS-specific techniques for building UI in UtilityNotch — a notch-panel menubar app targeting macOS 14+.

---

## Project Architecture

```
UtilityNotch/
├── App/                    # App entry, lifecycle, AppState
├── Modules/                # Feature modules (Music, Todo, Timer, etc.)
│   └── ModuleName/
│       ├── ModuleNameView.swift
│       └── ModuleNameViewModel.swift (if needed)
├── Core/
│   ├── NotchPanelController.swift   # NSWindow management
│   └── AppState.swift               # @Observable global state
└── Shared/
    └── Components/         # Reusable SwiftUI views
```

**Key constraint**: Each module's visible content zone is **268pt wide**. Anything wider will clip or overflow.

---

## State Management Rules

```swift
// Use @Observable (Swift 5.9+) for AppState
@Observable final class AppState {
    var todoItems: [TodoItem] = []
    // ...
}

// In views: use @Bindable for two-way bindings
@Bindable var appState: AppState

// Pass state via environment, not through long init chains
.environment(appState)
```

**Never use `@StateObject` + `ObservableObject` for new code** — the project uses Swift Observation (`@Observable`).

---

## NSWindow / Panel Management

UtilityNotch uses a custom `NSPanel` that sits above the menubar. Key patterns:

```swift
// NotchPanelController must be @MainActor
@MainActor final class NotchPanelController: NSObject {
    func showPanel() {
        // Always animate on main thread
        panel.setFrame(targetFrame, display: true, animate: false)
        panel.makeKeyAndOrderFront(nil)
    }
}
```

**Rules:**
- All `NSWindow`/`NSPanel` mutations → `@MainActor`
- Never store a strong reference to `NSWindow` in SwiftUI views
- Use `NSScreen.main` coordinates, not SwiftUI coordinate space, for positioning

---

## SwiftUI Layout Patterns

### The 268pt Content Zone
```swift
// Module root view — always constrain width
var body: some View {
    VStack(spacing: 0) {
        // content
    }
    .frame(width: 268)        // hard constraint
    .clipped()
}
```

### Spacing System
| Token | Value | Use |
|---|---|---|
| `.spacing2` | 2pt | icon gaps |
| `.spacing4` | 4pt | tight items |
| `.spacing8` | 8pt | list item padding |
| `.spacing12` | 12pt | section gaps |
| `.spacing16` | 16pt | panel edge padding |

Use `VStack(spacing: 8)` as the default. Never use magic numbers inline without a comment.

### Hit Target Minimums
- Buttons: minimum 44×44pt tap target (use `.contentShape(Rectangle())` to expand)
- List rows: minimum 36pt height

---

## Swift 6 Concurrency Safety

```swift
// Crossing isolation boundaries: use @MainActor or Task { @MainActor in ... }
func updateUI() async {
    let data = await fetchData()        // off main
    await MainActor.run {               // back to main
        self.items = data
    }
}

// Sendable closures: capture only value types or @MainActor-isolated refs
// Never capture NSView or NSWindow in a detached Task without @MainActor
```

**Common pitfalls already fixed in this project:**
- `NotchPanelController` is `@MainActor`
- `TodoItem` conforms to `Sendable` (it's a struct)
- Drop delegates use `@Bindable(appState).todoItems` not `$appState`

---

## Dark Mode & Vibrancy

UtilityNotch panels use vibrancy. Rules:
```swift
// Always use semantic colors, never hardcoded hex
Color.primary           // adapts light/dark
Color.secondary
Color(nsColor: .windowBackgroundColor)

// For panel backgrounds use:
.background(.ultraThinMaterial)   // preferred
.background(.regularMaterial)     // for higher contrast needs
```

Never use `Color.white` or `Color.black` directly in any panel view.

---

## Module Development Checklist

When adding a new module:
- [ ] Create `Modules/ModuleName/ModuleNameView.swift`
- [ ] Root view is constrained to `frame(width: 268)`
- [ ] State lives in `AppState` (not local `@State` unless purely ephemeral UI)
- [ ] All async work is `@MainActor`-safe
- [ ] Animations use spring physics (see `emotional-design` skill)
- [ ] Dark mode tested with `.preferredColorScheme(.dark)`
- [ ] Hit targets ≥ 44pt

---

## Build Commands

```bash
# Debug build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme UtilityNotch -configuration Debug \
  -destination 'platform=macOS' build

# Quick check
xcodebuild -scheme UtilityNotch -configuration Debug -quiet
```

---

## Common Anti-Patterns

- Using `DispatchQueue.main.async` instead of `await MainActor.run`
- Hardcoded frame sizes that don't account for the 268pt constraint
- `@StateObject` with `ObservableObject` (use `@Observable` instead)
- Magic number colors (`Color(red: 0.2, green: 0.4, blue: 0.8)`)
- Synchronous work in `task {}` modifiers without `await`
- Storing `NSWindow` as a strong var in a SwiftUI view
