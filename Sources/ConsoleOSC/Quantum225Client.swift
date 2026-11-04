import Foundation
import Darwin
import AutoSmaartCore

public enum OscTransportError: Error { case notAccepted, badHost }

public final class Quantum225Client: OscLink {
    private let fd: Int32
    private let timeout: TimeInterval
    private var destination = sockaddr_in()

    public init(host: String, port: UInt16, timeout: TimeInterval = 1.0) throws {
        self.timeout = timeout
        fd = socket(AF_INET, SOCK_DGRAM, 0)
        if fd < 0 { throw OscTransportError.notAccepted }
        destination.sin_family = sa_family_t(AF_INET)
        destination.sin_port = port.bigEndian
        if inet_aton(host, &destination.sin_addr) == 0 { throw OscTransportError.badHost }
        var tv = timeval(tv_sec: Int(timeout), tv_usec: Int32((timeout - floor(timeout)) * 1_000_000))
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    }

    public func close() { Darwin.close(fd) }

    public func read(address: String) throws -> OscValue {
        try send(encodeOsc(address: address, value: nil))
        let reply = try receive()
        guard reply.address == address, let value = reply.value else { throw OscTransportError.notAccepted }
        return value
    }

    public func write(address: String, value: OscValue) throws {
        try send(encodeOsc(address: address, value: value))
        let reply = try receive()
        guard reply.address == address, reply.value == value else { throw OscTransportError.notAccepted }
    }

    private func send(_ data: Data) throws {
        let result = data.withUnsafeBytes { raw in
            withUnsafePointer(to: &destination) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sendto(fd, raw.baseAddress, data.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
            }
        }
        if result < 0 { throw OscTransportError.notAccepted }
    }

    private func receive() throws -> (address: String, value: OscValue?) {
        var buffer = [UInt8](repeating: 0, count: 2048)
        let count = recv(fd, &buffer, buffer.count, 0)
        if count <= 0 { throw OscTransportError.notAccepted }
        return try decodeOsc(Data(buffer.prefix(count)))
    }
}
