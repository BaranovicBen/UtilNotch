import SwiftUI

// MARK: - Color hex extension

extension Color {
    /// Initialize a Color from a 6-digit hex string (e.g. "0A84FF").
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >>  8) & 0xFF) / 255.0
        let b = Double(int         & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - ModuleNavItem

struct ModuleNavItem: Identifiable {
    let id: String
    let icon: String
    let name: String
}

// MARK: - ModuleShellView

/// Full-panel shell wrapping every module.
/// Provides: drag handle, header row, content slot, footer bar, right sidebar.
/// CSS source: /DesignReference/Css/template.css + DESIGN.md
struct ModuleShellView<Content: View>: View {
    let moduleTitle: String
    let moduleIcon: String
    let modules: [ModuleNavItem]
    let activeModuleID: String
    let onModuleSelect: (String) -> Void
    let statusDotColor: Color
    let statusLeft: String
    let statusRight: String
    let actionButton: (() -> AnyView)?
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 0) {
            // ── LEFT COLUMN: main content (fills all width minus 40px sidebar) ──
            VStack(spacing: 0) {
                dragHandle
                headerRow
                contentSlot
                footerBar
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ── RIGHT COLUMN: sidebar (40px fixed) ──
            sidebarRail
                .frame(width: 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 1. Drag Handle
    // CSS: padding: 8px 0px 0px; handle: 36×5px rgba(255,255,255,0.2) radius 9999px

    private var dragHandle: some View {
        HStack {
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 5)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - 2. Header Row
    // CSS: height 44px, padding 0px 16px, border-bottom 1px rgba(255,255,255,0.1)
    // Title: Inter semibold 17px, letter-spacing -0.425px, #FFFFFF
    // Icon: #0A84FF
    // Action button (non-destructive): bg rgba(255,255,255,0.1), radius 9999px, padding 4px 12px
    // Action button (destructive): bg rgba(255,69,58,0.15), radius 9999px, padding 4px 12px

    private var headerRow: some View {
        HStack(spacing: 0) {
            // Icon + title group
            HStack(spacing: 8) {
                Image(systemName: moduleIcon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(red: 0.039, green: 0.518, blue: 1.0)) // #0A84FF

                Text(moduleTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.425)
                    .foregroundStyle(Color.white)
            }

            Spacer()

            // Optional action button
            if let actionButton {
                actionButton()
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
        }
    }

    // MARK: - 3. Content Slot
    // CSS: padding 8px 16px (from template.css "Main - 3. CONTENT AREA")

    private var contentSlot: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .clipped()
    }

    // MARK: - 4. Footer Bar
    // CSS: height 28px, padding 0px 16px, bottom padding 10px
    // Status dot: 6×6px, radius 9999px
    // Text: JetBrains Mono / Liberation Mono regular 11px, letter-spacing 0.55px, uppercase
    // Text color: rgba(255,255,255,0.35)

    private var footerBar: some View {
        HStack(spacing: 0) {
            // Left side: dot + status text
            HStack(spacing: 8) {
                Circle()
                    .fill(statusDotColor)
                    .frame(width: 6, height: 6)

                Text(statusLeft)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .textCase(.uppercase)
                    .kerning(0.55)
            }

            Spacer()

            // Right side: status text
            Text(statusRight)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.35))
                .textCase(.uppercase)
                .kerning(0.55)
        }
        .padding(.horizontal, 16)
        .frame(height: 28)
        .padding(.bottom, 10)
    }

    // MARK: - 5. Sidebar (Right Rail)
    // CSS: width 40px, padding 16px 0px, border-left 1px rgba(255,255,255,0.05)
    // Icon buttons: 32×32px, radius 8px
    // Active: bg rgba(255,255,255,0.1), icon #FFFFFF
    // Inactive: no bg, icon rgba(255,255,255,0.35)
    // Hover: bg rgba(255,255,255,0.06), icon rgba(255,255,255,0.85)
    // Settings gear pinned at bottom, border-top 1px rgba(255,255,255,0.05)

    private var sidebarRail: some View {
        VStack(spacing: 0) {
            // Scrollable module icons with top/bottom fade
            ZStack {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(modules) { item in
                            ShellRailButton(
                                icon: item.icon,
                                name: item.name,
                                isActive: activeModuleID == item.id
                            ) {
                                onModuleSelect(item.id)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.06),
                            .init(color: .black, location: 0.94),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            // Settings gear pinned at bottom
            // CSS: border-top: 1px solid rgba(255,255,255,0.05), padding 8px 0 0
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 1)
                .padding(.horizontal, 4)

            ShellSettingsButton()
                .padding(.top, 4)
                .padding(.bottom, 6)
        }
        .overlay(alignment: .leading) {
            // CSS: border-left: 1px solid rgba(255, 255, 255, 0.05)
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 1)
        }
    }
}

// MARK: - Shell Rail Button

/// Individual icon button in the sidebar.
/// CSS: 32×32px container, radius 8px, icon sizes per module
private struct ShellRailButton: View {
    let icon: String
    let name: String
    let isActive: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(backgroundColor)

                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(iconColor)
                    .scaleEffect(isHovering ? 1.07 : 1.0)
                    .animation(.easeOut(duration: 0.14), value: isHovering)
            }
            .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovering = hovering }
        }
        // Tooltip floats to the LEFT of the rail
        .overlay(alignment: .trailing) {
            if isHovering {
                Text(name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(white: 0.18))
                    )
                    .fixedSize()
                    .offset(x: -40)
                    .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .trailing)))
                    .zIndex(100)
            }
        }
    }

    // CSS: active bg rgba(255,255,255,0.1); hover bg rgba(255,255,255,0.06); inactive: clear
    private var backgroundColor: Color {
        if isActive { return Color.white.opacity(0.1) }
        if isHovering { return Color.white.opacity(0.06) }
        return .clear
    }

    // CSS: active icon #FFFFFF; hover rgba(255,255,255,0.85); inactive rgba(255,255,255,0.35)
    private var iconColor: Color {
        if isActive { return Color(red: 0.039, green: 0.518, blue: 1.0) } // #0A84FF active
        if isHovering { return Color.white.opacity(0.85) }
        return Color.white.opacity(0.35)
    }
}

