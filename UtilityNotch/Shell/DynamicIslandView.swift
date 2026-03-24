import SwiftUI

/// Dynamic Island panel style.
/// Idle: small pill at top-center. Hover/trigger: spring-expands to show active module content.
/// Uses the same ModuleRegistry + AppState as the standard Expanded Panel — no separate data layer.
struct DynamicIslandView: View {
    @Environment(AppState.self) private var appState
    @State private var isExpanded: Bool = false
    @State private var showContent: Bool = false
    @State private var isPanelDropTargeted = false

    // Collapsed pill geometry
    private let collapsedWidth:  CGFloat = 180
    private let collapsedHeight: CGFloat = 36

    // Expanded geometry — narrower than full panel, same height
    private let expandedWidth:   CGFloat = UNConstants.panelWidth
    private let expandedHeight:  CGFloat = UNConstants.panelHeight

    var body: some View {
        ZStack(alignment: .top) {
            // ── Morphing capsule background ─────────────────────────
            RoundedRectangle(cornerRadius: isExpanded ? UNConstants.panelCornerRadius : collapsedHeight / 2,
                             style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: isExpanded ? UNConstants.panelCornerRadius : collapsedHeight / 2,
                                     style: .continuous)
                        .fill(UNConstants.panelBackground.opacity(isExpanded ? 0.85 : 0.92))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: isExpanded ? UNConstants.panelCornerRadius : collapsedHeight / 2,
                                     style: .continuous)
                        .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5)
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
            RoundedRectangle(
                cornerRadius: isExpanded ? UNConstants.panelCornerRadius : collapsedHeight / 2,
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
                // Delay content fade-in until shape is ~80% through its morph
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    showContent = true
                }
            } else {
                showContent = false
            }
        }
        .onChange(of: appState.isPanelVisible) { _, visible in
            if visible {
                isExpanded = false
                showContent = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                        isExpanded = true
                    }
                }
            } else {
                isExpanded = false
                showContent = false
            }
        }
        .environment(\.colorScheme, .dark)
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

    // MARK: - Expanded Content (same module views as Expanded Panel)

    @ViewBuilder
    private var expandedContent: some View {
        VStack(spacing: 0) {
            // Notch pill at top (same as NotchPanelView)
            Capsule()
                .fill(Color.white.opacity(0.1))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 4)

            HStack(spacing: 0) {
                // Active module — reuses the same container
                ActiveModuleContainerView()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                Rectangle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 0.5)
                    .padding(.vertical, 14)

                // Utility rail — horizontal icon row at right edge
                UtilityRailView()
                    .frame(width: UNConstants.railWidth)
                    .padding(.vertical, 8)
            }
        }
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
