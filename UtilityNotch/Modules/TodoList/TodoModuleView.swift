import SwiftUI

// MARK: - Display Task Model

private struct TodoDisplayTask: Identifiable {
    let id: UUID
    let text: String
    let description: String?
    let timestamp: String
    let isComplete: Bool
    let isInteractive: Bool
}

/// Todo module — full-shell Figma implementation, wired to AppState.
/// CSS source: /DesignReference/Css/todo.css
struct TodoModuleView: View {
    @Environment(AppState.self) private var appState
    @State private var showAddInput: Bool = false
    @State private var newTaskText: String = ""
    @State private var newTaskDesc: String = ""
    @FocusState private var isNewTaskFocused: Bool

    // Dummy tasks for initial state (shown when appState.todoItems is empty)
    private static let dummyTasks: [(text: String, timestamp: String, isDone: Bool)] = [
        (text: "Fix parser bug",           timestamp: "09:41", isDone: false),
        (text: "Write unit tests",          timestamp: "10:15", isDone: false),
        (text: "Review pull request #42",   timestamp: "11:03", isDone: false),
        (text: "Update dependencies",       timestamp: "08:30", isDone: true),
        (text: "Ship v1.0 release notes",   timestamp: "08:00", isDone: true),
    ]

    private var isUsingDummy: Bool { appState.todoItems.isEmpty }

    private var displayTasks: [TodoDisplayTask] {
        if isUsingDummy {
            return Self.dummyTasks.map { t in
                TodoDisplayTask(id: UUID(), text: t.text, description: nil, timestamp: t.timestamp,
                            isComplete: t.isDone, isInteractive: false)
            }
        }
        return appState.todoItems.map { item in
            TodoDisplayTask(id: item.id, text: item.title, description: item.description, timestamp: "—",
                        isComplete: item.isDone, isInteractive: true)
        }
    }

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
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    if showAddInput {
                        addInputRow
                    }
                    ForEach(displayTasks) { task in
                        taskRow(task)
                    }
                }
            }
        }
    }

    // MARK: - Add Input Row
    // Same card style as task rows: bg rgba(255,255,255,0.03), radius 8px, padding 12px
    // Text field: bg rgba(255,255,255,0.06), SF Pro Regular 14pt, placeholder white 25%

    private var addInputRow: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(spacing: 6) {
                // Title field
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

                // Description field
                TextField("", text: $newTaskDesc)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .onSubmit { confirmAdd() }
                    .overlay(alignment: .leading) {
                        if newTaskDesc.isEmpty {
                            Text("Add description…")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(Color.white.opacity(0.2))
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
            }

            // Confirm button
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

            // Cancel button
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
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .onAppear { isNewTaskFocused = true }
    }

    // MARK: - Task Row
    // CSS: padding 12px, bg rgba(255,255,255,0.03), radius 8px, height 45px

    @ViewBuilder
    private func taskRow(_ task: TodoDisplayTask) -> some View {
        TaskRowView(task: task) {
            guard task.isInteractive else { return }
            toggleTask(task.id)
        } onDelete: {
            guard task.isInteractive else { return }
            deleteTask(task.id)
        }
    }

    // MARK: - Actions

    private func confirmAdd() {
        let text = newTaskText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { cancelAdd(); return }
        let desc = newTaskDesc.trimmingCharacters(in: .whitespaces)
        withAnimation(.easeOut(duration: 0.2)) {
            appState.todoItems.insert(
                TodoItem(title: text, description: desc.isEmpty ? nil : desc),
                at: 0
            )
        }
        newTaskText = ""
        newTaskDesc = ""
        showAddInput = false
        appState.dismissalLocks.remove(.activeEditing)
    }

    private func cancelAdd() {
        newTaskText = ""
        newTaskDesc = ""
        showAddInput = false
        appState.dismissalLocks.remove(.activeEditing)
    }

    private func deleteTask(_ id: UUID) {
        withAnimation(.easeOut(duration: 0.2)) {
            appState.todoItems.removeAll { $0.id == id }
        }
    }

    private func toggleTask(_ id: UUID) {
        guard let idx = appState.todoItems.firstIndex(where: { $0.id == id }) else { return }
        let wasAlreadyDone = appState.todoItems[idx].isDone
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            appState.todoItems[idx].isDone.toggle()
            // Completed tasks move to the bottom; un-checked tasks return before first done item
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

// MARK: - Task Row View

private struct TaskRowView: View {
    let task: TodoDisplayTask
    let onToggle: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: onToggle) {
                if task.isComplete {
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
            .disabled(!task.isInteractive)

            // Task text + optional description
            VStack(alignment: .leading, spacing: 2) {
                Text(task.text)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(task.isComplete ? Color.white.opacity(0.3) : Color.white.opacity(0.85))
                    .strikethrough(task.isComplete, color: Color.white.opacity(0.3))
                    .lineLimit(1)

                if let desc = task.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Delete button (hover only)
            if isHovering && task.isInteractive {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                        )
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            } else {
                // Timestamp (hidden when hovering to make room for delete)
                Text(task.timestamp)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.35))
            }
        }
        .padding(12)
        .frame(minHeight: 45)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(isHovering && task.isInteractive ? 0.05 : 0.03))
        )
        .contentShape(Rectangle())
        .onHover { h in withAnimation(.easeInOut(duration: 0.12)) { isHovering = h } }
    }
}
