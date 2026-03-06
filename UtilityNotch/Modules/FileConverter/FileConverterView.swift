import SwiftUI

/// File Converter view — mock UI with conversion type picker and placeholder action.
/// Replace with real file conversion logic in production.
struct FileConverterView: View {
    @State private var selectedConversion: ConversionType = .pngToJpg
    @State private var selectedFile: String = ""
    @State private var conversionStatus: ConversionStatus = .idle
    
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
            
            Spacer()
            
            // Conversion type picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Conversion Type")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Picker("", selection: $selectedConversion) {
                    ForEach(ConversionType.allCases) { type in
                        Text(type.label).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .tint(.white)
            }
            .padding(.bottom, 16)
            
            // File drop zone
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: UNConstants.innerCornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                        .frame(height: 100)
                    
                    VStack(spacing: 6) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                        
                        if selectedFile.isEmpty {
                            Text("Drop a file here or click to select")
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
                .onTapGesture {
                    mockSelectFile()
                }
            }
            .padding(.bottom, 16)
            
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
                .padding(.top, 10)
                .transition(.opacity)
            }
            
            Spacer()
            
            // Beta note
            Text("Mock converter • Real file conversion will use system frameworks")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    // MARK: - Mock Actions
    
    private func mockSelectFile() {
        // MARK: TODO — Replace with NSOpenPanel in production
        selectedFile = "example_image.\(selectedConversion.inputExtension)"
        conversionStatus = .idle
    }
    
    private func mockConvert() {
        conversionStatus = .converting
        
        // Simulate a short conversion delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                conversionStatus = .done("Converted to \(selectedConversion.outputExtension.uppercased()) successfully")
            }
        }
    }
}

// MARK: - Models

private enum ConversionType: String, CaseIterable, Identifiable {
    case pngToJpg
    case jpgToPng
    case heicToJpg
    case pdfToPng
    case webpToPng
    case markdownToHtml
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .pngToJpg: return "PNG → JPEG"
        case .jpgToPng: return "JPEG → PNG"
        case .heicToJpg: return "HEIC → JPEG"
        case .pdfToPng: return "PDF → PNG"
        case .webpToPng: return "WebP → PNG"
        case .markdownToHtml: return "Markdown → HTML"
        }
    }
    
    var inputExtension: String {
        switch self {
        case .pngToJpg: return "png"
        case .jpgToPng: return "jpg"
        case .heicToJpg: return "heic"
        case .pdfToPng: return "pdf"
        case .webpToPng: return "webp"
        case .markdownToHtml: return "md"
        }
    }
    
    var outputExtension: String {
        switch self {
        case .pngToJpg: return "jpg"
        case .jpgToPng, .heicToJpg, .webpToPng: return "png"
        case .pdfToPng: return "png"
        case .markdownToHtml: return "html"
        }
    }
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
