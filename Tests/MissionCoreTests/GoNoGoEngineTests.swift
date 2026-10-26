import Foundation
import Testing

@testable import MissionCore

@Suite("Go/no-go engine")
struct GoNoGoEngineTests {
    // MARK: Red flags

    @Test("Each red flag on its own forces its level", arguments: RedFlag.allCases)
    func redFlagAlone(flag: RedFlag) {
        let output = GoNoGoEngine.evaluate(ukInput([], flags: [flag], now: 60))
        #expect(output.state == flag.state)
        #expect(output.reasons == [flag.reason])
    }

    @Test("Red flags map to the NHS levels")
    func redFlagLevels() {
        let call999: Set<RedFlag> = [.urgeToPush, .cordVisible, .seizureCollapse, .heavyBleeding]
        for flag in RedFlag.allCases {
            #expect(flag.state == (call999.contains(flag) ? .call999 : .callNow), "\(flag)")
        }
    }

    @Test("Red flags never time out, and clear as soon as they're switched off")
    func redFlagsHold() {
        let first = GoNoGoEngine.evaluate(ukInput([], flags: [.watersBroken], now: 0))
        let tenHoursLater = GoNoGoEngine.evaluate(
            ukInput([], flags: [.watersBroken], previous: first.snapshot, now: 36_000)
        )
        #expect(tenHoursLater.state == .callNow)
        #expect(tenHoursLater.enteredAt == at(0))

        let switchedOff = GoNoGoEngine.evaluate(ukInput([], previous: tenHoursLater.snapshot, now: 36_060))
        #expect(switchedOff.state == .early)
        #expect(!switchedOff.isEasing)
    }

    @Test("Several 999 flags are all listed")
    func severalFlags() {
        let output = GoNoGoEngine.evaluate(ukInput([], flags: [.cordVisible, .urgeToPush, .bleeding], now: 60))
        #expect(output.state == .call999)
        #expect(output.reasons == [.urgeToPush, .cordVisible])
    }

    @Test("Red flag and contraction reasons at the same level are both listed")
    func sameLevelReasons() {
        let output = GoNoGoEngine.evaluate(
            ukInput(regular(count: 6, every: 100, duration: 40), flags: [.bleeding], now: 560))
        #expect(output.state == .callNow)
        #expect(output.reasons == [.bleeding, .tooManyInTenMinutes])
    }

    @Test("Unknown gestation never triggers the preterm rule")
    func unknownGestation() {
        let output = GoNoGoEngine.evaluate(ukInput([], profile: LabourProfile(region: .uk), now: 60))
        #expect(output.state == .early)
    }

    // MARK: Hysteresis

    @Test("A rise is immediate")
    func riseIsImmediate() {
        let calm = GoNoGoEngine.evaluate(ukInput(regular(count: 3, every: 300, duration: 50), now: 700))
        #expect(calm.state == .early)
        let urgent = GoNoGoEngine.evaluate(
            ukInput(
                regular(count: 3, every: 300, duration: 50), flags: [.reducedMovements], previous: calm.snapshot,
                now: 710)
        )
        #expect(urgent.state == .callNow)
        #expect(urgent.enteredAt == at(710))
    }

    @Test("Advice holds for 15 minutes after the pattern eases, then drops")
    func dropAfterDwell() {
        let log = regular(count: 17, every: 240, duration: 50)  // last start at 3840
        var output = GoNoGoEngine.evaluate(ukInput(log, now: 3900))
        #expect(output.state == .callTriage)

        // The pattern goes stale 3 median intervals (720 s) after the last start.
        output = GoNoGoEngine.evaluate(ukInput(log, previous: output.snapshot, now: 4561))
        #expect(output.state == .callTriage)
        #expect(output.isEasing)
        #expect(output.reasons == [.regularPatternSustained, .patternEasing])
        #expect(output.nextReviewAt == at(4561 + 900))

        output = GoNoGoEngine.evaluate(ukInput(log, previous: output.snapshot, now: 4561 + 600))
        #expect(output.state == .callTriage)
        #expect(output.isEasing)

        output = GoNoGoEngine.evaluate(ukInput(log, previous: output.snapshot, now: 4561 + 900))
        #expect(output.state == .early)
        #expect(!output.isEasing)
        #expect(output.enteredAt == at(4561 + 900))
    }

