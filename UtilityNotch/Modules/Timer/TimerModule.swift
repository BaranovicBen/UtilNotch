import SwiftUI

struct TimerModule: UtilityModule {
    let id = "timer"
    let name = "Timer"
    let icon = "timer"
    var isEnabled: Bool = true
    var supportsBackground: Bool = false
    var supportsNotifications: Bool = true
    var requiredPermissions: [PermissionInfo] { [] }

    func makeMainView() -> AnyView {
        AnyView(TimerView())
    }

    func makeSettingsView() -> AnyView? { nil }
}
