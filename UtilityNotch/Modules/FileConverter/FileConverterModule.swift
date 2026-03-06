import SwiftUI

/// File Converter utility module — stub (fleshed out in Segment 6)
struct FileConverterModule: UtilityModule {
    let id = "fileConverter"
    let name = "File Converter"
    let icon = "doc.badge.gearshape"
    var isEnabled = true
    
    func makeMainView() -> AnyView {
        AnyView(Text("File Converter — coming soon").foregroundStyle(.secondary))
    }
}
