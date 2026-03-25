import SwiftUI

/// File Converter module — full-shell Figma implementation.
/// CSS source: /DesignReference/Css/FileConverter.css
struct ConverterModuleView: View {
    @Environment(AppState.self) private var appState

    // Format pills: IMAGE · DOCUMENT · AUDIO · VIDEO · ARCHIVE
    private let formats = ["IMAGE", "DOCUMENT", "AUDIO", "VIDEO", "ARCHIVE"]

    var body: some View {
        ModuleShellView(
            moduleTitle: "File Converter",
            moduleIcon: "arrow.2.squarepath",
            modules: shellNavItems(appState: appState),
            activeModuleID: appState.activeModuleID,
            onModuleSelect: { id in
                withAnimation(.spring(duration: 0.28, bounce: 0.16)) {
                    appState.selectModule(id)
                }
            },
            statusDotColor: Color.white.opacity(0.2),
            statusLeft: "LOCAL CONVERSION ONLY",
            statusRight: "NO CLOUD · PRIVATE",
            actionButton: nil
        ) {
            VStack(spacing: 0) {
                // Drop zone
                // CSS: bg rgba(255,255,255,0.02), border 1px dashed rgba(255,255,255,0.18), radius 12px
                dropZone
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)

                // Format pills
                // CSS: margin top 24px, gap 8px, pills bg rgba(255,255,255,0.06) radius 9999px
                formatPills
                    .padding(.top, 24)
            }
        }
    }

    // MARK: - Drop Zone
    // CSS: bg rgba(255,255,255,0.02), border 1px dashed rgba(255,255,255,0.18), radius 12px
    // Icon: SF Symbol rgba(255,255,255,0.2)
    // Primary text: Inter 500 14px rgba(255,255,255,0.45)
    // Secondary text: Liberation Mono 400 12px rgba(255,255,255,0.25)

    private var dropZone: some View {
        ZStack {
            // Dashed border background — CSS exception for universally understood affordance
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            Color.white.opacity(0.18),
                            style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                        )
                )

            VStack(spacing: 0) {
                // Upload icon
                // CSS: rgba(255,255,255,0.2), ~21×27px icon
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.2))
                    .padding(.bottom, 16)

                // Primary text
                // CSS: Inter 500 14px rgba(255,255,255,0.45)
                Text("Drop files to convert")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .padding(.bottom, 4)

                // Secondary text
                // CSS: Liberation Mono 400 12px rgba(255,255,255,0.25) letter-spacing -0.3px
                Text("or drag from Finder")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.25))
            }
        }
    }

    // MARK: - Format Pills
    // CSS: padding 3px 12px 4.5px, bg rgba(255,255,255,0.06), radius 9999px
    // Text: SF Pro semibold 11px letter-spacing 0.55px rgba(255,255,255,0.8)

    private var formatPills: some View {
        HStack(spacing: 8) {
            ForEach(formats, id: \.self) { format in
                Text(format)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .kerning(0.55)
                    .padding(.top, 3)
                    .padding(.bottom, 4.5)
                    .padding(.horizontal, 12)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                    )
            }
        }
    }
}
