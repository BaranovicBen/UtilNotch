import AppKit
import SwiftUI

enum ClipboardContentKind: String, Codable, CaseIterable, Identifiable {
    case code
    case url
    case image
    case file
    case text

    var id: String { rawValue }

    var filterTitle: String {
        switch self {
        case .code: "Code"
        case .url: "Links"
        case .image: "Images"
        case .file: "Files"
        case .text: "Text"
        }
    }

    var icon: String {
        switch self {
        case .code: "curlybraces"
        case .url: "link"
        case .image: "photo"
        case .file: "doc"
        case .text: "text.alignleft"
        }
    }

    var accentColor: Color {
        switch self {
        case .code: Color(hex: "BF5AF2")
        case .url: Color(hex: "0A84FF")
        case .image: Color(hex: "30D158")
        case .file: Color(hex: "FF9F0A")
        case .text: Color.white.opacity(0.48)
        }
    }
}

enum ClipboardHistorySettingsKey {
    static let maxItems = "clipboardHistory.maxItems"
    static let defaultMaxItems = 30
}

struct ClipboardHistoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    let kind: ClipboardContentKind
    let preview: String
    let detail: String
    let createdAt: Date
    let plainText: String?
    let fileURLString: String?
    let imageData: Data?
    let isDemo: Bool

    init(
        id: UUID = UUID(),
        kind: ClipboardContentKind,
        preview: String,
        detail: String,
        createdAt: Date = Date(),
        plainText: String? = nil,
        fileURLString: String? = nil,
        imageData: Data? = nil,
        isDemo: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.preview = preview
        self.detail = detail
        self.createdAt = createdAt
        self.plainText = plainText
        self.fileURLString = fileURLString
        self.imageData = imageData
        self.isDemo = isDemo
    }

    var icon: String {
        kind.icon
    }

    var accentColor: Color {
        kind.accentColor
    }

    var timestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: createdAt)
    }

    var relativeTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: .now)
    }

    var searchableText: String {
        [preview, detail, plainText, fileURLString]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    var copySignature: String {
        switch kind {
        case .image:
            return "image:\(imageData?.count ?? 0):\(detail)"
        case .file:
            return "file:\(fileURLString ?? preview)"
        default:
            return "\(kind.rawValue):\(plainText ?? preview)"
        }
    }

    static let demoItems: [ClipboardHistoryItem] = [
        ClipboardHistoryItem(
            kind: .code,
            preview: "export const useClipboard = () => useContext(ClipboardContext)",
            detail: "Code Snippet",
            createdAt: Date(timeIntervalSinceNow: -82),
            plainText: "export const useClipboard = () => useContext(ClipboardContext)",
            isDemo: true
        ),
        ClipboardHistoryItem(
            kind: .url,
            preview: "https://developer.apple.com/design/human-interface-guidelines",
            detail: "URL",
            createdAt: Date(timeIntervalSinceNow: -1840),
            plainText: "https://developer.apple.com/design/human-interface-guidelines",
            isDemo: true
        ),
        ClipboardHistoryItem(
            kind: .image,
            preview: "ui_concept_v4_final.png",
            detail: "Image 1440 x 900",
            createdAt: Date(timeIntervalSinceNow: -5160),
            isDemo: true
        ),
        ClipboardHistoryItem(
            kind: .file,
            preview: "ReleaseNotes.md",
            detail: "Markdown File",
            createdAt: Date(timeIntervalSinceNow: -7410),
            fileURLString: "/Users/benjamin/Documents/ReleaseNotes.md",
            isDemo: true
        )
    ]
}

@Observable
final class ClipboardHistoryStore {
    var items: [ClipboardHistoryItem] = []
    var selectedKind: ClipboardContentKind?
    var recentlyCopiedID: UUID?
    var isMonitoring: Bool = false

    @ObservationIgnored private var changeCount: Int = NSPasteboard.general.changeCount
    @ObservationIgnored private var pollTimer: Timer?
    @ObservationIgnored private var persistence = PersistenceManager.shared

    private var historyLimit: Int {
        let stored = UserDefaults.standard.integer(forKey: ClipboardHistorySettingsKey.maxItems)
        let value = stored == 0 ? ClipboardHistorySettingsKey.defaultMaxItems : stored
        return min(max(value, 5), 200)
    }

    var isShowingDemoItems: Bool { items.isEmpty }

    var visibleItems: [ClipboardHistoryItem] {
        let source = isShowingDemoItems ? ClipboardHistoryItem.demoItems : items
        guard let selectedKind else { return source }
        return source.filter { $0.kind == selectedKind }
    }

    var storedItemCount: Int {
        isShowingDemoItems ? ClipboardHistoryItem.demoItems.count : items.count
    }

    func onAppear() {
        items = persistence.load([ClipboardHistoryItem].self, key: .clipboardHistory) ?? []
        if trimToHistoryLimit() {
            save()
        }
        changeCount = NSPasteboard.general.changeCount
        captureCurrentPasteboard()
        startMonitoring()
    }

