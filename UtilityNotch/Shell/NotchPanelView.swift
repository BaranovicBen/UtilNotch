import SwiftUI

/// Root SwiftUI view hosted inside the floating NSPanel.
/// Layout: notch-shaped top edge, center content + right utility rail, dark glass surface.
struct NotchPanelView: View {
    @Environment(AppState.self) private var appState
    
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
        .environment(\.colorScheme, .dark)
    }
}
