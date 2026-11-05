import Foundation
import AutoSmaartCore
import ConsoleOSC

public struct FaderDriver {
    private let kind: StripKind
    private let index: Int
    private let link: OscLink

    public init(kind: StripKind, index: Int, link: OscLink) {
        self.kind = kind
        self.index = index
        self.link = link
    }

    public func read() throws -> FaderLevel {
        let address = try faderAddress(kind: kind, index: index)
        let value = try link.read(address: address)
        guard case .float32(let wire) = value else { throw ConfirmError.kept }
        return faderLevel(fromWire: wire)
    }

    public func write(_ level: FaderLevel) throws {
        let address = try faderAddress(kind: kind, index: index)
        try link.write(address: address, value: .float32(faderWire(from: level)))
    }

    public func raiseByHalfDb() throws -> FaderLevel {
        let next = raisedFader(try read(), by: 0.5)
        try write(next)
        return next
    }

    public func writeMinusInfinity() throws {
        try write(.minusInfinity)
    }
}
