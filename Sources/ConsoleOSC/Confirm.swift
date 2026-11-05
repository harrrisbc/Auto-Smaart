import Foundation
import AutoSmaartCore

public struct Replacement: Equatable {
    public var address: String
    public var value: OscValue
    public init(address: String, value: OscValue) {
        self.address = address
        self.value = value
    }
}

public enum ConfirmError: Error, Equatable {
    case kept
    case mismatch
}

public protocol OscLink: AnyObject {
    func read(address: String) throws -> OscValue
    func write(address: String, value: OscValue) throws
}

public func confirmReplace(_ items: [Replacement], link: OscLink) throws -> [Replacement] {
    var restore: [Replacement] = []
    for item in items {
        do {
            restore.append(Replacement(address: item.address, value: try link.read(address: item.address)))
        } catch {
            throw ConfirmError.kept
        }
    }
    var accepted = 0
    for item in items {
        do {
            try link.write(address: item.address, value: item.value)
            accepted += 1
        } catch {
            var restoreFailed = false
            for previous in restore.prefix(accepted) {
                do { try link.write(address: previous.address, value: previous.value) }
                catch { restoreFailed = true }
            }
            throw restoreFailed ? ConfirmError.mismatch : ConfirmError.kept
        }
    }
    return restore
}

public func writeOnly(_ items: [Replacement], link: OscLink) throws {
    var accepted = 0
    for item in items {
        do {
            try link.write(address: item.address, value: item.value)
            accepted += 1
        } catch {
            throw accepted == 0 ? ConfirmError.kept : ConfirmError.mismatch
        }
    }
}
