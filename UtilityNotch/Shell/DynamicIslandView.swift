import SwiftUI

/// Dynamic Island panel style.
/// Idle: small pill at top-center. Hover/trigger: spring-expands to show active module content.
/// Uses the same ModuleRegistry + AppState as the standard Expanded Panel — no separate data layer.
struct DynamicIslandView: View {
    @Environment(AppState.self) private var appState
    @State private var isExpanded: Bool = false
    @State private var showContent: Bool = false
    @State private var isPanelDropTargeted = false
    /// Suppresses close-on-hover-exit for 600ms after an open sequence begins.
    /// Prevents the race where the expanding panel window causes a spurious hover-exit
    /// on the trigger zone, which would immediately fire the close sequence.
    @State private var suppressClose: Bool = false

    // Collapsed pill geometry
    private let collapsedWidth:  CGFloat = 180
    private let collapsedHeight: CGFloat = 36

    // Expanded geometry — narrower than full panel, same height
    private let expandedWidth:   CGFloat = UNConstants.panelWidth
    private let expandedHeight:  CGFloat = UNConstants.panelHeight

    var body: some View {
        VStack(spacing: 0) {
        ZStack(alignment: .top) {
            // ── Morphing capsule background ─────────────────────────
            // DI expanded: sharp top corners (flush with notch/bezel), rounded bottom.
            // Collapsed pill: uniform corner radius.
            UnevenRoundedRectangle(
                topLeadingRadius:     isExpanded ? 0 : collapsedHeight / 2,
                bottomLeadingRadius:  isExpanded ? UNConstants.panelCornerRadius : collapsedHeight / 2,
                bottomTrailingRadius: isExpanded ? UNConstants.panelCornerRadius : collapsedHeight / 2,
                topTrailingRadius:    isExpanded ? 0 : collapsedHeight / 2,
                style: .continuous
            )
            .fill(.ultraThinMaterial)
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius:     isExpanded ? 0 : collapsedHeight / 2,
                    bottomLeadingRadius:  isExpanded ? UNConstants.panelCornerRadius : collapsedHeight / 2,
                    bottomTrailingRadius: isExpanded ? UNConstants.panelCornerRadius : collapsedHeight / 2,
                    topTrailingRadius:    isExpanded ? 0 : collapsedHeight / 2,
                    style: .continuous
                )
                .fill(UNConstants.panelBackground)
            )
            .overlay(
                Group {
                    if isExpanded {
                        // Open-path border: left + bottom + right edges ONLY.
                        // UnevenRoundedRectangle.strokeBorder draws all four edges —
                        // including a straight horizontal line at y=0 (the top) — even
                        // when topRadius = 0. That 1px line is visible against the notch
                        // hardware. DIExpandedBorderShape omits the top edge entirely.
                        DIExpandedBorderShape(cornerRadius: UNConstants.panelCornerRadius)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    } else {
                        // Floating pill: all four edges need the specular highlight
                        UnevenRoundedRectangle(
                            topLeadingRadius:     collapsedHeight / 2,
                            bottomLeadingRadius:  collapsedHeight / 2,
                            bottomTrailingRadius: collapsedHeight / 2,
                            topTrailingRadius:    collapsedHeight / 2,
                            style: .continuous
                        )
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    }
                }
            )
            .overlay(
                Group {
                    if isExpanded {
                        UnevenRoundedRectangle(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: UNConstants.panelCornerRadius,
                            bottomTrailingRadius: UNConstants.panelCornerRadius,
                            topTrailingRadius: 0,
                            style: .continuous
                        )
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: "0A84FF").opacity(UNConstants.panelGlowOpacity),
                                    Color.clear
                                ]),
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 300
                            )
                        )
                    }
                }
            )
            .shadow(color: .black.opacity(isExpanded ? 0.4 : 0.25), radius: isExpanded ? 28 : 12, y: isExpanded ? 8 : 4)
            .frame(
                width:  isExpanded ? expandedWidth  : collapsedWidth,
                height: isExpanded ? expandedHeight : collapsedHeight
            )

            // ── Collapsed indicator (pill content) ──────────────────
            if !isExpanded {
                collapsedContent
                    .frame(width: collapsedWidth, height: collapsedHeight)
                    .transition(.opacity)
            }

            // ── Expanded module content (delayed fade-in so shape morphs first) ─
            if isExpanded {
                expandedContent
                    .frame(width: expandedWidth, height: expandedHeight)
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeIn(duration: 0.12), value: showContent)
                    .transition(.opacity)
            }
        }
        // Clip to the current pill/panel shape so content never overflows during morph
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius:     isExpanded ? 0 : collapsedHeight / 2,
                bottomLeadingRadius:  isExpanded ? UNConstants.panelCornerRadius : collapsedHeight / 2,
                bottomTrailingRadius: isExpanded ? UNConstants.panelCornerRadius : collapsedHeight / 2,
                topTrailingRadius:    isExpanded ? 0 : collapsedHeight / 2,
                style: .continuous
            )
        )
        // Size the frame to the larger of the two states so the animation has room
        .frame(
            width:  isExpanded ? expandedWidth  : collapsedWidth,
            height: isExpanded ? expandedHeight : collapsedHeight
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            appState.isPointerInsidePanel = hovering
            // Suppress close during the 600ms lock window that follows every open.
            // This prevents the race where the panel window appearing causes a
            // spurious hover-exit event that would immediately collapse the panel.
            if !hovering && suppressClose { return }
            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                isExpanded = hovering
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isPanelDropTargeted) { providers in
            handlePanelDrop(providers)
        }
        .onChange(of: isPanelDropTargeted) { _, targeted in
            if targeted { appState.dismissalLocks.insert(.dragDrop) }
            else { appState.dismissalLocks.remove(.dragDrop) }
            if targeted, !isExpanded {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { isExpanded = true }
            }
        }
        .onAppear {
            isExpanded = false
            showContent = false
        }
        .onChange(of: isExpanded) { _, expanded in
            if expanded {
                // Start 600ms close-suppression lock — prevents spurious hover-exit
                // events from the appearing panel window from collapsing the panel.
                suppressClose = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    suppressClose = false
                }
                // Rule 11: frame expands first (spring response=0.38, ~80% settled at 0.30s),
                // then content fades in UNConstants.contentFadeDelay (0.08s) after that.
                let delay = 0.30 + UNConstants.contentFadeDelay
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    showContent = true
                }
            } else {
                // Rule 11 close: content fades out first, then frame collapses
                showContent = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    isExpanded = false
                }
            }
        }
        .onChange(of: appState.isPanelVisible) { _, visible in
            if visible {
                isExpanded = false
                showContent = false
                // Start 600ms close-suppression lock on programmatic open too
                suppressClose = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    suppressClose = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                        isExpanded = true
                    }
                }
            } else {
                suppressClose = false
                isExpanded = false
                showContent = false
            }
        }
        .environment(\.colorScheme, .dark)

        Spacer(minLength: 0)
        } // VStack
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Collapsed Pill

    /// Shows a small ambient indicator when a background state is active (timer running, music playing).
    @ViewBuilder
    private var collapsedContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.expand.vertical")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))

            Text("Utility Notch")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.65))

            Spacer(minLength: 0)

            // Ambient indicator for active states (music or timer)
            ambientIndicator
        }
        .padding(.horizontal, 14)
    }

    @ViewBuilder
    private var ambientIndicator: some View {
        // Music playing ambient glyph
        if appState.activeModuleID == "musicControl" {
            Image(systemName: "music.note")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.purple.opacity(0.8))
        }
    }

    // MARK: - Expanded Content

    // CanonicalShellView is the stable shell that hosts the switching content slot.
    // It lives here, above ActiveModuleContainerView, so switching modules only
    // updates the content — never the shell, header, footer, or sidebar.
    @ViewBuilder
    private var expandedContent: some View {
        CanonicalShellView {
            ActiveModuleContainerView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Drop Handling

    private func handlePanelDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                DispatchQueue.main.async {
                    appState.pendingFileURL = url
                    appState.selectModule("fileConverter")
                    appState.showPanel()
                }
            }
        }
        return true
    }
}

