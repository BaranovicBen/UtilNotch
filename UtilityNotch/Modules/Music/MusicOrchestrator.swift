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
    private var enrichers: [String: any MusicEnrichmentProvider] = [:]
    private var refreshTask: Task<Void, Never>?
    private var pollingTask: Task<Void, Never>?

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
        registerEnricher(AppleMusicEnrichment(), forBundleID: "com.apple.Music")
        registerEnricher(SpotifyEnrichment(auth: spotifyAuth), forBundleID: "com.spotify.client")
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
        await mediaRemote.playPause()
        try? await Task.sleep(for: .milliseconds(150))
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

        // Try MRMediaRemote first (on macOS < 15 this returns real data)
        var state = await mediaRemote.refreshNowPlaying()

        // On macOS 15+, mediaremoted returns "Operation not permitted".
        // Fall back to the distributed-notification watcher which works everywhere.
        if !state.isAvailable, let dnState = dnWatcher.latestState {
            state = dnState
            #if DEBUG
            print("🎵 [Orch] using DN state (MRMediaRemote unavailable)")
            #endif
        }

        // Resolve the active bundle ID from the winning state
        let activeBundleID: String? = {
            switch state.provider {
            case .appleMusic: return "com.apple.Music"
            case .spotify:    return "com.spotify.client"
            case .unknown:    return mediaRemote.activeAppBundleID
            }
        }()

        if state.isAvailable,
           let bundleID = activeBundleID,
           let enricher = enrichers[bundleID] {
            let queue = await enricher.enrichQueue()
            if !queue.isEmpty { state = state.withUpNext(queue) }
        }

        nowPlaying = state.isAvailable ? state : nil
        activeProviderKind = state.isAvailable ? state.provider : nil
        updateProviderStatuses(from: state)
        #if DEBUG
        if let np = nowPlaying {
            print("🎵 [Orch] nowPlaying → \"\(np.current?.title ?? "?")\" playing=\(np.isPlaying)")
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
