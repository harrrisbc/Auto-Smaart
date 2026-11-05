import SwiftUI
import AutoSmaartCore

enum BandPalette {
    /// Distinct colors for EQ bands 1…8. Index is the console band number.
    private static let hexes: [UInt32] = [
        0xff6b6b, 0xffa94d, 0xffd43b, 0x69db7c,
        0x4dabf7, 0xda77f2, 0xf783ac, 0x66d9e8
    ]

    static func color(for index: Int) -> Color {
        let slot = max(1, index)
        return Color(hex: hexes[(slot - 1) % hexes.count])
    }
}

enum BandHoverText {
    static func readout(_ band: EqBand) -> String {
        let gain = roundHalfAwayFromZero(band.gainDb, places: 1)
        let gainLabel = String(format: "%+.1f dB", gain)
        switch band.shape {
        case .lowShelf:
            return "LF shelf · \(formatFrequency(band.hz)) · \(gainLabel)"
        case .highShelf:
            return "HF shelf · \(formatFrequency(band.hz)) · \(gainLabel)"
        case .peaking:
            let qLabel = String(format: "Q %.2f", band.q)
            return "\(formatFrequency(band.hz)) · \(qLabel) · \(gainLabel)"
        }
    }
}

struct BandHoverBadge: View {
    let band: EqBand

    var body: some View {
        Text(BandHoverText.readout(band))
            .font(.custom("Inter", size: 11).weight(.medium))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.88)))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(BandPalette.color(for: band.index), lineWidth: 1)
            )
    }
}
