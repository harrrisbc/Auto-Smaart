import Foundation
import AutoSmaartCore

enum AddressError: Error, Equatable {
    case outputOutOfRange
    case bandOutOfRange
}

public func delayAddresses(output: Int) throws -> (delay: String, fineDelay: String) {
    try delayAddresses(kind: .matrix, index: output)
}

public func delayAddresses(kind: CalibrationBusKind, index: Int) throws -> (delay: String, fineDelay: String) {
    guard kind.indexRange.contains(index) else { throw AddressError.outputOutOfRange }
    let prefix = "\(kind.oscPrefix)/\(index)/Channel_Delay"
    return (prefix + "/delay", prefix + "/fine_delay")
}

public func eqAddresses(output: Int, band: Int) throws -> (freq: String, gain: String, q: String, on: String) {
    try eqAddresses(kind: .matrix, index: output, band: band)
}

public func eqAddresses(kind: CalibrationBusKind, index: Int, band: Int) throws -> (freq: String, gain: String, q: String, on: String) {
    guard kind.indexRange.contains(index) else { throw AddressError.outputOutOfRange }
    guard (1...8).contains(band) else { throw AddressError.bandOutOfRange }
    let prefix = "\(kind.oscPrefix)/\(index)/EQ"
    return (
        prefix + "/eq_freq_\(band)",
        prefix + "/eq_gain_\(band)",
        prefix + "/eq_Q_\(band)",
        prefix + "/eq_on_\(band)"
    )
}

public func matrixMuteAddress(output: Int) throws -> String {
    try busMuteAddress(kind: .matrix, index: output)
}

public func busMuteAddress(kind: CalibrationBusKind, index: Int) throws -> String {
    guard kind.indexRange.contains(index) else { throw AddressError.outputOutOfRange }
    return "\(kind.oscPrefix)/\(index)/mute"
}
