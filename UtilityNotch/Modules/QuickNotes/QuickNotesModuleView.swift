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
    @State private var pinnedExpandedNoteID: UUID? = nil
    @State private var hoveredNoteID: UUID? = nil
    @FocusState private var isPopupTitleFocused: Bool

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
                withAnimation(UNMotion.moduleSwitch) {
                    appState.selectModule(id)
                }
            },
            statusDotColor: Color.white.opacity(0.2),
            statusLeft: "SAVED TO DISK",
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
                HStack(alignment: .top, spacing: UNConstants.moduleColumnGap) {
                    notesSummaryPanel
                        .frame(width: 132)
                        .frame(maxHeight: .infinity)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 8) {
                            if isUsingDummy {
                                notesEmptyState
                            } else {
                                ForEach(appState.quickNotes) { note in
                                    liveNoteCard(note)
                                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                                }
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if showingNewNotePopup {
                    UNConstants.overlayScrim
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture { dismissPopup() }

                    popupCard
                        .padding(.horizontal, 24)
                        .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
            }
            .animation(UNMotion.gentle, value: showingNewNotePopup)
        }
    }

    private var notesSummaryPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(appState.quickNotes.count)")
                .font(.system(size: 44, weight: .black))
                .foregroundStyle(UNConstants.textPrimary)

            Text("notes")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(UNConstants.textSecondary)

            Spacer(minLength: 0)

            Image(systemName: "note.text")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(UNConstants.textTertiary)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: UNConstants.tileCornerRadius, style: .continuous)
                .fill(UNConstants.insetSurface)
        }
    }

    private var notesEmptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "note.text")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(UNConstants.textPlaceholder)
            Text("nothing captured yet")
                .font(.system(size: 14))
                .foregroundStyle(UNConstants.textSecondary)
            Button { openNewNotePopup() } label: {
                Text("new note")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(UNConstants.textPrimary)
                    .padding(.horizontal, 12)
                    .frame(height: UNConstants.compactControlHeight)
                    .background(Capsule().fill(UNConstants.controlSurface))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }

    // MARK: - Live Note Card

    @ViewBuilder
    private func liveNoteCard(_ note: QuickNote) -> some View {
        LiveNoteCardView(
            note: note,
            isExpanded: hoveredNoteID == note.id || pinnedExpandedNoteID == note.id,
            onHoverChanged: { hovering in
                setHovered(note.id, hovering: hovering)
            },
            onToggleExpanded: { togglePinnedExpansion(note.id) },
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
                .foregroundStyle(UNConstants.textPrimary)

            Spacer().frame(height: 12)

            // Title field
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(UNConstants.insetSurface)

                if popupTitle.isEmpty {
                    Text("Title…")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(UNConstants.textPlaceholder)
                        .padding(.horizontal, 12)
                        .allowsHitTesting(false)
                }

                TextField("", text: $popupTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(UNConstants.textPrimary)
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
                    .fill(UNConstants.insetSurface)

                if popupBody.isEmpty {
                    Text("Add description…")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(UNConstants.textPlaceholder)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $popupBody)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(UNConstants.textPrimary)
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
                        .foregroundStyle(UNConstants.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(UNConstants.controlSurface)
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
                                .fill(canCreate ? UNConstants.accentBlue : UNConstants.controlSurface)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canCreate)
            }
        }
        .padding(16)
        .background(UNConstants.panelBackground)
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

    private func setHovered(_ id: UUID, hovering: Bool) {
        withAnimation(UNMotion.standard) {
            if hovering {
                hoveredNoteID = id
            } else if hoveredNoteID == id {
                hoveredNoteID = nil
            }
        }
    }

    private func togglePinnedExpansion(_ id: UUID) {
        withAnimation(UNMotion.standard) {
            pinnedExpandedNoteID = pinnedExpandedNoteID == id ? nil : id
        }
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
        withAnimation(UNMotion.expressive) {
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
        withAnimation(UNMotion.listItem) {
            appState.quickNotes.removeAll { $0.id == note.id }
        }
        if pinnedExpandedNoteID == note.id {
            pinnedExpandedNoteID = nil
        }
        if hoveredNoteID == note.id {
            hoveredNoteID = nil
        }
    }
}

// MARK: - Live Note Card View

private struct LiveNoteCardView: View {
    let note: QuickNote
    let isExpanded: Bool
    let onHoverChanged: (Bool) -> Void
    let onToggleExpanded: () -> Void
    let onEdit: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @State private var isFlashing = false
    @State private var isConfirmingDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(note.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(UNConstants.textPrimary)
                    .lineLimit(isExpanded ? 2 : 1)
                Spacer()
                if isHovering {
                    hoverActions
                        .transition(.opacity)
                } else {
                    Text(formatTimestamp(note.createdAt))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(UNConstants.textTertiary)
                }
            }

            if !note.body.isEmpty {
                Text(note.body)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(UNConstants.textSecondary)
                    .lineLimit(isExpanded ? nil : 2)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: UNConstants.rowCornerRadius, style: .continuous)
                .fill(isFlashing ? UNConstants.raisedSurface : (isHovering ? UNConstants.rowHoverSurface : UNConstants.rowSurface))
        )
        .overlay(
            RoundedRectangle(cornerRadius: UNConstants.rowCornerRadius, style: .continuous)
                .strokeBorder(
                    isExpanded ? UNConstants.iconActiveTint.opacity(0.28) : Color.clear,
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggleExpanded)
        .onHover { hovering in
            withAnimation(UNMotion.hover) {
                isHovering = hovering
            }
            onHoverChanged(hovering)
        }
    }

    @ViewBuilder
    private var hoverActions: some View {
        HStack(spacing: 8) {
            // Edit
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 13))
                    .foregroundStyle(UNConstants.textSecondary)
            }
            .buttonStyle(.plain)

            // Copy with flash
            Button {
                onCopy()
                withAnimation(UNMotion.flashOn) { isFlashing = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                    withAnimation(UNMotion.flashOff) { isFlashing = false }
                }
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 13))
                    .foregroundStyle(UNConstants.textSecondary)
            }
            .buttonStyle(.plain)

            // Delete
            Button(action: confirmOrDelete) {
                Image(systemName: isConfirmingDelete ? "trash.fill" : "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(UNConstants.destructiveRed)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(isConfirmingDelete ? UNConstants.selectedSurface : Color.clear)
                    )
                    .scaleEffect(isConfirmingDelete ? 1.12 : 1.0)
            }
            .buttonStyle(.plain)
        }
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
