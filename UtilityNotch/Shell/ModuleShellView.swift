import SwiftUI

// MARK: - Environment Keys
// Kept for source compatibility with module views that set them.
// They are no longer read by CanonicalShellView — the shell has no env-key branching.

private struct ShowModuleSidebarKey: EnvironmentKey { static let defaultValue = true }
private struct ShowDragHandleKey:    EnvironmentKey { static let defaultValue: Bool = true }
private struct ShowModuleHeaderKey:  EnvironmentKey { static let defaultValue: Bool = true }

extension EnvironmentValues {
    var showModuleSidebar: Bool {
        get { self[ShowModuleSidebarKey.self] }
        set { self[ShowModuleSidebarKey.self] = newValue }
    }
    var showDragHandle: Bool {
        get { self[ShowDragHandleKey.self] }
        set { self[ShowDragHandleKey.self] = newValue }
    }
    var showModuleHeader: Bool {
        get { self[ShowModuleHeaderKey.self] }
        set { self[ShowModuleHeaderKey.self] = newValue }
    }
}

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

/// Transparent pass-through that pushes module UI metadata into AppState.
///
/// Previously, this was a thin shim over CanonicalShellView. Now CanonicalShellView
/// lives ABOVE the module-switching layer (in DynamicIslandView and NotchPanelView)
/// and reads all metadata reactively from AppState. ModuleShellView's job is to
/// push the module-specific title, footer strings, and action button into AppState
/// on appear and whenever those values change.
///
/// All 7 module views call this with the same external API — no module changes needed.
struct ModuleShellView<Content: View>: View {
    let moduleTitle: String
    let moduleIcon: String
    // Legacy navigation params — accepted for source compat, not used
    let modules: [ModuleNavItem]
    let activeModuleID: String
    let onModuleSelect: (String) -> Void
    let statusDotColor: Color       // accepted for source compat, not rendered
    let statusLeft: String
    let statusRight: String
    let actionButton: (() -> AnyView)?
    @ViewBuilder let content: () -> Content

    @Environment(AppState.self) private var appState

    var body: some View {
        content()
            .onAppear {
                appState.moduleTitle = moduleTitle
                appState.moduleFooterLeft = statusLeft
                appState.moduleFooterRight = statusRight
                appState.setModuleActionButton(actionButton)
            }
            .onChange(of: statusLeft)  { _, new in appState.moduleFooterLeft  = new }
            .onChange(of: statusRight) { _, new in appState.moduleFooterRight = new }
    }
}

// MARK: - Nav Item Helper

/// Builds the ModuleNavItem list from the app's current enabled module order.
/// Still used by module views to populate the now-unused `modules:` param.
func shellNavItems(appState: AppState) -> [ModuleNavItem] {
    appState.enabledModuleIDs.compactMap { id in
        guard let m = ModuleRegistry.module(for: id) else { return nil }
        return ModuleNavItem(id: m.id, icon: m.icon, name: m.name)
    }
}

// MARK: - Action Button Helpers

/// Non-destructive pill button for use as actionButton in ModuleShellView.
func makeAddActionButton(icon: String, label: String) -> AnyView {
    AnyView(ShellActionButton(icon: icon, label: label, isDestructive: false))
}

/// Destructive pill button for use as actionButton in ModuleShellView.
func makeDestructiveActionButton(icon: String, label: String) -> AnyView {
    AnyView(ShellActionButton(icon: icon, label: label, isDestructive: true))
}

private struct ShellActionButton: View {
    let icon: String
    let label: String
    let isDestructive: Bool

    private var bgColor: Color {
        isDestructive ? Color(red: 1.0, green: 0.271, blue: 0.227).opacity(0.15)
                      : Color.white.opacity(0.1)
    }
    private var fgColor: Color {
        isDestructive ? Color(red: 1.0, green: 0.271, blue: 0.227)
                      : Color.white
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(fgColor)

            Text(label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .textCase(.uppercase)
                .kerning(0.55)
                .foregroundStyle(fgColor)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .background(Capsule().fill(bgColor))
    }
}
