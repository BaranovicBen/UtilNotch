import SwiftUI

/// Music module — vertical-column layout.
/// Carousel (prev/current/next art) → title/artist → wave → controls → scrubber.
/// Depends only on MusicProvider; injected via \.musicProvider environment key.
struct MusicModuleView: View {
    @Environment(AppState.self)      private var appState
    @Environment(\.musicProvider)    private var provider

    // Carousel animation state
    @State private var wheelOffset: CGFloat = 0
    @State private var carouselLocked: Bool = false

    // Progress-bar drag state
    @State private var isDraggingProgress: Bool = false
    @State private var dragProgress: CGFloat = 0
    @State private var trackWidth: CGFloat = 0

    // Wheel carousel geometry
    private let artSize: CGFloat    = 100   // layout size for all album tiles
    private let slotDistance: CGFloat = 92  // center-to-side-center distance
    private let maxRotation: Double  = 35   // Y-rotation degrees at the side positions

    var body: some View {
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
            statusDotColor: Color.white.opacity(0.2),
            statusLeft: provider.currentTrack != nil ? "NOW PLAYING" : "CONNECT A PLAYER",
            statusRight: "DEMO",
            actionButton: nil
        ) {
            musicContent
        }
    }

    // MARK: - Full content column

    private var musicContent: some View {
        VStack(spacing: 0) {
            carouselView
            Spacer().frame(height: 8)
            trackInfoView
            Spacer().frame(height: 8)
            waveView
            Spacer().frame(height: 8)
            controlsView
            Spacer().frame(height: 8)
            progressView
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 3D Wheel Carousel

    private var carouselView: some View {
        ZStack(alignment: .center) {
            // Outer slots (±2) are declared first so they sit behind everything else.
            // They are invisible at rest (outerFade = 0) and only materialise during
            // a swipe animation as they slide into the side position — this keeps
            // the transition seamless without them ever showing at idle.
            wheelSlot(at: provider.currentIndex - 2, base: -slotDistance * 2, zIdx: 1, isOuter: true)
            wheelSlot(at: provider.currentIndex + 2, base:  slotDistance * 2, zIdx: 1, isOuter: true)
            // Visible side slots
            wheelSlot(at: provider.currentIndex - 1, base: -slotDistance,     zIdx: 2)
            wheelSlot(at: provider.currentIndex + 1, base:  slotDistance,     zIdx: 2)
            // Center — always on top
            wheelSlot(at: provider.currentIndex,     base:  0,                zIdx: 3)
        }
        // Fixed width sized to exactly fit center + two side albums (no room for ±2 slots).
        // Combined with .clipped() this is a belt-and-suspenders guarantee: even if a
        // floating pixel of an outer album escapes the opacity fade it is hard-clipped here.
        .frame(width: slotDistance * 2 + artSize)   // 92*2 + 100 = 284 pt
        .frame(height: 110)
        .clipped()
    }

    /// One album in the wheel.
    /// All 3D transforms are derived from the album's live x-position (`base + wheelOffset`),
    /// so they animate continuously and in-sync as the wheel turns.
    ///
    /// - Parameters:
    ///   - isOuter: When `true` the slot fades to **zero opacity at rest** (|norm| ≥ 2) and
    ///              only fades in as the animation brings it into the side position. This hides
    ///              the ±2 albums without removing them from the view tree (removing them would
    ///              create a visible gap on the arriving side mid-animation).
    @ViewBuilder
    private func wheelSlot(at rawIndex: Int, base: CGFloat, zIdx: Double, isOuter: Bool = false) -> some View {
        let pos    = base + wheelOffset
        let norm   = max(-2.0, min(2.0, Double(pos) / Double(slotDistance)))
        let sideT  = min(1.0, abs(norm))   // 0.0 = center, 1.0 = full side position

        // Outer fade: 0 at |norm|=2 (at rest), rises linearly to 1 at |norm|=1 (side slot).
        // Inner slots always get outerFade = 1 so they are unaffected.
        let outerFade: Double = isOuter ? max(0.0, 2.0 - abs(norm)) : 1.0

        artTile(at: rawIndex)
            .frame(width: artSize, height: artSize)
            // Dark vignette on the album surface, rotates with the tile
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
            // Shadow fades out for side albums; invisible for outer albums
            .shadow(
                color: Color.black.opacity(0.55 * (1.0 - sideT) * outerFade),
                radius: 18.0 * (1.0 - sideT),
                y:      5.0  * (1.0 - sideT)
            )
            .offset(x: pos)
            .zIndex(zIdx)
    }

    /// Base album-art tile — colored gradient square with music note icon.
    /// Shadow and side-transforms are applied by `wheelSlot`, not here.
    @ViewBuilder
    private func artTile(at rawIndex: Int) -> some View {
        let tracks = provider.tracks
        if tracks.isEmpty {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
        } else {
            let idx   = ((rawIndex % tracks.count) + tracks.count) % tracks.count
            let track = tracks[idx]
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: track.albumColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.white.opacity(0.25))
                )
        }
    }

    // MARK: - Track info

    private var trackInfoView: some View {
        VStack(spacing: 4) {
            Text(provider.currentTrack?.title ?? "—")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .contentTransition(.numericText())

            Text(provider.currentTrack?.artist ?? "")
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.55))
                .lineLimit(1)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .animation(.easeInOut(duration: 0.25), value: provider.currentIndex)
    }

    // MARK: - Sound wave

    private var waveView: some View {
        MusicWaveView(isPlaying: provider.isPlaying)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
    }

    // MARK: - Playback controls

    private var controlsView: some View {
        HStack(spacing: 24) {
            // ⏮ Backward
            controlButton(icon: "backward.fill", size: 16, diameter: 36) {
                triggerCarousel(forward: false)
            }

            // ⏯ Play / Pause
            controlButton(
                icon: provider.isPlaying ? "pause.fill" : "play.fill",
                size: 20, diameter: 40,
                fillOpacity: 0.22
            ) {
                Task {
                    if provider.isPlaying { await provider.pause() }
                    else                  { await provider.play()  }
                }
            }

            // ⏭ Forward
            controlButton(icon: "forward.fill", size: 16, diameter: 36) {
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
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(fillOpacity))
                    .frame(width: diameter, height: diameter)
                Image(systemName: icon)
                    .font(.system(size: size, weight: .medium))
                    .foregroundStyle(Color.white)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Progress bar + timestamps

    private var progressView: some View {
        let duration = provider.currentTrack?.duration ?? 1
        let elapsed  = isDraggingProgress ? dragProgress * duration : provider.currentTime
        let progress = max(0, min(1, elapsed / duration))

        return VStack(spacing: 5) {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 3)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "8B5CF6"), Color(hex: "3B82F6")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, trackWidth * progress), height: 3)
                    .animation(
                        isDraggingProgress ? nil : .linear(duration: 0.5),
                        value: provider.currentTime
                    )
            }
            // Fixed hit area — no GeometryReader, so no layout inflation
            .frame(height: 18)
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
                        let time = normalized * (provider.currentTrack?.duration ?? 0)
                        Task { await provider.seek(to: time) }
                        isDraggingProgress = false
                    }
            )

            HStack {
                Text(formatTime(
                    isDraggingProgress
                        ? dragProgress * (provider.currentTrack?.duration ?? 0)
                        : provider.currentTime
                ))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.35))
                .animation(nil, value: provider.currentTime)

                Spacer()

                Text(formatTime(provider.currentTrack?.duration ?? 0))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.35))
            }
        }
    }

    // MARK: - Wheel animation

    /// Spin the wheel in the given direction, then commit the index change.
    /// The snap-back is seamless: the new album arrangement at wheelOffset=0
    /// exactly matches the visuals at the animated end-state.
    private func triggerCarousel(forward: Bool) {
        guard !carouselLocked else { return }
        carouselLocked = true

        let target = forward ? -slotDistance : slotDistance

        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            wheelOffset = target
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            Task { @MainActor in
                if forward { await provider.next()     }
                else       { await provider.previous() }
                wheelOffset = 0   // instant — no animation, visually seamless
                carouselLocked = false
            }
        }
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: TimeInterval) -> String {
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
            DispatchQueue.main.async {
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
