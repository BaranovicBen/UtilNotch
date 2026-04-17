import Foundation

/// Abstraction over any music playback source.
/// All methods are async to accommodate remote APIs and system calls.
protocol MusicProvider: AnyObject {
    var kind: MusicProviderKind { get }
    var capabilities: MusicCapabilities { get }

    func connect() async
    func disconnect() async
    func refreshStatus() async -> MusicProviderStatus
    func refreshNowPlaying() async -> NowPlayingState

    func playPause() async
    func next() async
    func previous() async
    func seek(to seconds: Double) async
    func openNativeApp()
}

/// Extended protocol for providers that can supply a full queue preview.
protocol QueueAwareMusicProvider: MusicProvider {
    func refreshQueue() async -> [TrackCard]
}
