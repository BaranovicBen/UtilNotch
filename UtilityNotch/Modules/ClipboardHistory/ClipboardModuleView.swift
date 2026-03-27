import SwiftUI
import AppKit

/// Clipboard History module — full-shell Figma implementation, wired to NSPasteboard.
/// CSS source: template.css + DESIGN.md (no dedicated clipboard.css)
struct ClipboardModuleView: View {
    @Environment(AppState.self) private var appState

    enum ClipType { case code, url, image, text }

    struct ClipItem: Identifiable {
        let id: UUID
        let type: ClipType
        let primary: String
        let meta: String
        let timestamp: String
        var imageSize: String? = nil
        var isDummy: Bool = false
    }

    // 4 dummy items shown when pasteboard is empty / on first launch
    private static let dummyItems: [ClipItem] = [
        ClipItem(id: UUID(), type: .code,
                 primary: "export const useClipboard = () => { return useContext(Clipboa…",
                 meta: "Code Snippet", timestamp: "12:45:02", isDummy: true),
        ClipItem(id: UUID(), type: .url,
                 primary: "https://developer.apple.com/design/human-interface-guidel...",
                 meta: "URL", timestamp: "11:20:15", isDummy: true),
        ClipItem(id: UUID(), type: .image,
                 primary: "ui_concept_v4_final.png",
                 meta: "Image", timestamp: "10:05:44", imageSize: "2.4MB", isDummy: true),
        ClipItem(id: UUID(), type: .text,
                 primary: "The Obsidian Instrument treats the interface as a high-fidelity instrument…",
                 meta: "Text", timestamp: "09:30:11", isDummy: true),
    ]

    @State private var items: [ClipItem] = Self.dummyItems
    @State private var flashingID: UUID? = nil
    @State private var clearConfirmActive: Bool = false
    @State private var clearConfirmTimer: Timer? = nil
    @State private var pbChangeCount: Int = NSPasteboard.general.changeCount
    @State private var pollTimer: Timer? = nil

    var body: some View {
        ModuleShellView(
            moduleTitle: "Clipboard History",
            moduleIcon: "doc.on.clipboard",
            modules: shellNavItems(appState: appState),
            activeModuleID: appState.activeModuleID,
            onModuleSelect: { id in
                withAnimation(.spring(duration: 0.28, bounce: 0.16)) {
                    appState.selectModule(id)
                }
            },
            statusDotColor: Color(hex: "32D74B"),
            statusLeft: "CLIPBOARD SYNC ACTIVE",
            statusRight: "\(items.filter { !$0.isDummy }.count + (items.allSatisfy(\.isDummy) ? items.count : 0)) ITEMS STORED",
            actionButton: {
                AnyView(
                    Button {
                        if clearConfirmActive {
                            clearAll()
                        } else {
                            activateClearConfirm()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.system(size: 10, weight: .medium))
                            Text(clearConfirmActive ? "CONFIRM?" : "CLEAR ALL")
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
                )
            }
        ) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(items) { item in
                        clipCard(item)
                    }
                }
            }
        }
        .onAppear {
            pbChangeCount = NSPasteboard.general.changeCount
            startPolling()
        }
        .onDisappear {
            pollTimer?.invalidate(); pollTimer = nil
            clearConfirmTimer?.invalidate(); clearConfirmTimer = nil
        }
    }

    // MARK: - Polling

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                let current = NSPasteboard.general.changeCount
                if current != pbChangeCount {
                    pbChangeCount = current
                    checkNewClipboardContent()
                }
            }
        }
    }

    private func checkNewClipboardContent() {
        guard let str = NSPasteboard.general.string(forType: .string), !str.isEmpty else { return }
        let trimmed = str.prefix(200).description
        let type: ClipType
        let meta: String
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            type = .url; meta = "URL"
        } else if trimmed.contains("\n") || trimmed.count > 80 {
            type = .text; meta = "Text"
        } else {
            type = .code; meta = "Code Snippet"
        }
        let formatter = DateFormatter(); formatter.dateFormat = "HH:mm:ss"
        let newItem = ClipItem(id: UUID(), type: type, primary: trimmed,
                               meta: meta, timestamp: formatter.string(from: Date()), isDummy: false)
        withAnimation(.easeOut(duration: 0.2)) {
            // Replace dummy data on first real capture
            if items.allSatisfy(\.isDummy) { items = [] }
            items.insert(newItem, at: 0)
            if items.count > 20 { items.removeLast() }
        }
    }

    // MARK: - CLEAR ALL

    private func activateClearConfirm() {
        clearConfirmActive = true
        clearConfirmTimer?.invalidate()
        clearConfirmTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            Task { @MainActor in clearConfirmActive = false }
        }
    }

    private func clearAll() {
        clearConfirmTimer?.invalidate()
        clearConfirmActive = false
        withAnimation(.easeOut(duration: 0.2)) {
            items = Self.dummyItems
        }
    }

    // MARK: - Clip Card
    // Card: bg rgba(255,255,255,0.03), radius 8px, padding 12px (from template/todo CSS)
    // Flash on tap: white 8% for 150ms then returns

    @ViewBuilder
    private func clipCard(_ item: ClipItem) -> some View {
        HStack(spacing: 12) {
            if item.type == .image {
                imageCard(item)
            } else {
                textCard(item)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(flashingID == item.id
                      ? Color.white.opacity(0.08)
                      : Color.white.opacity(0.03))
        )
        .overlay(alignment: .topTrailing) {
            if item.isDummy {
                Text("DEMO")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.3))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Color.white.opacity(0.07))
                    )
                    .padding(6)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { copyItem(item) }
    }

    // TEXT / CODE / URL variant
    @ViewBuilder
    private func textCard(_ item: ClipItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            switch item.type {
            case .code:
                Text(item.primary)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(1).truncationMode(.tail)
            case .url:
                Text(item.primary)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(hex: "0A84FF"))
                    .lineLimit(1).truncationMode(.tail)
            default:
                Text(item.primary)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(2).truncationMode(.tail)
            }
            HStack(spacing: 4) {
                Text(item.timestamp)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.35))
                Circle().fill(Color.white.opacity(0.2)).frame(width: 3, height: 3)
                Text(item.meta)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.35))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // IMAGE variant: thumbnail placeholder + info
    @ViewBuilder
    private func imageCard(_ item: ClipItem) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(LinearGradient(colors: [Color(hex: "1C3A5E"), Color(hex: "0A1628")],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(Image(systemName: "photo").font(.system(size: 14)).foregroundStyle(Color.white.opacity(0.4)))
            .frame(width: 48, height: 48)

        VStack(alignment: .leading, spacing: 4) {
            Text(item.primary)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.85))
                .lineLimit(1)
            HStack(spacing: 4) {
                Text(item.timestamp)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.35))
                if let size = item.imageSize {
                    Circle().fill(Color.white.opacity(0.2)).frame(width: 3, height: 3)
                    Text(size)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.35))
                }
                Circle().fill(Color.white.opacity(0.2)).frame(width: 3, height: 3)
                Text(item.meta)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.35))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Copy Action

    private func copyItem(_ item: ClipItem) {
        guard !item.isDummy else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.primary, forType: .string)
        // Flash: white 8% for 150ms
        withAnimation(.easeOut(duration: 0.05)) { flashingID = item.id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeOut(duration: 0.1)) { flashingID = nil }
        }
    }
}
