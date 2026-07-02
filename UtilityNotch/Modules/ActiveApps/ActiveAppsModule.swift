import SwiftUI

/// Active Apps module — live RAM dashboard + running-app list/grid with focus-switch and force-quit.
struct ActiveAppsModule: UtilityModule {
    let id = "activeApps"
    let name = "Active Apps"
    let icon = "square.grid.2x2"
    let contentTint = UNConstants.activeAppsContentTint
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

// MARK: - Settings

private struct ActiveAppsSettingsView: View {
    @AppStorage("activeApps.viewMode")    private var viewMode = "list"
    @AppStorage("activeApps.refreshRate") private var refreshRate = 3.0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Active Apps")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            settingRow("Default view") {
                Picker("", selection: $viewMode) {
                    Text("List").tag("list")
                    Text("Grid").tag("grid")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 140)
            }

            settingRow("Refresh interval") {
                Picker("", selection: $refreshRate) {
                    Text("1 s").tag(1.0)
                    Text("3 s").tag(3.0)
                    Text("5 s").tag(5.0)
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 100)
            }

            Text("Pressure colors (Normal / Heavy / Critical) are customizable under the module color settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func settingRow<V: View>(_ label: String, @ViewBuilder content: () -> V) -> some View {
        HStack {
            Text(label).font(.system(size: 13))
            Spacer()
            content()
        }
    }
}
