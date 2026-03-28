import SwiftUI

/// The one canonical shell layout, shared by both DI and Extended Panel modes.
///
/// Lives ABOVE the module-switching layer (ActiveModuleContainerView) so SwiftUI
/// never recreates it on module switch. Only the content slot (ActiveModuleContainerView)
/// updates when the active module changes.
///
/// All header/footer metadata (title, footer strings, action button) is read
/// reactively from AppState, where it is pushed by ModuleShellView on each
/// module view's appear / onChange cycle.
struct CanonicalShellView<Content: View>: View {
    @Environment(AppState.self) private var appState
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 0) {
            // ── Left: header + content + footer ───────────────────────
            VStack(spacing: 0) {
                header
                contentSlot
                footer
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ── Right: sidebar rail (48pt, full height) ────────────────
            SidebarRailView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header (60pt)
    // Rule 8: title left-aligned at 24pt, action button right at 24pt, SF Pro Semibold 16pt

    private var header: some View {
        HStack(spacing: 8) {
            Text(appState.moduleTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                // Crossfade title text to match content area transition
                .animation(.easeInOut(duration: 0.22), value: appState.activeModuleID)

            Spacer()

            // Action button — re-read when moduleActionButtonRevision changes
            if let builder = appState.moduleActionButtonBuilder {
                let _ = appState.moduleActionButtonRevision
                builder()
                    .animation(.easeInOut(duration: 0.22), value: appState.moduleActionButtonRevision)
            }
        }
        .padding(.horizontal, UNConstants.headerPaddingH)
        .frame(height: UNConstants.headerHeight)
    }

    // MARK: - Content slot

    private var contentSlot: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .clipped()
    }

    // MARK: - Footer (38pt)
    // Rule 9: SF Mono 10pt, uppercase, 60% white, 16pt padding, text only — no dot/icon

    private var footer: some View {
        HStack(spacing: 0) {
            Text(appState.moduleFooterLeft)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.60))
                .textCase(.uppercase)
                .kerning(0.08 * 10)
                .animation(.easeInOut(duration: 0.22), value: appState.moduleFooterLeft)

            Spacer()

            Text(appState.moduleFooterRight)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.60))
                .textCase(.uppercase)
                .kerning(0.08 * 10)
                .animation(.easeInOut(duration: 0.22), value: appState.moduleFooterRight)
        }
        .padding(.horizontal, UNConstants.footerPaddingH)
        .frame(height: UNConstants.footerHeight)
    }
}
