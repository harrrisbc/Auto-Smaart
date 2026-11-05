import Foundation
import AutoSmaartCore

public enum AddressError: Error, Equatable {
    case outputOutOfRange
    case bandOutOfRange
    case stripOutOfRange
}

public func stripPrefix(kind: StripKind, index: Int) throws -> String {
    guard stripIndexRange(kind).contains(index) else { throw AddressError.stripOutOfRange }
    switch kind {
    case .inputChannel: return "/sd/Input_Channels/\(index)"
    case .groupBus: return "/sd/Group_Outputs/\(index)"
    case .auxBus: return "/sd/Aux_Outputs/\(index)"
    case .matrixBus: return "/sd/Matrix_Outputs/\(index)"
    }
}

public func faderAddress(kind: StripKind, index: Int) throws -> String {
    try stripPrefix(kind: kind, index: index) + "/fader"
}

public func muteAddress(kind: StripKind, index: Int) throws -> String {
    try stripPrefix(kind: kind, index: index) + "/mute"
}

public func eqAddresses(kind: StripKind, index: Int, band: Int) throws -> (freq: String, gain: String, q: String, on: String) {
    guard (1...8).contains(band) else { throw AddressError.bandOutOfRange }
    let prefix = try stripPrefix(kind: kind, index: index) + "/EQ"
    return (
        prefix + "/eq_freq_\(band)",
        prefix + "/eq_gain_\(band)",
        prefix + "/eq_Q_\(band)",
        prefix + "/eq_on_\(band)"
    )
}

public func delayAddresses(output: Int) throws -> (delay: String, fineDelay: String) {
    try delayAddresses(kind: .matrixBus, index: output)
}

public func delayAddresses(kind: StripKind, index: Int) throws -> (delay: String, fineDelay: String) {
    switch kind {
    case .matrixBus, .auxBus:
        break
    case .inputChannel, .groupBus:
        throw AddressError.stripOutOfRange
    }
    let prefix = try stripPrefix(kind: kind, index: index) + "/Channel_Delay"
    return (prefix + "/delay", prefix + "/fine_delay")
}

public func eqAddresses(output: Int, band: Int) throws -> (freq: String, gain: String, q: String, on: String) {
    do {
        return try eqAddresses(kind: .matrixBus, index: output, band: band)
    } catch AddressError.stripOutOfRange {
        throw AddressError.outputOutOfRange
    }
}

public func muteAllAddresses() -> [String] {
    var addresses: [String] = []
    for i in 1...72 { addresses.append("/sd/Input_Channels/\(i)/mute") }
    for g in 1...24 { addresses.append("/sd/Group_Outputs/\(g)/mute") }
    for a in 1...24 { addresses.append("/sd/Aux_Outputs/\(a)/mute") }
    for m in 1...12 { addresses.append("/sd/Matrix_Outputs/\(m)/mute") }
    addresses.append("/sd/Master_Outputs/1/mute")
    return addresses
}
