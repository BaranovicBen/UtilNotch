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

            // System Media (MediaRemote)
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

            // Apple Music queue enrichment
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

            // Spotify queue enrichment
            SpotifySettingsRow(auth: orchestrator.spotifyAuth)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Spotify row

private struct SpotifySettingsRow: View {
    var auth: SpotifyAuthClient

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: statusIcon)
                    .font(.system(size: 14))
                    .foregroundStyle(statusColor)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Spotify Queue")
                        .font(.system(size: 13))
                    Text(statusDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if SpotifyConfig.clientID.isEmpty {
                    // No client ID configured — button not useful
                } else if auth.isConnected {
                    Button("Disconnect") { auth.disconnect() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                } else {
                    Button(auth.isConnecting ? "Connecting…" : "Connect") {
                        Task { await auth.connect() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(auth.isConnecting)
                }
            }

            if SpotifyConfig.clientID.isEmpty {
                Text("Set SpotifyConfig.clientID in the source code to enable Spotify queue preview. Register your app at developer.spotify.com.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.leading, 28)
            } else if let err = auth.connectionError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.leading, 28)
            }
        }
    }

    private var statusIcon: String {
        if SpotifyConfig.clientID.isEmpty { return "exclamationmark.circle" }
        if auth.isConnected { return "checkmark.circle.fill" }
        if auth.isConnecting { return "arrow.trianglehead.2.clockwise.rotate.90" }
        return "circle"
    }

    private var statusColor: Color {
        if SpotifyConfig.clientID.isEmpty { return .orange }
        if auth.isConnected { return .green }
        return .secondary
    }

    private var statusDetail: String {
        if SpotifyConfig.clientID.isEmpty { return "Client ID not configured" }
        if auth.isConnected { return "Connected — upcoming Spotify tracks visible in queue" }
        if auth.isConnecting { return "Waiting for browser authorization…" }
        if auth.connectionError != nil { return "Connection failed" }
        return "Not connected"
    }
}
