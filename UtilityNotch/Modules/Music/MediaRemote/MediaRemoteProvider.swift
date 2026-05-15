import AppKit

/// Universal MusicProvider backed by Apple's private MediaRemote framework.
/// Works with any media app — Apple Music, Spotify, Podcasts, YouTube Music, etc.
/// No special entitlements required.
@MainActor
final class MediaRemoteProvider: MusicProvider {

    static let shared = MediaRemoteProvider()
    private init() { self.framework = MediaRemoteFramework.load() }

    // MARK: - MusicProvider

    var kind: MusicProviderKind {
        switch activeAppBundleID {
        case "com.apple.Music":    return .appleMusic
        case "com.spotify.client": return .spotify
        default:                   return .unknown
        }
    }

    let capabilities: MusicCapabilities = .full

    // MARK: - Internal state

    var isAvailable: Bool { framework != nil }
    private(set) var activeAppBundleID: String?

    /// Called by orchestrator when any MRMR notification fires.
    var onNowPlayingChanged: (() -> Void)?

    private let framework: MediaRemoteFramework?
    private var isRegistered = false
    private var observers: [NSObjectProtocol] = []

    /// Cached previous card — populated when MRMR reports a new track ID.
    private var lastSeenTrackID: String?
    private var lastSeenCard: TrackCard?
    private var cachedPrevious: TrackCard?

    // MARK: - Connect / disconnect

    func connect() async {
        guard !isRegistered else {
            debugLog("connect.skipped", fields: ["reason": "alreadyRegistered"])
            return
        }
        guard let fw = framework else {
            #if DEBUG
            print("🎵 [MR] framework unavailable — dlopen/dlsym failed")
            #endif
            debugLog("connect.failed", fields: ["reason": "frameworkUnavailable"])
            return
        }
        debugLog("connect.begin")
        fw.registerForNowPlaying(.main)
        isRegistered = true
        #if DEBUG
        print("🎵 [MR] registered for now-playing notifications — waiting 400ms for XPC handshake")
        #endif
        // Give mediaremoted time to complete the XPC registration before we fire the first query
        try? await Task.sleep(for: .milliseconds(400))
        subscribeToNotifications()
        debugLog("connect.end", fields: ["observerCount": "\(observers.count)"])
    }

    func disconnect() async {
        debugLog("disconnect", fields: ["observerCount": "\(observers.count)"])
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        isRegistered = false
    }

    // MARK: - Status

    func refreshStatus() async -> MusicProviderStatus {
        debugLog("refreshStatus", fields: [
            "frameworkAvailable": "\(framework != nil)",
            "activeAppBundleID": activeAppBundleID ?? "nil"
        ])
        return MusicProviderStatus(
            isAuthorized: framework != nil,
            isInstalled: true,
            hasActiveSession: activeAppBundleID != nil,
            displayName: "System Media",
            detail: framework == nil ? "MediaRemote unavailable" : nil
        )
    }

    // MARK: - Now Playing

