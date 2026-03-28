import SwiftUI
import UniformTypeIdentifiers

/// Root SwiftUI view hosted inside the floating NSPanel.
/// Layout: notch-shaped top edge, center content + right utility rail, dark glass surface.
struct NotchPanelView: View {
    @Environment(AppState.self) private var appState
    @State private var isPanelDropTargeted = false
    
    var body: some View {
        // ModuleShellView (inside each module view) handles drag handle,
        // header, content, footer, and the 40px sidebar rail.
        ActiveModuleContainerView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                                Color(hex: "0A84FF").opacity(UNConstants.panelGlowOpacity),
                                Color.clear
                            ]),
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 300
                        )
                    )
                // Ghost border (outer container specular highlight)
                RoundedRectangle(cornerRadius: UNConstants.panelCornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
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
            else { appState.dismissalLocks.remove(.dragDrop) }
        }
        .environment(\.colorScheme, .dark)
    }
    
    private func handlePanelDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                DispatchQueue.main.async {
                    appState.pendingFileURL = url
                    appState.selectModule("fileConverter")
                    appState.showPanel()
                }
            }
        }
        return true
    }
}
