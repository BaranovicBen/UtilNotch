import SwiftUI

/// Redesigned Quick Notes — compact capture, clean preview cards, hover actions, click-to-expand.
struct QuickNotesView: View {
    @Environment(AppState.self) private var appState
    @State private var newTitle: String = ""
    @State private var newBody: String = ""
    @FocusState private var isTitleFocused: Bool
    @State private var expandedNoteID: UUID?

    /// Character limits
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
            Text("\(appState.quickNotes.count) notes")
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
                    .onTapGesture { appState.isInteracting = true }
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
                        onToggleExpand: { toggleExpand(note.id) },
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
        withAnimation(.easeInOut(duration: 0.2)) {
            expandedNoteID = expandedNoteID == id ? nil : id
        }
    }

    private func delete(_ id: UUID) {
        withAnimation(.easeOut(duration: 0.2)) {
            appState.quickNotes.removeAll { $0.id == id }
        }
        if expandedNoteID == id { expandedNoteID = nil }
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
    let onToggleExpand: () -> Void
    let onConvertToTodo: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Top row: title + hover actions
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.white)
                        .lineLimit(isExpanded ? nil : 1)
                }

                Spacer(minLength: 4)

                if isHovering {
                    HStack(spacing: 6) {
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
                    .transition(.opacity)
                }
            }

            // Body preview or full body
            if !note.body.isEmpty {
                Text(note.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(isExpanded ? nil : 2)
            }

            // Timestamp
            Text(note.createdAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .accessibilityLabel(Text(note.createdAt, style: .date))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(isHovering ? 0.05 : 0.03))
        )
        .contentShape(Rectangle())
        .onTapGesture { onToggleExpand() }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }
}
