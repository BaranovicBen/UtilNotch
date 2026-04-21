import Foundation

/// Enriches the now-playing queue for Spotify using the Web API.
/// Also enriches the current track's play state — artwork URL, accurate is_playing, and progress —
/// by calling `/v1/me/player` when Spotify is authenticated.
///
/// On any error: returns base state unchanged. On 401: disconnects auth client.
@MainActor
final class SpotifyEnrichment: MusicEnrichmentProvider {

    nonisolated private static let bundleID = "com.spotify.client"
    private let auth: SpotifyAuthClient
    private let api = SpotifyWebAPIClient()

    /// Last successful Web API current-player payload (reused during throttle window)
    private var cachedPlayer: SpotifyCurrentPlayer?
    private var cachedPlayerTrackID: String?
    private var lastPlayerFetchAt: Date?

    init(auth: SpotifyAuthClient) {
        self.auth = auth
    }

    // MARK: - MusicEnrichmentProvider

    nonisolated func canEnrich(bundleID: String) -> Bool {
        bundleID == Self.bundleID
    }

    func enrichQueue() async -> [TrackCard] {
        guard auth.isConnected else { return [] }
        do {
            let token = try await auth.validToken()
            return try await api.fetchQueue(token: token)
        } catch SpotifyAuthError.unauthorized {
            auth.disconnect()
            return []
        } catch {
            return []
        }
    }

    // MARK: - Current state enrichment

    /// Enriches a DN-based state with accurate play state, progress, and artwork from the Web API.
    /// Throttled to one Web API call per 2 s for the same track; uses cached result during window.
    func enrichCurrentState(base: NowPlayingState) async -> NowPlayingState {
        guard auth.isConnected else { return base }

        let dnTrackID = base.current?.id ?? ""
        let now = Date()
        let trackChanged = cachedPlayerTrackID != dnTrackID
        let throttled = lastPlayerFetchAt.map { now.timeIntervalSince($0) < 2.0 } ?? false

        if !trackChanged && throttled, let cached = cachedPlayer {
            // Reuse cached player data during throttle window (same track, recent fetch)
            return merge(cached, into: base)
        }

        do {
            let token = try await auth.validToken()
            guard let player = try await api.fetchCurrentPlayer(token: token) else {
                return base
            }
            cachedPlayer = player
            cachedPlayerTrackID = dnTrackID
            lastPlayerFetchAt = Date()
            #if DEBUG
            print("🎵 [SpotifyEnrich] player → isPlaying=\(player.isPlaying) progress=\(player.progressMs)ms art=\(player.artworkURL?.absoluteString ?? "nil")")
            #endif
            return merge(player, into: base)
        } catch SpotifyAuthError.unauthorized {
            auth.disconnect()
            return base
        } catch {
            return base
        }
    }

    // MARK: - Merge helpers

    private func merge(_ player: SpotifyCurrentPlayer, into base: NowPlayingState) -> NowPlayingState {
        let card = TrackCard(
            id: player.trackID.map { "spotify:\($0)" } ?? base.current?.id ?? "",
            provider: .spotify,
            title: player.title.isEmpty ? (base.current?.title ?? "") : player.title,
            artist: player.artist.isEmpty ? (base.current?.artist ?? "") : player.artist,
            album: player.album ?? base.current?.album,
            artworkData: nil,
            artworkURL: player.artworkURL ?? base.current?.artworkURL,
            deepLinkURL: player.deepLinkURL ?? base.current?.deepLinkURL
        )
        return base
            .withCurrentCard(card)
            .withPlayState(
                isPlaying: player.isPlaying,
                progressSeconds: Double(player.progressMs) / 1000,
                durationSeconds: player.durationMs.map { Double($0) / 1000 }
            )
    }
}
