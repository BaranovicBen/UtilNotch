import SwiftUI
import Combine

/// AppDelegate that owns the NotchPanelController and observes AppState
/// to show/hide the floating panel. Bridges SwiftUI ↔ AppKit.

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    
    private let appState = AppState.shared
    private var panelController: NotchPanelController?
    private var hoverTrigger: HoverTriggerZone?
    private var fileDragReceiver: FileDragReceiverZone?
    private var eventManager: EventTriggerManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Suppress window state restoration noise
        NSWindow.allowsAutomaticWindowTabbing = false
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        
        panelController = NotchPanelController(appState: appState)

        // Install hover trigger zone at top-center of screen
        hoverTrigger = HoverTriggerZone(appState: appState)
        hoverTrigger?.install()

        // Install full-width drag receiver — always present, activates during file drags
        fileDragReceiver = FileDragReceiverZone(appState: appState)
        fileDragReceiver?.install()

        // Install all event monitors (hotkey, escape, click-outside, inactivity)
        if let panelController {
            eventManager = EventTriggerManager(appState: appState, panelController: panelController)
            eventManager?.install()
        }

        startMusicOnlyIfPlaybackIsActive()
        
        startObservingPanelVisibility()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        hoverTrigger?.uninstall()
        fileDragReceiver?.uninstall()
        eventManager?.uninstall()
    }
    
    private func startObservingPanelVisibility() {
        // Robust observation loop: captures appState strongly (it's a singleton),
        // and ALWAYS re-registers even if self is transiently nil.
        func observe() {
            withObservationTracking {
                _ = appState.isPanelVisible
                _ = appState.panelPresentationRevision
            } onChange: { [weak self] in
                Task { @MainActor in
                    self?.handlePanelVisibilityChange()
                    // ALWAYS re-register — this line must execute unconditionally
                    observe()
                }
            }
        }
        observe()
        startObservingPanelStyle()
    }

    private func startObservingPanelStyle() {
        func observe() {
            withObservationTracking {
                _ = appState.panelStyle
            } onChange: { [weak self] in
                Task { @MainActor in
                    // Rebuild panel so next show uses the new style
                    self?.panelController?.rebuildPanel()
                    observe()
                }
            }
        }
        observe()
    }
    
    private func handlePanelVisibilityChange() {
        guard let panelController else { return }
        if appState.isPanelVisible {
            // Make the trigger zone transparent to drag events while the panel is open.
            // HoverTriggerZone and the panel share the same window level (mainMenuWindow+2).
            // With two same-level windows overlapping, macOS drag IPC can route a drop to
            // the wrong window — causing kDragIPCLeaveApplication while the panel's drop
            // delegate fires simultaneously (reentrant conflict). Passthrough eliminates
            // the conflict: the trigger zone is only needed to open the panel, and it
            // already is open, so it doesn't need to receive any events.
            hoverTrigger?.setPassthrough(true)
            panelController.showPanel()
        } else {
            panelController.hidePanel()
            hoverTrigger?.setPassthrough(false)
        }
    }

    private func startMusicOnlyIfPlaybackIsActive() {
        guard appState.enabledModuleIDs.contains("musicControl") else { return }
        Task { @MainActor in
            if let state = await MusicStartupProbe.activePlaybackState() {
                MusicOrchestrator.shared.seedStartupState(state)
            }
        }
    }
    
    /// Expose panel controller for external access
    var notchPanelController: NotchPanelController? { panelController }
}
