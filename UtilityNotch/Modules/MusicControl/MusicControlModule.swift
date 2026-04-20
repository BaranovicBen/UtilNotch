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
        AnyView(MusicSettingsView())
    }
}

// MARK: - Settings view

private struct MusicSettingsView: View {
    @Environment(\.musicOrchestrator) private var orchestrator

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Music Sources")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            HStack(spacing: 10) {
                Image(systemName: orchestrator.isMediaRemoteAvailable ? "checkmark.circle.fill" : "xmark.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(orchestrator.isMediaRemoteAvailable ? Color.green : Color.secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text("System Media Control")
                        .font(.system(size: 13))
                    Text(orchestrator.isMediaRemoteAvailable
                         ? (orchestrator.activeProviderKind.map { "Active: \($0.displayName)" } ?? "No media playing")
                         : "MediaRemote unavailable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !orchestrator.isMediaRemoteAvailable {
                    Button("Retry") {
                        Task { await orchestrator.connectProvider(.appleMusic) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.green)
                        .frame(width: 20)
                    Text("Apple Music Queue")
                        .font(.system(size: 13))
                }
                Text("Upcoming tracks are read from your current playlist when Music.app is playing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 28)
            }

            Divider()

            Text("Spotify queue enrichment coming in a future update.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
