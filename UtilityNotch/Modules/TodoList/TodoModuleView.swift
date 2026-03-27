import SwiftUI

/// Todo module — full-shell Figma implementation, wired to AppState.
/// CSS source: /DesignReference/Css/todo.css
struct TodoModuleView: View {
    @Environment(AppState.self) private var appState
    @State private var showAddInput: Bool = false
    @State private var newTaskText: String = ""
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

    // Unified display model so dummy and real items render identically
    private struct DisplayTask: Identifiable {
        let id: UUID
        let text: String
        let timestamp: String
        let isComplete: Bool
        let isInteractive: Bool
    }

    private var displayTasks: [DisplayTask] {
        if isUsingDummy {
            return Self.dummyTasks.map { t in
                DisplayTask(id: UUID(), text: t.text, timestamp: t.timestamp,
                            isComplete: t.isDone, isInteractive: false)
            }
        }
        return appState.todoItems.map { item in
            DisplayTask(id: item.id, text: item.title, timestamp: "—",
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
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )

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
        .frame(minHeight: 45)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .onAppear { isNewTaskFocused = true }
    }

    // MARK: - Task Row
    // CSS: padding 12px, bg rgba(255,255,255,0.03), radius 8px, height 45px

    @ViewBuilder
    private func taskRow(_ task: DisplayTask) -> some View {
        HStack(spacing: 12) {
            // Checkbox
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

            // Task text
            Text(task.text)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(task.isComplete ? Color.white.opacity(0.3) : Color.white.opacity(0.85))
                .strikethrough(task.isComplete, color: Color.white.opacity(0.3))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Timestamp
            Text(task.timestamp)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.35))
        }
        .padding(12)
        .frame(minHeight: 45)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard task.isInteractive else { return }
            toggleTask(task.id)
        }
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
