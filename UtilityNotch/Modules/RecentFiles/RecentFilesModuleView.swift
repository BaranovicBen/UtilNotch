import AppKit
import SwiftUI

struct RecentFilesModuleView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    struct FileEntry: Identifiable {
        let id: URL
        let url: URL
        let name: String
        let kind: String
        let size: Int64?
        let modifiedAt: Date?
        let symbol: String
        let tint: Color
    }

    @State private var files: [FileEntry] = []

    var body: some View {
        ModuleShellView(
            moduleTitle: "Recent Files",
            moduleIcon: "doc.text.magnifyingglass",
            modules: shellNavItems(appState: appState),
            activeModuleID: appState.activeModuleID,
            onModuleSelect: { id in
                withAnimation(reduceMotion ? UNMotion.reduced : UNMotion.moduleSwitch) {
                    appState.selectModule(id)
                }
            },
            statusDotColor: files.isEmpty ? Color.white.opacity(0.2) : UNConstants.successGreen,
            statusLeft: "\(files.count) LOCAL",
            statusRight: "NO CLOUD",
            actionButton: nil
        ) {
            Group {
                if files.isEmpty {
                    emptyState
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 7) {
                            ForEach(files) { file in
                                RecentFileRow(file: file)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            refreshRecentFiles()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(UNConstants.textTertiary)
            Text("No recent files found")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(UNConstants.textPrimary)
            Text("Recent Documents, Desktop, and Downloads files will appear here locally.")
                .font(.system(size: 12))
                .foregroundStyle(UNConstants.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 36)
    }

    @MainActor
    private func refreshRecentFiles() {
        let manager = FileManager.default
        let directories = [
            manager.urls(for: .documentDirectory, in: .userDomainMask).first,
            manager.urls(for: .desktopDirectory, in: .userDomainMask).first,
            manager.urls(for: .downloadsDirectory, in: .userDomainMask).first
        ].compactMap { $0 }

        let keys: [URLResourceKey] = [
            .isDirectoryKey,
            .isRegularFileKey,
            .contentModificationDateKey,
            .contentAccessDateKey,
            .fileSizeKey,
            .isHiddenKey
        ]
        var seen = Set<URL>()
        var candidates: [FileEntry] = NSDocumentController.shared.recentDocumentURLs.compactMap {
            makeEntry(for: $0, keys: keys, seen: &seen)
        }

        for directory in directories {
            if let shallowURLs = try? manager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles]
            ) {
                for url in shallowURLs.prefix(120) {
                    if let entry = makeEntry(for: url, keys: keys, seen: &seen) {
                        candidates.append(entry)
                    }
                }
            }

            guard let enumerator = manager.enumerator(
                at: directory,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: nil
            ) else { continue }

            var scannedInDirectory = 0
            for case let url as URL in enumerator {
                guard scannedInDirectory < 220 else { break }
                scannedInDirectory += 1
                if let entry = makeEntry(for: url, keys: keys, seen: &seen) {
                    candidates.append(entry)
                }
            }
        }

        let sorted = candidates
            .sorted { ($0.modifiedAt ?? .distantPast) > ($1.modifiedAt ?? .distantPast) }
            .prefix(30)

        withAnimation(reduceMotion ? UNMotion.reduced : UNMotion.listItem) {
            files = Array(sorted)
        }
    }

    private func makeEntry(for url: URL, keys: [URLResourceKey], seen: inout Set<URL>) -> FileEntry? {
        let standardized = url.standardizedFileURL
        guard !seen.contains(standardized),
              let values = try? standardized.resourceValues(forKeys: Set(keys)),
              values.isDirectory != true,
              values.isRegularFile == true,
              values.isHidden != true,
              !Self.isNoise(standardized)
        else { return nil }

        seen.insert(standardized)
        return FileEntry(
            id: standardized,
            url: standardized,
            name: standardized.lastPathComponent,
            kind: standardized.pathExtension.isEmpty ? "FILE" : standardized.pathExtension.uppercased(),
            size: values.fileSize.map(Int64.init),
            modifiedAt: values.contentAccessDate ?? values.contentModificationDate,
            symbol: Self.symbol(for: standardized),
            tint: Self.tint(for: standardized)
        )
    }

    private static func isNoise(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        return name.hasPrefix(".") || ["download", "crdownload", "part", "tmp", "DS_Store"].contains(ext)
    }

    private static func symbol(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "heic", "gif", "tiff": return "photo"
        case "pdf": return "doc.richtext"
        case "mov", "mp4", "m4v": return "play.rectangle"
        case "mp3", "m4a", "wav": return "waveform"
        case "zip", "dmg", "pkg": return "archivebox"
        case "swift", "json", "md", "txt": return "doc.text"
        default: return "doc"
        }
    }

    private static func tint(for url: URL) -> Color {
        switch url.pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "heic", "gif", "tiff": return UNConstants.fileImageEnd
        case "pdf": return UNConstants.filePDFStart
        case "mov", "mp4", "m4v": return UNConstants.fileVideoEnd
        case "mp3", "m4a", "wav": return UNConstants.fileAudioEnd
        case "zip", "dmg", "pkg": return UNConstants.fileArchiveStart
        default: return UNConstants.fileDefaultEnd
        }
    }
}

private struct RecentFileRow: View {
    let file: RecentFilesModuleView.FileEntry

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(file.tint.opacity(0.10))
                    .frame(width: 34, height: 34)
                Image(systemName: file.symbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(file.tint.opacity(0.9))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
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
                rowButton("arrow.up.forward.square") { open(file.url) }
                rowButton("folder") { reveal(file.url) }
                rowButton("doc.on.doc") { copyPath(file.url) }
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
        let size = file.size.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "size unknown"
        let time = file.modifiedAt.map(Self.relativeString) ?? "unknown"
        return "\(file.kind) · \(size) · \(time)"
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
