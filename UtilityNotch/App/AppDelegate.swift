import SwiftUI
import Combine

/// AppDelegate that owns the NotchPanelController and observes AppState
/// to show/hide the floating panel. Bridges SwiftUI ↔ AppKit.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    
    private let appState = AppState.shared
    private var panelController: NotchPanelController?
    private var hoverTrigger: HoverTriggerZone?
    private var eventManager: EventTriggerManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Suppress window state restoration noise
        NSWindow.allowsAutomaticWindowTabbing = false
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        
        panelController = NotchPanelController(appState: appState)
        
        // Install hover trigger zone at top-center of screen
        hoverTrigger = HoverTriggerZone(appState: appState)
        hoverTrigger?.install()
        
        // Install all event monitors (hotkey, escape, click-outside, inactivity)
        if let panelController {
            eventManager = EventTriggerManager(appState: appState, panelController: panelController)
            eventManager?.install()
        }
        
        startObservingPanelVisibility()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        hoverTrigger?.uninstall()
        eventManager?.uninstall()
    }
    
    private func startObservingPanelVisibility() {
        // Robust observation loop: captures appState strongly (it's a singleton),
        // and ALWAYS re-registers even if self is transiently nil.
        func observe() {
            withObservationTracking {
                _ = appState.isPanelVisible
            } onChange: { [weak self] in
                Task { @MainActor in
                    self?.handlePanelVisibilityChange()
                    // ALWAYS re-register — this line must execute unconditionally
                    observe()
                }
            }
        }
        observe()
    }
    
    private func handlePanelVisibilityChange() {
        guard let panelController else { return }
        if appState.isPanelVisible {
            panelController.showPanel()
        } else {
            panelController.hidePanel()
        }
    }
    
    /// Expose panel controller for external access
    var notchPanelController: NotchPanelController? { panelController }
}
