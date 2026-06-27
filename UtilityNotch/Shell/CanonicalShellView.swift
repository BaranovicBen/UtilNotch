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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                header
                contentSlot
                footer
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            SidebarRailView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header (60pt)
    // Rule 8: title left-aligned at 24pt, action button right at 24pt, SF Pro Semibold 16pt

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(appState.moduleTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(UNConstants.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(UNConstants.textTertiary)

                    Text(appState.commandShelfStatusText)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(UNConstants.textTertiary)
                        .lineLimit(1)
                }
            }
            .animation(shellAnimation, value: appState.activeModuleID)

            Spacer()

            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10, weight: .medium))
                Text("⌘K")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
            }
            .foregroundStyle(UNConstants.textTertiary)
            .help("Command search placeholder")

            if let builder = appState.moduleActionButtonBuilder {
                let _ = appState.moduleActionButtonRevision
                builder()
                    .animation(shellAnimation, value: appState.moduleActionButtonRevision)
            }
        }
        .padding(.horizontal, UNConstants.headerPaddingH)
        .frame(height: UNConstants.headerHeight)
    }

    // MARK: - Content slot

    private var contentSlot: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, UNConstants.contentPaddingH)
            .padding(.vertical, UNConstants.contentPaddingV)
            .background {
                ZStack {
                    UNConstants.contentLift
                    // A user-set module accent overrides the built-in environmental tint.
                    if let custom = appState.moduleColors.accentColor(for: appState.activeModuleID) {
                        custom.opacity(0.05)
                    } else {
                        activeModule?.contentTint ?? Color.clear
                    }
                }
            }
            .clipped()
            .animation(shellAnimation, value: appState.activeModuleID)
    }

    private var activeModule: (any UtilityModule)? {
        ModuleRegistry.module(for: appState.activeModuleID)
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
                .animation(shellAnimation, value: appState.moduleFooterLeft)

            Spacer()

            Text(appState.moduleFooterRight)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.60))
                .textCase(.uppercase)
                .kerning(0.08 * 10)
                .animation(shellAnimation, value: appState.moduleFooterRight)
        }
        .padding(.horizontal, UNConstants.footerPaddingH)
        .frame(height: UNConstants.footerHeight)
    }

    private var shellAnimation: Animation {
        reduceMotion ? UNMotion.reduced : UNMotion.contentFade
    }
}
