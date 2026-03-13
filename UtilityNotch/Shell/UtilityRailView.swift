import SwiftUI

/// Right-side vertical icon rail showing enabled utility modules.
/// Command+drag reorders modules; normal click selects.
struct UtilityRailView: View {
    @Environment(AppState.self) private var appState
    @State private var draggingID: String?
    @State private var isCommandHeld: Bool = false

    private var enabledModuleIDsBinding: Binding<[String]> {
        Binding(
            get: { appState.enabledModuleIDs },
            set: { appState.enabledModuleIDs = $0 }
        )
    }

    var body: some View {
        VStack(spacing: 6) {
            ForEach(enabledModules, id: \.id) { module in
                RailButton(
                    icon: module.icon,
                    name: module.name,
                    showLabel: appState.showHoverLabels,
                    isActive: appState.activeModuleID == module.id
                ) {
                    withAnimation(.spring(duration: 0.28, bounce: 0.16)) {
                        appState.selectModule(module.id)
                    }
                }
                .onDrag {
                    draggingID = module.id
                    return NSItemProvider(object: module.id as NSString)
                }
                .onDrop(of: [.text], delegate: ModuleDropDelegate(
                    item: module.id,
                    current: enabledModuleIDsBinding,
                    draggingID: $draggingID,
                    commandHeld: isCommandHeld
                ))
            }

            Spacer(minLength: 4)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .padding(.vertical, 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.04), lineWidth: 0.5)
                .padding(.vertical, 6)
        )
        .onAppear { installCommandKeyMonitor() }
    }

    private var enabledModules: [any UtilityModule] {
        appState.enabledModuleIDs.compactMap { ModuleRegistry.module(for: $0) }
    }

    /// Track whether the Command key is currently held via local key-flag events.
    private func installCommandKeyMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            isCommandHeld = event.modifierFlags.contains(.command)
            return event
        }
    }
}

// MARK: - Rail Button

private struct RailButton: View {
    let icon: String
    let name: String
    let showLabel: Bool
    let isActive: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(backgroundColor)

                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isActive ? UNConstants.iconActiveTint : UNConstants.iconTint)
                    .scaleEffect(isHovering ? 1.08 : 1.0)
                    .animation(.easeOut(duration: 0.14), value: isHovering)
            }
            .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
        .help(showLabel ? name : "")
    }

    private var backgroundColor: Color {
        if isActive {
            return UNConstants.accentHighlight
        } else if isHovering {
            return Color.white.opacity(0.06)
        }
        return .clear
    }
}

// MARK: - Drop Delegate

private struct ModuleDropDelegate: DropDelegate {
    let item: String
    @Binding var current: [String]
    @Binding var draggingID: String?
    let commandHeld: Bool

    func dropEntered(info: DropInfo) {
        guard commandHeld else { return }
        guard let draggingID, draggingID != item,
              let from = current.firstIndex(of: draggingID),
              let to = current.firstIndex(of: item) else { return }
        if current[to] != draggingID {
            withAnimation(.easeInOut(duration: 0.15)) {
                current.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
            }
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}
