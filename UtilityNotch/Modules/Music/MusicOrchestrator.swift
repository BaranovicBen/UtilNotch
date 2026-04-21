import SwiftUI

/// Central coordinator for music playback.
/// Uses MediaRemoteProvider (MRMediaRemote private framework) as the universal base.
/// Optional enrichment providers extend the queue preview per active app.
@MainActor
@Observable
final class MusicOrchestrator {

    // MARK: - Shared instance

    nonisolated(unsafe) static let shared = MusicOrchestrator()

    // MARK: - Published state

    private(set) var nowPlaying: NowPlayingState?
    private(set) var activeProviderKind: MusicProviderKind?
    private(set) var providerStatuses: [MusicProviderKind: MusicProviderStatus] = [:]
    private(set) var isMediaRemoteAvailable: Bool = false
    private(set) var spotifyAuth = SpotifyAuthClient()

    // MARK: - Private

    private let mediaRemote = MediaRemoteProvider.shared
    private var enrichers: [String: any MusicEnrichmentProvider] = [:]
    private var refreshTask: Task<Void, Never>?

    nonisolated private init() {
        Task { await connect() }
    }

    // MARK: - Setup

    private func connect() async {
        await mediaRemote.connect()
        isMediaRemoteAvailable = mediaRemote.isAvailable
        mediaRemote.onNowPlayingChanged = { [weak self] in
            self?.scheduleRefresh()
        }
        // Restore any previously-stored Spotify tokens from the Keychain
        spotifyAuth.loadStoredTokens()
        registerEnricher(AppleMusicEnrichment(), forBundleID: "com.apple.Music")
        registerEnricher(SpotifyEnrichment(auth: spotifyAuth), forBundleID: "com.spotify.client")
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
        var state = await mediaRemote.refreshNowPlaying()

        if state.isAvailable,
           let bundleID = mediaRemote.activeAppBundleID,
           let enricher = enrichers[bundleID] {
            let queue = await enricher.enrichQueue()
            if !queue.isEmpty { state = state.withUpNext(queue) }
        }

        nowPlaying = state.isAvailable ? state : nil
        activeProviderKind = state.isAvailable ? state.provider : nil
        updateProviderStatuses(from: state)
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
    nonisolated(unsafe) static let defaultValue: MusicOrchestrator = MusicOrchestrator.shared
}

extension EnvironmentValues {
    var musicOrchestrator: MusicOrchestrator {
        get { self[MusicOrchestratorKey.self] }
        set { self[MusicOrchestratorKey.self] = newValue }
    }
}
