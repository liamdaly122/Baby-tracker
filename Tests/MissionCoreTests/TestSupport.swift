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

/// UK thresholds with the pattern hold switched on at an hour, as a midwife might ask.
let ukWithHour = ThresholdTable.builtIn(for: .uk).profile(applying: [.patternWindowSec: 3600])

func ukInput(
    _ contractions: [Contraction],
    flags: Set<RedFlag> = [],
    profile: LabourProfile = LabourProfile(region: .uk, gestationalAgeDays: 280),
    thresholds: ThresholdProfile = ThresholdTable.builtIn(for: .uk).defaults,
    previous: EngineStateSnapshot? = nil,
    easedAt: Double? = nil,
    now: Double
) -> EngineInput {
    EngineInput(
        contractions: contractions,
        redFlags: flags,
        profile: profile,
        thresholds: thresholds,
        previous: previous,
        easedAt: easedAt.map(at),
        now: at(now)
    )
}

/// Contractions with these start-to-start gaps, from `first`, each `duration` long.
func withGaps(_ gaps: [Double], duration: Double = 50, first: Double = 0) -> [Contraction] {
    var starts = [first]
    for gap in gaps {
        starts.append(starts[starts.count - 1] + gap)
    }
    return starts.map { Contraction(start: at($0), end: at($0 + duration)) }
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
