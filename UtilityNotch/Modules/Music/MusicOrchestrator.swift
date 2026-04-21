import SwiftUI

/// Central coordinator for music playback.
/// Uses MediaRemoteProvider (MRMediaRemote private framework) as the universal base.
/// Optional enrichment providers extend the queue preview per active app.
@MainActor
@Observable
final class MusicOrchestrator {

    // MARK: - Shared instance

    nonisolated static let shared = MusicOrchestrator()

    // MARK: - Published state

    private(set) var nowPlaying: NowPlayingState?
    private(set) var activeProviderKind: MusicProviderKind?
    private(set) var providerStatuses: [MusicProviderKind: MusicProviderStatus] = [:]
    private(set) var isMediaRemoteAvailable: Bool = false
    private(set) var spotifyAuth = SpotifyAuthClient()

    // MARK: - Private

    private let mediaRemote = MediaRemoteProvider.shared
    private let dnWatcher   = DistributedNotificationProvider()
    private let appleMusicEnricher = AppleMusicEnrichment()
    private var spotifyEnricher: SpotifyEnrichment?
    private var enrichers: [String: any MusicEnrichmentProvider] = [:]
    private var refreshTask: Task<Void, Never>?
    private var pollingTask: Task<Void, Never>?
    private var refreshGeneration: UInt64 = 0

    /// The track that was `nowPlaying.current` before the most recent track change.
    /// Injected into the `previous` carousel slot when providers don't supply it.
    private var previousCard: TrackCard?
    private var lastKnownCurrentID: String?

    nonisolated private init() {
        Task { await connect() }
    }

    // MARK: - Setup

    private func connect() async {
        #if DEBUG
        print("🎵 [Orch] connect() starting")
        #endif

        // Distributed notifications — primary source, works on all macOS versions
        dnWatcher.start()
        dnWatcher.onNowPlayingChanged = { [weak self] in
            self?.scheduleRefresh()
        }

        // MRMediaRemote — blocked on macOS 15 but kept for commands (play/pause/skip)
        await mediaRemote.connect()
        isMediaRemoteAvailable = mediaRemote.isAvailable
        #if DEBUG
        print("🎵 [Orch] mediaRemote.isAvailable=\(mediaRemote.isAvailable)")
        #endif
        mediaRemote.onNowPlayingChanged = { [weak self] in
            self?.scheduleRefresh()
        }

        spotifyAuth.loadStoredTokens()
        let se = SpotifyEnrichment(auth: spotifyAuth)
        spotifyEnricher = se
        registerEnricher(appleMusicEnricher, forBundleID: "com.apple.Music")
        registerEnricher(se, forBundleID: "com.spotify.client")
        await _refresh()
        startPolling()
    }

