import Foundation

/// Core playback state machine used by MockMusicProvider.
/// Drives a 1-second timer that advances `currentTime` and auto-skips at track end.
@Observable
final class MusicPlayerState {

    var tracks: [MusicTrack]
    var currentIndex: Int = 0
    var isPlaying: Bool = true
    var currentTime: TimeInterval = 0
    var volume: Float = 0.8

    private var playTimer: Timer?

    init(tracks: [MusicTrack]) {
        self.tracks = tracks
        startTimer()
    }

    var currentTrack: MusicTrack? {
        tracks.isEmpty ? nil : tracks[currentIndex]
    }

    // MARK: - Playback controls

    func play() {
        isPlaying = true
        startTimer()
    }

    func pause() {
        isPlaying = false
        stopTimer()
    }

    func next() {
        currentIndex = (currentIndex + 1) % max(1, tracks.count)
        currentTime = 0
    }

    func previous() {
        // If more than 3 s in, restart the current track instead of going back.
        if currentTime > 3 {
            currentTime = 0
            return
        }
        currentIndex = (currentIndex - 1 + max(1, tracks.count)) % max(1, tracks.count)
        currentTime = 0
    }

    func seek(to time: TimeInterval) {
        guard let track = currentTrack else { return }
        currentTime = max(0, min(time, track.duration))
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isPlaying,
                      let track = self.currentTrack else { return }
                self.currentTime += 1
                if self.currentTime >= track.duration { self.next() }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        playTimer = timer
    }

    private func stopTimer() {
        playTimer?.invalidate()
        playTimer = nil
    }

    deinit { playTimer?.invalidate() }
}
