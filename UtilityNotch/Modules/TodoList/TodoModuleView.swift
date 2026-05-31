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
    @State private var dragOriginalItems: [TodoItem]? = nil
    @State private var didCommitDrag: Bool = false
    @State private var localDragEndMonitor: Any? = nil
    @State private var globalDragEndMonitor: Any? = nil

    private var isUsingDummy: Bool { appState.todoItems.isEmpty }
    private var completedCount: Int { appState.completedCount }
    private var remainingCount: Int { appState.remainingCount }
    private var totalCount: Int { completedCount + remainingCount }
    private var allDone: Bool { !isUsingDummy && completedCount > 0 && remainingCount == 0 }

    var body: some View {
        @Bindable var state = appState

        ModuleShellView(
            moduleTitle: "Todo",
            moduleIcon: "checklist",
            modules: shellNavItems(appState: appState),
            activeModuleID: appState.activeModuleID,
            onModuleSelect: { id in
                withAnimation(UNMotion.moduleSwitch) {
                    appState.selectModule(id)
                }
            },
            statusDotColor: Color.white.opacity(0.2),
            statusLeft: "\(completedCount) DONE",
            statusRight: allDone ? "ALL CLEAR" : "\(remainingCount) LEFT",
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
            HStack(alignment: .top, spacing: UNConstants.moduleColumnGap) {
                todoSummaryPanel
                    .frame(width: 132)
                    .frame(maxHeight: .infinity)

                VStack(spacing: UNConstants.moduleRowGap) {
                    if showAddInput {
                        addInputRow
                    }

                    if isUsingDummy {
                        todoEmptyState
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 8) {
                                ForEach(appState.todoItems) { item in
                                    let isDragged = draggingID == item.id

                                    Group {
                                        if isDragged {
                                            dragInsertionRail
                                        } else {
                                            liveRow(item)
                                        }
                                    }
                                        .animation(UNMotion.dragLift, value: draggingID)
                                        .animation(UNMotion.dragDisplace, value: appState.todoItems.map(\.id))
                                        .if(!item.isDone && editingID == nil && !isDragged) { view in
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
                                                items: $state.todoItems,
                                                draggingID: $draggingID,
                                                onCommit: { commitDrag() }
                                            )
                                        )
                                }
                            }
                            .animation(UNMotion.listItem, value: appState.todoItems.map(\.id))
                            .padding(.bottom, 4)
                        }
                        .clipped()
                        .onChange(of: draggingID) { _, newVal in
                            if newVal == nil {
                                appState.dismissalLocks.remove(.dragDrop)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                resetDanglingDragState()
            }
            .onChange(of: appState.activeModuleID) { _, newValue in
                guard newValue != "todoList" else { return }
                cancelDrag()
            }
            .onDisappear {
                cancelDrag()
            }
        }
    }

    private var todoEmptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checklist")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(UNConstants.textPlaceholder)
            Text("nothing here yet")
                .font(.system(size: 14))
                .foregroundStyle(UNConstants.textSecondary)
            Button {
                showAddInput = true
                isNewTaskFocused = true
                appState.dismissalLocks.insert(.activeEditing)
            } label: {
                Text("add your first task")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(UNConstants.textPrimary)
                    .padding(.horizontal, 12)
                    .frame(height: UNConstants.compactControlHeight)
                    .background(Capsule().fill(UNConstants.controlSurface))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var todoSummaryPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    if allDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 40, weight: .black))
                            .foregroundStyle(UNConstants.successGreen)
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                    } else {
                        Text("\(completedCount)")
                            .font(.system(size: 44, weight: .black))
                            .foregroundStyle(UNConstants.textPrimary)
                            .contentTransition(.numericText())
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                        Text("/ \(max(totalCount, 1))")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(UNConstants.textTertiary)
                    }
                }
                .animation(UNMotion.expressive, value: allDone)

                Text(allDone ? "all clear" : "done today")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(UNConstants.textSecondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                statusMetric(label: "done", value: completedCount, color: UNConstants.successGreen)
                statusMetric(label: "open", value: remainingCount, color: UNConstants.accentBlue)
            }

            Spacer(minLength: 0)

            Image(systemName: "checklist")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(UNConstants.textTertiary)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: UNConstants.tileCornerRadius, style: .continuous)
                .fill(UNConstants.insetSurface)
                .overlay {
                    if allDone {
                        RoundedRectangle(cornerRadius: UNConstants.tileCornerRadius, style: .continuous)
                            .fill(UNConstants.successGreen.opacity(0.04))
                    }
                }
        }
    }

    private func statusMetric(label: String, value: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(UNConstants.textSecondary)
            Spacer(minLength: 0)
            Text("\(value)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(UNConstants.textPrimary)
        }
    }

    // MARK: - Add Input Row

    private var addInputRow: some View {
        HStack(spacing: 8) {
            TextField("", text: $newTaskText)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(UNConstants.textPrimary)
                .focused($isNewTaskFocused)
                .onSubmit { confirmAdd() }
                .overlay(alignment: .leading) {
                    if newTaskText.isEmpty {
                        Text("New task…")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(UNConstants.textPlaceholder)
                            .allowsHitTesting(false)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(UNConstants.insetSurface)
                )

            Button { confirmAdd() } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(UNConstants.textPrimary)
                    .frame(width: UNConstants.hudButtonSize, height: UNConstants.hudButtonSize)
                    .background(
                        Circle()
                            .fill(UNConstants.controlSurface)
                    )
            }
            .buttonStyle(.plain)

            Button { cancelAdd() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(UNConstants.textSecondary)
                    .frame(width: UNConstants.hudButtonSize, height: UNConstants.hudButtonSize)
                    .background(
                        Circle()
                            .fill(UNConstants.insetSurface)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(minHeight: 45)
        .background(
            RoundedRectangle(cornerRadius: UNConstants.rowCornerRadius, style: .continuous)
                .fill(UNConstants.rowSurface)
        )
        .onAppear { isNewTaskFocused = true }
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
        .background(UNConstants.overlayScrim, in: RoundedRectangle(cornerRadius: UNConstants.rowCornerRadius, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: UNConstants.rowCornerRadius, style: .continuous))
    }

    private var dragInsertionRail: some View {
        HStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            UNConstants.iconActiveTint.opacity(0.55),
                            UNConstants.iconActiveTint,
                            UNConstants.iconActiveTint.opacity(0.55)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 3)
        }
        .padding(.horizontal, 14)
        .frame(height: 12)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    // MARK: - Actions

    private func confirmAdd() {
        let text = newTaskText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { cancelAdd(); return }
        withAnimation(UNMotion.expressive) {
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
        withAnimation(UNMotion.listItem) {
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

    private func finishDrag(commit: Bool) {
        guard draggingID != nil || dragOriginalItems != nil else { return }

        uninstallDragEndMonitors()

        if !commit, let originalItems = dragOriginalItems {
            withAnimation(UNMotion.dragDisplace) {
                appState.todoItems = originalItems
            }
        }

        withAnimation(UNMotion.dragLift) {
            draggingID = nil
        }

        dragOriginalItems = nil
        didCommitDrag = false
        appState.dismissalLocks.remove(.dragDrop)
    }

    private func startDrag(_ item: TodoItem) -> NSItemProvider {
        dragOriginalItems = appState.todoItems
        didCommitDrag = false
        draggingID = item.id
        appState.dismissalLocks.insert(.dragDrop)
        installDragEndMonitors()
        return NSItemProvider(object: item.id.uuidString as NSString)
    }

    private func commitDrag() {
        didCommitDrag = true
        finishDrag(commit: true)
    }

    private func cancelDrag() {
        finishDrag(commit: false)
    }

    private func resetDanglingDragState() {
        guard draggingID != nil || dragOriginalItems != nil else { return }
        cancelDrag()
    }

    private func installDragEndMonitors() {
        uninstallDragEndMonitors()

        localDragEndMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseUp, .rightMouseUp, .otherMouseUp, .keyDown]
        ) { event in
            if event.type == .keyDown, event.keyCode == 53 {
                scheduleDragCleanupFallback()
            } else if event.type == .leftMouseUp ||
                        event.type == .rightMouseUp ||
                        event.type == .otherMouseUp {
                scheduleDragCleanupFallback()
            }
            return event
        }

        globalDragEndMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseUp, .rightMouseUp, .otherMouseUp]
        ) { _ in
            scheduleDragCleanupFallback()
        }
    }

    private func uninstallDragEndMonitors() {
        if let localDragEndMonitor {
            NSEvent.removeMonitor(localDragEndMonitor)
            self.localDragEndMonitor = nil
        }
        if let globalDragEndMonitor {
            NSEvent.removeMonitor(globalDragEndMonitor)
            self.globalDragEndMonitor = nil
        }
    }

    private func scheduleDragCleanupFallback() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard draggingID != nil else { return }
            finishDrag(commit: didCommitDrag)
        }
    }

    /// Toggle done/undone, then re-sort so undone items always precede done items.
    /// Filter-based sort avoids SwiftUI animation glitches from simultaneous item
    /// mutation + positional move in the same animation block.
    private func toggleTask(_ id: UUID) {
        guard let idx = appState.todoItems.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(UNMotion.listItem) {
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
    let onCommit: () -> Void

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        onCommit()
        return true
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

        withAnimation(UNMotion.dragDisplace) {
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
    @State private var isConfirmingDelete = false
    @State private var checkPulse = false
    @FocusState private var isEditFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox — toggles done/undone
            Button(action: toggleWithPulse) {
                if item.isDone {
                    ZStack {
                        Circle()
                            .fill(UNConstants.successGreen)
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
            .scaleEffect(checkPulse ? 1.22 : 1.0)
            .animation(UNMotion.tap, value: checkPulse)

            // Inline edit field or task title
            if isEditing {
                TextField("", text: $editDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(UNConstants.textPrimary)
                    .focused($isEditFocused)
                    .onSubmit { onSaveEdit(editDraft) }
                    .frame(maxWidth: .infinity)
            } else {
                Text(item.title)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(item.isDone ? UNConstants.textMuted : UNConstants.textPrimary)
                    .strikethrough(item.isDone, color: Color.white.opacity(0.3))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Trailing: confirm (editing) | action buttons + drag handle (hovering) | passive state
            if isEditing {
                Button { onSaveEdit(editDraft) } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(UNConstants.textPrimary)
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

                    Button(action: confirmOrDelete) {
                        Image(systemName: isConfirmingDelete ? "trash.fill" : "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(UNConstants.destructiveRed)
                            .frame(width: 26, height: 26)
                            .background(
                                Circle()
                                    .fill(isConfirmingDelete ? UNConstants.selectedSurface : Color.clear)
                            )
                            .scaleEffect(isConfirmingDelete ? 1.12 : 1.0)
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
            RoundedRectangle(cornerRadius: UNConstants.rowCornerRadius, style: .continuous)
                .fill(isEditing ? UNConstants.raisedSurface : (isHovering ? UNConstants.rowHoverSurface : UNConstants.rowSurface))
        )
        .contentShape(Rectangle())
        // Tap the row (outside buttons) → toggle done/undone
        .onTapGesture {
            guard !isEditing else { return }
            toggleWithPulse()
        }
        .onHover { h in withAnimation(UNMotion.hover) { isHovering = h } }
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

    private func toggleWithPulse() {
        if !item.isDone {
            withAnimation(UNMotion.tap) { checkPulse = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(UNMotion.tap) { checkPulse = false }
            }
        }
        onToggle()
    }

    private func confirmOrDelete() {
        if isConfirmingDelete {
            isConfirmingDelete = false
            onDelete()
        } else {
            withAnimation(UNMotion.tap) { isConfirmingDelete = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(UNMotion.tap) { isConfirmingDelete = false }
            }
        }
    }
}
