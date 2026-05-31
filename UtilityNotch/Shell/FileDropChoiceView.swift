import SwiftUI
import UniformTypeIdentifiers

/// Transient dual drop surface shown while the user is dragging files over the notch/panel.
/// Presents Files Tray and File Converter as two adjacent glass cards.
/// The user decides what happens to their files by where they drop — no pre-selection required.
///
/// State lifecycle:
///   `appState.isExternalFileDrag = true`  → this view appears
///   Drop on Tray   → pendingTrayURLs → selectModule("filesTray")   → isExternalFileDrag = false
///   Drop on Conv.  → pendingFileURL  → selectModule("fileConverter")→ isExternalFileDrag = false
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
                    .onDrop(of: [.fileURL], isTargeted: $isTrayTargeted, perform: handleTrayDrop)
                converterCard
                    .onDrop(of: [.fileURL], isTargeted: $isConverterTargeted, perform: handleConverterDrop)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.vertical, 4)
        .onChange(of: isTrayTargeted) { _, targeted in
            if targeted { appState.dismissalLocks.insert(.dragDrop) }
            else        { appState.dismissalLocks.remove(.dragDrop) }
        }
        .onChange(of: isConverterTargeted) { _, targeted in
            if targeted { appState.dismissalLocks.insert(.dragDrop) }
            else        { appState.dismissalLocks.remove(.dragDrop) }
        }
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

    // MARK: - Drop Handlers

    private func handleTrayDrop(_ providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()

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
            appState.isExternalFileDrag = false
            appState.preDragModuleID = nil
            appState.dismissalLocks.remove(.externalDragDrop)
            withAnimation(reduceMotion ? UNMotion.reduced : UNMotion.moduleSwitch) {
                appState.selectModule("filesTray")
            }
        }
        return true
    }

    private func handleConverterDrop(_ providers: [NSItemProvider]) -> Bool {
        // File Converter processes one file at a time. Take the first valid URL.
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil),
                  !url.hasDirectoryPath          // folders not supported by converter
            else { return }

            DispatchQueue.main.async {
                appState.pendingFileURL = url
                appState.isExternalFileDrag = false
                appState.preDragModuleID = nil
                appState.dismissalLocks.remove(.externalDragDrop)
                withAnimation(reduceMotion ? UNMotion.reduced : UNMotion.moduleSwitch) {
                    appState.selectModule("fileConverter")
                }
            }
        }
        return true
    }
}
