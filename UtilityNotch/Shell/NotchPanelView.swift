import SwiftUI
import UniformTypeIdentifiers

/// Root SwiftUI view hosted inside the floating NSPanel.
/// Layout: notch-shaped top edge, center content + right utility rail, dark glass surface.
struct NotchPanelView: View {
    @Environment(AppState.self) private var appState
    @State private var isPanelDropTargeted = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Notch-like pill at top center
            notchPill
            
            // Main content area
            HStack(spacing: 0) {
                // Center: active module content
                ActiveModuleContainerView()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                
                // Thin separator
                Rectangle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 0.5)
                    .padding(.vertical, 14)
                
                // Right rail: utility icons (40pt fixed width)
                UtilityRailView()
                    .frame(width: UNConstants.railWidth)
                    .padding(.vertical, 8)
            }
        }
        .frame(width: UNConstants.panelWidth, height: UNConstants.panelHeight)
        .background {
            ZStack {
                // Glass material — main visual layer
                RoundedRectangle(cornerRadius: UNConstants.panelCornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                
                // Dark tint overlay for depth
                RoundedRectangle(cornerRadius: UNConstants.panelCornerRadius, style: .continuous)
                    .fill(UNConstants.panelBackground.opacity(0.85))
                
                // Subtle inner border
                RoundedRectangle(cornerRadius: UNConstants.panelCornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: UNConstants.panelCornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.4), radius: 28, y: 8)
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
    
    /// Small pill at the top center that visually connects to the notch area.
    private var notchPill: some View {
        Capsule()
            .fill(Color.white.opacity(0.1))
            .frame(width: 36, height: 5)
            .padding(.top, 8)
            .padding(.bottom, 4)
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
