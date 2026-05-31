import SwiftUI

/// Active Apps module — lists running user-facing apps for fast focus switching.
struct ActiveAppsModule: UtilityModule {
    let id = "activeApps"
    let name = "Active Apps"
    let icon = "app.badge"
    let contentTint = UNConstants.activeAppsContentTint
    var isEnabled: Bool = true
    var supportsBackground: Bool = false
    var supportsNotifications: Bool = false
    var requiredPermissions: [PermissionInfo] { [] }

    func makeMainView() -> AnyView {
        AnyView(ActiveAppsModuleView())
    }
}
