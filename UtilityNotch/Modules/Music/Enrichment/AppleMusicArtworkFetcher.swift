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
        var term = "\(title) \(artist)"
        if let album { term += " \(album)" }
        components.queryItems = [
            URLQueryItem(name: "term",   value: term),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit",  value: "5"),
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

            // Prefer a result whose title/artist starts with or closely matches ours
            let best = resp.results.first { track in
                let t = (track.trackName  ?? "").lowercased()
                let a = (track.artistName ?? "").lowercased()
                return t.hasPrefix(normalTitle) || normalTitle.hasPrefix(t)
                    || a.hasPrefix(normalArtist) || normalArtist.hasPrefix(a)
            } ?? resp.results.first

            guard let artStr = best?.artworkUrl100 else {
                misses.insert(key)
                return nil
            }
            // Upgrade 100×100 thumbnail to 600×600
            let highRes = artStr.replacingOccurrences(of: "100x100bb", with: "600x600bb")
            let artURL  = URL(string: highRes)
            if let u = artURL {
                hits[key] = u
                #if DEBUG
                print("🎵 [AppleMusicArt] ✓ \"\(title)\" → \(u.absoluteString)")
                #endif
            } else {
                misses.insert(key)
            }
            return artURL

        } catch {
            // Network error — don't cache miss so we can try again later
            #if DEBUG
            print("🎵 [AppleMusicArt] error for \"\(title)\": \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    private struct iTunesResponse: Decodable {
        let results: [iTunesTrack]
    }
    private struct iTunesTrack: Decodable {
        let artworkUrl100: String?
        let trackName:     String?
        let artistName:    String?
    }
}
