import SwiftUI

struct FilesTrayModule: UtilityModule {
    let id = "filesTray"
    let name = "Files Tray"
    let icon = "tray"
    let contentTint = UNConstants.filesContentTint
    var isEnabled: Bool = true
    var supportsBackground: Bool = false
    var supportsNotifications: Bool = false
    var requiredPermissions: [PermissionInfo] { [] }

    func makeMainView() -> AnyView { AnyView(FilesTrayModuleView()) }
    func makeSettingsView() -> AnyView? { AnyView(FilesTraySettingsView()) }
}
