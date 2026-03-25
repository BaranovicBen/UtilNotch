import SwiftUI

/// Clipboard History module — full-shell Figma implementation.
/// CSS source: template.css + DESIGN.md (no dedicated clipboard.css)
struct ClipboardModuleView: View {
    @Environment(AppState.self) private var appState

    enum ClipType { case code, url, image, text }

    private struct ClipItem: Identifiable {
        let id = UUID()
        let type: ClipType
        let primary: String
        let meta: String
        let timestamp: String
        var imageSize: String? = nil
    }

    private let items: [ClipItem] = [
        ClipItem(type: .code,
                 primary: "export const useClipboard = () => { return useContext(Clipboa…",
                 meta: "Code Snippet",
                 timestamp: "12:45:02"),
        ClipItem(type: .url,
                 primary: "https://developer.apple.com/design/human-interface-guidel...",
                 meta: "URL",
                 timestamp: "11:20:15"),
        ClipItem(type: .image,
                 primary: "ui_concept_v4_final.png",
                 meta: "Image",
                 timestamp: "10:05:44",
                 imageSize: "2.4MB"),
        ClipItem(type: .text,
                 primary: "The Obsidian Instrument treats the interface as a high-fidelity instrument…",
                 meta: "Text",
                 timestamp: "09:30:11"),
    ]

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
            statusRight: "5 ITEMS STORED",
            actionButton: { makeDestructiveActionButton(icon: "trash", label: "CLEAR ALL") }
        ) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(items) { item in
                        clipCard(item)
                    }
                }
            }
        }
    }

    // MARK: - Clip Card
    // Card: bg rgba(255,255,255,0.03), radius 8px, padding 12px (from template/todo CSS)

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
                .fill(Color.white.opacity(0.03))
        )
    }

    // TEXT / CODE / URL variant
    @ViewBuilder
    private func textCard(_ item: ClipItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Primary content
            switch item.type {
            case .code:
                // CSS: SF Mono, truncated single line, rgba(255,255,255,0.85)
                Text(item.primary)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.tail)
            case .url:
                // CSS: #0A84FF full opacity, SF Pro regular, truncated
                Text(item.primary)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(hex: "0A84FF"))
                    .lineLimit(1)
                    .truncationMode(.tail)
            case .text:
                // CSS: SF Pro regular, max 2 lines, rgba(255,255,255,0.85)
                Text(item.primary)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(2)
                    .truncationMode(.tail)
            case .image:
                EmptyView()
            }

            // Meta line: timestamp · type
            // CSS: SF Mono 11px rgba(255,255,255,0.35)
            HStack(spacing: 4) {
                Text(item.timestamp)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.35))
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 3, height: 3)
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
        // Thumbnail placeholder: 48×48px, radius 6px (design-system inner radius)
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(hex: "1C3A5E"), Color(hex: "0A1628")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white.opacity(0.4))
            )
            .frame(width: 48, height: 48)

        VStack(alignment: .leading, spacing: 4) {
            // Filename: SF Pro regular, rgba(255,255,255,0.85)
            Text(item.primary)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.85))
                .lineLimit(1)

            // Meta: timestamp · size · type
            HStack(spacing: 4) {
                Text(item.timestamp)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.35))
                if let size = item.imageSize {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 3, height: 3)
                    Text(size)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.35))
                }
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 3, height: 3)
                Text(item.meta)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.35))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
