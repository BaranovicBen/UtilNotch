import Foundation

// MARK: - Provider Kind

enum MusicProviderKind: String, Codable, Equatable, CaseIterable {
    case appleMusic
    case spotify
    /// Any other media app detected via MRMediaRemote (Podcasts, YouTube Music, etc.)
    case unknown

    var displayName: String {
        switch self {
        case .appleMusic: return "Apple Music"
        case .spotify:    return "Spotify"
        case .unknown:    return "Media"
        }
    }
}

// MARK: - Track Card

/// Provider-agnostic track representation.
/// UI must never handle Apple Music `Song` or Spotify JSON types directly.
struct TrackCard: Equatable, Identifiable {
    let id: String
    let provider: MusicProviderKind
    let title: String
    let artist: String
    let album: String?
    /// Raw artwork bytes from MRMediaRemote. Preferred over artworkURL when present.
    let artworkData: Data?
    let artworkURL: URL?
    let deepLinkURL: URL?

    /// Returns a copy of this card with `artworkURL` set to the given value.
    func withArtworkURL(_ url: URL) -> TrackCard {
        TrackCard(
            id: id, provider: provider, title: title, artist: artist, album: album,
            artworkData: artworkData, artworkURL: url, deepLinkURL: deepLinkURL
        )
    }

    /// Returns a copy of this card with artwork taken from `source` when self has none.
    func preservingArtwork(from source: TrackCard) -> TrackCard {
        guard artworkData == nil && artworkURL == nil else { return self }
        guard source.artworkData != nil || source.artworkURL != nil else { return self }
        return TrackCard(
            id: id, provider: provider, title: title, artist: artist, album: album,
            artworkData: source.artworkData, artworkURL: source.artworkURL,
            deepLinkURL: deepLinkURL
        )
    }
}

// MARK: - Now Playing State

/// Normalized playback snapshot — the single currency shared between all providers and all UI.
struct NowPlayingState: Equatable {
    let provider: MusicProviderKind
    let isAvailable: Bool
    let isPlaying: Bool
    let progressSeconds: Double?
    let durationSeconds: Double?
    /// Actual playback rate (1.0 = normal, 0.0 = paused, 0.5/2.0 = slow/fast).
    let playbackRate: Double
    /// When this snapshot was captured — used to interpolate elapsed time in the view.
    let refreshedAt: Date
    let current: TrackCard?
    let previous: TrackCard?
    let next: TrackCard?
    let upNext: [TrackCard]
    let playbackSourceLabel: String?

    /// Interpolated elapsed time. Call from a periodic view timer for smooth scrubber display.
    func currentElapsedTime(at date: Date = Date()) -> Double {
        guard let progress = progressSeconds else { return 0 }
        guard isPlaying && playbackRate > 0 else { return progress }
        let elapsed = progress + date.timeIntervalSince(refreshedAt) * playbackRate
        if let dur = durationSeconds { return max(0, min(elapsed, dur)) }
        return max(0, elapsed)
    }

    /// Returns a new state with updated progress and `refreshedAt` reset to `Date()`.
    func withProgress(_ seconds: Double) -> NowPlayingState {
        NowPlayingState(
            provider: provider, isAvailable: isAvailable, isPlaying: isPlaying,
            progressSeconds: seconds, durationSeconds: durationSeconds,
            playbackRate: playbackRate, refreshedAt: Date(),
            current: current, previous: previous,
            next: next, upNext: upNext,
            playbackSourceLabel: playbackSourceLabel
        )
    }

    /// Returns a new state with updated play/pause state and a fresh `refreshedAt`.
    func withPlayState(isPlaying: Bool, progressSeconds: Double?, durationSeconds: Double? = nil) -> NowPlayingState {
        NowPlayingState(
            provider: provider, isAvailable: isAvailable, isPlaying: isPlaying,
            progressSeconds: progressSeconds,
            durationSeconds: durationSeconds ?? self.durationSeconds,
            playbackRate: isPlaying ? 1.0 : 0.0, refreshedAt: Date(),
            current: current, previous: previous,
            next: next, upNext: upNext,
            playbackSourceLabel: playbackSourceLabel
        )
    }

    /// Returns a new state with the previous track slot replaced.
    func withPrevious(_ card: TrackCard?) -> NowPlayingState {
        NowPlayingState(
            provider: provider, isAvailable: isAvailable, isPlaying: isPlaying,
            progressSeconds: progressSeconds, durationSeconds: durationSeconds,
            playbackRate: playbackRate, refreshedAt: refreshedAt,
            current: current, previous: card,
            next: next, upNext: upNext,
            playbackSourceLabel: playbackSourceLabel
        )
    }

    /// Returns a new state with the current track card replaced.
    func withCurrentCard(_ card: TrackCard) -> NowPlayingState {
        NowPlayingState(
            provider: provider, isAvailable: isAvailable, isPlaying: isPlaying,
            progressSeconds: progressSeconds, durationSeconds: durationSeconds,
            playbackRate: playbackRate, refreshedAt: refreshedAt,
            current: card, previous: previous,
            next: next, upNext: upNext,
            playbackSourceLabel: playbackSourceLabel
        )
    }

    /// Returns a new state with the upNext queue replaced by the given tracks.
    /// The first track in `tracks` becomes `next`, the rest populate `upNext`.
    func withUpNext(_ tracks: [TrackCard]) -> NowPlayingState {
        NowPlayingState(
            provider: provider, isAvailable: isAvailable, isPlaying: isPlaying,
            progressSeconds: progressSeconds, durationSeconds: durationSeconds,
            playbackRate: playbackRate, refreshedAt: refreshedAt,
            current: current, previous: previous,
            next: tracks.first ?? next,
            upNext: tracks.count > 1 ? Array(tracks.dropFirst()) : upNext,
            playbackSourceLabel: playbackSourceLabel
        )
    }

    static func unavailable(for provider: MusicProviderKind) -> NowPlayingState {
        NowPlayingState(
            provider: provider,
            isAvailable: false,
            isPlaying: false,
            progressSeconds: nil,
            durationSeconds: nil,
            playbackRate: 1.0,
            refreshedAt: Date(),
            current: nil,
            previous: nil,
            next: nil,
            upNext: [],
            playbackSourceLabel: nil
        )
    }
}

// MARK: - Provider Status

struct MusicProviderStatus: Equatable {
    let isAuthorized: Bool
    let isInstalled: Bool
    let hasActiveSession: Bool
    let displayName: String
    let detail: String?

    static func disconnected(displayName: String) -> MusicProviderStatus {
        MusicProviderStatus(
            isAuthorized: false,
            isInstalled: false,
            hasActiveSession: false,
            displayName: displayName,
            detail: nil
        )
    }
}

// MARK: - Capabilities

/// Describes what a provider can do at runtime.
/// UI disables controls rather than collapsing layout when capabilities are absent.
struct MusicCapabilities: Equatable {
    let canPlayPause: Bool
    let canSkipNext: Bool
    let canSkipPrevious: Bool
    let canShowQueuePreview: Bool
    let canOpenNativeApp: Bool

    static let full = MusicCapabilities(
        canPlayPause: true, canSkipNext: true, canSkipPrevious: true,
        canShowQueuePreview: true, canOpenNativeApp: true
    )

    static let readOnly = MusicCapabilities(
        canPlayPause: false, canSkipNext: false, canSkipPrevious: false,
        canShowQueuePreview: true, canOpenNativeApp: true
    )

    static let none = MusicCapabilities(
        canPlayPause: false, canSkipNext: false, canSkipPrevious: false,
        canShowQueuePreview: false, canOpenNativeApp: false
    )
}
