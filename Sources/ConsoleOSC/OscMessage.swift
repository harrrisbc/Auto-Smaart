import Foundation
import AutoSmaartCore

enum OscCodecError: Error { case shortPacket, badType }

func encodeOsc(address: String, value: OscValue?) -> Data {
    var data = oscString(address)
    switch value {
    case nil:
        data.append(oscString(","))
    case .float32(let number):
        data.append(oscString(",f"))
        var big = number.bitPattern.bigEndian
        data.append(Data(bytes: &big, count: 4))
    case .int32(let number):
        data.append(oscString(",i"))
        var big = number.bigEndian
        data.append(Data(bytes: &big, count: 4))
    }
    return data
}

func decodeOsc(_ data: Data) throws -> (address: String, value: OscValue?) {
    var offset = 0
    let address = try readOscString(data, &offset)
    let tags = try readOscString(data, &offset)
    if tags == "," { return (address, nil) }
    if tags == ",f" {
        guard offset + 4 <= data.count else { throw OscCodecError.shortPacket }
        let bits = UInt32(bigEndian: data.subdata(in: offset..<(offset + 4)).withUnsafeBytes { $0.load(as: UInt32.self) })
        return (address, .float32(Float(bitPattern: bits)))
    }
    if tags == ",i" {
        guard offset + 4 <= data.count else { throw OscCodecError.shortPacket }
        let bits = Int32(bigEndian: data.subdata(in: offset..<(offset + 4)).withUnsafeBytes { $0.load(as: Int32.self) })
        return (address, .int32(bits))
    }
    throw OscCodecError.badType
}

private func oscString(_ text: String) -> Data {
    var data = Data(text.utf8)
    data.append(0)
    while data.count % 4 != 0 { data.append(0) }
    return data
}

private func readOscString(_ data: Data, _ offset: inout Int) throws -> String {
    guard let end = data[offset...].firstIndex(of: 0) else { throw OscCodecError.shortPacket }
    let text = String(data: data[offset..<end], encoding: .utf8) ?? ""
    offset = end + 1
    while offset % 4 != 0 { offset += 1 }
    return text
}
