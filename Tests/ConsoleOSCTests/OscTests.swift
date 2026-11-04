import XCTest
@testable import ConsoleOSC
@testable import AutoSmaartCore

final class MemoryLink: OscLink {
    var values: [String: OscValue]
    var log: [(String, String, OscValue?)] = []
    var failWriteAddresses: Set<String> = []
    var failRestoreAddresses: Set<String> = []
    private var writesAccepted: Set<String> = []
    init(values: [String: OscValue]) { self.values = values }
    func read(address: String) throws -> OscValue {
        log.append(("read", address, nil))
        guard let value = values[address] else { throw LinkFailure.missing }
        return value
    }
    func write(address: String, value: OscValue) throws {
        log.append(("write", address, value))
        if failWriteAddresses.contains(address) && !writesAccepted.contains(address) { throw LinkFailure.rejected }
        if failRestoreAddresses.contains(address) && writesAccepted.contains(address) { throw LinkFailure.rejected }
        values[address] = value
        writesAccepted.insert(address)
    }
}

enum LinkFailure: Error { case missing, rejected }

final class OscTests: XCTestCase {
    func testDelayQueryAndFloatZeroPacket() throws {
        let address = "/sd/Matrix_Outputs/1/Channel_Delay/delay"
        XCTAssertEqual(encodeOsc(address: address, value: nil).hex, "2f73642f4d61747269785f4f7574707574732f312f4368616e6e656c5f44656c61792f64656c6179000000002c000000")
        let packet = encodeOsc(address: address, value: .float32(0))
        XCTAssertEqual(packet.hex, "2f73642f4d61747269785f4f7574707574732f312f4368616e6e656c5f44656c61792f64656c6179000000002c66000000000000")
        let decoded = try decodeOsc(packet)
        XCTAssertEqual(decoded.address, address)
        XCTAssertEqual(decoded.value, .float32(0))
    }

    func testEqOnIntPacket() throws {
        let address = "/sd/Matrix_Outputs/1/EQ/eq_on_1"
        let packet = encodeOsc(address: address, value: .int32(1))
        XCTAssertEqual(packet.hex, "2f73642f4d61747269785f4f7574707574732f312f45512f65715f6f6e5f31002c69000000000001")
        XCTAssertEqual(try decodeOsc(packet).value, .int32(1))
    }

    func testAddressesRejectAnythingOutsideMatrixBandRange() throws {
        let delay = try delayAddresses(output: 1)
        XCTAssertEqual(delay.delay, "/sd/Matrix_Outputs/1/Channel_Delay/delay")
        XCTAssertEqual(delay.fineDelay, "/sd/Matrix_Outputs/1/Channel_Delay/fine_delay")
        let eq = try eqAddresses(output: 12, band: 8)
        XCTAssertEqual(eq.freq, "/sd/Matrix_Outputs/12/EQ/eq_freq_8")
        XCTAssertEqual(eq.gain, "/sd/Matrix_Outputs/12/EQ/eq_gain_8")
        XCTAssertEqual(eq.q, "/sd/Matrix_Outputs/12/EQ/eq_Q_8")
        XCTAssertEqual(eq.on, "/sd/Matrix_Outputs/12/EQ/eq_on_8")
        XCTAssertThrowsError(try delayAddresses(output: 0))
        XCTAssertThrowsError(try delayAddresses(output: 13))
        XCTAssertThrowsError(try eqAddresses(output: 1, band: 0))
        XCTAssertThrowsError(try eqAddresses(output: 1, band: 9))
    }

    func testDriverSourceHasNoForbiddenAddress() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let directory = root.appendingPathComponent("Sources/ConsoleOSC")
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let source = try files.filter { $0.pathExtension == "swift" }.map { try String(contentsOf: $0) }.joined(separator: "\n")
        for forbidden in ["eq_curve", "dynamic_eq", "Input_Channels", "delay_on", "Graphic", "eq_in", "lock"] {
            XCTAssertFalse(source.contains(forbidden), forbidden)
        }
    }

    func testConfirmReadsThenWritesAndReturnsTheRestoreCopy() throws {
        let delay = try delayAddresses(output: 1)
        let link = MemoryLink(values: [delay.delay: .float32(1.5), delay.fineDelay: .float32(2.5)])
        let sent = [
            Replacement(address: delay.delay, value: .float32(12.4)),
            Replacement(address: delay.fineDelay, value: .float32(12.4))
        ]
        let restore = try confirmReplace(sent, link: link)
        XCTAssertEqual(restore.map(\.value), [.float32(1.5), .float32(2.5)])
        XCTAssertEqual(link.log.map { $0.0 }, ["read", "read", "write", "write"])
        XCTAssertEqual(link.values[delay.delay], .float32(12.4))
    }

    func testReadFailureWritesNothing() throws {
        let delay = try delayAddresses(output: 1)
        let link = MemoryLink(values: [delay.delay: .float32(0)])
        XCTAssertThrowsError(try confirmReplace([
            Replacement(address: delay.delay, value: .float32(12.4)),
            Replacement(address: delay.fineDelay, value: .float32(12.4))
        ], link: link)) { error in
            XCTAssertEqual(error as? ConfirmError, .kept)
        }
        XCTAssertEqual(link.log.map(\.0), ["read", "read"])
    }

    func testFailedLaterWriteRestoresOnlyWhatWasWritten() throws {
        let delay = try delayAddresses(output: 1)
        let link = MemoryLink(values: [delay.delay: .float32(0), delay.fineDelay: .float32(5)])
        link.failWriteAddresses = [delay.fineDelay]
        XCTAssertThrowsError(try confirmReplace([
            Replacement(address: delay.delay, value: .float32(12.4)),
            Replacement(address: delay.fineDelay, value: .float32(12.4))
        ], link: link)) { error in
            XCTAssertEqual(error as? ConfirmError, .kept)
        }
        XCTAssertEqual(link.values[delay.delay], .float32(0))
        XCTAssertEqual(link.values[delay.fineDelay], .float32(5))
        XCTAssertEqual(link.log.filter { $0.0 == "write" }.map(\.1), [delay.delay, delay.fineDelay, delay.delay])
    }

    func testFailedRestoreIsMismatch() throws {
        let delay = try delayAddresses(output: 1)
        let link = MemoryLink(values: [delay.delay: .float32(0), delay.fineDelay: .float32(5)])
        link.failWriteAddresses = [delay.fineDelay]
        link.failRestoreAddresses = [delay.delay]
        XCTAssertThrowsError(try confirmReplace([
            Replacement(address: delay.delay, value: .float32(12.4)),
            Replacement(address: delay.fineDelay, value: .float32(12.4))
        ], link: link)) { error in
            XCTAssertEqual(error as? ConfirmError, .mismatch)
        }
    }
}

extension Data {
    var hex: String { map { String(format: "%02x", $0) }.joined() }
}
