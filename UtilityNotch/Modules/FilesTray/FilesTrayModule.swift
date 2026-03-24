import SwiftUI

struct FilesTrayModule: UtilityModule {
    let id = "filesTray"
    let name = "Files Tray"
    let icon = "tray"
    var isEnabled: Bool = true
    var supportsBackground: Bool = false
    var supportsNotifications: Bool = false
    var requiredPermissions: [PermissionInfo] { [] }

    func makeMainView() -> AnyView { AnyView(FilesTrayView()) }
    func makeSettingsView() -> AnyView? { AnyView(FilesTraySettingsView()) }
}
