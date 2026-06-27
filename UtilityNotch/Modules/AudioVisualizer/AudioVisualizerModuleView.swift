import AppKit
import SwiftUI

/// Live vertical audio spectrum. Each bar grows upward from a shared baseline in proportion
/// to the energy in its frequency band. Smoothing lives in `AudioSpectrumAnalyzer` (attack/decay)
/// so the bars are rendered directly from the latest published values — no implicit animation.
struct AudioVisualizerModuleView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var analyzer = AudioSpectrumAnalyzer()

    private var statusLeft: String {
        analyzer.previewMode ? "PREVIEW" : "LIVE INPUT"
    }

    private var statusRight: String {
        switch analyzer.state {
        case .active:      return "REACTING"
        case .listening:   return "LISTENING"
        case .denied:      return "MIC OFF"
        case .unavailable: return "NO INPUT"
        case .idle:        return analyzer.previewMode ? "DEMO" : "IDLE"
        }
    }

    private var statusDotColor: Color {
        switch analyzer.state {
        case .active:      return UNConstants.successGreen
        case .listening:   return UNConstants.accentBlue
        case .denied:      return UNConstants.destructiveRed
        case .unavailable: return UNConstants.amber
        case .idle:        return Color.white.opacity(0.2)
        }
    }

    var body: some View {
        ModuleShellView(
            moduleTitle: "Audio Visualizer",
            moduleIcon: "waveform",
            modules: shellNavItems(appState: appState),
            activeModuleID: appState.activeModuleID,
            onModuleSelect: { id in
                withAnimation(reduceMotion ? UNMotion.reduced : UNMotion.moduleSwitch) {
                    appState.selectModule(id)
                }
            },
            statusDotColor: statusDotColor,
            statusLeft: statusLeft,
            statusRight: statusRight,
            actionButton: {
                AnyView(
                    Button {
                        withAnimation(reduceMotion ? UNMotion.reduced : UNMotion.standard) {
                            analyzer.previewMode.toggle()
                        }
                    } label: {
                        makeAddActionButton(
                            icon: analyzer.previewMode ? "dot.radiowaves.left.and.right" : "waveform.badge.magnifyingglass",
                            label: analyzer.previewMode ? "GO LIVE" : "PREVIEW"
                        )
                    }
                    .buttonStyle(.plain)
                )
            }
        ) {
            ZStack {
                spectrum
                if needsFallback { fallbackOverlay }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { analyzer.start() }
        .onDisappear { analyzer.stop() }
    }

    // MARK: - Spectrum

    private var spectrum: some View {
        GeometryReader { geo in
            let count = analyzer.levels.count
            let gap: CGFloat = 6
            let barWidth = max(3, (geo.size.width - gap * CGFloat(count - 1)) / CGFloat(count))
            let maxHeight = geo.size.height
            let baseline: CGFloat = 4   // resting nub so the meter never fully disappears

            HStack(alignment: .bottom, spacing: gap) {
                ForEach(0..<count, id: \.self) { i in
                    let level = analyzer.levels[i]
                    let height = baseline + level * (maxHeight - baseline)
                    RoundedRectangle(cornerRadius: barWidth / 2, style: .continuous)
                        .fill(barGradient(level: level))
                        .frame(width: barWidth, height: height)
                        .opacity(needsFallback ? 0.25 : 1)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
        }
    }

    private func barGradient(level: CGFloat) -> LinearGradient {
        // Cool blue base lifting toward green at the crest — both are existing palette tokens.
        // Higher bands glow a little brighter via the top stop's opacity.
        let crest = UNConstants.successGreen.opacity(0.55 + 0.4 * Double(min(1, level)))
        return LinearGradient(
            colors: [UNConstants.accentBlue.opacity(0.55), crest],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    // MARK: - Fallback

    private var needsFallback: Bool {
        switch analyzer.state {
        case .denied, .unavailable: return true
        case .idle:                 return !analyzer.previewMode
        case .listening, .active:   return false
        }
    }

    @ViewBuilder
    private var fallbackOverlay: some View {
        VStack(spacing: 8) {
            Image(systemName: fallbackIcon)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(UNConstants.textTertiary)
            Text(fallbackTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(UNConstants.textPrimary)
            Text(fallbackSubtitle)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(UNConstants.textSecondary)
                .multilineTextAlignment(.center)

            if analyzer.state == .denied {
                Button {
                    openMicrophoneSettings()
                } label: {
                    makeAddActionButton(icon: "gearshape", label: "OPEN SETTINGS")
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 24)
    }

    private var fallbackIcon: String {
        switch analyzer.state {
        case .denied:      return "mic.slash"
        case .unavailable: return "waveform.slash"
        default:           return "waveform"
        }
    }

    private var fallbackTitle: String {
        switch analyzer.state {
        case .denied:      return "microphone is off"
        case .unavailable: return "no audio input"
        default:           return "nothing to show yet"
        }
    }

    private var fallbackSubtitle: String {
        switch analyzer.state {
        case .denied:      return "allow microphone access to\nvisualize live audio"
        case .unavailable: return "connect an input device, or\nturn on preview from the footer"
        default:           return "play some audio, or turn on\npreview from the footer"
        }
    }

    private func openMicrophoneSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") else { return }
        NSWorkspace.shared.open(url)
    }
}
