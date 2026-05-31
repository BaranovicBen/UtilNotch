import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// Files Tray module — full-shell Figma implementation, wired to TrayItem persistence.
/// CSS source: /DesignReference/Css/FilesTray.css
struct FilesTrayModuleView: View {
    @Environment(AppState.self) private var appState

    @State private var store = FilesTrayStore()
    @State private var isDragTargeted: Bool = false
    @State private var workflow: FilesWorkflow = .store
    @State private var isConverterDragTargeted: Bool = false
    @State private var converterFileName: String?
    @State private var converterStatus: ConversionDisplayState = .idle
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
        DummyFile(name: "hero_image.png", gradientStart: UNConstants.fileImageStart, gradientEnd: UNConstants.fileImageEnd, sfSymbol: "photo.fill"),
        DummyFile(name: "brief.pdf",      gradientStart: UNConstants.filePDFStart, gradientEnd: UNConstants.filePDFEnd, sfSymbol: "doc.fill"),
        DummyFile(name: "design.fig",     gradientStart: UNConstants.musicProgressStart, gradientEnd: UNConstants.musicProgressEnd, sfSymbol: "squareshape.controlhandles.on.squareshape.controlhandles"),
        DummyFile(name: "report.xlsx",    gradientStart: UNConstants.fileAudioStart, gradientEnd: UNConstants.fileAudioEnd, sfSymbol: "tablecells.fill"),
    ]

    private var isUsingDummy: Bool { store.trayItems.isEmpty }

    var body: some View {
        ModuleShellView(
            moduleTitle: "Files Tray",
            moduleIcon: "tray",
            modules: shellNavItems(appState: appState),
            activeModuleID: appState.activeModuleID,
            onModuleSelect: { id in
                withAnimation(UNMotion.moduleSwitch) {
                    appState.selectModule(id)
                }
            },
            statusDotColor: Color.white.opacity(0.2),
            statusLeft: workflow == .store ? (isUsingDummy ? "0 FILES" : "\(store.trayItems.count) FILES") : "LOCAL CONVERT",
            statusRight: workflow == .store ? "DROP TO ADD" : converterStatus.footerText,
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
                                    .background(Capsule().fill(UNConstants.accentBlue))
                                    .offset(x: 5, y: -3)
                                    .allowsHitTesting(false)
                                    .transition(.scale(scale: 0.7).combined(with: .opacity))
                            }
                        }
                    }
                    .animation(UNMotion.standard, value: isUsingDummy)
                    .animation(UNMotion.standard, value: store.isSelectMode)
                    .animation(UNMotion.standard, value: store.selectedIDs.isEmpty)
                )
            }
        ) {
            VStack(spacing: 10) {
                workflowSwitch

                if workflow == .store {
                    filesStoreSurface
                } else {
                    converterSurface
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .onChange(of: isConverterDragTargeted) { _, targeted in
            if targeted { appState.dismissalLocks.insert(.dragDrop) }
            else { appState.dismissalLocks.remove(.dragDrop) }
        }
    }

    private var workflowSwitch: some View {
        HStack(spacing: 2) {
            ForEach(FilesWorkflow.allCases) { item in
                Button {
                    withAnimation(UNMotion.standard) { workflow = item }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: item.icon)
                            .font(.system(size: 11, weight: .medium))
                        Text(item.label)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(workflow == item ? UNConstants.textPrimary : UNConstants.textTertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(workflow == item ? UNConstants.selectedSurface : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(UNConstants.insetSurface))
    }

    private var filesStoreSurface: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: UNConstants.tileCornerRadius, style: .continuous)
                .fill(isDragTargeted ? UNConstants.insetSurface : UNConstants.contentLift)
                .overlay(
                    RoundedRectangle(cornerRadius: UNConstants.tileCornerRadius, style: .continuous)
                        .strokeBorder(
                            Color.white.opacity(isDragTargeted ? 0.35 : 0.15),
                            style: StrokeStyle(lineWidth: isDragTargeted ? 1.5 : 1, dash: [6, 4])
                        )
                )
                .animation(UNMotion.hover, value: isDragTargeted)

            if isUsingDummy {
                storeEmptyState
                    .padding(12)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 16) {
                    ForEach(store.trayItems) { item in
                        liveThumbnail(item)
                    }
                }
                .padding(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL], isTargeted: $isDragTargeted) { providers in
            handleDrop(providers)
        }
    }

    private var converterSurface: some View {
        ZStack {
            RoundedRectangle(cornerRadius: UNConstants.tileCornerRadius, style: .continuous)
                .fill(isConverterDragTargeted ? UNConstants.insetSurface : UNConstants.contentLift)
                .overlay(
                    RoundedRectangle(cornerRadius: UNConstants.tileCornerRadius, style: .continuous)
                        .strokeBorder(
                            Color.white.opacity(isConverterDragTargeted ? 0.35 : 0.15),
                            style: StrokeStyle(lineWidth: isConverterDragTargeted ? 1.5 : 1, dash: isConverterDragTargeted ? [] : [6, 4])
                        )
                )

            VStack(spacing: 10) {
                Image(systemName: converterStatus.iconName)
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(converterStatus == .done ? UNConstants.successGreen : UNConstants.textPlaceholder)

                Text(converterFileName ?? (isConverterDragTargeted ? "release to convert" : "drop a file to convert"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(UNConstants.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if converterStatus == .converting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(converterStatus.message)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(UNConstants.textTertiary)
                        .textCase(.uppercase)
                }
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL], isTargeted: $isConverterDragTargeted) { providers in
            handleConverterDrop(providers)
        }
    }

    private var storeEmptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: isDragTargeted ? "tray.and.arrow.down.fill" : "tray")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(UNConstants.textPlaceholder)
            Text(isDragTargeted ? "release to store" : "drop files here")
                .font(.system(size: 14))
                .foregroundStyle(UNConstants.textSecondary)
            Text("stored locally until you remove them")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(UNConstants.textTertiary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
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

    private func handleConverterDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async {
                converterFileName = url.lastPathComponent
                runMockConversion()
            }
        }
        return true
    }

    private func runMockConversion() {
        converterStatus = .converting
        appState.dismissalLocks.insert(.activeConvert)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(UNMotion.progress) {
                converterStatus = .done
            }
            appState.dismissalLocks.remove(.activeConvert)
        }
    }
}

