import SwiftUI

/// Files Tray module — full-shell Figma implementation.
/// CSS source: /DesignReference/Css/FilesTray.css
struct FilesTrayModuleView: View {
    @Environment(AppState.self) private var appState

    private struct TrayFile: Identifiable {
        let id = UUID()
        let name: String
        let gradientStart: Color
        let gradientEnd: Color
        let sfSymbol: String
    }

    private let files: [TrayFile] = [
        TrayFile(name: "hero_image.png", gradientStart: Color(hex: "0A84FF"), gradientEnd: Color(hex: "00468D"), sfSymbol: "photo.fill"),
        TrayFile(name: "brief.pdf",      gradientStart: Color(hex: "FF453A"), gradientEnd: Color(hex: "8B0000"), sfSymbol: "doc.fill"),
        TrayFile(name: "design.fig",     gradientStart: Color(hex: "A259FF"), gradientEnd: Color(hex: "5E0DAC"), sfSymbol: "squareshape.controlhandles.on.squareshape.controlhandles"),
        TrayFile(name: "report.xlsx",    gradientStart: Color(hex: "30D158"), gradientEnd: Color(hex: "1A6632"), sfSymbol: "tablecells.fill"),
    ]

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
            statusLeft: "4 FILES",
            statusRight: "DROP TO ADD",
            actionButton: { makeDestructiveActionButton(icon: "trash", label: "CLEAR") }
        ) {
            // Drop Zone Container
            // CSS: padding 12px, bg rgba(255,255,255,0.02), border 1px dashed rgba(255,255,255,0.15), radius 12px
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                Color.white.opacity(0.15),
                                style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                            )
                    )

                // Files grid — 4-column LazyVGrid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 16) {
                    ForEach(files) { file in
                        fileThumbnail(file)
                    }
                }
                .padding(12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - File Thumbnail
    // CSS outer: 72×72 bg rgba(255,255,255,0.08) radius 8px
    // CSS inner: 60×60 gradient rect radius 6px
    // CSS label: Inter 400 10px rgba(255,255,255,0.4) centered

    @ViewBuilder
    private func fileThumbnail(_ file: TrayFile) -> some View {
        VStack(spacing: 8) {
            // Outer container
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 72, height: 72)

                // Inner gradient rect
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [file.gradientStart, file.gradientEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: file.sfSymbol)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.4))
                    )
            }

            // File name label — CSS: Inter 400 10px rgba(255,255,255,0.4) centered
            Text(file.name)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.4))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 72)
                .multilineTextAlignment(.center)
        }
    }
}
