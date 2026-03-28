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
    
    /// Total expanded panel width
    static let panelWidth: CGFloat = 620
    
    /// Total expanded panel height
    static let panelHeight: CGFloat = 380
    
    /// Width fraction for the utility rail (right side) — kept for legacy reference
    static let railWidthFraction: CGFloat = 0.18

    /// Fixed pixel width for the utility rail
    static let railWidth: CGFloat = 40
    
    /// Corner radius for the main panel
    static let panelCornerRadius: CGFloat = 20
    
    /// Corner radius for inner cards / module containers
    static let innerCornerRadius: CGFloat = 12
    
    // MARK: - Shell Layout

    /// Sidebar (right rail) width — aligns icon zone with content, gear zone with footer
    static let sidebarWidth: CGFloat = 48

    /// Header row height — shared by CanonicalShellView and SidebarRailView top blank zone
    static let headerHeight: CGFloat = 60

    /// Footer bar height — shared by CanonicalShellView and SidebarRailView gear zone
    static let footerHeight: CGFloat = 38

    // MARK: - Timing
    
    /// Default animation duration
    static let animationDuration: Double = 0.28
    
    /// Hover delay before opening panel (seconds)
    static let hoverOpenDelay: Double = 0.3
    
    /// Default inactivity timeout (seconds)
    static let defaultInactivityTimeout: Double = 8.0
    
    // MARK: - Colors
    
    /// Panel background color
    static let panelBackground = Color(white: 0.08)
    
    /// Rail background color
    static let railBackground = Color(white: 0.12)
    
    /// Active/selected accent
    static let accentHighlight = Color.white.opacity(0.12)
    
    /// Icon default tint
    static let iconTint = Color.white.opacity(0.7)
    
    /// Icon active tint
    static let iconActiveTint = Color.white
    
    // MARK: - Keyboard Shortcut
    
    /// Global hotkey: Option + Space
    static let globalHotkeyKeyCode: UInt16 = 49  // Space
    static let globalHotkeyModifiers: NSEvent.ModifierFlags = .option
}
