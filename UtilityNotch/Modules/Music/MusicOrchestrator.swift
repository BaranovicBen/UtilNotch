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

    /// Previously-playing track injected into the carousel `previous` slot.
    private var previousCard: TrackCard?
    private var lastKnownCurrentID: String?

    /// Bounded Spotify artwork retry — cancelled/replaced on each track change or new retry.
    private var spotifyRetryTask: Task<Void, Never>?
    /// How many retries have been attempted for each Spotify track ID.
    private var spotifyArtworkRetryCount: [String: Int] = [:]

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

        // Preserve artwork when the same track re-refreshes without artwork
        if let existing = nowPlaying?.current,
           let newCurrent = state.current,
           existing.id == newCurrent.id {
            state = state.withCurrentCard(newCurrent.preservingArtwork(from: existing))
        }

        // Apple Music DN never sends elapsed position.
        // Preserve the in-progress interpolated value for same-track refreshes so the
        // scrubber keeps ticking. For a brand-new track, start at 0.
        if state.provider == .appleMusic, state.progressSeconds == nil {
            if let existingNP = nowPlaying,
               state.current?.id == existingNP.current?.id,
               existingNP.progressSeconds != nil {
                let interpolated = existingNP.currentElapsedTime(at: Date())
                state = state.withPlayState(
                    isPlaying: state.isPlaying,
                    progressSeconds: interpolated,
                    durationSeconds: state.durationSeconds
                )
            } else if state.isPlaying, state.current != nil {
                // New track starting — begin interpolation from 0
                state = state.withPlayState(
                    isPlaying: state.isPlaying,
                    progressSeconds: 0,
                    durationSeconds: state.durationSeconds
                )
            }
        }

        // Track the previously-playing card for the carousel previous slot.
        if let newID = state.current?.id, newID != lastKnownCurrentID {
            previousCard = nowPlaying?.current
            lastKnownCurrentID = newID
            // Reset Spotify artwork retry count for this new track
            spotifyArtworkRetryCount.removeValue(forKey: newID)
            spotifyRetryTask?.cancel()
        }

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
            let artTag = np.current?.artworkURL != nil ? "url" :
                         np.current?.artworkData != nil ? "data" : "–"
            print("🎵 [Orch] \"\(np.current?.title ?? "?")\" playing=\(np.isPlaying) progress=\(String(format: "%.1f", np.progressSeconds ?? 0))s dur=\(String(format: "%.0f", np.durationSeconds ?? 0))s art=\(artTag)")
        } else {
            print("🎵 [Orch] nowPlaying → nil")
        }
        #endif

        // Spotify: retry enrichment if we have no artwork (stale API data was discarded)
        if state.isAvailable, state.provider == .spotify,
           state.current?.artworkURL == nil, state.current?.artworkData == nil {
            scheduleSpotifyArtworkRetry(for: state.current?.id ?? "")
        }

        // Apple Music: fetch artwork in background via iTunes Search API
        // (DN never includes artwork; published state first for immediate title/play display)
        if state.isAvailable, state.provider == .appleMusic,
           let card = state.current,
           card.artworkData == nil, card.artworkURL == nil {
            spawnAppleMusicArtworkFetch(for: card)
        }
    }

    /// Schedules a bounded retry refresh for Spotify when enrichment returned no artwork.
    /// Cancelled and replaced on each call; max 3 retries per track ID.
    private func scheduleSpotifyArtworkRetry(for trackID: String) {
        guard !trackID.isEmpty else { return }
        let attempt = (spotifyArtworkRetryCount[trackID] ?? 0) + 1
        guard attempt <= 3 else {
            #if DEBUG
            print("🎵 [Orch] Spotify artwork retry limit reached for \(trackID)")
            #endif
            return
        }
        spotifyArtworkRetryCount[trackID] = attempt
        spotifyRetryTask?.cancel()
        spotifyRetryTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1500))
            guard let self, !Task.isCancelled else { return }
            #if DEBUG
            print("🎵 [Orch] Spotify artwork retry \(attempt) firing")
            #endif
            await self._refresh()
        }
    }

    /// Fetches Apple Music artwork from the iTunes Search API in a background task.
    /// Updates `nowPlaying` only if the same track is still playing when the result arrives.
    private func spawnAppleMusicArtworkFetch(for card: TrackCard) {
        let trackID  = card.id
        let title    = card.title
        let artist   = card.artist
        let album    = card.album
        let storeURL = card.deepLinkURL  // Apple Music Store URL contains ?i=<trackID>
        Task { [weak self] in
            guard let self else { return }
            guard let artURL = await AppleMusicArtworkFetcher.shared.artwork(
                title: title, artist: artist, album: album, storeURL: storeURL
            ) else { return }
            guard let current = self.nowPlaying?.current, current.id == trackID,
                  current.artworkURL == nil, current.artworkData == nil else { return }
            if let existing = self.nowPlaying {
                self.nowPlaying = existing.withCurrentCard(current.withArtworkURL(artURL))
                #if DEBUG
                print("🎵 [Orch] Apple Music artwork injected for \"\(title)\"")
                #endif
            }
        }
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
