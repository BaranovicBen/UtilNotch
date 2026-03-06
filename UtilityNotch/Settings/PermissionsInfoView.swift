import SwiftUI

/// Permissions information view — displays which permissions each utility needs.
/// No real permission requests in beta — display-only.
struct PermissionsInfoView: View {
    
    var body: some View {
        Form {
            Section {
                Text("Utility Notch uses system permissions to provide certain features. If a permission is denied, the affected utility will still appear but may have limited functionality.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            
            ForEach(ModuleRegistry.allModules.filter { !$0.requiredPermissions.isEmpty }, id: \.id) { module in
                Section(module.name) {
                    ForEach(module.requiredPermissions) { perm in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.shield")
                                    .foregroundStyle(.orange)
                                Text(perm.name)
                                    .fontWeight(.medium)
                            }
                            
                            Text(perm.reason)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "gear")
                                    .font(.caption2)
                                Text("System Settings → \(perm.systemSettingsPath)")
                                    .font(.caption)
                            }
                            .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            Section("Modules with no extra permissions") {
                ForEach(ModuleRegistry.allModules.filter { $0.requiredPermissions.isEmpty }, id: \.id) { module in
                    HStack(spacing: 8) {
                        Image(systemName: module.icon)
                            .frame(width: 20)
                        Text(module.name)
                        Spacer()
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.green)
                        Text("No permissions needed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
