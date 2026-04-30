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

    func seedLatestState(_ state: NowPlayingState) {
        latestState = state
    }

    /// Distributed notifications only report future changes. On app launch, query
    /// already-running players once so music that started before Utility Notch is
    /// visible without requiring a pause/play toggle.
    func primeFromRunningPlayers() {
        if let spotifyState = querySpotifyCurrentState() {
            latestState = spotifyState
            #if DEBUG
            print("🎵 [DN-Prime] using current Spotify playback")
            #endif
            return
        }

        if let appleMusicState = queryAppleMusicCurrentState() {
            latestState = appleMusicState
            #if DEBUG
            print("🎵 [DN-Prime] using current Apple Music playback")
            #endif
        }
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

    private func querySpotifyCurrentState() -> NowPlayingState? {
        guard isAppRunning(bundleID: "com.spotify.client") else { return nil }
        let script = """
        tell application "Spotify"
            if player state is stopped then return ""
            set t to current track
            set d to {name of t, artist of t, album of t, spotify url of t, duration of t, player position, player state as string}
            set AppleScript's text item delimiters to "|||"
            return d as text
        end tell
        """
        guard let fields = runAppleScript(script), fields.count >= 7 else { return nil }

        let title = fields[0].isEmpty ? "Unknown" : fields[0]
        let artist = fields[1]
        let album = fields[2].isEmpty ? nil : fields[2]
        let rawURI = fields[3]
        let trackID = Self.extractSpotifyID(rawURI) ?? "\(title)-\(artist)"
        let duration = Double(fields[4]).map { $0 > 3600 ? $0 / 1000 : $0 }
        let position = Double(fields[5]) ?? 0
        let isPlaying = fields[6].lowercased() == "playing"

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

        return NowPlayingState(
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
    }

    private func queryAppleMusicCurrentState() -> NowPlayingState? {
        guard isAppRunning(bundleID: "com.apple.Music") else { return nil }
        let script = """
        tell application "Music"
            if player state is stopped then return ""
            set t to current track
            set storeValue to ""
            try
                set storeValue to address of t
            end try
            set d to {name of t, artist of t, album of t, persistent ID of t, duration of t, player position, player state as string, storeValue, track number of t}
            set AppleScript's text item delimiters to "|||"
            return d as text
        end tell
        """
        guard let fields = runAppleScript(script), fields.count >= 9 else { return nil }

        let title = fields[0].isEmpty ? "Unknown" : fields[0]
        let artist = fields[1]
        let album = fields[2].isEmpty ? nil : fields[2]
        let trackID = fields[3].isEmpty ? "\(title)-\(artist)" : fields[3]
        let duration = Double(fields[4])
        let position = Double(fields[5]) ?? 0
        let isPlaying = fields[6].lowercased() == "playing"
        let storeURL = fields[7].isEmpty ? nil : URL(string: fields[7])
        let trackNumber = Int(fields[8])

        let card = TrackCard(
            id: "apple:dn:\(trackID)",
            provider: .appleMusic,
            title: title,
            artist: artist,
            album: album,
            artworkData: nil,
            artworkURL: nil,
            deepLinkURL: storeURL,
            trackNumber: trackNumber
        )

        return NowPlayingState(
            provider: .appleMusic,
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
            playbackSourceLabel: "APPLE MUSIC",
            previousHistory: []
        )
    }

    private func runAppleScript(_ source: String) -> [String]? {
        var error: NSDictionary?
        guard let result = NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue,
              !result.isEmpty
        else {
            #if DEBUG
            if let error {
                print("🎵 [DN-Prime] AppleScript failed: \(error)")
            }
            #endif
            return nil
        }
        return result.components(separatedBy: "|||")
    }

    private func isAppRunning(bundleID: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
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
