import SwiftUI

/// Data model for a single track displayed in the Music module.
struct MusicTrack: Identifiable, Equatable {
    let id: UUID
    let title: String
    let artist: String
    let duration: TimeInterval
    /// Gradient stop colors used for the album-art placeholder tile.
    let albumColors: [Color]

    static func == (lhs: MusicTrack, rhs: MusicTrack) -> Bool { lhs.id == rhs.id }
}
