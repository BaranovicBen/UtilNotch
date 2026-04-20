import Foundation

/// Protocol for optional queue enrichment providers.
/// Enrichers only supply the upcoming track list — all playback state comes from MediaRemoteProvider.
protocol MusicEnrichmentProvider: AnyObject {
    /// Returns true if this enricher can supply queue data for the given app bundle ID.
    func canEnrich(bundleID: String) -> Bool
    /// Fetches the upcoming queue tracks. Returns empty array on any failure.
    func enrichQueue() async -> [TrackCard]
}
