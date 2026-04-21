import Foundation

/// Fetches the current user's Spotify playback queue via the Web API.
/// All error handling (unauthorized, rate-limit, server errors) is encapsulated here.
/// Callers receive either a list of tracks or an error — never partial results.
struct SpotifyWebAPIClient {

    func fetchQueue(token: String) async throws -> [TrackCard] {
        var req = URLRequest(url: SpotifyConfig.queueEndpoint)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await send(req, retriesLeft: 3)
    }

    // MARK: - Private

    private func send(_ req: URLRequest, retriesLeft: Int) async throws -> [TrackCard] {
        let (data, resp) = try await URLSession.shared.data(for: req)
        let statusCode = (resp as? HTTPURLResponse)?.statusCode ?? 0

        switch statusCode {
        case 200:
            return try parseQueue(from: data)
        case 204:
            // Nothing queued / playback inactive
            return []
        case 401:
            throw SpotifyAuthError.unauthorized
        case 429 where retriesLeft > 0:
            let retryAfter = (resp as? HTTPURLResponse)
                .flatMap { $0.value(forHTTPHeaderField: "Retry-After") }
                .flatMap { Double($0) } ?? 2.0
            try await Task.sleep(for: .seconds(retryAfter))
            return try await send(req, retriesLeft: retriesLeft - 1)
        case 500...599 where retriesLeft > 0:
            let delay = 1.5 * Double(4 - retriesLeft)
            try await Task.sleep(for: .seconds(delay))
            return try await send(req, retriesLeft: retriesLeft - 1)
        default:
            return []
        }
    }

    private func parseQueue(from data: Data) throws -> [TrackCard] {
        // Spotify queue endpoint returns { currently_playing: …, queue: [ …track objects… ] }
        // We only need the queue array (upcoming tracks, not the current track).
        let root = try JSONDecoder().decode(QueueResponse.self, from: data)
        return root.queue
            .filter { $0.type == "track" }
            .prefix(5)
            .compactMap(\.asTrackCard)
    }
}

// MARK: - Decodable models

private struct QueueResponse: Decodable {
    let queue: [QueueItem]
}

private struct QueueItem: Decodable {
    let type: String
    let id: String?
    let name: String
    let artists: [Artist]?
    let album: Album?
    let external_urls: ExternalURLs?

    struct Artist: Decodable { let name: String }
    struct Album: Decodable {
        let name: String
        let images: [AlbumImage]?
        struct AlbumImage: Decodable { let url: String; let width: Int?; let height: Int? }
    }
    struct ExternalURLs: Decodable { let spotify: String? }

    var asTrackCard: TrackCard? {
        let artist = artists?.first?.name ?? ""
        // Pick the smallest image that's still ≥64px (avoids thumbnail blurriness)
        let artURL = album?.images?
            .compactMap { img -> (Int, URL)? in
                guard let w = img.width, let u = URL(string: img.url) else { return nil }
                return (w, u)
            }
            .filter { $0.0 >= 64 }
            .min(by: { $0.0 < $1.0 })
            .map(\.1)
        let deepLink = external_urls?.spotify.flatMap { URL(string: $0) }
        return TrackCard(
            id: "spotify:queue:\(id ?? name)",
            provider: .spotify,
            title: name,
            artist: artist,
            album: album?.name,
            artworkData: nil,
            artworkURL: artURL,
            deepLinkURL: deepLink
        )
    }
}
