import AppKit
import SwiftUI

// MARK: - Screen geometry (recomputed on every call, safe across display changes)

struct ScreenGeometry {

    /// Display that should host the notch UI.
    /// Prefer the notched built-in panel when it is present; external displays can
    /// become `NSScreen.main` and otherwise leave the hover zone on the wrong screen.
    static var screen: NSScreen {
        notchedScreen ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private static var notchedScreen: NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
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
    static let contentPaddingH: CGFloat = 16
    static let contentPaddingV: CGFloat = 8
    static let moduleCanvasWidth: CGFloat = panelWidth - sidebarWidth - (contentPaddingH * 2)
    static let moduleCanvasHeight: CGFloat = contentHeight - (contentPaddingV * 2)

    // MARK: - Component Layout

    static let hudButtonSize: CGFloat = 28
    static let hudIconSize: CGFloat = 12
    static let compactControlHeight: CGFloat = 30
    static let rowCornerRadius: CGFloat = 8
    static let cardCornerRadius: CGFloat = 8
    static let tileCornerRadius: CGFloat = 10
    static let moduleColumnGap: CGFloat = 12
    static let moduleRowGap: CGFloat = 8

    // MARK: - Header / Footer Padding

    static let headerPaddingH: CGFloat = 24
    static let footerPaddingH: CGFloat = 16

    // MARK: - Sidebar

    static let sidebarIconSize: CGFloat = 15
    static let sidebarInactiveOpacity: Double = 0.35
    static let sidebarTooltipDelay: Double = 0.15

    // MARK: - Timing

    static let animationDuration: Double = 0.28
    static let dynamicIslandCloseDuration: Double = 0.52
    static let contentFadeDelay: Double = 0.08
    static let hoverOpenDelay: Double = 0.3
    static let defaultInactivityTimeout: Double = 8.0

    // MARK: - Colors

    static let panelBackground = Color.black
    static let accentHighlight = Color.white.opacity(0.08)
    static let iconTint = Color.white.opacity(0.35)
    static let iconActiveTint = Color(hex: "0A84FF")
    static let accentBlue = Color(hex: "0A84FF")
    static let successGreen = Color(red: 52/255, green: 199/255, blue: 89/255)
    static let destructiveRed = Color(red: 1.0, green: 0.271, blue: 0.227)
    static let amber = Color(red: 255/255, green: 159/255, blue: 10/255)

    // MARK: - Surface Opacities

    static let panelGlowOpacity: Double = 0.08
    static let panelGlowRadius: CGFloat = 220
    static let activeStateOpacity: Double = 0.08
    static let hoverStateOpacity: Double = 0.05
    static let panelGhostBorder = Color.white.opacity(0.10)
    static let sidebarBorder = Color.white.opacity(0.15)
    static let contentLift = Color.white.opacity(0.02)
    static let insetSurface = Color.white.opacity(0.04)
    static let rowSurface = Color.white.opacity(0.03)
    static let rowHoverSurface = Color.white.opacity(0.05)
    static let raisedSurface = Color.white.opacity(0.08)
    static let selectedSurface = Color.white.opacity(0.12)
    static let controlSurface = Color.white.opacity(0.10)
    static let controlHoverSurface = Color.white.opacity(0.14)
    static let overlayScrim = Color.black.opacity(0.50)
    static let tooltipSurface = Color.black.opacity(0.60)
    static let textPrimary = Color.white.opacity(0.85)
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary = Color.white.opacity(0.35)
    static let textPlaceholder = Color.white.opacity(0.25)
    static let textMuted = Color.white.opacity(0.30)

    // MARK: - Module Environmental Tints

    static let todoContentTint = successGreen.opacity(0.015)
    static let notesContentTint = amber.opacity(0.014)
    static let clipboardContentTint = accentBlue.opacity(0.015)
    static let musicContentTint = musicProgressStart.opacity(0.012)
    static let calendarContentTint = accentBlue.opacity(0.015)
    static let filesContentTint = fileDefaultEnd.opacity(0.012)
    static let fileConverterContentTint = fileVideoEnd.opacity(0.012)
    static let activeAppsContentTint = fileDefaultEnd.opacity(0.014)
    static let downloadsContentTint = fileAudioEnd.opacity(0.014)
    static let recentFilesContentTint = fileDefaultStart.opacity(0.014)
    static let liveActivitiesContentTint = accentBlue.opacity(0.014)

    // MARK: - File Type Tints

    static let fileImageStart = Color(hex: "7C3AED")
    static let fileImageEnd = Color(hex: "EC4899")
    static let filePDFStart = Color(hex: "DC2626")
    static let filePDFEnd = Color(hex: "F97316")
    static let fileVideoStart = Color(hex: "2563EB")
    static let fileVideoEnd = Color(hex: "06B6D4")
    static let fileAudioStart = Color(hex: "059669")
    static let fileAudioEnd = Color(hex: "34D399")
    static let fileArchiveStart = Color(hex: "D97706")
    static let fileArchiveEnd = Color(hex: "FBBF24")
    static let fileDefaultStart = Color(hex: "475569")
    static let fileDefaultEnd = Color(hex: "94A3B8")

    // MARK: - State Colors

    static let successTint = Color(red: 52/255, green: 199/255, blue: 89/255).opacity(0.10)
    static let successBorder = Color(red: 52/255, green: 199/255, blue: 89/255).opacity(0.25)
    static let errorTint = Color(red: 255/255, green: 159/255, blue: 10/255).opacity(0.10)
    static let errorBorder = Color(red: 255/255, green: 159/255, blue: 10/255).opacity(0.25)
    static let focusTint = Color(hex: "0A84FF").opacity(0.08)
    static let focusBorder = Color(hex: "0A84FF").opacity(0.50)

    // MARK: - Music Module

    /// Status dot color when music is actively playing.
    static let musicPlayingTint = Color(red: 52/255, green: 211/255, blue: 153/255).opacity(0.8)
    /// Progress bar gradient — leading color.
    static let musicProgressStart = Color(red: 139/255, green: 92/255, blue: 246/255)
    /// Progress bar gradient — trailing color.
    static let musicProgressEnd   = Color(red: 59/255, green: 130/255, blue: 246/255)
    /// Deterministic album-art placeholder palette (6 two-stop gradients, keyed on track ID hash).
    static let musicArtPalette: [[Color]] = [
        [Color(hex: "1A0533"), Color(hex: "6D28D9")],
        [Color(hex: "7F1D1D"), Color(hex: "F97316")],
        [Color(hex: "1E3A5F"), Color(hex: "06B6D4")],
        [Color(hex: "713F12"), Color(hex: "FBBF24")],
        [Color(hex: "4C1D95"), Color(hex: "EC4899")],
        [Color(hex: "064E3B"), Color(hex: "34D399")],
    ]

    // MARK: - Keyboard Shortcut

    static let globalHotkeyKeyCode: UInt16 = 49
    static let globalHotkeyModifiers: NSEvent.ModifierFlags = .option
}

// MARK: - Motion Tokens

/// Named animation curves shared across the app. Use these instead of open-coding
/// `.spring(...)`, `.easeInOut(...)`, etc. The set is intentionally small — every
/// surface should map to one of these tokens.
///
/// macOS 14 introduces `.smooth / .snappy / .bouncy` springs whose defaults are
/// tuned to feel like Apple's first-party UI. We lean on those for the premium
/// feel and only fall back to ease curves where motion must be linearly framed
/// (hover, press flashes).
enum UNMotion {

