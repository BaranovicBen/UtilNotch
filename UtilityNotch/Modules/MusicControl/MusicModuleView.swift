import SwiftUI

/// Music module — vertical-column layout.
/// Carousel (prev/current/next art) → title/artist → wave → controls → scrubber.
/// Reads from MusicOrchestrator via \.musicOrchestrator environment key.
struct MusicModuleView: View {
    @Environment(AppState.self)         private var appState
    @Environment(\.musicOrchestrator)   private var orchestrator

    // Carousel animation state
    @State private var wheelOffset: CGFloat = 0
    @State private var carouselLocked: Bool = false

    // Progress-bar drag state
    @State private var isDraggingProgress: Bool = false
    @State private var dragProgress: CGFloat = 0
    @State private var trackWidth: CGFloat = 0

    // 1-second tick for interpolated elapsed time display
    @State private var displayTime = Date()

    // Wheel carousel geometry
    private let artSize: CGFloat     = 100
    private let slotDistance: CGFloat = 92
    private let maxRotation: Double   = 35

    // Virtual carousel: [outerPrev?, prev?, current?, next?, outerNext?]
    // Indices 0/4 are the ±2 outer (off-screen) slots used only during animation.
    private var carouselCards: [TrackCard?] {
        let s = orchestrator.nowPlaying
        return [nil, s?.previous, s?.current, s?.next, s?.upNext.first]
    }
    // Center index is always 2 (current track)
    private let carouselCenter = 2

    var body: some View {
        let np = orchestrator.nowPlaying
        ModuleShellView(
            moduleTitle: "Music",
            moduleIcon: "music.note",
            modules: shellNavItems(appState: appState),
            activeModuleID: appState.activeModuleID,
            onModuleSelect: { id in
                withAnimation(.spring(duration: 0.28, bounce: 0.16)) {
                    appState.selectModule(id)
                }
            },
            statusDotColor: np != nil
                ? UNConstants.musicPlayingTint
                : Color.white.opacity(0.2),
            statusLeft: np?.current != nil ? "NOW PLAYING" : "NO SOURCE",
            statusRight: np?.playbackSourceLabel ?? "—",
            actionButton: nil
        ) {
            if np != nil {
                musicContent
            } else {
                emptyStateView
            }
        }
        .onAppear { appState.setModuleActionButton(nil) }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { t in
            displayTime = t
        }
    }