    /// Polls every 5 seconds so we catch state that was active before app launch,
    /// slowing to 15-second intervals after the first minute.
    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            var ticks = 0
            let intervals: [Duration] = Array(repeating: .seconds(5), count: 12)
                + Array(repeating: .seconds(15), count: 1000)
            for interval in intervals {
                try? await Task.sleep(for: interval)
                guard let self, !Task.isCancelled else { break }
                await self._refresh()
                ticks += 1
            }
        }
    }

    // MARK: - Provider registration (compat + enricher registration)

    func connectProvider(_ kind: MusicProviderKind) async {
        await connect()
    }

    func registerEnricher(_ enricher: any MusicEnrichmentProvider, forBundleID bundleID: String) {
        enrichers[bundleID] = enricher
    }

    // MARK: - Computed capabilities

    var capabilities: MusicCapabilities {
        isMediaRemoteAvailable ? mediaRemote.capabilities : .none
    }

    var hasAnyAuthorizedProvider: Bool {
        isMediaRemoteAvailable
    }

    // MARK: - Actions

    func playPause() async {
        // Optimistic toggle — keeps UI snappy while command + refresh are in-flight
        if let np = nowPlaying {
            nowPlaying = np.withPlayState(
                isPlaying: !np.isPlaying,
                progressSeconds: np.currentElapsedTime(at: Date())
            )
        }
        await mediaRemote.playPause()
        try? await Task.sleep(for: .milliseconds(400))
        await _refresh()
    }

    func next() async {
        await mediaRemote.next()
        try? await Task.sleep(for: .milliseconds(350))
        await _refresh()
    }

    func previous() async {
        await mediaRemote.previous()
        try? await Task.sleep(for: .milliseconds(350))
        await _refresh()
    }

    func seek(to seconds: Double) async {
        await mediaRemote.seek(to: seconds)
    }

    func openCurrentProviderApp() {
        mediaRemote.openNativeApp()
    }

    // MARK: - Refresh

    /// Schedules a debounced refresh. Cancels any in-flight refresh before starting a new one.
    func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self, !Task.isCancelled else { return }
            await self._refresh()
        }
    }

    func refresh() async {
        await _refresh()
    }

    private func _refresh() async {
        guard !Task.isCancelled else { return }

        let gen: UInt64 = refreshGeneration &+ 1
        refreshGeneration = gen

        var state = await mediaRemote.refreshNowPlaying()
        guard refreshGeneration == gen else { return }

        if !state.isAvailable, let dnState = dnWatcher.latestState {
            state = dnState
            #if DEBUG
            print("🎵 [Orch] using DN state (MRMediaRemote unavailable)")
            #endif
        }

        let activeBundleID: String? = {
            switch state.provider {
            case .appleMusic: return "com.apple.Music"
            case .spotify:    return "com.spotify.client"
            case .unknown:    return mediaRemote.activeAppBundleID
            }
        }()

        // Enrich Spotify state with real play state, progress, and artwork via Web API
        if state.isAvailable, state.provider == .spotify, let se = spotifyEnricher {
            state = await se.enrichCurrentState(base: state)
            guard refreshGeneration == gen else { return }
        }

        // Queue enrichment (next / upNext carousel slots)
        if state.isAvailable,
           let bundleID = activeBundleID,
           let enricher = enrichers[bundleID] {
            let queue = await enricher.enrichQueue()
            guard refreshGeneration == gen else { return }
            if !queue.isEmpty { state = state.withUpNext(queue) }
        }

        // Preserve artwork from the existing nowPlaying state when the same track
        // re-refreshes without artwork (e.g. after a DN fires before enrichment completes).
        if let existing = nowPlaying?.current,
           let newCurrent = state.current,
           existing.id == newCurrent.id {
            state = state.withCurrentCard(newCurrent.preservingArtwork(from: existing))
        }

        // Track the previously-playing card so the carousel can show it.
        // Save the old current BEFORE overwriting nowPlaying.
        if let newID = state.current?.id, newID != lastKnownCurrentID {
            previousCard = nowPlaying?.current
            lastKnownCurrentID = newID
        }

        // Inject previousCard into the state when providers don't supply a previous slot.
        if state.previous == nil,
           let prev = previousCard,
           prev.id != state.current?.id {
            state = state.withPrevious(prev)
        }

        nowPlaying = state.isAvailable ? state : nil
        activeProviderKind = state.isAvailable ? state.provider : nil
        updateProviderStatuses(from: state)
        #if DEBUG
        if let np = nowPlaying {
            print("🎵 [Orch] nowPlaying → \"\(np.current?.title ?? "?")\" playing=\(np.isPlaying) progress=\(String(format: "%.1f", np.progressSeconds ?? 0))s art=\(np.current?.artworkURL != nil || np.current?.artworkData != nil ? "✓" : "–")")
        } else {
            print("🎵 [Orch] nowPlaying → nil (unavailable)")
        }
        #endif
    }

    private func updateProviderStatuses(from state: NowPlayingState) {
        let status = MusicProviderStatus(
            isAuthorized: isMediaRemoteAvailable,
            isInstalled: true,
            hasActiveSession: state.isAvailable,
            displayName: "System Media",
            detail: isMediaRemoteAvailable ? nil : "MediaRemote unavailable"
        )
        // Mirror status under all known kinds so the settings view works correctly
        for kind in MusicProviderKind.allCases {
            providerStatuses[kind] = status
        }
    }
}

// MARK: - SwiftUI Environment

private struct MusicOrchestratorKey: EnvironmentKey {
    static let defaultValue: MusicOrchestrator = MusicOrchestrator.shared
}

extension EnvironmentValues {
    var musicOrchestrator: MusicOrchestrator {
        get { self[MusicOrchestratorKey.self] }
        set { self[MusicOrchestratorKey.self] = newValue }
    }
}
