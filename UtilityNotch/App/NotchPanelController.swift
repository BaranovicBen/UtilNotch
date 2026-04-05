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

    /// Observer token for display configuration changes.
    private var screenObserver: Any?

    init(appState: AppState) {
        self.appState = appState
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { @MainActor [weak self] _ in
            self?.repositionPanel()
            self?.repositionTriggerZone()
        }
    }

    deinit {
        if let token = screenObserver {
            NotificationCenter.default.removeObserver(token)
        }
    }

    // MARK: - Panel Lifecycle

    func showPanel() {
        // Cancel any pending hide completion — this is the race-fix
        hideWorkItem?.cancel()
        hideWorkItem = nil

        if panel == nil {
            createPanel()
        }
        guard let panel else { return }

        // Always reset to a clean pre-show state
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0
        panel.animator().alphaValue = 0
        NSAnimationContext.endGrouping()

        repositionPanel()
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = UNConstants.animationDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func hidePanel() {
        guard let panel else { return }

        // Cancel any previous pending hide
        hideWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.panel?.orderOut(nil)
            self?.hideWorkItem = nil
        }
        hideWorkItem = workItem

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = UNConstants.animationDuration * 0.8
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            // Only order out if this hide was not cancelled by a subsequent show
            workItem.perform()
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
        let panel = NotchPanel(
            contentRect: NSRect(
                x: ScreenGeometry.panelOriginX,
                y: panelOriginY(),
                width: UNConstants.panelWidth,
                height: UNConstants.panelHeight
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
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
        hostingView.frame = panel.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(hostingView)

        self.panel = panel
    }

    /// Rebuild the panel with the new style. Call after `appState.panelStyle` changes.
    func rebuildPanel() {
        panel?.orderOut(nil)
        panel = nil
        // createPanel() is called lazily on next showPanel()
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
}
