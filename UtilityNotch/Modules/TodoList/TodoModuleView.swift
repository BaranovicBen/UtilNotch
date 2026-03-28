import SwiftUI

/// Todo module — full-shell Figma implementation, wired to AppState.
/// CSS source: /DesignReference/Css/todo.css
struct TodoModuleView: View {
    @Environment(AppState.self) private var appState
    @State private var showAddInput: Bool = false
    @State private var newTaskText: String = ""
    @FocusState private var isNewTaskFocused: Bool
    @State private var editingID: UUID? = nil
    @State private var editDraft: String = ""

    // Dummy tasks shown when data source is empty
    private static let dummyTasks: [(text: String, timestamp: String, isDone: Bool)] = [
        (text: "Fix parser bug",           timestamp: "09:41", isDone: false),
        (text: "Write unit tests",          timestamp: "10:15", isDone: false),
        (text: "Review pull request #42",   timestamp: "11:03", isDone: false),
        (text: "Update dependencies",       timestamp: "08:30", isDone: true),
        (text: "Ship v1.0 release notes",   timestamp: "08:00", isDone: true),
    ]

    private var isUsingDummy: Bool { appState.todoItems.isEmpty }
    private var completedCount: Int { isUsingDummy ? 2 : appState.completedCount }
    private var remainingCount: Int { isUsingDummy ? 3 : appState.remainingCount }

    var body: some View {
        ModuleShellView(
            moduleTitle: "Todo",
            moduleIcon: "checklist",
            modules: shellNavItems(appState: appState),
            activeModuleID: appState.activeModuleID,
            onModuleSelect: { id in
                withAnimation(.spring(duration: 0.28, bounce: 0.16)) {
                    appState.selectModule(id)
                }
            },
            statusDotColor: Color.white.opacity(0.2),
            statusLeft: "\(completedCount) COMPLETED TODAY",
            statusRight: "\(remainingCount) REMAINING",
            actionButton: {
                AnyView(
                    Button {
                        showAddInput = true
                        isNewTaskFocused = true
                        appState.dismissalLocks.insert(.activeEditing)
                    } label: {
                        makeAddActionButton(icon: "plus", label: "ADD TASK")
                    }
                    .buttonStyle(.plain)
                )
            }
        ) {
            VStack(spacing: 0) {
                if showAddInput {
                    addInputRow
                        .padding(.bottom, 8)
                }

                if isUsingDummy {
                    // Non-interactive dummy list
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 8) {
                            ForEach(Self.dummyTasks, id: \.text) { t in
                                dummyRow(text: t.text, timestamp: t.timestamp, isDone: t.isDone)
                            }
                        }
                    }
                } else {
                    // Live list with drag-to-reorder
                    List {
                        ForEach(appState.todoItems) { item in
                            liveRow(item)
                                .padding(.bottom, 8)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                        .onMove { indices, newOffset in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                appState.todoItems.move(fromOffsets: indices, toOffset: newOffset)
                                // Keep incomplete tasks above complete tasks
                                let incomplete = appState.todoItems.filter { !$0.isDone }
                                let complete = appState.todoItems.filter { $0.isDone }
                                appState.todoItems = incomplete + complete
                            }
                            appState.dismissalLocks.remove(.moduleGesture)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                }
            }
        }
    }

    // MARK: - Add Input Row

