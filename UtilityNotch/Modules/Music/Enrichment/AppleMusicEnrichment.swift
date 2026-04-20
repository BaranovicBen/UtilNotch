import Foundation
import AppKit

/// Enriches the now-playing queue for Music.app using NSAppleScript.
/// Reads the next 5 tracks from the currently-playing playlist so the carousel
/// can show upcoming titles/artists even when MRMediaRemote does not expose them.
///
/// Only called when MediaRemoteProvider identifies `com.apple.Music` as the
/// active player — everything else (playback state, artwork) still comes from MRMR.
final class AppleMusicEnrichment: MusicEnrichmentProvider {

    private static let bundleID = "com.apple.Music"

    // MARK: - MusicEnrichmentProvider

    func canEnrich(bundleID: String) -> Bool {
        bundleID == Self.bundleID
    }

    func enrichQueue() async -> [TrackCard] {
        guard isRunning else { return [] }
        guard let raw = await runScript(queueScript), !raw.isEmpty else { return [] }

        // Rows: char(30) — Record Separator.  Fields: char(31) — Unit Separator.
        // Format per row: title \u001F artist \u001F album \u001F databaseID
        let rows = raw.components(separatedBy: "\u{001E}").filter { !$0.isEmpty }
        return rows.compactMap { parseRow($0) }
    }

    // MARK: - Private helpers

    private var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).isEmpty
    }

    private func parseRow(_ row: String) -> TrackCard? {
        let parts = row.components(separatedBy: "\u{001F}")
        guard parts.count >= 4 else { return nil }
        let title  = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let artist = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let album  = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)
        let dbID   = parts[3].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        return TrackCard(
            id: "apple:queue:\(dbID)",
            provider: .appleMusic,
            title: title,
            artist: artist,
            album: album.isEmpty ? nil : album,
            artworkData: nil,
            artworkURL: nil,
            deepLinkURL: nil
        )
    }

    /// AppleScript that returns the next ≤5 tracks in the current playlist.
    /// Uses U+001F (unit separator) between fields and U+001E (record separator) between rows.
    private var queueScript: String {
        // Note: AppleScript character ids: 31 = unit separator, 30 = record separator
        """
        if application "Music" is not running then return ""
        tell application "Music"
            if player state is stopped then return ""
            set sep to character id 31
            set rowSep to character id 30
            set cID to database ID of current track
            set plist to current playlist
            set allTracks to tracks of plist
            set found to false
            set result to ""
            set n to 0
            repeat with t in allTracks
                if found and n < 5 then
                    set albumStr to ""
                    try
                        set albumStr to album of t
                    end try
                    set result to result & (name of t) & sep & (artist of t) & sep & albumStr & sep & (database ID of t as string) & rowSep
                    set n to n + 1
                end if
                if (database ID of t) is cID then set found to true
            end repeat
            return result
        end tell
        """
    }

    @discardableResult
    private func runScript(_ source: String) async -> String? {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let script = NSAppleScript(source: source)
                var err: NSDictionary?
                let result = script?.executeAndReturnError(&err)
                cont.resume(returning: result?.stringValue)
            }
        }
    }
}