// MARK: - Shell Settings Button

private struct ShellSettingsButton: View {
    @State private var isHovering = false

    var body: some View {
        Button {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovering ? Color.white.opacity(0.06) : Color.clear)

                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .regular))
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

// MARK: - Nav Item Helper

/// Builds the list of ModuleNavItem from the app's current enabled module order.
/// Call from within a view that has @Environment(AppState.self).
func shellNavItems(appState: AppState) -> [ModuleNavItem] {
    appState.enabledModuleIDs.compactMap { id in
        guard let m = ModuleRegistry.module(for: id) else { return nil }
        return ModuleNavItem(id: m.id, icon: m.icon, name: m.name)
    }
}

// MARK: - Action Button Helpers

/// Non-destructive pill button for use as actionButton in ModuleShellView.
/// CSS: bg rgba(255,255,255,0.1), radius 9999px, padding 4px 12px
/// Text: 11px SF Mono, uppercase, letter-spacing 0.55, color #FFFFFF
func makeAddActionButton(icon: String, label: String) -> AnyView {
    AnyView(ShellActionButton(icon: icon, label: label, isDestructive: false))
}

/// Destructive pill button for use as actionButton in ModuleShellView.
/// CSS: bg rgba(255,69,58,0.15), radius 9999px, padding 4px 12px
/// Icon/text color: #FF453A
func makeDestructiveActionButton(icon: String, label: String) -> AnyView {
    AnyView(ShellActionButton(icon: icon, label: label, isDestructive: true))
}

private struct ShellActionButton: View {
    let icon: String
    let label: String
    let isDestructive: Bool

    // CSS non-destructive: bg rgba(255,255,255,0.1), color #FFFFFF
    // CSS destructive: bg rgba(255,69,58,0.15), color #FF453A
    private var bgColor: Color {
        isDestructive ? Color(red: 1.0, green: 0.271, blue: 0.227).opacity(0.15)
                      : Color.white.opacity(0.1)
    }
    private var fgColor: Color {
        isDestructive ? Color(red: 1.0, green: 0.271, blue: 0.227) // #FF453A
                      : Color.white
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(fgColor)

            Text(label)
                // CSS: font-weight 700 (bold), 11px, uppercase, letter-spacing 0.55px
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .textCase(.uppercase)
                .kerning(0.55)
                .foregroundStyle(fgColor)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .background(
            Capsule()
                .fill(bgColor)
        )
    }
}
