import Foundation

/// Abstraction over any music playback source (mock, Spotify, Apple Music, …).
/// All mutating calls are async so real integrations can bridge to system APIs.
protocol MusicProvider: AnyObject {
    /// The full playback queue visible to the module.
    var tracks: [MusicTrack] { get }
    /// Index of the currently playing track inside `tracks`.
    var currentIndex: Int { get }
    /// Convenience: `tracks[currentIndex]`, or nil when the queue is empty.
    var currentTrack: MusicTrack? { get }
    /// Whether playback is active.
    var isPlaying: Bool { get }
    /// Elapsed time within the current track (seconds).
    var currentTime: TimeInterval { get }

    func play() async
    func pause() async
    func next() async
    func previous() async
    func seek(to time: TimeInterval) async
}
