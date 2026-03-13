import AppKit

/// Manages all event monitors for closing and toggling the panel:
/// - Global keyboard shortcut (⌥Space) — always toggles
/// - Escape key — force-closes
/// - Click outside panel — closes only if not interacting
/// - Mouse leave panel area — primary close signal (with grace period)
/// - Inactivity timeout — only when idle and not suppressed
@MainActor
final class EventTriggerManager {
    
    private let appState: AppState
    private weak var panelController: NotchPanelController?
    
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var globalClickMonitor: Any?
    private var mouseMoveMonitor: Any?
    private var inactivityTimer: Timer?
    private var mouseLeaveTimer: Timer?
    
    private var lastKnownVisibility: Bool = false
    
    /// Grace period before closing after mouse leaves the panel area
    private let mouseLeaveGracePeriod: TimeInterval = 0.6
    
    init(appState: AppState, panelController: NotchPanelController) {
        self.appState = appState
        self.panelController = panelController
    }
    
    // MARK: - Lifecycle
    
    func install() {
        installGlobalHotkey()
        installClickOutsideMonitor()
        installMouseTrackingMonitor()
        startObservingPanelState()
    }
    
    func uninstall() {
        if let globalKeyMonitor { NSEvent.removeMonitor(globalKeyMonitor) }
        if let localKeyMonitor { NSEvent.removeMonitor(localKeyMonitor) }
        if let globalClickMonitor { NSEvent.removeMonitor(globalClickMonitor) }
        if let mouseMoveMonitor { NSEvent.removeMonitor(mouseMoveMonitor) }
        inactivityTimer?.invalidate()
        mouseLeaveTimer?.invalidate()
        
        globalKeyMonitor = nil
        localKeyMonitor = nil
        globalClickMonitor = nil
        mouseMoveMonitor = nil
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
        // ⌥Space toggles panel (force — ignores interaction lock)
        if event.keyCode == UNConstants.globalHotkeyKeyCode &&
           event.modifierFlags.contains(UNConstants.globalHotkeyModifiers) {
            if appState.isPanelVisible {
                appState.forceHidePanel()
            } else {
                appState.showPanel()
            }
            return
        }
        
        // Escape force-closes panel
        if event.keyCode == 53 && appState.isPanelVisible {
            appState.forceHidePanel()
        }
    }
    
    // MARK: - Click Outside
    
    private func installClickOutsideMonitor() {
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            DispatchQueue.main.async {
                guard let self, self.appState.isPanelVisible else { return }
                // Only block click-outside for active interaction/task/drag — not pointer position
                guard !self.appState.shouldSuppressClickOutside else { return }
                
                if let panelWindow = self.panelController?.panelWindow {
                    let screenPoint = NSEvent.mouseLocation
                    if !panelWindow.frame.contains(screenPoint) {
                        self.appState.isPanelVisible = false
                        self.appState.isInteracting = false
                        self.appState.isPointerInsidePanel = false
                    }
                }
            }
        }
    }
    
    // MARK: - Mouse Leave Detection (primary close signal)
    
    private func installMouseTrackingMonitor() {
        mouseMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] _ in
            DispatchQueue.main.async {
                self?.checkMousePosition()
            }
        }
    }
    
    private func checkMousePosition() {
        guard appState.isPanelVisible else {
            mouseLeaveTimer?.invalidate()
            mouseLeaveTimer = nil
            appState.isPointerInsidePanel = false
            return
        }
        
        guard let panelWindow = panelController?.panelWindow else { return }
        
        let mouseLocation = NSEvent.mouseLocation
        // Expand the panel frame slightly for a generous hit area
        let expandedFrame = panelWindow.frame.insetBy(dx: -12, dy: -12)
        appState.isPointerInsidePanel = expandedFrame.contains(mouseLocation)
        
        if appState.isPointerInsidePanel {
            // Mouse is inside — cancel any pending close
            mouseLeaveTimer?.invalidate()
            mouseLeaveTimer = nil
        } else {
            // Mouse is outside — start grace period if not already started
            if mouseLeaveTimer == nil && !appState.shouldSuppressClose {
                mouseLeaveTimer = Timer.scheduledTimer(withTimeInterval: mouseLeaveGracePeriod, repeats: false) { [weak self] _ in
                    DispatchQueue.main.async {
                        guard let self else { return }
                        // Double-check: still outside and not suppressed?
                        if let pw = self.panelController?.panelWindow {
                            let pos = NSEvent.mouseLocation
                            let frame = pw.frame.insetBy(dx: -12, dy: -12)
                            if !frame.contains(pos) && !self.appState.shouldSuppressClose {
                                self.appState.hidePanel()
                            }
                        }
                        self.mouseLeaveTimer = nil
                    }
                }
            }
        }
    }
    
    // MARK: - Inactivity Timer
    
    private func resetInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = nil
        
        guard appState.isPanelVisible,
              appState.inactivityTimeout > 0,
              !appState.shouldSuppressClose else { return }
        
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: appState.inactivityTimeout, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, !self.appState.shouldSuppressClose else { return }
                self.appState.hidePanel()
            }
        }
    }
    
    // MARK: - Observe Panel State
    
    private func startObservingPanelState() {
        func observe() {
            withObservationTracking {
                _ = appState.isPanelVisible
                _ = appState.shouldSuppressClose
            } onChange: { [appState] in
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    let visible = appState.isPanelVisible
                    if visible != self.lastKnownVisibility {
                        self.lastKnownVisibility = visible
                        if visible {
                            self.resetInactivityTimer()
                        } else {
                            self.inactivityTimer?.invalidate()
                            self.inactivityTimer = nil
                            self.mouseLeaveTimer?.invalidate()
                            self.mouseLeaveTimer = nil
                        }
                    } else if !appState.shouldSuppressClose {
                        self.resetInactivityTimer()
                    }
                    observe()
                }
            }
        }
        observe()
    }
}
