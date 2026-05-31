import SwiftUI

/// Dynamic Island panel style.
/// Idle: small pill at top-center. Hover/trigger: spring-expands to show active module content.
/// Uses the same ModuleRegistry + AppState as the standard Expanded Panel — no separate data layer.
struct DynamicIslandView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded: Bool = false
    @State private var showContent: Bool = false
    @State private var isPanelDropTargeted = false
    @State private var pillGlowing: Bool = false
    /// Invalidates delayed animation callbacks when show/hide changes rapidly.
    @State private var animationGeneration: Int = 0

    // Collapsed pill geometry
    private let collapsedWidth: CGFloat = 220
    private let collapsedHeight: CGFloat = 38
    private let collapsedCornerRadius: CGFloat = 12

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
                topLeadingRadius:     isExpanded ? 0 : collapsedCornerRadius,
                bottomLeadingRadius:  isExpanded ? UNConstants.panelCornerRadius : collapsedCornerRadius,
                bottomTrailingRadius: isExpanded ? UNConstants.panelCornerRadius : collapsedCornerRadius,
                topTrailingRadius:    isExpanded ? 0 : collapsedCornerRadius,
                style: .continuous
            )
            .fill(.ultraThinMaterial)
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius:     isExpanded ? 0 : collapsedCornerRadius,
                    bottomLeadingRadius:  isExpanded ? UNConstants.panelCornerRadius : collapsedCornerRadius,
                    bottomTrailingRadius: isExpanded ? UNConstants.panelCornerRadius : collapsedCornerRadius,
                    topTrailingRadius:    isExpanded ? 0 : collapsedCornerRadius,
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
                        .stroke(UNConstants.panelGhostBorder, lineWidth: 1)
                    } else {
                        // Floating pill: all four edges need the specular highlight
                        UnevenRoundedRectangle(
                            topLeadingRadius:     collapsedCornerRadius,
                            bottomLeadingRadius:  collapsedCornerRadius,
                            bottomTrailingRadius: collapsedCornerRadius,
                            topTrailingRadius:    collapsedCornerRadius,
                            style: .continuous
                        )
                        .strokeBorder(pillGlowing ? Color.white.opacity(0.28) : UNConstants.panelGhostBorder, lineWidth: 1)
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
                                    UNConstants.accentBlue.opacity(UNConstants.panelGlowOpacity),
                                    Color.clear
                                ]),
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: UNConstants.panelGlowRadius
                            )
                        )
                    }
                }
            )
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
                    .animation(reduceMotion ? UNMotion.reduced : UNMotion.crossFade, value: showContent)
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
                    topLeadingRadius:     collapsedCornerRadius,
                    bottomLeadingRadius:  collapsedCornerRadius,
                    bottomTrailingRadius: collapsedCornerRadius,
                    topTrailingRadius:    collapsedCornerRadius,
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
            if hovering {
                expandFromNotch()
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isPanelDropTargeted) { providers in
            handlePanelDrop(providers)
        }
        .onChange(of: isPanelDropTargeted) { _, targeted in
            if targeted { appState.dismissalLocks.insert(.dragDrop) }
            else { appState.dismissalLocks.remove(.dragDrop) }
            if targeted, !isExpanded {
                expandFromNotch()
            }
        }
        .onAppear {
            animationGeneration &+= 1
            isExpanded = false
            showContent = false
            if appState.isPanelVisible {
                expandFromNotch(after: 0.05)
            }
        }
        .onChange(of: appState.isPanelVisible) { _, visible in
            if visible {
                expandFromNotch(after: 0.05)
            } else {
                collapseIntoNotch()
            }
        }
        .onChange(of: appState.panelPresentationRevision) { _, _ in
            guard appState.isPanelVisible else { return }
            expandFromNotch(after: 0.05)
        }
        .onDisappear {
            animationGeneration &+= 1
        }
        .environment(\.colorScheme, .dark)

        Spacer(minLength: 0)
        } // VStack
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Collapsed Pill

    @ViewBuilder
    private var collapsedContent: some View {
        defaultPillContent
            .transition(.opacity.animation(reduceMotion ? UNMotion.reduced : UNMotion.crossFade))
    }

    /// Compact ambient status: one useful thing, kept quiet until the panel opens.
    @ViewBuilder
    private var defaultPillContent: some View {
        HStack(spacing: 8) {
            Image(systemName: appState.ambientPillIcon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(UNConstants.textSecondary)

            Text(appState.ambientPillText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)

            Image(systemName: appState.highestPriorityLiveActivity == nil ? "lock" : "waveform.path.ecg")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(UNConstants.textTertiary)
        }
        .padding(.horizontal, 14)
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

    // MARK: - Motion

    private func expandFromNotch(after delay: Double = 0) {
        animationGeneration &+= 1
        let generation = animationGeneration

        let expand = {
            guard animationGeneration == generation else { return }

            if isExpanded {
                // Re-shows can arrive while a close is still in flight (for example
                // when the cursor skims the edge of the panel). If the shell is
                // already open, keep the module content alive instead of blanking
                // the whole panel while waiting on an expansion that is not needed.
                withAnimation(reduceMotion ? UNMotion.reduced : UNMotion.crossFade) {
                    showContent = true
                }
                return
            }

            showContent = false

            withAnimation(reduceMotion ? UNMotion.reduced : UNMotion.panelOpen) {
                isExpanded = true
            }

            // Rule 11: frame expands first, then content fades in after it settles.
            let contentDelay = reduceMotion ? 0.02 : 0.30 + UNConstants.contentFadeDelay
            DispatchQueue.main.asyncAfter(deadline: .now() + contentDelay) {
                guard animationGeneration == generation, isExpanded else { return }
                withAnimation(reduceMotion ? UNMotion.reduced : UNMotion.crossFade) {
                    showContent = true
                }
            }
        }

        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: expand)
        } else {
            expand()
        }
    }

    private func collapseIntoNotch() {
        animationGeneration &+= 1
        let generation = animationGeneration

        withAnimation(reduceMotion ? UNMotion.reduced : UNMotion.press) {
            showContent = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.02 : 0.12)) {
            guard animationGeneration == generation else { return }
            withAnimation(reduceMotion ? UNMotion.reduced : UNMotion.panelClose) {
                isExpanded = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.10 : 0.34)) {
                guard animationGeneration == generation, !isExpanded else { return }
                withAnimation(reduceMotion ? UNMotion.reduced : UNMotion.crossFade) { pillGlowing = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    withAnimation(reduceMotion ? UNMotion.reduced : UNMotion.crossFade) { pillGlowing = false }
                }
            }
        }
    }

    // MARK: - Drop Handling

    private func handlePanelDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                DispatchQueue.main.async {
                    appState.pendingTrayURLs.append(url)
                    appState.selectModule("filesTray")
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
