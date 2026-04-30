import Foundation
import AppKit

/// Lightweight launch-time playback probe.
/// Keeps app startup from creating the full music orchestrator unless music is
/// actually active and the Music module is enabled.
@MainActor
enum MusicStartupProbe {
    static func hasActivePlayback() async -> Bool {
        if await isSpotifyStreaming() { return true }
        if isAppleMusicStreaming() { return true }
        return false
    }

    private static func isSpotifyStreaming() async -> Bool {
        let auth = SpotifyAuthClient()
        auth.loadStoredTokens()
        guard auth.isConnected else { return false }

        do {
            let token = try await auth.validToken()
            return try await SpotifyWebAPIClient()
                .fetchCurrentPlayer(token: token)?
                .isPlaying == true
        } catch {
            return false
        }
    }

    private static func isAppleMusicStreaming() -> Bool {
        guard isAppRunning(bundleID: "com.apple.Music") else { return false }
        let script = """
        tell application "Music"
            return player state as string
        end tell
        """
        return runAppleScript(script)?.lowercased() == "playing"
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
