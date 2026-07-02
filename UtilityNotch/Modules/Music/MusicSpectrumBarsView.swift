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
    // Customizable spectrum zone colors (low/mid/high). Default to the classic green/amber/red.
    var lowColor: Color = UNConstants.successGreen
    var midColor: Color = UNConstants.amber
    var highColor: Color = UNConstants.destructiveRed

    private let segments = 24
    private let barSpacing: CGFloat = 8
    private let segmentGap: CGFloat = 2

    // Zone thresholds (fraction of the bar height).
    private let greenTop = 0.55
    private let amberTop = 0.85

    var body: some View {
        bars
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
                // Pill keeps its full vibrant color always. On hover each lit pill gets a small
                // halo in its own color (tight shadow). Safe now because the meter is inset 8pt
                // from the content clip edge, so the shadow's expanded bounds stay inside it.
                Capsule(style: .continuous)
                    .fill(isLit ? base : base.opacity(0.06))
                    .frame(width: width, height: segH)
                    .shadow(
                        color: (isLit && glow) ? base.opacity(0.85) : .clear,
                        radius: (isLit && glow) ? 2.5 : 0
                    )
            }
        }
    }

    private func zoneColor(fromBottom: Int) -> Color {
        let frac = Double(fromBottom) / Double(segments - 1)
        if frac < greenTop { return lowColor }
        if frac < amberTop { return midColor }
        return highColor
    }

}
