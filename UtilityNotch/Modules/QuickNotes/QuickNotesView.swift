import SwiftUI

/// Minimal quick notes list with fast capture, inline edit, and handoff to Todo.
struct QuickNotesView: View {
    @Environment(AppState.self) private var appState
    @State private var newTitle: String = ""
    @State private var newBody: String = ""
    @FocusState private var isTitleFocused: Bool
    @State private var editingNoteID: UUID?
    @State private var draftTitle: String = ""
    @State private var draftBody: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            composer
            Divider().overlay(Color.white.opacity(0.08))
            notesList
            Spacer(minLength: 0)
        }
        .onAppear { appState.isInteracting = false }
    }
    
    private var header: some View {
        HStack {
            Label("Quick Notes", systemImage: "note.text")
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
        }
    }
    
    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Title", text: $newTitle)
                .textFieldStyle(.plain)
                .padding(8)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                .focused($isTitleFocused)
                .onSubmit(addNote)
                .onTapGesture { appState.isInteracting = true }
                .onChange(of: isTitleFocused) { _, focused in appState.isInteracting = focused }
            TextField("Short body", text: $newBody, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.plain)
                .padding(8)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                .onTapGesture { appState.isInteracting = true }
            HStack {
                Button(action: addNote) {
                    Label("Add", systemImage: "plus.circle.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.body)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                
                Spacer()
            }
        }
    }
    
    private var notesList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(appState.quickNotes) { note in
                NoteRow(
                    note: note,
                    isEditing: editingNoteID == note.id,
                    draftTitle: editingNoteID == note.id ? $draftTitle : .constant(note.title),
                    draftBody: editingNoteID == note.id ? $draftBody : .constant(note.body),
                    onBeginEdit: {
                        editingNoteID = note.id
                        draftTitle = note.title
                        draftBody = note.body
                        appState.isInteracting = true
                    },
                    onCommit: { title, body in
                        saveEdit(id: note.id, title: title, body: body)
                    },
                    onCancel: { editingNoteID = nil; appState.isInteracting = false },
                    onConvertToTodo: { convertToTodo(note) },
                    onDelete: { delete(note.id) }
                )
            }
        }
    }
    
    // MARK: - Actions
    
    private func addNote() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let body = newBody.trimmingCharacters(in: .whitespacesAndNewlines)
        appState.quickNotes.insert(QuickNote(title: title, body: body), at: 0)
        newTitle = ""
        newBody = ""
        appState.isInteracting = false
    }
    
    private func saveEdit(id: UUID, title: String, body: String) {
        guard let idx = appState.quickNotes.firstIndex(where: { $0.id == id }) else { return }
        appState.quickNotes[idx].title = title
        appState.quickNotes[idx].body = body
        editingNoteID = nil
        appState.isInteracting = false
    }
    
    private func delete(_ id: UUID) {
        appState.quickNotes.removeAll { $0.id == id }
        if editingNoteID == id { editingNoteID = nil }
    }
    
    private func convertToTodo(_ note: QuickNote) {
        let title = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        appState.todoItems.insert(TodoItem(title: title), at: 0)
    }
}

// MARK: - Row

private struct NoteRow: View {
    let note: QuickNote
    let isEditing: Bool
    @Binding var draftTitle: String
    @Binding var draftBody: String
    let onBeginEdit: () -> Void
    let onCommit: (String, String) -> Void
    let onCancel: () -> Void
    let onConvertToTodo: () -> Void
    let onDelete: () -> Void
    
    @FocusState private var isTitleFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isEditing {
                TextField("Title", text: $draftTitle)
                    .textFieldStyle(.plain)
                    .padding(6)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                    .focused($isTitleFocused)
                    .onSubmit { commit() }
                    .onAppear { isTitleFocused = true }
                TextField("Body", text: $draftBody, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.plain)
                    .padding(6)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                    .onSubmit { commit() }
                HStack {
                    Button("Save", action: commit)
                    Button("Cancel", role: .cancel, action: onCancel)
                    Spacer()
                }
                .font(.caption)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if !note.body.isEmpty {
                        Text(note.body)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(count: 2, perform: onBeginEdit)
            }
            HStack(spacing: 10) {
                Button("Convert to Todo", action: onConvertToTodo)
                    .font(.caption)
                Button(role: .destructive, action: onDelete) { Text("Delete") }
                    .font(.caption)
                Spacer()
                Text(note.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .onExitCommand(perform: onCancel)
    }
    
    private func commit() {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = draftBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        onCommit(title, body)
    }
}
