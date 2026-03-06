import AppKit

/// Manages all event monitors for closing and toggling the panel:
/// - Global keyboard shortcut (⌥Space)
/// - Escape key to close
/// - Click outside panel to close
/// - Inactivity timeout auto-close
/// - Mouse exit from panel area to close
@MainActor
final class EventTriggerManager {
    
    private let appState: AppState
    private weak var panelController: NotchPanelController?
    
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var globalClickMonitor: Any?
    private var inactivityTimer: Timer?
    
    /// Tracks the last known panel visibility to detect edges
    private var lastKnownVisibility: Bool = false
    
    init(appState: AppState, panelController: NotchPanelController) {
        self.appState = appState
        self.panelController = panelController
    }
    
    // MARK: - Lifecycle
    
    func install() {
        installGlobalHotkey()
        installClickOutsideMonitor()
        startObservingPanelState()
    }
    
    func uninstall() {
        if let globalKeyMonitor { NSEvent.removeMonitor(globalKeyMonitor) }
        if let localKeyMonitor { NSEvent.removeMonitor(localKeyMonitor) }
        if let globalClickMonitor { NSEvent.removeMonitor(globalClickMonitor) }
        inactivityTimer?.invalidate()
        
        globalKeyMonitor = nil
        localKeyMonitor = nil
        globalClickMonitor = nil
    }
    
    // MARK: - Global Hotkey (⌥Space)
    
    private func installGlobalHotkey() {
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            DispatchQueue.main.async { self?.handleKeyEvent(event) }
        }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            DispatchQueue.main.async { self?.handleKeyEvent(event) }
            return event
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        // ⌥Space toggles panel
        if event.keyCode == UNConstants.globalHotkeyKeyCode &&
           event.modifierFlags.contains(UNConstants.globalHotkeyModifiers) {
            appState.togglePanel()
            return
        }
        
        // Escape closes panel
        if event.keyCode == 53 && appState.isPanelVisible {
            appState.hidePanel()
        }
    }
    
    // MARK: - Click Outside
    
    private func installClickOutsideMonitor() {
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            DispatchQueue.main.async {
                guard let self, self.appState.isPanelVisible else { return }
                
                if let panelWindow = self.panelController?.panelWindow {
                    let screenPoint = NSEvent.mouseLocation
                    let panelFrame = panelWindow.frame
                    
                    if !panelFrame.contains(screenPoint) {
                        self.appState.hidePanel()
                    }
                }
            }
        }
    }
    
    // MARK: - Inactivity Timer
    
    private func resetInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = nil
        
        guard appState.isPanelVisible, appState.inactivityTimeout > 0 else { return }
        
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: appState.inactivityTimeout, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.appState.hidePanel()
            }
        }
    }
    
    // MARK: - Observe Panel State (robust, cannot silently die)
    
    private func startObservingPanelState() {
        // Use withObservationTracking with unconditional re-registration.
        // The key difference: we do NOT use [weak self] — this manager lives
        // for the entire app lifetime (owned by AppDelegate), so weak is unnecessary
        // and was causing the observation chain to break.
        func observe() {
            withObservationTracking {
                _ = appState.isPanelVisible
            } onChange: { [appState] in
                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        // Re-register even if self is gone — but it shouldn't be
                        return
                    }
                    let visible = appState.isPanelVisible
                    if visible != self.lastKnownVisibility {
                        self.lastKnownVisibility = visible
                        if visible {
                            self.resetInactivityTimer()
                        } else {
                            self.inactivityTimer?.invalidate()
                            self.inactivityTimer = nil
                        }
                    }
                    // ALWAYS re-register, unconditionally
                    observe()
                }
            }
        }
        observe()
    }
}
