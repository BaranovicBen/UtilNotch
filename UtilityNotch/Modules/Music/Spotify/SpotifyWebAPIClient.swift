import Foundation

/// Fetches the current user's Spotify playback queue via the Web API.
/// All error handling (unauthorized, rate-limit, server errors) is encapsulated here.
/// Callers receive either a list of tracks or an error — never partial results.
struct SpotifyWebAPIClient {

    func fetchQueue(token: String) async throws -> [TrackCard] {
        var req = URLRequest(url: SpotifyConfig.queueEndpoint)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await sendQueue(req, retriesLeft: 3)
    }

    /// Fetches the current player state — is_playing, progress, duration, and artwork URL.
    /// Returns nil when nothing is playing (HTTP 204) or after a 429 (caller should use cached state).
    func fetchCurrentPlayer(token: String) async throws -> SpotifyCurrentPlayer? {
        var req = URLRequest(url: SpotifyConfig.currentPlayerEndpoint)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        let statusCode = (resp as? HTTPURLResponse)?.statusCode ?? 0
        switch statusCode {
        case 200:
            return try parseCurrentPlayer(from: data)
        case 204:
            return nil
        case 401:
            throw SpotifyAuthError.unauthorized
        case 429:
            return nil
        default:
            return nil
        }
    }

    // MARK: - Private (queue)

    private func sendQueue(_ req: URLRequest, retriesLeft: Int) async throws -> [TrackCard] {
        let (data, resp) = try await URLSession.shared.data(for: req)
        let statusCode = (resp as? HTTPURLResponse)?.statusCode ?? 0

        switch statusCode {
        case 200:
            return try parseQueue(from: data)
        case 204:
            return []
        case 401:
            throw SpotifyAuthError.unauthorized
        case 429 where retriesLeft > 0:
            let retryAfter = (resp as? HTTPURLResponse)
                .flatMap { $0.value(forHTTPHeaderField: "Retry-After") }
                .flatMap { Double($0) } ?? 2.0
            try await Task.sleep(for: .seconds(retryAfter))
            return try await sendQueue(req, retriesLeft: retriesLeft - 1)
        case 500...599 where retriesLeft > 0:
            let delay = 1.5 * Double(4 - retriesLeft)
            try await Task.sleep(for: .seconds(delay))
            return try await sendQueue(req, retriesLeft: retriesLeft - 1)
        default:
            return []
        }
    }

    private func parseQueue(from data: Data) throws -> [TrackCard] {
        let root = try JSONDecoder().decode(QueueResponse.self, from: data)
        return root.queue
            .filter { $0.type == "track" }
            .prefix(5)
            .compactMap(\.asTrackCard)
    }

    // MARK: - Private (current player)

    private func parseCurrentPlayer(from data: Data) throws -> SpotifyCurrentPlayer? {
        let root = try JSONDecoder().decode(CurrentPlayerResponse.self, from: data)
        guard let item = root.item else { return nil }
        let artist = item.artists?.first?.name ?? ""
        let artURL = item.album?.images?
            .compactMap { img -> (Int, URL)? in
                guard let w = img.width, let u = URL(string: img.url) else { return nil }
                return (w, u)
            }
            .filter { $0.0 >= 64 }
            .max(by: { $0.0 < $1.0 })   // largest available (640×640 when present)
            .map(\.1)
        let deepLink = item.external_urls?.spotify.flatMap { URL(string: $0) }
        return SpotifyCurrentPlayer(
            isPlaying:   root.is_playing,
            progressMs:  root.progress_ms ?? 0,
            durationMs:  item.duration_ms,
            trackID:     item.id,
            title:       item.name,
            artist:      artist,
            album:       item.album?.name,
            artworkURL:  artURL,
            deepLinkURL: deepLink
        )
    }
}

// MARK: - SpotifyCurrentPlayer

struct SpotifyCurrentPlayer {
    let isPlaying:   Bool
    let progressMs:  Int
    let durationMs:  Int?
    let trackID:     String?
    let title:       String
    let artist:      String
    let album:       String?
    let artworkURL:  URL?
    let deepLinkURL: URL?
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
        let artURL = album?.images?
            .compactMap { img -> (Int, URL)? in
                guard let w = img.width, let u = URL(string: img.url) else { return nil }
                return (w, u)
            }
            .filter { $0.0 >= 64 }
            .max(by: { $0.0 < $1.0 })   // largest available (640×640 when present)
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

private struct CurrentPlayerResponse: Decodable {
    let is_playing:  Bool
    let progress_ms: Int?
    let item:        PlayerItem?
}

private struct PlayerItem: Decodable {
    let id:           String?
    let name:         String
    let duration_ms:  Int?
    let artists:      [Artist]?
    let album:        Album?
    let external_urls: ExternalURLs?

    struct Artist: Decodable { let name: String }
    struct Album: Decodable {
        let name: String
        let images: [AlbumImage]?
        struct AlbumImage: Decodable { let url: String; let width: Int?; let height: Int? }
    }
    struct ExternalURLs: Decodable { let spotify: String? }
}
