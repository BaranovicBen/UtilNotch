import SwiftUI
import UniformTypeIdentifiers

/// File Converter — clean, compact UI with pill format selectors and minimal drop zone.
struct FileConverterView: View {
    @Environment(AppState.self) private var appState
    @State private var inputFormat: FileFormat = .png
    @State private var outputFormat: FileFormat = .jpg
    @State private var selectedFile: String = ""
    @State private var conversionStatus: ConversionStatus = .idle
    @State private var isDragTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("File Converter", systemImage: "doc.badge.gearshape")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.bottom, 16)

            // Inline format row: [FROM pills] → [TO pills]
            VStack(spacing: 8) {
                HStack(spacing: 0) {
                    formatPills(selection: $inputFormat, label: "From")
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 18)
                    Spacer(minLength: 8)
                    formatPills(selection: $outputFormat, label: "To")
                }
            }
            .padding(.bottom, 16)

            // Drop zone — minimal, clear
            dropZone
                .padding(.bottom, 12)

            // Convert button
            convertButton

            // Status message
            if case .done(let message) = conversionStatus {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .offset(y: 2)))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { appState.dismissalLocks.remove(.activeEditing) }
        .onDisappear {
            appState.dismissalLocks.remove(.dragDrop)
            if conversionStatus != .converting { appState.dismissalLocks.remove(.activeConvert) }
        }
    }

    // MARK: - Format Pills

    @ViewBuilder
    private func formatPills(selection: Binding<FileFormat>, label: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.leading, 2)

            HStack(spacing: 4) {
                ForEach(FileFormat.allCases) { fmt in
                    Button {
                        withAnimation(.easeOut(duration: 0.12)) {
                            selection.wrappedValue = fmt
                        }
                    } label: {
                        Text(fmt.label)
                            .font(.caption2.weight(selection.wrappedValue == fmt ? .semibold : .regular))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(selection.wrappedValue == fmt
                                          ? Color.white.opacity(0.15)
                                          : Color.white.opacity(0.04))
                            )
                            .foregroundStyle(selection.wrappedValue == fmt ? .white : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Drop Zone

    @ViewBuilder
    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isDragTargeted ? Color.blue.opacity(0.7) : Color.white.opacity(0.10),
                    style: StrokeStyle(lineWidth: isDragTargeted ? 1.5 : 1, dash: isDragTargeted ? [] : [5, 4])
                )
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isDragTargeted ? Color.blue.opacity(0.06) : Color.clear)
                )
                .frame(height: 72)

            HStack(spacing: 8) {
                Image(systemName: isDragTargeted ? "arrow.down.circle.fill" : "arrow.down.doc")
                    .font(.system(size: 16))
                    .foregroundStyle(isDragTargeted ? Color.blue : Color.white.opacity(0.25))

                if selectedFile.isEmpty {
                    Text(isDragTargeted ? "Release to select" : "Drop file · click · ⌘V")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.25))
                } else {
                    Text(selectedFile)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Button {
                        selectedFile = ""
                        conversionStatus = .idle
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
        }
        .contentShape(Rectangle())
        .onTapGesture { mockSelectFile() }
        .onDrop(of: [.fileURL], isTargeted: $isDragTargeted) { providers in
            handleDrop(providers)
        }
        .onChange(of: isDragTargeted) { _, targeted in
            if targeted { appState.dismissalLocks.insert(.dragDrop) }
            else { appState.dismissalLocks.remove(.dragDrop) }
        }
    }

    // MARK: - Convert Button

    @ViewBuilder
    private var convertButton: some View {
        Button(action: mockConvert) {
            HStack(spacing: 6) {
                if conversionStatus == .converting {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.75)
                }
                Text(conversionStatus.buttonLabel)
                    .font(.callout.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selectedFile.isEmpty
                          ? Color.white.opacity(0.05)
                          : Color.blue.opacity(0.55))
            )
            .foregroundStyle(selectedFile.isEmpty ? Color.white.opacity(0.3) : Color.white)
        }
        .buttonStyle(.plain)
        .disabled(selectedFile.isEmpty || conversionStatus == .converting)
    }

    // MARK: - Actions

    private func mockSelectFile() {
        appState.dismissalLocks.insert(.activeEditing)
        selectedFile = "example_image.\(inputFormat.ext)"
        conversionStatus = .idle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            appState.dismissalLocks.remove(.activeEditing)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                DispatchQueue.main.async {
                    self.selectedFile = url.lastPathComponent
                    self.conversionStatus = .idle
                }
            }
        }
        return true
    }

    private func mockConvert() {
        conversionStatus = .converting
        appState.dismissalLocks.insert(.activeConvert)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.2)) {
                self.conversionStatus = .done("\(self.inputFormat.label) → \(self.outputFormat.label)")
            }
            self.appState.dismissalLocks.remove(.activeConvert)
        }
    }
}

// MARK: - Models

private enum FileFormat: String, CaseIterable, Identifiable {
    case png, jpg, heic, pdf, webp

    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
    var ext: String { rawValue }
}

private enum ConversionStatus: Equatable {
    case idle
    case converting
    case done(String)

    var buttonLabel: String {
        switch self {
        case .idle: return "Convert"
        case .converting: return "Converting…"
        case .done: return "Convert Again"
        }
    }
}
