import SwiftUI

/// Visual drag-to-reorder sheet for module ordering.
/// Opened from Module Settings. Shows all enabled modules with drag handles.
struct ModuleReorderSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    /// Working copy of the order — committed on Done
    @State private var workingOrder: [String] = []
    @State private var draggingID: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Reorder Modules")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Button("Done") { commit(); dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Divider()

            Text("Drag to reorder. This order appears in the utility rail.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Reorder list
            List {
                ForEach(workingOrder, id: \.self) { moduleID in
                    if let module = ModuleRegistry.module(for: moduleID) {
                        reorderRow(module: module, moduleID: moduleID)
                            .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
                .onMove { source, destination in
                    workingOrder.move(fromOffsets: source, toOffset: destination)
                }
            }
            .listStyle(.plain)
            .environment(\.editMode, .constant(.active))
            .frame(minHeight: 260)

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Reset to Default") { resetToDefault() }
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 380)
        .onAppear { workingOrder = appState.enabledModuleIDs }
    }

    @ViewBuilder
    private func reorderRow(module: any UtilityModule, moduleID: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: module.icon)
                .frame(width: 22, height: 22)
                .foregroundStyle(.secondary)

            Text(module.name)
                .font(.body)

            Spacer()

            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func commit() {
        appState.enabledModuleIDs = workingOrder
        appState.validateActiveModule()
    }

    private func resetToDefault() {
        workingOrder = ["todoList", "quickNotes", "clipboardHistory", "musicControl", "fileConverter", "timer"]
    }
}
