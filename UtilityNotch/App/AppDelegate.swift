import SwiftUI
import Combine

/// AppDelegate that owns the NotchPanelController and observes AppState
/// to show/hide the floating panel. Bridges SwiftUI ↔ AppKit.
final class AppDelegate: NSObject, NSApplicationDelegate {
    
    private let appState = AppState.shared
    private var panelController: NotchPanelController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        panelController = NotchPanelController(appState: appState)
        startObservingPanelVisibility()
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
    
    /// Expose panel controller for trigger system (Segment 5)
    var notchPanelController: NotchPanelController? { panelController }
}
