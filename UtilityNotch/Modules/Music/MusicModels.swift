import Foundation

// MARK: - Provider Kind

enum MusicProviderKind: String, Codable, Equatable, CaseIterable {
    case appleMusic
    case spotify

    var displayName: String {
        switch self {
        case .appleMusic: return "Apple Music"
        case .spotify:    return "Spotify"
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
    let artworkURL: URL?
    let deepLinkURL: URL?
}

// MARK: - Now Playing State

/// Normalized playback snapshot — the single currency shared between all providers and all UI.
struct NowPlayingState: Equatable {
    let provider: MusicProviderKind
    let isAvailable: Bool
    let isPlaying: Bool
    let progressSeconds: Double?
    let durationSeconds: Double?
    let current: TrackCard?
    let previous: TrackCard?
    let next: TrackCard?
    let upNext: [TrackCard]
    let playbackSourceLabel: String?

    static func unavailable(for provider: MusicProviderKind) -> NowPlayingState {
        NowPlayingState(
            provider: provider,
            isAvailable: false,
            isPlaying: false,
            progressSeconds: nil,
            durationSeconds: nil,
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
