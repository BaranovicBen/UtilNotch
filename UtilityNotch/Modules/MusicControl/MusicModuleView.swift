import SwiftUI

/// Music module — artwork-led layout with transport controls and a compact pulse meter.
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
    @State private var isShuffleEnabled = false
    @State private var isRepeatOneEnabled = false

    // 1-second tick for interpolated elapsed time display
    @State private var displayTime = Date()

    // Live audio spectrum meter (real microphone FFT — replaces the old demo pulse animation)
    @State private var spectrumAnalyzer = AudioSpectrumAnalyzer()
    // Watches the default output device so live mic is auto-suppressed on Bluetooth headphones.
    @State private var routeMonitor = AudioOutputRouteMonitor()

    // User's chosen visualizer source (persisted). Defaults to the animated dummy.
    @AppStorage(MusicVizKey.source) private var vizSourceRaw = MusicVizSource.dummy.rawValue
    private var vizSource: MusicVizSource { MusicVizSource(rawValue: vizSourceRaw) ?? .dummy }

    /// Live mic only when the user picked it AND we're not on a Bluetooth output. Capturing the mic
    /// over Bluetooth forces the headset into low-quality call mode and degrades playback.
    private var wantsLiveAudio: Bool { vizSource == .live && !routeMonitor.isBluetoothOutput }

    // Whole-module hover → ambient glow + visualizer brightening
    @State private var isModuleHovering = false
    // Which transport control is directly hovered (gets a slightly stronger glow)
    @State private var hoveredControlIcon: String? = nil

    // Wheel carousel geometry
    private let artSize: CGFloat     = 100
    private let slotDistance: CGFloat = 92
    private let maxRotation: Double   = 35

    // Virtual carousel: [outerPrev?, prev?, current?, next?, outerNext?]
    // Indices 0/4 are the ±2 outer (off-screen) slots used only during animation.
    private var carouselCards: [TrackCard?] {
        let s = orchestrator.nowPlaying
        let history = s?.previousHistory ?? []
        // outerPrev = second-most-recent history card (the card before `previous`)
        let outerPrev: TrackCard? = history.count > 1 ? history[history.count - 2] : nil
        return [outerPrev, s?.previous, s?.current, s?.next, s?.upNext.first]
    }
    // Center index is always 2 (current track)
    private let carouselCenter = 2

    private var coverAccent: Color {
        // User-set module accent/glow overrides the album-derived color; nil → fall back to it.
        appState.moduleColors.musicGlowColor ?? orchestrator.waveColor
    }

    var body: some View {
        let np = orchestrator.nowPlaying
        ModuleShellView(
            moduleTitle: "Music",
            moduleIcon: "music.note",
            modules: shellNavItems(appState: appState),
            activeModuleID: appState.activeModuleID,
            onModuleSelect: { id in
                withAnimation(UNMotion.moduleSwitch) {
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
        .onAppear {
            appState.setModuleActionButton(nil)
            updateMusicActivity()
            routeMonitor.start()
            applyVizMode()
        }
        .onDisappear {
            spectrumAnalyzer.stop()
            routeMonitor.stop()
        }
        .onChange(of: vizSourceRaw) { _, _ in applyVizMode() }
        .onChange(of: routeMonitor.isBluetoothOutput) { _, _ in applyVizMode() }
        .onChange(of: spectrumAnalyzer.lifecycle) { _, newState in
            // If live was requested but the mic is denied/unavailable, fall back to dummy. Coarse
            // lifecycle only (changes rarely) — never engine ops here.
            guard wantsLiveAudio else { return }
            switch newState {
            case .denied, .unavailable, .failed: spectrumAnalyzer.previewMode = true
            default: break
            }
        }
        .onChange(of: orchestrator.nowPlaying?.current?.id) { _, _ in updateMusicActivity() }
        .onChange(of: orchestrator.nowPlaying?.isPlaying) { _, _ in updateMusicActivity() }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { t in
            displayTime = t
            updateMusicActivity()
        }
    }

    // MARK: - Empty state

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 32))
                .foregroundStyle(UNConstants.textPlaceholder)

            VStack(spacing: 6) {
                Text("No music playing")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(UNConstants.textPrimary)
                Text("Start playback in Spotify, Apple Music, or any media app — it will appear here automatically.")
                    .font(.system(size: 11))
                    .foregroundStyle(UNConstants.textTertiary)
                    .multilineTextAlignment(.center)
            }

            if !orchestrator.isMediaRemoteAvailable {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 11))
                        .foregroundStyle(UNConstants.amber)
                    Text("MediaRemote failed to load")
                        .font(.system(size: 11))
                        .foregroundStyle(UNConstants.amber)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(UNConstants.amber.opacity(0.12)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
    }

    // MARK: - Full content column

    private var musicContent: some View {
        ZStack {
            ambientGlow            // strictly behind content — never covers the visualizer
            contentRow
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.18)) { isModuleHovering = hovering }
        }
    }

    private var contentRow: some View {
        HStack(alignment: .center, spacing: 18) {
            currentArtworkTile(size: 178)
                .frame(width: 178, height: 178)

            VStack(alignment: .leading, spacing: 14) {
                trackInfoView

                controlsView
                progressView
            }
            .frame(width: 224, height: 178, alignment: .center)

            Spacer(minLength: 0)

            pulseWheelView
        }
    }

    /// Compact, track-colored elliptical ambient glow centered on the content. Sits behind the
    /// row and fades to clear well inside the module borders, so it reads as soft emitted light
    /// rather than a translucent rectangle.
    ///
    /// IMPORTANT: no `.blendMode` here. A blend mode on a ZStack child forces the *whole* ZStack
    /// into a bounds-clipped compositing group, which clipped the edge-pinned 4th visualizer bar
    /// on hover. The glow is instead self-contained in its own `compositingGroup()` (blur + opacity
    /// only), so it can never impose clipping on the content row.
    private var ambientGlow: some View {
        GeometryReader { geo in
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [coverAccent.opacity(0.22), coverAccent.opacity(0.07), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: min(geo.size.width, geo.size.height) * 0.85
                    )
                )
                .frame(width: geo.size.width * 0.66, height: geo.size.height * 0.68)
                .position(x: geo.size.width * 0.5, y: geo.size.height * 0.52)
                .blur(radius: 36)
                .compositingGroup()
                .opacity(isModuleHovering ? 1 : 0)
        }
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.18), value: isModuleHovering)
    }

    @ViewBuilder
    private func currentArtworkTile(size: CGFloat) -> some View {
        let card = orchestrator.nowPlaying?.current
        if let data = card?.artworkData, let nsImg = NSImage(data: data) {
            Image(nsImage: nsImg)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: UNConstants.tileCornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: UNConstants.tileCornerRadius, style: .continuous)
                        .strokeBorder(coverAccent.opacity(0.24), lineWidth: 1)
                )
        } else if let url = card?.artworkURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: UNConstants.tileCornerRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: UNConstants.tileCornerRadius, style: .continuous)
                                .strokeBorder(coverAccent.opacity(0.24), lineWidth: 1)
                        )
                default:
                    artPlaceholder(for: card)
                }
            }
        } else {
            artPlaceholder(for: card)
        }
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
        return VStack(alignment: .leading, spacing: 5) {
                Text(np?.current?.title ?? "—")
                    .font(.system(size: 18, weight: .medium))
                .foregroundStyle(UNConstants.textPrimary)
                .lineLimit(1)
                .contentTransition(.numericText())

            Text(np?.current?.artist ?? "")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(UNConstants.textSecondary)
                .lineLimit(1)
                .contentTransition(.numericText())

            if let album = np?.current?.album, !album.isEmpty {
                Text(album)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(UNConstants.textTertiary)
                    .lineLimit(1)
                    .textCase(.uppercase)
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(UNMotion.standard, value: orchestrator.nowPlaying?.current?.id)
    }

    // MARK: - Spectrum meter (5 bars, aligned to album cover height)

    private var pulseWheelView: some View {
        // Meter is 76 wide + 8pt trailing margin (= 84pt footprint, unchanged layout budget).
        // The trailing margin keeps the 4th bar clear of the module's right-edge content clip.
        MusicSpectrumBarsView(
            analyzer: spectrumAnalyzer,
            color: coverAccent,
            glow: isModuleHovering,
            lowColor: appState.moduleColors.musicVizLow,
            midColor: appState.moduleColors.musicVizMid,
            highColor: appState.moduleColors.musicVizHigh
        )
        .frame(width: 76, height: 178)
        .padding(.trailing, 8)
    }

    /// Applies the current source choice to the analyzer. Live starts the mic engine; dummy (or the
    /// Bluetooth-forced fallback) flips on the animated preview, which frees the mic immediately.
    private func applyVizMode() {
        if wantsLiveAudio {
            spectrumAnalyzer.previewMode = false   // re-attempt live (mic may now be granted)
            spectrumAnalyzer.start()               // requests microphone permission on first activation
        } else {
            spectrumAnalyzer.previewMode = true    // setter stops the engine + runs the dummy motion
        }
    }

    // MARK: - Playback controls

    private var controlsView: some View {
        let caps = orchestrator.capabilities
        return HStack(spacing: 9) {
            modeButton(
                icon: "shuffle",
                isActive: isShuffleEnabled,
                tooltip: "Shuffle queue"
            ) {
                toggleShuffle()
            }

            controlButton(icon: "backward.fill", size: 15, diameter: 38,
                          disabled: !caps.canSkipPrevious || orchestrator.isTransportCommandInFlight || carouselLocked) {
                triggerCarousel(forward: false)
            }

            controlButton(
                icon: orchestrator.nowPlaying?.isPlaying == true ? "pause.fill" : "play.fill",
                size: 18, diameter: 44, fillOpacity: 0.18,
                disabled: !caps.canPlayPause || orchestrator.isTransportCommandInFlight
            ) {
                Task { await orchestrator.playPause() }
            }

            controlButton(icon: "forward.fill", size: 15, diameter: 38,
                          disabled: !caps.canSkipNext || orchestrator.isTransportCommandInFlight || carouselLocked) {
                triggerCarousel(forward: true)
            }

            modeButton(
                icon: "repeat.1",
                isActive: isRepeatOneEnabled,
                tooltip: "Repeat current song"
            ) {
                toggleRepeatOne()
            }
        }
        .frame(width: 224, alignment: .center)
    }

    private func controlButton(
        icon: String,
        size: CGFloat,
        diameter: CGFloat,
        fillOpacity: Double = 0.15,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let strong = hoveredControlIcon == icon
        return Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(fillOpacity + (isModuleHovering ? 0.05 : 0)))
                    .frame(width: diameter, height: diameter)
                    .shadow(
                        color: controlGlowColor(strong: strong),
                        radius: controlGlowRadius(strong: strong)
                    )
                Image(systemName: icon)
                    .font(.system(size: size, weight: .medium))
                    .foregroundStyle(disabled ? UNConstants.textMuted : Color.white)
                    .contentTransition(.symbolEffect(.replace.downUp))
            }
        }
        .buttonStyle(.pressFeedback)
        .disabled(disabled)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { hoveredControlIcon = hovering ? icon : (hoveredControlIcon == icon ? nil : hoveredControlIcon) }
        }
    }

    /// Soft accent glow for transport controls. Off when the module isn't hovered; subtle on module
    /// hover; a touch stronger on the directly-hovered button. Localized (circular shadow), no layout change.
    private func controlGlowColor(strong: Bool) -> Color {
        guard isModuleHovering else { return .clear }
        return coverAccent.opacity(strong ? 0.75 : 0.32)
    }
    private func controlGlowRadius(strong: Bool) -> CGFloat {
        guard isModuleHovering else { return 0 }
        return strong ? 9 : 5
    }

    private func modeButton(
        icon: String,
        isActive: Bool,
        tooltip: String,
        action: @escaping () -> Void
    ) -> some View {
        let strong = hoveredControlIcon == icon
        return Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isActive ? Color.white : UNConstants.textSecondary)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(isActive ? coverAccent.opacity(0.20) : UNConstants.controlSurface)
                        .shadow(
                            color: controlGlowColor(strong: strong),
                            radius: controlGlowRadius(strong: strong)
                        )
                )
                .overlay(
                    Circle()
                        .strokeBorder(isActive ? coverAccent.opacity(0.50) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.pressFeedback)
        .help(tooltip)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { hoveredControlIcon = hovering ? icon : (hoveredControlIcon == icon ? nil : hoveredControlIcon) }
        }
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
                    .fill(coverAccent.opacity(0.16))
                    .frame(height: 4)
                Capsule()
                    .fill(LinearGradient(
                        colors: [
                            coverAccent.opacity(0.95),
                            coverAccent.opacity(0.72)
                        ],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: max(0, trackWidth * progress), height: 4)
                    .animation(isDraggingProgress ? nil : UNMotion.progress,
                               value: progress)
            }
            .frame(height: 14)
            .contentShape(Rectangle())
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { trackWidth = $0 }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDraggingProgress {
                            appState.dismissalLocks.insert(.dragDrop)
                        }
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
                        appState.dismissalLocks.remove(.dragDrop)
                    }
            )

            HStack {
                Text(formatTime(
                    isDraggingProgress
                        ? dragProgress * (np?.durationSeconds ?? 0)
                        : (np?.currentElapsedTime(at: displayTime) ?? 0)
                ))
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(UNConstants.textTertiary)

                Spacer()

                Text(formatTime(np?.durationSeconds ?? 0))
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(UNConstants.textTertiary)
            }
        }
        .frame(width: 224)
    }

    // MARK: - Wheel animation

    private func triggerCarousel(forward: Bool) {
        guard !carouselLocked else { return }
        carouselLocked = true

        Task { @MainActor in
            if forward { await orchestrator.next() }
            else       { await orchestrator.previous() }
            carouselLocked = false
        }
    }

    private func toggleShuffle() {
        let target = !isShuffleEnabled
        isShuffleEnabled = target
        Task {
            let succeeded = await orchestrator.setShuffleEnabled(target)
            if !succeeded {
                await MainActor.run { isShuffleEnabled.toggle() }
            }
        }
    }

    private func toggleRepeatOne() {
        let target = !isRepeatOneEnabled
        isRepeatOneEnabled = target
        Task {
            let succeeded = await orchestrator.setRepeatOneEnabled(target)
            if !succeeded {
                await MainActor.run { isRepeatOneEnabled.toggle() }
            }
        }
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Double) -> String {
        let s = max(0, Int(seconds))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    @MainActor
    private func updateMusicActivity() {
        appState.liveActivities.removeAll { $0.destinationModuleID == "musicControl" && $0.icon == "music.note" }
        guard let np = orchestrator.nowPlaying,
              np.isPlaying,
              let track = np.current else { return }

        let progress: Double?
        if let duration = np.durationSeconds, duration > 0 {
            progress = min(max(np.currentElapsedTime(at: displayTime) / duration, 0), 1)
        } else {
            progress = nil
        }

        appState.liveActivities.append(
            LiveActivity(
                title: track.title,
                subtitle: track.artist,
                icon: "music.note",
                progress: progress,
                priority: 45,
                timestamp: Date(),
                destinationModuleID: "musicControl"
            )
        )
    }
}
