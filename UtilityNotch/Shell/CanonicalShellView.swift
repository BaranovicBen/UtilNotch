import SwiftUI

struct CanonicalShellView<Content: View>: View {

    let moduleTitle: String
    let moduleIcon: String
    let statusDotColor: Color   // kept for API compat, not rendered
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
    // Rule 8: title left-aligned at 24pt, action button right at 24pt, SF Pro Semibold 16pt

    private var header: some View {
        HStack(spacing: 8) {
            Text(moduleTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            if let actionButton {
                actionButton()
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
            Text(statusLeft)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.60))
                .textCase(.uppercase)
                .kerning(0.08 * 10)

            Spacer()

            Text(statusRight)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.60))
                .textCase(.uppercase)
                .kerning(0.08 * 10)
        }
        .padding(.horizontal, UNConstants.footerPaddingH)
        .frame(height: UNConstants.footerHeight)
    }
}
