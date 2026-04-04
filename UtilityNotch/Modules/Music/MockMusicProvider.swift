import SwiftUI

/// Mock MusicProvider backed by an in-memory MusicPlayerState.
/// Used until a real Spotify / Apple Music integration is wired in.
@Observable
final class MockMusicProvider: MusicProvider {

    static let shared = MockMusicProvider()

    private let state: MusicPlayerState

    private init() {
        self.state = MusicPlayerState(tracks: Self.mockTracks)
    }

    // MARK: - MusicProvider

    var tracks: [MusicTrack]     { state.tracks }
    var currentIndex: Int        { state.currentIndex }
    var currentTrack: MusicTrack? { state.currentTrack }
    var isPlaying: Bool          { state.isPlaying }
    var currentTime: TimeInterval { state.currentTime }

    func play()     async { state.play() }
    func pause()    async { state.pause() }
    func next()     async { state.next() }
    func previous() async { state.previous() }
    func seek(to time: TimeInterval) async { state.seek(to: time) }

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

// MARK: - SwiftUI Environment

private struct MusicProviderKey: EnvironmentKey {
    // nonisolated(unsafe) allows accessing the @Observable shared instance as a
    // static default without actor isolation gymnastics.
    nonisolated(unsafe) static let defaultValue: any MusicProvider = MockMusicProvider.shared
}

extension EnvironmentValues {
    var musicProvider: any MusicProvider {
        get { self[MusicProviderKey.self] }
        set { self[MusicProviderKey.self] = newValue }
    }
}
