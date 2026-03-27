import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// Files Tray module — full-shell Figma implementation, wired to TrayItem persistence.
/// CSS source: /DesignReference/Css/FilesTray.css
struct FilesTrayModuleView: View {
    @Environment(AppState.self) private var appState

    @State private var trayItems: [TrayItem] = []
    @State private var isDragTargeted: Bool = false

    // Dummy files shown when tray is empty (preserves visual design on first launch)
    private struct DummyFile: Identifiable {
        let id = UUID()
        let name: String
        let gradientStart: Color
        let gradientEnd: Color
        let sfSymbol: String
    }
    private let dummyFiles: [DummyFile] = [
        DummyFile(name: "hero_image.png", gradientStart: Color(hex: "0A84FF"), gradientEnd: Color(hex: "00468D"), sfSymbol: "photo.fill"),
        DummyFile(name: "brief.pdf",      gradientStart: Color(hex: "FF453A"), gradientEnd: Color(hex: "8B0000"), sfSymbol: "doc.fill"),
        DummyFile(name: "design.fig",     gradientStart: Color(hex: "A259FF"), gradientEnd: Color(hex: "5E0DAC"), sfSymbol: "squareshape.controlhandles.on.squareshape.controlhandles"),
        DummyFile(name: "report.xlsx",    gradientStart: Color(hex: "30D158"), gradientEnd: Color(hex: "1A6632"), sfSymbol: "tablecells.fill"),
    ]

    private var isUsingDummy: Bool { trayItems.isEmpty }

    var body: some View {
        ModuleShellView(
            moduleTitle: "Files Tray",
            moduleIcon: "tray",
            modules: shellNavItems(appState: appState),
            activeModuleID: appState.activeModuleID,
            onModuleSelect: { id in
                withAnimation(.spring(duration: 0.28, bounce: 0.16)) {
                    appState.selectModule(id)
                }
            },
            statusDotColor: Color.white.opacity(0.2),
            statusLeft: isUsingDummy ? "4 FILES" : "\(trayItems.count) FILES",
            statusRight: "DROP TO ADD",
            actionButton: {
                AnyView(
                    Button { shareAll() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 10, weight: .medium))
                            Text("AIRDROP ALL")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .textCase(.uppercase)
                                .kerning(0.55)
                        }
                        .foregroundStyle(Color.white)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)
                        .background(Capsule().fill(Color.white.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                    .opacity(isUsingDummy ? 0.4 : 1.0)
                    .disabled(isUsingDummy)
                )
            }
        ) {
            // Drop Zone Container
            // CSS: padding 12px, bg rgba(255,255,255,0.02), border 1px dashed rgba(255,255,255,0.15), radius 12px
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isDragTargeted ? Color.white.opacity(0.04) : Color.white.opacity(0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                Color.white.opacity(isDragTargeted ? 0.35 : 0.15),
                                style: StrokeStyle(lineWidth: isDragTargeted ? 1.5 : 1, dash: [6, 4])
                            )
                    )
                    .animation(.easeInOut(duration: 0.15), value: isDragTargeted)