    // MARK: - Empty state

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 32))
                .foregroundStyle(Color.white.opacity(0.18))

            VStack(spacing: 6) {
                Text("No music playing")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.7))
                Text("Play any music and it will appear here automatically.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await orchestrator.connectProvider(.appleMusic) }
            } label: {
                Label("Allow Media Control", systemImage: "play.circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
    }

    // MARK: - Full content column

    private var musicContent: some View {
        VStack(spacing: 0) {
            carouselView
            Spacer().frame(height: 4)
            trackInfoView
            Spacer().frame(height: 4)
            waveView
            Spacer().frame(height: 4)
            controlsView
            Spacer().frame(height: 4)
            progressView
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 3D Wheel Carousel

    private var carouselView: some View {
        ZStack(alignment: .center) {
            wheelSlot(at: carouselCenter - 2, base: -slotDistance * 2, zIdx: 1, isOuter: true)
            wheelSlot(at: carouselCenter + 2, base:  slotDistance * 2, zIdx: 1, isOuter: true)
            wheelSlot(at: carouselCenter - 1, base: -slotDistance,     zIdx: 2)
            wheelSlot(at: carouselCenter + 1, base:  slotDistance,     zIdx: 2)
            wheelSlot(at: carouselCenter,     base:  0,                zIdx: 3)
        }
        .frame(width: slotDistance * 2 + artSize)
        .frame(height: 110)
        .clipped()
    }

    @ViewBuilder
    private func wheelSlot(at index: Int, base: CGFloat, zIdx: Double, isOuter: Bool = false) -> some View {
        let pos    = base + wheelOffset
        let norm   = max(-2.0, min(2.0, Double(pos) / Double(slotDistance)))
        let sideT  = min(1.0, abs(norm))
        let outerFade: Double = isOuter ? max(0.0, 2.0 - abs(norm)) : 1.0

        artTile(at: index)
            .frame(width: artSize, height: artSize)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.35 * sideT))
            )
            .scaleEffect(1.0 - 0.28 * sideT)
            .opacity((1.0 - 0.55 * sideT) * outerFade)
            .rotation3DEffect(
                .degrees(norm * maxRotation),
                axis: (x: 0, y: 1, z: 0),
                anchor: .center,
                anchorZ: 0,
                perspective: 0.35
            )
            .shadow(
                color: Color.black.opacity(0.55 * (1.0 - sideT) * outerFade),
                radius: 18.0 * (1.0 - sideT),
                y:      5.0  * (1.0 - sideT)
            )
            .offset(x: pos)
            .zIndex(zIdx)
    }

    /// Album art tile. Prefers raw artworkData, then artworkURL, then a deterministic gradient.
    @ViewBuilder
    private func artTile(at index: Int) -> some View {
        let card = carouselCards.indices.contains(index) ? carouselCards[index] : nil
        if let data = card?.artworkData, let nsImg = NSImage(data: data) {
            Image(nsImage: nsImg)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: artSize, height: artSize)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else if let url = card?.artworkURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: artSize, height: artSize)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                default:
                    artPlaceholder(for: card)
                }
            }
        } else {
            artPlaceholder(for: card)
        }
    }

    private func artPlaceholder(for card: TrackCard?) -> some View {
        let palette = UNConstants.musicArtPalette
        let idx = abs(card?.id.hashValue ?? 0) % palette.count
        return RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(LinearGradient(
                colors: palette[idx],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.white.opacity(0.25))
            )
    }

    // MARK: - Track info

    private var trackInfoView: some View {
        let np = orchestrator.nowPlaying
        return VStack(spacing: 4) {
            Text(np?.current?.title ?? "—")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .contentTransition(.numericText())

            Text(np?.current?.artist ?? "")
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.55))
                .lineLimit(1)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .animation(.easeInOut(duration: 0.25), value: orchestrator.nowPlaying?.current?.id)
    }

    // MARK: - Sound wave

    private var waveView: some View {
        MusicWaveView(isPlaying: orchestrator.nowPlaying?.isPlaying ?? false)
            .frame(maxWidth: .infinity)
            .frame(height: 24)
    }

    // MARK: - Playback controls

    private var controlsView: some View {
        let caps = orchestrator.capabilities
        return HStack(spacing: 16) {
            controlButton(icon: "backward.fill", size: 13, diameter: 30,
                          disabled: !caps.canSkipPrevious) {
                triggerCarousel(forward: false)
            }

            controlButton(
                icon: orchestrator.nowPlaying?.isPlaying == true ? "pause.fill" : "play.fill",
                size: 16, diameter: 34, fillOpacity: 0.22,
                disabled: !caps.canPlayPause
            ) {
                Task { await orchestrator.playPause() }
            }

            controlButton(icon: "forward.fill", size: 13, diameter: 30,
                          disabled: !caps.canSkipNext) {
                triggerCarousel(forward: true)
            }
        }
    }

    @ViewBuilder
    private func controlButton(
        icon: String,
        size: CGFloat,
        diameter: CGFloat,
        fillOpacity: Double = 0.15,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(fillOpacity))
                    .frame(width: diameter, height: diameter)
                Image(systemName: icon)
                    .font(.system(size: size, weight: .medium))
                    .foregroundStyle(Color.white.opacity(disabled ? 0.3 : 1.0))
            }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    // MARK: - Progress bar + timestamps

    private var progressView: some View {
        let np = orchestrator.nowPlaying
        let duration = np?.durationSeconds ?? 1
        let elapsed  = isDraggingProgress
            ? dragProgress * duration
            : (np?.currentElapsedTime(at: displayTime) ?? 0)
        let progress = max(0, min(1, elapsed / max(duration, 1)))

        return VStack(spacing: 3) {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 3)
                Capsule()
                    .fill(LinearGradient(
                        colors: [UNConstants.musicProgressStart, UNConstants.musicProgressEnd],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: max(0, trackWidth * progress), height: 3)
                    .animation(isDraggingProgress ? nil : .spring(response: 0.4, dampingFraction: 0.9),
                               value: progress)
            }
            .frame(height: 12)
            .contentShape(Rectangle())
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { trackWidth = $0 }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDraggingProgress = true
                        dragProgress = trackWidth > 0
                            ? max(0, min(1, value.location.x / trackWidth)) : 0
                    }
                    .onEnded { value in
                        let normalized = trackWidth > 0
                            ? max(0, min(1, value.location.x / trackWidth)) : 0
                        let time = normalized * (np?.durationSeconds ?? 0)
                        Task { await orchestrator.seek(to: time) }
                        isDraggingProgress = false
                    }
            )

            HStack {
                Text(formatTime(
                    isDraggingProgress
                        ? dragProgress * (np?.durationSeconds ?? 0)
                        : (np?.currentElapsedTime(at: displayTime) ?? 0)
                ))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.35))

                Spacer()

                Text(formatTime(np?.durationSeconds ?? 0))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.35))
            }
        }
    }

    // MARK: - Wheel animation

    private func triggerCarousel(forward: Bool) {
        guard !carouselLocked else { return }
        carouselLocked = true
        let target = forward ? -slotDistance : slotDistance

        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            wheelOffset = target
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.38))
            if forward { await orchestrator.next() }
            else       { await orchestrator.previous() }
            wheelOffset = 0
            carouselLocked = false
        }
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Double) -> String {
        let s = max(0, Int(seconds))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Sound Wave (30 animated bars)

private struct MusicWaveView: View {
    let isPlaying: Bool

    @State private var barHeights: [CGFloat] = Array(repeating: 3, count: 30)
    @State private var waveTimer: Timer?

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<30, id: \.self) { i in
                Capsule()
                    .fill(Color.white.opacity(0.30))
                    .frame(width: 3, height: barHeights[i])
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 24)
        .clipped()
        .onAppear   { if isPlaying { startAnimating() } }
        .onDisappear { stopAnimating() }
        .onChange(of: isPlaying) { _, playing in
            playing ? startAnimating() : stopAnimating()
        }
    }

    private func startAnimating() {
        stopAnimating()
        let t = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { _ in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.12)) {
                    barHeights = (0..<30).map { _ in CGFloat.random(in: 3...24) }
                }
            }
        }
        waveTimer = t
    }

    private func stopAnimating() {
        waveTimer?.invalidate()
        waveTimer = nil
        withAnimation(.easeInOut(duration: 0.25)) {
            barHeights = Array(repeating: 3, count: 30)
        }
    }
}
