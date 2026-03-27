import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Tray Item Model

struct TrayItem: Identifiable, Codable {
    let id: UUID
    var path: String            // Absolute path — used as display fallback
    var bookmarkData: Data?     // Security-scoped bookmark for cross-relaunch access

    init(id: UUID = UUID(), url: URL) {
        self.id = id
        self.path = url.path
        // ENTITLEMENT_NOTE: requires com.apple.security.files.bookmarks.app-scope
        self.bookmarkData = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    /// Resolves the stored bookmark (or falls back to path) and starts security-scoped access.
    func resolvedURL() -> URL? {
        if let data = bookmarkData {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data,
                                  options: .withSecurityScope,
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &stale) {
                _ = url.startAccessingSecurityScopedResource()
                return url
            }
        }
        // Plain path fallback (no security scope — only works within same session)
        let url = URL(fileURLWithPath: path)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    var displayName: String { URL(fileURLWithPath: path).lastPathComponent }
}

// MARK: - Persistence helper

enum TrayPersistence {
    static private var fileURL: URL {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("UtilityNotch", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return support.appendingPathComponent("filesTray.json")
    }

    static func load() -> [TrayItem] {
        guard let data = try? Data(contentsOf: fileURL),
              let items = try? JSONDecoder().decode([TrayItem].self, from: data) else { return [] }
        return items
    }

    static func save(_ items: [TrayItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

// MARK: - Settings Key

private enum TrayKey {
    static let capacity = "filesTray.maxCapacity"
}

// MARK: - Main View

struct FilesTrayView: View {
    @Environment(AppState.self) private var appState
    @AppStorage(TrayKey.capacity) private var maxCapacity: Int = 12

    @State private var items: [TrayItem] = []
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Files Tray", systemImage: "tray")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                if !items.isEmpty {
                    Button { shareAll() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 11))
                            Text("AirDrop")
                                .font(.caption.weight(.medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08), in: Capsule())
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 10)

            // ── Content: drop zone or thumbnail grid ─────────────────
            if items.isEmpty {
                emptyDropZone
            } else {
                thumbnailGrid
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: handleDrop)
        .onChange(of: isDropTargeted) { _, v in
            if v { appState.dismissalLocks.insert(.dragDrop) }
            else { appState.dismissalLocks.remove(.dragDrop) }
        }
        .onAppear { items = TrayPersistence.load() }
    }

    // MARK: - Empty Drop Zone

    private var emptyDropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    Color.white.opacity(isDropTargeted ? 0.4 : 0.2),
                    style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                )
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(isDropTargeted ? 0.04 : 0))
                )
                .animation(.easeInOut(duration: 0.15), value: isDropTargeted)

            VStack(spacing: 8) {
                Image(systemName: "tray.and.arrow.down")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
                Text("Drop files here")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Thumbnail Grid (horizontal scroll, 64×64 each)

    private var thumbnailGrid: some View {
        ZStack(alignment: .bottom) {
            // Drop zone overlay (dashed border) even when items are present
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    Color.white.opacity(isDropTargeted ? 0.35 : 0),
                    style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                )
                .animation(.easeInOut(duration: 0.15), value: isDropTargeted)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(items) { item in
                        TrayThumbnail(item: item, onRemove: { remove(item) })
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Drop Handler

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var loaded = 0
        for provider in providers {
            guard items.count + loaded < maxCapacity else { break }
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url  = URL(dataRepresentation: data, relativeTo: nil) else { return }
                Task { @MainActor in
                    guard !items.contains(where: { $0.path == url.path }) else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        items.append(TrayItem(url: url))
                    }
                    TrayPersistence.save(items)
                }
            }
            loaded += 1
        }
        return true
    }

    // MARK: - Actions

    private func remove(_ item: TrayItem) {
        withAnimation(.easeOut(duration: 0.2)) {
            items.removeAll { $0.id == item.id }
        }
        TrayPersistence.save(items)
    }

    private func shareAll() {
        let urls = items.compactMap { $0.resolvedURL() }
        guard !urls.isEmpty, let button = NSApp.keyWindow?.contentView else { return }
        let picker = NSSharingServicePicker(items: urls as [Any])
        picker.show(relativeTo: .zero, of: button, preferredEdge: .minY)
    }
}

// MARK: - Thumbnail Card

private struct TrayThumbnail: View {
    let item: TrayItem
    let onRemove: () -> Void

    @State private var isHovering = false
    @State private var icon: NSImage? = nil

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Card
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 64, height: 64)
                    if let icon {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 52, height: 52)
                    } else {
                        Image(systemName: "doc")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(item.displayName)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .multilineTextAlignment(.center)
                    .frame(width: 64)
            }
            // Drag support — expose file URL to drag destinations
            .onDrag {
                guard let url = item.resolvedURL() else { return NSItemProvider() }
                return NSItemProvider(contentsOf: url) ?? NSItemProvider()
            }

            // ✕ remove button (hover)
            if isHovering {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .background(Color.black.opacity(0.5), in: Circle())
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .onHover { h in withAnimation(.easeInOut(duration: 0.15)) { isHovering = h } }
        .onAppear { loadIcon() }
    }

    private func loadIcon() {
        let path = item.resolvedURL()?.path ?? item.path
        Task.detached(priority: .userInitiated) {
            let img = NSWorkspace.shared.icon(forFile: path)
            img.size = NSSize(width: 64, height: 64)
            await MainActor.run { icon = img }
        }
    }
}

// MARK: - Settings View

struct FilesTraySettingsView: View {
    @AppStorage(TrayKey.capacity) private var maxCapacity: Int = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Files Tray Settings")
                .font(.headline)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 6) {
                Text("Max tray capacity")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $maxCapacity) {
                    Text("6 files").tag(6)
                    Text("12 files").tag(12)
                    Text("24 files").tag(24)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }
}
