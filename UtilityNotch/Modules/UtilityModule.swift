import SwiftUI

/// Contract that every utility module must conform to.
/// To add a new utility: create a struct conforming to this protocol,
/// then register it in ModuleRegistry.allModules.
protocol UtilityModule: Identifiable {
    /// Unique stable identifier (e.g. "todoList")
    var id: String { get }
    
    /// Human-readable name shown in rail tooltip & settings
    var name: String { get }
    
    /// SF Symbol name for the utility rail icon
    var icon: String { get }
    
    /// Whether the module is currently enabled by the user
    var isEnabled: Bool { get set }
    
    /// Whether this module can perform background work (e.g. clipboard monitoring)
    var supportsBackground: Bool { get }
    
    /// Whether this module can send notifications
    var supportsNotifications: Bool { get }
    
    /// The main content view displayed in the center panel
    @ViewBuilder @MainActor
    func makeMainView() -> AnyView
    
    /// Optional per-module settings view (nil = no settings)
    @ViewBuilder @MainActor
    func makeSettingsView() -> AnyView?
    
    /// Permissions this module requires (display-only in beta)
    var requiredPermissions: [PermissionInfo] { get }
}

// MARK: - Defaults

extension UtilityModule {
    var supportsBackground: Bool { false }
    var supportsNotifications: Bool { false }
    var requiredPermissions: [PermissionInfo] { [] }
    
    func makeSettingsView() -> AnyView? { nil }
}

// MARK: - Permission Info (display-only model)

struct PermissionInfo: Identifiable {
    let id: String
    let name: String            // e.g. "Accessibility"
    let reason: String          // Why this module needs it
    let systemSettingsPath: String  // e.g. "Privacy & Security → Accessibility"
}
