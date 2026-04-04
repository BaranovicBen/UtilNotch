import AppKit

/// Manages an invisible window at top-center of the screen that detects mouse hover.
/// When the mouse enters the zone, the panel opens after a short delay.
/// Trigger zone dimensions are derived from ScreenGeometry (notch-height-aware).
@MainActor
final class HoverTriggerZone {

    private var triggerWindow: NSWindow?
    private var appState: AppState
    private var hoverTimer: Timer?

    init(appState: AppState) {
        self.appState = appState
    }

    func install() {
        guard triggerWindow == nil else { return }
        triggerWindow = makeWindow()
        triggerWindow?.orderFrontRegardless()
    }

    /// Tear down and rebuild the trigger window with fresh ScreenGeometry.
    /// Called by NotchPanelController when display configuration changes.
    func reinstall() {
        uninstall()
        install()
    }

    func uninstall() {
        hoverTimer?.invalidate()
        triggerWindow?.orderOut(nil)
        triggerWindow = nil
    }

    // MARK: - Private

    private func makeWindow() -> NSWindow {
        let triggerFrame = CGRect(
            x: ScreenGeometry.triggerZoneOriginX,
            y: ScreenGeometry.triggerZoneOriginY,
            width: ScreenGeometry.triggerZoneWidth,
            height: ScreenGeometry.triggerZoneHeight
        )

        let window = NSWindow(
            contentRect: triggerFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = false
        // Must be above mainMenuWindow so hover events are captured in the notch area
        window.level = NSWindow.Level(
            rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 2
        )
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.hasShadow = false

        let trackingView = HoverTrackingView(
            frame: NSRect(origin: .zero, size: triggerFrame.size)
        )
        trackingView.onMouseEntered = { [weak self] in self?.handleMouseEntered() }
        trackingView.onMouseExited  = { [weak self] in self?.handleMouseExited() }

        window.contentView = trackingView
        return window
    }

    // MARK: - Hover Handling

    private func handleMouseEntered() {
        hoverTimer?.invalidate()
        hoverTimer = Timer.scheduledTimer(
            withTimeInterval: UNConstants.hoverOpenDelay,
            repeats: false
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.appState.showPanel()
            }
        }
    }

    private func handleMouseExited() {
        hoverTimer?.invalidate()
        hoverTimer = nil
    }
}

// MARK: - NSView with tracking area

private class HoverTrackingView: NSView {

    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }

        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseEntered?()
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExited?()
    }
}
