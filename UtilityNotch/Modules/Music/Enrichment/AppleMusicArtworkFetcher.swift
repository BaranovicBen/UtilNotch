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
    /// Tries the iTunes Lookup API (exact, by track ID) before falling back to text search.
    /// Caches both hits and misses in-memory so subsequent calls for the same track are instant.
    func artwork(title: String, artist: String, album: String? = nil, storeURL: URL? = nil) async -> URL? {
        let key = cacheKey(title: title, artist: artist)
        if let cached = hits[key]  { return cached }
        if misses.contains(key)    { return nil    }

        // Prefer exact lookup via track ID from the Apple Music Store URL (?i=XXXXXXX)
        if let storeURL,
           let trackID = Self.extractAppleMusicTrackID(from: storeURL) {
            if let url = await artworkByLookup(trackID: trackID, key: key) { return url }
        }

        return await fetch(title: title, artist: artist, album: album, key: key)
    }

    // MARK: - Private

    /// Extracts the iTunes track ID from Apple Music / geo.itunes Store URLs (?i= parameter).
    private static func extractAppleMusicTrackID(from url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "i" })?.value
    }

    /// Looks up artwork by exact iTunes track ID. Much more reliable than text search.
    private func artworkByLookup(trackID: String, key: String) async -> URL? {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")!
        components.queryItems = [
            URLQueryItem(name: "id",     value: trackID),
            URLQueryItem(name: "entity", value: "song")
        ]
        guard let url = components.url else { return nil }
        do {
            var req = URLRequest(url: url)
            req.timeoutInterval = 5
            let (data, _) = try await URLSession.shared.data(for: req)
            let resp = try JSONDecoder().decode(iTunesResponse.self, from: data)
            guard let artStr = resp.results.first?.artworkUrl100 else { return nil }
            let highRes = artStr.replacingOccurrences(
                of: #"\d+x\d+bb"#, with: "600x600bb", options: .regularExpression)
            guard let artURL = URL(string: highRes) else { return nil }
            hits[key] = artURL
            #if DEBUG
            print("🎵 [AppleMusicArt] ✓ lookup id=\(trackID) → \(artURL.absoluteString)")
            #endif
            return artURL
        } catch {
            #if DEBUG
            print("🎵 [AppleMusicArt] lookup error id=\(trackID): \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    private func cacheKey(title: String, artist: String) -> String {
        "\(title.lowercased().trimmingCharacters(in: .whitespaces))\0\(artist.lowercased().trimmingCharacters(in: .whitespaces))"
    }

    private func fetch(title: String, artist: String, album: String?, key: String) async -> URL? {
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        // Use a simplified search term: strip "(feat. ...)" from title and use only first artist
        // so complex multi-artist titles don't confuse the iTunes search engine.
        let baseTitle   = (title.components(separatedBy: " (feat.").first
                        ?? title.components(separatedBy: " (ft.").first
                        ?? title).trimmingCharacters(in: .whitespaces)
        let firstArtist = (artist.components(separatedBy: ",").first
                        ?? artist).trimmingCharacters(in: .whitespaces)
        let term = "\(baseTitle) \(firstArtist)"
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

            let normalArtist = artist.lowercased().trimmingCharacters(in: .whitespaces)
            let baseTitleNorm  = baseTitle.lowercased()
            let firstArtistNorm = firstArtist.lowercased()

            // Title must match (base vs result title, substring both ways).
            // Artist: accept if the result artist matches the first artist OR is contained
            // anywhere in the full multi-artist string (e.g. "K/DA" in "K/DA, Madison Beer…").
            let candidates = resp.results.filter { track in
                let t = (track.trackName  ?? "").lowercased()
                let a = (track.artistName ?? "").lowercased()
                let titleMatch  = t.contains(baseTitleNorm) || baseTitleNorm.contains(t)
                let artistMatch = a.contains(firstArtistNorm)
                              || firstArtistNorm.contains(a)
                              || normalArtist.contains(a)
                return titleMatch && artistMatch
            }

            var best = candidates.first
            if candidates.count > 1, let album {
                let normalAlbum = album.lowercased().trimmingCharacters(in: .whitespaces)
                best = candidates.first {
                    ($0.collectionName ?? "").lowercased().contains(normalAlbum)
                } ?? candidates.first
            }

            guard let artStr = best?.artworkUrl100 else {
                misses.insert(key)
                #if DEBUG
                print("🎵 [AppleMusicArt] no match for \"\(title)\" – \(artist) (results: \(resp.results.count))")
                #endif
                return nil
            }

            let highRes = artStr.replacingOccurrences(
                of: #"\d+x\d+bb"#, with: "600x600bb", options: .regularExpression)
            let artURL = URL(string: highRes)
            if let u = artURL {
                hits[key] = u
                #if DEBUG
                print("🎵 [AppleMusicArt] ✓ search \"\(title)\" → \(u.absoluteString)")
                #endif
            } else {
                misses.insert(key)
            }
            return artURL

        } catch {
            #if DEBUG
            print("🎵 [AppleMusicArt] search error for \"\(title)\": \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    // MARK: - Next-track pre-fetch (heuristic, album-based)

    /// Returns a minimal `TrackCard` for the track immediately following `afterTrackNumber`
    /// in the album identified by `albumID` using the iTunes Lookup API.
    /// Returns nil when the track is the last in the album, the request fails, or the API
    /// doesn't recognize the album ID.  This is a heuristic — it is wrong for playlists,
    /// shuffle, and autoplay radio; use only as a cache-warming hint.
    func nextTrackInAlbum(albumID: String, afterTrackNumber: Int) async -> TrackCard? {
        var comps = URLComponents(string: "https://itunes.apple.com/lookup")!
        comps.queryItems = [
            URLQueryItem(name: "id",     value: albumID),
            URLQueryItem(name: "entity", value: "song")
        ]
        guard let url = comps.url else { return nil }
        do {
            var req = URLRequest(url: url)
            req.timeoutInterval = 6
            let (data, _) = try await URLSession.shared.data(for: req)
            let resp = try JSONDecoder().decode(iTunesAlbumResponse.self, from: data)
            let tracks = resp.results.filter { $0.wrapperType == "track" }
            guard let nextTrack = tracks.first(where: { ($0.trackNumber ?? 0) == afterTrackNumber + 1 })
            else { return nil }

            // Build a minimal card. Pre-warm the hits cache so artwork is instant when current.
            let title  = nextTrack.trackName  ?? ""
            let artist = nextTrack.artistName ?? ""
            let key    = cacheKey(title: title, artist: artist)
            var artURL: URL? = hits[key]
            if artURL == nil, let rawArt = nextTrack.artworkUrl100 {
                let highRes = rawArt.replacingOccurrences(
                    of: #"\d+x\d+bb"#, with: "600x600bb", options: .regularExpression)
                artURL = URL(string: highRes)
                if let u = artURL { hits[key] = u }
            }

            let trackID = nextTrack.trackId.map { "\($0)" } ?? "\(albumID)-\(afterTrackNumber+1)"
            return TrackCard(
                id: "apple:next:\(trackID)",
                provider: .appleMusic,
                title: title,
                artist: artist,
                album: nextTrack.collectionName,
                artworkData: nil,
                artworkURL: artURL,
                deepLinkURL: nextTrack.trackViewUrl.flatMap { URL(string: $0) },
                trackNumber: nextTrack.trackNumber
            )
        } catch {
            #if DEBUG
            print("🎵 [AppleMusicArt] album lookup error id=\(albumID): \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    private struct iTunesAlbumResponse: Decodable {
        let results: [iTunesAlbumTrack]
    }
    private struct iTunesAlbumTrack: Decodable {
        let wrapperType:    String?
        let trackNumber:    Int?
        let trackId:        Int?
        let trackName:      String?
        let artistName:     String?
        let collectionName: String?
        let artworkUrl100:  String?
        let trackViewUrl:   String?
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
