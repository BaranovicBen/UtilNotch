import SwiftUI
import AppKit

/// Active Apps module — full-shell Figma implementation, wired to NSWorkspace.
/// Polls running apps every 3 seconds; falls back to 6 dummy rows when list is empty.
/// CSS source: /DesignReference/Css/ActiveApps.css
struct ActiveAppsModuleView: View {
    @Environment(AppState.self) private var appState

    // MARK: - Real app data from NSWorkspace

    struct RunningEntry: Identifiable {
        let id: pid_t
        let name: String
        let category: String
        let color: Color
        let memory: String
        let pid: pid_t
        let icon: NSImage?
    }

    @State private var runningApps: [RunningEntry] = []
    @State private var refreshTimer: Timer? = nil

    // MARK: - Dummy fallback (6 rows, shown when NSWorkspace returns empty)

    private let dummyApps: [(name: String, category: String, color: Color, memory: String)] = [
        ("Xcode",          "Developer Tools", Color(hex: "0A84FF"), "1.2 GB"),
        ("Figma",          "Design Tools",    Color(hex: "A259FF"), "487 MB"),
        ("Safari",         "Web Browser",     Color(hex: "0A84FF"), "312 MB"),
        ("Simulator",      "Developer Tools", Color(hex: "FF9F0A"), "891 MB"),
        ("Terminal",       "Developer Tools", Color(hex: "30D158"), "48 MB"),
        ("Utility Notch",  "Utilities",       Color(hex: "636366"), "22 MB"),
    ]

    private var isUsingDummy: Bool { runningApps.isEmpty }

    var body: some View {
        ModuleShellView(
            moduleTitle: "Active Apps",
            moduleIcon: "square.grid.2x2",
            modules: shellNavItems(appState: appState),
            activeModuleID: appState.activeModuleID,
            onModuleSelect: { id in
                withAnimation(.spring(duration: 0.28, bounce: 0.16)) {
                    appState.selectModule(id)
                }
            },
            statusDotColor: Color(hex: "32D74B"),
            statusLeft: isUsingDummy ? "8 APPS RUNNING" : "\(runningApps.count) APPS RUNNING",
            statusRight: "CLICK QUIT TO FORCE QUIT",
            actionButton: nil
        ) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {
                    if isUsingDummy {
                        ForEach(dummyApps, id: \.name) { app in
                            dummyAppRow(app)
                        }
                    } else {
                        ForEach(runningApps) { app in
                            liveAppRow(app)
                        }
                    }
                }
            }
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

    // MARK: - Dummy App Row (non-interactive, visual demo)
    // CSS: padding 10px 12px, height 56px, bg rgba(255,255,255,0.03), radius 8px

    @ViewBuilder
    private func dummyAppRow(_ app: (name: String, category: String, color: Color, memory: String)) -> some View {
        HStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 28, height: 28)
                Image(systemName: "app.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            .padding(.trailing, 12)

            VStack(alignment: .leading, spacing: 0) {
                Text(app.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(1)
                Text(app.category.uppercased())
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .kerning(0.5)
                    .lineLimit(1)
            }

            Spacer()

            Text(app.memory)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.7))
                .padding(.trailing, 16)

            Text("QUIT")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(hex: "FF453A"))
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
                .background(Capsule().fill(Color(hex: "FF453A").opacity(0.1)))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .opacity(0.5)
    }

    // MARK: - Live App Row (wired QUIT button)

    @ViewBuilder
    private func liveAppRow(_ app: RunningEntry) -> some View {
        LiveAppRowView(app: app) {
            forceQuit(app)
        }
    }

    // MARK: - NSWorkspace

    private func refreshApps() {
        let selfBundleID = Bundle.main.bundleIdentifier ?? "com.utilitynotch"
        let raw = NSWorkspace.shared.runningApplications.filter { app in
            guard app.activationPolicy == .regular else { return false }
            guard app.bundleIdentifier != selfBundleID else { return false }
            return true
        }
        let entries = raw.map { app -> RunningEntry in
            let iconImg: NSImage? = {
                if let url = app.bundleURL {
                    let img = NSWorkspace.shared.icon(forFile: url.path)
                    img.size = NSSize(width: 28, height: 28)
                    return img
                }
                return nil
            }()
            return RunningEntry(
                id: app.processIdentifier,
                name: app.localizedName ?? "Unknown",
                category: categoryForApp(app),
                color: colorForApp(app),
                memory: "— MB",
                pid: app.processIdentifier,
                icon: iconImg
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        withAnimation(.easeOut(duration: 0.2)) { runningApps = entries }
    }

    private func startPolling() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            Task { @MainActor in refreshApps() }
        }
    }

    private func forceQuit(_ app: RunningEntry) {
        guard let running = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == app.pid })
        else { return }
        _ = running.forceTerminate()
        // Optimistic remove — next poll will also clean up
        withAnimation(.easeOut(duration: 0.2)) {
            runningApps.removeAll { $0.pid == app.pid }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { refreshApps() }
    }

    // MARK: - Category / Color helpers

    private func categoryForApp(_ app: NSRunningApplication) -> String {
        let id = app.bundleIdentifier?.lowercased() ?? ""
        if id.contains("xcode") || id.contains("terminal") || id.contains("instruments") { return "Developer Tools" }
        if id.contains("figma") || id.contains("sketch") || id.contains("pixelmator") { return "Design Tools" }
        if id.contains("safari") || id.contains("chrome") || id.contains("firefox") { return "Web Browser" }
        if id.contains("simulator") { return "Developer Tools" }
        return "Utilities"
    }

    private func colorForApp(_ app: NSRunningApplication) -> Color {
        let id = app.bundleIdentifier?.lowercased() ?? ""
        if id.contains("xcode") || id.contains("safari") { return Color(hex: "0A84FF") }
        if id.contains("figma") { return Color(hex: "A259FF") }
        if id.contains("simulator") { return Color(hex: "FF9F0A") }
        if id.contains("terminal") { return Color(hex: "30D158") }
        return Color(hex: "636366")
    }
}

// MARK: - Live App Row View

private struct LiveAppRowView: View {
    let app: ActiveAppsModuleView.RunningEntry
    let onQuit: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 0) {
            // App icon — real NSWorkspace icon, fallback to grey rect
            Group {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 28, height: 28)
                }
            }
            .padding(.trailing, 12)

            VStack(alignment: .leading, spacing: 0) {
                Text(app.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(1)
                Text(app.category.uppercased())
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .kerning(0.5)
                    .lineLimit(1)
            }

            Spacer()

            // QUIT button — wired to forceTerminate
            Button(action: onQuit) {
                Text("QUIT")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(hex: "FF453A"))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(
                        Capsule()
                            .fill(Color(hex: "FF453A").opacity(isHovering ? 0.2 : 0.1))
                    )
            }
            .buttonStyle(.plain)
            .onHover { h in withAnimation(.easeOut(duration: 0.12)) { isHovering = h } }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
    }
}
