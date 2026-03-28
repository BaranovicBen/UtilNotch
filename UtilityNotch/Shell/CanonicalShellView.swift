import SwiftUI

/// The one canonical shell layout used by both Extended Panel and Dynamic Island expanded state.
///
/// Layout contract (design system dimensions):
///
///   ┌─────────────────────────────────────────┬──────────┐
///   │  Header 60pt  icon · title · actionBtn  │  blank   │  ← top zone
///   ├─────────────────────────────────────────┤  60pt    │
///   │                                         ├──────────┤
///   │  Content area  (fills: ~282pt at 380    │  icons   │  ← scrollable module buttons
///   │   panel height with 60+38 consumed)     │  fills   │
///   │                                         ├──────────┤
///   ├─────────────────────────────────────────┤  gear    │  ← gear zone
///   │  Footer 38pt   dot · left · right       │  38pt    │
///   └─────────────────────────────────────────┴──────────┘
///         maxWidth: .infinity               48pt fixed
///
/// Modules pass: title, icon, statusDotColor, statusLeft, statusRight, actionButton, content.
/// Navigation state (module list, active ID, selection) is owned by SidebarRailView via AppState.
/// This view has no background — the presenter wrapper (NotchPanelView / DynamicIslandView) supplies it.
struct CanonicalShellView<Content: View>: View {

    let moduleTitle: String
    let moduleIcon: String
    let statusDotColor: Color
    let statusLeft: String
    let statusRight: String
    let actionButton: (() -> AnyView)?
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

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: moduleIcon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(red: 0.039, green: 0.518, blue: 1.0))  // #0A84FF

            Text(moduleTitle)
                .font(.system(size: 17, weight: .semibold))
                .tracking(-0.425)
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            if let actionButton {
                actionButton()
            }
        }
        .padding(.horizontal, 16)
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

    private var footer: some View {
        HStack(spacing: 0) {
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

            Text(statusRight)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.35))
                .textCase(.uppercase)
                .kerning(0.55)
        }
        .padding(.horizontal, 16)
        .frame(height: UNConstants.footerHeight)
    }
}
