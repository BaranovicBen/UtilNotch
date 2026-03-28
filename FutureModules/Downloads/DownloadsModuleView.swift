import SwiftUI

/// Downloads module — full-shell Figma implementation.
/// CSS source: /DesignReference/Css/Downloads.css
struct DownloadsModuleView: View {
    @Environment(AppState.self) private var appState

    private struct DownloadEntry: Identifiable {
        let id = UUID()
        let name: String
        let status: String      // e.g. "COMPLETED"
        let size: String        // e.g. "7.1 GB"
        let time: String        // e.g. "14 MIN AGO"
    }

    private let downloads: [DownloadEntry] = [
        DownloadEntry(name: "Xcode_15.4.dmg",    status: "COMPLETED", size: "7.1 GB",  time: "14 MIN AGO"),
        DownloadEntry(name: "SF-Symbols-5.pkg",  status: "COMPLETED", size: "1.2 GB",  time: "2 HRS AGO"),
        DownloadEntry(name: "Figma_Desktop.dmg", status: "COMPLETED", size: "156 MB",  time: "YESTERDAY"),
        DownloadEntry(name: "CleanMyMac.zip",    status: "COMPLETED", size: "44 MB",   time: "MON"),
    ]

    var body: some View {
        ModuleShellView(
            moduleTitle: "Downloads",
            moduleIcon: "arrow.down.circle",
            modules: shellNavItems(appState: appState),
            activeModuleID: appState.activeModuleID,
            onModuleSelect: { id in
                withAnimation(.spring(duration: 0.28, bounce: 0.16)) {
                    appState.selectModule(id)
                }
            },
            statusDotColor: Color.white.opacity(0.2),
            statusLeft: "4 DOWNLOADS",
            statusRight: "FINDER → CLEAR",
            actionButton: { makeDestructiveActionButton(icon: "trash", label: "CLEAR ALL") }
        ) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(downloads) { item in
                        downloadRow(item)
                    }
                }
            }
        }
    }

    // MARK: - Download Row
    // CSS: padding 12px, gap 12px, height 62px, bg rgba(255,255,255,0.03), radius 12px

    @ViewBuilder
    private func downloadRow(_ item: DownloadEntry) -> some View {
        HStack(spacing: 12) {
            // File icon — CSS: 36×36 radius 6px, bg #2C2C2E, icon rgba(255,255,255,0.6)
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(hex: "2C2C2E"))
                    .frame(width: 36, height: 36)

                Image(systemName: "arrow.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.6))
            }

            // File name + status
            VStack(alignment: .leading, spacing: 2) {
                // CSS: Inter 500 14px rgba(255,255,255,0.85)
                Text(item.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(1)

                // CSS: JetBrains Mono 400 11px letter-spacing 0.55px uppercase rgba(255,255,255,0.35)
                Text(item.status)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .kerning(0.55)
            }

            Spacer()

            // Right column: size + time
            VStack(alignment: .trailing, spacing: 2) {
                // CSS: JetBrains Mono 400 12px rgba(255,255,255,0.7)
                Text(item.size)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.7))

                // CSS: JetBrains Mono 400 12px rgba(255,255,255,0.35)
                Text(item.time)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.35))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
    }
}
