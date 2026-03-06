import SwiftUI

/// Todo List utility module — stub (fleshed out in Segment 6)
struct TodoListModule: UtilityModule {
    let id = "todoList"
    let name = "Todo List"
    let icon = "checklist"
    var isEnabled = true
    
    func makeMainView() -> AnyView {
        AnyView(Text("Todo List — coming soon").foregroundStyle(.secondary))
    }
}
