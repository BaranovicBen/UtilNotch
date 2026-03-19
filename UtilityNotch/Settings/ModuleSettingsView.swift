import SwiftUI

/// Module management settings — enable/disable, reorder, choose default.
struct ModuleSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showReorderSheet = false

    var body: some View {
        @Bindable var state = appState

        Form {
            Section {
                Text("Toggle modules on or off. Use the Reorder button to change their order in the rail.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                List {
                    ForEach(orderedModuleEntries, id: \.id) { entry in
                        moduleRow(entry: entry)
                    }
                }
                .frame(minHeight: 200)
            } header: {
                HStack {
                    Text("Enabled Utilities")
                    Spacer()
                    Button {
                        showReorderSheet = true
                    } label: {
                        Label("Reorder", systemImage: "arrow.up.arrow.down")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
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
        .sheet(isPresented: $showReorderSheet) {
            ModuleReorderSheet()
                .environment(appState)
        }
    }

    // MARK: - Helpers

    /// Modules in current enabled order (respecting enabledModuleIDs for order,
    /// plus any disabled modules appended at the end).
    private var orderedModuleEntries: [ModuleListEntry] {
        // Start with the enabled order
        var entries: [ModuleListEntry] = appState.enabledModuleIDs.compactMap { id in
            guard let module = ModuleRegistry.module(for: id) else { return nil }
            return ModuleListEntry(id: id, name: module.name, icon: module.icon, isEnabled: true)
        }
        // Append disabled modules (those in registry but not enabled)
        let enabledSet = Set(appState.enabledModuleIDs)
        for module in ModuleRegistry.allModules where !enabledSet.contains(module.id) {
            entries.append(ModuleListEntry(id: module.id, name: module.name, icon: module.icon, isEnabled: false))
        }
        return entries
    }

    @ViewBuilder
    private func moduleRow(entry: ModuleListEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: entry.icon)
                .frame(width: 24)
                .foregroundStyle(entry.isEnabled ? .primary : .tertiary)

            Text(entry.name)
                .foregroundStyle(entry.isEnabled ? .primary : .secondary)

            Spacer()

            Toggle("", isOn: Binding(
                get: { entry.isEnabled },
                set: { handleToggle(moduleID: entry.id, isEnabled: $0) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .padding(.vertical, 2)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
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
