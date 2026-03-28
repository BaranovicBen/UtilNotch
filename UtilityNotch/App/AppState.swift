import SwiftUI

/// Centralized app state — single source of truth for the shell.
/// Owns: active utility, enabled utilities, panel visibility, all settings.
/// Persists: todos, notes, module order, and key settings to local JSON via PersistenceManager.
@Observable
final class AppState {

    /// Shared instance — used by both SwiftUI scenes and AppDelegate
    static let shared = AppState()

    // MARK: - Init / Persistence

    private let defaults = UserDefaults.standard
    private let persistence = PersistenceManager.shared

    private init() {
        // Load persisted data
        let savedTodos = persistence.load([TodoItem].self, key: .todos)
        let savedNotes = persistence.load([QuickNote].self, key: .notes)
        let savedOrder = persistence.load([String].self, key: .moduleOrder)
        let savedSettings = persistence.load(PersistedSettings.self, key: .settings)

        // Apply todos
        _todoItems = savedTodos ?? []

        // Apply notes
        _quickNotes = savedNotes ?? []

        // Apply module order
        let defaultOrder = ["todoList", "quickNotes", "clipboardHistory", "musicControl", "fileConverter", "calendar", "filesTray"]
        _enabledModuleIDs = savedOrder ?? defaultOrder

        // Apply settings
        if let s = savedSettings {
            _menuBarSummaryMode = TodoSummaryMode(rawValue: s.menuBarSummaryMode) ?? .counts
            _showHoverLabels = s.showHoverLabels
            _inactivityTimeout = s.inactivityTimeout
            _defaultModuleID = s.defaultModuleID
            _activeModuleID = s.activeModuleID
            _showMusicWaveform = s.showMusicWaveform
            _panelStyle = PanelStyle(rawValue: s.panelStyle ?? "") ?? .expandedPanel
        } else if let raw = defaults.string(forKey: "menuBarSummaryMode"),
                  let mode = TodoSummaryMode(rawValue: raw) {
            // Migrate from old UserDefaults
            _menuBarSummaryMode = mode
        }
    }

    // MARK: - Panel State

    var isPanelVisible: Bool = false

    /// True when the cursor is inside the panel bounds (used to defer close while hovering within UI)
    var isPointerInsidePanel: Bool = false

    /// Composable lock set — modules insert/remove specific locks instead of toggling bool flags.
    var dismissalLocks: DismissalLock = []

    /// Whether the panel should resist auto-close right now (mouse-leave and inactivity).
    var shouldSuppressClose: Bool {
        isPointerInsidePanel || !dismissalLocks.isEmpty
    }

    /// Whether active work should block an explicit outside-click dismiss.
    /// `.activeEditing` does NOT block click-outside — clicking outside naturally unfocuses text fields.
    var shouldSuppressClickOutside: Bool {
        !dismissalLocks.subtracting(.activeEditing).isEmpty
    }

    // MARK: - Module State

    private var _activeModuleID: String = "todoList"
    /// Currently displayed module ID
    var activeModuleID: String {
        get { _activeModuleID }
        set { _activeModuleID = newValue; saveSettings() }
    }

    private var _enabledModuleIDs: [String] = ["todoList", "quickNotes", "clipboardHistory", "musicControl", "fileConverter", "calendar", "filesTray"]
    /// Ordered list of enabled module IDs (also defines rail order)
    var enabledModuleIDs: [String] {
        get { _enabledModuleIDs }
        set { _enabledModuleIDs = newValue; persistence.save(newValue, key: .moduleOrder) }
    }

    // MARK: - Settings

    private var _showHoverLabels: Bool = true
    var showHoverLabels: Bool {
        get { _showHoverLabels }
        set { _showHoverLabels = newValue; saveSettings() }
    }

    private var _launchAtLogin: Bool = false
    var launchAtLogin: Bool {
        get { _launchAtLogin }
        set { _launchAtLogin = newValue }
    }

    private var _inactivityTimeout: Double = 0
    var inactivityTimeout: Double {
        get { _inactivityTimeout }
        set { _inactivityTimeout = newValue; saveSettings() }
    }

    private var _defaultModuleID: String? = nil
    var defaultModuleID: String? {
        get { _defaultModuleID }
        set { _defaultModuleID = newValue; saveSettings() }
    }

    private var _menuBarSummaryMode: TodoSummaryMode = .counts
    var menuBarSummaryMode: TodoSummaryMode {
        get { _menuBarSummaryMode }
        set {
            _menuBarSummaryMode = newValue
            defaults.set(newValue.rawValue, forKey: "menuBarSummaryMode")
            saveSettings()
        }
    }

    private var _showMusicWaveform: Bool = true
    var showMusicWaveform: Bool {
        get { _showMusicWaveform }
        set { _showMusicWaveform = newValue; saveSettings() }
    }

    private var _panelStyle: PanelStyle = .expandedPanel
    /// The visual style used for the notch panel (persisted).
    var panelStyle: PanelStyle {
        get { _panelStyle }
        set { _panelStyle = newValue; saveSettings() }
    }

    // MARK: - Todo State (shared for menu bar)

    private var _todoItems: [TodoItem] = []
    var todoItems: [TodoItem] {
        get { _todoItems }
        set { _todoItems = newValue; persistence.save(newValue, key: .todos) }
    }

