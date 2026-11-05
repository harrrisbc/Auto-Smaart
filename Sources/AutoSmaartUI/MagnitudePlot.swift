import SwiftUI
import AutoSmaartCore

public struct MagnitudePlot: View {
    var before: [MagnitudePoint]
    var after: [MagnitudePoint]?
    var eq: [MagnitudePoint]

    public init(before: [MagnitudePoint], after: [MagnitudePoint]?, eq: [MagnitudePoint] = []) {
        self.before = before
        self.after = after
        self.eq = eq
    }

    public var body: some View {
        canvas
            .frame(minHeight: 220)
            .overlay(alignment: .topTrailing) {
            HStack(spacing: 12) {
                legend(Theme.beforeTrace, "Trace")
                if after != nil { legend(Theme.afterTrace, "After") }
                if eq.count > 1 { legend(Theme.eqTrace, "EQ") }
            }
            .padding(8)
        }
        .overlay(alignment: .bottomLeading) {
            HStack {
                Text("20 Hz")
                Spacer()
                Text("20 kHz")
            }
            .font(.custom("Inter", size: 11))
            .foregroundStyle(Theme.dim)
            .padding(.horizontal, 4)
        }
    }

    private var canvas: some View {
        let scale = bounds([before, after ?? [], eq])
        let low = scale.0
        let high = scale.1
        return Canvas { context, size in
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
            stroke(context, size, before, Theme.beforeTrace, low: low, high: high)
            if let after { stroke(context, size, after, Theme.afterTrace, low: low, high: high) }
            stroke(context, size, eq, Theme.eqTrace, low: low, high: high)
        }
    }

    private func legend(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1).fill(color).frame(width: 14, height: 2)
            Text(title).font(.custom("Inter", size: 11)).foregroundStyle(Theme.secondary)
        }
    }

    private func bounds(_ series: [[MagnitudePoint]]) -> (Double, Double) {
        let values = series.flatMap { points in
            points.filter { $0.hz >= 20 && $0.hz <= 20000 }.map(\.db)
        }
        let low = values.min() ?? -6
        let high = values.max() ?? 6
        if low == high { return (low - 3, high + 3) }
        return (low, high)
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
            let x = (log10(point.hz) - log10(20)) / (log10(20000) - log10(20)) * size.width
            let y = (1 - (point.db - low) / span) * size.height
            if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        context.stroke(path, with: .color(color), lineWidth: 1.5)
    }
}
