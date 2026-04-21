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
        let trackID  = (info["Track ID"] as? String) ?? "\(title)-\(artist)"
        // "Playing" is delivered as NSNumber (1/0) or Bool depending on macOS version
        let isPlaying: Bool = {
            if let b = info["Playing"] as? Bool { return b }
            if let n = info["Playing"] as? NSNumber { return n.boolValue }
            return false
        }()
        let position: Double = {
            if let d = info["Position"] as? Double { return d }
            if let n = info["Position"] as? NSNumber { return n.doubleValue }
            return 0
        }()
        // Duration is sometimes present in ms, sometimes in seconds depending on version.
        // Heuristic: values > 3600 are in ms (no track is > 1 hr in Spotify usually).
        let rawDuration: Double? = {
            if let d = info["Duration"] as? Double { return d }
            if let n = info["Duration"] as? NSNumber { return n.doubleValue }
            return nil
        }()
        let duration: Double? = rawDuration.map { $0 > 3600 ? $0 / 1000 : $0 }

        #if DEBUG
        print("🎵 [DN-Spotify] \"\(title)\" – \(artist) playing=\(isPlaying) pos=\(String(format: "%.1f", position))s")
        #endif

        let card = TrackCard(
            id: "spotify:dn:\(trackID)",
            provider: .spotify,
            title: title,
            artist: artist,
            album: album,
            artworkData: nil,
            artworkURL: nil,
            deepLinkURL: URL(string: trackID)
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
            playbackSourceLabel: "SPOTIFY"
        )
        onNowPlayingChanged?()
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
        let isPlaying = playerState == "Playing"
        // "Total Time" is in milliseconds
        let totalTimeMs: Double? = {
            if let d = info["Total Time"] as? Double { return d }
            if let n = info["Total Time"] as? NSNumber { return n.doubleValue }
            return nil
        }()
        let duration = totalTimeMs.map { $0 / 1000 }
        let storeURL = (info["Store URL"] as? String).flatMap { URL(string: $0) }
        // Artwork may be present as NSData
        let artData  = info["Artwork"] as? Data

        #if DEBUG
        print("🎵 [DN-AppleMusic] \"\(title)\" – \(artist) state=\(playerState)")
        #endif

        let card = TrackCard(
            id: "apple:dn:\(title)-\(artist)",
            provider: .appleMusic,
            title: title,
            artist: artist,
            album: album,
            artworkData: artData,
            artworkURL: nil,
            deepLinkURL: storeURL
        )

        latestState = NowPlayingState(
            provider: .appleMusic,
            isAvailable: true,
            isPlaying: isPlaying,
            progressSeconds: nil,   // Apple Music DN doesn't include elapsed position
            durationSeconds: duration,
            playbackRate: isPlaying ? 1.0 : 0,
            refreshedAt: Date(),
            current: card,
            previous: nil,
            next: nil,
            upNext: [],
            playbackSourceLabel: "APPLE MUSIC"
        )
        onNowPlayingChanged?()
    }
}
