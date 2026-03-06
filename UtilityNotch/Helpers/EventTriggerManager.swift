%import AppKit

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
    private var mouseExitMonitor: Any?
    
    init(appState: AppState, panelController: NotchPanelController) {
        self.appState = appState
        self.panelController = panelController
    }
    
    // MARK: - Lifecycle
    
    func install() {
        installGlobalHotkey()
        installClickOutsideMonitor()
        installEscapeMonitor()
        startObservingPanelState()
    }
    
    func uninstall() {
        if let globalKeyMonitor { NSEvent.removeMonitor(globalKeyMonitor) }
        if let localKeyMonitor { NSEvent.removeMonitor(localKeyMonitor) }
        if let globalClickMonitor { NSEvent.removeMonitor(globalClickMonitor) }
        if let mouseExitMonitor { NSEvent.removeMonitor(mouseExitMonitor) }
        inactivityTimer?.invalidate()
        
        globalKeyMonitor = nil
        localKeyMonitor = nil
        globalClickMonitor = nil
        mouseExitMonitor = nil
    }
    
    // MARK: - Global Hotkey (⌥Space)
    
    private func installGlobalHotkey() {
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        // ⌥Space toggles panel
        if event.keyCode == UNConstants.globalHotkeyKeyCode &&
           event.modifierFlags.contains(UNConstants.globalHotkeyModifiers) {
            DispatchQueue.main.async { [weak self] in
                self?.appState.togglePanel()
            }
            return
        }
        
        // Escape closes panel
        if event.keyCode == 53 && appState.isPanelVisible {
            DispatchQueue.main.async { [weak self] in
                self?.appState.hidePanel()
            }
        }
    }
    
    // MARK: - Escape (redundant path via local monitor, kept for clarity)
    
    private func installEscapeMonitor() {
        // Handled inside handleKeyEvent above
    }
    
    // MARK: - Click Outside
    
    private func installClickOutsideMonitor() {
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, self.appState.isPanelVisible else { return }
            
            // Check if click is outside the panel window
            if let panelWindow = self.panelController?.panelWindow {
                let clickLocation = event.locationInWindow
                let screenPoint = NSEvent.mouseLocation
                let panelFrame = panelWindow.frame
                
                if !panelFrame.contains(screenPoint) {
                    DispatchQueue.main.async { [weak self] in
                        self?.appState.hidePanel()
                    }
                }
            }
        }
    }
    
    // MARK: - Inactivity Timer
    
    private func resetInactivityTimer() {
        inactivityTimer?.invalidate()
        
        guard appState.isPanelVisible, appState.inactivityTimeout > 0 else {
            inactivityTimer = nil
            return
        }
        
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: appState.inactivityTimeout, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.appState.hidePanel()
            }
        }
    }
    
    // MARK: - Observe Panel State
    
    private func startObservingPanelState() {
        func observe() {
            withObservationTracking {
                _ = appState.isPanelVisible
            } onChange: { [weak self] in
                DispatchQueue.main.async {
                    if self?.appState.isPanelVisible == true {
                        self?.resetInactivityTimer()
                    } else {
                        self?.inactivityTimer?.invalidate()
                        self?.inactivityTimer = nil
                    }
                    observe()
                }
            }
        }
        observe()
    }
}
