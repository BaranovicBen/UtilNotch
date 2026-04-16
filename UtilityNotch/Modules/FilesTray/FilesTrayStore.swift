import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Data layer for the Files Tray module.
/// Owns: tray item collection, persistence, file picker, AirDrop sharing, selection state.
/// FilesTrayModuleView reads from this store — it never calls TrayPersistence directly.
@Observable
final class FilesTrayStore {

    // MARK: - State

    var trayItems: [TrayItem] = []
    var isSelectMode: Bool = false
    var selectedIDs: Set<UUID> = []

    // Strong references prevent ARC from releasing delegates/pickers before completion
    @ObservationIgnored private var _sharingDelegate: SharingPickerDelegate?
    @ObservationIgnored private var _sharingPicker: NSSharingServicePicker?

    // MARK: - Computed

    var selectedItems: [TrayItem] {
        trayItems.filter { selectedIDs.contains($0.id) }
    }

    // MARK: - Lifecycle

    func onAppear() {
        trayItems = TrayPersistence.load()
    }

    // MARK: - Tray actions

    /// Adds URLs to the tray, skipping duplicates. Persists immediately.
    func addURLs(_ urls: [URL]) {
        var changed = false
        for url in urls {
            guard !trayItems.contains(where: { $0.path == url.path }) else { continue }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                trayItems.append(TrayItem(url: url))
            }
            changed = true
        }
        if changed { TrayPersistence.save(trayItems) }
    }

    /// Removes a single item and persists.
    func removeItem(_ item: TrayItem) {
        selectedIDs.remove(item.id)
        withAnimation(.easeOut(duration: 0.2)) {
            trayItems.removeAll { $0.id == item.id }
        }
        TrayPersistence.save(trayItems)
    }

    /// Removes all currently selected items and exits select mode if tray becomes empty.
    func removeSelected() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.74)) {
            trayItems.removeAll { selectedIDs.contains($0.id) }
        }
        selectedIDs.removeAll()
        TrayPersistence.save(trayItems)
        if trayItems.isEmpty {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                isSelectMode = false
            }
        }
    }

    // MARK: - Selection

    func toggleSelectMode() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
            isSelectMode.toggle()
        }
        if !isSelectMode { selectedIDs.removeAll() }
    }

    func toggleSelection(_ item: TrayItem) {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
            if selectedIDs.contains(item.id) {
                selectedIDs.remove(item.id)
            } else {
                selectedIDs.insert(item.id)
            }
        }
    }

    // MARK: - File picker

    /// Opens an NSOpenPanel allowing multiple file selection.
    /// The panel is a .nonactivatingPanel, so we must activate the app first
    /// otherwise NSOpenPanel.begin() silently fails.
    func openFilePicker(appState: AppState) {
        appState.dismissalLocks.insert(.pickerOpen)
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true

        // Non-activating panel apps must activate before presenting system sheets
        NSApp.activate(ignoringOtherApps: true)

        panel.begin { [weak self] response in
            DispatchQueue.main.async {
                appState.dismissalLocks.remove(.pickerOpen)
                if response == .OK {
                    self?.addURLs(panel.urls)
                }
            }
        }
    }

    // MARK: - AirDrop / sharing

    /// Shows the system share picker anchored to `anchorView`.
    /// Shares selected items when in select mode (if any selected), otherwise shares all.
    /// Inserts .pickerOpen lock so the panel stays open while the picker is visible.
    ///
    /// Notes:
    ///   - .pickerOpen is inserted at the TOP of this function, before any anchor check,
    ///     so the panel can never close during setup due to a mouse-leave or inactivity fire.
    ///     If the guard fails, the lock is removed synchronously in that branch.
    ///   - NSSharingServicePicker does NOT require NSApp.activate — calling it causes a
    ///     synthetic activation event that races the dismissal lock on the main queue.
    ///   - Strong references to picker and delegate are held until sharingPickerDidDismiss.
    func shareItems(appState: AppState, anchorView: NSView?) {
        let items = (isSelectMode && !selectedIDs.isEmpty) ? selectedItems : trayItems
        let urls = items.compactMap { $0.resolvedURL() }
        guard !urls.isEmpty else { return }

        // Insert .pickerOpen BEFORE any anchor resolution so the panel can never
        // close during the setup phase due to a mouse-leave or inactivity fire.
        // If we bail below, the lock is removed synchronously in that branch.
        appState.dismissalLocks.insert(.pickerOpen)
        print("🔵 [Share] lock inserted — locks: \(appState.dismissalLocks.rawValue), anchorView: \(anchorView != nil), anchorWindow: \(anchorView?.window != nil)")

        let panelWindow = anchorView?.window
            ?? NSApp.windows.first(where: { $0.isVisible && $0.level.rawValue >= Int(CGWindowLevelForKey(.mainMenuWindow)) })

        let anchorIsValid = anchorView?.window != nil
        let fallbackView = panelWindow?.contentView

        guard anchorIsValid || fallbackView != nil else {
            // Can't show picker — release the lock we just inserted.
            appState.dismissalLocks.remove(.pickerOpen)
            print("🔴 [Share] guard failed — no anchor, no fallback view. Lock released.")
            return
        }

        let delegate = SharingPickerDelegate(appState: appState, store: self)
        _sharingDelegate = delegate

        let picker = NSSharingServicePicker(items: urls as [Any])
        picker.delegate = delegate
        _sharingPicker = picker

        if anchorIsValid, let view = anchorView {
            picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
        } else if let contentView = fallbackView {
            // Fallback: footer/right area where action buttons live.
            // Footer is at y=0..38 (bottom of content view in AppKit coords).
            let rect = CGRect(x: contentView.bounds.maxX - 90, y: 6, width: 60, height: 26)
            picker.show(relativeTo: rect, of: contentView, preferredEdge: .minY)
        }
    }

    /// Called by the delegate once the picker is dismissed — clears retained references.
    fileprivate func sharingPickerDidDismiss() {
        _sharingPicker = nil
        _sharingDelegate = nil
    }
}

// MARK: - Sharing picker delegate

/// Keeps .pickerOpen DismissalLock active while the NSSharingServicePicker is on screen.
/// Released when the user picks a service or dismisses the picker.
private final class SharingPickerDelegate: NSObject, NSSharingServicePickerDelegate {
    private let appState: AppState
    private weak var store: FilesTrayStore?

    init(appState: AppState, store: FilesTrayStore? = nil) {
        self.appState = appState
        self.store = store
        super.init()
        // .pickerOpen lock is inserted by shareItems() before this delegate is created.
        // Do NOT insert again here — would require two removes to clear.
    }

    func sharingServicePicker(_ picker: NSSharingServicePicker, didChoose service: NSSharingService?) {
        // Fires on both service selection and dismissal (service == nil).
        // Short delay so the panel can't close while the mouse travels back from the picker.
        print("🔵 [Share] didChoose fired — service: \(service?.title ?? "nil")")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.appState.dismissalLocks.remove(.pickerOpen)
            self?.store?.sharingPickerDidDismiss()
            print("🔵 [Share] lock released — locks: \(self?.appState.dismissalLocks.rawValue ?? -1)")
        }
    }
}
