import XCTest
@testable import ConsoleOSC
@testable import AutoSmaartCore

final class StripAddressTests: XCTestCase {
    func testPrefixesAndFader() throws {
        XCTAssertEqual(try stripPrefix(kind: .inputChannel, index: 7), "/sd/Input_Channels/7")
        XCTAssertEqual(try stripPrefix(kind: .groupBus, index: 3), "/sd/Group_Outputs/3")
        XCTAssertEqual(try stripPrefix(kind: .auxBus, index: 4), "/sd/Aux_Outputs/4")
        XCTAssertEqual(try stripPrefix(kind: .matrixBus, index: 12), "/sd/Matrix_Outputs/12")
        XCTAssertEqual(try faderAddress(kind: .inputChannel, index: 1), "/sd/Input_Channels/1/fader")
        XCTAssertThrowsError(try faderAddress(kind: .inputChannel, index: 0))
        XCTAssertThrowsError(try faderAddress(kind: .inputChannel, index: 73))
        XCTAssertThrowsError(try faderAddress(kind: .matrixBus, index: 13))
    }

    func testEqAddressesAnyStrip() throws {
        let eq = try eqAddresses(kind: .inputChannel, index: 5, band: 2)
        XCTAssertEqual(eq.freq, "/sd/Input_Channels/5/EQ/eq_freq_2")
        XCTAssertEqual(eq.gain, "/sd/Input_Channels/5/EQ/eq_gain_2")
        XCTAssertEqual(eq.q, "/sd/Input_Channels/5/EQ/eq_Q_2")
        XCTAssertEqual(eq.on, "/sd/Input_Channels/5/EQ/eq_on_2")
        let matrix = try eqAddresses(output: 1, band: 1)
        XCTAssertEqual(matrix.freq, "/sd/Matrix_Outputs/1/EQ/eq_freq_1")
    }

    func testMuteAllOrderAndCount() {
        let addresses = muteAllAddresses()
        XCTAssertEqual(addresses.count, 72 + 24 + 24 + 12 + 1)
        XCTAssertEqual(addresses.first, "/sd/Input_Channels/1/mute")
        XCTAssertEqual(addresses[71], "/sd/Input_Channels/72/mute")
        XCTAssertEqual(addresses[72], "/sd/Group_Outputs/1/mute")
        XCTAssertEqual(addresses[72 + 24], "/sd/Aux_Outputs/1/mute")
        XCTAssertEqual(addresses[72 + 24 + 24], "/sd/Matrix_Outputs/1/mute")
        XCTAssertEqual(addresses.last, "/sd/Master_Outputs/1/mute")
    }

    func testMuteAddressFollowsStripKind() throws {
        XCTAssertEqual(try muteAddress(kind: .inputChannel, index: 7), "/sd/Input_Channels/7/mute")
        XCTAssertEqual(try muteAddress(kind: .matrixBus, index: 3), "/sd/Matrix_Outputs/3/mute")
    }

    func testMuteAllWritesIntOneAndContinuesAfterFailure() throws {
        final class CountingLink: OscLink {
            var values: [String: OscValue] = [:]
            var log: [String] = []
            var fail = Set<String>()
            func read(address: String) throws -> OscValue { values[address]! }
            func write(address: String, value: OscValue) throws {
                log.append(address)
                if fail.contains(address) { throw ConfirmError.kept }
                values[address] = value
            }
        }
        let link = CountingLink()
        link.fail = ["/sd/Input_Channels/2/mute"]
        let result = muteAll(link: link)
        XCTAssertEqual(result.attempted, 133)
        XCTAssertEqual(result.accepted, 132)
        XCTAssertEqual(link.log.count, 133)
        XCTAssertEqual(link.values["/sd/Input_Channels/1/mute"], .int32(1))
        XCTAssertNil(link.values["/sd/Input_Channels/2/mute"])
        XCTAssertEqual(link.values["/sd/Master_Outputs/1/mute"], .int32(1))
    }

    func testForbiddenAddressListAllowsInputChannels() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let directory = root.appendingPathComponent("Sources/ConsoleOSC")
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let source = try files.filter { $0.pathExtension == "swift" }.map { try String(contentsOf: $0) }.joined(separator: "\n")
        XCTAssertTrue(source.contains("Input_Channels"))
        for forbidden in ["eq_curve", "dynamic_eq", "Graphic", "eq_in", "lock"] {
            XCTAssertFalse(source.contains(forbidden), forbidden)
        }
    }
}
