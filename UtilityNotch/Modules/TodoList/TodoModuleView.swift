import SwiftUI
import UniformTypeIdentifiers

/// Todo module — full-shell Figma implementation, wired to AppState.
/// CSS source: /DesignReference/Css/todo.css
struct TodoModuleView: View {
    @Environment(AppState.self) private var appState
    @State private var showAddInput: Bool = false
    @State private var newTaskText: String = ""
    @FocusState private var isNewTaskFocused: Bool
    @State private var editingID: UUID? = nil
    @State private var editDraft: String = ""
    @State private var draggingID: UUID? = nil
    @State private var dropTargetID: UUID? = nil

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
                    // Live list — stable stack with a visible source row and gap indicator.
                    // This avoids the disappearing-row glitches caused by hiding the
                    // source while SwiftUI is also animating repeated dropEntered moves.
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 8) {
                            ForEach(appState.todoItems) { item in
                                let isDragged = draggingID == item.id
                                let isDropTarget = dropTargetID == item.id && !isDragged
                                liveRow(item)
                                    .opacity(isDragged ? 0.62 : 1.0)
                                    .scaleEffect(isDragged ? 0.985 : 1.0)
                                    .overlay(alignment: .top) {
                                        if isDropTarget {
                                            Capsule()
                                                .fill(UNConstants.iconActiveTint.opacity(0.78))
                                                .frame(height: 2)
                                                .padding(.horizontal, 10)
                                                .offset(y: -5)
                                                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                                        }
                                    }
                                    .overlay {
                                        if isDragged {
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                                        }
                                    }
                                    .animation(
                                        .spring(response: 0.24, dampingFraction: 0.82),
                                        value: draggingID
                                    )
                                    .animation(.spring(response: 0.22, dampingFraction: 0.84), value: dropTargetID)
                                    // Drag-to-reorder — only undone items
                                    .if(!item.isDone && editingID == nil) { view in
                                        view.onDrag {
                                            startDrag(item)
                                        } preview: {
                                            dragPreview(for: item)
                                        }
                                    }
                                    .onDrop(
                                        of: [UTType.plainText],
                                        delegate: TodoDropDelegate(
                                            target: item,
                                            items: Bindable(appState).todoItems,
                                            draggingID: $draggingID,
                                            dropTargetID: $dropTargetID,
                                            onCleanup: { cleanupDrag() }
                                        )
                                    )
                            }
                        }
                        .animation(
                            .spring(response: 0.35, dampingFraction: 0.72),
                            value: appState.todoItems.map(\.id)
                        )
                        .padding(.bottom, 4)
                    }
                    .clipped()
                    .onChange(of: draggingID) { _, newVal in
                        // Safety net: if draggingID is cleared by any path, release lock
                        if newVal == nil {
                            appState.dismissalLocks.remove(.dragDrop)
                        }
                    }
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

    private func dragPreview(for item: TodoItem) -> some View {
        LiveTaskRowView(
            item: item,
            isEditing: false,
            editDraft: .constant(""),
            onToggle: {},
            onDelete: {},
            onEdit: {},
            onSaveEdit: { _ in },
            onCancelEdit: {}
        )
        .frame(width: 520)
        .background(Color.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Actions

    private func confirmAdd() {
        let text = newTaskText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { cancelAdd(); return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.74)) {
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
        withAnimation(.spring(response: 0.35, dampingFraction: 0.74)) {
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

    private func cleanupDrag() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            draggingID = nil
            dropTargetID = nil
        }
        appState.dismissalLocks.remove(.dragDrop)
    }

    private func startDrag(_ item: TodoItem) -> NSItemProvider {
        draggingID = item.id
        dropTargetID = item.id
        appState.dismissalLocks.insert(.dragDrop)
        return NSItemProvider(object: item.id.uuidString as NSString)
    }

    /// Toggle done/undone, then re-sort so undone items always precede done items.
    /// Filter-based sort avoids SwiftUI animation glitches from simultaneous item
    /// mutation + positional move in the same animation block.
    private func toggleTask(_ id: UUID) {
        guard let idx = appState.todoItems.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.74)) {
            appState.todoItems[idx].isDone.toggle()
            let undone = appState.todoItems.filter { !$0.isDone }
            let done   = appState.todoItems.filter {  $0.isDone }
            appState.todoItems = undone + done
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

// MARK: - Drop Delegate (drag-to-reorder, undone items only)

private struct TodoDropDelegate: DropDelegate {
    let target: TodoItem
    @Binding var items: [TodoItem]
    @Binding var draggingID: UUID?
    @Binding var dropTargetID: UUID?
    let onCleanup: () -> Void

    func dropUpdated(info: DropInfo) -> DropProposal? {
        if draggingID != target.id, !target.isDone {
            dropTargetID = target.id
        }
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        onCleanup()
        return true
    }

    func dropExited(info: DropInfo) {
        if dropTargetID == target.id {
            dropTargetID = nil
        }
    }

    func dropEntered(info: DropInfo) {
        guard
            let id   = draggingID,
            id      != target.id,
            !target.isDone,
            let from = items.firstIndex(where: { $0.id == id }),
            let to   = items.firstIndex(where: { $0.id == target.id }),
            !items[from].isDone
        else { return }

        dropTargetID = target.id

        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            items.move(
                fromOffsets: IndexSet(integer: from),
                toOffset: to > from ? to + 1 : to
            )
        }
    }
}

// MARK: - Conditional Modifier

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
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
            // Checkbox — toggles done/undone
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

            // Trailing: confirm (editing) | action buttons + drag handle (hovering) | passive state
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
                HStack(spacing: 4) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white.opacity(0.40))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "FF453A"))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)

                    // Drag handle — visible for undone items, signals draggability
                    if !item.isDone {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.9))
                            .frame(width: 22, height: 26)
                    }
                }
                .transition(.opacity)
            } else {
                // Passive state: drag handle for undone, dash for done
                if !item.isDone {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .frame(width: 22, height: 26)
                } else {
                    Text("—")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.35))
                }
            }
        }
        .padding(12)
        .frame(minHeight: 45)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(isEditing ? 0.07 : (isHovering ? 0.05 : 0.03)))
        )
        .contentShape(Rectangle())
        // Tap the row (outside buttons) → toggle done/undone
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
