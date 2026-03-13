import SwiftUI

/// General settings tab — global app preferences.
struct GeneralSettingsView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        @Bindable var state = appState
        
        Form {
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
            
            Section("Menu Bar") {
                Picker("Todo summary", selection: $state.menuBarSummaryMode) {
                    ForEach(TodoSummaryMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                Text("Controls the text shown in the status bar icon. Long task names are truncated.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("System") {
                Toggle("Launch at login", isOn: $state.launchAtLogin)
                // MARK: TODO — Wire to SMAppService.mainApp.register() in production
                
                Text("Keyboard shortcut: ⌥ Space")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                // MARK: TODO — Make configurable with a shortcut recorder
            }
            
            Section("About") {
                HStack {
                    Text("Utility Notch")
                        .fontWeight(.medium)
                    Spacer()
                    Text("Beta 1.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}
