import Foundation

/// Fetches Apple Music / iTunes artwork via the public iTunes Search API.
/// Caches both hits and misses in-memory to avoid hammering the API during polling.
/// No authentication or entitlements required — the API is completely public.
actor AppleMusicArtworkFetcher {

    static let shared = AppleMusicArtworkFetcher()

    private var hits: [String: URL] = [:]   // cacheKey → resolved artwork URL
    private var misses: Set<String> = []    // cacheKeys confirmed to have no result

    // MARK: - Public

    /// Returns the best-available artwork URL for the given track, or nil.
    /// Caches results in-memory so subsequent calls for the same track are instant.
    func artwork(title: String, artist: String, album: String? = nil) async -> URL? {
        let key = cacheKey(title: title, artist: artist)
        if let cached = hits[key]  { return cached }
        if misses.contains(key)    { return nil    }
        return await fetch(title: title, artist: artist, album: album, key: key)
    }

    // MARK: - Private

    private func cacheKey(title: String, artist: String) -> String {
        "\(title.lowercased().trimmingCharacters(in: .whitespaces))\0\(artist.lowercased().trimmingCharacters(in: .whitespaces))"
    }

    private func fetch(title: String, artist: String, album: String?, key: String) async -> URL? {
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        // Include all metadata to narrow results; more candidates → better chance of exact match
        var term = "\(title) \(artist)"
        if let album { term += " \(album)" }
        components.queryItems = [
            URLQueryItem(name: "term",   value: term),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit",  value: "10"),
            URLQueryItem(name: "media",  value: "music")
        ]
        guard let url = components.url else {
            misses.insert(key)
            return nil
        }

        do {
            var req = URLRequest(url: url)
            req.timeoutInterval = 5
            let (data, _) = try await URLSession.shared.data(for: req)
            let resp = try JSONDecoder().decode(iTunesResponse.self, from: data)

            let normalTitle  = title.lowercased().trimmingCharacters(in: .whitespaces)
            let normalArtist = artist.lowercased().trimmingCharacters(in: .whitespaces)

            // Require BOTH title AND artist to match (substring both directions).
            // This prevents returning unrelated tracks that share only a title or artist.
            let candidates = resp.results.filter { track in
                let t = (track.trackName  ?? "").lowercased()
                let a = (track.artistName ?? "").lowercased()
                let titleMatch  = t.contains(normalTitle)  || normalTitle.contains(t)
                let artistMatch = a.contains(normalArtist) || normalArtist.contains(a)
                return titleMatch && artistMatch
            }

            // Prefer the candidate whose album name also matches, for extra precision
            var best = candidates.first
            if candidates.count > 1, let album {
                let normalAlbum = album.lowercased().trimmingCharacters(in: .whitespaces)
                best = candidates.first {
                    ($0.collectionName ?? "").lowercased().contains(normalAlbum)
                } ?? candidates.first
            }

            guard let artStr = best?.artworkUrl100 else {
                // No confident match — cache as miss to avoid hammering the API
                misses.insert(key)
                #if DEBUG
                print("🎵 [AppleMusicArt] no confident match for \"\(title)\" – \(artist) (results: \(resp.results.count))")
                #endif
                return nil
            }

            // Upgrade any NxNbb thumbnail to 600×600 (handles 100x100bb, 75x75bb, etc.)
            let highRes = artStr.replacingOccurrences(
                of: #"\d+x\d+bb"#, with: "600x600bb",
                options: .regularExpression
            )
            let artURL = URL(string: highRes)
            if let u = artURL {
                hits[key] = u
                #if DEBUG
                print("🎵 [AppleMusicArt] ✓ \"\(title)\" – \(artist) → \(u.absoluteString)")
                #endif
            } else {
                misses.insert(key)
            }
            return artURL

        } catch {
            // Network error — don't cache miss so we can retry on the next polling cycle
            #if DEBUG
            print("🎵 [AppleMusicArt] network error for \"\(title)\": \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    private struct iTunesResponse: Decodable {
        let results: [iTunesTrack]
    }
    private struct iTunesTrack: Decodable {
        let artworkUrl100:  String?
        let trackName:      String?
        let artistName:     String?
        let collectionName: String?
    }
}
