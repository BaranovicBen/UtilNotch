import SwiftUI

/// Canonical sidebar rail. 48pt wide, full panel height.
/// Zones align with CanonicalShellView:
///   Top blank zone: 60pt (aligns with header)
///   Icon scroll zone: fills remaining height
///   Gear zone: 38pt (aligns with footer)
struct SidebarRailView: View {
    @Environment(AppState.self) private var appState
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
            // ── Top blank zone (aligns with header) ───────────────────
            Color.clear
                .frame(height: UNConstants.headerHeight)

            // ── Icon scroll zone ──────────────────────────────────────
            ZStack {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(enabledModules, id: \.id) { module in
                            SidebarButton(
                                icon: module.icon,
                                name: module.name,
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

            // ── Gear zone (aligns with footer) ────────────────────────
            SidebarGearButton()
                .frame(height: UNConstants.footerHeight)
        }
        .frame(width: UNConstants.sidebarWidth)
        // Sidebar left border — the ONLY allowed structural divider in the app (Rule 7)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.white.opacity(0.15))
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
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(backgroundColor)

                Image(systemName: icon)
                    .font(.system(size: UNConstants.sidebarIconSize, weight: .medium))
                    .foregroundStyle(iconColor)
                    .scaleEffect(isHovering ? 1.07 : 1.0)
                    .animation(.easeOut(duration: 0.14), value: isHovering)
            }
            .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovering = hovering }
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
                    .foregroundStyle(Color.white.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.black.opacity(0.60))
                    )
                    .fixedSize()
                    .offset(x: -44)
                    .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .trailing)))
                    .zIndex(100)
            }
        }
    }

    private var backgroundColor: Color {
        if isActive   { return UNConstants.accentHighlight }  // rgba(255,255,255,0.08)
        if isHovering { return Color.white.opacity(UNConstants.hoverStateOpacity) }
        return .clear
    }

    private var iconColor: Color {
        if isActive   { return UNConstants.iconActiveTint }           // #0A84FF
        if isHovering { return Color.white }                           // 100% on hover
        return Color.white.opacity(UNConstants.sidebarInactiveOpacity) // 35% inactive
    }
}

// MARK: - Gear Button (no tooltip per Rule 6)

private struct SidebarGearButton: View {
    @State private var isHovering = false

    var body: some View {
        SettingsLink {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovering ? Color.white.opacity(UNConstants.hoverStateOpacity) : Color.clear)

                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(isHovering ? Color.white : Color.white.opacity(0.50))
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