// MARK: - DI expanded border shape

/// Open-path shape that draws only the LEFT + BOTTOM + RIGHT edges of the panel —
/// the top edge is intentionally omitted.
///
/// Why: `UnevenRoundedRectangle(topRadius: 0).strokeBorder(...)` still renders a
/// straight 1px horizontal line at y = 0 (the top of the rect). In DI mode the panel
/// top is flush with the hardware notch/bezel, so that line is visible as a white seam.
/// This shape's path starts at top-left, traces left → bottom → right, and stops at
/// top-right without closing — leaving the top edge completely empty.
private struct DIExpandedBorderShape: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = cornerRadius
        // Start at top-left (sharp corner, flush with screen top — no arc)
        p.move(to: CGPoint(x: 0, y: 0))
        // Left edge down to bottom-left corner tangent point
        p.addLine(to: CGPoint(x: 0, y: rect.maxY - r))
        // Bottom-left corner (addArc with tangents handles coordinate-system ambiguity)
        p.addArc(
            tangent1End: CGPoint(x: 0,         y: rect.maxY),
            tangent2End: CGPoint(x: r,         y: rect.maxY),
            radius: r
        )
        // Bottom edge across to bottom-right corner tangent point
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.maxY))
        // Bottom-right corner
        p.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.maxX, y: rect.maxY - r),
            radius: r
        )
        // Right edge up to top-right (sharp corner — path ends here, not closed)
        p.addLine(to: CGPoint(x: rect.maxX, y: 0))
        // Intentionally NOT closed — top edge absent
        return p
    }
}
