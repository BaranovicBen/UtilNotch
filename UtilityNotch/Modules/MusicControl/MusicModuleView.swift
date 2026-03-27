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

    // MARK: - Content Slot

    // Layout from Music.css:
    //   Top: Track Info Row (album art 151×148 + track info column)
    //   Middle: intentional empty void
    //   Bottom: progress bar (4px height) + timestamps (11px Liberation Mono)

    private var musicContent: some View {
        VStack(spacing: 0) {
            // ── Track info row ────────────────────────────────────────
            // CSS: flex-direction row, gap 24px, height 148px
            HStack(alignment: .top, spacing: 24) {
                // Album art
                // CSS: 151×148px, border-radius 12px
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "1a1a2e"), Color(hex: "16213e"), Color(hex: "0f3460")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.white.opacity(0.25))
                    )
                    .frame(width: 151, height: 148)

                // Track info column
                // CSS: padding 8px 0 0, container 135.42×128px
                VStack(alignment: .leading, spacing: 0) {
                    // Track title
                    // CSS: Inter weight 700, size 24px, line-height 30px, #FFFFFF
                    Text("Midnight City")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)

                    Spacer().frame(height: 16)

                    // Artist
                    // CSS: Inter weight 400, size 14px, line-height 21px, rgba(255,255,255,0.5)
                    Text("M83 — Hurry Up, We're Dreaming")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .lineLimit(2)

                    Spacer()
                }
                .frame(height: 148)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // ── Sound wave visualiser ─────────────────────────────────
            SoundWaveView(isPlaying: isPlaying, colors: [Color.white.opacity(0.5), Color.white])
                .frame(height: 44)
                .frame(maxWidth: .infinity)

            Spacer()

            // ── Progress bar + timestamps + controls ──────────────────
            // CSS: Full-width Progress Bar, 4px height, radius 9999, margin bottom 24px

            VStack(spacing: 0) {
                // Playback controls row
                // CSS: flex-direction row, justify-content space-between, height 57px
                // play button: 40×40 white circle, prev/next: icon only rgba(255,255,255,0.4)
                HStack(spacing: 0) {
                    // Left timestamp
                    // CSS: Liberation Mono 11px, rgba(255,255,255,0.4)
                    Text("1:38")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.4))

                    Spacer()

                    // Controls: prev, play, next
                    // CSS: gap 24px between buttons
                    HStack(spacing: 24) {
                        // Backward
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { isPlaying = true }
                        } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.4))
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.plain)

                        // Play/pause: 36×36 white circle, icon #000000
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { isPlaying.toggle() }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 36, height: 36)
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(Color.black)
                            }
                        }
                        .buttonStyle(.plain)

                        // Forward
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { isPlaying = true }
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.4))
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    // Right timestamp
                    Text("4:03")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
                .frame(height: 40)

                Spacer().frame(height: 12)

                // Progress bar — 3pt height
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 3)
                        Capsule()
                            .fill(Color.white)
                            .frame(width: max(0, geo.size.width * progress), height: 3)
                    }
                }
                .frame(height: 3)
            }
        }
    }
}
