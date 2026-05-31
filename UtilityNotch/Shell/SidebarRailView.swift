import SwiftUI

/// Canonical sidebar rail. 48pt wide, full panel height.
/// Zones align with CanonicalShellView:
///   Top blank zone: 60pt (aligns with header)
///   Icon scroll zone: fills remaining height
///   Gear zone: 38pt (aligns with footer)
struct SidebarRailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draggingID: String? = nil
    @State private var commandKeyMonitor: Any? = nil
    @State private var isCommandHeld: Bool = false

    private var enabledModuleIDsBinding: Binding<[String]> {
        Binding(
            get: { appState.enabledModuleIDs },
            set: { appState.enabledModuleIDs = $0 }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: UNConstants.headerHeight)

            ZStack {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(enabledModules, id: \.id) { module in
                            SidebarButton(
                                icon: module.icon,
                                name: module.name,
                                isActive: appState.activeModuleID == module.id
                            ) {
                                withAnimation(reduceMotion ? UNMotion.reduced : UNMotion.moduleSwitch) {
                                    appState.selectModule(module.id)
                                }
                            }
                            .onDrag {
                                draggingID = module.id
                                return NSItemProvider(object: module.id as NSString)
                            }
                            .onDrop(of: [.text], delegate: SidebarDropDelegate(
                                item: module.id,
                                current: enabledModuleIDsBinding,
                                draggingID: $draggingID,
                                commandHeld: isCommandHeld
                            ))
                        }
                    }
                    .padding(.vertical, 4)
                }
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black,  location: 0.06),
                            .init(color: .black,  location: 0.94),
                            .init(color: .clear,  location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .frame(maxHeight: .infinity)

            SidebarGearButton()
                .frame(height: UNConstants.footerHeight)
        }
        .frame(width: UNConstants.sidebarWidth)
        .background(UNConstants.insetSurface)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(UNConstants.sidebarBorder)
                .frame(width: 1)
        }
        .onAppear  { installCommandKeyMonitor() }
        .onDisappear { removeCommandKeyMonitor() }
    }

    // MARK: - Helpers

    private var enabledModules: [any UtilityModule] {
        appState.enabledModuleIDs.compactMap { ModuleRegistry.module(for: $0) }
    }

    private func installCommandKeyMonitor() {
        commandKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            self.isCommandHeld = event.modifierFlags.contains(.command)
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

// MARK: - Sidebar Button with 150ms tooltip delay

private struct SidebarButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let icon: String
    let name: String
    let isActive: Bool
    let action: () -> Void

    @State private var isHovering = false
    @State private var showTooltip = false
    @State private var tooltipTask: Task<Void, Never>? = nil

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(backgroundColor)

                Image(systemName: icon)
                    .font(.system(size: UNConstants.sidebarIconSize, weight: .medium))
                    .foregroundStyle(iconColor)
                    .scaleEffect(reduceMotion ? 1 : (isHovering ? 1.07 : 1.0))
                    .animation(reduceMotion ? UNMotion.reduced : UNMotion.tap, value: isHovering)
            }
            .frame(width: UNConstants.hudButtonSize, height: UNConstants.hudButtonSize)
        }
        .buttonStyle(.pressFeedback)
        .onHover { hovering in
            withAnimation(reduceMotion ? UNMotion.reduced : UNMotion.hover) { isHovering = hovering }
            if hovering {
                // 150ms delay before showing tooltip (Rule 6 / DESIGN.md §6)
                tooltipTask?.cancel()
                tooltipTask = Task {
                    try? await Task.sleep(for: .seconds(UNConstants.sidebarTooltipDelay))
                    guard !Task.isCancelled else { return }
                    await MainActor.run { showTooltip = true }
                }
            } else {
                tooltipTask?.cancel()
                tooltipTask = nil
                showTooltip = false
            }
        }
        // Tooltip: left of icon, vertically centered (Rule 6 / DESIGN.md §6)
        .overlay(alignment: .trailing) {
            if showTooltip {
                Text(name)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(UNConstants.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(UNConstants.tooltipSurface)
                    )
                    .fixedSize()
                    .offset(x: -44)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.92, anchor: .trailing)))
                    .zIndex(100)
            }
        }
    }

    private var backgroundColor: Color {
        if isActive   { return UNConstants.selectedSurface }
        if isHovering { return Color.white.opacity(UNConstants.hoverStateOpacity) }
        return .clear
    }

    private var iconColor: Color {
        if isActive   { return UNConstants.iconActiveTint }
        if isHovering { return Color.white }
        return Color.white.opacity(UNConstants.sidebarInactiveOpacity)
    }
}

// MARK: - Gear Button (no tooltip per Rule 6)

private struct SidebarGearButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        SettingsLink {
            ZStack {
                Circle()
                    .fill(isHovering ? Color.white.opacity(UNConstants.hoverStateOpacity) : Color.clear)

                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(isHovering ? Color.white : Color.white.opacity(0.50))
                    .scaleEffect(reduceMotion ? 1 : (isHovering ? 1.07 : 1.0))
                    .animation(reduceMotion ? UNMotion.reduced : UNMotion.tap, value: isHovering)
            }
            .frame(width: UNConstants.hudButtonSize, height: UNConstants.hudButtonSize)
        }
        .buttonStyle(.pressFeedback)
        .onHover { h in withAnimation(reduceMotion ? UNMotion.reduced : UNMotion.hover) { isHovering = h } }
    }
}
// MARK: - Drop Delegate

private struct SidebarDropDelegate: DropDelegate {
    let item: String
    @Binding var current: [String]
    @Binding var draggingID: String?
    let commandHeld: Bool

    func dropEntered(info: DropInfo) {
        guard commandHeld else { return }
        guard let draggingID, draggingID != item,
              let from = current.firstIndex(of: draggingID),
              let to   = current.firstIndex(of: item) else { return }
        if current[to] != draggingID {
            withAnimation(UNMotion.dragDisplace) {
                current.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
            }
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}
