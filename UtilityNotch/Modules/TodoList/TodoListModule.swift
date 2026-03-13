import SwiftUI

/// Todo List utility module — local task management with add/delete/toggle.
struct TodoListModule: UtilityModule {
    let id = "todoList"
    let name = "Todo List"
    let icon = "checklist"
    var isEnabled = true
    
    func makeMainView() -> AnyView {
        AnyView(TodoListView())
    }
    
    func makeSettingsView() -> AnyView? {
        AnyView(TodoListSettingsView())
    }
}

/// Per-module settings for Todo List.
private struct TodoListSettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        VStack(alignment: .leading, spacing: 12) {
            Text("Todo List Settings")
                .font(.headline)

            Picker("Menu bar summary", selection: $state.menuBarSummaryMode) {
                ForEach(TodoSummaryMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            Text("Controls the text shown in the status bar icon. Long task names are truncated.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Local storage only in beta. Persistent storage and sync will be added later.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
