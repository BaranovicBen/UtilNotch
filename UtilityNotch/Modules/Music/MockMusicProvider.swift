import SwiftUI

/// Mock music provider backed by an in-memory MusicPlayerState.
/// Used until real providers (Apple Music, Spotify) are wired in.
@Observable
final class MockMusicProvider: MusicProvider, QueueAwareMusicProvider {

    static let shared = MockMusicProvider()

    @MainActor let kind: MusicProviderKind = .appleMusic
    let capabilities: MusicCapabilities = .full

    private let state: MusicPlayerState
    /// Last-seen track ID — used to detect track changes and promote current → previous.
    private var lastSeenTrackID: String?
    private var cachedPrevious: TrackCard?

    private init() {
        self.state = MusicPlayerState(tracks: Self.mockTracks)
    }

    // MARK: - MusicProvider

    func connect() async {}
    func disconnect() async {}

    func refreshStatus() async -> MusicProviderStatus {
        MusicProviderStatus(isAuthorized: true, isInstalled: true, hasActiveSession: true,
                            displayName: "Mock (Demo)", detail: nil)
    }

    func refreshNowPlaying() async -> NowPlayingState {
        let tracks = state.tracks
        guard !tracks.isEmpty else { return .unavailable(for: .appleMusic) }

        let current = trackCard(at: state.currentIndex)

        // Promote current → previous when track advances
        if let current, current.id != lastSeenTrackID {
            if lastSeenTrackID != nil { cachedPrevious = trackCard(forID: lastSeenTrackID!) }
            lastSeenTrackID = current.id
        }

        let nextIdx  = (state.currentIndex + 1) % tracks.count
        let upNextCards = (2...4).compactMap { offset -> TrackCard? in
            trackCard(at: (state.currentIndex + offset) % tracks.count)
        }

        return NowPlayingState(
            provider: .appleMusic,
            isAvailable: true,
            isPlaying: state.isPlaying,
            progressSeconds: state.currentTime,
            durationSeconds: state.currentTrack?.duration,
            playbackRate: state.isPlaying ? 1.0 : 0.0,
            refreshedAt: Date(),
            current: current,
            previous: cachedPrevious,
            next: trackCard(at: nextIdx),
            upNext: upNextCards,
            playbackSourceLabel: "DEMO",
            previousHistory: []
        )
    }

    func playPause() async {
        if state.isPlaying { state.pause() } else { state.play() }
    }

    func next() async {
        if let id = lastSeenTrackID { cachedPrevious = trackCard(forID: id) }
        state.next()
    }

    func previous() async { state.previous() }
    func seek(to seconds: Double) async { state.seek(to: seconds) }
    @MainActor func openNativeApp() {}

    // MARK: - QueueAwareMusicProvider

    func refreshQueue() async -> [TrackCard] {
        let tracks = state.tracks
        guard !tracks.isEmpty else { return [] }
        return (1...min(4, tracks.count - 1)).compactMap { offset in
            trackCard(at: (state.currentIndex + offset) % tracks.count)
        }
    }

    // MARK: - Helpers

    private func trackCard(at rawIndex: Int) -> TrackCard? {
        let tracks = state.tracks
        guard !tracks.isEmpty else { return nil }
        let idx = ((rawIndex % tracks.count) + tracks.count) % tracks.count
        return makeCard(from: tracks[idx])
    }

    private func trackCard(forID id: String) -> TrackCard? {
        state.tracks.first(where: { $0.id.uuidString == id }).map { makeCard(from: $0) }
    }

    private func makeCard(from track: MusicTrack) -> TrackCard {
        TrackCard(id: track.id.uuidString, provider: .appleMusic,
                  title: track.title, artist: track.artist,
                  album: nil, artworkData: nil, artworkURL: nil, deepLinkURL: nil,
                  trackNumber: nil)
    }

    // MARK: - Mock catalogue

    static let mockTracks: [MusicTrack] = [
        MusicTrack(id: UUID(), title: "Midnight City",     artist: "M83",           duration: 243,
                   albumColors: [Color(hex: "1A0533"), Color(hex: "6D28D9")]),
        MusicTrack(id: UUID(), title: "Blinding Lights",   artist: "The Weeknd",    duration: 200,
                   albumColors: [Color(hex: "7F1D1D"), Color(hex: "F97316")]),
        MusicTrack(id: UUID(), title: "Starboy",           artist: "The Weeknd",    duration: 230,
                   albumColors: [Color(hex: "1E3A5F"), Color(hex: "06B6D4")]),
        MusicTrack(id: UUID(), title: "Bohemian Rhapsody", artist: "Queen",         duration: 354,
                   albumColors: [Color(hex: "713F12"), Color(hex: "FBBF24")]),
        MusicTrack(id: UUID(), title: "Levitating",        artist: "Dua Lipa",      duration: 203,
                   albumColors: [Color(hex: "4C1D95"), Color(hex: "EC4899")]),
        MusicTrack(id: UUID(), title: "Peaches",           artist: "Justin Bieber", duration: 198,
                   albumColors: [Color(hex: "064E3B"), Color(hex: "34D399")]),
    ]
}
