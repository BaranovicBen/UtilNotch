import SwiftUI
import UniformTypeIdentifiers

/// Root SwiftUI view hosted inside the floating NSPanel.
/// Layout: notch-shaped top edge, center content + right utility rail, dark glass surface.
struct NotchPanelView: View {
    @Environment(AppState.self) private var appState
    @State private var isPanelDropTargeted = false
    
    var body: some View {
        // CanonicalShellView is the stable shell — it never rebuilds on module switch.
        // Only its content slot (ActiveModuleContainerView) updates when active module changes.
        CanonicalShellView {
            ActiveModuleContainerView()
        }
        .frame(width: UNConstants.panelWidth, height: UNConstants.panelHeight)
        .background {
            ZStack {
                // Base: black glass
                RoundedRectangle(cornerRadius: UNConstants.panelCornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: UNConstants.panelCornerRadius, style: .continuous)
                    .fill(UNConstants.panelBackground)
                // Ambient blue glow at top-left (DESIGN.md §3)
                RoundedRectangle(cornerRadius: UNConstants.panelCornerRadius, style: .continuous)
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                UNConstants.accentBlue.opacity(UNConstants.panelGlowOpacity),
                                Color.clear
                            ]),
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: UNConstants.panelGlowRadius
                        )
                    )
                // Ghost border (outer container specular highlight)
                RoundedRectangle(cornerRadius: UNConstants.panelCornerRadius, style: .continuous)
                    .strokeBorder(UNConstants.panelGhostBorder, lineWidth: 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: UNConstants.panelCornerRadius, style: .continuous))
        .contentShape(Rectangle())
        .onHover { hovering in
            appState.isPointerInsidePanel = hovering
        }
        .onDrop(of: [.fileURL], isTargeted: $isPanelDropTargeted) { providers in
            handlePanelDrop(providers)
        }
        .onChange(of: isPanelDropTargeted) { _, targeted in
            if targeted { appState.dismissalLocks.insert(.dragDrop) }
            else {
                appState.dismissalLocks.remove(.dragDrop)
                // Drag left the panel without a drop (cancelled) — restore previous module.
                if appState.isExternalFileDrag {
                    withAnimation(UNMotion.standard) {
                        appState.isExternalFileDrag = false
                        if let prev = appState.preDragModuleID {
                            appState.selectModule(prev)
                            appState.preDragModuleID = nil
                        }
                    }
                }
            }
        }
        .environment(\.colorScheme, .dark)
    }
    
    private func handlePanelDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                DispatchQueue.main.async {
                    // Background fallback: dropped on panel chrome outside any card.
                    // Route to Files Tray and clean up drag state.
                    appState.pendingTrayURLs.append(url)
                    appState.isExternalFileDrag = false
                    appState.preDragModuleID = nil
                    appState.selectModule("filesTray")
                    appState.showPanel()
                }
            }
        }
        return true
    }
}
