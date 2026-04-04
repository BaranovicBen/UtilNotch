import AppKit
import SwiftUI

// MARK: - Screen geometry (recomputed on every call, safe across display changes)

struct ScreenGeometry {

    static var screen: NSScreen {
        NSScreen.main ?? NSScreen.screens[0]
    }

    /// Physical top of the display in screen coordinates.
    static var screenTop: CGFloat {
        screen.frame.maxY
    }

    /// Height of the notch cutout in points. 0 on non-notched displays.
    static var notchHeight: CGFloat {
        screen.safeAreaInsets.top
    }

    /// Y origin for the panel window frame (panel top = physical screen top).
    static var panelOriginY: CGFloat {
        screenTop - UNConstants.panelHeight
    }

    /// X origin for the panel window frame (horizontally centered).
    static var panelOriginX: CGFloat {
        screen.frame.midX - (UNConstants.panelWidth / 2)
    }

    /// Height of the hover trigger zone — matches notch height, or 12pt fallback.
    static var triggerZoneHeight: CGFloat {
        notchHeight > 0 ? notchHeight : 12
    }

    /// Width of the hover trigger zone (200pt covers the notch with margin).
    static var triggerZoneWidth: CGFloat {
        200
    }

    /// Y origin of the trigger zone window (bottom edge of the notch).
    static var triggerZoneOriginY: CGFloat {
        screenTop - triggerZoneHeight
    }

    /// X origin of the trigger zone window (horizontally centered).
    static var triggerZoneOriginX: CGFloat {
        screen.frame.midX - (triggerZoneWidth / 2)
    }

    /// Whether the current display has a physical notch.
    static var hasNotch: Bool {
        notchHeight > 0
    }
}

// MARK: - Design constants

/// Shared design constants for the Utility Notch shell.
enum UNConstants {

    // MARK: - Panel Dimensions

    static let panelWidth: CGFloat = 622
    static let panelHeight: CGFloat = 382
    static let panelCornerRadius: CGFloat = 20
    static let invertedCornerRadius: CGFloat = 10
    static let innerCornerRadius: CGFloat = 12

    // MARK: - Shell Layout

    static let sidebarWidth: CGFloat = 48
    static let headerHeight: CGFloat = 60
    static let footerHeight: CGFloat = 38
    static let contentHeight: CGFloat = 282

    // MARK: - Header / Footer Padding

    static let headerPaddingH: CGFloat = 24
    static let footerPaddingH: CGFloat = 16

    // MARK: - Sidebar

    static let sidebarIconSize: CGFloat = 15
    static let sidebarInactiveOpacity: Double = 0.35
    static let sidebarTooltipDelay: Double = 0.15

    // MARK: - Timing

    static let animationDuration: Double = 0.28
    static let contentFadeDelay: Double = 0.08
    static let hoverOpenDelay: Double = 0.3
    static let defaultInactivityTimeout: Double = 8.0

    // MARK: - Colors

    static let panelBackground = Color.black
    static let accentHighlight = Color.white.opacity(0.08)
    static let iconTint = Color.white.opacity(0.35)
    static let iconActiveTint = Color(hex: "0A84FF")

    // MARK: - Surface Opacities

    static let panelGlowOpacity: Double = 0.05
    static let activeStateOpacity: Double = 0.08
    static let hoverStateOpacity: Double = 0.05

    // MARK: - State Colors

    static let successTint = Color(red: 52/255, green: 199/255, blue: 89/255).opacity(0.10)
    static let successBorder = Color(red: 52/255, green: 199/255, blue: 89/255).opacity(0.25)
    static let errorTint = Color(red: 255/255, green: 159/255, blue: 10/255).opacity(0.10)
    static let errorBorder = Color(red: 255/255, green: 159/255, blue: 10/255).opacity(0.25)
    static let focusTint = Color(hex: "0A84FF").opacity(0.08)
    static let focusBorder = Color(hex: "0A84FF").opacity(0.50)

    // MARK: - Keyboard Shortcut

    static let globalHotkeyKeyCode: UInt16 = 49
    static let globalHotkeyModifiers: NSEvent.ModifierFlags = .option
}
