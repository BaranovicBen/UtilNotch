import AppKit
import UniformTypeIdentifiers

/// A full-screen-width invisible window sitting at the top of the screen (notch area).
/// Normally transparent to mouse events. During an external file drag it becomes active,
/// detects when files enter the notch zone, opens the panel, and captures dropped URLs.
///
/// Design:
///   - Window spans the full display width at notch height — much easier to aim at than
///     the 200pt HoverTriggerZone.
///   - `ignoresMouseEvents = true` by default — invisible to all normal interactions.
///   - Global `leftMouseDragged` monitor activates it; `leftMouseUp` deactivates it.
///   - On drop: URLs → `appState.pendingTrayURLs` (drained by FilesTrayModuleView).
@MainActor
final class FileDragReceiverZone {

    private var receiverWindow: NSWindow?
    private let appState: AppState
    private var isDragActive = false
    private var dragStartMonitor: Any?
    private var dragEndMonitor: Any?

    init(appState: AppState) {
        self.appState = appState
    }

    func install() {
        guard receiverWindow == nil else { return }
        receiverWindow = makeWindow()
        receiverWindow?.orderFrontRegardless()
        installDragStateMonitors()
    }

    func uninstall() {
        receiverWindow?.orderOut(nil)
        receiverWindow = nil
        if let m = dragStartMonitor { NSEvent.removeMonitor(m) }
        if let m = dragEndMonitor   { NSEvent.removeMonitor(m) }
        dragStartMonitor = nil
        dragEndMonitor = nil
    }

    // MARK: - Private

    private func makeWindow() -> NSWindow {
        guard let screen = NSScreen.screens.first else { return NSWindow() }

        // Full-width strip at the very top of the screen
        let frame = CGRect(
            x: screen.frame.minX,
            y: screen.frame.maxY - ScreenGeometry.triggerZoneHeight,
            width: screen.frame.width,
            height: ScreenGeometry.triggerZoneHeight
        )

        let window = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true   // off until a drag is detected
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.hasShadow = false

        let receiverView = FileDragReceiverView(
            frame: NSRect(origin: .zero, size: frame.size),
            appState: appState
        )
        window.contentView = receiverView
        return window
    }

    /// Use global event monitors to detect when the user starts/stops dragging.
    /// This is the only reliable way to toggle ignoresMouseEvents from outside
    /// the drag session without requiring accessibility permissions.
    private func installDragStateMonitors() {
        dragStartMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.isDragActive else { return }
                self.isDragActive = true
                self.receiverWindow?.ignoresMouseEvents = false
            }
        }

        dragEndMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isDragActive else { return }
                self.isDragActive = false
                self.receiverWindow?.ignoresMouseEvents = true
                self.appState.dismissalLocks.remove(.externalDragDrop)
            }
        }
    }
}

// MARK: - Drag receiver view

private class FileDragReceiverView: NSView {

    private let appState: AppState

    init(frame: NSRect, appState: AppState) {
        self.appState = appState
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: NSDraggingDestination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        Task { @MainActor in
            // Open panel and navigate to Files Tray
            appState.showPanel()
            appState.selectModule("filesTray")
            appState.dismissalLocks.insert(.externalDragDrop)
        }
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        Task { @MainActor in
            appState.dismissalLocks.remove(.externalDragDrop)
        }
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard
        guard let items = pb.readObjects(forClasses: [NSURL.self],
                                         options: [.urlReadingFileURLsOnly: true]) as? [URL],
              !items.isEmpty else { return false }

        Task { @MainActor in
            appState.pendingTrayURLs.append(contentsOf: items)
            appState.dismissalLocks.remove(.externalDragDrop)
        }
        return true
    }
}
