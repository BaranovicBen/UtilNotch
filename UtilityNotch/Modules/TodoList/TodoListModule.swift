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
        AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text("Todo List Settings")
                    .font(.headline)
                Text("Local storage only in beta. Persistent storage and sync will be added later.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        )
    }
}
