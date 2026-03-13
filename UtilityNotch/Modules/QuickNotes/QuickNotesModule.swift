import SwiftUI

/// Lightweight Quick Notes utility — fast capture of small notes with optional handoff to Todos.
struct QuickNotesModule: UtilityModule {
    let id = "quickNotes"
    let name = "Quick Notes"
    let icon = "note.text"
    var isEnabled: Bool = true
    
    func makeMainView() -> AnyView {
        AnyView(QuickNotesView())
    }
}
