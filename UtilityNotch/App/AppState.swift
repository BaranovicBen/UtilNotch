import SwiftUI

/// Centralized app state — single source of truth for the shell.
/// Owns: active utility, enabled utilities, panel visibility, all settings.
@Observable
final class AppState {
    
    /// Shared instance — used by both SwiftUI scenes and AppDelegate
    static let shared = AppState()
    
    // MARK: - Panel State
    
    var isPanelVisible: Bool = false
    
    /// True when the user is actively interacting with module UI (controls, text fields, drag, etc.)
    /// While true, auto-close signals (inactivity, click-outside) are suppressed.
    var isInteracting: Bool = false
    
    /// True when a module is performing an active task (e.g. file conversion in progress).
    /// While true, all auto-close signals are suppressed.
    var hasActiveTask: Bool = false
    
    /// True during an active drag session targeting the panel.
    var isDraggingOver: Bool = false
    
    /// Whether the panel should resist auto-close right now.
    var shouldSuppressClose: Bool {
        isInteracting || hasActiveTask || isDraggingOver
    }
    
    // MARK: - Module State
    
    /// Currently displayed module ID
    var activeModuleID: String = "todoList"
    
    /// Ordered list of enabled module IDs (also defines rail order)
    var enabledModuleIDs: [String] = ["todoList", "clipboardHistory", "musicControl", "fileConverter"]
    
    // MARK: - Settings
    
    /// Show utility name tooltip on hover in the rail
    var showHoverLabels: Bool = true
    
    /// Launch at login (placeholder — wired to SMAppService later)
    var launchAtLogin: Bool = false
    
    /// Seconds of inactivity before auto-close (0 = disabled)
    /// Only fires when shouldSuppressClose is false.
    var inactivityTimeout: Double = 0  // Disabled by default in beta
    
    /// Default module shown on open (nil = last used)
    var defaultModuleID: String? = nil
    
    // MARK: - Todo State (shared for menu bar)
    
    /// The todo items, shared so the menu bar can display the next pending task.
    var todoItems: [TodoItem] = TodoItem.sampleItems
    
    /// Next pending (not done) task title for menu bar display.
    var nextPendingTask: String? {
        todoItems.first(where: { !$0.isDone })?.title
    }
    
    // MARK: - Helpers
    
    func togglePanel() {
        isPanelVisible.toggle()
    }
    
    func showPanel() {
        isPanelVisible = true
    }
    
    func hidePanel() {
        guard !shouldSuppressClose else { return }
        isPanelVisible = false
        isInteracting = false
    }
    
    /// Force-hide even when interacting (e.g. user pressed Escape or hotkey).
    func forceHidePanel() {
        isPanelVisible = false
        isInteracting = false
        hasActiveTask = false
        isDraggingOver = false
    }
    
    /// Select a module; only if it's enabled
    func selectModule(_ id: String) {
        guard enabledModuleIDs.contains(id) else { return }
        activeModuleID = id
    }
    
    /// Ensure activeModuleID is still valid after enable/disable changes
    func validateActiveModule() {
        if !enabledModuleIDs.contains(activeModuleID) {
            activeModuleID = defaultModuleID ?? enabledModuleIDs.first ?? "todoList"
        }
    }
}