    func onDisappear() {
        pollTimer?.invalidate()
        pollTimer = nil
        isMonitoring = false
    }

    func clearHistory() {
        withAnimation(UNMotion.listItem) {
            items.removeAll()
        }
        save()
    }

    func delete(_ item: ClipboardHistoryItem) {
        guard !item.isDemo else { return }
        withAnimation(UNMotion.listItem) {
            items.removeAll { $0.id == item.id }
        }
        save()
    }

    func copy(_ item: ClipboardHistoryItem) {
        guard !item.isDemo else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.kind {
        case .image:
            if let data = item.imageData, let image = NSImage(data: data) {
                pasteboard.writeObjects([image])
            }
        case .file:
            if let rawURL = item.fileURLString, let url = resolvedFileURL(from: rawURL) {
                pasteboard.writeObjects([url as NSURL])
            }
        default:
            pasteboard.setString(item.plainText ?? item.preview, forType: .string)
        }

        changeCount = pasteboard.changeCount
        withAnimation(UNMotion.flashOn) { recentlyCopiedID = item.id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { [weak self] in
            withAnimation(UNMotion.flashOff) { self?.recentlyCopiedID = nil }
        }
    }

    private func startMonitoring() {
        pollTimer?.invalidate()
        isMonitoring = true
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollPasteboard()
            }
        }
    }

    private func pollPasteboard() {
        let current = NSPasteboard.general.changeCount
        guard current != changeCount else { return }
        changeCount = current
        captureCurrentPasteboard()
    }

    private func captureCurrentPasteboard() {
        guard let item = makeItem(from: NSPasteboard.general) else { return }
        insert(item)
    }

    private func insert(_ item: ClipboardHistoryItem) {
        guard !item.preview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        withAnimation(UNMotion.expressive) {
            items.removeAll { $0.copySignature == item.copySignature }
            items.insert(item, at: 0)
            _ = trimToHistoryLimit()
        }
        save()
    }

    @discardableResult
    private func trimToHistoryLimit() -> Bool {
        if items.count > historyLimit {
            items.removeLast(items.count - historyLimit)
            return true
        }
        return false
    }

    private func save() {
        persistence.save(items, key: .clipboardHistory)
    }

    private func makeItem(from pasteboard: NSPasteboard) -> ClipboardHistoryItem? {
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [NSURL],
           let url = urls.first {
            return makeFileItem(url as URL)
        }

        if let image = NSImage(pasteboard: pasteboard) {
            return makeImageItem(image)
        }

        if let text = pasteboard.string(forType: .string) {
            return makeTextItem(text)
        }

        return nil
    }

    private func makeTextItem(_ rawText: String) -> ClipboardHistoryItem? {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let kind: ClipboardContentKind
        let detail: String
        if let url = URL(string: text), url.scheme?.hasPrefix("http") == true {
            kind = .url
            detail = url.host ?? "URL"
        } else if looksLikeCode(text) {
            kind = .code
            detail = "Code Snippet"
        } else {
            kind = .text
            detail = "\(text.count) Characters"
        }

        return ClipboardHistoryItem(
            kind: kind,
            preview: String(text.prefix(500)),
            detail: detail,
            plainText: text
        )
    }

    private func makeFileItem(_ url: URL) -> ClipboardHistoryItem {
        ClipboardHistoryItem(
            kind: .file,
            preview: url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent,
            detail: url.pathExtension.isEmpty ? "File" : "\(url.pathExtension.uppercased()) File",
            fileURLString: url.absoluteString
        )
    }

    private func makeImageItem(_ image: NSImage) -> ClipboardHistoryItem? {
        let size = image.size
        let resized = image.resizedForClipboardHistory(maxDimension: 220)
        guard let data = resized.tiffRepresentation else { return nil }

        return ClipboardHistoryItem(
            kind: .image,
            preview: "Image from Clipboard",
            detail: "Image \(Int(size.width)) x \(Int(size.height))",
            imageData: data
        )
    }

    private func looksLikeCode(_ text: String) -> Bool {
        let codeMarkers = ["func ", "struct ", "class ", "let ", "var ", "import ", "const ", "=>", "{", "};", "</"]
        return (text.contains("\n") && codeMarkers.contains { text.contains($0) })
            || codeMarkers.prefix(8).contains { text.hasPrefix($0) }
    }

    private func resolvedFileURL(from rawURL: String) -> URL? {
        if let url = URL(string: rawURL), url.isFileURL {
            return url
        }
        guard !rawURL.isEmpty else { return nil }
        return URL(fileURLWithPath: rawURL)
    }
}

private extension NSImage {
    func resizedForClipboardHistory(maxDimension: CGFloat) -> NSImage {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        let scale = min(maxDimension / max(width, height), 1)
        let targetSize = NSSize(width: width * scale, height: height * scale)

        let image = NSImage(size: targetSize)
        image.lockFocus()
        draw(in: NSRect(origin: .zero, size: targetSize), from: .zero, operation: .copy, fraction: 1)
        image.unlockFocus()
        return image
    }
}
