import Foundation
import Testing

@testable import MissionCore

@Suite("Call-rate paths, each on its own")
struct CallRatePathTests {
    private let defaults = ThresholdTable.builtIn(for: .uk).defaults

    private struct MetPaths {
        var counted: Bool
        var median: Bool
        var frequency: Bool
    }

    private func paths(_ output: EngineOutput) -> MetPaths {
        let values = output.metrics.recentIntervalsSec
        let counted = Double(values.filter { $0 <= 300 }.count) >= 0.75 * Double(values.count)
        let median =
            (output.metrics.recentMedianIntervalSec ?? .infinity) <= 300
            && (output.metrics.recentUpperQuartileSec ?? .infinity) <= 405
        let frequency = GoNoGoEngine.meetsFrequency(output.metrics.runIntervalsSec, limit: 300)
        return MetPaths(counted: counted, median: median, frequency: frequency)
    }

    @Test("Median path only: 3 gaps around 5 minutes, one just over")
    func medianOnly() {
        let output = GoNoGoEngine.evaluate(ukInput(withGaps([300, 305, 295]), now: 905))
        let met = paths(output)
        #expect(!met.counted && met.median && !met.frequency)
        #expect(output.state == .callTriage)
    }

    @Test("Counted path only: 3 of 4 gaps under 5 minutes, one long one")
    func countedOnly() {
        let output = GoNoGoEngine.evaluate(ukInput(withGaps([50, 60, 280, 800]), now: 1195))
        let met = paths(output)
        #expect(met.counted && !met.median && !met.frequency)
        #expect(output.state == .callTriage)
    }

    @Test("Frequency path only: coupled contractions, 1 then 7 minutes")
    func frequencyOnly() {
        let gaps = (0..<12).map { $0 % 2 == 0 ? 60.0 : 420 }
        let output = GoNoGoEngine.evaluate(ukInput(withGaps(gaps), now: gaps.reduce(0, +) + 30))
        let met = paths(output)
        #expect(!met.counted && !met.median && met.frequency)
        #expect(output.state == .callTriage)
        #expect(output.metrics.missedTapGaps.isEmpty)
        let line = StateCopy.reasonLine(for: .regularPatternSustained, metrics: output.metrics, thresholds: defaults)
        #expect(line.hasPrefix("Frequent, every 1 min to 7 min"), "\(line)")
    }

    @Test("A burst of quick taps on early labour doesn't count as frequent")
    func burstNotFrequent() {
        let gaps: [Double] = [540, 540, 540, 480, 480, 480, 40, 40]
        let output = GoNoGoEngine.evaluate(ukInput(withGaps(gaps), now: gaps.reduce(0, +) + 30))
        #expect(output.state < .callTriage)
    }

    @Test("A gap over twice the limit rules out the frequency path")
    func longGapNotFrequent() {
        #expect(!GoNoGoEngine.meetsFrequency([100, 100, 100, 100, 100, 700], limit: 300))
        #expect(GoNoGoEngine.meetsFrequency([100, 100, 100, 100, 100, 600], limit: 300))
        #expect(!GoNoGoEngine.meetsFrequency([60, 360, 60, 360, 60], limit: 300))
    }

    // Log-level monotonicity can't hold exactly: a shorter gap compresses time, so a hold (US, or a
    // midwife's) isn't reached yet, and an older, longer gap can slide into the 20-minute window.
    // What must hold is that the rule itself is one-sided over the intervals it's given.
    @Test("The call rule is one-sided: shortening any interval never fails it, over 5,000 random sets")
    func shorteningNeverFailsTheRule() {
        var rng = SeededGenerator(seed: 0x5407_7E2)
        for _ in 0..<5000 {
            let base = Double.random(in: 100...500, using: &rng)
            let recent = (0..<Int.random(in: 3...8, using: &rng)).map { _ in
                base * Double.random(in: 0.3...2, using: &rng)
            }
            let run = (0..<Int.random(in: 3...14, using: &rng)).map { _ in
                base * Double.random(in: 0.3...2, using: &rng)
            }
            for limit in [300.0, 450]
            where GoNoGoEngine.meetsRate(recent: recent, run: run, limit: limit, regularityCV: 0.35) {
                var shorterRecent = recent
                shorterRecent[Int.random(in: 0..<recent.count, using: &rng)] *= Double.random(
                    in: 0.1...0.99, using: &rng)
                var shorterRun = run
                shorterRun[Int.random(in: 0..<run.count, using: &rng)] *= Double.random(in: 0.1...0.99, using: &rng)
                #expect(GoNoGoEngine.meetsRate(recent: shorterRecent, run: run, limit: limit, regularityCV: 0.35))
                #expect(GoNoGoEngine.meetsRate(recent: recent, run: shorterRun, limit: limit, regularityCV: 0.35))
            }
        }
    }
}

