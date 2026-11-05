import Foundation
@testable import SmaartAPI

final class ScriptedWire: SmaartWire {
    var sent: [String] = []
    var replies: [String]
    var isOpen = false
    init(replies: [String]) { self.replies = replies }
    func connect() throws { isOpen = true }
    func close() { isOpen = false }
    func send(_ text: String) throws { sent.append(text) }
    func receive() throws -> String {
        guard !replies.isEmpty else { throw SmaartReaderError.noTrace }
        return replies.removeFirst()
    }
}

enum JSONValue: Equatable {
    case string(String)
    case bool(Bool)
    case number(Double)
    case object([String: JSONValue])
    case array([JSONValue])
    case null
}

extension JSONValue: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let value = try? container.decode(Bool.self) { self = .bool(value); return }
        if let value = try? container.decode(Double.self) { self = .number(value); return }
        if let value = try? container.decode(String.self) { self = .string(value); return }
        if let value = try? container.decode([String: JSONValue].self) { self = .object(value); return }
        if let value = try? container.decode([JSONValue].self) { self = .array(value); return }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "unknown JSON")
    }
}