    @Test("Contractions picking up again cancel the drop")
    func dropCancelled() {
        let hold = Advice(state: .callTriage, reasons: [.regularPatternSustained])
        let eased = Hysteresis.apply(
            raw: Advice(state: .early, reasons: [.noRegularPattern]),
            previous: HeldAdvice(advice: hold, enteredAt: at(0), pendingDrop: nil),
            now: at(100)
        )
        #expect(eased.pendingDrop != nil)
        let back = Hysteresis.apply(raw: hold, previous: eased, now: at(200))
        #expect(back.advice == hold)
        #expect(back.pendingDrop == nil)
        #expect(back.enteredAt == at(0))
    }

    @Test("A drop lands on the highest state seen during the dwell")
    func dropToHighestSeen() {
        let start = HeldAdvice(
            advice: Advice(state: .callNow, reasons: [.tooManyInTenMinutes]),
            enteredAt: at(0),
            pendingDrop: nil
        )
        let building = Advice(state: .establishing, reasons: [.patternBuilding])
        let early = Advice(state: .early, reasons: [.noRegularPattern])
        var held = Hysteresis.apply(raw: early, previous: start, now: at(100))
        held = Hysteresis.apply(raw: building, previous: held, now: at(400))
        held = Hysteresis.apply(raw: early, previous: held, now: at(1000))
        #expect(held.advice == building)
        #expect(held.pendingDrop?.target == early)
        #expect(held.pendingDrop?.since == at(1000))
    }

    // MARK: Thresholds

    @Test("Overrides are clamped to safe bounds")
    func clamping() {
        let table = ThresholdTable.builtIn(for: .uk)
        let profile = table.profile(applying: [
            .patternWindowSec: 7200,
            .urgentSingleDurationSec: 300,
            .urgentCountIn10Min: 10,
            .adviceIntervalSec: 60,
            .regularityCV: 2,
            .earlyCallerWindowSec: 600,
        ])
        #expect(profile.patternWindowSec == 3600)
        #expect(profile.urgentSingleDurationSec == 120)
        #expect(profile.urgentCountIn10Min == 6)
        #expect(profile.adviceIntervalSec == 180)
        #expect(profile.regularityCV == 0.5)
        #expect(profile.earlyCallerWindowSec == 1800)
    }

    @Test("Duration rule: 0 or less switches it off, anything else is clamped to 30–90 s")
    func durationClamping() {
        let table = ThresholdTable.builtIn(for: .uk)
        #expect(table.profile(applying: [.adviceDurationSec: 0]).adviceDurationSec == 0)
        #expect(table.profile(applying: [.adviceDurationSec: -5]).adviceDurationSec == 0)
        #expect(table.profile(applying: [.adviceDurationSec: 10]).adviceDurationSec == 30)
        #expect(table.profile(applying: [.adviceDurationSec: 200]).adviceDurationSec == 90)
        #expect(table.profile(applying: [.adviceDurationSec: 45]).adviceDurationSec == 45)
    }

    @Test("Non-finite overrides fall back to the default")
    func nonFinite() {
        let table = ThresholdTable.builtIn(for: .uk)
        #expect(table.profile(applying: [.adviceIntervalSec: .nan]).adviceIntervalSec == 300)
        #expect(table.profile(applying: [.patternWindowSec: .infinity]).patternWindowSec == 3600)
    }

    @Test("Fixed fields are not editable")
    func editability() {
        let table = ThresholdTable.builtIn(for: .uk)
        #expect(!table.limit(for: .earlyCallerWindowSec).isEditable)
        #expect(!table.limit(for: .travelEarlyCallMinutes).isEditable)
        #expect(table.limit(for: .adviceIntervalSec).isEditable)
        #expect(table.limit(for: .adviceDurationSec).isEditable)
    }

