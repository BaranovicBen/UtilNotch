import SwiftUI

/// Right-side vertical icon rail showing enabled utility modules.
/// Takes ~1/5 of the panel width. Shows SF Symbols; clicking switches the active utility.
struct UtilityRailView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(spacing: 6) {
            ForEach(enabledModules, id: \.id) { module in
                RailButton(
                    icon: module.icon,
                    name: module.name,
                    isActive: appState.activeModuleID == module.id,
                    showLabel: appState.showHoverLabels
                ) {
                    withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                        appState.selectModule(module.id)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .frame(maxHeight: .infinity)
        .background(UNConstants.railBackground.opacity(0.5))
    }
    
    private var enabledModules: [any UtilityModule] {
        appState.enabledModuleIDs.compactMap { ModuleRegistry.module(for: $0) }
    }
}

// MARK: - Rail Button

private struct RailButton: View {
    let icon: String
    let name: String
    let isActive: Bool
    let showLabel: Bool
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Background highlight
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(backgroundColor)
                
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isActive ? UNConstants.iconActiveTint : UNConstants.iconTint)
                    .scaleEffect(isHovering ? 1.1 : 1.0)
                    .animation(.easeOut(duration: 0.15), value: isHovering)
            }
            .frame(width: 42, height: 42)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .help(name)
        .overlay(alignment: .leading) {
            // Floating label on hover (appears to the left of the rail)
            if isHovering && showLabel {
                Text(name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(white: 0.15))
                            .shadow(color: .black.opacity(0.3), radius: 4, x: -2)
                    )
                    .offset(x: -100)
                    .transition(.opacity.combined(with: .offset(x: 8)))
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeOut(duration: 0.18), value: isHovering)
    }
    
    private var backgroundColor: Color {
        if isActive {
            return UNConstants.accentHighlight
        } else if isHovering {
            return Color.white.opacity(0.06)
        }
        return .clear
    }
}
