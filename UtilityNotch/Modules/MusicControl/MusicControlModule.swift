import SwiftUI

/// Music Control utility module — stub (fleshed out in Segment 6)
struct MusicControlModule: UtilityModule {
    let id = "musicControl"
    let name = "Music Control"
    let icon = "music.note"
    var isEnabled = true
    
    var requiredPermissions: [PermissionInfo] {
        [PermissionInfo(
            id: "mediaAccess",
            name: "Media & Apple Music",
            reason: "Needed to control playback and display now-playing info.",
            systemSettingsPath: "Privacy & Security → Media & Apple Music"
        )]
    }
    
    func makeMainView() -> AnyView {
        AnyView(Text("Music Control — coming soon").foregroundStyle(.secondary))
    }
}
