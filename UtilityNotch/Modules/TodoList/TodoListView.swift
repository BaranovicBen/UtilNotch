import SwiftUI

/// Todo List — drag-reorderable with .onMove, persistence-backed, inline edit, hover delete.
struct TodoListView: View {
    @Environment(AppState.self) private var appState
    @State private var newItemText: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var editingID: UUID?
    @State private var draftTitle: String = ""

    // Demo items shown on first launch — not persisted
    private static let demoItems: [TodoItem] = [
        TodoItem(title: "Fix parser bug"),
        TodoItem(title: "Write unit tests"),
        TodoItem(title: "Ship v1.0", isDone: true)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Todo List", systemImage: "checklist")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(appState.remainingCount == 1 ? "1 remaining" : "\(appState.remainingCount) remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 12)

            // Input row
            HStack(spacing: 8) {
                TextField("Add a task…", text: $newItemText)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                    .focused($isInputFocused)
                    .onSubmit { addItem() }
                    .onChange(of: isInputFocused) { _, focused in
                        if focused { appState.dismissalLocks.insert(.activeEditing) }
                        else { appState.dismissalLocks.remove(.activeEditing) }
                    }

                Button(action: addItem) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                .disabled(newItemText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.bottom, 10)

            // List with native onMove drag reordering
            if appState.todoItems.isEmpty {
                // Demo placeholder — not persisted, read-only
                List {
                    ForEach(Self.demoItems) { item in
                        TodoRow(
                            item: item,
                            isEditing: false,
                            draftTitle: .constant(item.title),
                            onBeginEdit: {}, onCommit: { _ in }, onCancel: {},
                            onToggle: {}, onDelete: {}
                        )
                        .opacity(0.5)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            } else {
                List {
                    ForEach(appState.todoItems) { item in
                        TodoRow(
                            item: item,
                            isEditing: editingID == item.id,
                            draftTitle: editingID == item.id ? $draftTitle : .constant(item.title),
                            onBeginEdit: {
                                editingID = item.id
                                draftTitle = item.title
                                appState.dismissalLocks.insert(.activeEditing)
                            },
                            onCommit: { title in saveEdit(id: item.id, newTitle: title) },
                            onCancel: {
                                editingID = nil
                                appState.dismissalLocks.remove(.activeEditing)
                            },
                            onToggle: { toggleItem(item.id) },
                            onDelete: { deleteItem(item.id) }
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                    }
                    .onMove { source, destination in
                        var items = appState.todoItems
                        items.move(fromOffsets: source, toOffset: destination)
                        appState.todoItems = items
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Actions

    private func addItem() {
        let text = newItemText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            appState.todoItems.insert(TodoItem(title: text), at: 0)
        }
        newItemText = ""
        appState.dismissalLocks.remove(.activeEditing)
    }

    private func toggleItem(_ id: UUID) {
        guard let idx = appState.todoItems.firstIndex(where: { $0.id == id }) else { return }
        let wasAlreadyDone = appState.todoItems[idx].isDone

        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            appState.todoItems[idx].isDone.toggle()
            // When marking done, slide item to the bottom so incomplete tasks float to top.
            // Un-checking moves it back to just before the first done item (natural slot).
            if !wasAlreadyDone {
                let item = appState.todoItems.remove(at: idx)
                appState.todoItems.append(item)
            } else {
                // Move un-checked item back before first done item
                let item = appState.todoItems.remove(at: idx)
                let insertIdx = appState.todoItems.firstIndex(where: { $0.isDone }) ?? appState.todoItems.count
                appState.todoItems.insert(item, at: insertIdx)
            }
        }
    }

    private func deleteItem(_ id: UUID) {
        withAnimation(.easeOut(duration: 0.2)) {
            appState.todoItems.removeAll { $0.id == id }
        }
        if editingID == id { editingID = nil }
    }

    private func saveEdit(id: UUID, newTitle: String) {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let idx = appState.todoItems.firstIndex(where: { $0.id == id }) else {
            editingID = nil
            appState.dismissalLocks.remove(.activeEditing)
            return
        }
        appState.todoItems[idx].title = title
        editingID = nil
        appState.dismissalLocks.remove(.activeEditing)
    }
}

// MARK: - Row

private struct TodoRow: View {
    let item: TodoItem
    let isEditing: Bool
    @Binding var draftTitle: String
    let onBeginEdit: () -> Void
    let onCommit: (String) -> Void
    let onCancel: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isDone ? .green : .secondary)
                    .font(.body)
            }
            .buttonStyle(.plain)

            if isEditing {
                TextField("Edit task", text: $draftTitle)
                    .textFieldStyle(.plain)
                    .focused($isFieldFocused)
                    .onSubmit { commit() }
                    .onAppear { isFieldFocused = true }
            } else {
                Text(item.title)
                    .strikethrough(item.isDone)
                    .foregroundStyle(item.isDone ? .secondary : .primary)
                    .lineLimit(1)
                    .onTapGesture(count: 2, perform: onBeginEdit)
            }

            Spacer()

            if isHovering && !isEditing {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(isHovering ? Color.white.opacity(0.04) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .onHover { isHovering = $0 }
        .onExitCommand(perform: onCancel)
    }

    private func commit() {
        onCommit(draftTitle)
    }
}

// MARK: - Model

struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var description: String?
    var isDone: Bool

    init(id: UUID = UUID(), title: String, description: String? = nil, isDone: Bool = false) {
        self.id = id
        self.title = title
        self.description = description
        self.isDone = isDone
    }
}
