import SwiftUI

/// Recent Files module — full-shell Figma implementation.
/// CSS source: /DesignReference/Css/RecentFiles.css
struct RecentFilesModuleView: View {
    @Environment(AppState.self) private var appState

    private struct FileEntry: Identifiable {
        let id = UUID()
        let name: String
        let meta: String        // e.g. "PDF · 1.8 MB"
        let time: String        // e.g. "2 min ago"
        let iconColor: Color    // icon foreground
        let iconBg: Color       // icon background tint
        let sfSymbol: String
    }

    private let files: [FileEntry] = [
        FileEntry(name: "ProjectSpec.pdf",    meta: "PDF · 1.8 MB",  time: "2 MIN AGO",   iconColor: Color(hex: "FF453A"), iconBg: Color(hex: "FF453A").opacity(0.1), sfSymbol: "doc.fill"),
        FileEntry(name: "design_mockup.png",  meta: "PNG · 4.2 MB",  time: "14 MIN AGO",  iconColor: Color(hex: "0A84FF"), iconBg: Color(hex: "0A84FF").opacity(0.1), sfSymbol: "photo.fill"),
        FileEntry(name: "AppDelegate.swift",  meta: "SWIFT · 12 KB", time: "1 HR AGO",    iconColor: Color(hex: "30D158"), iconBg: Color(hex: "30D158").opacity(0.1), sfSymbol: "swift"),
        FileEntry(name: "wireframes_v3.fig",  meta: "FIGMA · 28 MB", time: "YESTERDAY",   iconColor: Color(hex: "A259FF"), iconBg: Color(hex: "A259FF").opacity(0.1), sfSymbol: "squareshape.controlhandles.on.squareshape.controlhandles"),
        FileEntry(name: "config.json",        meta: "JSON · 3 KB",   time: "2 DAYS AGO",  iconColor: Color(hex: "FF9F0A"), iconBg: Color(hex: "FF9F0A").opacity(0.1), sfSymbol: "curlybraces"),
    ]

    var body: some View {
        ModuleShellView(
            moduleTitle: "Recent Files",
            moduleIcon: "doc.text.magnifyingglass",
            modules: shellNavItems(appState: appState),
            activeModuleID: appState.activeModuleID,
            onModuleSelect: { id in
                withAnimation(.spring(duration: 0.28, bounce: 0.16)) {
                    appState.selectModule(id)
                }
            },
            statusDotColor: Color.white.opacity(0.2),
            statusLeft: "RECENT FILES",
            statusRight: "LOCAL ONLY",
            actionButton: nil
        ) {
            ScrollView(.vertical, showsIndicators: false) {
                // CSS: gap 8px
                VStack(spacing: 8) {
                    ForEach(files) { file in
                        fileRow(file)
                    }
                }
            }
        }
    }

    // MARK: - File Row
    // CSS: padding 8px, gap 12px, height 54px, bg rgba(255,255,255,0.03), radius 8px

    @ViewBuilder
    private func fileRow(_ file: FileEntry) -> some View {
        HStack(spacing: 12) {
            // File type icon — CSS: 36×36 radius 6px, tinted bg
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(file.iconBg)
                    .frame(width: 36, height: 36)

                Image(systemName: file.sfSymbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(file.iconColor)
            }

            // File name + meta
            VStack(alignment: .leading, spacing: 2) {
                // CSS: Inter 500 14px #FFFFFF
                Text(file.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)

                // CSS: JetBrains Mono 400 11px letter-spacing 0.55px uppercase rgba(255,255,255,0.35)
                Text(file.meta)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .kerning(0.55)
                    .lineLimit(1)
            }

            Spacer()

            // Relative time — CSS: JetBrains Mono 400 11px rgba(255,255,255,0.35) text-right
            Text(file.time)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.35))
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
    }
}
