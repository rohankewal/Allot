import Foundation

/// SplitMix64. Seedable and identical on every device and OS version, which
/// Swift's own generator isn't, so everyone gets the same puzzle each day.
nonisolated struct SeededRandom: Sendable {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// 0..<n. The modulo bias is far too small to matter for n this small.
    mutating func int(_ n: Int) -> Int {
        precondition(n > 0)
        return Int(next() % UInt64(n))
    }

    /// An index chosen with probability proportional to its weight.
    mutating func weighted(_ weights: [Int]) -> Int {
        let total = weights.reduce(0, +)
        var pick = int(total)
        for (i, w) in weights.enumerated() {
            if pick < w { return i }
            pick -= w
        }
        return weights.count - 1
    }
}
