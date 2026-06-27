import SwiftUI
import UniformTypeIdentifiers

/// Transient drop surface shown while the user is dragging files over the notch/panel.
/// Presents the Files Tray as a single glass card. Dropping stores the files in the tray.
///
/// State lifecycle:
///   `appState.isExternalFileDrag = true`  → this view appears
///   Drop on Tray   → pendingTrayURLs → selectModule("filesTray")   → isExternalFileDrag = false
///   Drag cancelled → NotchPanelView.onChange(isPanelDropTargeted)   → isExternalFileDrag = false
struct FileDropChoiceView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isTrayTargeted = false

    var body: some View {
        VStack(spacing: 10) {
            header
            trayCard
                .onDrop(of: [.fileURL], delegate: TrayDropDelegate(
                    appState: appState,
                    isTargeted: $isTrayTargeted,
                    reduceMotion: reduceMotion
                ))
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
            Text("Keep them in the tray")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(UNConstants.textTertiary)
                .textCase(.uppercase)
        }
    }

    // MARK: - Card

    private var trayCard: some View {
        dropCard(
            icon: isTrayTargeted ? "tray.and.arrow.down.fill" : "tray",
            title: "Files Tray",
            subtitle: "Keep, move,\ncopy, or share",
            hint: isTrayTargeted ? "release to store" : "drop here",
            isTargeted: isTrayTargeted
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

// MARK: - Drop Delegate

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
        withAnimation(reduceMotion ? UNMotion.reduced : UNMotion.moduleSwitch) {
            appState.finishExternalFileDrag(selecting: "filesTray")
        }

        let providers = info.itemProviders(for: [.fileURL])
        FileURLDropLoader.load(from: providers) { urls in
            guard !urls.isEmpty else { return }
            appState.pendingTrayURLs.append(contentsOf: urls)
        }
        return true
    }
}
