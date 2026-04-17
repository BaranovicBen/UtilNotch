import SwiftUI

/// Music Control utility module.
/// The orchestrator (`MusicOrchestrator.shared`) is injected via the default
/// `\.musicOrchestrator` environment key — no manual injection needed here.
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
        AnyView(MusicModuleView())
    }

    func makeSettingsView() -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text("Music Control Settings")
                    .font(.headline)
                Text("Display preferences, preferred music app (Mock / Spotify / Apple Music), and notification behavior will be configurable once a provider is integrated.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                // TODO: Music provider selection — wire when provider is implemented.
            }
            .padding()
        )
    }
}
