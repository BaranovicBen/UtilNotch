import SwiftUI

/// Clipboard History utility module — mock clipboard entries with search and copy.
/// Replace with real NSPasteboard monitoring + Accessibility permission in production.
struct ClipboardHistoryModule: UtilityModule {
    let id = "clipboardHistory"
    let name = "Clipboard History"
    let icon = "doc.on.clipboard"
    var isEnabled = true
    let supportsBackground = true
    
    var requiredPermissions: [PermissionInfo] {
        [PermissionInfo(
            id: "accessibility",
            name: "Accessibility",
            reason: "Needed to monitor clipboard changes system-wide.",
            systemSettingsPath: "Privacy & Security → Accessibility"
        )]
    }
    
    func makeMainView() -> AnyView {
        AnyView(ClipboardModuleView())
    }
    
    func makeSettingsView() -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text("Clipboard History Settings")
                    .font(.headline)
                Text("History limit, auto-clear, and exclusion rules will be configurable in production.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        )
    }
}
