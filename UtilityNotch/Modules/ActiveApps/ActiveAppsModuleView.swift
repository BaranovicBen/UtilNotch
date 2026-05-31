import AppKit
import SwiftUI

/// Active Apps is intentionally switch-only in v1: no force quit or destructive controls.
struct ActiveAppsModuleView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    struct RunningEntry: Identifiable {
        let id: pid_t
        let name: String
        let bundleIdentifier: String
        let isFrontmost: Bool
        let icon: NSImage?
        let app: NSRunningApplication
    }

    @State private var runningApps: [RunningEntry] = []
    @State private var refreshTimer: Timer?

    private var frontmostName: String {
        runningApps.first(where: \.isFrontmost)?.name ?? "local"
    }

    var body: some View {
        ModuleShellView(
            moduleTitle: "Active Apps",
            moduleIcon: "app.badge",
            modules: shellNavItems(appState: appState),
            activeModuleID: appState.activeModuleID,
            onModuleSelect: { id in
                withAnimation(reduceMotion ? UNMotion.reduced : UNMotion.moduleSwitch) {
                    appState.selectModule(id)
                }
            },
            statusDotColor: runningApps.isEmpty ? Color.white.opacity(0.2) : UNConstants.successGreen,
            statusLeft: "\(runningApps.count) APPS",
            statusRight: frontmostName.uppercased(),
            actionButton: nil
        ) {
            Group {
                if runningApps.isEmpty {
                    emptyState
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 7) {
                            ForEach(runningApps) { app in
                                ActiveAppRow(entry: app) {
                                    activate(app)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            refreshApps()
            startPolling()
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "app.badge")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(UNConstants.textTertiary)
            Text("No switchable apps")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(UNConstants.textPrimary)
            Text("Running applications will appear here for local focus switching.")
                .font(.system(size: 12))
                .foregroundStyle(UNConstants.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 36)
    }

    @MainActor
    private func refreshApps() {
        let selfBundleID = Bundle.main.bundleIdentifier
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let apps = NSWorkspace.shared.runningApplications
            .filter { app in
                app.activationPolicy == .regular &&
                app.localizedName?.isEmpty == false &&
                app.bundleIdentifier != selfBundleID
            }
            .map { app in
                RunningEntry(
                    id: app.processIdentifier,
                    name: app.localizedName ?? "Unknown",
                    bundleIdentifier: app.bundleIdentifier ?? "local.app",
                    isFrontmost: app.processIdentifier == frontmostPID,
                    icon: app.icon,
                    app: app
                )
            }
            .sorted {
                if $0.isFrontmost != $1.isFrontmost { return $0.isFrontmost }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

        withAnimation(reduceMotion ? UNMotion.reduced : UNMotion.listItem) {
            runningApps = Array(apps.prefix(24))
        }
    }

    @MainActor
    private func activate(_ entry: RunningEntry) {
        entry.app.activate(options: [.activateAllWindows])
        refreshApps()
    }

    private func startPolling() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            Task { @MainActor in refreshApps() }
        }
    }
}

private struct ActiveAppRow: View {
    let entry: ActiveAppsModuleView.RunningEntry
    let onActivate: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        Button(action: onActivate) {
            HStack(spacing: 11) {
                Group {
                    if let icon = entry.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 30, height: 30)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(UNConstants.insetSurface)
                            .frame(width: 30, height: 30)
                            .overlay {
                                Image(systemName: "app")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(UNConstants.textSecondary)
                            }
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(UNConstants.textPrimary)
                        .lineLimit(1)
                    Text(entry.bundleIdentifier)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(UNConstants.textTertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if entry.isFrontmost {
                    Text("ACTIVE")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(UNConstants.successGreen)
                } else {
                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(UNConstants.textTertiary)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: UNConstants.rowCornerRadius, style: .continuous)
                    .fill(entry.isFrontmost ? UNConstants.selectedSurface : (isHovering ? UNConstants.rowHoverSurface : UNConstants.rowSurface))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(reduceMotion ? UNMotion.reduced : UNMotion.hover) {
                isHovering = hovering
            }
        }
    }
}
