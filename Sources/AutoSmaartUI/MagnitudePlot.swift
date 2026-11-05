import SwiftUI
import AutoSmaartCore

public struct MagnitudePlot: View {
    var before: [MagnitudePoint]
    var after: [MagnitudePoint]?
    /// Selected target curve, drawn in its own color for comparison.
    var target: [MagnitudePoint]
    /// In-use peaking bands only; unused slots stay undrawn.
    var bands: [EqBand]

    /// Fixed display window: +10 dB at the top, −10 dB at the bottom.
    private static let displayHigh = 10.0
    private static let displayLow = -10.0

    @State private var hoverBand: EqBand?
    @State private var hoverPoint: CGPoint = .zero

    public init(
        before: [MagnitudePoint],
        after: [MagnitudePoint]?,
        target: [MagnitudePoint] = [],
        bands: [EqBand] = []
    ) {
        self.before = before
        self.after = after
        self.target = target
        self.bands = bands
    }

    public var body: some View {
        let offset = traceCenterOffset(before)
        let centeredBefore = shift(before, by: -offset)
        let centeredAfter = after.map { shift($0, by: -offset) }
        let centeredTarget = shift(target, by: -offset)
        let bandCurves = bands.map { band in
            (band: band, points: summedEqResponse(bands: [band]))
        }
        let low = Self.displayLow
        let high = Self.displayHigh
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    strokeGrid(context, size, low: low, high: high)
                    stroke(context, size, centeredBefore, Theme.beforeTrace, low: low, high: high)
                    if let centeredAfter {
                        stroke(context, size, centeredAfter, Theme.afterTrace, low: low, high: high)
                    }
                    stroke(context, size, centeredTarget, Theme.targetTrace, low: low, high: high)
                    for entry in bandCurves {
                        let color = BandPalette.color(for: entry.band.index)
                        stroke(context, size, entry.points, color, low: low, high: high)
                        markCenter(context, size, band: entry.band, color: color, low: low, high: high)
                    }
                }
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        hoverPoint = location
                        hoverBand = nearestBand(
                            at: location,
                            size: geo.size,
                            curves: bandCurves,
                            low: low,
                            high: high
                        )
                    case .ended:
                        hoverBand = nil
                    }
                }

                if let hoverBand {
                    BandHoverBadge(band: hoverBand)
                        .position(
                            x: min(geo.size.width - 90, max(90, hoverPoint.x)),
                            y: max(18, hoverPoint.y - 22)
                        )
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(minHeight: 220)
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 12) {
                legend(Theme.beforeTrace, "Trace")
                if after != nil { legend(Theme.afterTrace, "After") }
                if target.count > 1 { legend(Theme.targetTrace, "Target") }
                ForEach(bands, id: \.index) { band in
                    legend(BandPalette.color(for: band.index), "B\(band.index)")
                }
            }
            .padding(8)
        }
        .overlay(alignment: .topLeading) {
            Text("+10 dB")
                .font(.custom("Inter", size: 11))
                .foregroundStyle(Theme.dim)
                .padding(8)
        }
        .overlay(alignment: .bottomLeading) {
            HStack {
                Text("−10 dB")
                Spacer()
                Text("20 Hz")
                Spacer()
                Text("20 kHz")
            }
            .font(.custom("Inter", size: 11))
            .foregroundStyle(Theme.dim)
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
    }

    /// Mean level of the input trace — shifted to 0 so the trace sits at vertical center.
    private func traceCenterOffset(_ points: [MagnitudePoint]) -> Double {
        let values = points.filter { $0.hz >= 20 && $0.hz <= 20000 }.map(\.db)
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func shift(_ points: [MagnitudePoint], by delta: Double) -> [MagnitudePoint] {
        points.map { MagnitudePoint(hz: $0.hz, db: $0.db + delta, phase: $0.phase) }
    }

    private func legend(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1).fill(color).frame(width: 14, height: 2)
            Text(title).font(.custom("Inter", size: 11)).foregroundStyle(Theme.secondary)
        }
    }

    private func strokeGrid(_ context: GraphicsContext, _ size: CGSize, low: Double, high: Double) {
        let grid = Path { path in
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: size.width, y: 0))
            path.move(to: CGPoint(x: 0, y: size.height))
            path.addLine(to: CGPoint(x: size.width, y: size.height))
        }
        context.stroke(grid, with: .color(Theme.grid), lineWidth: 1)
        if low < 0 && high > 0 {
            let y = (1 - (0 - low) / (high - low)) * size.height
            var zero = Path()
            zero.move(to: CGPoint(x: 0, y: y))
            zero.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(zero, with: .color(Theme.grid), lineWidth: 1)
        }
    }

    private func stroke(
        _ context: GraphicsContext,
        _ size: CGSize,
        _ points: [MagnitudePoint],
        _ color: Color,
        low: Double,
        high: Double
    ) {
        let kept = points.filter { $0.hz >= 20 && $0.hz <= 20000 }.sorted { $0.hz < $1.hz }
        guard kept.count > 1 else { return }
        let span = max(1, high - low)
        var path = Path()
        for (index, point) in kept.enumerated() {
            let x = xPos(point.hz, width: size.width)
            let y = (1 - (point.db - low) / span) * size.height
            if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        context.stroke(path, with: .color(color), lineWidth: 1.5)
    }

    private func markCenter(
        _ context: GraphicsContext,
        _ size: CGSize,
        band: EqBand,
        color: Color,
        low: Double,
        high: Double
    ) {
        guard band.hz >= 20 && band.hz <= 20000 else { return }
        let span = max(1, high - low)
        let x = xPos(band.hz, width: size.width)
        let peakDb = summedEqResponse(bands: [band], at: [band.hz]).first?.db ?? band.gainDb
        let y = (1 - (peakDb - low) / span) * size.height
        let rect = CGRect(x: x - 3.5, y: y - 3.5, width: 7, height: 7)
        context.fill(Path(ellipseIn: rect), with: .color(color))
    }

    private func nearestBand(
        at location: CGPoint,
        size: CGSize,
        curves: [(band: EqBand, points: [MagnitudePoint])],
        low: Double,
        high: Double
    ) -> EqBand? {
        guard !curves.isEmpty, size.width > 0, size.height > 0 else { return nil }
        let span = max(1, high - low)
        let hz = hzAt(x: location.x, width: size.width)
        var best: (EqBand, CGFloat)?
        for entry in curves {
            let db = summedEqResponse(bands: [entry.band], at: [hz]).first?.db ?? 0
            let y = CGFloat((1 - (db - low) / span) * size.height)
            let centerX = xPos(entry.band.hz, width: size.width)
            let curveDistance = abs(location.y - y)
            let centerDistance = abs(location.x - centerX)
            let score = min(curveDistance, centerDistance * 0.35 + curveDistance * 0.65)
            if score > 16 { continue }
            if best == nil || score < best!.1 {
                best = (entry.band, score)
            }
        }
        return best?.0
    }

    private func xPos(_ hz: Double, width: CGFloat) -> CGFloat {
        let clamped = min(20000.0, max(20.0, hz))
        return CGFloat((log10(clamped) - log10(20)) / (log10(20000) - log10(20))) * width
    }

    private func hzAt(x: CGFloat, width: CGFloat) -> Double {
        let t = Double(max(0, min(1, x / max(width, 1))))
        return pow(10, log10(20) + t * (log10(20000) - log10(20)))
    }
}
