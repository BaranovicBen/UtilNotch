import SwiftUI

/// Todo module — full-shell Figma implementation.
/// CSS source: /DesignReference/Css/todo.css
struct TodoModuleView: View {
    @Environment(AppState.self) private var appState

    private struct Task: Identifiable {
        let id = UUID()
        let text: String
        let timestamp: String
        let isComplete: Bool
    }

    // Dummy data: incomplete tasks first, complete at bottom.
    private let tasks: [Task] = [
        Task(text: "Fix parser bug",           timestamp: "09:41", isComplete: false),
        Task(text: "Write unit tests",          timestamp: "10:15", isComplete: false),
        Task(text: "Review pull request #42",   timestamp: "11:03", isComplete: false),
        Task(text: "Update dependencies",       timestamp: "08:30", isComplete: true),
        Task(text: "Ship v1.0 release notes",   timestamp: "08:00", isComplete: true),
    ]

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
            statusLeft: "2 COMPLETED TODAY",
            statusRight: "3 REMAINING",
            actionButton: { makeAddActionButton(icon: "plus", label: "ADD TASK") }
        ) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(tasks) { task in
                        taskRow(task)
                    }
                }
            }
        }
    }

    // MARK: - Task Row
    // CSS: padding 12px, bg rgba(255,255,255,0.03), radius 8px, height 45px

    @ViewBuilder
    private func taskRow(_ task: Task) -> some View {
        HStack(spacing: 12) {
            // Checkbox
            // Complete: bg #32D74B radius 9999px 20×20px with white checkmark
            // Incomplete: border 1px rgba(255,255,255,0.3) radius 9999px 20×20px
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
            // Incomplete: Inter 400 14px rgba(255,255,255,0.85)
            // Complete: same + text-decoration line-through, rgba(255,255,255,0.3)
            Text(task.text)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(task.isComplete ? Color.white.opacity(0.3) : Color.white.opacity(0.85))
                .strikethrough(task.isComplete, color: Color.white.opacity(0.3))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Timestamp
            // CSS: JetBrains Mono 400 11px rgba(255,255,255,0.35)
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
    }
}
