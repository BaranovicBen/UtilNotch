import SwiftUI
import UniformTypeIdentifiers

/// Transient dual drop surface shown while the user is dragging files over the notch/panel.
/// Presents Files Tray and File Converter as two adjacent glass cards.
/// The user decides what happens to their files by where they drop — no pre-selection required.
///
/// State lifecycle:
///   `appState.isExternalFileDrag = true`  → this view appears
///   Drop on Tray   → pendingTrayURLs → selectModule("filesTray")   → isExternalFileDrag = false
///   Drop on Conv.  → fileConverterStore.selectFile → selectModule("fileConverter") → isExternalFileDrag = false
///   Drag cancelled → NotchPanelView.onChange(isPanelDropTargeted)   → isExternalFileDrag = false
struct FileDropChoiceView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isTrayTargeted = false
    @State private var isConverterTargeted = false

    var body: some View {
        VStack(spacing: 10) {
            header
            HStack(spacing: 10) {
                trayCard
                    .onDrop(of: [.fileURL], delegate: TrayDropDelegate(
                        appState: appState,
                        isTargeted: $isTrayTargeted,
                        reduceMotion: reduceMotion
                    ))
                converterCard
                    .onDrop(of: [.fileURL], delegate: ConverterDropDelegate(
                        appState: appState,
                        isTargeted: $isConverterTargeted,
                        reduceMotion: reduceMotion
                    ))
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 2) {
            Text("Drop files")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(UNConstants.textPrimary)
            Text("Store them or convert them")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(UNConstants.textTertiary)
                .textCase(.uppercase)
        }
    }

    // MARK: - Cards

    private var trayCard: some View {
        dropCard(
            icon: isTrayTargeted ? "tray.and.arrow.down.fill" : "tray",
            title: "Files Tray",
            subtitle: "Keep, move,\ncopy, or share",
            hint: isTrayTargeted ? "release to store" : "drop here",
            isTargeted: isTrayTargeted
        )
    }

    private var converterCard: some View {
        dropCard(
            icon: isConverterTargeted ? "arrow.down.doc.fill" : "arrow.2.squarepath",
            title: "Convert",
            subtitle: "Change format\ninstantly",
            hint: isConverterTargeted ? "release to convert" : "drop here",
            isTargeted: isConverterTargeted
        )
    }

    @ViewBuilder
    private func dropCard(
        icon: String,
        title: String,
        subtitle: String,
        hint: String,
        isTargeted: Bool
    ) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(isTargeted ? UNConstants.accentBlue : UNConstants.textPlaceholder)
                .animation(reduceMotion ? nil : UNMotion.hover, value: isTargeted)
                .frame(height: 32)

            VStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(UNConstants.textPrimary)

                Text(subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(UNConstants.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Text(hint)
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(isTargeted ? UNConstants.accentBlue.opacity(0.7) : UNConstants.textTertiary)
                .textCase(.uppercase)
                .animation(reduceMotion ? nil : UNMotion.hover, value: isTargeted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(cardBackground(isTargeted: isTargeted))
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func cardBackground(isTargeted: Bool) -> some View {
        RoundedRectangle(cornerRadius: UNConstants.tileCornerRadius, style: .continuous)
            .fill(isTargeted ? UNConstants.insetSurface : UNConstants.contentLift)
            .overlay(
                RoundedRectangle(cornerRadius: UNConstants.tileCornerRadius, style: .continuous)
                    .strokeBorder(
                        Color.white.opacity(isTargeted ? 0.35 : 0.15),
                        style: StrokeStyle(
                            lineWidth: isTargeted ? 1.5 : 1,
                            dash: isTargeted ? [] : [6, 4]
                        )
                    )
            )
            .animation(reduceMotion ? nil : UNMotion.hover, value: isTargeted)
    }
}

// MARK: - Drop Delegates
// Using DropDelegate instead of the closure-based .onDrop(isTargeted:perform:) because
// SwiftUI's hover tracking doesn't reliably fire for both siblings in an HStack on macOS
// — the first sibling "wins" and the second never gets dropEntered/dropExited.
// DropDelegate gives explicit dropEntered/dropExited per view.

private struct TrayDropDelegate: DropDelegate {
    let appState: AppState
    @Binding var isTargeted: Bool
    let reduceMotion: Bool

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.fileURL])
    }

    func dropEntered(info: DropInfo) {
        isTargeted = true
        appState.dismissalLocks.insert(.dragDrop)
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
        appState.dismissalLocks.remove(.dragDrop)
    }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        appState.dismissalLocks.remove(.dragDrop)
        appState.isExternalFileDrag = false
        appState.preDragModuleID = nil
        appState.dismissalLocks.remove(.externalDragDrop)
        withAnimation(reduceMotion ? UNMotion.reduced : UNMotion.moduleSwitch) {
            appState.selectModule("filesTray")
        }

        let providers = info.itemProviders(for: [.fileURL])
        let group = DispatchGroup()
        var urls: [URL] = []
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urls.append(url)
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            guard !urls.isEmpty else { return }
            appState.pendingTrayURLs.append(contentsOf: urls)
        }
        return true
    }
}

private struct ConverterDropDelegate: DropDelegate {
    let appState: AppState
    @Binding var isTargeted: Bool
    let reduceMotion: Bool

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.fileURL])
    }

    func dropEntered(info: DropInfo) {
        isTargeted = true
        appState.dismissalLocks.insert(.dragDrop)
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
        appState.dismissalLocks.remove(.dragDrop)
    }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        appState.dismissalLocks.remove(.dragDrop)
        appState.isExternalFileDrag = false
        appState.preDragModuleID = nil
        appState.dismissalLocks.remove(.externalDragDrop)
        withAnimation(reduceMotion ? UNMotion.reduced : UNMotion.moduleSwitch) {
            appState.selectModule("fileConverter")
        }

        guard let provider = info.itemProviders(for: [.fileURL]).first else { return true }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil),
                  !url.hasDirectoryPath
            else { return }
            DispatchQueue.main.async {
                appState.fileConverterStore.selectFile(url)
            }
        }
        return true
    }
}
