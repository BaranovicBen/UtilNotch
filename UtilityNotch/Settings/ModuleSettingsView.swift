import SwiftUI

/// Module management settings — enable/disable, reorder, choose default.
struct ModuleSettingsView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        @Bindable var state = appState
        
        Form {
            Section("Enabled Utilities") {
                Text("Drag to reorder. Disabled utilities are hidden from the rail.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                List {
                    ForEach(allModulesBinding, id: \.wrappedValue.id) { $moduleEntry in
                        HStack(spacing: 12) {
                            Image(systemName: moduleEntry.icon)
                                .frame(width: 24)
                                .foregroundStyle(moduleEntry.isEnabled ? .primary : .tertiary)
                            
                            Text(moduleEntry.name)
                                .foregroundStyle(moduleEntry.isEnabled ? .primary : .secondary)
                            
                            Spacer()
                            
                            Toggle("", isOn: $moduleEntry.isEnabled)
                                .toggleStyle(.switch)
                                .labelsHidden()
                                .onChange(of: moduleEntry.isEnabled) { _, newValue in
                                    handleToggle(moduleID: moduleEntry.id, isEnabled: newValue)
                                }
                        }
                        .padding(.vertical, 2)
                    }
                    .onMove { source, destination in
                        appState.enabledModuleIDs.move(fromOffsets: source, toOffset: destination)
                    }
                }
                .frame(minHeight: 180)
            }
            
            Section("Default Utility") {
                Picker("Open panel with:", selection: $state.defaultModuleID) {
                    Text("Last used").tag(Optional<String>(nil))
                    ForEach(appState.enabledModuleIDs, id: \.self) { moduleID in
                        if let module = ModuleRegistry.module(for: moduleID) {
                            Text(module.name).tag(Optional(moduleID))
                        }
                    }
                }
            }
            
            Section("Per-Utility Settings") {
                ForEach(ModuleRegistry.allModules, id: \.id) { module in
                    if let settingsView = module.makeSettingsView() {
                        DisclosureGroup(module.name) {
                            settingsView
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
    
    // MARK: - Helpers
    
    /// Bridge between ModuleRegistry (value types) and bindings for the list.
    private var allModulesBinding: Binding<[ModuleListEntry]> {
        Binding(
            get: {
                ModuleRegistry.allModules.map { module in
                    ModuleListEntry(
                        id: module.id,
                        name: module.name,
                        icon: module.icon,
                        isEnabled: appState.enabledModuleIDs.contains(module.id)
                    )
                }
            },
            set: { entries in
                // Sync enabledModuleIDs from entries
                appState.enabledModuleIDs = entries.filter(\.isEnabled).map(\.id)
                appState.validateActiveModule()
            }
        )
    }
    
    private func handleToggle(moduleID: String, isEnabled: Bool) {
        if isEnabled {
            if !appState.enabledModuleIDs.contains(moduleID) {
                appState.enabledModuleIDs.append(moduleID)
            }
        } else {
            appState.enabledModuleIDs.removeAll { $0 == moduleID }
        }
        appState.validateActiveModule()
    }
}

// MARK: - Helper model

private struct ModuleListEntry: Identifiable {
    let id: String
    let name: String
    let icon: String
    var isEnabled: Bool
}
