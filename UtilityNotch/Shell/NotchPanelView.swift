import SwiftUI

/// Root SwiftUI view hosted inside the floating NSPanel.
/// Layout: center content area + right utility rail, on a dark glass surface.
struct NotchPanelView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        HStack(spacing: 0) {
            // Center: active module content
            ActiveModuleContainerView()
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Thin separator
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 1)
                .padding(.vertical, 10)
            
            // Right rail: utility icons (~1/5 width)
            UtilityRailView()
                .frame(width: UNConstants.panelWidth * UNConstants.railWidthFraction)
        }
        .frame(width: UNConstants.panelWidth, height: UNConstants.panelHeight)
        .background(
            RoundedRectangle(cornerRadius: UNConstants.panelCornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
        )
        .clipShape(RoundedRectangle(cornerRadius: UNConstants.panelCornerRadius, style: .continuous))
        .environment(\.colorScheme, .dark)
    }
}
