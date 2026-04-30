import Foundation
import AppKit

/// Lightweight launch-time playback probe.
/// Keeps app startup from creating the full music orchestrator unless music is
/// actually active and the Music module is enabled.
@MainActor
enum MusicStartupProbe {
    static func activePlaybackState() async -> NowPlayingState? {
        if let spotifyState = await spotifyPlaybackState() { return spotifyState }
        if let appleMusicState = appleMusicPlaybackState() { return appleMusicState }
        return nil
    }

    private static func spotifyPlaybackState() async -> NowPlayingState? {
        let auth = SpotifyAuthClient()
        auth.loadStoredTokens()
        guard auth.isConnected else { return nil }

        do {
            let token = try await auth.validToken()
            guard let player = try await SpotifyWebAPIClient().fetchCurrentPlayer(token: token),
                  player.isPlaying
            else { return nil }

            let card = TrackCard(
                id: player.trackID.map { "spotify:\($0)" } ?? "spotify:\(player.title)-\(player.artist)",
                provider: .spotify,
                title: player.title,
                artist: player.artist,
                album: player.album,
                artworkData: nil,
                artworkURL: player.artworkURL,
                deepLinkURL: player.deepLinkURL,
                trackNumber: nil
            )

            return NowPlayingState(
                provider: .spotify,
                isAvailable: true,
                isPlaying: true,
                progressSeconds: Double(player.progressMs) / 1000,
                durationSeconds: player.durationMs.map { Double($0) / 1000 },
                playbackRate: 1,
                refreshedAt: Date(),
                current: card,
                previous: nil,
                next: nil,
                upNext: [],
                playbackSourceLabel: "SPOTIFY",
                previousHistory: []
            )
        } catch {
            return nil
        }
    }

    private static func appleMusicPlaybackState() -> NowPlayingState? {
        guard isAppRunning(bundleID: "com.apple.Music") else { return nil }
        let script = """
        tell application "Music"
            if player state is not playing then return ""
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
        guard let raw = runAppleScript(script), !raw.isEmpty else { return nil }
        let fields = raw.components(separatedBy: "|||")
        guard fields.count >= 9 else { return nil }

        let title = fields[0].isEmpty ? "Unknown" : fields[0]
        let artist = fields[1]
        let album = fields[2].isEmpty ? nil : fields[2]
        let trackID = fields[3].isEmpty ? "\(title)-\(artist)" : fields[3]
        let duration = Double(fields[4])
        let position = Double(fields[5]) ?? 0
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
            isPlaying: true,
            progressSeconds: position,
            durationSeconds: duration,
            playbackRate: 1,
            refreshedAt: Date(),
            current: card,
            previous: nil,
            next: nil,
            upNext: [],
            playbackSourceLabel: "APPLE MUSIC",
            previousHistory: []
        )
    }

    private static func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        #if DEBUG
        if let error {
            print("🎵 [StartupProbe] AppleScript failed: \(error)")
        }
        #endif
        return result?.stringValue
    }

    private static func isAppRunning(bundleID: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }
}
