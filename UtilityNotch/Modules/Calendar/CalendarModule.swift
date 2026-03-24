import SwiftUI
import EventKit

// ENTITLEMENT_NOTE: requires com.apple.security.personal-information.calendars
// Added to UtilityNotch.entitlements for sandboxed calendar access.

/// Shared EKEventStore — one instance per app lifetime to avoid re-prompting.
let sharedEventStore = EKEventStore()

struct CalendarModule: UtilityModule {
    let id = "calendar"
    let name = "Calendar"
    let icon = "calendar"
    var isEnabled: Bool = true
    var supportsBackground: Bool = false
    var supportsNotifications: Bool = true

    var requiredPermissions: [PermissionInfo] {
        [PermissionInfo(
            id: "calendars",
            name: "Calendars",
            reason: "Reads upcoming events from your calendar to display them in the notch.",
            systemSettingsPath: "Privacy & Security → Calendars"
        )]
    }

    func makeMainView() -> AnyView { AnyView(CalendarView()) }
    func makeSettingsView() -> AnyView? { AnyView(CalendarSettingsView()) }
}
