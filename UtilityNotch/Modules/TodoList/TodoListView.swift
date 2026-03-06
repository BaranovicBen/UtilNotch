import SwiftUI

/// Todo List view — simple local list with add, delete, and toggle completion.
/// Uses local @State for beta. Replace with persistent storage later.
struct TodoListView: View {
    @State private var items: [TodoItem] = TodoItem.sampleItems
    @State private var newItemText: String = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Todo List", systemImage: "checklist")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(items.filter { !$0.isDone }.count) remaining")
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
                
                Button(action: addItem) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                .disabled(newItemText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.bottom, 10)
            
            // List
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(items) { item in
                        TodoRow(item: item, onToggle: {
                            toggleItem(item.id)
                        }, onDelete: {
                            deleteItem(item.id)
                        })
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    // MARK: - Actions
    
    private func addItem() {
        let text = newItemText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            items.insert(TodoItem(title: text), at: 0)
        }
        newItemText = ""
    }
    
    private func toggleItem(_ id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            items[idx].isDone.toggle()
        }
    }
    
    private func deleteItem(_ id: UUID) {
        withAnimation(.easeOut(duration: 0.2)) {
            items.removeAll { $0.id == id }
        }
    }
}

// MARK: - Row

private struct TodoRow: View {
    let item: TodoItem
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isDone ? .green : .secondary)
                    .font(.body)
            }
            .buttonStyle(.plain)
            
            Text(item.title)
                .strikethrough(item.isDone)
                .foregroundStyle(item.isDone ? .secondary : .primary)
                .lineLimit(1)
            
            Spacer()
            
            if isHovering {
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
    }
}

// MARK: - Model

struct TodoItem: Identifiable {
    let id = UUID()
    var title: String
    var isDone: Bool = false
    
    static let sampleItems: [TodoItem] = [
        TodoItem(title: "Design onboarding flow"),
        TodoItem(title: "Review pull requests", isDone: true),
        TodoItem(title: "Update dependencies"),
        TodoItem(title: "Write unit tests for module registry"),
        TodoItem(title: "Prepare demo for team meeting"),
    ]
}
