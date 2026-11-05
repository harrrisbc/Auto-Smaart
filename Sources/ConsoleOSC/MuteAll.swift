import Foundation
import AutoSmaartCore

public struct MuteAllResult: Equatable {
    public var attempted: Int
    public var accepted: Int
    public init(attempted: Int, accepted: Int) {
        self.attempted = attempted
        self.accepted = accepted
    }
}

public func muteAll(link: OscLink) -> MuteAllResult {
    let addresses = muteAllAddresses()
    var accepted = 0
    for address in addresses {
        do {
            try link.write(address: address, value: .int32(1))
            accepted += 1
        } catch {
            // Keep going. Stop prefers mute over tidy state.
        }
    }
    return MuteAllResult(attempted: addresses.count, accepted: accepted)
}
