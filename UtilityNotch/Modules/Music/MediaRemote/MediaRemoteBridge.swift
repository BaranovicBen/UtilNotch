import Foundation

// MARK: - Command values (stable since macOS 10.12, verified against TBD symbols)

enum MRCommand: UInt32 {
    case play             = 0
    case pause            = 1
    case togglePlayPause  = 2
    case stop             = 3
    case nextTrack        = 4
    case previousTrack    = 5
    case seekToPosition   = 45
}

/// Options dict key for seekToPosition command.
let kMRMediaRemoteOptionPlaybackPosition = "kMRMediaRemoteOptionPlaybackPosition"

// MARK: - Now Playing info keys

enum MRNowPlayingInfoKey {
    static let title            = "kMRMediaRemoteNowPlayingInfoTitle"
    static let artist           = "kMRMediaRemoteNowPlayingInfoArtist"
    static let album            = "kMRMediaRemoteNowPlayingInfoAlbum"
    static let duration         = "kMRMediaRemoteNowPlayingInfoDuration"
    static let elapsedTime      = "kMRMediaRemoteNowPlayingInfoElapsedTime"
    static let playbackRate     = "kMRMediaRemoteNowPlayingInfoPlaybackRate"
    static let artworkData      = "kMRMediaRemoteNowPlayingInfoArtworkData"
    static let artworkURL       = "kMRMediaRemoteNowPlayingInfoArtworkURL"
    static let uniqueIdentifier = "kMRMediaRemoteNowPlayingInfoUniqueIdentifier"
    static let queueIndex       = "kMRMediaRemoteNowPlayingInfoQueueIndex"
    static let totalQueueCount  = "kMRMediaRemoteNowPlayingInfoTotalQueueCount"
}

// MARK: - Notification names

extension Notification.Name {
    static let mrNowPlayingInfoDidChange        = Notification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification")
    static let mrNowPlayingAppDidChange         = Notification.Name("kMRMediaRemoteNowPlayingApplicationDidChangeNotification")
    static let mrNowPlayingAppIsPlayingDidChange = Notification.Name("kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification")
}

// MARK: - Function typedefs
//
// The MRMR exported symbols are C functions whose callback parameters are ObjC blocks.
// Use @convention(c) for the function pointer itself, @convention(block) for the callbacks.

typealias MRGetNowPlayingInfoFunc =
    @convention(c) (
        DispatchQueue,
        @escaping @convention(block) (NSDictionary?) -> Void
    ) -> Void

typealias MRSendCommandFunc =
    @convention(c) (UInt32, NSDictionary?) -> Bool

typealias MRRegisterForNotificationsFunc =
    @convention(c) (DispatchQueue) -> Void

typealias MRGetAppDisplayIDFunc =
    @convention(c) (
        DispatchQueue,
        @escaping @convention(block) (NSString?) -> Void
    ) -> Void

// MARK: - Framework loader

/// Wraps the four MRMR entry points loaded at runtime via dlopen/dlsym.
/// Returns nil if the private framework is unavailable (unlikely on macOS 14+).
struct MediaRemoteFramework {
    let getNowPlayingInfo: MRGetNowPlayingInfoFunc
    let sendCommand:       MRSendCommandFunc
    let registerForNowPlaying: MRRegisterForNotificationsFunc
    let getAppDisplayID:   MRGetAppDisplayIDFunc

    static func load() -> MediaRemoteFramework? {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        guard let handle = dlopen(path, RTLD_NOW) else { return nil }
        guard
            let rawGetInfo = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo"),
            let rawSend    = dlsym(handle, "MRMediaRemoteSendCommand"),
            let rawReg     = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications"),
            let rawAppID   = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationDisplayID")
        else { return nil }

        return MediaRemoteFramework(
            getNowPlayingInfo:    unsafeBitCast(rawGetInfo, to: MRGetNowPlayingInfoFunc.self),
            sendCommand:          unsafeBitCast(rawSend,    to: MRSendCommandFunc.self),
            registerForNowPlaying: unsafeBitCast(rawReg,    to: MRRegisterForNotificationsFunc.self),
            getAppDisplayID:      unsafeBitCast(rawAppID,   to: MRGetAppDisplayIDFunc.self)
        )
    }
}
