import SwiftUI
import AppKit
import EventKit
import ServiceManagement

/// Permissions information view — displays current system status and which permissions each utility needs.
struct PermissionsInfoView: View {
    @State private var isRequestingCalendarAccess = false
    
    var body: some View {
        Form {
            Section {
                Text("Utility Notch uses system permissions to provide certain features. If a permission is denied, the affected utility will still appear but may have limited functionality.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Current Status") {
                statusRow(
                    title: "Apple Music app",
                    detail: "Used for queue enrichment through Apple Events.",
                    status: appleMusicStatusText,
                    color: appleMusicInstalled ? .green : .orange
                )

                statusRow(
                    title: "System media controls",
                    detail: "MediaRemote framework for now-playing state and playback controls.",
                    status: mediaRemoteAvailable ? "Available" : "Unavailable",
                    color: mediaRemoteAvailable ? .green : .red
                )

                statusRow(
                    title: "Clipboard",
                    detail: "Reads local pasteboard changes while the Clipboard History module is open.",
                    status: "Available",
                    color: .green
                )

                let calendarStatus = calendarPermissionStatus
                statusRow(
                    title: "Calendars",
                    detail: "EventKit access for the Calendar module.",
                    status: calendarStatus.text,
                    color: calendarStatus.color,
                    action: {
                        calendarAccessButton
                    }
                )

                let launchStatus = launchAtLoginStatus
                statusRow(
                    title: "Launch at login",
                    detail: "Managed by macOS Login Items.",
                    status: launchStatus.text,
                    color: launchStatus.color
                )
            }
            
            ForEach(ModuleRegistry.allModules.filter { !$0.requiredPermissions.isEmpty }, id: \.id) { module in
                Section(module.name) {
                    ForEach(module.requiredPermissions) { perm in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.shield")
                                    .foregroundStyle(.orange)
                                Text(perm.name)
                                    .fontWeight(.medium)
                            }
                            
                            Text(perm.reason)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "gear")
                                    .font(.caption2)
                                Text("System Settings → \(perm.systemSettingsPath)")
                                    .font(.caption)
                            }
                            .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            Section("Modules with no extra permissions") {
                ForEach(ModuleRegistry.allModules.filter { $0.requiredPermissions.isEmpty }, id: \.id) { module in
                    HStack(spacing: 8) {
                        Image(systemName: module.icon)
                            .frame(width: 20)
                        Text(module.name)
                        Spacer()
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.green)
                        Text("No permissions needed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var appleMusicInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Music") != nil
    }

    private var appleMusicStatusText: String {
        guard appleMusicInstalled else { return "Not installed" }
        let running = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty
        return running ? "Installed, running" : "Installed"
    }

    private var mediaRemoteAvailable: Bool {
        MediaRemoteFramework.load() != nil
    }

    private var calendarPermissionStatus: (text: String, color: Color) {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .authorized:
            return ("Allowed", .green)
        case .writeOnly:
            return ("Write only", .orange)
        case .notDetermined:
            return ("Not requested", .gray)
        case .denied:
            return ("Denied", .red)
        case .restricted:
            return ("Restricted", .red)
        @unknown default:
            return ("Unknown", .gray)
        }
    }

    private var launchAtLoginStatus: (text: String, color: Color) {
        switch SMAppService.mainApp.status {
        case .enabled:
            return ("Enabled", .green)
        case .requiresApproval:
            return ("Requires approval", .orange)
        case .notRegistered:
            return ("Off", .gray)
        case .notFound:
            return ("Unavailable", .red)
        @unknown default:
            return ("Unknown", .gray)
        }
    }

    @ViewBuilder
    private var calendarAccessButton: some View {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
            Button(isRequestingCalendarAccess ? "Requesting..." : "Allow Access") {
                requestCalendarAccess()
            }
            .disabled(isRequestingCalendarAccess)
        case .denied, .restricted, .writeOnly:
            Button("Open Settings") {
                openCalendarPrivacySettings()
            }
        default:
            EmptyView()
        }
    }

    private func statusRow<Action: View>(
        title: String,
        detail: String,
        status: String,
        color: Color,
        @ViewBuilder action: () -> Action
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(color)
                Text(title)
                    .fontWeight(.medium)
                Spacer()
                Text(status)
                    .font(.caption)
                    .foregroundStyle(color)
                action()
            }

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func statusRow(title: String, detail: String, status: String, color: Color) -> some View {
        statusRow(title: title, detail: detail, status: status, color: color) {
            EmptyView()
        }
    }

    private func requestCalendarAccess() {
        guard !isRequestingCalendarAccess else { return }
        isRequestingCalendarAccess = true
        NSApp.activate(ignoringOtherApps: true)
        Task {
            do {
                if #available(macOS 14.0, *) {
                    _ = try await sharedEventStore.requestFullAccessToEvents()
                } else {
                    _ = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Bool, Error>) in
                        sharedEventStore.requestAccess(to: .event) { granted, error in
                            if let error {
                                cont.resume(throwing: error)
                            } else {
                                cont.resume(returning: granted)
                            }
                        }
                    }
                }
            } catch {
                #if DEBUG
                print("Calendar permission request failed: \(error)")
                #endif
            }
            await MainActor.run {
                isRequestingCalendarAccess = false
            }
        }
    }

    private func openCalendarPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") else { return }
        NSWorkspace.shared.open(url)
    }
}
