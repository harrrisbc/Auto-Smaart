import XCTest
import Darwin
@testable import ConsoleOSC
@testable import AutoSmaartCore

final class FakeQuantum225 {
    private var fd: Int32 = -1
    private var thread: Thread?
    private let lock = NSLock()
    private(set) var received: [Data] = []
    var values: [String: OscValue] = [:]
    var refuse: Set<String> = []
    let port: UInt16

    init() throws {
        let socketFd = socket(AF_INET, SOCK_DGRAM, 0)
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(socketFd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        if bound != 0 { throw OscTransportError.notAccepted }
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(socketFd, $0, &length) }
        }
        fd = socketFd
        port = UInt16(bigEndian: address.sin_port)
        thread = Thread { [weak self] in self?.loop() }
        thread?.start()
    }

    func stop() { close(fd) }

    private func loop() {
        var buffer = [UInt8](repeating: 0, count: 2048)
        while true {
            var sender = sockaddr_in()
            var length = socklen_t(MemoryLayout<sockaddr_in>.size)
            let count = withUnsafeMutablePointer(to: &sender) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { recvfrom(fd, &buffer, buffer.count, 0, $0, &length) }
            }
            if count <= 0 { return }
            let data = Data(buffer.prefix(count))
            lock.lock(); received.append(data); lock.unlock()
            guard let message = try? decodeOsc(data) else { continue }
            if message.value == nil {
                let stored = values[message.address] ?? .float32(0)
                let reply = encodeOsc(address: message.address, value: stored)
                _ = reply.withUnsafeBytes { raw in
                    withUnsafePointer(to: &sender) {
                        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sendto(fd, raw.baseAddress, reply.count, 0, $0, length) }
                    }
                }
            } else if let value = message.value, !refuse.contains(message.address) {
                values[message.address] = value
                let reply = encodeOsc(address: message.address, value: value)
                _ = reply.withUnsafeBytes { raw in
                    withUnsafePointer(to: &sender) {
                        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sendto(fd, raw.baseAddress, reply.count, 0, $0, length) }
                    }
                }
            }
        }
    }
}

final class FakeConsoleTests: XCTestCase {
    func testNothingArrivesBeforeConfirmThenDelayAndEqMatchTheSpec() throws {
        let fake = try FakeQuantum225()
        defer { fake.stop() }
        let client = try Quantum225Client(host: "127.0.0.1", port: fake.port)
        defer { client.close() }
        Thread.sleep(forTimeInterval: 0.05)
        XCTAssertTrue(fake.received.isEmpty)
        let delay = try delayAddresses(output: 1)
        _ = try confirmReplace([
            Replacement(address: delay.delay, value: .float32(12.4)),
            Replacement(address: delay.fineDelay, value: .float32(12.4))
        ], link: client)
        let delayPackets = fake.received.compactMap { try? decodeOsc($0) }
        // confirmReplace reads every address first, then writes in order.
        XCTAssertEqual(delayPackets.map(\.address), [delay.delay, delay.fineDelay, delay.delay, delay.fineDelay])
        XCTAssertEqual(delayPackets.map(\.value), [nil, nil, .float32(12.4), .float32(12.4)])
        let beforeEq = fake.received.count
        let band = try eqAddresses(output: 1, band: 1)
        _ = try confirmReplace([
            Replacement(address: band.freq, value: .float32(100)),
            Replacement(address: band.gain, value: .float32(-6)),
            Replacement(address: band.q, value: .float32(4)),
            Replacement(address: band.on, value: .int32(1))
        ], link: client)
        let eqPackets = fake.received.dropFirst(beforeEq).compactMap { try? decodeOsc($0) }
        XCTAssertEqual(eqPackets.map(\.address), [band.freq, band.gain, band.q, band.on, band.freq, band.gain, band.q, band.on])
        XCTAssertFalse(eqPackets.map(\.address).contains(where: { $0.contains("eq_freq_2") }))
    }

    func testRefusedWriteIsNotASuccessAndTheStoredValueStays() throws {
        let fake = try FakeQuantum225()
        defer { fake.stop() }
        let delay = try delayAddresses(output: 1)
        fake.values[delay.delay] = .float32(1)
        fake.values[delay.fineDelay] = .float32(2)
        fake.refuse = [delay.fineDelay]
        let client = try Quantum225Client(host: "127.0.0.1", port: fake.port)
        defer { client.close() }
        XCTAssertThrowsError(try confirmReplace([
            Replacement(address: delay.delay, value: .float32(12.4)),
            Replacement(address: delay.fineDelay, value: .float32(12.4))
        ], link: client)) { error in
            XCTAssertEqual(error as? ConfirmError, .kept)
        }
        XCTAssertEqual(fake.values[delay.delay], .float32(1))
        XCTAssertEqual(fake.values[delay.fineDelay], .float32(2))
    }
}
