import AppKit
import SwiftUI

/// Manages the floating notch panel window.
/// Uses NSPanel so the panel doesn't steal focus from the user's active app.
/// The panel is positioned at top-center of the main screen.
@MainActor
final class NotchPanelController {
    
    private var panel: NSPanel?
    private var appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    // MARK: - Panel Lifecycle
    
    func showPanel() {
        if panel == nil {
            createPanel()
        }
        guard let panel else { return }
        
        positionPanel(panel)
        
        // Start state: invisible and slightly scaled up toward the notch
        panel.alphaValue = 0
        panel.contentView?.layer?.anchorPoint = CGPoint(x: 0.5, y: 1.0)
        panel.orderFrontRegardless()
        
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = UNConstants.animationDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }
    
    func hidePanel() {
        guard let panel else { return }
        
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = UNConstants.animationDuration * 0.8  // slightly faster close
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.panel?.orderOut(nil)
        })
    }
    
    // MARK: - Private
    
    private func createPanel() {
        let panel = NotchPanel(
            contentRect: NSRect(x: 0, y: 0,
                                width: UNConstants.panelWidth,
                                height: UNConstants.panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        
        // Host SwiftUI content
        let hostingView = NSHostingView(
            rootView: NotchPanelView()
                .environment(appState)
        )
        hostingView.frame = panel.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(hostingView)
        
        self.panel = panel
    }
    
    private func positionPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        
        // Position: top-center of screen, just below the menu bar
        let x = screenFrame.midX - (UNConstants.panelWidth / 2)
        let y = visibleFrame.maxY - UNConstants.panelHeight
        
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    /// Access the underlying NSPanel (for trigger zone / event monitors)
    var panelWindow: NSPanel? { panel }
}

// MARK: - Custom NSPanel subclass

/// Borderless non-activating panel that allows key events to pass through.
private class NotchPanel: NSPanel {
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    
    override func resignKey() {
        super.resignKey()
        // Panel lost key status — can be used for auto-close later
    }
}
