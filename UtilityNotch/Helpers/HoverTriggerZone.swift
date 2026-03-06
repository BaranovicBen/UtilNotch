import AppKit

/// Manages an invisible window at top-center of the screen that detects mouse hover.
/// When the mouse enters the zone, the panel opens after a short delay.
/// Beta approximation — can be replaced with real notch detection later.
@MainActor
final class HoverTriggerZone {
    
    private var triggerWindow: NSWindow?
    private var trackingArea: NSTrackingArea?
    private var appState: AppState
    private var hoverTimer: Timer?
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    func install() {
        guard triggerWindow == nil else { return }
        
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let screenFrame = screen.frame
        
        let zoneWidth = UNConstants.triggerZoneWidth
        let zoneHeight = UNConstants.triggerZoneHeight
        let x = screenFrame.midX - zoneWidth / 2
        let y = screenFrame.maxY - zoneHeight // top of screen
        
        let window = NSWindow(
            contentRect: NSRect(x: x, y: y, width: zoneWidth, height: zoneHeight),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = false
        window.level = .screenSaver  // above everything
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.hasShadow = false
        
        let trackingView = HoverTrackingView(frame: NSRect(x: 0, y: 0, width: zoneWidth, height: zoneHeight))
        trackingView.onMouseEntered = { [weak self] in
            self?.handleMouseEntered()
        }
        trackingView.onMouseExited = { [weak self] in
            self?.handleMouseExited()
        }
        
        window.contentView = trackingView
        window.orderFrontRegardless()
        
        self.triggerWindow = window
    }
    
    func uninstall() {
        hoverTimer?.invalidate()
        triggerWindow?.orderOut(nil)
        triggerWindow = nil
    }
    
    // MARK: - Hover Handling
    
    private func handleMouseEntered() {
        hoverTimer?.invalidate()
        hoverTimer = Timer.scheduledTimer(withTimeInterval: UNConstants.hoverOpenDelay, repeats: false) { [weak self] _ in
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
