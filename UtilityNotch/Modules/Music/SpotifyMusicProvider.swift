import Foundation

/// Stub for Spotify provider — will be fully implemented in Phase 3 using Spotify Web API.
@Observable
final class SpotifyMusicProvider: MusicProvider {

    let kind: MusicProviderKind = .spotify
    let capabilities: MusicCapabilities = .full

    func connect() async {}
    func disconnect() async {}
    func refreshStatus() async -> MusicProviderStatus { .disconnected(displayName: "Spotify") }
    func refreshNowPlaying() async -> NowPlayingState { .unavailable(for: .spotify) }
    func playPause() async {}
    func next() async {}
    func previous() async {}
    func seek(to seconds: Double) async {}
    func openNativeApp() {}
}
