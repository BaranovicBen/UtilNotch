import Foundation
import AppKit

/// Reads now-playing state via NSDistributedNotificationCenter.
///
/// Spotify broadcasts "com.spotify.client.PlaybackStateChanged" and Apple Music
/// broadcasts "com.apple.Music.playerInfo" to every process on the system — no
/// entitlements, no TCC, works on every macOS version including Sequoia.
///
/// This replaces MRMediaRemote as the primary reading source on macOS 15+
/// where mediaremoted enforces "Operation not permitted" on third-party readers.
@MainActor
final class DistributedNotificationProvider {

    private(set) var latestState: NowPlayingState?
    var onNowPlayingChanged: (() -> Void)?

    private var observers: [NSObjectProtocol] = []

    // MARK: - Lifecycle

    func start() {
        guard observers.isEmpty else { return }
        subscribe("com.spotify.client.PlaybackStateChanged", handler: handleSpotify)
        subscribe("com.apple.Music.playerInfo",              handler: handleAppleMusic)
        #if DEBUG
        print("🎵 [DN] distributed notification listeners registered")
        #endif
    }

    func stop() {
        observers.forEach { DistributedNotificationCenter.default().removeObserver($0) }
        observers.removeAll()
    }

    // MARK: - Private

    private func subscribe(_ name: String, handler: @escaping (Notification) -> Void) {
        // deliverImmediately: use suspensionBehavior .deliverImmediately so we get
        // notifications even when the app's run loop is idle (notch is hidden).
        let center = DistributedNotificationCenter.default()
        let obs = center.addObserver(
            forName: NSNotification.Name(name),
            object: nil,
            queue: .main,
            using: { [weak self] note in
                guard self != nil else { return }
                MainActor.assumeIsolated { handler(note) }
            }
        )
        observers.append(obs)
    }

    // MARK: - Spotify

    private func handleSpotify(_ notification: Notification) {
        guard let info = notification.userInfo else { return }

        let running = (info["Running"] as? Bool) ?? true
        guard running else {
            #if DEBUG
            print("🎵 [DN-Spotify] app not running → clear")
            #endif
            latestState = nil
            onNowPlayingChanged?()
            return
        }

        let title    = (info["Name"]    as? String) ?? "Unknown"
        let artist   = (info["Artist"]  as? String) ?? ""
        let album    = info["Album"]    as? String
        let rawURI   = (info["Track ID"] as? String) ?? ""
        // Normalize to a canonical 22-char Spotify ID; fall back to "title-artist"
        let trackID  = Self.extractSpotifyID(rawURI) ?? "\(title)-\(artist)"

        // Newer Spotify versions use "Player State" string; older ones use "Playing" Bool/NSNumber.
        let isPlaying: Bool = {
            if let state = info["Player State"] as? String { return state == "Playing" }
            if let b = info["Playing"] as? Bool { return b }
            if let n = info["Playing"] as? NSNumber { return n.boolValue }
            return false
        }()
        let position: Double = {
            if let d = info["Position"] as? Double { return d }
            if let n = info["Position"] as? NSNumber { return n.doubleValue }
            return 0
        }()
        // Duration: heuristic for ms vs seconds (no track > 3600s in Spotify)
        let rawDuration: Double? = {
            if let d = info["Duration"] as? Double { return d }
            if let n = info["Duration"] as? NSNumber { return n.doubleValue }
            return nil
        }()
        let duration: Double? = rawDuration.map { $0 > 3600 ? $0 / 1000 : $0 }

        #if DEBUG
        print("🎵 [DN-Spotify] \"\(title)\" – \(artist) playing=\(isPlaying) pos=\(String(format: "%.1f", position))s id=\(trackID)")
        #endif

        // Canonical Spotify card ID: "spotify:<22-char-ID>" or "spotify:<title-artist>"
        let card = TrackCard(
            id: "spotify:\(trackID)",
            provider: .spotify,
            title: title,
            artist: artist,
            album: album,
            artworkData: nil,
            artworkURL: nil,
            deepLinkURL: rawURI.isEmpty ? nil : URL(string: rawURI),
            trackNumber: nil
        )

        latestState = NowPlayingState(
            provider: .spotify,
            isAvailable: true,
            isPlaying: isPlaying,
            progressSeconds: position,
            durationSeconds: duration,
            playbackRate: isPlaying ? 1.0 : 0,
            refreshedAt: Date(),
            current: card,
            previous: nil,
            next: nil,
            upNext: [],
            playbackSourceLabel: "SPOTIFY",
            previousHistory: []
        )
        onNowPlayingChanged?()
    }