    private var addInputRow: some View {
        HStack(spacing: 8) {
            TextField("", text: $newTaskText)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.85))
                .focused($isNewTaskFocused)
                .onSubmit { confirmAdd() }
                .overlay(alignment: .leading) {
                    if newTaskText.isEmpty {
                        Text("New task…")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.25))
                            .allowsHitTesting(false)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )

            Button { confirmAdd() } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)

            Button { cancelAdd() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(minHeight: 45)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .onAppear { isNewTaskFocused = true }
    }

    // MARK: - Dummy Row

    @ViewBuilder
    private func dummyRow(text: String, timestamp: String, isDone: Bool) -> some View {
        HStack(spacing: 12) {
            if isDone {
                ZStack {
                    Circle().fill(Color(hex: "32D74B")).frame(width: 20, height: 20)
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.white)
                }
            } else {
                Circle()
                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                    .frame(width: 20, height: 20)
            }
            Text(text)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(isDone ? Color.white.opacity(0.3) : Color.white.opacity(0.85))
                .strikethrough(isDone, color: Color.white.opacity(0.3))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(timestamp)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.35))
        }
        .padding(12)
        .frame(minHeight: 45)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .opacity(0.5)
    }

    // MARK: - Live Row

    @ViewBuilder
    private func liveRow(_ item: TodoItem) -> some View {
        LiveTaskRowView(
            item: item,
            isEditing: editingID == item.id,
            editDraft: $editDraft,
            onToggle: { toggleTask(item.id) },
            onDelete: { deleteTask(item.id) },
            onEdit: {
                editingID = item.id
                editDraft = item.title
                appState.dismissalLocks.insert(.activeEditing)
            },
            onSaveEdit: { newTitle in
                saveEdit(id: item.id, title: newTitle)
            },
            onCancelEdit: {
                editingID = nil
                editDraft = ""
                appState.dismissalLocks.remove(.activeEditing)
            }
        )
    }

    // MARK: - Actions

    private func confirmAdd() {
        let text = newTaskText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { cancelAdd(); return }
        withAnimation(.easeOut(duration: 0.2)) {
            appState.todoItems.insert(TodoItem(title: text), at: 0)
        }
        newTaskText = ""
        showAddInput = false
        appState.dismissalLocks.remove(.activeEditing)
    }

    private func cancelAdd() {
        newTaskText = ""
        showAddInput = false
        appState.dismissalLocks.remove(.activeEditing)
    }

    private func deleteTask(_ id: UUID) {
        withAnimation(.easeOut(duration: 0.2)) {
            appState.todoItems.removeAll { $0.id == id }
        }
    }

    private func saveEdit(id: UUID, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, let idx = appState.todoItems.firstIndex(where: { $0.id == id }) {
            appState.todoItems[idx].title = trimmed
        }
        editingID = nil
        editDraft = ""
        appState.dismissalLocks.remove(.activeEditing)
    }

    private func toggleTask(_ id: UUID) {
        guard let idx = appState.todoItems.firstIndex(where: { $0.id == id }) else { return }
        let wasAlreadyDone = appState.todoItems[idx].isDone
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            appState.todoItems[idx].isDone.toggle()
            if !wasAlreadyDone {
                let item = appState.todoItems.remove(at: idx)
                appState.todoItems.append(item)
            } else {
                let item = appState.todoItems.remove(at: idx)
                let insertIdx = appState.todoItems.firstIndex(where: { $0.isDone }) ?? appState.todoItems.count
                appState.todoItems.insert(item, at: insertIdx)
            }
        }
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

// MARK: - Live Task Row View

private struct LiveTaskRowView: View {
    let item: TodoItem
    let isEditing: Bool
    @Binding var editDraft: String
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    let onSaveEdit: (String) -> Void
    let onCancelEdit: () -> Void

    @State private var isHovering = false
    @FocusState private var isEditFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox — also fires toggle
            Button(action: onToggle) {
                if item.isDone {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "32D74B"))
                            .frame(width: 20, height: 20)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                } else {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                        .frame(width: 20, height: 20)
                }
            }
            .buttonStyle(.plain)

            // Inline edit field or task title
            if isEditing {
                TextField("", text: $editDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .focused($isEditFocused)
                    .onSubmit { onSaveEdit(editDraft) }
                    .frame(maxWidth: .infinity)
            } else {
                Text(item.title)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(item.isDone ? Color.white.opacity(0.3) : Color.white.opacity(0.85))
                    .strikethrough(item.isDone, color: Color.white.opacity(0.3))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Right side: confirm (edit mode) / action buttons (hover) / timestamp
            if isEditing {
                Button { onSaveEdit(editDraft) } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.8))
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            } else if isHovering {
                HStack(spacing: 6) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white.opacity(0.40))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "FF453A"))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
                .transition(.opacity)
            } else {
                Text("—")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.35))
            }
        }
        .padding(12)
        .frame(minHeight: 45)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(isEditing ? 0.07 : (isHovering ? 0.05 : 0.03)))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isEditing else { return }
            onToggle()
        }
        .onHover { h in withAnimation(.easeInOut(duration: 0.15)) { isHovering = h } }
        .onChange(of: isEditing) { _, editing in
            if editing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isEditFocused = true
                }
            } else {
                isEditFocused = false
            }
        }
    }
}
