import XCTest
@testable import AutoSmaartRingOut
@testable import AutoSmaartCore
@testable import ConsoleOSC

final class NotchWriterTests: XCTestCase {
    private func seededLink(kind: StripKind = .inputChannel, index: Int = 1) throws -> (MemoryLink, NotchWriter) {
        let link = MemoryLink(values: [:])
        for band in 1...8 {
            let eq = try eqAddresses(kind: kind, index: index, band: band)
            // Unused at Start: leave missing so captureUndoBaseline skips them when read fails.
            // Pre-seed band 1 as if console had a prior notch for deepen/restore tests when needed.
            _ = eq
        }
        let writer = NotchWriter(kind: kind, index: index, link: link)
        return (link, writer)
    }

    func testNewBandWritesFreqGainQOnInOrder() throws {
        let (link, writer) = try seededLink()
        try writer.captureUndoBaseline(readingBands: [])
        let decision = try writer.apply(peakHz: 1000)
        guard case .write(let band) = decision else { return XCTFail("\(decision)") }
        XCTAssertEqual(band.gainDb, -3)
        XCTAssertEqual(band.q, 16)
        let eq = try eqAddresses(kind: .inputChannel, index: 1, band: 1)
        XCTAssertEqual(link.log.map(\.0), ["write", "write", "write", "write"])
        // New band: no prior console values — writer uses writeOnly when restore reads would fail.
        // Spec: "new band: none yet on console for that index". Implementation: writeOnly for brand-new index with empty undo for that band.
        XCTAssertEqual(link.values[eq.freq], .float32(1000))
        XCTAssertEqual(link.values[eq.gain], .float32(-3))
        XCTAssertEqual(link.values[eq.q], .float32(16))
        XCTAssertEqual(link.values[eq.on], .int32(1))
        XCTAssertEqual(writer.bands, [band])
    }

    func testDeepenUsesConfirmReplaceAndKeepsFrequency() throws {
        let kind = StripKind.matrixBus
        let index = 2
        let eq = try eqAddresses(kind: kind, index: index, band: 1)
        let link = MemoryLink(values: [
            eq.freq: .float32(1000),
            eq.gain: .float32(-3),
            eq.q: .float32(16),
            eq.on: .int32(1)
        ])
        let writer = NotchWriter(kind: kind, index: index, link: link)
        writer.bands = [EqBand(index: 1, hz: 1000, gainDb: -3, q: 16)]
        let decision = try writer.apply(peakHz: 1010)
        guard case .deepen(let band) = decision else { return XCTFail("\(decision)") }
        XCTAssertEqual(band.gainDb, -6)
        XCTAssertEqual(band.hz, 1000)
        XCTAssertEqual(link.values[eq.gain], .float32(-6))
        XCTAssertEqual(link.log.filter { $0.0 == "read" }.count, 4)
    }

    func testFailedWriteRestoresAndDoesNotMerge() throws {
        let eq = try eqAddresses(kind: .inputChannel, index: 1, band: 1)
        let link = MemoryLink(values: [
            eq.freq: .float32(800),
            eq.gain: .float32(-3),
            eq.q: .float32(16),
            eq.on: .int32(1)
        ])
        link.failWriteAddresses = [eq.gain]
        let writer = NotchWriter(kind: .inputChannel, index: 1, link: link)
        writer.bands = [EqBand(index: 1, hz: 800, gainDb: -3, q: 16)]
        XCTAssertThrowsError(try writer.apply(peakHz: 805))
        XCTAssertEqual(link.values[eq.freq], .float32(800))
        XCTAssertEqual(link.values[eq.gain], .float32(-3))
        XCTAssertEqual(writer.bands.first?.gainDb, -3)
    }

    func testBandCapAndFloorWriteNothing() throws {
        let (link, writer) = try seededLink()
        writer.bands = (1...8).map { EqBand(index: $0, hz: Double($0) * 100 + 50, gainDb: -3, q: 16) }
        XCTAssertEqual(try writer.apply(peakHz: 4500), .bandCap)
        XCTAssertTrue(link.log.isEmpty)
        writer.bands = [EqBand(index: 1, hz: 1000, gainDb: -18, q: 16)]
        XCTAssertEqual(try writer.apply(peakHz: 1000), .floorReached(writer.bands[0]))
        XCTAssertTrue(link.log.isEmpty)
    }

    func testUndoRestoresSnapshot() throws {
        let eq = try eqAddresses(kind: .inputChannel, index: 1, band: 1)
        let link = MemoryLink(values: [
            eq.freq: .float32(500),
            eq.gain: .float32(-1),
            eq.q: .float32(4),
            eq.on: .int32(1)
        ])
        let writer = NotchWriter(kind: .inputChannel, index: 1, link: link)
        try writer.captureUndoBaseline(readingBands: [1])
        writer.bands = [EqBand(index: 1, hz: 500, gainDb: -1, q: 4)]
        _ = try writer.apply(peakHz: 2000)
        XCTAssertEqual(writer.bands.count, 2)
        try writer.undo()
        XCTAssertEqual(link.values[eq.gain], .float32(-1))
        // Band 2 had no Start read — Undo sends nothing for that unused index.
        let eq2 = try eqAddresses(kind: .inputChannel, index: 1, band: 2)
        XCTAssertEqual(link.values[eq2.gain], .float32(-3))
        XCTAssertTrue(writer.bands.isEmpty)
    }
}
