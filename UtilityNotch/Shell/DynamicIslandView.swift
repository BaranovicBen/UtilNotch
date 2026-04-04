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
                        // Open-path border: concave top corners + left + bottom + right.
                        // Top edge is intentionally omitted (no horizontal seam against the notch).
                        // Concave arcs at top-left and top-right match the outer radius of the notch pill.
                        DIExpandedBorderShape(
                            cornerRadius: UNConstants.panelCornerRadius,
                            invertedCornerRadius: UNConstants.invertedCornerRadius
                        )
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
        // Clip to the current shape so content never overflows during morph.
        // Expanded: NotchPanelShape gives concave top corners matching the notch pill.
        // Collapsed: standard pill (capsule via UnevenRoundedRectangle).
        .clipShape(
            isExpanded
                ? AnyShape(NotchPanelShape(
                    cornerRadius: UNConstants.panelCornerRadius,
                    invertedCornerRadius: UNConstants.invertedCornerRadius
                  ))
                : AnyShape(UnevenRoundedRectangle(
                    topLeadingRadius:     collapsedHeight / 2,
                    bottomLeadingRadius:  collapsedHeight / 2,
                    bottomTrailingRadius: collapsedHeight / 2,
                    topTrailingRadius:    collapsedHeight / 2,
                    style: .continuous
                  ))
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

// MARK: - DI panel shapes

/// Closed panel shape with concave (inverted) top corners and convex bottom corners.
/// Used as the clip shape when the DI panel is expanded, so the scooped top corners
/// reveal the desktop/wallpaper — creating the illusion the panel grows from the notch.
private struct NotchPanelShape: Shape {
    let cornerRadius: CGFloat
    let invertedCornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r  = cornerRadius
        let ir = invertedCornerRadius

        // Start on the top edge, past the left inverted corner scoop
        path.move(to: CGPoint(x: ir, y: 0))

        // Top-left inverted (concave) corner.
        // Arc centered at (0, 0) — the rect's physical corner, outside the filled area.
        // clockwise: true traces the short arc through (0.707·ir, 0.707·ir),
        // bowing into the rect interior so the top-left region is transparent.
        path.addArc(
            center: .zero,
            radius: ir,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: true
        )

        // Left edge down to bottom-left corner tangent
        path.addLine(to: CGPoint(x: 0, y: rect.maxY - r))

        // Bottom-left convex corner
        path.addArc(
            tangent1End: CGPoint(x: 0,         y: rect.maxY),
            tangent2End: CGPoint(x: r,         y: rect.maxY),
            radius: r
        )

        // Bottom edge
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.maxY))

        // Bottom-right convex corner
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.maxX, y: rect.maxY - r),
            radius: r
        )

        // Right edge up to top-right corner scoop
        path.addLine(to: CGPoint(x: rect.maxX, y: ir))

        // Top-right inverted (concave) corner.
        // Arc centered at (rect.maxX, 0) — the rect's top-right physical corner.
        path.addArc(
            center: CGPoint(x: rect.maxX, y: 0),
            radius: ir,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: true
        )

        // Top edge back to start, then close
        path.addLine(to: CGPoint(x: ir, y: 0))
        path.closeSubpath()
        return path
    }
}

/// Open-path border shape: concave top corners + left + bottom + right edges.
/// The top edge is intentionally omitted — no horizontal stroke at y=0 against the notch.
private struct DIExpandedBorderShape: Shape {
    let cornerRadius: CGFloat
    let invertedCornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var p  = Path()
        let r  = cornerRadius
        let ir = invertedCornerRadius

        // Start at top-left, past the concave scoop
        p.move(to: CGPoint(x: ir, y: 0))

        // Top-left inverted (concave) corner
        p.addArc(
            center: .zero,
            radius: ir,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: true
        )

        // Left edge down
        p.addLine(to: CGPoint(x: 0, y: rect.maxY - r))

        // Bottom-left convex corner
        p.addArc(
            tangent1End: CGPoint(x: 0,         y: rect.maxY),
            tangent2End: CGPoint(x: r,         y: rect.maxY),
            radius: r
        )

        // Bottom edge
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.maxY))

        // Bottom-right convex corner
        p.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.maxX, y: rect.maxY - r),
            radius: r
        )

        // Right edge up to top-right corner scoop
        p.addLine(to: CGPoint(x: rect.maxX, y: ir))

        // Top-right inverted (concave) corner — path ends here, top edge absent
        p.addArc(
            center: CGPoint(x: rect.maxX, y: 0),
            radius: ir,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: true
        )

        // Intentionally NOT closed — no top-edge stroke
        return p
    }
}
