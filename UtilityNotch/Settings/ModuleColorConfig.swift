import SwiftUI

/// User-customizable colors per module. Hex strings ("RRGGBB"); empty string = use the built-in
/// default. Persisted via `PersistenceManager` under `.moduleColors`.
struct ModuleColorConfig: Codable, Equatable {

    // MARK: Music
    /// Overall module accent / glow. Empty = use the album-derived `waveColor`.
    var musicGlowHex: String
    /// Visualizer zone colors (low/green, mid/amber, high/red).
    var musicVizLowHex: String
    var musicVizMidHex: String
    var musicVizHighHex: String

    /// Generic per-module accent tint, keyed by module id. Missing = module default.
    var moduleAccentHex: [String: String]

    // MARK: Active Apps (memory-pressure zone colors)
    // Optional so older persisted configs (written before these existed) still decode — a missing
    // key decodes to nil and falls back to the default below.
    var activeAppsNormalHex: String?
    var activeAppsHeavyHex: String?
    var activeAppsCriticalHex: String?

    // MARK: Defaults (match the current UNConstants palette)
    static let defaultGlow = ""                 // "" → album waveColor
    static let defaultVizLow  = "34C759"        // successGreen
    static let defaultVizMid  = "FF9F0A"        // amber
    static let defaultVizHigh = "FF453A"        // destructiveRed

    static let defaultAANormal   = "34C759"     // successGreen
    static let defaultAAHeavy    = "FF9F0A"     // amber
    static let defaultAACritical = "FF453A"     // destructiveRed

    static let `default` = ModuleColorConfig(
        musicGlowHex: defaultGlow,
        musicVizLowHex: defaultVizLow,
        musicVizMidHex: defaultVizMid,
        musicVizHighHex: defaultVizHigh,
        moduleAccentHex: [:],
        activeAppsNormalHex: nil,
        activeAppsHeavyHex: nil,
        activeAppsCriticalHex: nil
    )

    // MARK: Resolved colors

    /// Custom music glow/accent, or nil to fall back to the album color.
    var musicGlowColor: Color? {
        musicGlowHex.isEmpty ? nil : Color(hex: musicGlowHex)
    }
    var musicVizLow:  Color { Color(hex: musicVizLowHex.isEmpty  ? Self.defaultVizLow  : musicVizLowHex) }
    var musicVizMid:  Color { Color(hex: musicVizMidHex.isEmpty  ? Self.defaultVizMid  : musicVizMidHex) }
    var musicVizHigh: Color { Color(hex: musicVizHighHex.isEmpty ? Self.defaultVizHigh : musicVizHighHex) }

    /// Active Apps pressure-zone colors — custom hex, or the built-in default when unset/empty.
    var activeAppsNormal: Color {
        Color(hex: (activeAppsNormalHex?.isEmpty ?? true) ? Self.defaultAANormal : activeAppsNormalHex!)
    }
    var activeAppsHeavy: Color {
        Color(hex: (activeAppsHeavyHex?.isEmpty ?? true) ? Self.defaultAAHeavy : activeAppsHeavyHex!)
    }
    var activeAppsCritical: Color {
        Color(hex: (activeAppsCriticalHex?.isEmpty ?? true) ? Self.defaultAACritical : activeAppsCriticalHex!)
    }

    /// Per-module accent, or nil to use that module's built-in tint.
    func accentColor(for moduleID: String) -> Color? {
        guard let hex = moduleAccentHex[moduleID], !hex.isEmpty else { return nil }
        return Color(hex: hex)
    }
}
