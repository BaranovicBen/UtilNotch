import SwiftUI

/// Center content area that displays the currently active utility module's view.
/// Lazily resolves the module from the registry each time the active ID changes.
struct ActiveModuleContainerView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        Group {
            if let module = ModuleRegistry.module(for: appState.activeModuleID) {
                module.makeMainView()
                    .id(module.id)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 6)),
                        removal: .opacity.combined(with: .offset(y: -6))
                    ))
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .animation(.easeInOut(duration: 0.25), value: appState.activeModuleID)
    }
    
    private var placeholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.dashed")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No utility selected")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
