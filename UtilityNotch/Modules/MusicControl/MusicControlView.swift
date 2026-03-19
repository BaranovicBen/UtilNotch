import SwiftUI

/// Music Control — compact layout with smaller album art, tighter controls, optional sound wave.
struct MusicControlView: View {
    @Environment(AppState.self) private var appState
    @State private var isPlaying: Bool = true
    @State private var currentTrack: MockTrack = .sampleTracks[0]
    @State private var trackIndex: Int = 0
    @State private var progress: Double = 0.35
    @State private var volume: Double = 0.7

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack {
                Label("Music", systemImage: "music.note")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Toggle(isOn: Binding(
                    get: { appState.showMusicWaveform },
                    set: { appState.showMusicWaveform = $0 }
                )) {
                    Image(systemName: "waveform")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .toggleStyle(.button)
                .buttonStyle(.plain)
                .help("Show waveform")
            }
            .padding(.bottom, 14)

            // Album art + track info + waveform row
            HStack(alignment: .center, spacing: 12) {
                // Album art — compact
                albumArt
                    .frame(width: 56, height: 56)

                // Track info
                VStack(alignment: .leading, spacing: 2) {
                    Text(currentTrack.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                        .foregroundStyle(.white)

                    Text(currentTrack.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(currentTrack.album)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                // Sound wave (optional) — uses the right side negative space
                if appState.showMusicWaveform {
                    SoundWaveView(isPlaying: isPlaying, colors: currentTrack.gradientColors)
                        .frame(width: 32, height: 36)
                        .transition(.opacity)
                }
            }
            .padding(.bottom, 14)

            // Progress bar
            progressBar
                .padding(.bottom, 10)

            // Playback controls — compact
            HStack(spacing: 28) {
                Button(action: previousTrack) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .buttonStyle(.plain)

                Button(action: togglePlayPause) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button(action: nextTrack) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 12)

            // Volume
            HStack(spacing: 7) {
                Image(systemName: "speaker.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Slider(value: $volume, in: 0...1)
                    .tint(.white.opacity(0.35))
                Image(systemName: "speaker.wave.3.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var albumArt: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(
                LinearGradient(
                    colors: currentTrack.gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.45))
            )
            .shadow(color: currentTrack.gradientColors.first?.opacity(0.4) ?? .clear, radius: 8, y: 2)
    }

    @ViewBuilder
    private var progressBar: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 3)
                    Capsule()
                        .fill(Color.white.opacity(0.55))
                        .frame(width: geo.size.width * progress, height: 3)
                }
            }
            .frame(height: 3)

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

    // MARK: - Actions (mock)

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
}

// MARK: - Sound Wave Visualization

/// Animated vertical bars that react to playback state.
struct SoundWaveView: View {
    var isPlaying: Bool
    var colors: [Color]

    private let barCount = 5
    @State private var heights: [CGFloat] = [0.3, 0.6, 0.4, 0.75, 0.5]
    @State private var animationTimer: Timer?

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { i in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [colors.first ?? .white, colors.last ?? .white],
                            startPoint: .bottom,
                            endPoint: .top
                        ).opacity(0.7)
                    )
                    .frame(width: 2.5, height: isPlaying ? max(3, heights[i] * 32) : 3)
                    .animation(
                        isPlaying
                            ? .easeInOut(duration: Double.random(in: 0.28...0.55)).repeatForever(autoreverses: true)
                            : .easeOut(duration: 0.3),
                        value: heights[i]
                    )
            }
        }
        .frame(maxHeight: .infinity)
        .onAppear { startAnimating() }
        .onDisappear { stopAnimating() }
        .onChange(of: isPlaying) { _, playing in
            if playing { startAnimating() } else { stopAnimating() }
        }
    }

    private func startAnimating() {
        guard isPlaying else { return }
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            Task { @MainActor in
                withAnimation {
                    heights = (0..<barCount).map { _ in CGFloat.random(in: 0.2...1.0) }
                }
            }
        }
        // Kick off immediately
        withAnimation {
            heights = (0..<barCount).map { _ in CGFloat.random(in: 0.2...1.0) }
        }
    }

    private func stopAnimating() {
        animationTimer?.invalidate()
        animationTimer = nil
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
        MockTrack(title: "Midnight City", artist: "M83", album: "Hurry Up, We're Dreaming",
                  duration: 243, gradientColors: [.indigo, .purple]),
        MockTrack(title: "Blinding Lights", artist: "The Weeknd", album: "After Hours",
                  duration: 200, gradientColors: [.red, .orange]),
        MockTrack(title: "Starboy", artist: "The Weeknd", album: "Starboy",
                  duration: 230, gradientColors: [.blue, .cyan]),
        MockTrack(title: "Bohemian Rhapsody", artist: "Queen", album: "A Night at the Opera",
                  duration: 354, gradientColors: [.yellow, .orange]),
    ]
}
