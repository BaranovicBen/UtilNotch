import SwiftUI

/// Right-side vertical icon rail showing enabled utility modules.
struct UtilityRailView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(spacing: 6) {
            ForEach(enabledModules, id: \.id) { module in
                RailButton(
                    icon: module.icon,
                    name: module.name,
                    isActive: appState.activeModuleID == module.id
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
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(backgroundColor)
                
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
        .help(name) // Native macOS tooltip — clean Apple-like treatment
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
