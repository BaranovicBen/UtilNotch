import SwiftUI

/// Centralized app state — single source of truth for the shell.
/// Owns: active utility, enabled utilities, panel visibility, all settings.
@Observable
final class AppState {
    
    /// Shared instance — used by both SwiftUI scenes and AppDelegate
    static let shared = AppState()
    
    // MARK: - Init / Persistence
    
    private let defaults = UserDefaults.standard
    private init() {
        if let raw = defaults.string(forKey: UserDefaultKey.menuBarSummaryMode),
           let mode = TodoSummaryMode(rawValue: raw) {
            menuBarSummaryMode = mode
        }
    }
    
    // MARK: - Panel State
    
    var isPanelVisible: Bool = false
    
    /// True when the cursor is inside the panel bounds (used to defer close while hovering within UI)
    var isPointerInsidePanel: Bool = false
    
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
        isPointerInsidePanel || isInteracting || hasActiveTask || isDraggingOver
    }
    
    // MARK: - Module State
    
    /// Currently displayed module ID
    var activeModuleID: String = "todoList"
    
    /// Ordered list of enabled module IDs (also defines rail order)
    var enabledModuleIDs: [String] = ["todoList", "quickNotes", "clipboardHistory", "musicControl", "fileConverter"]
    
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
    
    /// Preferred menu bar todo summary display mode
    var menuBarSummaryMode: TodoSummaryMode = .counts {
        didSet { defaults.set(menuBarSummaryMode.rawValue, forKey: UserDefaultKey.menuBarSummaryMode) }
    }
    
    // MARK: - Todo State (shared for menu bar)
    
    /// The todo items, shared so the menu bar can display the next pending task.
    var todoItems: [TodoItem] = TodoItem.sampleItems
    
    /// Next pending (not done) task title for menu bar display.
    var nextPendingTask: String? {
        todoItems.first(where: { !$0.isDone })?.title
    }
    
    var completedCount: Int { todoItems.filter { $0.isDone }.count }
    var remainingCount: Int { todoItems.count - completedCount }
    
    // MARK: - Quick Notes / Shared Drop Payloads
    
    var quickNotes: [QuickNote] = []
    var pendingFileURL: URL?
    
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
        isPointerInsidePanel = false
    }
    
    /// Force-hide even when interacting (e.g. user pressed Escape or hotkey).
    func forceHidePanel() {
        isPanelVisible = false
        isInteracting = false
        hasActiveTask = false
        isDraggingOver = false
        isPointerInsidePanel = false
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
    
    func summaryTextForMenuBar() -> String {
        menuBarSummaryMode.render(done: completedCount, remaining: remainingCount, next: nextPendingTask)
    }
}

// MARK: - Models / Settings

enum TodoSummaryMode: String, CaseIterable, Identifiable {
    case counts
    case countsWithNext
    case remainingWithNext
    case doneWithNext
    case nextOnly
    
    var id: String { rawValue }
    var label: String {
        switch self {
        case .counts: return "✓ 2  ○ 4"
        case .countsWithNext: return "✓ 2  ○ 4  |  Next"
        case .remainingWithNext: return "○ 4  |  Next"
        case .doneWithNext: return "✓ 2  |  Next"
        case .nextOnly: return "Next task"
        }
    }
    
    func render(done: Int, remaining: Int, next: String?) -> String {
        let truncated = next?.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextText: String? = {
            guard let truncated, !truncated.isEmpty else { return nil }
            let limit = 36
            if truncated.count > limit {
                let prefix = truncated.prefix(limit - 1)
                return "\(prefix)…"
            }
            return truncated
        }()
        switch self {
        case .counts:
            return "✓ \(done)  ○ \(remaining)"
        case .countsWithNext:
            if let nextText {
                return "✓ \(done)  ○ \(remaining)  |  \(nextText)"
            }
            return "✓ \(done)  ○ \(remaining)"
        case .remainingWithNext:
            if let nextText {
                return "○ \(remaining)  |  \(nextText)"
            }
            return remaining > 0 ? "○ \(remaining)" : "Idle"
        case .doneWithNext:
            if let nextText {
                return "✓ \(done)  |  \(nextText)"
            }
            return "✓ \(done)"
        case .nextOnly:
            if let nextText { return nextText }
            return remaining > 0 ? "Next task" : "All clear"
        }
    }
}

struct QuickNote: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var body: String
    var createdAt: Date
    
    init(id: UUID = UUID(), title: String, body: String, createdAt: Date = .init()) {
        self.id = id
        self.title = title
        self.body = body
        self.createdAt = createdAt
    }
}

private enum UserDefaultKey {
    static let menuBarSummaryMode = "menuBarSummaryMode"
}