    /// Extracts the raw 22-char Spotify track ID from any common URI format.
    /// Returns nil for unrecognised formats (caller falls back to title-artist).
    private static func extractSpotifyID(_ uri: String) -> String? {
        let candidate: String?
        if uri.hasPrefix("spotify:track:") {
            candidate = String(uri.dropFirst("spotify:track:".count))
        } else if uri.contains("open.spotify.com/track/") {
            let tail = uri.components(separatedBy: "/track/").last ?? ""
            candidate = tail.components(separatedBy: "?").first
        } else {
            candidate = uri
        }
        guard let id = candidate, id.count == 22,
              id.allSatisfy({ $0.isLetter || $0.isNumber }) else { return nil }
        return id
    }

    // MARK: - Apple Music

    private func handleAppleMusic(_ notification: Notification) {
        guard let info = notification.userInfo else { return }

        let playerState = (info["Player State"] as? String) ?? "Stopped"
        guard playerState != "Stopped" else {
            if latestState?.provider == .appleMusic {
                #if DEBUG
                print("🎵 [DN-AppleMusic] stopped → clear")
                #endif
                latestState = nil
                onNowPlayingChanged?()
            }
            return
        }

        let title    = (info["Name"]    as? String) ?? "Unknown"
        let artist   = (info["Artist"]  as? String) ?? ""
        let album    = info["Album"]    as? String
        // PersistentID is the stable iTunes library track ID — prefer over title-artist fallback
        let trackID  = (info["PersistentID"] as? String)
            ?? (info["PersistentID"] as? NSNumber).map { "\($0)" }
            ?? "\(title)-\(artist)"
        let isPlaying = playerState == "Playing"

        // "Total Time" is milliseconds
        let totalTimeMs: Double? = {
            if let d = info["Total Time"] as? Double { return d }
            if let n = info["Total Time"] as? NSNumber { return n.doubleValue }
            return nil
        }()
        let duration = totalTimeMs.map { $0 / 1000 }

        // Some macOS versions include elapsed position in seconds
        let elapsedSecs: Double? = {
            if let d = info["Elapsed Time"] as? Double { return d }
            if let n = info["Elapsed Time"] as? NSNumber { return n.doubleValue }
            return nil
        }()

        let storeURL = (info["Store URL"] as? String).flatMap { URL(string: $0) }
        let artData: Data? = (info["Artwork"] as? Data)
            ?? (info["Artwork"] as? NSImage)?.tiffRepresentation
        let trackNumber: Int? = {
            if let n = info["Track Number"] as? Int    { return n }
            if let n = info["Track Number"] as? NSNumber { return n.intValue }
            return nil
        }()

        #if DEBUG
        let keys = info.keys.compactMap { $0 as? String }.sorted()
        print("🎵 [DN-AppleMusic] keys: \(keys.joined(separator: ", "))")
        if let raw = info["Artwork"] {
            print("🎵 [DN-AppleMusic] artwork type=\(type(of: raw)) data=\(artData?.count ?? 0)B")
        } else {
            print("🎵 [DN-AppleMusic] artwork absent")
        }
        print("🎵 [DN-AppleMusic] \"\(title)\" – \(artist) state=\(playerState) elapsed=\(elapsedSecs.map { String(format: "%.1fs", $0) } ?? "nil")")
        #endif

        let card = TrackCard(
            id: "apple:dn:\(trackID)",
            provider: .appleMusic,
            title: title,
            artist: artist,
            album: album,
            artworkData: artData,
            artworkURL: nil,
            deepLinkURL: storeURL,
            trackNumber: trackNumber
        )

        latestState = NowPlayingState(
            provider: .appleMusic,
            isAvailable: true,
            isPlaying: isPlaying,
            progressSeconds: elapsedSecs,
            durationSeconds: duration,
            playbackRate: isPlaying ? 1.0 : 0,
            refreshedAt: Date(),
            current: card,
            previous: nil,
            next: nil,
            upNext: [],
            playbackSourceLabel: "APPLE MUSIC",
            previousHistory: []
        )
        onNowPlayingChanged?()
    }
}
