import XCTest
@testable import AutoSmaartRingOut
@testable import AutoSmaartCore
@testable import ConsoleOSC

final class MemoryLink: OscLink {
    var values: [String: OscValue]
    var log: [(String, String, OscValue?)] = []
    var failWriteAddresses: Set<String> = []
    init(values: [String: OscValue]) { self.values = values }
    func read(address: String) throws -> OscValue {
        log.append(("read", address, nil))
        guard let value = values[address] else { throw ConfirmError.kept }
        return value
    }
    func write(address: String, value: OscValue) throws {
        log.append(("write", address, value))
        if failWriteAddresses.contains(address) { throw ConfirmError.kept }
        values[address] = value
    }
}

final class FaderDriverTests: XCTestCase {
    func testReadWriteAndRaiseOnlyTouchFaderAddress() throws {
        let address = try faderAddress(kind: .inputChannel, index: 3)
        let link = MemoryLink(values: [address: .float32(-20)])
        let driver = FaderDriver(kind: .inputChannel, index: 3, link: link)
        XCTAssertEqual(try driver.read(), .decibels(-20))
        let raised = try driver.raiseByHalfDb()
        XCTAssertEqual(raised, .decibels(-19.5))
        XCTAssertEqual(link.values[address], .float32(-19.5))
        try driver.writeMinusInfinity()
        XCTAssertEqual(link.values[address], .float32(-150))
        XCTAssertEqual(try driver.read(), .minusInfinity)
        XCTAssertTrue(link.log.allSatisfy { $0.1 == address })
        XCTAssertFalse(link.log.contains { $0.1.contains("mute") })
    }

    func testRaiseFromMinusInfinityWritesMinus149_5() throws {
        let address = try faderAddress(kind: .matrixBus, index: 1)
        let link = MemoryLink(values: [address: .float32(-150)])
        let driver = FaderDriver(kind: .matrixBus, index: 1, link: link)
        XCTAssertEqual(try driver.raiseByHalfDb(), .decibels(-149.5))
    }

    func testFailedWriteSurfaces() throws {
        let address = try faderAddress(kind: .inputChannel, index: 1)
        let link = MemoryLink(values: [address: .float32(0)])
        link.failWriteAddresses = [address]
        let driver = FaderDriver(kind: .inputChannel, index: 1, link: link)
        XCTAssertThrowsError(try driver.raiseByHalfDb())
    }
}
