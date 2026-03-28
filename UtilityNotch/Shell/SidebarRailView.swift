import SwiftUI

/// Canonical sidebar rail. 48pt wide, full panel height.
///
/// Internal zones align with CanonicalShellView's left column:
///   Top blank zone  60pt — empty space that sits beside the header
///   Icon scroll zone  fills remaining height (~282pt in 380pt panel)
///   Gear zone       38pt — settings gear that sits beside the footer
///
/// Width (48pt) is set internally via frame. No external sizing needed.
/// Reads module list, active ID, and hover-label preference from AppState directly.
/// Command+drag reorders the module list.
struct SidebarRailView: View {
    @Environment(AppState.self) private var appState
    @State private var draggingID: String? = nil
    @State private var isCommandHeld: Bool = false
    @State private var commandKeyMonitor: Any? = nil
    @State private var hoveredModuleID: String? = nil

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
                                isActive: appState.activeModuleID == module.id,
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
            .frame(maxHeight: .infinity)

            // ── Gear zone (aligns with footer) ────────────────────────
            Divider()
                .opacity(0.08)
                .padding(.horizontal, 4)

            SidebarGearButton()
                .frame(height: UNConstants.footerHeight)
        }
        .frame(width: UNConstants.sidebarWidth)
        // Only visible divider: left border separating sidebar from content
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 0.5)
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

// MARK: - Sidebar Button

private struct SidebarButton: View {
    let icon: String
    let name: String
    let isActive: Bool
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
        // Tooltip floats to the left of the rail
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
        if isActive   { return UNConstants.accentHighlight }
        if isHovering { return Color.white.opacity(0.06) }
        return .clear
    }

    private var iconColor: Color {
        if isActive   { return UNConstants.iconActiveTint }
        if isHovering { return Color.white.opacity(0.85) }
        return Color.white.opacity(0.45)
    }
}

// MARK: - Gear Button

private struct SidebarGearButton: View {
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
