import Foundation

/// Enriches the now-playing queue for Spotify using the Web API.
/// All playback state (artwork, progress, controls) still comes from MediaRemoteProvider.
/// This enricher only adds the upcoming queue tracks.
///
/// On any error: returns []. On 401 (token revoked/expired): also disconnects the
/// auth client so the settings view can prompt the user to reconnect.
@MainActor
final class SpotifyEnrichment: MusicEnrichmentProvider {

    private static let bundleID = "com.spotify.client"
    private let auth: SpotifyAuthClient
    private let api = SpotifyWebAPIClient()

    init(auth: SpotifyAuthClient) {
        self.auth = auth
    }

    // MARK: - MusicEnrichmentProvider

    func canEnrich(bundleID: String) -> Bool {
        bundleID == Self.bundleID
    }

    func enrichQueue() async -> [TrackCard] {
        guard auth.isConnected else { return [] }
        do {
            let token = try await auth.validToken()
            return try await api.fetchQueue(token: token)
        } catch SpotifyAuthError.unauthorized {
            // Token was revoked or fully expired — surface this in settings
            auth.disconnect()
            return []
        } catch {
            return []
        }
    }
}