@Suite("Alerts at a 999 moment")
struct NineNineNineAlertTests {
    @Test("Heavy bleeding, then a contraction passes 2 minutes: no 'call your unit' alert")
    func heavyBleedingAndLongContraction() {
        let flags: Set<RedFlag> = [.heavyBleeding]
        let open = [Contraction(start: at(1000), end: nil)]
        let before = GoNoGoEngine.evaluate(ukInput(open, flags: flags, now: 1010))
        let after = GoNoGoEngine.evaluate(ukInput(open, flags: flags, previous: before.snapshot, now: 1130))
        #expect(after.state == .call999)
        #expect(LabourAlertPlanner.immediate(previous: before.snapshot, output: after, region: .uk).isEmpty)
    }

    @Test("Urge to push, then 6 in 10: no 'call your unit' alert")
    func urgeToPushAndSixInTen() {
        let flags: Set<RedFlag> = [.urgeToPush]
        let first = GoNoGoEngine.evaluate(ukInput([], flags: flags, now: 0))
        let six = regular(count: 6, every: 90, duration: 40, first: 60)
        let later = GoNoGoEngine.evaluate(ukInput(six, flags: flags, previous: first.snapshot, now: 520))
        let alerts = LabourAlertPlanner.immediate(previous: first.snapshot, output: later, region: .uk)
        #expect(alerts.allSatisfy { $0.title != "Call your maternity unit now" })
        #expect(alerts.isEmpty)
    }

    @Test("One long contraction is one alert: the nudge, the open reason and the stop share an identifier")
    func oneLongContraction() {
        let session = UUID()
        let flags: Set<RedFlag> = [.watersBroken]
        let open = [Contraction(start: at(1000), end: nil)]
        let input = ukInput(open, flags: flags, now: 1010)
        let early = GoNoGoEngine.evaluate(input)
        let nudge = LabourAlertPlanner.scheduled(input: input, output: early).first { $0.kind == .stillGoing }
        let passed = GoNoGoEngine.evaluate(ukInput(open, flags: flags, previous: early.snapshot, now: 1122))
        let openAlert = LabourAlertPlanner.immediate(previous: early.snapshot, output: passed, region: .uk)
        #expect(openAlert.map { $0.identifier(sessionID: session) } == [nudge?.identifier(sessionID: session)])
        #expect(openAlert.first?.fireAt == at(1122))

        let stopped = [Contraction(start: at(1000), end: at(1150))]
        let afterStop = GoNoGoEngine.evaluate(ukInput(stopped, flags: flags, previous: passed.snapshot, now: 1151))
        #expect(afterStop.contractionAdvice.reasons.contains(.contractionOverUrgentDuration))
        #expect(LabourAlertPlanner.immediate(previous: passed.snapshot, output: afterStop, region: .uk).isEmpty)
    }
}

@Suite("They've stopped, tapped by mistake")
struct StoppedMisTapTests {
    @Test(
        "The next contraction within 3× the pace cancels it; later than that, it stands",
        arguments: [(1.5, true), (2.9, true), (3.2, false)]
    )
    func cancelWindow(ratio: Double, cancelled: Bool) {
        let log = regular(count: 10, every: 240, duration: 50)  // last start 2160
        let next = 2160 + 240 * ratio
        let withNext = log + [Contraction(start: at(next), end: at(next + 50))]
        let tapped = GoNoGoEngine.evaluate(ukInput(withNext, easedAt: 2200, now: next + 55))
        let never = GoNoGoEngine.evaluate(ukInput(withNext, now: next + 55))
        if cancelled {
            // Exactly as if he'd never tapped it.
            #expect(tapped.state == never.state && tapped.reasons == never.reasons, "ratio \(ratio)")
        } else {
            // A new run starts after the stop.
            #expect(tapped.reasons == [.notEnoughContractions], "ratio \(ratio)")
        }
    }

    @Test("A cancelled stop keeps the call-point time, so a hold doesn't come back")
    func keepsCallPoint() {
        let log = regular(count: 17, every: 240, duration: 50)  // last start 3840
        let met = GoNoGoEngine.evaluate(ukInput(log, thresholds: ukWithHour, now: 3845))
        #expect(met.state == .callTriage)
        let metAt = met.snapshot.callRuleMetAt
        let stopped = GoNoGoEngine.evaluate(
            ukInput(log, thresholds: ukWithHour, previous: met.snapshot, easedAt: 3900, now: 3910))
        #expect(stopped.state == .early)
        let next = log + [Contraction(start: at(4080), end: at(4130))]
        let back = GoNoGoEngine.evaluate(
            ukInput(next, thresholds: ukWithHour, previous: stopped.snapshot, easedAt: 3900, now: 4135))
        #expect(back.state == .callTriage)
        #expect(back.snapshot.callRuleMetAt == metAt)
    }
}

