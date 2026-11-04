import SwiftUI
import AutoSmaartCore

public struct MagnitudePlot: View {
    var before: [MagnitudePoint]
    var after: [MagnitudePoint]?

    public init(before: [MagnitudePoint], after: [MagnitudePoint]?) {
        self.before = before
        self.after = after
    }

    public var body: some View {
        Canvas { context, size in
            let grid = Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: size.width, y: 0))
                path.move(to: CGPoint(x: 0, y: size.height))
                path.addLine(to: CGPoint(x: size.width, y: size.height))
            }
            context.stroke(grid, with: .color(Theme.grid), lineWidth: 1)
            stroke(context, size, before, Theme.beforeTrace)
            if let after { stroke(context, size, after, Theme.afterTrace) }
        }
        .frame(minHeight: 220)
        .overlay(alignment: .bottomLeading) {
            HStack {
                Text("20 Hz")
                Spacer()
                Text("20 kHz")
            }
            .font(.custom("Inter", size: 11))
            .foregroundStyle(Theme.dim)
        }
    }

    private func stroke(_ context: GraphicsContext, _ size: CGSize, _ points: [MagnitudePoint], _ color: Color) {
        let kept = points.filter { $0.hz >= 20 && $0.hz <= 20000 }.sorted { $0.hz < $1.hz }
        guard kept.count > 1 else { return }
        let lows = kept.map(\.db).min() ?? -6
        let highs = kept.map(\.db).max() ?? 6
        let span = max(1, highs - lows)
        var path = Path()
        for (index, point) in kept.enumerated() {
            let x = (log10(point.hz) - log10(20)) / (log10(20000) - log10(20)) * size.width
            let y = (1 - (point.db - lows) / span) * size.height
            if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        context.stroke(path, with: .color(color), lineWidth: 1.5)
    }
}
