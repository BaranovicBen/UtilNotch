import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// File Converter module — full-shell Figma implementation with wired interactions.
/// CSS source: /DesignReference/Css/FileConverter.css
struct ConverterModuleView: View {
    @Environment(AppState.self) private var appState

    // Format category pills: tapping highlights the selected category
    private let formats = ["IMAGE", "DOCUMENT", "AUDIO", "VIDEO", "ARCHIVE"]
    @State private var selectedFormat: String = "IMAGE"

    // Drop zone / file selection state
    @State private var isDragTargeted: Bool = false
    @State private var droppedFileName: String? = nil
    @State private var conversionStatus: ConverterStatus = .idle

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
                dropZone
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)

                // Format pills
                formatPills
                    .padding(.top, 24)
            }
        }
        .onAppear {
            // Pick up any file URL routed here from a panel-level drop
            if let url = appState.pendingFileURL {
                droppedFileName = url.lastPathComponent
                appState.pendingFileURL = nil
            }
        }
        .onChange(of: appState.pendingFileURL) { _, url in
            // React when Files Tray sends a file while this module is already active
            guard let url else { return }
            droppedFileName = url.lastPathComponent
            appState.pendingFileURL = nil
        }
        .onChange(of: isDragTargeted) { _, targeted in
            if targeted { appState.dismissalLocks.insert(.dragDrop) }
            else { appState.dismissalLocks.remove(.dragDrop) }
        }
    }

    // MARK: - Drop Zone
    // CSS: bg rgba(255,255,255,0.02), border 1px dashed rgba(255,255,255,0.18), radius 12px

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isDragTargeted ? Color.white.opacity(0.05) : Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            isDragTargeted ? Color.white.opacity(0.4) : Color.white.opacity(0.18),
                            style: StrokeStyle(lineWidth: isDragTargeted ? 1.5 : 1, dash: isDragTargeted ? [] : [6, 4])
                        )
                )
                .animation(.easeInOut(duration: 0.15), value: isDragTargeted)

            if let fileName = droppedFileName {
                // File selected state
                VStack(spacing: 0) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .padding(.bottom, 16)
                    Text(fileName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.65))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 20)
                    if conversionStatus == .converting {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.top, 10)
                    } else if case .done = conversionStatus {
                        Text("Done")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color(hex: "32D74B"))
                            .padding(.top, 6)
                    }
                }
            } else {
                VStack(spacing: 0) {
                    Image(systemName: isDragTargeted ? "arrow.down.circle.fill" : "square.and.arrow.up")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(isDragTargeted ? Color.white.opacity(0.6) : Color.white.opacity(0.2))
                        .padding(.bottom, 16)
                    Text(isDragTargeted ? "Release to convert" : "Drop files to convert")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.45))
                        .padding(.bottom, 4)
                    Text("or click to browse")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.25))
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { openFilePicker() }
        .onDrop(of: [.fileURL], isTargeted: $isDragTargeted) { providers in
            handleDrop(providers)
        }
    }

    // MARK: - Format Pills
    // CSS: padding 3px 12px 4.5px, bg rgba(255,255,255,0.06) unselected / 0.12 selected, radius 9999px

    private var formatPills: some View {
        HStack(spacing: 8) {
            ForEach(formats, id: \.self) { format in
                Button {
                    withAnimation(.easeOut(duration: 0.12)) { selectedFormat = format }
                } label: {
                    Text(format)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(selectedFormat == format ? Color.white : Color.white.opacity(0.8))
                        .kerning(0.55)
                        .padding(.top, 3)
                        .padding(.bottom, 4.5)
                        .padding(.horizontal, 12)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(selectedFormat == format ? 0.12 : 0.06))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Interactions

    private func openFilePicker() {
        appState.dismissalLocks.insert(.pickerOpen)
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            DispatchQueue.main.async {
                appState.dismissalLocks.remove(.pickerOpen)
                if response == .OK, let url = panel.url {
                    droppedFileName = url.lastPathComponent
                    conversionStatus = .idle
                }
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                DispatchQueue.main.async {
                    droppedFileName = url.lastPathComponent
                    conversionStatus = .idle
                    mockConvert()
                }
            }
        }
        return true
    }

    private func mockConvert() {
        guard droppedFileName != nil else { return }
        conversionStatus = .converting
        appState.dismissalLocks.insert(.activeConvert)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.2)) { conversionStatus = .done }
            appState.dismissalLocks.remove(.activeConvert)
        }
    }
}

private enum ConverterStatus: Equatable {
    case idle, converting, done
}
