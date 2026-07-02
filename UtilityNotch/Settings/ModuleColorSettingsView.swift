import SwiftUI

/// Per-module color customization, styled in the UtilityNotch dark-glass aesthetic.
/// Left: module list. Right: that module's color controls (hex field + system color picker).
/// Music exposes the overall glow/accent plus the three visualizer zone colors; every other
/// module exposes a single accent tint. All edits persist immediately and apply live.
struct ModuleColorSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedID: String = "musicControl"

    private let railWidth: CGFloat = 184

    var body: some View {
        HStack(spacing: 0) {
            moduleRail
            Rectangle()
                .fill(UNConstants.sidebarBorder)
                .frame(width: 1)
            detail
        }
        .frame(minWidth: 560, minHeight: 420)
        .background(UNConstants.panelBackground)
        .preferredColorScheme(.dark)
    }

    // MARK: - Left rail

    private var moduleRail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                Text("MODULES")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(UNConstants.textTertiary)
                    .padding(.horizontal, 14)
                    .padding(.top, 16)
                    .padding(.bottom, 6)

                ForEach(ModuleRegistry.allModules, id: \.id) { module in
                    railRow(id: module.id, name: module.name, icon: module.icon)
                }
            }
            .padding(.bottom, 16)
        }
        .frame(width: railWidth)
        .background(Color.white.opacity(0.02))
    }

    private func railRow(id: String, name: String, icon: String) -> some View {
        let selected = selectedID == id
        return Button {
            withAnimation(UNMotion.standard) { selectedID = id }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(selected ? UNConstants.accentBlue : UNConstants.textSecondary)
                    .frame(width: 18)
                Text(name)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? UNConstants.textPrimary : UNConstants.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: UNConstants.rowCornerRadius, style: .continuous)
                    .fill(selected ? UNConstants.accentHighlight : .clear)
            )
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail

    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                let module = ModuleRegistry.module(for: selectedID)

                VStack(alignment: .leading, spacing: 3) {
                    Text(module?.name ?? "Module")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(UNConstants.textPrimary)
                    Text("Customize colors — pick from the swatch or type a hex code.")
                        .font(.system(size: 12))
                        .foregroundStyle(UNConstants.textSecondary)
                }

                if selectedID == "musicControl" {
                    musicControls
                } else if selectedID == "activeApps" {
                    activeAppsControls
                } else {
                    genericControls
                }

                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Music

    @ViewBuilder
    private var musicControls: some View {
        sectionLabel("MODULE GLOW & ACCENT")
        ColorEditRow(
            title: "Overall glow / accent",
            subtitle: appState.moduleColors.musicGlowHex.isEmpty ? "Using album color" : "Custom",
            hex: bind(\.musicGlowHex),
            allowAuto: true
        )

        sectionLabel("VISUALIZER")
        ColorEditRow(title: "Low band (green)",  subtitle: "Bass / low-mid",  hex: bind(\.musicVizLowHex))
        ColorEditRow(title: "Mid band (amber)",  subtitle: "Mids",            hex: bind(\.musicVizMidHex))
        ColorEditRow(title: "High band (red)",   subtitle: "Treble / peaks",  hex: bind(\.musicVizHighHex))

        resetButton {
            var c = appState.moduleColors
            c.musicGlowHex = ModuleColorConfig.defaultGlow
            c.musicVizLowHex = ModuleColorConfig.defaultVizLow
            c.musicVizMidHex = ModuleColorConfig.defaultVizMid
            c.musicVizHighHex = ModuleColorConfig.defaultVizHigh
            appState.moduleColors = c
        }
    }

    // MARK: - Active Apps

    @ViewBuilder
    private var activeAppsControls: some View {
        sectionLabel("MEMORY PRESSURE ZONES")
        ColorEditRow(title: "Normal (green)",   subtitle: "Low pressure",      hex: bindOpt(\.activeAppsNormalHex))
        ColorEditRow(title: "Heavy (amber)",    subtitle: "Elevated pressure", hex: bindOpt(\.activeAppsHeavyHex))
        ColorEditRow(title: "Critical (red)",   subtitle: "High pressure",     hex: bindOpt(\.activeAppsCriticalHex))

        resetButton {
            var c = appState.moduleColors
            c.activeAppsNormalHex = nil
            c.activeAppsHeavyHex = nil
            c.activeAppsCriticalHex = nil
            appState.moduleColors = c
        }
    }

    // MARK: - Generic module accent

    @ViewBuilder
    private var genericControls: some View {
        sectionLabel("ACCENT")
        ColorEditRow(
            title: "Accent tint",
            subtitle: (appState.moduleColors.moduleAccentHex[selectedID]?.isEmpty ?? true) ? "Using default" : "Custom",
            hex: accentBind(selectedID),
            allowAuto: true
        )
        resetButton {
            var c = appState.moduleColors
            c.moduleAccentHex[selectedID] = ""
            appState.moduleColors = c
        }
    }

    // MARK: - Pieces

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(UNConstants.textTertiary)
            .padding(.top, 4)
    }

    private func resetButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.counterclockwise")
                Text("Reset to defaults")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(UNConstants.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(UNConstants.controlSurface))
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
    }

    // MARK: - Bindings

    private func bind(_ keyPath: WritableKeyPath<ModuleColorConfig, String>) -> Binding<String> {
        Binding(
            get: { appState.moduleColors[keyPath: keyPath] },
            set: { newVal in
                var c = appState.moduleColors
                c[keyPath: keyPath] = Self.sanitize(newVal)
                appState.moduleColors = c
            }
        )
    }

    private func bindOpt(_ keyPath: WritableKeyPath<ModuleColorConfig, String?>) -> Binding<String> {
        Binding(
            get: { appState.moduleColors[keyPath: keyPath] ?? "" },
            set: { newVal in
                var c = appState.moduleColors
                c[keyPath: keyPath] = Self.sanitize(newVal)
                appState.moduleColors = c
            }
        )
    }

    private func accentBind(_ id: String) -> Binding<String> {
        Binding(
            get: { appState.moduleColors.moduleAccentHex[id] ?? "" },
            set: { newVal in
                var c = appState.moduleColors
                c.moduleAccentHex[id] = Self.sanitize(newVal)
                appState.moduleColors = c
            }
        )
    }

    static func sanitize(_ s: String) -> String {
        let allowed = s.uppercased().unicodeScalars.filter { CharacterSet(charactersIn: "0123456789ABCDEF").contains($0) }
        return String(String.UnicodeScalarView(allowed.prefix(6)))
    }
}