    // MARK: - Spring presets

    /// Crisp tap response — buttons, toggles, single-state flips.
    static let tap: Animation = .snappy(duration: 0.22, extraBounce: 0.10)

    /// Default state change — the most common motion in the app.
    static let standard: Animation = .smooth(duration: 0.28, extraBounce: 0.12)

    /// Module/sidebar selection — slightly slower and slightly bouncier than
    /// `standard` so a module switch reads as a deliberate motion.
    static let moduleSwitch: Animation = .smooth(duration: 0.32, extraBounce: 0.14)

    /// Sheet / popup / settings flyout — calm, low-bounce.
    static let gentle: Animation = .smooth(duration: 0.38, extraBounce: 0.06)

    /// Delight moments — new item added, success states.
    static let expressive: Animation = .bouncy(duration: 0.42, extraBounce: 0.18)

    /// List inserts / removes — items entering or leaving a stack.
    static let listItem: Animation = .smooth(duration: 0.32, extraBounce: 0.12)

    /// Other rows sliding apart to make room for a dragged item.
    static let dragDisplace: Animation = .smooth(duration: 0.28, extraBounce: 0.08)

    /// The dragged item itself — quick, slightly springier.
    static let dragLift: Animation = .snappy(duration: 0.20, extraBounce: 0.18)

    /// Cross-fade between two states of the same surface.
    static let crossFade: Animation = .smooth(duration: 0.22, extraBounce: 0)

    /// Reduced-motion fallback — short opacity/scale changes without travel.
    static let reduced: Animation = .smooth(duration: 0.12, extraBounce: 0)

    /// Module-switch content fade in `ActiveModuleContainerView`.
    static let contentFade: Animation = .smooth(duration: 0.22, extraBounce: 0)

    /// Dynamic Island expand from the notch.
    static let panelOpen: Animation = .smooth(duration: 0.40, extraBounce: 0.14)

    /// Dynamic Island collapse — slightly faster so close feels responsive.
    static let panelClose: Animation = .smooth(duration: 0.32, extraBounce: 0.04)

    /// Music progress bar — low-bounce smoothing for value changes.
    static let progress: Animation = .smooth(duration: 0.45, extraBounce: 0)

    /// Calendar day selection / date shift.
    static let daySelect: Animation = .snappy(duration: 0.26, extraBounce: 0.12)

    // MARK: - Non-spring (intentional)

    /// Hover — the ONLY easeInOut allowed for user-facing motion (per design rules).
    static let hover: Animation = .easeInOut(duration: 0.15)

    /// Press feedback flash — quick, framed, no bounce.
    static let press: Animation = .easeOut(duration: 0.10)

    /// Quick on / slow off used for the "just copied" flash.
    static let flashOn: Animation  = .easeOut(duration: 0.08)
    static let flashOff: Animation = .easeOut(duration: 0.18)
}

// MARK: - Press Feedback Button Style

/// Subtle scale + opacity on press. Gives interactive surfaces a premium tactile
/// feel without the heaviness of a full bounce. Pair with `.buttonStyle(.pressFeedback)`.
struct PressFeedbackButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.94
    var pressedOpacity: Double = 0.82

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? pressedOpacity : 1)
            .animation(UNMotion.tap, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressFeedbackButtonStyle {
    /// Subtle scale-down + opacity dim on press.
    static var pressFeedback: PressFeedbackButtonStyle { .init() }
}
