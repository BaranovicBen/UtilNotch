import Foundation

/// Single registration point for all compile-time utility modules.
/// To add a new module: append it to `allModules`.
enum ModuleRegistry {

    /// All available modules in default order.
    /// This is the ONLY place modules are registered.
    static var allModules: [any UtilityModule] = [
        TodoListModule(),
        QuickNotesModule(),
        ClipboardHistoryModule(),
        MusicControlModule(),
        FileConverterModule(),
        LiveActivitiesModule(),
        CalendarModule(),
        FilesTrayModule(),
        ActiveAppsModule(),
        RecentFilesModule(),
        DownloadsModule()
    ]

    /// Look up a module by ID
    static func module(for id: String) -> (any UtilityModule)? {
        allModules.first { $0.id == id }
    }
}
