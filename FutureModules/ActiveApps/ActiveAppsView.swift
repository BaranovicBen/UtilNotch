import SwiftUI
import AppKit

// MARK: - Model

/// Represents a running user-facing application.
struct RunningApp: Identifiable {
    let id: pid_t          // PID as stable identity
    let name: String
    let icon: NSImage
    let bundleIdentifier: String
    let pid: pid_t
}

// MARK: - Main View

/// Lists running user-facing apps; each row shows icon + name with a hover force-quit button.
struct ActiveAppsView: View {
    @Environment(AppState.self) private var appState
    @State private var apps: [RunningApp] = []
    @State private var refreshTimer: Timer?
    @State private var confirmingQuit: pid_t? = nil   // PID awaiting second-hover confirm

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Active Apps", systemImage: "app.badge")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(apps.count) running")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 10)

            if apps.isEmpty {
                Spacer()
                Text("No apps running")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 2) {
                        ForEach(apps) { app in
                            AppRow(
                                app: app,
                                onForceQuit: { forceQuit(app) }
                            )
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            refreshApps()
            startPolling()
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }

    // MARK: - Data

    private func refreshApps() {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.utilitynotch"
        let raw = NSWorkspace.shared.runningApplications.filter { app in
            guard app.activationPolicy == .regular else { return false }  // user-facing only
            guard app.bundleIdentifier != bundleID else { return false }  // exclude self
            return true
        }
        apps = raw.map { app in
            RunningApp(
                id: app.processIdentifier,
                name: app.localizedName ?? "Unknown",
                icon: app.icon ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage(),
                bundleIdentifier: app.bundleIdentifier ?? "",
                pid: app.processIdentifier
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func startPolling() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            Task { @MainActor in refreshApps() }
        }
    }

    private func forceQuit(_ app: RunningApp) {
        guard let running = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == app.pid }) else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            _ = running.forceTerminate()
        }
        // Refresh after a brief delay so the list updates
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { refreshApps() }
    }
}

// MARK: - App Row

private struct AppRow: View {
    let app: RunningApp
    let onForceQuit: () -> Void

    @State private var isHovering = false
    @State private var confirmHover = false  // second hover reveals "Confirm" label

    var body: some View {
        HStack(spacing: 10) {
            // App icon
            Image(nsImage: app.icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            // App name
            Text(app.name)
                .font(.callout)
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            // Force-quit button — visible on hover only
            if isHovering {
                Button(action: onForceQuit) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                        Text("Force Quit")
                            .font(.caption2.weight(.medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.red.opacity(confirmHover ? 0.35 : 0.18))
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.red.opacity(0.4), lineWidth: 0.5)
                            )
                    )
                    .foregroundStyle(Color.red.opacity(confirmHover ? 1.0 : 0.75))
                }
                .buttonStyle(.plain)
                .onHover { confirmHover = $0 }
                .help("Force Quit \(app.name)")
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.85, anchor: .trailing).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(isHovering ? 0.05 : 0))
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
                if !hovering { confirmHover = false }
            }
        }
    }
}

// MARK: - Settings View

struct ActiveAppsSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Apps Settings")
                .font(.headline)
            Text("No settings available for this module yet.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }
}
