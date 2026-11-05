import Foundation
import AutoSmaartCore
import ConsoleOSC

public final class NotchWriter {
    private let kind: StripKind
    private let index: Int
    private let link: OscLink
    public var bands: [EqBand] = []
    public private(set) var undoSnapshot: [Replacement] = []

    public init(kind: StripKind, index: Int, link: OscLink) {
        self.kind = kind
        self.index = index
        self.link = link
    }

    public func captureUndoBaseline(readingBands bandIndexes: [Int]) throws {
        var snapshot: [Replacement] = []
        for band in bandIndexes {
            let eq = try eqAddresses(kind: kind, index: index, band: band)
            for address in [eq.freq, eq.gain, eq.q, eq.on] {
                do {
                    snapshot.append(Replacement(address: address, value: try link.read(address: address)))
                } catch {
                    // Unused band with no console read: skip this address.
                }
            }
        }
        undoSnapshot = snapshot
    }

    public func apply(peakHz: Double) throws -> NotchDecision {
        let decision = decideNotch(peakHz: peakHz, bands: bands)
        switch decision {
        case .bandCap, .floorReached:
            return decision
        case .write(let band):
            let eq = try eqAddresses(kind: kind, index: index, band: band.index)
            let items = [
                Replacement(address: eq.freq, value: .float32(Float(band.hz))),
                Replacement(address: eq.gain, value: .float32(Float(band.gainDb))),
                Replacement(address: eq.q, value: .float32(Float(band.q))),
                Replacement(address: eq.on, value: .int32(1))
            ]
            try writeOnly(items, link: link)
            bands.append(band)
            bands.sort { $0.index < $1.index }
            return decision
        case .deepen(let band):
            let eq = try eqAddresses(kind: kind, index: index, band: band.index)
            let items = [
                Replacement(address: eq.freq, value: .float32(Float(band.hz))),
                Replacement(address: eq.gain, value: .float32(Float(band.gainDb))),
                Replacement(address: eq.q, value: .float32(Float(band.q))),
                Replacement(address: eq.on, value: .int32(1))
            ]
            _ = try confirmReplace(items, link: link)
            if let offset = bands.firstIndex(where: { $0.index == band.index }) {
                bands[offset] = band
            }
            return decision
        }
    }

    public func undo() throws {
        guard !undoSnapshot.isEmpty else {
            bands = []
            return
        }
        try writeOnly(undoSnapshot, link: link)
        bands = []
    }
}
