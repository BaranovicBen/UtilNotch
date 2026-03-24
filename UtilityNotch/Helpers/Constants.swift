import SwiftUI

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
    
    // MARK: - Trigger Zone
    
    /// Width of the invisible hover trigger zone at top-center
    static let triggerZoneWidth: CGFloat = 200
    
    /// Height of the invisible hover trigger zone
    static let triggerZoneHeight: CGFloat = 12
    
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
