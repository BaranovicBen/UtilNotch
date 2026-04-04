import Foundation

/// Stub for a future Spotify integration.
///
/// Implementation options:
///   • Spotify Web API  — OAuth2 + REST, requires internet & user auth
///   • AppleScript bridge — `tell application "Spotify" to …`, works locally
///   • SpotifyiOS SDK  — not available on macOS; use the Web API instead
///
/// TODO: Spotify provider selection — wire when integration is implemented.
@Observable
final class SpotifyMusicProvider: MusicProvider {

    var tracks: [MusicTrack] = []
    var currentIndex: Int = 0
    var currentTrack: MusicTrack? { nil }
    var isPlaying: Bool = false
    var currentTime: TimeInterval = 0

    func play()     async { /* TODO: POST /me/player/play */ }
    func pause()    async { /* TODO: PUT  /me/player/pause */ }
    func next()     async { /* TODO: POST /me/player/next */ }
    func previous() async { /* TODO: POST /me/player/previous */ }
    func seek(to time: TimeInterval) async { /* TODO: PUT /me/player/seek?position_ms= */ }
}
