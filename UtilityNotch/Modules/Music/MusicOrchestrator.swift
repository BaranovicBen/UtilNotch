import SwiftUI

/// Central coordinator for music playback.
/// The only object the Music module UI talks to — providers are never accessed from UI directly.
///
/// Provider selection priority: user preferred → Apple Music → Spotify
/// Polling interval: 1 second (adaptive per-phase polish in Phase 6)
@Observable
final class MusicOrchestrator {

    // MARK: - Shared instance

    nonisolated(unsafe) static let shared = MusicOrchestrator()

    // MARK: - Published state

    private(set) var nowPlaying: NowPlayingState?
    private(set) var activeProviderKind: MusicProviderKind?
    private(set) var providerStatuses: [MusicProviderKind: MusicProviderStatus] = [:]

    /// User's preferred provider. Persisted separately — set via `setPreferredProvider`.
    var preferredProvider: MusicProviderKind? {
        didSet { Task { await refresh() } }
    }

    // MARK: - Private

    private var providers: [MusicProviderKind: any MusicProvider] = [:]
    private var pollingTask: Task<Void, Never>?

    private init() {
        providers[.appleMusic] = MockMusicProvider.shared
        Task { await refresh() }
        startPolling()
    }

    // MARK: - Provider registration

    /// Replace or add a provider. Call from app bootstrap when real providers are ready.
    func setProvider(_ provider: any MusicProvider) {
        providers[provider.kind] = provider
    }

    // MARK: - Computed capabilities

    var capabilities: MusicCapabilities {
        guard let kind = activeProviderKind, let p = providers[kind] else { return .none }
        return p.capabilities
    }

    // MARK: - Actions (forwarded to active provider)

    func playPause() async {
        await activeProvider?.playPause()
        await refresh()
    }

    func next() async {
        await activeProvider?.next()
        await refresh()
    }

    func previous() async {
        await activeProvider?.previous()
        await refresh()
    }

    func seek(to seconds: Double) async {
        await activeProvider?.seek(to: seconds)
    }

    func openCurrentProviderApp() {
        activeProvider?.openNativeApp()
    }

    func setPreferredProvider(_ kind: MusicProviderKind?) {
        preferredProvider = kind
    }

    // MARK: - Polling

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    // MARK: - Refresh

    func refresh() async {
        await refreshStatuses()
        await resolveNowPlaying()
    }

    private func refreshStatuses() async {
        for (kind, provider) in providers {
            let status = await provider.refreshStatus()
            providerStatuses[kind] = status
        }
    }

    private func resolveNowPlaying() async {
        for kind in prioritizedProviders() {
            guard let provider = providers[kind] else { continue }
            let state = await provider.refreshNowPlaying()
            if state.isAvailable {
                activeProviderKind = kind
                nowPlaying = state
                return
            }
        }
        activeProviderKind = nil
        nowPlaying = nil
    }

    private var activeProvider: (any MusicProvider)? {
        guard let kind = activeProviderKind else { return nil }
        return providers[kind]
    }

    /// Provider priority: user preferred → Apple Music → Spotify
    private func prioritizedProviders() -> [MusicProviderKind] {
        if let preferred = preferredProvider {
            return [preferred] + MusicProviderKind.allCases.filter { $0 != preferred }
        }
        return MusicProviderKind.allCases
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
