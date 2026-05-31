import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ConverterModuleView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var store = FileConverterStore()
    @State private var isDragTargeted = false

    private var statusRight: String {
        switch store.state {
        case .done: return "COMPLETE"
        case .failed: return "NEEDS ATTENTION"
        case .detecting, .converting: return "WORKING"
        case .idle: return "NO CLOUD"
        }
    }

    var body: some View {
        ModuleShellView(
            moduleTitle: "File Converter",
            moduleIcon: "doc.badge.gearshape",
            modules: shellNavItems(appState: appState),
            activeModuleID: appState.activeModuleID,
            onModuleSelect: { id in
                withAnimation(reduceMotion ? UNMotion.reduced : UNMotion.moduleSwitch) {
                    appState.selectModule(id)
                }
            },
            statusDotColor: store.state.isActive ? UNConstants.successGreen : Color.white.opacity(0.2),
            statusLeft: "LOCAL CONVERSION",
            statusRight: statusRight,
            actionButton: nil
        ) {
            VStack(spacing: 10) {
                dropZone
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                outputTypeStrip
            }
        }
        .onAppear {
            if let url = appState.pendingFileURL {
                select(url)
                appState.pendingFileURL = nil
            }
        }
        .onChange(of: appState.pendingFileURL) { _, url in
            guard let url else { return }
            select(url)
            appState.pendingFileURL = nil
        }
        .onChange(of: isDragTargeted) { _, targeted in
            if targeted { appState.dismissalLocks.insert(.dragDrop) }
            else { appState.dismissalLocks.remove(.dragDrop) }
        }
        .onChange(of: store.state.label) { _, _ in
            updateConversionActivity()
        }
    }

    private var dropZone: some View {
        Button {
            openFilePicker()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: UNConstants.tileCornerRadius, style: .continuous)
                    .fill(isDragTargeted ? UNConstants.rowHoverSurface : UNConstants.insetSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: UNConstants.tileCornerRadius, style: .continuous)
                            .strokeBorder(
                                isDragTargeted ? UNConstants.focusBorder : Color.white.opacity(0.18),
                                style: StrokeStyle(lineWidth: isDragTargeted ? 1.5 : 1, dash: isDragTargeted ? [] : [6, 4])
                            )
                    )

                VStack(spacing: 9) {
                    Image(systemName: dropZoneIcon)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(dropZoneTint)

                    Text(dropZoneTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(UNConstants.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 20)

                    Text(store.state.label)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(UNConstants.textTertiary)
                        .lineLimit(1)

                    if case .converting(let progress) = store.state {
                        ProgressView(value: max(progress, 0.04))
                            .progressViewStyle(.linear)
                            .tint(UNConstants.fileVideoEnd)
                            .frame(width: 150)
                    }

                    if canConvert {
                        Button {
                            convert()
                        } label: {
                            Text("Convert to \(store.selectedOutputType?.displayName ?? "Output")")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(UNConstants.textPrimary)
                                .padding(.horizontal, 12)
                                .frame(height: UNConstants.compactControlHeight)
                                .background(Capsule().fill(UNConstants.controlSurface))
                        }
                        .buttonStyle(.pressFeedback)
                        .disabled(store.state.isActive)
                    }
                }
                .padding(.horizontal, 18)
            }
        }
        .buttonStyle(.plain)
        .onDrop(of: [.fileURL], isTargeted: $isDragTargeted) { providers in
            handleDrop(providers)
        }
        .animation(reduceMotion ? UNMotion.reduced : UNMotion.hover, value: isDragTargeted)
    }

    private var outputTypeStrip: some View {
        HStack(spacing: 7) {
            if store.availableOutputTypes.isEmpty {
                Text("DROP FILE TO SHOW FORMATS")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(UNConstants.textTertiary)
                    .frame(height: UNConstants.compactControlHeight)
            } else {
                ForEach(store.availableOutputTypes, id: \.self) { type in
                    Button {
                        withAnimation(reduceMotion ? UNMotion.reduced : UNMotion.tap) {
                            store.selectedOutputType = type
                        }
                    } label: {
                        Text(type.displayName)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(type == store.selectedOutputType ? UNConstants.textPrimary : UNConstants.textSecondary)
                            .padding(.horizontal, 10)
                            .frame(height: UNConstants.compactControlHeight)
                            .background(
                                Capsule()
                                    .fill(type == store.selectedOutputType ? UNConstants.selectedSurface : UNConstants.controlSurface)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(height: UNConstants.compactControlHeight)
    }

    private var dropZoneIcon: String {
        switch store.state {
        case .done: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle"
        case .detecting, .converting: return "arrow.triangle.2.circlepath"
        default: return store.selectedFileURL == nil ? "square.and.arrow.down" : "doc.badge.gearshape"
        }
    }

    private var dropZoneTitle: String {
        if let url = store.selectedFileURL { return url.lastPathComponent }
        return isDragTargeted ? "Release to convert" : "Drop a file or click to browse"
    }

    private var dropZoneTint: Color {
        switch store.state {
        case .done: return UNConstants.successGreen
        case .failed: return UNConstants.destructiveRed
        default: return isDragTargeted ? UNConstants.accentBlue : UNConstants.textSecondary
        }
    }

    private var canConvert: Bool {
        store.selectedFileURL != nil && store.selectedOutputType != nil && !store.state.isActive
    }

    @MainActor
    private func openFilePicker() {
        appState.dismissalLocks.insert(.pickerOpen)
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            Task { @MainActor in
                appState.dismissalLocks.remove(.pickerOpen)
                if response == .OK, let url = panel.url {
                    select(url)
                }
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                Task { @MainActor in select(url) }
            }
        }
        return true
    }

    @MainActor
    private func select(_ url: URL) {
        withAnimation(reduceMotion ? UNMotion.reduced : UNMotion.listItem) {
            store.selectFile(url)
        }
    }

    @MainActor
    private func convert() {
        guard canConvert else { return }
        appState.dismissalLocks.insert(.activeConvert)
        updateConversionActivity()
        Task {
            await store.convert()
            await MainActor.run {
                appState.dismissalLocks.remove(.activeConvert)
                updateConversionActivity()
            }
        }
    }

    @MainActor
    private func updateConversionActivity() {
        appState.liveActivities.removeAll { $0.destinationModuleID == "fileConverter" }
        guard store.state.isActive, let fileName = store.selectedFileURL?.lastPathComponent else { return }
        let progress: Double?
        if case .converting(let value) = store.state {
            progress = max(value, 0.04)
        } else {
            progress = nil
        }
        appState.liveActivities.append(
            LiveActivity(
                title: "Converting",
                subtitle: fileName,
                icon: "doc.badge.gearshape",
                progress: progress,
                priority: 85,
                timestamp: Date(),
                destinationModuleID: "fileConverter"
            )
        )
    }
}
