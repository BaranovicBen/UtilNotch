import SwiftUI

/// Centralized app state — single source of truth for the shell.
/// Owns: active utility, enabled utilities, panel visibility, all settings.
@Observable
final class AppState {
    
    /// Shared instance — used by both SwiftUI scenes and AppDelegate
    static let shared = AppState()
    
    // MARK: - Panel State
    
    var isPanelVisible: Bool = false
    
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
    var inactivityTimeout: Double = 8.0
    
    /// Default module shown on open (nil = last used)
    var defaultModuleID: String? = nil
    
    // MARK: - Helpers
    
    func togglePanel() {
        isPanelVisible.toggle()
    }
    
    func showPanel() {
        isPanelVisible = true
    }
    
    func hidePanel() {
        isPanelVisible = false
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
