import AppKit
import SwiftUI

/// Clipboard History module - showcases recent text, links, files, and image clipboard items.
struct ClipboardModuleView: View {
    @Environment(AppState.self) private var appState

    @State private var store = ClipboardHistoryStore()
    @State private var clearConfirmActive = false
    @State private var clearConfirmTimer: Timer?

    var body: some View {
        ModuleShellView(
            moduleTitle: "Clipboard History",
            moduleIcon: "doc.on.clipboard",
            modules: shellNavItems(appState: appState),
            activeModuleID: appState.activeModuleID,
            onModuleSelect: { id in
                withAnimation(UNMotion.moduleSwitch) {
                    appState.selectModule(id)
                }
            },
            statusDotColor: store.isMonitoring ? Color(hex: "32D74B") : Color.white.opacity(0.2),
            statusLeft: store.isMonitoring ? "CLIPBOARD SYNC ACTIVE" : "CLIPBOARD SYNC PAUSED",
            statusRight: store.isShowingDemoItems ? "\(store.storedItemCount) EXAMPLES" : "\(store.storedItemCount) ITEMS STORED",
            actionButton: {
                AnyView(headerActions)
            }
        ) {
            VStack(spacing: 10) {
                typeFilterPopup

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(store.visibleItems) { item in
                            ClipboardHistoryCard(
                                item: item,
                                isCopied: store.recentlyCopiedID == item.id,
                                onCopy: { store.copy(item) },
                                onDelete: { store.delete(item) }
                            )
                        }

                        if store.visibleItems.isEmpty {
                            emptyFilterState
                        }
                    }
                    .padding(.bottom, 2)
                }
            }
        }
        .onAppear {
            store.onAppear()
        }
        .onDisappear {
            store.onDisappear()
            clearConfirmTimer?.invalidate()
            clearConfirmTimer = nil
        }
        .onChange(of: clearConfirmActive) { _, _ in
            appState.setModuleActionButton { AnyView(headerActions) }
        }
        .onChange(of: store.isShowingDemoItems) { _, _ in
            appState.setModuleActionButton { AnyView(headerActions) }
        }
    }

    private var headerActions: some View {
        HStack(spacing: 6) {
            Button {
                store.onAppear()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.68))
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help("Refresh clipboard")

            Button {
                if clearConfirmActive {
                    clearHistory()
                } else {
                    activateClearConfirm()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: clearConfirmActive ? "exclamationmark.triangle" : "trash")
                        .font(.system(size: 10, weight: .medium))
                    Text(clearConfirmActive ? "CONFIRM" : "CLEAR")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .textCase(.uppercase)
                        .kerning(0.55)
                }
                .foregroundStyle(Color(red: 1.0, green: 0.271, blue: 0.227))
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
                .background(
                    Capsule()
                        .fill(Color(red: 1.0, green: 0.271, blue: 0.227).opacity(0.15))
                )
            }
            .buttonStyle(.plain)
            .disabled(store.isShowingDemoItems && !clearConfirmActive)
            .opacity(store.isShowingDemoItems && !clearConfirmActive ? 0.45 : 1)
        }
    }

    private var typeFilterPopup: some View {
        Menu {
            Button {
                store.selectedKind = nil
            } label: {
                Label("All Types", systemImage: store.selectedKind == nil ? "checkmark" : "tray.full")
            }

            Divider()

            ForEach(ClipboardContentKind.allCases) { kind in
                Button {
                    store.selectedKind = kind
                } label: {
                    Label(kind.filterTitle, systemImage: store.selectedKind == kind ? "checkmark" : kind.icon)
                }
            }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(selectedFilterColor.opacity(store.selectedKind == nil ? 0.08 : 0.16))
                    Image(systemName: selectedFilterIcon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(selectedFilterColor)
                }
                .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Filter by type")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .textCase(.uppercase)
                        .foregroundStyle(Color.white.opacity(0.34))
                    Text(selectedFilterTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.84))
                }

                Spacer(minLength: 8)

                Text("\(store.visibleItems.count)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.38))

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.32))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
    }

    private var emptyFilterState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.25))
            Text(emptyFilterMessage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.42))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
    }

    private func activateClearConfirm() {
        clearConfirmActive = true
        clearConfirmTimer?.invalidate()
        clearConfirmTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            Task { @MainActor in
                clearConfirmActive = false
            }
        }
    }

    private func clearHistory() {
        clearConfirmTimer?.invalidate()
        clearConfirmTimer = nil
        clearConfirmActive = false
        store.clearHistory()
    }

    private var selectedFilterTitle: String {
        store.selectedKind?.filterTitle ?? "All Types"
    }

    private var selectedFilterIcon: String {
        store.selectedKind?.icon ?? "line.3.horizontal.decrease.circle"
    }

    private var selectedFilterColor: Color {
        store.selectedKind?.accentColor ?? Color.white.opacity(0.48)
    }

    private var emptyFilterMessage: String {
        guard let selectedKind = store.selectedKind else { return "No clips yet" }
        return "No \(selectedKind.filterTitle.lowercased()) clips"
    }
}

private struct ClipboardHistoryCard: View {
    let item: ClipboardHistoryItem
    let isCopied: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 5) {
                Text(item.preview)
                    .font(item.kind == .code
                        ? .system(size: 13, weight: .regular, design: .monospaced)
                        : .system(size: 13, weight: .regular)
                    )
                    .foregroundStyle(item.kind == .url ? item.accentColor : Color.white.opacity(0.85))
                    .lineLimit(item.kind == .text ? 2 : 1)
                    .truncationMode(.tail)

                HStack(spacing: 5) {
                    Text(item.timestamp)
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 3, height: 3)
                    Text(item.detail.uppercased())
                    if item.isDemo {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 3, height: 3)
                        Text("DEMO")
                    }
                }
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.34))
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailingActions
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isCopied ? Color.white.opacity(0.09) : Color.white.opacity(isHovering ? 0.055 : 0.03))
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onCopy)
        .onHover { h in withAnimation(UNMotion.hover) { isHovering = h } }
        .contextMenu {
            Button {
                onCopy()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            if !item.isDemo {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if item.kind == .image, let data = item.imageData, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(item.accentColor.opacity(item.kind == .text ? 0.1 : 0.16))
                Image(systemName: item.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(item.accentColor)
            }
            .frame(width: 42, height: 42)
        }
    }

    @ViewBuilder
    private var trailingActions: some View {
        if isCopied {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(hex: "32D74B"))
                .frame(width: 24, height: 24)
        } else if isHovering {
            HStack(spacing: 6) {
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.62))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.white.opacity(0.07)))
                }
                .buttonStyle(.plain)
                .help("Copy")

                if !item.isDemo {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(red: 1.0, green: 0.271, blue: 0.227).opacity(0.82))
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(Color(red: 1.0, green: 0.271, blue: 0.227).opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .help("Delete")
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }
}
