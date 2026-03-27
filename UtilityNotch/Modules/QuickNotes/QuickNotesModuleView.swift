import SwiftUI

/// Quick Notes module — full-shell Figma implementation, wired to AppState.
/// CSS source: /DesignReference/Css/QucikNotes.css
struct QuickNotesModuleView: View {
    @Environment(AppState.self) private var appState

    // Popup state
    @State private var showingNewNotePopup: Bool = false
    @State private var editingNote: QuickNote? = nil
    @State private var popupTitle: String = ""
    @State private var popupBody: String = ""
    @FocusState private var isPopupTitleFocused: Bool

    // Dummy notes for initial state (shown when appState.quickNotes is empty)
    private static let dummyNotes: [(title: String, timestamp: String, preview: String)] = [
        (title: "API Keys",          timestamp: "14:32",     preview: "All keys are stored in 1Password vault under the team…"),
        (title: "Standup Notes",     timestamp: "11:15",     preview: "Discussed migration timeline. Backend team needs 2 more…"),
        (title: "Design Feedback",   timestamp: "Yesterday", preview: "Sidebar feels too heavy. Reduce icon opacity on inactive…"),
        (title: "Release Checklist", timestamp: "Mon",       preview: "1. Tag release  2. Update changelog  3. Notify beta…"),
    ]

    private var isUsingDummy: Bool { appState.quickNotes.isEmpty }
    private var isEditing: Bool { editingNote != nil }
    private var canCreate: Bool { !popupTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

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
            actionButton: {
                AnyView(
                    Button { openNewNotePopup() } label: {
                        makeAddActionButton(icon: "plus", label: "NEW NOTE")
                    }
                    .buttonStyle(.plain)
                )
            }
        ) {
            ZStack(alignment: .center) {
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
                                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }

                // Popup overlay
                if showingNewNotePopup {
                    Color.black.opacity(0.50)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture { dismissPopup() }

                    popupCard
                        .padding(.horizontal, 24)
                        .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: showingNewNotePopup)
        }
    }

    // MARK: - Static Note Card (dummy data, non-interactive)

    @ViewBuilder
    private func staticNoteCard(title: String, timestamp: String, preview: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(1)
                Spacer()
                Text(timestamp)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.35))
            }
            Text(preview)
                .font(.system(size: 12, weight: .regular))
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

    // MARK: - Live Note Card

    @ViewBuilder
    private func liveNoteCard(_ note: QuickNote) -> some View {
        LiveNoteCardView(
            note: note,
            onEdit: { openEditPopup(note) },
            onCopy: { copyNote(note) },
            onDelete: { deleteNote(note) }
        )
    }

    // MARK: - Popup Card

    private var popupCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text(isEditing ? "Edit Note" : "New Note")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.85))

            Spacer().frame(height: 12)

            // Title field
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.06))

                if popupTitle.isEmpty {
                    Text("Title…")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.25))
                        .padding(.horizontal, 12)
                        .allowsHitTesting(false)
                }

                TextField("", text: $popupTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .focused($isPopupTitleFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .onChange(of: showingNewNotePopup) { _, showing in
                        if showing {
                            appState.dismissalLocks.insert(.activeEditing)
                        }
                    }
            }
            .frame(height: 40)

            Spacer().frame(height: 8)

            // Body TextEditor
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.06))

                if popupBody.isEmpty {
                    Text("Add description…")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.25))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $popupBody)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            }
            .frame(minHeight: 72)

            Spacer().frame(height: 16)

            // Button row
            HStack(spacing: 8) {
                Button { dismissPopup() } label: {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)

                Button { confirmPopup() } label: {
                    Text(isEditing ? "Save" : "Create")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(canCreate ? Color.white : Color.white.opacity(0.35))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(canCreate ? Color(hex: "0A84FF") : Color.white.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canCreate)
            }
        }
        .padding(16)
        .background(Color(hex: "1C1C1C"))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isPopupTitleFocused = true
            }
        }
    }

    // MARK: - Actions

    private func openNewNotePopup() {
        popupTitle = ""
        popupBody = ""
        editingNote = nil
        showingNewNotePopup = true
        appState.dismissalLocks.insert(.activeEditing)
    }

    private func openEditPopup(_ note: QuickNote) {
        popupTitle = note.title
        popupBody = note.body
        editingNote = note
        showingNewNotePopup = true
        appState.dismissalLocks.insert(.activeEditing)
    }

    private func dismissPopup() {
        showingNewNotePopup = false
        editingNote = nil
        popupTitle = ""
        popupBody = ""
        appState.dismissalLocks.remove(.activeEditing)
    }

    private func confirmPopup() {
        let title = popupTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let body = popupBody.trimmingCharacters(in: .whitespacesAndNewlines)
        withAnimation(.easeOut(duration: 0.2)) {
            if let editing = editingNote,
               let idx = appState.quickNotes.firstIndex(where: { $0.id == editing.id }) {
                appState.quickNotes[idx].title = title
                appState.quickNotes[idx].body = body
            } else {
                appState.quickNotes.insert(QuickNote(title: title, body: body), at: 0)
            }
        }
        dismissPopup()
    }

    private func copyNote(_ note: QuickNote) {
        let text = note.body.isEmpty ? note.title : "\(note.title)\n\(note.body)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func deleteNote(_ note: QuickNote) {
        withAnimation(.easeOut(duration: 0.18)) {
            appState.quickNotes.removeAll { $0.id == note.id }
        }
    }
}

// MARK: - Live Note Card View

private struct LiveNoteCardView: View {
    let note: QuickNote
    let onEdit: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @State private var isFlashing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(note.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
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

            if !note.body.isEmpty {
                Text(note.body)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(isFlashing ? 0.07 : (isHovering ? 0.05 : 0.03)))
        )
        .contentShape(Rectangle())
        .onHover { h in withAnimation(.easeInOut(duration: 0.12)) { isHovering = h } }
    }

    @ViewBuilder
    private var hoverActions: some View {
        HStack(spacing: 8) {
            // Edit
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.50))
            }
            .buttonStyle(.plain)

            // Copy with flash
            Button {
                onCopy()
                withAnimation(.easeIn(duration: 0.15)) { isFlashing = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation { isFlashing = false }
                }
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.50))
            }
            .buttonStyle(.plain)

            // Delete
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "FF453A"))
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
