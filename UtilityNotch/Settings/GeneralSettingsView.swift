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
            
            Section("System") {
                Toggle("Launch at login", isOn: .constant(false))
                    .disabled(true)
                    .overlay(alignment: .trailing) {
                        Text("Coming soon")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 4)
                    }

                Text("Keyboard shortcut: ⌥ Space")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                // MARK: TODO — Make configurable with a shortcut recorder
            }
            
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
