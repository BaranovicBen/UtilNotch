import SwiftUI

/// General settings tab — global app preferences.
struct GeneralSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    
    var body: some View {
        @Bindable var state = appState
        
        Form {
            if matches("interaction hover timeout compact expanded behavior") {
                Section("Interaction") {
                    Toggle("Show utility names on hover", isOn: $state.showHoverLabels)

                    HStack {
                        Text("Inactivity timeout")
                        Spacer()
                        Slider(value: $state.inactivityTimeout, in: 0...30, step: 1)
                            .frame(width: 160)
                        Text(state.inactivityTimeout > 0 ? "\(Int(state.inactivityTimeout))s" : "Off")
                            .foregroundStyle(.secondary)
                            .frame(width: 32, alignment: .trailing)
                            .monospacedDigit()
                    }
                }
            }
            
            if matches("system login keyboard shortcut performance") {
                Section("System") {
                    Toggle("Launch at login", isOn: $state.launchAtLogin)

                    Text(state.launchAtLoginStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Keyboard shortcut: ⌥ Space")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                    // MARK: TODO — Make configurable with a shortcut recorder
                }
            }

            if matches("privacy local first cloud accounts storage") {
                Section("Privacy") {
                    HStack(spacing: 10) {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Local-first")
                                .fontWeight(.medium)
                            Text("No account, cloud sync, or remote processing is required for core modules.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    LabeledContent("Local data") {
                        Text("tasks, notes, clipboard, files")
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("Network posture") {
                        Text("off by default")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            if matches("appearance panel style compact expanded dynamic island") {
                Section("Appearance") {
                    Picker("Panel Style", selection: $state.panelStyle) {
                        ForEach(PanelStyle.allCases) { style in
                            Text(style.label).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("Dynamic Island: hovers expand from a compact pill. Expanded Panel: always shows the full panel.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if matches("about version utility notch urnotch") {
                Section("About") {
                    HStack {
                        Text("urNotch")
                            .fontWeight(.medium)
                        Spacer()
                        Text("Beta 1.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search settings")
    }

    private func matches(_ text: String) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty || text.localizedCaseInsensitiveContains(query)
    }
}