private enum FilesWorkflow: String, CaseIterable, Identifiable {
    case store
    case convert

    var id: String { rawValue }

    var label: String {
        switch self {
        case .store: return "Store"
        case .convert: return "Convert"
        }
    }

    var icon: String {
        switch self {
        case .store: return "tray"
        case .convert: return "arrow.2.squarepath"
        }
    }
}

private enum ConversionDisplayState: Equatable {
    case idle
    case converting
    case done

    var iconName: String {
        switch self {
        case .idle: return "arrow.down.doc"
        case .converting: return "arrow.2.squarepath"
        case .done: return "checkmark.circle"
        }
    }

    var message: String {
        switch self {
        case .idle: return "choose format later"
        case .converting: return "converting"
        case .done: return "ready to open or share"
        }
    }

    var footerText: String {
        switch self {
        case .idle: return "DROP TO START"
        case .converting: return "CONVERTING"
        case .done: return "COMPLETE"
        }
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
    func updateNSView(_ nsView: NSView, context: Context) {
        // Re-capture on every layout pass so the reference is never stale/windowless.
        DispatchQueue.main.async { captured(nsView) }
    }
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
                    isActive  ? UNConstants.accentBlue :
                    isDisabled ? UNConstants.textPlaceholder :
                    UNConstants.textSecondary
                )
                .frame(width: UNConstants.hudButtonSize, height: UNConstants.hudButtonSize)
                .background(
                    Circle().fill(
                        isActive ? UNConstants.accentBlue.opacity(0.15) : UNConstants.controlSurface
                    )
                )
        }
        .buttonStyle(.pressFeedback)
        .disabled(isDisabled)
        .overlay(alignment: .bottom) {
            if isHovering && !isDisabled {
                Text(tooltip)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(UNConstants.textPrimary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(UNConstants.tooltipSurface)
                    )
                    .fixedSize()
                    .offset(y: 32)
                    .transition(.opacity.combined(with: .offset(y: -3)))
                    .allowsHitTesting(false)
                    .zIndex(100)
            }
        }
        .onHover { h in withAnimation(UNMotion.hover) { isHovering = h } }
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
            return (UNConstants.fileImageStart, UNConstants.fileImageEnd)
        case "pdf":
            return (UNConstants.filePDFStart, UNConstants.filePDFEnd)
        case "fig", "sketch", "xd":
            return (UNConstants.musicProgressStart, UNConstants.musicProgressEnd)
        case "xlsx", "csv", "numbers":
            return (UNConstants.fileAudioStart, UNConstants.fileAudioEnd)
        case "mp3", "wav", "aiff", "m4a":
            return (UNConstants.fileArchiveStart, UNConstants.fileArchiveEnd)
        case "mp4", "mov", "avi":
            return (UNConstants.fileVideoStart, UNConstants.fileVideoEnd)
        default:
            return (UNConstants.fileDefaultStart, UNConstants.fileDefaultEnd)
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
                              ? UNConstants.accentBlue.opacity(0.18)
                              : UNConstants.controlSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(
                                    isSelected ? UNConstants.accentBlue.opacity(0.6) : Color.clear,
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
                    .foregroundStyle(isSelected ? UNConstants.textPrimary : UNConstants.textTertiary)
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
                    .foregroundStyle(isSelected ? UNConstants.accentBlue : UNConstants.textSecondary)
                    .background(UNConstants.overlayScrim, in: Circle())
                    .offset(x: 4, y: -4)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            } else if isHovering {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .background(UNConstants.overlayScrim, in: Circle())
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
                .transition(.scale(scale: 0.7).combined(with: .opacity))
            }
        }
        .onHover { h in withAnimation(UNMotion.hover) { isHovering = h } }
        .onAppear { loadIcon() }
    }

    private func loadIcon() {
        let path = item.resolvedURL()?.path ?? item.path
        let img = NSWorkspace.shared.icon(forFile: path)
        img.size = NSSize(width: 64, height: 64)
        icon = img
    }
}
