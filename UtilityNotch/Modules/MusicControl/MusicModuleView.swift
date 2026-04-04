import SwiftUI

/// Music module — full-shell Figma implementation.
/// CSS source: /DesignReference/Css/Music.css
struct MusicModuleView: View {
    @Environment(AppState.self) private var appState
    @State private var isPlaying: Bool = true
    @State private var progress: CGFloat = 0.40

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
            statusLeft: "CONNECT A PLAYER",
            statusRight: "DEMO",
            actionButton: nil
        ) {
            musicContent
        }
    }

    // MARK: - Content

    private var musicContent: some View {
        VStack(spacing: 0) {
            // ── ALBUM ART — centered ───────────────────────────────────
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "1A0533"), Color(hex: "3D1A6E")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.white.opacity(0.25))
                )
                .frame(width: 88, height: 88)

            Spacer().frame(height: 10)

            // ── TRACK INFO — centered ──────────────────────────────────
            VStack(spacing: 4) {
                Text("Midnight City")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                Text("M83")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.50))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)

            Spacer().frame(height: 10)

            // ── WAVE: full width ───────────────────────────────────────
            MusicWaveView(isPlaying: isPlaying)
                .frame(maxWidth: .infinity)

            Spacer().frame(height: 10)

            // ── PLAYBACK CONTROLS — centered ──────────────────────────
            HStack(spacing: 20) {
                // Backward
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { isPlaying = true }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "backward.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.white)
                    }
                }
                .buttonStyle(.plain)

                // Play / Pause
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { isPlaying.toggle() }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.20))
                            .frame(width: 36, height: 36)
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                }
                .buttonStyle(.plain)

                // Forward
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { isPlaying = true }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.white)
                    }
                }
                .buttonStyle(.plain)
            }

            Spacer().frame(height: 10)

            // ── PROGRESS BAR + TIMESTAMPS ─────────────────────────────
            VStack(spacing: 5) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 3)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "8B5CF6"), Color(hex: "3B82F6")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, geo.size.width * progress), height: 3)
                    }
                }
                .frame(height: 3)

                HStack {
                    Text("1:38")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.35))
                    Spacer()
                    Text("4:03")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.35))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Music Wave View

private struct MusicWaveView: View {
    let isPlaying: Bool

    @State private var barHeights: [CGFloat] = Array(repeating: 4, count: 30)
    @State private var waveTimer: Timer? = nil

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
        .onAppear {
            if isPlaying { startAnimating() }
        }
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
