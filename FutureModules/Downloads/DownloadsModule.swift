import SwiftUI

/// Downloads utility module — shows recent downloads from ~/Downloads.
struct DownloadsModule: UtilityModule {
    let id = "downloads"
    let name = "Downloads"
    let icon = "arrow.down.circle"
    var isEnabled: Bool = true

    func makeMainView() -> AnyView {
        AnyView(DownloadsModuleView())
    }
}
