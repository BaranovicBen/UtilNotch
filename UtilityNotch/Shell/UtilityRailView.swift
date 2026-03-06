import SwiftUI

/// Right-side vertical icon rail showing enabled utility modules.
/// Takes ~1/5 of the panel width. Shows SF Symbols; clicking switches the active utility.
struct UtilityRailView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(spacing: 4) {
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
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .frame(maxHeight: .infinity)
        .background(UNConstants.railBackground)
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
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isActive ? UNConstants.accentHighlight : Color.clear)
                    .animation(.easeInOut(duration: 0.2), value: isActive)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isActive ? UNConstants.iconActiveTint : UNConstants.iconTint)
            }
            .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .popover(isPresented: .constant(isHovering && showLabel && !isActive), arrowEdge: .leading) {
            Text(name)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
        .help(name) // native macOS tooltip fallback
    }
}
