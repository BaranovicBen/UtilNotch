import AppKit
import SwiftUI

/// Manages the floating notch panel window.
/// Uses NSPanel so the panel doesn't steal focus from the user's active app.
/// The panel is positioned at top-center of the main screen.
@MainActor
final class NotchPanelController {

    private var panel: NSPanel?
    private var appState: AppState
    private var hoverTriggerZone: HoverTriggerZone?

    /// Tracks the pending orderOut so we can cancel it if show is called mid-hide.
    private var hideWorkItem: DispatchWorkItem?

    /// Invalidates stale animation completions when show/hide calls overlap.
    private var transitionGeneration = 0

    /// Observer token for display configuration changes.
    private var screenObserver: Any?

    init(appState: AppState) {
        self.appState = appState
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.repositionPanel()
                self?.repositionTriggerZone()
            }
        }
        // DEBUG: log every app deactivation so we can correlate with panel-close events.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in }
    }

    deinit {
        if let token = screenObserver {
            NotificationCenter.default.removeObserver(token)
        }
    }

    // MARK: - Panel Lifecycle

    func showPanel() {
        transitionGeneration &+= 1
        let generation = transitionGeneration

        // Cancel any pending hide completion — this is the race-fix
        hideWorkItem?.cancel()
        hideWorkItem = nil

        if panel == nil {
            createPanel()
        }
        guard let panel else { return }

        let shouldFadeIn = !panel.isVisible || panel.alphaValue < 0.99
        repositionPanel()
        panel.alphaValue = shouldFadeIn ? 0 : 1
        panel.orderFrontRegardless()

        if appState.panelStyle == .dynamicIsland {
            panel.alphaValue = 1
        } else {
            guard shouldFadeIn else { return }

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = UNConstants.animationDuration
                // Smooth ease-out curve — premium feel on appear.
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1.0, 0.36, 1.0)
                panel.animator().alphaValue = 1
            } completionHandler: { [weak self, weak panel] in
                Task { @MainActor in
                    guard let self, generation == self.transitionGeneration else { return }
                    panel?.alphaValue = 1
                }
            }
        }
    }

    func hidePanel() {
        guard let panel else { return }

        transitionGeneration &+= 1
        let generation = transitionGeneration

        // Cancel any previous pending hide
        hideWorkItem?.cancel()

        var workItem: DispatchWorkItem!
        workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  !workItem.isCancelled,
                  generation == self.transitionGeneration,
                  !self.appState.isPanelVisible else { return }
            self.panel?.orderOut(nil)
            self.panel?.alphaValue = 1
            self.hideWorkItem = nil
        }
        hideWorkItem = workItem

        if appState.panelStyle == .dynamicIsland {
            panel.alphaValue = 1
            DispatchQueue.main.asyncAfter(
                deadline: .now() + UNConstants.dynamicIslandCloseDuration,
                execute: workItem
            )
            return
        }

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = UNConstants.animationDuration * 0.8
            // Snappy ease-in curve — keeps the close feeling responsive.
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 1.0, 1.0)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            // Only order out if this hide was not cancelled by a subsequent show
            Task { @MainActor [weak self] in
                guard let self else { return }
                if !workItem.isCancelled,
                   generation == self.transitionGeneration,
                   !self.appState.isPanelVisible {
                    workItem.perform()
                }
            }
        })
    }

    // MARK: - Positioning

    func repositionPanel() {
        guard let panel else { return }
        let origin = CGPoint(x: ScreenGeometry.panelOriginX, y: panelOriginY())
        let size = CGSize(width: UNConstants.panelWidth, height: UNConstants.panelHeight)
        panel.setFrame(CGRect(origin: origin, size: size), display: false)
    }

    /// Mode-aware Y origin for the panel window.
    /// DI: top flush with physical screen top (overlaps notch).
    /// EP: top at bottom of menu bar (fully visible below it).
    private func panelOriginY() -> CGFloat {
        let screen = ScreenGeometry.screen
        switch appState.panelStyle {
        case .dynamicIsland:
            return screen.frame.maxY - UNConstants.panelHeight
        case .expandedPanel:
            return screen.visibleFrame.maxY - UNConstants.panelHeight
        }
    }

    func repositionTriggerZone() {
        hoverTriggerZone?.reinstall()
    }

    // MARK: - Private

    private func createPanel() {
        let screen = ScreenGeometry.screen
        let panel = NotchPanel(
            contentRect: NSRect(
                x: screen.frame.midX - (UNConstants.panelWidth / 2),
                y: panelOriginY(),
                width: UNConstants.panelWidth,
                height: UNConstants.panelHeight
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        panel.isFloatingPanel = true
        // Prevent macOS from auto-hiding the panel when the app deactivates.
        // NSPanel.hidesOnDeactivate defaults to true — without this, any app-activation
        // transition (e.g. NSSharingServicePicker appearing) orders the panel out directly,
        // bypassing all dismissal lock logic in AppState.
        panel.hidesOnDeactivate = false
        // Must be above mainMenuWindow so the panel renders inside the notch area
        panel.level = NSWindow.Level(
            rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 2
        )
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // DI mode: suppress shadow — any shadow above the panel breaks the notch illusion.
        // EP mode: shadow is fine (panel floats below the menu bar).
        panel.hasShadow = appState.panelStyle != .dynamicIsland
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true

        // Choose root view based on persisted panel style
        let hostingView: NSHostingView<AnyView>
        switch appState.panelStyle {
        case .expandedPanel:
            hostingView = NSHostingView(
                rootView: AnyView(NotchPanelView().environment(appState))
            )
        case .dynamicIsland:
            hostingView = NSHostingView(
                rootView: AnyView(DynamicIslandView().environment(appState))
            )
        }
        hostingView.frame = NSRect(
            x: 0,
            y: 0,
            width: UNConstants.panelWidth,
            height: UNConstants.panelHeight
        )
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView

        self.panel = panel
    }

    /// Rebuild the panel with the new style. Call after `appState.panelStyle` changes.
    func rebuildPanel() {
        transitionGeneration &+= 1
        hideWorkItem?.cancel()
        hideWorkItem = nil
        let wasVisible = appState.isPanelVisible
        panel?.orderOut(nil)
        panel = nil
        if wasVisible {
            showPanel()
        }
    }

    /// Register the HoverTriggerZone so the controller can reposition it on display changes.
    func register(hoverTriggerZone zone: HoverTriggerZone) {
        self.hoverTriggerZone = zone
    }

    /// Access the underlying NSPanel (for trigger zone / event monitors)
    var panelWindow: NSPanel? { panel }
}

// MARK: - Custom NSPanel subclass

/// Borderless non-activating panel that allows key events to pass through.
private class NotchPanel: NSPanel {

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // Disable window state restoration — prevents restorecount.plist noise
    override class var restorableStateKeyPaths: [String] { [] }
    override class func allowedClasses(forRestorableStateKeyPath keyPath: String) -> [AnyClass] { [] }

    override func resignKey() {
        super.resignKey()
    }

    override func orderOut(_ sender: Any?) {
        super.orderOut(sender)
    }
}
