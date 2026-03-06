import SwiftUI

/// Music Control utility module — mock now-playing UI with playback controls.
/// Replace with real MRMediaRemote / MediaPlayer integration in production.
struct MusicControlModule: UtilityModule {
    let id = "musicControl"
    let name = "Music Control"
    let icon = "music.note"
    var isEnabled = true
    let supportsNotifications = true
    
    var requiredPermissions: [PermissionInfo] {
        [PermissionInfo(
            id: "mediaAccess",
            name: "Media & Apple Music",
            reason: "Needed to control playback and display now-playing info.",
            systemSettingsPath: "Privacy & Security → Media & Apple Music"
        )]
    }
    
    func makeMainView() -> AnyView {
        AnyView(MusicControlView())
    }
    
    func makeSettingsView() -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text("Music Control Settings")
                    .font(.headline)
                Text("Display preferences, preferred music app, and notification behavior will be configurable in production.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        )
    }
}
