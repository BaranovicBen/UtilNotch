import SwiftUI

/// Root SwiftUI view hosted inside the floating NSPanel.
/// Placeholder — expanded fully in Segment 4.
struct NotchPanelView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        RoundedRectangle(cornerRadius: UNConstants.panelCornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                Text("Utility Notch Panel")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            )
            .frame(width: UNConstants.panelWidth, height: UNConstants.panelHeight)
            .environment(\.colorScheme, .dark)
    }
}