    var nextPendingTask: String? {
        todoItems.first(where: { !$0.isDone })?.title
    }

    var completedCount: Int { todoItems.filter { $0.isDone }.count }
    var remainingCount: Int { todoItems.count - completedCount }

    // MARK: - Module UI Metadata
    // Set by the active module view (via ModuleShellView) on appear/change.
    // Read by CanonicalShellView, which lives above the module-switching layer.
    // This is what allows the shell to be stable across module switches.

    /// Module title shown in the shell header (e.g. "Todo", not "Todo List")
    var moduleTitle: String = ""

    /// Footer left text — dynamic (e.g. "3 REMAINING") — updated on appear and on change
    var moduleFooterLeft: String = ""

    /// Footer right text — dynamic
    var moduleFooterRight: String = ""

    /// Incremented each time the module action button changes.
    /// CanonicalShellView observes this to know when to re-read the builder.
    var moduleActionButtonRevision: Int = 0

    /// Non-observable store for the current module's header action button builder.
    /// Access via moduleActionButtonBuilder; trigger a re-render by bumping moduleActionButtonRevision.
    @ObservationIgnored
    private let _moduleActionButtonStore = _ModuleActionButtonStore()

    /// The current module's action button factory closure, or nil if the module has none.
    var moduleActionButtonBuilder: (() -> AnyView)? {
        _moduleActionButtonStore.build
    }

    /// Call from a module view's onAppear to register its header action button.
    /// Pass nil if the module has no action button.
    func setModuleActionButton(_ build: (() -> AnyView)?) {
        _moduleActionButtonStore.build = build
        moduleActionButtonRevision &+= 1
    }

    // MARK: - Quick Notes / Shared Drop Payloads

    private var _quickNotes: [QuickNote] = []
    var quickNotes: [QuickNote] {
        get { _quickNotes }
        set { _quickNotes = newValue; persistence.save(newValue, key: .notes) }
    }

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
        dismissalLocks.remove(.activeEditing)
        isPointerInsidePanel = false
    }

    /// Force-hide even when interacting (e.g. user pressed Escape or hotkey).
    func forceHidePanel() {
        isPanelVisible = false
        dismissalLocks = []
        isPointerInsidePanel = false
    }

    /// Select a module; only if it's enabled. Clears activeEditing lock.
    func selectModule(_ id: String) {
        guard enabledModuleIDs.contains(id) else { return }
        if _activeModuleID != id {
            dismissalLocks.remove(.activeEditing)
        }
        _activeModuleID = id
        saveSettings()
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

    // MARK: - Settings Persistence

    private func saveSettings() {
        let snapshot = PersistedSettings(
            menuBarSummaryMode: _menuBarSummaryMode.rawValue,
            showHoverLabels: _showHoverLabels,
            inactivityTimeout: _inactivityTimeout,
            defaultModuleID: _defaultModuleID,
            activeModuleID: _activeModuleID,
            showMusicWaveform: _showMusicWaveform,
            panelStyle: _panelStyle.rawValue
        )
        persistence.save(snapshot, key: .settings)
    }
}

// MARK: - Internal helper (module action button store)

/// Reference-type store for the current module's action button builder.
/// Stored outside @Observable tracking so the closure is not diffed by the observation system.
/// CanonicalShellView triggers re-reads via AppState.moduleActionButtonRevision instead.
private final class _ModuleActionButtonStore {
    var build: (() -> AnyView)?
}

// MARK: - Dismissal Lock

/// Composable OptionSet controlling when the panel should resist being dismissed.
/// Insert/remove specific locks from modules; the panel only auto-closes when the set is empty.
struct DismissalLock: OptionSet {
    let rawValue: Int

    /// A drag-and-drop session is targeting the panel.
    static let dragDrop      = DismissalLock(rawValue: 1 << 0)
    /// A system or custom picker (color, file, date) is open in a module.
    static let pickerOpen    = DismissalLock(rawValue: 1 << 1)
    /// A long-running task is in progress (e.g. file conversion).
    static let activeConvert = DismissalLock(rawValue: 1 << 2)
    /// A text field inside a module has focus / the user is typing.
    /// NOTE: does NOT block click-outside — clicking outside naturally unfocuses the field.
    static let activeEditing = DismissalLock(rawValue: 1 << 3)
    /// A drag or gesture within module UI (list reorder, scroll momentum, etc.).
    static let moduleGesture = DismissalLock(rawValue: 1 << 4)
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
            if let nextText { return "✓ \(done)  ○ \(remaining)  |  \(nextText)" }
            return "✓ \(done)  ○ \(remaining)"
        case .remainingWithNext:
            if let nextText { return "○ \(remaining)  |  \(nextText)" }
            return remaining > 0 ? "○ \(remaining)" : "Idle"
        case .doneWithNext:
            if let nextText { return "✓ \(done)  |  \(nextText)" }
            return "✓ \(done)"
        case .nextOnly:
            if let nextText { return nextText }
            return remaining > 0 ? "Next task" : "All clear"
        }
    }
}

// MARK: - Panel Style

enum PanelStyle: String, CaseIterable, Identifiable {
    case expandedPanel = "expandedPanel"
    case dynamicIsland = "dynamicIsland"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .expandedPanel: return "Expanded Panel"
        case .dynamicIsland: return "Dynamic Island"
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

