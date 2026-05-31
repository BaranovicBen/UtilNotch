import AppKit
import SwiftUI

struct DownloadsModuleView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    struct DownloadEntry: Identifiable {
        let id: URL
        let url: URL
        let name: String
        let size: Int64?
        let modifiedAt: Date?
        let isActive: Bool
    }

    @State private var downloads: [DownloadEntry] = []
    @State private var refreshTimer: Timer?

    private var activeDownloads: [DownloadEntry] {
        downloads.filter(\.isActive)
    }

    var body: some View {
        ModuleShellView(
            moduleTitle: "Downloads",
            moduleIcon: "arrow.down.circle",
            modules: shellNavItems(appState: appState),
            activeModuleID: appState.activeModuleID,
            onModuleSelect: { id in
                withAnimation(reduceMotion ? UNMotion.reduced : UNMotion.moduleSwitch) {
                    appState.selectModule(id)
                }
            },
            statusDotColor: activeDownloads.isEmpty ? Color.white.opacity(0.2) : UNConstants.successGreen,
            statusLeft: activeDownloads.isEmpty ? "\(downloads.count) RECENT" : "\(activeDownloads.count) ACTIVE",
            statusRight: "LOCAL FOLDER",
            actionButton: nil
        ) {
            Group {
                if downloads.isEmpty {
                    emptyState
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 7) {
                            ForEach(downloads) { item in
                                DownloadRow(item: item)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            refreshDownloads()
            startPolling()
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
            removeDownloadsActivity()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(UNConstants.textTertiary)
            Text("Downloads are clear")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(UNConstants.textPrimary)
            Text("~/Downloads will appear here with open, reveal, and copy-path actions.")
                .font(.system(size: 12))
                .foregroundStyle(UNConstants.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 36)
    }

    @MainActor
    private func refreshDownloads() {
        guard let folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            downloads = []
            removeDownloadsActivity()
            return
        }

        let keys: Set<URLResourceKey> = [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        )) ?? []

        let entries = urls.compactMap { url -> DownloadEntry? in
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isDirectory != true else { return nil }
            return DownloadEntry(
                id: url,
                url: url,
                name: url.lastPathComponent,
                size: values.fileSize.map(Int64.init),
                modifiedAt: values.contentModificationDate,
                isActive: Self.isDownloadInProgress(url)
            )
        }
        .sorted { ($0.modifiedAt ?? .distantPast) > ($1.modifiedAt ?? .distantPast) }

        withAnimation(reduceMotion ? UNMotion.reduced : UNMotion.listItem) {
            downloads = Array(entries.prefix(30))
        }
        updateDownloadsActivity()
    }

    private func startPolling() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
            Task { @MainActor in refreshDownloads() }
        }
    }

    @MainActor
    private func updateDownloadsActivity() {
        removeDownloadsActivity()
        guard let active = activeDownloads.first else { return }
        appState.liveActivities.append(
            LiveActivity(
                title: "Downloading",
                subtitle: active.name,
                icon: "arrow.down.circle",
                progress: nil,
                priority: 80,
                timestamp: Date(),
                destinationModuleID: "downloads"
            )
        )
    }

    @MainActor
    private func removeDownloadsActivity() {
        appState.liveActivities.removeAll {
            $0.destinationModuleID == "downloads" && $0.icon == "arrow.down.circle"
        }
    }

    private static func isDownloadInProgress(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["download", "crdownload", "part", "partial", "tmp"].contains(ext)
    }
}

private struct DownloadRow: View {
    let item: DownloadsModuleView.DownloadEntry

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(item.isActive ? UNConstants.successTint : UNConstants.insetSurface)
                    .frame(width: 34, height: 34)
                Image(systemName: item.isActive ? "arrow.down.circle.fill" : "doc")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(item.isActive ? UNConstants.successGreen : UNConstants.textSecondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(UNConstants.textPrimary)
                    .lineLimit(1)
                Text(metaText)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(UNConstants.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 5) {
                rowButton("arrow.up.forward.square") { open(item.url) }
                rowButton("folder") { reveal(item.url) }
                rowButton("doc.on.doc") { copyPath(item.url) }
            }
            .opacity(isHovering ? 1 : 0.55)
        }
        .padding(.horizontal, 10)
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: UNConstants.rowCornerRadius, style: .continuous)
                .fill(isHovering ? UNConstants.rowHoverSurface : UNConstants.rowSurface)
        )
        .onHover { hovering in
            withAnimation(reduceMotion ? UNMotion.reduced : UNMotion.hover) {
                isHovering = hovering
            }
        }
    }

    private var metaText: String {
        let status = item.isActive ? "ACTIVE" : "READY"
        let size = item.size.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "size unknown"
        let time = item.modifiedAt.map(Self.relativeString) ?? "unknown"
        return "\(status) · \(size) · \(time)"
    }

    private func rowButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(UNConstants.textSecondary)
                .frame(width: 24, height: 24)
                .background(Circle().fill(UNConstants.controlSurface))
        }
        .buttonStyle(.pressFeedback)
    }

    @MainActor
    private func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    @MainActor
    private func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @MainActor
    private func copyPath(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
    }

    private static func relativeString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date()).uppercased()
    }
}
