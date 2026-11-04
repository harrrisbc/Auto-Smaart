import SwiftUI
import AutoSmaartCore

/// Compact log-frequency magnitude sketch for the landing curve list.
struct CurveThumb: View {
    var points: [MagnitudePoint]
    var selected: Bool
    /// Only when the shape alone would be ambiguous (e.g. stored bank curves).
    var label: String? = nil

    private let dbMin: Double = -3
    private let dbMax: Double = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Canvas { context, size in
                // Zero line
                let zeroY = y(0, height: size.height)
                var zero = Path()
                zero.move(to: CGPoint(x: 0, y: zeroY))
                zero.addLine(to: CGPoint(x: size.width, y: zeroY))
                context.stroke(zero, with: .color(Theme.grid), lineWidth: 1)

                let kept = points.filter { $0.hz >= 20 && $0.hz <= 20000 }.sorted { $0.hz < $1.hz }
                guard kept.count > 1 else { return }
                var path = Path()
                for (index, point) in kept.enumerated() {
                    let x = (log10(point.hz) - log10(20)) / (log10(20000) - log10(20)) * size.width
                    let pt = CGPoint(x: x, y: y(point.db, height: size.height))
                    if index == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                }
                context.stroke(path, with: .color(selected ? Theme.hoverGold : Theme.lightGold), lineWidth: 1.5)
            }
            .frame(height: 44)

            if let label, !label.isEmpty {
                Text(label)
                    .font(.custom("Inter", size: 10))
                    .foregroundStyle(Theme.dim)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? Theme.selectedRow : Theme.raised)
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .stroke(selected ? Theme.gold.opacity(0.5) : Theme.stroke, lineWidth: 1)
        )
    }

    private func y(_ db: Double, height: CGFloat) -> CGFloat {
        let clamped = min(dbMax, max(dbMin, db))
        return (1 - (clamped - dbMin) / (dbMax - dbMin)) * height
    }
}
