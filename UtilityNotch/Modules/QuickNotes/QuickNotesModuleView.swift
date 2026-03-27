import SwiftUI

/// Quick Notes module — full-shell Figma implementation, wired to AppState.
/// CSS source: /DesignReference/Css/QucikNotes.css
struct QuickNotesModuleView: View {
    @Environment(AppState.self) private var appState
    @State private var newNoteText: String = ""
    @State private var newNoteBody: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var expandedNoteID: UUID?

    // Dummy notes for initial state (shown when appState.quickNotes is empty)
    private static let dummyNotes: [(title: String, timestamp: String, preview: String)] = [
        (title: "API Keys",          timestamp: "14:32",     preview: "All keys are stored in 1Password vault under the team…"),
        (title: "Standup Notes",     timestamp: "11:15",     preview: "Discussed migration timeline. Backend team needs 2 more…"),
        (title: "Design Feedback",   timestamp: "Yesterday", preview: "Sidebar feels too heavy. Reduce icon opacity on inactive…"),
        (title: "Release Checklist", timestamp: "Mon",       preview: "1. Tag release  2. Update changelog  3. Notify beta…"),
    ]

    private var isUsingDummy: Bool { appState.quickNotes.isEmpty }

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
            statusRight: isUsingDummy ? "4 NOTES" : "\(appState.quickNotes.count) NOTES",
            actionButton: { makeAddActionButton(icon: "plus", label: "NEW NOTE") }
        ) {
            VStack(spacing: 8) {
                // Input area: title field + body TextEditor
                VStack(spacing: 6) {
                    // Title field
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                            .frame(height: 36)

                        if newNoteText.isEmpty {
                            Text("Note title…")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(Color.white.opacity(0.25))
                                .padding(.horizontal, 16)
                                .allowsHitTesting(false)
                        }

                        TextField("", text: $newNoteText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.85))
                            .focused($isInputFocused)
                            .padding(.horizontal, 16)
                            .onSubmit { submitNote() }
                            .onChange(of: isInputFocused) { _, focused in
                                if focused { appState.dismissalLocks.insert(.activeEditing) }
                                else { appState.dismissalLocks.remove(.activeEditing) }
                            }
                    }
                    .frame(height: 36)

                    // Body TextEditor (min 2 lines)
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.06))

                        if newNoteBody.isEmpty {
                            Text("Add details…")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(Color.white.opacity(0.2))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }

                        TextEditor(text: $newNoteBody)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.75))
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                    }
                    .frame(minHeight: 48)
                }

                // Notes list
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        if isUsingDummy {
                            ForEach(Array(Self.dummyNotes.enumerated()), id: \.offset) { _, note in
                                staticNoteCard(title: note.title, timestamp: note.timestamp, preview: note.preview)
                            }
                        } else {
                            ForEach(appState.quickNotes) { note in
                                liveNoteCard(note)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
    }

    // MARK: - Static Note Card (dummy data, non-interactive)

    @ViewBuilder
    private func staticNoteCard(title: String, timestamp: String, preview: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                Spacer()
                Text(timestamp)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.35))
            }
            Text(preview)
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
        .opacity(0.6)
    }

    // MARK: - Live Note Card (real data, with hover actions + expand/collapse)

    @ViewBuilder
    private func liveNoteCard(_ note: QuickNote) -> some View {
        LiveNoteCardView(
            note: note,
            isExpanded: expandedNoteID == note.id,
            onTap: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    expandedNoteID = expandedNoteID == note.id ? nil : note.id
                }
            },
            onCopy: {
                let text = note.body.isEmpty ? note.title : "\(note.title)\n\(note.body)"
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            },
            onDelete: {
                withAnimation(.easeOut(duration: 0.18)) {
                    appState.quickNotes.removeAll { $0.id == note.id }
                    if expandedNoteID == note.id { expandedNoteID = nil }
                }
            }
        )
    }

    // MARK: - Actions

    private func submitNote() {
        let text = newNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let body = newNoteBody.trimmingCharacters(in: .whitespacesAndNewlines)
        withAnimation(.easeOut(duration: 0.2)) {
            appState.quickNotes.insert(QuickNote(title: text, body: body), at: 0)
        }
        newNoteText = ""
        newNoteBody = ""
        appState.dismissalLocks.remove(.activeEditing)
    }
}

// MARK: - Live Note Card View

/// Individual live note card with hover actions and expand/collapse.
private struct LiveNoteCardView: View {
    let note: QuickNote
    let isExpanded: Bool
    let onTap: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title row + hover actions
            HStack(alignment: .firstTextBaseline) {
                Text(note.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                Spacer()
                if isHovering {
                    hoverActions
                        .transition(.opacity)
                } else {
                    Text(formatTimestamp(note.createdAt))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.35))
                }
            }

            // Preview / body text
            if !note.body.isEmpty {
                Text(note.body)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .lineLimit(isExpanded ? nil : 2)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(isHovering ? 0.05 : 0.03))
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onHover { h in withAnimation(.easeInOut(duration: 0.12)) { isHovering = h } }
    }

    @ViewBuilder
    private var hoverActions: some View {
        HStack(spacing: 6) {
            // Copy to clipboard
            Button(action: onCopy) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.6))
            }
            .buttonStyle(.plain)

            // Delete with fade animation
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: "FF453A").opacity(0.8))
            }
            .buttonStyle(.plain)
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            let f = DateFormatter(); f.dateFormat = "HH:mm"
            return f.string(from: date)
        } else if cal.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let f = DateFormatter(); f.dateFormat = "EEE"
            return f.string(from: date)
        }
    }
}
