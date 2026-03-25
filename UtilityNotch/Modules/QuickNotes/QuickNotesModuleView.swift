import SwiftUI

/// Quick Notes module — full-shell Figma implementation.
/// CSS source: /DesignReference/Css/QucikNotes.css
struct QuickNotesModuleView: View {
    @Environment(AppState.self) private var appState
    @State private var newNoteText: String = ""

    private struct Note: Identifiable {
        let id = UUID()
        let title: String
        let timestamp: String
        let preview: String
    }

    private let notes: [Note] = [
        Note(title: "API Keys",          timestamp: "14:32",     preview: "All keys are stored in 1Password vault under the team…"),
        Note(title: "Standup Notes",     timestamp: "11:15",     preview: "Discussed migration timeline. Backend team needs 2 more…"),
        Note(title: "Design Feedback",   timestamp: "Yesterday", preview: "Sidebar feels too heavy. Reduce icon opacity on inactive…"),
        Note(title: "Release Checklist", timestamp: "Mon",       preview: "1. Tag release  2. Update changelog  3. Notify beta…"),
    ]

    var body: some View {
        ModuleShellView(
            moduleTitle: "Quick Notes",
            moduleIcon: "note.text",
            modules: shellNavItems(appState: appState),
            activeModuleID: appState.activeModuleID,
            onModuleSelect: { id in
                withAnimation(.spring(duration: 0.28, bounce: 0.16)) {
                    appState.selectModule(id)
                }
            },
            statusDotColor: Color.white.opacity(0.2),
            statusLeft: "SAVED LOCALLY",
            statusRight: "4 NOTES",
            actionButton: { makeAddActionButton(icon: "plus", label: "NEW NOTE") }
        ) {
            VStack(spacing: 8) {
                // Input field
                // CSS: height 36px, padding 9.5px 16px, bg rgba(255,255,255,0.05), radius 12px
                // Placeholder: Inter 400 14px rgba(255,255,255,0.25)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 36)

                    if newNoteText.isEmpty {
                        Text("New note…")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.25))
                            .padding(.horizontal, 16)
                    }

                    TextField("", text: $newNoteText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .padding(.horizontal, 16)
                }
                .frame(height: 36)

                // Notes list
                // CSS: gap 8px, padding bottom 8px
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(notes) { note in
                            noteCard(note)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
    }

    // MARK: - Note Card
    // CSS: padding 12px, gap 4px, bg rgba(255,255,255,0.03), radius 12px, height ~68.5px

    @ViewBuilder
    private func noteCard(_ note: Note) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Line 1: title (left) + timestamp (right)
            HStack(alignment: .firstTextBaseline) {
                // Title: Inter 600 14px #FFFFFF
                Text(note.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)

                Spacer()

                // Timestamp: JetBrains Mono 400 11px rgba(255,255,255,0.35)
                Text(note.timestamp)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.35))
            }

            // Line 2: preview text
            // CSS: Inter 400 13px rgba(255,255,255,0.45), max 2 lines truncated
            Text(note.preview)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.45))
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
    }
}
