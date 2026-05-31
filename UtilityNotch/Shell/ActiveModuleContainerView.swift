import SwiftUI

/// Center content area that displays the currently active utility module's view.
/// During an external file drag (`appState.isExternalFileDrag == true`), replaces the
/// active module with `FileDropChoiceView` — a dual Tray / Converter drop surface.
/// Lazily resolves the module from the registry each time the active ID changes.
struct ActiveModuleContainerView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        Group {
            if appState.isExternalFileDrag {
                FileDropChoiceView()
                    .transition(contentTransition)
            } else if let module = ModuleRegistry.module(for: appState.activeModuleID) {
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
        .animation(reduceMotion ? UNMotion.reduced : UNMotion.standard, value: appState.isExternalFileDrag)
    }

    private var contentTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.97)),
                removal: .opacity.combined(with: .scale(scale: 1.02))
            )
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
