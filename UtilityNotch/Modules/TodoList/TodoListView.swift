import SwiftUI

/// Todo List view — with shared state, drag reordering, and interaction awareness.
struct TodoListView: View {
    @Environment(AppState.self) private var appState
    @State private var newItemText: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var editingID: UUID?
    @State private var draftTitle: String = ""
    @State private var draggingID: UUID?

    var body: some View {
        @Bindable var state = appState

        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Todo List", systemImage: "checklist")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(appState.todoItems.filter { !$0.isDone }.count) remaining")
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
                    .onChange(of: isInputFocused) { _, focused in appState.isInteracting = focused }
                
                Button(action: addItem) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                .disabled(newItemText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.bottom, 10)
            
            // List with drag reordering
            List {
                ForEach(appState.todoItems) { item in
                    TodoRow(
                        item: item,
                        isEditing: editingID == item.id,
                        draftTitle: editingID == item.id ? $draftTitle : .constant(item.title),
                        onBeginEdit: {
                            editingID = item.id
                            draftTitle = item.title
                            appState.isInteracting = true
                        },
                        onCommit: { title in
                            saveEdit(id: item.id, newTitle: title)
                        },
                        onCancel: {
                            editingID = nil
                            appState.isInteracting = false
                        },
                        onToggle: {
                            toggleItem(item.id)
                        },
                        onDelete: {
                            deleteItem(item.id)
                        }
                    )
                    .onDrag {
                        draggingID = item.id
                        return NSItemProvider(object: item.id.uuidString as NSString)
                    }
                    .onDrop(of: [.text], delegate: TodoDropDelegate(item: item, items: $state.todoItems, draggingID: $draggingID))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
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
        appState.isInteracting = false
    }
    
    private func toggleItem(_ id: UUID) {
        guard let idx = appState.todoItems.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            appState.todoItems[idx].isDone.toggle()
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
            appState.isInteracting = false
            return
        }
        appState.todoItems[idx].title = title
        editingID = nil
        appState.isInteracting = false
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
        .padding(.horizontal, 10)
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
    var isDone: Bool

    init(id: UUID = UUID(), title: String, isDone: Bool = false) {
        self.id = id
        self.title = title
        self.isDone = isDone
    }
}

// MARK: - Drag and Drop Delegate

private struct TodoDropDelegate: DropDelegate {
    let item: TodoItem
    @Binding var items: [TodoItem]
    @Binding var draggingID: UUID?

    func dropEntered(info: DropInfo) {
        guard let draggingID,
              draggingID != item.id,
              let from = items.firstIndex(where: { $0.id == draggingID }),
              let to = items.firstIndex(where: { $0.id == item.id }) else { return }

        withAnimation(.easeInOut(duration: 0.15)) {
            items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }

    func dropExited(info: DropInfo) {
        draggingID = nil
    }
}
