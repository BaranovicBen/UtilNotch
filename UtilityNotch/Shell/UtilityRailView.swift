import SwiftUI

/// Right-side vertical icon rail showing enabled utility modules.
/// 40pt wide, 32×32 icon targets (18pt icons), scrollable with top/bottom fade masks.
/// Settings gear pinned below scroll area. Custom hover tooltip.
/// Command+drag reorders modules.
struct UtilityRailView: View {
    @Environment(AppState.self) private var appState
    @State private var draggingID: String?
    @State private var isCommandHeld: Bool = false
    @State private var commandKeyMonitor: Any?
    @State private var hoveredModuleID: String? = nil

    private var enabledModuleIDsBinding: Binding<[String]> {
        Binding(
            get: { appState.enabledModuleIDs },
            set: { appState.enabledModuleIDs = $0 }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Scrollable module buttons with fade mask ─────────────
            ZStack {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(enabledModules, id: \.id) { module in
                            RailButton(
                                icon: module.icon,
                                name: module.name,
                                isActive: appState.activeModuleID == module.id,
                                isHoveredExternally: hoveredModuleID == module.id,
                                showTooltip: appState.showHoverLabels
                            ) {
                                withAnimation(.spring(duration: 0.28, bounce: 0.16)) {
                                    appState.selectModule(module.id)
                                }
                            } onHoverChange: { hovering in
                                hoveredModuleID = hovering ? module.id : nil
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
                    }
                    .padding(.vertical, 8)
                }
                // Fade mask — top and bottom edges fade to transparent
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear,   location: 0),
                            .init(color: .black,   location: 0.06),
                            .init(color: .black,   location: 0.94),
                            .init(color: .clear,   location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            // ── Settings gear (pinned to bottom) ────────────────────
            Divider()
                .opacity(0.08)
                .padding(.horizontal, 4)

            SettingsGearButton()
                .padding(.bottom, 6)
                .padding(.top, 4)
        }
        .frame(width: UNConstants.railWidth)
        .onAppear { installCommandKeyMonitor() }
        .onDisappear { removeCommandKeyMonitor() }
    }

    private var enabledModules: [any UtilityModule] {
        appState.enabledModuleIDs.compactMap { ModuleRegistry.module(for: $0) }
    }

    private func installCommandKeyMonitor() {
        commandKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            isCommandHeld = event.modifierFlags.contains(.command)
            return event
        }
    }

    private func removeCommandKeyMonitor() {
        if let monitor = commandKeyMonitor {
            NSEvent.removeMonitor(monitor)
            commandKeyMonitor = nil
        }
    }
}

// MARK: - Rail Button

private struct RailButton: View {
    let icon: String
    let name: String
    let isActive: Bool
    let isHoveredExternally: Bool
    let showTooltip: Bool
    let action: () -> Void
    let onHoverChange: (Bool) -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(backgroundColor)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(iconColor)
                    .scaleEffect(isHovering ? 1.07 : 1.0)
                    .animation(.easeOut(duration: 0.14), value: isHovering)
            }
            .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovering = hovering }
            onHoverChange(hovering)
        }
        // Tooltip shown to the left of the rail
        .overlay(alignment: .trailing) {
            if isHovering && showTooltip {
                Text(name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(white: 0.18))
                            .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
                    )
                    .fixedSize()
                    .offset(x: -40)
                    .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .trailing)))
                    .zIndex(100)
            }
        }
    }

    private var backgroundColor: Color {
        if isActive { return UNConstants.accentHighlight }
        if isHovering { return Color.white.opacity(0.06) }
        return .clear
    }

    private var iconColor: Color {
        if isActive { return UNConstants.iconActiveTint }
        if isHovering { return Color.white.opacity(0.85) }
        return Color.white.opacity(0.45)
    }
}

// MARK: - Settings Gear Button

private struct SettingsGearButton: View {
    @State private var isHovering = false

    var body: some View {
        Button {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovering ? Color.white.opacity(0.06) : Color.clear)
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(isHovering ? Color.white.opacity(0.85) : Color.white.opacity(0.35))
                    .scaleEffect(isHovering ? 1.07 : 1.0)
                    .animation(.easeOut(duration: 0.14), value: isHovering)
            }
            .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeInOut(duration: 0.12)) { isHovering = h } }
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
