import SwiftUI

struct LiveActivitiesModule: UtilityModule {
    let id   = "liveActivities"
    let name = "Live Activities"
    let icon = "clock.badge.checkmark"
    let contentTint = UNConstants.liveActivitiesContentTint
    var isEnabled: Bool = true
    var supportsBackground: Bool = false
    var supportsNotifications: Bool = false
    var requiredPermissions: [PermissionInfo] { [] }

    func makeMainView() -> AnyView { AnyView(LiveActivitiesModuleView()) }
}