@Suite("Activity hold limits")
struct ActivityHoldTests {
    @Test("One tap after hours of nothing doesn't bring back old advice")
    func afterHours() {
        let log = regular(count: 5, every: 240, duration: 50)
        let calling = GoNoGoEngine.evaluate(ukInput(log, now: 980))
        #expect(calling.state == .callTriage)
        let overnight = GoNoGoEngine.evaluate(ukInput(log, previous: calling.snapshot, now: 960 + 25_200))
        let oneTap = log + [Contraction(start: at(960 + 25_260), end: at(960 + 25_300))]
        let after = GoNoGoEngine.evaluate(ukInput(oneTap, previous: overnight.snapshot, now: 960 + 25_310))
        #expect(after.snapshot.holdingForTapsSince == nil)
        #expect(after.state < .callTriage || after.isEasing)
    }

    @Test("Deleting contractions doesn't hold advice up: the dwell starts at once")
    func deleteDoesNotHold() {
        let log = regular(count: 5, every: 240, duration: 50)
        let calling = GoNoGoEngine.evaluate(ukInput(log, now: 980))
        let trimmed = [log[0], log[4]]
        let after = GoNoGoEngine.evaluate(ukInput(trimmed, previous: calling.snapshot, now: 1030))
        #expect(after.isEasing)
        #expect(after.snapshot.holdingForTapsSince == nil)
    }
}

@Suite("Tapping after a forgotten stop")
struct ForgottenStopTapTests {
    @Test("After 'this is a new one', the next tap stops the new one, not the forgotten one")
    func tapTargetsLatest() {
        let session = UUID()
        var lamport: UInt64 = 0
        func event(_ kind: TapEventKind, _ time: Double, target: UUID? = nil) -> TapEvent {
            lamport += 1
            return TapEvent(
                sessionID: session, kind: kind, at: at(time), deviceID: "phone", lamport: lamport, target: target)
        }
        let first = event(.start, 0)
        let second = event(.start, 480)  // he chose "This is a new one"
        let log = EventLog.reduce([first, second])
        #expect(log.openContraction?.id == second.id)
        #expect(TapPolicy.action(open: log.openContraction, now: at(530)) == .stop(second.id, at: at(530)))
    }

    @Test("A start stamped hours ahead isn't something a tap stops")
    func futureOpen() {
        let future = Contraction(start: at(43_200), end: nil)
        #expect(TapPolicy.action(open: future, now: at(100)) == .start)
    }
}

@Suite("Phone numbers, round three")
struct PhoneNumberRoundThreeTests {
    private func parse(_ text: String, _ region: ContentRegion = .uk, overseas: Bool = false) -> Result<
        PhoneNumber, PhoneNumber.Problem
    > {
        PhoneNumber.parse(text, region: region, allowOverseas: overseas)
    }

    @Test("Real 9-digit numbers in areas with 5-digit local numbers are accepted")
    func mixedAreas() throws {
        let lancaster = try parse("01524 65944").get()
        #expect(lancaster.dialable == "+44152465944")
        #expect(lancaster.display == "01524 65944")
        #expect(try parse("+44 1524 65944").get().dialable == "+44152465944")
        #expect(try parse("0800 123 456").get().dialable == "+44800123456")
    }

    @Test("A 9-digit big-city number is still caught as a digit short")
    func bigCityShort() {
        #expect(parse("0113 392 673") == .failure(.tooShort))
        #expect(parse("0121 496 000") == .failure(.tooShort))
    }

    @Test("US numbers in UK mode, and invalid UK starts, are rejected")
    func crossRegion() {
        #expect(parse("(207) 946-0000") == .failure(.invalid))
        #expect(parse("4155552671") == .failure(.invalid))
        #expect(parse("06123456789") == .failure(.invalid))
        #expect(parse("04123456789") == .failure(.invalid))
    }

    @Test("A bracketed 0 after any country code isn't dialled")
    func overseasTrunkZero() throws {
        #expect(try parse("(+353) (0)87 123 4567", overseas: true).get().dialable == "+353871234567")
        #expect(try parse("+353 (0)87 123 4567", overseas: true).get().dialable == "+353871234567")
    }

    @Test("A saved number is re-parsed on decode: a mismatched display is corrected, a bad number fails")
    func decodeReparse() throws {
        let mismatched = #"{"raw":"0113 392 6731","dialable":"+447700900123","display":"0113 392 6731"}"#
        let fixed = try JSONDecoder().decode(PhoneNumber.self, from: Data(mismatched.utf8))
        #expect(fixed.display == "07700 900123")
        for bad in [
            #"{"raw":"x","dialable":"+44113392673","display":"x"}"#,
            #"{"raw":"x","dialable":"0113392673","display":"x"}"#,
        ] {
            #expect(throws: (any Error).self) { try JSONDecoder().decode(PhoneNumber.self, from: Data(bad.utf8)) }
        }
        #expect(try parse("0113 392 6731").get().isShortCode == false)
        #expect(PhoneNumber.shortCode("999")?.isShortCode == true)
    }
}