// MARK: - Color edit row

private struct ColorEditRow: View {
    let title: String
    var subtitle: String = ""
    @Binding var hex: String
    /// When true an empty hex means "auto" (album/default color) and shows an Auto chip.
    var allowAuto: Bool = false

    @State private var draft: String = ""

    private var isAuto: Bool { allowAuto && hex.isEmpty }

    private var swatchColor: Color {
        Color(hex: hex.isEmpty ? "3A3A3C" : hex)
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: hex.isEmpty ? "808080" : hex) },
            set: { hex = $0.toHex() }
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isAuto ? AnyShapeStyle(autoGradient) : AnyShapeStyle(swatchColor))
                    .frame(width: 34, height: 34)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
                if isAuto {
                    Text("A").font(.system(size: 13, weight: .bold)).foregroundStyle(.white.opacity(0.9))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(UNConstants.textPrimary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(UNConstants.textTertiary)
                        .textCase(.uppercase)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Text("#").font(.system(size: 12, design: .monospaced)).foregroundStyle(UNConstants.textTertiary)
                TextField("AUTO", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(UNConstants.textPrimary)
                    .frame(width: 64)
                    .onSubmit { commitDraft() }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(UNConstants.insetSurface)
            )

            ColorPicker("", selection: colorBinding, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 30)

            if allowAuto {
                Button {
                    hex = ""
                    draft = ""
                } label: {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 12))
                        .foregroundStyle(isAuto ? UNConstants.accentBlue : UNConstants.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Use automatic / default color")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: UNConstants.tileCornerRadius, style: .continuous)
                .fill(UNConstants.rowSurface)
        )
        .onAppear { draft = hex }
        .onChange(of: hex) { _, new in draft = new }
    }

    private func commitDraft() {
        let clean = ModuleColorSettingsView.sanitize(draft)
        hex = clean
        draft = clean
    }

    private var autoGradient: LinearGradient {
        LinearGradient(
            colors: [UNConstants.accentBlue, UNConstants.successGreen, UNConstants.amber],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}