    @Test("Early-caller adjustments don't stack below the early-caller window")
    func noStacking() {
        let thresholds = ThresholdTable.builtIn(for: .uk).profile(applying: [.patternWindowSec: 1800])
        let everything = LabourProfile(region: .uk, parity: 2, previousFastLabour: true, travelMinutes: 90)
        #expect(GoNoGoEngine.requiredSustainedSec(profile: everything, thresholds: thresholds) == 1800)
        let defaults = ThresholdTable.builtIn(for: .uk).defaults
        #expect(GoNoGoEngine.requiredSustainedSec(profile: everything, thresholds: defaults) == 1800)
        #expect(GoNoGoEngine.requiredSustainedSec(profile: LabourProfile(region: .uk), thresholds: defaults) == 3600)
    }

    // MARK: Scheduling

    @Test("Next review: an open contraction passing the urgent duration")
    func reviewOpenContraction() {
        let open = Contraction(start: at(1000), end: nil)
        let output = GoNoGoEngine.evaluate(ukInput([open], now: 1030))
        #expect(output.nextReviewAt == at(1121))
    }

    @Test("Next review: a pattern reaching its required hour")
    func reviewSustained() {
        // Every 4 min from 0; at 59 min the last start is 56 min, so the hour is reachable at 60 min.
        let output = GoNoGoEngine.evaluate(ukInput(regular(count: 15, every: 240, duration: 50), now: 3540))
        #expect(output.state == .establishing)
        #expect(output.nextReviewAt == at(3600))
    }

    // MARK: Determinism

    @Test("Evaluation is deterministic and ignores input order over 500 random logs")
    func determinism() {
        var rng = SeededGenerator(seed: 0x4D49_5353_494F_4E)
        for _ in 0..<500 {
            let input = randomInput(using: &rng)
            let first = GoNoGoEngine.evaluate(input)
            #expect(GoNoGoEngine.evaluate(input) == first)

            var shuffled = input
            shuffled.contractions.shuffle(using: &rng)
            #expect(GoNoGoEngine.evaluate(shuffled) == first)

            // Invariants that hold for any log.
            #expect(!first.reasons.isEmpty)
            for flag in input.redFlags {
                #expect(first.state >= flag.state)
            }
            #expect(first.metrics.analysedCount <= input.contractions.count)
            if let nextReview = first.nextReviewAt {
                #expect(nextReview > input.now)
            }
        }
    }

    @Test("Feeding each snapshot back in stays deterministic")
    func determinismWithHistory() {
        var rng = SeededGenerator(seed: 42)
        for _ in 0..<50 {
            let input = randomInput(using: &rng)
            #expect(run(input, steps: 6) == run(input, steps: 6))
        }
    }

    /// Evaluates every 5 minutes from `input.now`, feeding each snapshot into the next run.
    private func run(_ input: EngineInput, steps: Int) -> [EngineOutput] {
        var input = input
        let start = input.now
        var outputs: [EngineOutput] = []
        for step in 0..<steps {
            input.now = start.addingTimeInterval(Double(step) * 300)
            input.previous = outputs.last?.snapshot
            outputs.append(GoNoGoEngine.evaluate(input))
        }
        return outputs
    }

    private func randomInput(using rng: inout SeededGenerator) -> EngineInput {
        let region: ContentRegion = Bool.random(using: &rng) ? .uk : .us
        var contractions: [Contraction] = []
        var cursor = 0.0
        let count = Int.random(in: 0...40, using: &rng)
        for index in 0..<count {
            cursor += Double.random(in: 30...900, using: &rng)
            let start = at(cursor)
            let isLast = index == count - 1
            let end: Date? =
                isLast && Bool.random(using: &rng)
                ? nil : start.addingTimeInterval(Double.random(in: 10...150, using: &rng))
            contractions.append(Contraction(start: start, end: end))
        }
        let flags = Set(RedFlag.allCases.filter { _ in Int.random(in: 0..<10, using: &rng) == 0 })
        let profile = LabourProfile(
            region: region,
            parity: Int.random(in: 0...2, using: &rng),
            previousFastLabour: Bool.random(using: &rng),
            gestationalAgeDays: Int.random(in: 250...294, using: &rng),
            travelMinutes: Int.random(in: 5...60, using: &rng)
        )
        return EngineInput(
            contractions: contractions,
            redFlags: flags,
            profile: profile,
            thresholds: ThresholdTable.builtIn(for: region).defaults,
            now: at(cursor + Double.random(in: 0...1200, using: &rng))
        )
    }
}
