import SwiftUI

/// Dynamic Island panel style.
/// Idle: small pill at top-center. Hover/trigger: spring-expands to show active module content.
/// Uses the same ModuleRegistry + AppState as the standard Expanded Panel — no separate data layer.
///
/// Animation design:
/// - Shape morphs via spring (pill → panel).
/// - expandedContent is ALWAYS mounted so layout is pre-computed before the shape expands.
/// - clipShape acts as the content-reveal mask: content is fully opaque from the first frame of
///   expansion, so the growing clip reveals it — no ghost-border window.
/// - Closing: quick easeIn collapse synced with window alpha fade.
struct DynamicIslandView: View {
    @Environment(AppState.self) private var appState

    /// Single state variable drives both the shape morph and content visibility.
    /// No secondary `showContent` flag — eliminates the 0-opacity-content / ghost-border window.
    @State private var isExpanded: Bool = false
    @State private var isPanelDropTargeted = false

    // Collapsed pill geometry
    private let collapsedWidth:  CGFloat = 180
    private let collapsedHeight: CGFloat = 36

    // Expanded geometry — matches full panel
    private let expandedWidth:   CGFloat = UNConstants.panelWidth
    private let expandedHeight:  CGFloat = UNConstants.panelHeight

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // ── Morphing capsule background ─────────────────────────
                morphingBackground

                // ── Collapsed pill content ──────────────────────────────
                if !isExpanded {
                    collapsedContent
                        .frame(width: collapsedWidth, height: collapsedHeight)
                        .transition(.opacity)
                }

                // ── Expanded content — always mounted ───────────────────
                // Pre-mounted so layout is ready before the shape expands.
                // clipShape is the reveal mechanism: content is opaque the moment isExpanded
                // flips, so the expanding clip unmasks it — no empty-background ghost state.
                expandedContent
                    .frame(width: expandedWidth, height: expandedHeight)
                    .opacity(isExpanded ? 1 : 0)
                    .animation(.easeIn(duration: 0.1), value: isExpanded)
                    .allowsHitTesting(isExpanded)
            }
            // Clip to the current pill/panel shape — this IS the reveal animation on open
            .clipShape(
                RoundedRectangle(
                    cornerRadius: isExpanded ? UNConstants.panelCornerRadius : collapsedHeight / 2,
                    style: .continuous
                )
            )
            .frame(
                width:  isExpanded ? expandedWidth  : collapsedWidth,
                height: isExpanded ? expandedHeight : collapsedHeight
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                // Always update pointer state so EventTriggerManager dismissal logic is correct.
                appState.isPointerInsidePanel = hovering
                // Guard expansion: if the panel is already being dismissed (isPanelVisible=false),
                // don't let hover re-expand the shape mid-close-animation.
                guard appState.isPanelVisible else { return }
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
            // Panel visibility → shape state sync.
            // Open: spring expansion (no pre-reset, no async delay — avoids jitter from sync snap).
            // Close: quick easeIn collapse synced with window alpha fade duration (~0.22s).
            .onChange(of: appState.isPanelVisible) { _, visible in
                if visible {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                        isExpanded = true
                    }
                } else {
                    withAnimation(.easeIn(duration: 0.15)) {
                        isExpanded = false
                    }
                }
            }
            .environment(\.colorScheme, .dark)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Morphing Background

    private var currentCornerRadius: CGFloat {
        isExpanded ? UNConstants.panelCornerRadius : collapsedHeight / 2
    }

    private var morphingBackground: some View {
        RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous)
                    .fill(UNConstants.panelBackground.opacity(isExpanded ? 0.85 : 0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5)
            )
            .shadow(
                color: .black.opacity(isExpanded ? 0.4 : 0.25),
                radius: isExpanded ? 28 : 12,
                y: isExpanded ? 8 : 4
            )
            .frame(
                width:  isExpanded ? expandedWidth  : collapsedWidth,
                height: isExpanded ? expandedHeight : collapsedHeight
            )
    }

    // MARK: - Collapsed Pill

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

            ambientIndicator
        }
        .padding(.horizontal, 14)
    }

    @ViewBuilder
    private var ambientIndicator: some View {
        if appState.activeModuleID == "musicControl" {
            Image(systemName: "music.note")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.purple.opacity(0.8))
        }
    }

    // MARK: - Expanded Content

    @ViewBuilder
    private var expandedContent: some View {
        ActiveModuleContainerView()
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
