import SwiftUI

/// Clean 4-bar segmented audio meter for the Music module, sized to align with the album cover.
///
/// Exactly four bars — one per musical band (Bass, Low-mid, High-mid, Treble). Each bar is a
/// vertical stack of slim rounded pill segments that light up bottom→top with the band level:
/// green in the lower zone, amber in the middle, red at the peaks. Premium and readable.
///
/// Driven by real microphone FFT (`AudioSpectrumAnalyzer`, 4 aggregated bands). When the mic is
/// denied/unavailable the same bars animate from the analyzer's deterministic preview, badged
/// "DEMO" so live and fake states are never confused.
///
/// `glow` is driven by the Music module's hover state — when true, active pills brighten and gain
/// a soft colored shadow.
struct MusicSpectrumBarsView: View {
    let analyzer: AudioSpectrumAnalyzer
    var color: Color
    var glow: Bool = false

    private let segments = 24
    private let barSpacing: CGFloat = 8
    private let segmentGap: CGFloat = 2

    // Zone thresholds (fraction of the bar height).
    private let greenTop = 0.55
    private let amberTop = 0.85

    var body: some View {
        ZStack(alignment: .top) {
            bars
            if isDemo { demoBadge }
        }
        .frame(width: 76, height: 178)
    }
    // NOTE: deliberately NO shadow/brightness/saturation/blur on the meter. Every one of those is a
    // rasterizing filter that draws the meter into an offscreen layer; against the module's
    // right-edge content clip that layer dropped the edge-pinned 4th bar. The hover "glow" comes
    // from (1) the lit-pill brightness delta below and (2) the module's ambient glow behind the row.

    // MARK: - Bars

    private var bars: some View {
        GeometryReader { geo in
            let levels = analyzer.levels
            let count = max(1, levels.count)
            // Subtract a 2pt safety margin so sub-pixel rounding can never clip the last (4th) bar.
            let usableW = max(0, geo.size.width - 2)
            let barWidth = (usableW - barSpacing * CGFloat(count - 1)) / CGFloat(count)
            let segH = (geo.size.height - segmentGap * CGFloat(segments - 1)) / CGFloat(segments)

            HStack(alignment: .bottom, spacing: barSpacing) {
                ForEach(0..<count, id: \.self) { i in
                    barColumn(level: levels[i], width: barWidth, segH: segH)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
    }

    private func barColumn(level: CGFloat, width: CGFloat, segH: CGFloat) -> some View {
        let lit = Int((min(1, level) * CGFloat(segments)).rounded())
        return VStack(spacing: segmentGap) {
            ForEach(0..<segments, id: \.self) { s in
                let fromBottom = segments - 1 - s        // s counts from the top
                let isLit = fromBottom < lit
                let base = zoneColor(fromBottom: fromBottom)
                // Glow = a clear brightness delta on lit pills (0.8 → full). No filters/shadows,
                // so nothing rasterizes the meter or risks clipping the 4th bar.
                Capsule(style: .continuous)
                    .fill(base.opacity(isLit ? (glow ? 1.0 : 0.8) : 0.06))
                    .frame(width: width, height: segH)
            }
        }
    }

    private func zoneColor(fromBottom: Int) -> Color {
        let frac = Double(fromBottom) / Double(segments - 1)
        if frac < greenTop { return UNConstants.successGreen }
        if frac < amberTop { return UNConstants.amber }
        return UNConstants.destructiveRed
    }

    // MARK: - Demo badge

    private var isDemo: Bool { analyzer.previewMode }

    private var demoBadge: some View {
        Text(analyzer.lifecycle == .denied ? "MIC OFF · DEMO" : "DEMO")
            .font(.system(size: 7, weight: .semibold, design: .monospaced))
            .foregroundStyle(UNConstants.amber)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                Capsule().fill(Color.black.opacity(0.55))
                    .overlay(Capsule().strokeBorder(UNConstants.amber.opacity(0.4), lineWidth: 0.5))
            )
            .offset(y: -2)
    }
}
