import SwiftUI

/// Active Apps module — lists running user-facing apps with force-quit capability.
struct ActiveAppsModule: UtilityModule {
    let id = "activeApps"
    let name = "Active Apps"
    let icon = "app.badge"
    var isEnabled: Bool = true
    var supportsBackground: Bool = false
    var supportsNotifications: Bool = false
    var requiredPermissions: [PermissionInfo] { [] }

    func makeMainView() -> AnyView {
        AnyView(ActiveAppsModuleView())
    }

    func makeSettingsView() -> AnyView? {
        AnyView(ActiveAppsSettingsView())
    }
}
