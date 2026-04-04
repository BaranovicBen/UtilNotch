import Foundation

/// Stub for a future Apple Music / system media integration.
///
/// Implementation options:
///   • MusicKit  — `import MusicKit`, requires Apple Music subscription entitlement
///   • MediaPlayer framework — `MPMusicPlayerController.systemMusicPlayer`
///   • MRMediaRemote (private)  — broadest compatibility but AppStore-unsafe
///
/// TODO: Apple Music provider selection — wire when integration is implemented.
@Observable
final class AppleMusicProvider: MusicProvider {

    var tracks: [MusicTrack] = []
    var currentIndex: Int = 0
    var currentTrack: MusicTrack? { nil }
    var isPlaying: Bool = false
    var currentTime: TimeInterval = 0

    func play()     async { /* TODO: MPMusicPlayerController.systemMusicPlayer.play() */ }
    func pause()    async { /* TODO: MPMusicPlayerController.systemMusicPlayer.pause() */ }
    func next()     async { /* TODO: MPMusicPlayerController.systemMusicPlayer.skipToNextItem() */ }
    func previous() async { /* TODO: MPMusicPlayerController.systemMusicPlayer.skipToPreviousItem() */ }
    func seek(to time: TimeInterval) async { /* TODO: currentPlaybackTime = time */ }
}
