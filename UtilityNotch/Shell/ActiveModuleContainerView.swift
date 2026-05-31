import SwiftUI

/// Center content area that displays the currently active utility module's view.
/// Lazily resolves the module from the registry each time the active ID changes.
struct ActiveModuleContainerView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        Group {
            if let module = ModuleRegistry.module(for: appState.activeModuleID) {
                module.makeMainView()
                    .id(module.id)
                    .transition(moduleTransition)
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .animation(reduceMotion ? UNMotion.reduced : UNMotion.contentFade, value: appState.activeModuleID)
    }

    private var moduleTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .opacity.combined(with: .offset(y: 6)),
                removal: .opacity.combined(with: .offset(y: -3))
            )
    }
    
    private var placeholder: some View {
        VStack(spacing: 6) {
            Image(systemName: "square.dashed")
                .font(.system(size: 28))
                .foregroundStyle(UNConstants.textTertiary)
            Text("no utility selected")
                .font(.caption)
                .foregroundStyle(UNConstants.textSecondary)
        }
    }
}