    func refreshNowPlaying() async -> NowPlayingState {
        guard let fw = framework else {
            #if DEBUG
            print("🎵 [MR] refreshNowPlaying: no framework")
            #endif
            debugLog("refreshNowPlaying.unavailable", fields: ["reason": "frameworkUnavailable"])
            return .unavailable(for: kind)
        }
        debugLog("refreshNowPlaying.begin")

        // getAppDisplayID can return nil even when music IS playing (known MRMR quirk).
        // We store it if present, but never bail out early because of it.
        let bundleID: String? = await withCheckedContinuation { cont in
            fw.getAppDisplayID(.main) { id in
                cont.resume(returning: id as String?)
            }
        }
        activeAppBundleID = bundleID
        #if DEBUG
        print("🎵 [MR] getAppDisplayID → \(bundleID ?? "<nil>")")
        #endif
        debugLog("refreshNowPlaying.appDisplayID", fields: ["bundleID": bundleID ?? "nil"])

        let dict: NSDictionary? = await withCheckedContinuation { cont in
            fw.getNowPlayingInfo(.main) { d in
                cont.resume(returning: d)
            }
        }
        #if DEBUG
        let keys = (dict?.allKeys as? [String])?.sorted() ?? []
        print("🎵 [MR] getNowPlayingInfo → \(dict == nil ? "nil" : "\(dict!.count) keys: \(keys)")")
        #endif
        debugLog("refreshNowPlaying.info", fields: [
            "isNil": "\(dict == nil)",
            "keyCount": "\(dict?.count ?? 0)"
        ])
        guard let info = dict, info.count > 0 else {
            debugLog("refreshNowPlaying.unavailable", fields: ["reason": "emptyInfo"])
            return .unavailable(for: kind)
        }

        let capturedAt = Date()
        let title    = info[MRNowPlayingInfoKey.title]    as? String ?? "Unknown"
        let artist   = info[MRNowPlayingInfoKey.artist]   as? String ?? ""
        let album    = info[MRNowPlayingInfoKey.album]    as? String
        let duration = (info[MRNowPlayingInfoKey.duration]    as? NSNumber)?.doubleValue
        let elapsed  = (info[MRNowPlayingInfoKey.elapsedTime] as? NSNumber)?.doubleValue ?? 0
        let rate     = (info[MRNowPlayingInfoKey.playbackRate] as? NSNumber)?.doubleValue ?? 0
        let trackUID = (info[MRNowPlayingInfoKey.uniqueIdentifier] as? NSNumber)
                        .map { "\($0)" } ?? "\(title)-\(artist)"
        let artData  = info[MRNowPlayingInfoKey.artworkData] as? Data
        let artURL   = info[MRNowPlayingInfoKey.artworkURL]  as? URL
        #if DEBUG
        print("🎵 [MR] now playing: \"\(title)\" – \(artist) | rate=\(rate) elapsed=\(elapsed)s")
        #endif
        debugLog("refreshNowPlaying.current", fields: [
            "trackUID": trackUID,
            "title": title,
            "artist": artist,
            "rate": "\(rate)",
            "elapsed": String(format: "%.2f", elapsed),
            "hasArtworkData": "\(artData != nil)",
            "hasArtworkURL": "\(artURL != nil)"
        ])

        let current = TrackCard(
            id: "mrmr:\(trackUID)",
            provider: kind,
            title: title,
            artist: artist,
            album: album,
            artworkData: artData,
            artworkURL: artURL,
            deepLinkURL: nil,
            trackNumber: nil
        )

        if trackUID != lastSeenTrackID {
            cachedPrevious = lastSeenCard
            debugLog("refreshNowPlaying.trackChanged", fields: [
                "from": lastSeenTrackID ?? "nil",
                "to": trackUID,
                "cachedPreviousID": cachedPrevious?.id ?? "nil"
            ])
            lastSeenTrackID = trackUID
        }
        lastSeenCard = current

        let sourceLabel: String? = {
            switch activeAppBundleID {
            case "com.apple.Music":    return "APPLE MUSIC"
            case "com.spotify.client": return "SPOTIFY"
            default:
                if let id = activeAppBundleID,
                   let app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first {
                    return app.localizedName?.uppercased()
                }
                return nil
            }
        }()

        return NowPlayingState(
            provider: kind,
            isAvailable: true,
            isPlaying: rate > 0,
            progressSeconds: elapsed,
            durationSeconds: duration,
            playbackRate: rate > 0 ? rate : 0,
            refreshedAt: capturedAt,
            current: current,
            previous: cachedPrevious,
            next: nil,
            upNext: [],
            playbackSourceLabel: sourceLabel,
            previousHistory: []
        )
    }

    // MARK: - Playback commands

    func playPause() async {
        let sent = framework?.sendCommand(MRCommand.togglePlayPause.rawValue, nil) ?? false
        debugLog("command.playPause", fields: ["sent": "\(sent)"])
    }

    func next() async {
        let sent = framework?.sendCommand(MRCommand.nextTrack.rawValue, nil) ?? false
        debugLog("command.next", fields: ["sent": "\(sent)"])
    }

    func previous() async {
        let sent = framework?.sendCommand(MRCommand.previousTrack.rawValue, nil) ?? false
        debugLog("command.previous", fields: ["sent": "\(sent)"])
    }

    func seek(to seconds: Double) async {
        let sent = framework?.sendCommand(
            MRCommand.seekToPosition.rawValue,
            [kMRMediaRemoteOptionPlaybackPosition: seconds] as NSDictionary
        ) ?? false
        debugLog("command.seek", fields: ["sent": "\(sent)", "seconds": String(format: "%.2f", seconds)])
    }

    func openNativeApp() {
        guard let bundleID = activeAppBundleID else {
            debugLog("openNativeApp.skipped", fields: ["reason": "missingBundleID"])
            return
        }
        debugLog("openNativeApp", fields: ["bundleID": bundleID])
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let cfg = NSWorkspace.OpenConfiguration()
            cfg.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: cfg)
        }
    }

    // MARK: - Notifications

    private func subscribeToNotifications() {
        let names: [Notification.Name] = [
            .mrNowPlayingInfoDidChange,
            .mrNowPlayingAppDidChange,
            .mrNowPlayingAppIsPlayingDidChange
        ]
        for name in names {
            let obs = NotificationCenter.default.addObserver(
                forName: name, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.debugLog("notification", fields: ["name": name.rawValue])
                    self?.onNowPlayingChanged?()
                }
            }
            observers.append(obs)
        }
    }

    private func debugLog(_ event: String, fields: [String: String] = [:]) {
        #if DEBUG
        let body = fields
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        print("🎵 [Music][MR] event=\(event)\(body.isEmpty ? "" : " \(body)")")
        #endif
    }
}
