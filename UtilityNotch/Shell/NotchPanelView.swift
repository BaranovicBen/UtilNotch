import SwiftUI

/// Root SwiftUI view hosted inside the floating NSPanel.
/// Layout: notch-shaped top edge, center content + right utility rail, dark glass surface.
struct NotchPanelView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(spacing: 0) {
            // Notch-like pill at top center
            notchPill
            
            // Main content area
            HStack(spacing: 0) {
                // Center: active module content — properly centered
                ActiveModuleContainerView()
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Thin separator
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 0.5)
                    .padding(.vertical, 12)
                
                // Right rail: utility icons (~1/5 width)
                UtilityRailView()
                    .frame(width: UNConstants.panelWidth * UNConstants.railWidthFraction)
            }
        }
        .frame(width: UNConstants.panelWidth, height: UNConstants.panelHeight)
        .background {
            ZStack {
                // Solid dark base — prevents transparent/artifact flicker on launch
                UNConstants.panelBackground
                
                // Glass material overlay
                RoundedRectangle(cornerRadius: UNConstants.panelCornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                
                // Subtle inner border
                RoundedRectangle(cornerRadius: UNConstants.panelCornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: UNConstants.panelCornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.55), radius: 40, y: 12)
        }
        .clipShape(RoundedRectangle(cornerRadius: UNConstants.panelCornerRadius, style: .continuous))
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
}
