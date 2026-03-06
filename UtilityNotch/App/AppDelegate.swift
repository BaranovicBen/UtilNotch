import SwiftUI
import Combine

/// AppDelegate that owns the NotchPanelController and observes AppState
/// to show/hide the floating panel. Bridges SwiftUI ↔ AppKit.
final class AppDelegate: NSObject, NSApplicationDelegate {
    
    private let appState = AppState.shared
    private var panelController: NotchPanelController?
    private var hoverTrigger: HoverTriggerZone?
    private var eventManager: EventTriggerManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
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
        func observe() {
            withObservationTracking {
                _ = appState.isPanelVisible
            } onChange: { [weak self] in
                DispatchQueue.main.async {
                    self?.handlePanelVisibilityChange()
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
