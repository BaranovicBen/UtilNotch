import SwiftUI
import UniformTypeIdentifiers

/// File Converter view — with drag-and-drop, paste support, and improved from/to picker.
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
            .padding(.bottom, 14)
            
            // From / To pickers
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("From")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $inputFormat) {
                        ForEach(FileFormat.allCases) { fmt in
                            Text(fmt.label).tag(fmt)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                    .padding(6)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                }
                
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                    .padding(.top, 16)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("To")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $outputFormat) {
                        ForEach(FileFormat.allCases) { fmt in
                            Text(fmt.label).tag(fmt)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                    .padding(6)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.bottom, 14)
            
            // File drop zone
            ZStack {
                RoundedRectangle(cornerRadius: UNConstants.innerCornerRadius, style: .continuous)
                    .strokeBorder(
                        isDragTargeted ? Color.blue.opacity(0.6) : Color.white.opacity(0.15),
                        style: StrokeStyle(lineWidth: isDragTargeted ? 2 : 1.5, dash: isDragTargeted ? [] : [6])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: UNConstants.innerCornerRadius, style: .continuous)
                            .fill(isDragTargeted ? Color.blue.opacity(0.08) : Color.clear)
                    )
                    .frame(height: 90)
                
                VStack(spacing: 6) {
                    Image(systemName: isDragTargeted ? "arrow.down.circle.fill" : "arrow.down.doc")
                        .font(.system(size: 24))
                        .foregroundStyle(isDragTargeted ? .blue : .secondary)
                    
                    if selectedFile.isEmpty {
                        Text("Drop a file, click to select, or ⌘V to paste")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text(selectedFile)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { mockSelectFile() }
            .onDrop(of: [.fileURL], isTargeted: $isDragTargeted) { providers in
                handleDrop(providers)
            }
            .onChange(of: isDragTargeted) { _, targeted in
                appState.isDraggingOver = targeted
            }
            .padding(.bottom, 14)
            
            // Convert button
            Button(action: mockConvert) {
                HStack {
                    if conversionStatus == .converting {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.8)
                    }
                    Text(conversionStatus.buttonLabel)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(selectedFile.isEmpty ? Color.white.opacity(0.06) : Color.blue.opacity(0.6))
                )
                .foregroundColor(selectedFile.isEmpty ? .gray : .white)
            }
            .buttonStyle(.plain)
            .disabled(selectedFile.isEmpty || conversionStatus == .converting)
            
            // Status
            if case .done(let message) = conversionStatus {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
                .transition(.opacity)
            }
            
            Spacer()
            
            Text("Mock converter • ⌘V to paste file path • Drag files onto the panel")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { appState.isInteracting = false }
        .onDisappear {
            appState.isDraggingOver = false
            if conversionStatus != .converting {
                appState.hasActiveTask = false
            }
        }
    }
    
    // MARK: - Actions
    
    private func mockSelectFile() {
        appState.isInteracting = true
        selectedFile = "example_image.\(inputFormat.ext)"
        conversionStatus = .idle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            appState.isInteracting = false
        }
    }
    
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                DispatchQueue.main.async {
                    selectedFile = url.lastPathComponent
                    conversionStatus = .idle
                }
            }
        }
        return true
    }
    
    private func mockConvert() {
        conversionStatus = .converting
        appState.hasActiveTask = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                conversionStatus = .done("Converted \(inputFormat.label) → \(outputFormat.label) successfully")
            }
            appState.hasActiveTask = false
        }
    }
}

// MARK: - Models

private enum FileFormat: String, CaseIterable, Identifiable {
    case png, jpg, heic, pdf, webp, md, html
    
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
