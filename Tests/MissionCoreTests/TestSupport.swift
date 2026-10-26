import Foundation

@testable import MissionCore

let origin = Date(timeIntervalSince1970: 1_800_000_000)

func at(_ seconds: Double) -> Date {
    origin.addingTimeInterval(seconds)
}

/// `count` contractions every `every` seconds from `first`, each `duration` long.
func regular(count: Int, every: Double, duration: Double, first: Double = 0) -> [Contraction] {
    (0..<count).map { index in
        let start = at(first + Double(index) * every)
        return Contraction(start: start, end: start.addingTimeInterval(duration))
    }
}

func ukInput(
    _ contractions: [Contraction],
    flags: Set<RedFlag> = [],
    profile: LabourProfile = LabourProfile(region: .uk, gestationalAgeDays: 280),
    previous: EngineStateSnapshot? = nil,
    now: Double
) -> EngineInput {
    EngineInput(
        contractions: contractions,
        redFlags: flags,
        profile: profile,
        thresholds: ThresholdTable.builtIn(for: .uk).defaults,
        previous: previous,
        now: at(now)
    )
}

/// SplitMix64: a small seeded generator so random tests repeat exactly on every platform.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }
}
