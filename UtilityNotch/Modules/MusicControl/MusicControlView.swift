import SwiftUI

/// Music Control — Dynamic Island-inspired compact player.
/// Single horizontal row: [art] [title/artist] [waveform?] [controls]
/// Full-width thin progress bar pinned to bottom.
/// No volume slider (removed by design decision).
struct MusicControlView: View {
    @Environment(AppState.self) private var appState
    @State private var isPlaying: Bool = true
    @State private var currentTrack: MockTrack = .sampleTracks[0]
    @State private var trackIndex: Int = 0
    @State private var progress: Double = 0.35
    @State private var simulatedPlayTimer: Timer?

    // Fixed gradient colors — consistent across all tracks
    private let progressGradient = LinearGradient(
        colors: [
            Color(red: 0.55, green: 0.35, blue: 0.95),
            Color(red: 0.35, green: 0.55, blue: 1.0)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        VStack(spacing: 0) {
            // ── Main player row ────────────────────────────────────
            HStack(spacing: 12) {
                // Album art — compact 52×52
                albumArt
                    .frame(width: 52, height: 52)

                // Track info
                VStack(alignment: .leading, spacing: 3) {
                    Text(currentTrack.title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(currentTrack.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Sound wave — shown between info and controls
                if appState.showMusicWaveform {
                    SoundWaveView(isPlaying: isPlaying, colors: currentTrack.gradientColors)
                        .frame(width: 26, height: 32)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.7).combined(with: .opacity),
                            removal: .opacity
                        ))
                }

                // Playback controls — circular buttons right-aligned
                HStack(spacing: 8) {
                    CircularControlButton(icon: "backward.fill", iconSize: 14) { previousTrack() }
                    CircularControlButton(
                        icon: isPlaying ? "pause.fill" : "play.fill",
                        iconSize: 16,
                        diameter: 36
                    ) { togglePlayPause() }
                    CircularControlButton(icon: "forward.fill", iconSize: 14) { nextTrack() }
                }
            }
            .padding(.bottom, 12)

            // ── Progress bar — full width, no Spacer above ─────────
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 2.5)
                        Capsule()
                            .fill(progressGradient)
                            .frame(width: max(0, geo.size.width * progress), height: 2.5)
                            .animation(.linear(duration: 0.5), value: progress)
                    }
                }
                .frame(height: 2.5)

                HStack {
                    Text(formatTime(progress * currentTrack.duration))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                    Spacer()
                    Text(formatTime(currentTrack.duration))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { startProgressSimulation() }
        .onDisappear { simulatedPlayTimer?.invalidate() }
    }

    // MARK: - Album Art

    @ViewBuilder
    private var albumArt: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(
                LinearGradient(
                    colors: currentTrack.gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.4))
            )
            .shadow(
                color: (currentTrack.gradientColors.first ?? .clear).opacity(0.45),
                radius: 10,
                y: 3
            )
    }

    // MARK: - Actions

    private func togglePlayPause() {
        withAnimation(.easeInOut(duration: 0.15)) { isPlaying.toggle() }
    }

    private func nextTrack() {
        withAnimation(.easeInOut(duration: 0.2)) {
            trackIndex = (trackIndex + 1) % MockTrack.sampleTracks.count
            currentTrack = MockTrack.sampleTracks[trackIndex]
            progress = 0
        }
    }

    private func previousTrack() {
        withAnimation(.easeInOut(duration: 0.2)) {
            trackIndex = (trackIndex - 1 + MockTrack.sampleTracks.count) % MockTrack.sampleTracks.count
            currentTrack = MockTrack.sampleTracks[trackIndex]
            progress = 0
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // Simulates playback progress so the bar animates in demo
    private func startProgressSimulation() {
        simulatedPlayTimer?.invalidate()
        simulatedPlayTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                guard isPlaying else { return }
                let step = 1.0 / currentTrack.duration
                progress = min(1.0, progress + step)
                if progress >= 1.0 { nextTrack() }
            }
        }
    }
}

// MARK: - Circular Control Button

private struct CircularControlButton: View {
    let icon: String
    var iconSize: CGFloat = 14
    var diameter: CGFloat = 32
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(isHovering ? 0.14 : 0.08))
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundStyle(.white.opacity(isHovering ? 1.0 : 0.85))
            }
            .frame(width: diameter, height: diameter)
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { isHovering = h } }
    }
}

// MARK: - Sound Wave Visualization

/// Compact animated bars reacting to playback state.
struct SoundWaveView: View {
    var isPlaying: Bool
    var colors: [Color]

    private let barCount = 4
    @State private var heights: [CGFloat] = [0.35, 0.65, 0.45, 0.7]
    @State private var animationTimer: Timer?

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<barCount, id: \.self) { i in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                (colors.first ?? .white).opacity(0.6),
                                (colors.last ?? .white).opacity(0.9)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 2.5, height: isPlaying ? max(4, heights[i] * 28) : 4)
                    .animation(
                        isPlaying
                            ? .easeInOut(duration: Double.random(in: 0.25...0.5))
                                .repeatForever(autoreverses: true)
                            : .easeOut(duration: 0.25),
                        value: heights[i]
                    )
            }
        }
        .frame(maxHeight: .infinity)
        .onAppear { startAnimating() }
        .onDisappear { stopAnimating() }
        .onChange(of: isPlaying) { _, playing in
            playing ? startAnimating() : stopAnimating()
        }
    }

    private func startAnimating() {
        guard isPlaying else { return }
        animationTimer?.invalidate()
        withAnimation { heights = randomHeights() }
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.28, repeats: true) { _ in
            Task { @MainActor in
                withAnimation { heights = randomHeights() }
            }
        }
    }

    private func stopAnimating() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func randomHeights() -> [CGFloat] {
        (0..<barCount).map { _ in CGFloat.random(in: 0.2...1.0) }
    }
}

// MARK: - Mock Track Model

private struct MockTrack {
    let title: String
    let artist: String
    let album: String
    let duration: Double
    let gradientColors: [Color]

    static let sampleTracks: [MockTrack] = [
        MockTrack(title: "Midnight City",    artist: "M83",        album: "Hurry Up…",     duration: 243, gradientColors: [.indigo, .purple]),
        MockTrack(title: "Blinding Lights",  artist: "The Weeknd", album: "After Hours",   duration: 200, gradientColors: [.red, .orange]),
        MockTrack(title: "Starboy",          artist: "The Weeknd", album: "Starboy",       duration: 230, gradientColors: [.blue, .cyan]),
        MockTrack(title: "Bohemian Rhapsody",artist: "Queen",      album: "A Night at…",  duration: 354, gradientColors: [.yellow, .orange]),
    ]
}
