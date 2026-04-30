import SwiftUI
import AppKit

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
    /// Dominant color extracted from the current track's artwork. Used to tint the wave bars.
    private(set) var waveColor: Color = Color.white.opacity(0.5)

    // MARK: - Private

    private let mediaRemote = MediaRemoteProvider.shared
    private let dnWatcher   = DistributedNotificationProvider()
    private let appleMusicEnricher = AppleMusicEnrichment()
    private var spotifyEnricher: SpotifyEnrichment?
    private var enrichers: [String: any MusicEnrichmentProvider] = [:]
    private var refreshTask: Task<Void, Never>?
    private var refreshGeneration: UInt64 = 0

    /// Previously-playing track injected into the carousel `previous` slot.
    private var recentHistory: [TrackCard] = []  // oldest first, max 10
    private var lastKnownCurrentID: String?
    /// Set to true before calling `previous()` so `_refresh` knows not to append to history.
    private var pendingNavBackward = false

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
        dnWatcher.primeFromRunningPlayers()
        await _refresh()
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
        pendingNavBackward = true
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
            // Only push to history on forward/natural navigation — not when pressing previous.
            // Backward nav restores from history; appending would corrupt carousel order.
            if !pendingNavBackward,
               let departing = nowPlaying?.current, departing.id != newID {
                recentHistory.append(departing)
                if recentHistory.count > 10 { recentHistory.removeFirst() }
            }
            pendingNavBackward = false
            lastKnownCurrentID = newID
            // Reset Spotify artwork retry count for this new track
            spotifyArtworkRetryCount.removeValue(forKey: newID)
            spotifyRetryTask?.cancel()
        }

        // Inject the most-recent history card as the `previous` slot (slot 1 in carousel).
        // Also patch any history entry whose artwork hadn't loaded when it was pushed.
        let prevCard = recentHistory.last(where: { $0.id != state.current?.id })
        if state.previous == nil, let prev = prevCard {
            state = state.withPrevious(prev)
        }

        // Carry the full history into state (excludes current track to avoid dup).
        let historyForState = recentHistory.filter { $0.id != state.current?.id }
        state = state.withPreviousHistory(historyForState)

        // Preserve a pre-fetched next card across same-track refreshes.
        // (DN never provides 'next' for Apple Music; album pre-fetch injects it.)
        if state.next == nil,
           let existingNext = nowPlaying?.next,
           state.current?.id == nowPlaying?.current?.id {
            state = state.withNext(existingNext)
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

        // Apple Music: heuristic next-track pre-fetch via album lookup (best-effort).
        if state.isAvailable, state.provider == .appleMusic,
           state.next == nil,
           let card = state.current {
            spawnAppleMusicNextTrackPreFetch(for: card)
        }

        // Extract dominant color from artwork for wave tinting.
        updateWaveColor(from: state.current)
    }

    private func updateWaveColor(from card: TrackCard?) {
        guard let data = card?.artworkData,
              let color = Self.dominantColor(from: data)
        else {
            waveColor = Color.white.opacity(0.5)
            return
        }
        waveColor = color
    }

    /// Samples an 8×8 thumbnail of the image and returns the most-saturated pixel as a Color.
    /// Falls back to nil when the image can't be decoded or all pixels are achromatic.
    private static func dominantColor(from data: Data) -> Color? {
        guard let nsImage = NSImage(data: data),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }

        let side = 8
        var pixels = [UInt8](repeating: 0, count: 4 * side * side)
        guard let ctx = CGContext(
            data: &pixels,
            width: side, height: side,
            bitsPerComponent: 8, bytesPerRow: 4 * side,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

        var bestSaturation: CGFloat = 0
        var bestColor: (CGFloat, CGFloat, CGFloat) = (1, 1, 1)

        for i in stride(from: 0, to: pixels.count, by: 4) {
            let r = CGFloat(pixels[i])     / 255
            let g = CGFloat(pixels[i + 1]) / 255
            let b = CGFloat(pixels[i + 2]) / 255
            let maxC = max(r, g, b)
            let minC = min(r, g, b)
            let sat  = maxC > 0 ? (maxC - minC) / maxC : 0
            if sat > bestSaturation {
                bestSaturation = sat
                bestColor = (r, g, b)
            }
        }

        guard bestSaturation > 0.15 else { return nil }
        return Color(red: bestColor.0, green: bestColor.1, blue: bestColor.2).opacity(0.75)
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
    /// Also patches any matching entry in `recentHistory` in case the track moved there quickly.
    private func spawnAppleMusicArtworkFetch(for card: TrackCard) {
        let trackID  = card.id
        let title    = card.title
        let artist   = card.artist
        let album    = card.album
        let storeURL = card.deepLinkURL
        Task { [weak self] in
            guard let self else { return }
            guard let artURL = await AppleMusicArtworkFetcher.shared.artwork(
                title: title, artist: artist, album: album, storeURL: storeURL
            ) else { return }

            // Inject into current card if it's still current.
            if let current = self.nowPlaying?.current, current.id == trackID,
               current.artworkURL == nil, current.artworkData == nil,
               let existing = self.nowPlaying {
                self.nowPlaying = existing.withCurrentCard(current.withArtworkURL(artURL))
                #if DEBUG
                print("🎵 [Orch] Apple Music artwork injected for \"\(title)\"")
                #endif
            }

            // Also patch any history entry that was pushed before artwork arrived.
            if let histIdx = self.recentHistory.firstIndex(where: { $0.id == trackID }),
               self.recentHistory[histIdx].artworkURL == nil,
               self.recentHistory[histIdx].artworkData == nil {
                self.recentHistory[histIdx] = self.recentHistory[histIdx].withArtworkURL(artURL)
                // Re-stamp state so the carousel sees the updated history.
                if let existing = self.nowPlaying {
                    let updated = self.recentHistory.filter { $0.id != existing.current?.id }
                    var patched = existing.withPreviousHistory(updated)
                    if let prevCard = updated.last {
                        patched = patched.withPrevious(prevCard)
                    }
                    self.nowPlaying = patched
                }
            }
        }
    }

    /// Heuristic: look up the next track in the same album via the iTunes API and pre-warm
    /// the carousel `next` slot. Only fires for Apple Music when `next` is nil, the card has
    /// a trackNumber, and the deepLinkURL exposes an album ID.
    /// This is best-effort — fails gracefully for playlists / shuffle / last album track.
    private func spawnAppleMusicNextTrackPreFetch(for card: TrackCard) {
        guard let trackNumber = card.trackNumber,
              let storeURL = card.deepLinkURL,
              let albumID = Self.extractAlbumID(from: storeURL)
        else { return }

        let currentID = card.id
        Task { [weak self] in
            guard let self else { return }
            guard let nextCard = await AppleMusicArtworkFetcher.shared
                    .nextTrackInAlbum(albumID: albumID, afterTrackNumber: trackNumber)
            else { return }
            // Only inject if same track is still current and next slot is still empty.
            guard self.nowPlaying?.current?.id == currentID,
                  self.nowPlaying?.next == nil,
                  let existing = self.nowPlaying
            else { return }
            self.nowPlaying = existing.withNext(nextCard)
            #if DEBUG
            print("🎵 [Orch] Apple Music next-track pre-fetched: \"\(nextCard.title)\"")
            #endif
        }
    }

    /// Extracts the album ID from an Apple Music Store URL.
    /// Format: `https://music.apple.com/us/album/<name>/<albumID>?i=<trackID>`
    static func extractAlbumID(from url: URL) -> String? {
        // Strip query, take the last numeric path component.
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        comps?.query = nil
        guard let cleanURL = comps?.url else { return nil }
        let last = cleanURL.lastPathComponent
        guard !last.isEmpty, last.allSatisfy(\.isNumber) else { return nil }
        return last
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
