import AppKit
import UniformTypeIdentifiers

/// A full-screen-width invisible window sitting at the top of the screen (notch area).
/// Detects file drags entering the notch zone, opens the panel, and captures dropped URLs.
///
/// Design:
///   - Window spans the full display width at notch height.
///   - `ignoresMouseEvents = false` always — NSDraggingDestination requires this to fire.
///     Safe because the window only covers the ~28pt notch cutout where there is no
///     interactive UI. HoverTriggerZone sits at level +2 above this window (+1), so
///     normal hover events still route to HoverTriggerZone first.
///   - On drag enter: opens panel, navigates to Files Tray, inserts .externalDragDrop lock.
///   - On drop: URLs → `appState.pendingTrayURLs` (drained by FilesTrayModuleView).
@MainActor
final class FileDragReceiverZone {

    private var receiverWindow: NSWindow?
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func install() {
        guard receiverWindow == nil else { return }
        receiverWindow = makeWindow()
        receiverWindow?.orderFrontRegardless()
    }

    func uninstall() {
        receiverWindow?.orderOut(nil)
        receiverWindow = nil
        appState.dismissalLocks.remove(.externalDragDrop)
    }

    // MARK: - Private

    private func makeWindow() -> NSWindow {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return NSWindow() }

        // Centered strip wider than the notch, extending further down for easier drag targeting.
        let zoneWidth  = ScreenGeometry.triggerZoneWidth + 50
        let zoneHeight = ScreenGeometry.triggerZoneHeight + 7

        let frame = CGRect(
            x: screen.frame.midX - zoneWidth / 2,
            y: screen.frame.maxY - zoneHeight,
            width: zoneWidth,
            height: zoneHeight
        )

        let window = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        // Must be false — NSDraggingDestination callbacks require the window to receive events.
        window.ignoresMouseEvents = false
        // One level below HoverTriggerZone (mainMenuWindow + 2) so hover events still route there.
        // macOS drag delivery iterates registered windows, so drags reach us even at the lower level.
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.hasShadow = false

        let receiverView = FileDragReceiverView(
            frame: NSRect(origin: .zero, size: frame.size),
            appState: appState
        )
        window.contentView = receiverView
        return window
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
            appState.showPanel()
            appState.selectModule("filesTray")
            appState.dismissalLocks.insert(.externalDragDrop)
        }
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        Task { @MainActor in
            appState.dismissalLocks.remove(.externalDragDrop)
        }
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard
        guard let items = pb.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL], !items.isEmpty else { return false }

        Task { @MainActor in
            appState.pendingTrayURLs.append(contentsOf: items)
            appState.dismissalLocks.remove(.externalDragDrop)
        }
        return true
    }
}
