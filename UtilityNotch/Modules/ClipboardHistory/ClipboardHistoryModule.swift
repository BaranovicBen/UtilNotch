import SwiftUI

/// Clipboard History utility module — stub (fleshed out in Segment 6)
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
        AnyView(Text("Clipboard History — coming soon").foregroundStyle(.secondary))
    }
}
