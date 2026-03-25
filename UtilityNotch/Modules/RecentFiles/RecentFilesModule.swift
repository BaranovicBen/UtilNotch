import SwiftUI

/// Recent Files utility module — shows recently accessed files.
struct RecentFilesModule: UtilityModule {
    let id = "recentFiles"
    let name = "Recent Files"
    let icon = "doc.text.magnifyingglass"
    var isEnabled: Bool = true

    func makeMainView() -> AnyView {
        AnyView(RecentFilesModuleView())
    }
}
