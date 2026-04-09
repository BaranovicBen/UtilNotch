import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// Files Tray module — full-shell Figma implementation, wired to TrayItem persistence.
/// CSS source: /DesignReference/Css/FilesTray.css
struct FilesTrayModuleView: View {
    @Environment(AppState.self) private var appState

    @State private var store = FilesTrayStore()
    @State private var isDragTargeted: Bool = false
    // Captures the AirDrop button's NSView so NSSharingServicePicker anchors to it
    @State private var shareAnchorView: NSView? = nil

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

    private var isUsingDummy: Bool { store.trayItems.isEmpty }

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
            statusLeft: isUsingDummy ? "4 FILES" : "\(store.trayItems.count) FILES",
            statusRight: "DROP TO ADD",
            actionButton: {
                AnyView(
                    HStack(spacing: 6) {
                        // Add files — always visible
                        CircularIconButton(
                            icon: "folder.badge.plus",
                            tooltip: "Add files",
                            isActive: false,
                            isDisabled: false,
                            action: { store.openFilePicker(appState: appState) }
                        )

                        // Select / Done — hidden while tray is empty
                        if !isUsingDummy {
                            CircularIconButton(
                                icon: store.isSelectMode ? "checkmark.circle.fill" : "checkmark.circle",
                                tooltip: store.isSelectMode ? "Done" : "Select files",
                                isActive: store.isSelectMode,
                                isDisabled: false,
                                action: { store.toggleSelectMode() }
                            )
                            .transition(.scale(scale: 0.7).combined(with: .opacity))
                        }

                        // AirDrop — badge shows selection count in select mode
                        let canShare = !isUsingDummy && (!store.isSelectMode || !store.selectedIDs.isEmpty)
                        let airdropTooltip = (store.isSelectMode && !store.selectedIDs.isEmpty)
                            ? "AirDrop \(store.selectedIDs.count) file\(store.selectedIDs.count == 1 ? "" : "s")"
                            : "AirDrop all"
                        ZStack(alignment: .topTrailing) {
                            CircularIconButton(
                                icon: "antenna.radiowaves.left.and.right",
                                tooltip: airdropTooltip,
                                isActive: false,
                                isDisabled: !canShare,
                                action: { store.shareItems(appState: appState, anchorView: shareAnchorView) }
                            )
                            .background(NSViewAnchor { shareAnchorView = $0 })

                            // Selection count badge
                            if store.isSelectMode && !store.selectedIDs.isEmpty {
                                Text("\(store.selectedIDs.count)")
                                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 3)
                                    .padding(.vertical, 1.5)
                                    .background(Capsule().fill(Color(hex: "0A84FF")))
                                    .offset(x: 5, y: -3)
                                    .allowsHitTesting(false)
                                    .transition(.scale(scale: 0.7).combined(with: .opacity))
                            }
                        }
                    }
                    .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isUsingDummy)
                    .animation(.spring(response: 0.28, dampingFraction: 0.72), value: store.isSelectMode)
                    .animation(.spring(response: 0.28, dampingFraction: 0.72), value: store.selectedIDs.isEmpty)
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
                        ForEach(store.trayItems) { item in
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
        .onAppear {
            store.onAppear()
            // Drain files captured by FileDragReceiverZone before the panel finished opening
            if !appState.pendingTrayURLs.isEmpty {
                store.addURLs(appState.pendingTrayURLs)
                appState.pendingTrayURLs = []
            }
        }
        .onChange(of: appState.pendingTrayURLs) { _, urls in
            guard !urls.isEmpty else { return }
            store.addURLs(urls)
            appState.pendingTrayURLs = []
        }
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

    // MARK: - Live Thumbnail (wired × button, select mode, drag-out)

    @ViewBuilder
    private func liveThumbnail(_ item: TrayItem) -> some View {
        LiveThumbnailView(
            item: item,
            isSelectMode: store.isSelectMode,
            isSelected: store.selectedIDs.contains(item.id),
            onRemove: { store.removeItem(item) },
            onSelect: { store.toggleSelection(item) }
        )
        .contextMenu {
            Button {
                if let url = item.resolvedURL() {
                    appState.pendingFileURL = url
                    withAnimation(.spring(duration: 0.28, bounce: 0.16)) {
                        appState.selectModule("fileConverter")
                    }
                }
            } label: {
                Label("Send to File Converter", systemImage: "arrow.2.squarepath")
            }

            Divider()

            Button(role: .destructive) {
                store.removeItem(item)
            } label: {
                Label("Remove from Tray", systemImage: "trash")
            }
        }
    }

    // MARK: - Drop Handler

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                Task { @MainActor in
                    store.addURLs([url])
                }
            }
        }
        return true
    }
}

// MARK: - NSView anchor helper

/// Transparent NSView embedded as a button background.
/// Captures the underlying NSView so NSSharingServicePicker can anchor to the actual button position.
private struct NSViewAnchor: NSViewRepresentable {
    let captured: (NSView) -> Void
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async { captured(v) }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - Circular icon button with hover tooltip

private struct CircularIconButton: View {
    let icon: String
    let tooltip: String
    let isActive: Bool
    let isDisabled: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(
                    isActive  ? Color(hex: "0A84FF") :
                    isDisabled ? Color.white.opacity(0.25) :
                    Color.white.opacity(0.5)
                )
                .frame(width: 26, height: 26)
                .background(
                    Circle().fill(
                        isActive ? Color(hex: "0A84FF").opacity(0.15) : Color.white.opacity(0.08)
                    )
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .overlay(alignment: .bottom) {
            if isHovering && !isDisabled {
                Text(tooltip)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color(red: 0.12, green: 0.12, blue: 0.12))
                            .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                    )
                    .fixedSize()
                    .offset(y: 32)
                    .transition(.opacity.combined(with: .offset(y: -3)))
                    .allowsHitTesting(false)
                    .zIndex(100)
            }
        }
        .onHover { h in withAnimation(.easeInOut(duration: 0.15)) { isHovering = h } }
        .zIndex(isHovering ? 100 : 0)
    }
}

// MARK: - Live Thumbnail View

private struct LiveThumbnailView: View {
    let item: TrayItem
    let isSelectMode: Bool
    let isSelected: Bool
    let onRemove: () -> Void
    let onSelect: () -> Void

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
                    // Background tile — highlighted when selected
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected
                              ? Color(hex: "0A84FF").opacity(0.18)
                              : Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(
                                    isSelected ? Color(hex: "0A84FF").opacity(0.6) : Color.clear,
                                    lineWidth: 1.5
                                )
                        )
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
                    .foregroundStyle(Color.white.opacity(isSelected ? 0.75 : 0.4))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 72)
                    .multilineTextAlignment(.center)
            }
            // Drag-out support — disabled in select mode
            .onDrag {
                guard !isSelectMode, let url = item.resolvedURL() else { return NSItemProvider() }
                return NSItemProvider(contentsOf: url) ?? NSItemProvider()
            }
            // Tap to toggle selection in select mode
            .onTapGesture {
                if isSelectMode { onSelect() }
            }

            // Top-right overlay: checkmark in select mode, × on hover in normal mode
            if isSelectMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isSelected ? Color(hex: "0A84FF") : Color.white.opacity(0.45))
                    .background(Color.black.opacity(0.35), in: Circle())
                    .offset(x: 4, y: -4)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            } else if isHovering {
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
        let img = NSWorkspace.shared.icon(forFile: path)
        img.size = NSSize(width: 64, height: 64)
        icon = img
    }
}
