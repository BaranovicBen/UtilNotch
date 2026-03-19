import SwiftUI

/// Quick Notes — compact capture, clean cards, hover actions, double-click to edit, copy, exact time.
struct QuickNotesView: View {
    @Environment(AppState.self) private var appState
    @State private var newTitle: String = ""
    @State private var newBody: String = ""
    @FocusState private var isTitleFocused: Bool
    @State private var expandedNoteID: UUID?
    @State private var editingNoteID: UUID?

    private let titleLimit = 60
    private let bodyLimit = 280

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            composer
            Divider().overlay(Color.white.opacity(0.06))
            notesList
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { appState.isInteracting = false }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Label("Quick Notes", systemImage: "note.text")
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
            Text(appState.quickNotes.count == 1 ? "1 note" : "\(appState.quickNotes.count) notes")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Compact Composer

    private var composer: some View {
        HStack(spacing: 6) {
            VStack(spacing: 4) {
                TextField("Title", text: $newTitle)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                    .focused($isTitleFocused)
                    .onSubmit(addNote)
                    .onChange(of: isTitleFocused) { _, focused in appState.isInteracting = focused }
                    .onChange(of: newTitle) { _, val in
                        if val.count > titleLimit { newTitle = String(val.prefix(titleLimit)) }
                    }

                TextField("Body (optional)", text: $newBody)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                    .onTapGesture { appState.isInteracting = true }
                    .onChange(of: newBody) { _, val in
                        if val.count > bodyLimit { newBody = String(val.prefix(bodyLimit)) }
                    }
            }

            Button(action: addNote) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    // MARK: - Notes List

    private var notesList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(appState.quickNotes) { note in
                    NoteCard(
                        note: note,
                        isExpanded: expandedNoteID == note.id,
                        isEditing: editingNoteID == note.id,
                        onToggleExpand: { toggleExpand(note.id) },
                        onBeginEdit: { beginEdit(note.id) },
                        onCommitEdit: { newTitle, newBody in commitEdit(note.id, title: newTitle, body: newBody) },
                        onCancelEdit: { editingNoteID = nil; appState.isInteracting = false },
                        onCopy: { copyNote(note) },
                        onConvertToTodo: { convertToTodo(note) },
                        onDelete: { delete(note.id) }
                    )
                }
            }
        }
    }

    // MARK: - Actions

    private func addNote() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let body = newBody.trimmingCharacters(in: .whitespacesAndNewlines)
        withAnimation(.easeOut(duration: 0.2)) {
            appState.quickNotes.insert(QuickNote(title: title, body: body), at: 0)
        }
        newTitle = ""
        newBody = ""
        appState.isInteracting = false
    }

    private func toggleExpand(_ id: UUID) {
        guard editingNoteID != id else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            expandedNoteID = expandedNoteID == id ? nil : id
        }
    }

    private func beginEdit(_ id: UUID) {
        expandedNoteID = id
        editingNoteID = id
        appState.isInteracting = true
    }

    private func commitEdit(_ id: UUID, title: String, body: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty,
              let idx = appState.quickNotes.firstIndex(where: { $0.id == id }) else {
            editingNoteID = nil
            appState.isInteracting = false
            return
        }
        appState.quickNotes[idx].title = trimmedTitle
        appState.quickNotes[idx].body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        editingNoteID = nil
        appState.isInteracting = false
    }

    private func delete(_ id: UUID) {
        withAnimation(.easeOut(duration: 0.2)) {
            appState.quickNotes.removeAll { $0.id == id }
        }
        if expandedNoteID == id { expandedNoteID = nil }
        if editingNoteID == id { editingNoteID = nil; appState.isInteracting = false }
    }

    private func copyNote(_ note: QuickNote) {
        let text = note.body.isEmpty ? note.title : "\(note.title)\n\(note.body)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func convertToTodo(_ note: QuickNote) {
        let title = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        appState.todoItems.insert(TodoItem(title: title), at: 0)
    }
}

// MARK: - Note Card

private struct NoteCard: View {
    let note: QuickNote
    let isExpanded: Bool
    let isEditing: Bool
    let onToggleExpand: () -> Void
    let onBeginEdit: () -> Void
    let onCommitEdit: (String, String) -> Void
    let onCancelEdit: () -> Void
    let onCopy: () -> Void
    let onConvertToTodo: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @State private var editTitle: String = ""
    @State private var editBody: String = ""
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isEditing {
                editingContent
            } else {
                displayContent
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(isEditing ? 0.07 : isHovering ? 0.05 : 0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isEditing ? Color.white.opacity(0.12) : Color.clear, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovering = hovering }
        }
        .onTapGesture(count: 2) {
            if !isEditing {
                editTitle = note.title
                editBody = note.body
                onBeginEdit()
            }
        }
        .onTapGesture(count: 1) {
            if !isEditing { onToggleExpand() }
        }
    }

    // MARK: - Display Mode

    @ViewBuilder
    private var displayContent: some View {
        HStack(alignment: .top, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(note.title)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(isExpanded ? nil : 1)
            }

            Spacer(minLength: 4)

            if isHovering {
                hoverActions
                    .transition(.opacity)
            }
        }

        if !note.body.isEmpty {
            Text(note.body)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(isExpanded ? nil : 2)
        }

        // Exact creation time
        Text(exactTimeString(note.createdAt))
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }

    // MARK: - Edit Mode

    @ViewBuilder
    private var editingContent: some View {
        VStack(spacing: 6) {
            TextField("Title", text: $editTitle)
                .textFieldStyle(.plain)
                .font(.callout.weight(.medium))
                .focused($isTitleFocused)
                .onSubmit { onCommitEdit(editTitle, editBody) }
                .onExitCommand(perform: onCancelEdit)

            TextField("Body", text: $editBody)
                .textFieldStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
                .onSubmit { onCommitEdit(editTitle, editBody) }
                .onExitCommand(perform: onCancelEdit)

            HStack {
                Button("Cancel") { onCancelEdit() }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                Spacer()
                Button("Save") { onCommitEdit(editTitle, editBody) }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.blue)
                    .buttonStyle(.plain)
                    .disabled(editTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear { isTitleFocused = true }
    }

    // MARK: - Hover Actions

    @ViewBuilder
    private var hoverActions: some View {
        HStack(spacing: 6) {
            Button(action: onCopy) {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("Copy note")

            Button(action: onConvertToTodo) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.caption)
                    .foregroundStyle(.blue.opacity(0.8))
            }
            .buttonStyle(.plain)
            .help("Convert to Todo")

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("Delete")
        }
    }

    // MARK: - Exact Time

    private func exactTimeString(_ date: Date) -> String {
        let cal = Calendar.current
        let now = Date()

        if cal.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Today \(formatter.string(from: date))"
        } else if cal.isDateInYesterday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Yesterday \(formatter.string(from: date))"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, h:mm a"
            return formatter.string(from: date)
        }
    }
}
