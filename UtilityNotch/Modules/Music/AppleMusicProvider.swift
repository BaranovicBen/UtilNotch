import Foundation

/// Stub for Apple Music provider — will be fully implemented in Phase 2 using MusicKit.
@Observable
final class AppleMusicProvider: MusicProvider {

    let kind: MusicProviderKind = .appleMusic
    let capabilities: MusicCapabilities = .full

    func connect() async {}
    func disconnect() async {}
    func refreshStatus() async -> MusicProviderStatus { .disconnected(displayName: "Apple Music") }
    func refreshNowPlaying() async -> NowPlayingState { .unavailable(for: .appleMusic) }
    func playPause() async {}
    func next() async {}
    func previous() async {}
    func seek(to seconds: Double) async {}
    func openNativeApp() {}
}