                // Files grid — 4-column LazyVGrid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 16) {
                    if isUsingDummy {
                        ForEach(dummyFiles) { file in
                            dummyThumbnail(file)
                        }
                    } else {
                        ForEach(trayItems) { item in
                            liveThumbnail(item)
                        }
                    }
                }
                .padding(12)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 208)
            .onDrop(of: [.fileURL], isTargeted: $isDragTargeted) { providers in
                handleDrop(providers)
            }
        }
        .onAppear { trayItems = TrayPersistence.load() }
        .onChange(of: isDragTargeted) { _, targeted in
            if targeted { appState.dismissalLocks.insert(.dragDrop) }
            else { appState.dismissalLocks.remove(.dragDrop) }
        }
    }

    // MARK: - Dummy Thumbnail (non-interactive, visual demo)
    // CSS outer: 72×72 bg rgba(255,255,255,0.08) radius 8px

    @ViewBuilder
    private func dummyThumbnail(_ file: DummyFile) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 72, height: 72)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(LinearGradient(colors: [file.gradientStart, file.gradientEnd],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: file.sfSymbol)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.4))
                    )
            }
            Text(file.name)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.4))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 72)
                .multilineTextAlignment(.center)
        }
        .opacity(0.6)
    }

    // MARK: - Live Thumbnail (wired × button + drag-out)

    @ViewBuilder
    private func liveThumbnail(_ item: TrayItem) -> some View {
        LiveThumbnailView(item: item) {
            removeItem(item)
        }
    }

    // MARK: - Drop Handler

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                Task { @MainActor in
                    guard !trayItems.contains(where: { $0.path == url.path }) else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        trayItems.append(TrayItem(url: url))
                    }
                    TrayPersistence.save(trayItems)
                }
            }
        }
        return true
    }

    // MARK: - Actions

    private func removeItem(_ item: TrayItem) {
        withAnimation(.easeOut(duration: 0.2)) {
            trayItems.removeAll { $0.id == item.id }
        }
        TrayPersistence.save(trayItems)
    }

    private func shareAll() {
        let urls = trayItems.compactMap { $0.resolvedURL() }
        guard !urls.isEmpty else { return }
        guard let button = NSApp.keyWindow?.contentView else { return }
        let picker = NSSharingServicePicker(items: urls as [Any])
        picker.show(relativeTo: .zero, of: button, preferredEdge: .minY)
    }
}

// MARK: - Live Thumbnail View

private struct LiveThumbnailView: View {
    let item: TrayItem
    let onRemove: () -> Void

    @State private var isHovering = false
    @State private var icon: NSImage? = nil

    // Gradient/icon derived from file extension
    private var gradientColors: (Color, Color) {
        let ext = URL(fileURLWithPath: item.path).pathExtension.lowercased()
        switch ext {
        case "png", "jpg", "jpeg", "heic", "gif", "webp":
            return (Color(hex: "0A84FF"), Color(hex: "00468D"))
        case "pdf":
            return (Color(hex: "FF453A"), Color(hex: "8B0000"))
        case "fig", "sketch", "xd":
            return (Color(hex: "A259FF"), Color(hex: "5E0DAC"))
        case "xlsx", "csv", "numbers":
            return (Color(hex: "30D158"), Color(hex: "1A6632"))
        case "mp3", "wav", "aiff", "m4a":
            return (Color(hex: "FF9F0A"), Color(hex: "8B5200"))
        case "mp4", "mov", "avi":
            return (Color(hex: "FF453A"), Color(hex: "6B0000"))
        default:
            return (Color(hex: "636366"), Color(hex: "3A3A3C"))
        }
    }

    private var sfSymbol: String {
        let ext = URL(fileURLWithPath: item.path).pathExtension.lowercased()
        switch ext {
        case "png", "jpg", "jpeg", "heic", "gif", "webp": return "photo.fill"
        case "pdf": return "doc.fill"
        case "fig", "sketch": return "squareshape.controlhandles.on.squareshape.controlhandles"
        case "xlsx", "csv", "numbers": return "tablecells.fill"
        case "mp3", "wav", "aiff", "m4a": return "music.note"
        case "mp4", "mov": return "video.fill"
        default: return "doc.fill"
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 72, height: 72)

                    if let icon {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 56, height: 56)
                    } else {
                        let (start, end) = gradientColors
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(LinearGradient(colors: [start, end],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: sfSymbol)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.4))
                            )
                    }
                }
                Text(item.displayName)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 72)
                    .multilineTextAlignment(.center)
            }
            // Drag-out support — exposes file URL to drop destinations
            .onDrag {
                guard let url = item.resolvedURL() else { return NSItemProvider() }
                return NSItemProvider(contentsOf: url) ?? NSItemProvider()
            }

            // × remove button (hover only)
            if isHovering {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .background(Color.black.opacity(0.5), in: Circle())
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
                .transition(.scale(scale: 0.7).combined(with: .opacity))
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
