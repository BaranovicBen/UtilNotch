import SwiftUI

/// File Converter utility module — mock UI with conversion type picker and placeholder action.
/// Replace with real conversion logic (CoreImage, PDFKit, etc.) in production.
struct FileConverterModule: UtilityModule {
    let id = "fileConverter"
    let name = "File Converter"
    let icon = "doc.badge.gearshape"
    var isEnabled = true
    
    func makeMainView() -> AnyView {
        AnyView(FileConverterView())
    }
    
    func makeSettingsView() -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text("File Converter Settings")
                    .font(.headline)
                Text("Default output format, output folder, and quality settings will be configurable in production.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        )
    }
}
