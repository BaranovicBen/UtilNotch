import SwiftUI

/// Music module — vertical-column layout.
/// Carousel (prev/current/next art) → title/artist → wave → controls → scrubber.
/// Depends only on MusicProvider; injected via \.musicProvider environment key.
struct MusicModuleView: View {
    @Environment(AppState.self)      private var appState
    @Environment(\.musicProvider)    private var provider

    // Carousel animation state
    @State private var slideOffset: CGFloat = 0
    @State private var carouselLocked: Bool = false

    // Progress-bar drag state
    @State private var isDraggingProgress: Bool = false
    @State private var dragProgress: CGFloat = 0

    // Carousel geometry constants
    private let artFull: CGFloat = 88
    private let artSmall: CGFloat = 66
    private let carouselSpacing: CGFloat = 14
    // Distance between the center of the current art and a side art:
    // half of full + gap + half of small = 44 + 14 + 33 = 91
    private var slotOffset: CGFloat { artFull / 2 + carouselSpacing + artSmall / 2 }

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
            Spacer().frame(height: 10)
            trackInfoView
            Spacer().frame(height: 10)
            waveView
            Spacer().frame(height: 10)
            controlsView
            Spacer().frame(height: 10)
            progressView
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Carousel

    private var carouselView: some View {
        ZStack(alignment: .center) {
            // prevprev — rendered so the forward slide looks seamless
            artTile(at: provider.currentIndex - 2)
                .frame(width: artSmall, height: artSmall)
                .opacity(0.4)
                .offset(x: -slotOffset * 2 + slideOffset)

            // prev
            artTile(at: provider.currentIndex - 1)
                .frame(width: artSmall, height: artSmall)
                .opacity(0.4)
                .offset(x: -slotOffset + slideOffset)

            // current
            artTile(at: provider.currentIndex)
                .frame(width: artFull, height: artFull)
                .offset(x: slideOffset)

            // next
            artTile(at: provider.currentIndex + 1)
                .frame(width: artSmall, height: artSmall)
                .opacity(0.4)
                .offset(x: slotOffset + slideOffset)

            // nextnext — rendered so the forward slide looks seamless
            artTile(at: provider.currentIndex + 2)
                .frame(width: artSmall, height: artSmall)
                .opacity(0.4)
                .offset(x: slotOffset * 2 + slideOffset)
        }
        .frame(maxWidth: .infinity)
        .frame(height: artFull)
        // Gradient mask creates the soft-edge "peek" effect without a hard clip.
        .mask(
            HStack(spacing: 0) {
                LinearGradient(
                    colors: [.clear, .black],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(width: 52)
                Color.black
                LinearGradient(
                    colors: [.black, .clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(width: 52)
            }
        )
    }

    /// Album-art placeholder tile for the track at a wrapped index offset from the queue.
    @ViewBuilder
    private func artTile(at rawIndex: Int) -> some View {
        let tracks = provider.tracks
        if tracks.isEmpty {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.05))
        } else {
            let idx = ((rawIndex % tracks.count) + tracks.count) % tracks.count
            let track = tracks[idx]
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: track.albumColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.white.opacity(0.25))
                )
                .shadow(
                    color: (track.albumColors.first ?? .clear).opacity(0.4),
                    radius: 8, y: 3
                )
        }
    }

    // MARK: - Track info

    private var trackInfoView: some View {
        VStack(spacing: 4) {
            Text(provider.currentTrack?.title ?? "—")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .contentTransition(.numericText())

            Text(provider.currentTrack?.artist ?? "")
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.50))
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
        VStack(spacing: 5) {
            GeometryReader { geo in
                let duration   = provider.currentTrack?.duration ?? 1
                let elapsed    = isDraggingProgress ? dragProgress * duration : provider.currentTime
                let progress   = max(0, min(1, elapsed / duration))

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
                        .frame(width: max(0, geo.size.width * progress), height: 3)
                        .animation(
                            isDraggingProgress ? nil : .linear(duration: 0.5),
                            value: provider.currentTime
                        )
                }
                // Enlarged hit area for the scrubber
                .frame(height: 18)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDraggingProgress = true
                            dragProgress = max(0, min(1, value.location.x / geo.size.width))
                        }
                        .onEnded { value in
                            let normalized = max(0, min(1, value.location.x / geo.size.width))
                            let time = normalized * (provider.currentTrack?.duration ?? 0)
                            Task { await provider.seek(to: time) }
                            isDraggingProgress = false
                        }
                )
            }
            .frame(height: 18)

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

    // MARK: - Carousel animation

    /// Animate the carousel in the given direction, then advance the provider index.
    private func triggerCarousel(forward: Bool) {
        guard !carouselLocked else { return }
        carouselLocked = true

        let targetOffset = forward ? -slotOffset : slotOffset

        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            slideOffset = targetOffset
        }

        // After the spring mostly settles, swap the index and snap offset back.
        // Because the new item arrangement exactly matches the animated end-state,
        // the snap is visually seamless.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
            Task { @MainActor in
                if forward { await provider.next()     }
                else       { await provider.previous() }
                // Instant reset — no animation so it doesn't fight the spring.
                slideOffset = 0
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

    @State private var barHeights: [CGFloat] = Array(repeating: 4, count: 30)
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
        .frame(height: 32)
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
                    barHeights = (0..<30).map { _ in CGFloat.random(in: 4...32) }
                }
            }
        }
        waveTimer = t
    }

    private func stopAnimating() {
        waveTimer?.invalidate()
        waveTimer = nil
        withAnimation(.easeInOut(duration: 0.25)) {
            barHeights = Array(repeating: 6, count: 30)
        }
    }
}
