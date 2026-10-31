import Foundation
import Testing

@testable import MissionCore

private var utc: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
    return calendar
}

@Suite("Call rule")
struct CallRuleTests {
    private let defaults = ThresholdTable.builtIn(for: .uk).defaults

    @Test(
        "Frequent contractions meet the call rule whatever their spread",
        arguments: [[180.0, 300], [120, 240], [120, 180, 240, 300], [150, 300], [100, 290, 200, 280]]
    )
    func frequentButUneven(cycle: [Double]) {
        let gaps = (0..<12).map { cycle[$0 % cycle.count] }
        let log = withGaps(gaps)
        let now = gaps.reduce(0, +) + 60
        let output = GoNoGoEngine.evaluate(ukInput(log, now: now))
        #expect(output.state == .callTriage, "\(cycle)")
    }

    @Test("Mostly over 5 minutes is not the call point, even if the median is under it")
    func mostlyOver() {
        // Gaps alternate 2 and 8 minutes: the median is 5, but half the gaps are 8.
        let gaps = (0..<12).map { $0 % 2 == 0 ? 120.0 : 480 }
        let output = GoNoGoEngine.evaluate(ukInput(withGaps(gaps), now: gaps.reduce(0, +) + 60))
        #expect(output.state < .callTriage)
    }

    @Test("Hostile thresholds are clamped inside the engine, so they can't switch off a safety rule")
    func hostileThresholds() {
        var hostile = defaults
        hostile.urgentSingleDurationSec = 600
        hostile.urgentCountIn10Min = 0
        hostile.adviceIntervalSec = 1
        hostile.patternWindowSec = 99_999
        let long = [Contraction(start: at(0), end: at(130))]
        let output = GoNoGoEngine.evaluate(ukInput(long, thresholds: hostile, now: 200))
        #expect(output.state == .callNow)
        #expect(output.reasons == [.contractionOverUrgentDuration])

        // An advice interval of 1 second is clamped to the 3-minute floor, and the hold to an hour.
        let regular = regular(count: 17, every: 240, duration: 50)
        let clamped = GoNoGoEngine.evaluate(ukInput(regular, thresholds: hostile, now: 3900))
        #expect(clamped.state == .establishing)
        #expect(clamped.reasons == [.patternBuilding])
        #expect(clamped.requiredSustainedSec == 3600)
    }

    @Test("The urgent rules look back an hour whatever the pattern hold is set to")
    func urgentLookBack() {
        let log = regular(count: 6, every: 100, duration: 40) + regular(count: 1, every: 0, duration: 40, first: 2400)
        let output = GoNoGoEngine.evaluate(ukInput(log, thresholds: ukWithHour, now: 2500))
        #expect(output.reasons.contains(.tooManyInTenMinutes))
    }

    @Test("Numbers never round across the call point")
    func noRoundingAcrossThreshold() {
        for tenths in 2400...5000 {
            let seconds = Double(tenths) / 10
            let rounded = StateCopy.guardedRound(seconds, step: 5, threshold: 300)
            #expect((rounded > 300) == (seconds > 300), "\(seconds) printed as \(rounded)")
        }
        #expect(StateCopy.clock(320, threshold: 300) == "5:20")
        #expect(StateCopy.clock(301, threshold: 300) == "5:05")
        #expect(StateCopy.clock(299, threshold: 300) == "5 min")
        #expect(StateCopy.clock(240) == "4 min")
    }

    @Test("Uneven but frequent reads as a range, not a single number")
    func unevenCopy() {
        let gaps = (0..<12).map { $0 % 2 == 0 ? 180.0 : 300 }
        let output = GoNoGoEngine.evaluate(ukInput(withGaps(gaps), now: gaps.reduce(0, +) + 60))
        let line = StateCopy.reasonLine(for: .regularPatternSustained, metrics: output.metrics, thresholds: defaults)
        #expect(line.hasPrefix("Frequent, every 3 min to 5 min"), "\(line)")
    }

    @Test("Building copy for a gap just over 5 minutes never says 5 min")
    func buildingCopy() {
        let output = GoNoGoEngine.evaluate(ukInput(regular(count: 8, every: 320, duration: 50), now: 2300))
        #expect(output.reasons == [.patternBuilding])
        let line = StateCopy.reasonLine(for: .patternBuilding, metrics: output.metrics, thresholds: defaults)
        #expect(line == "About every 5 min 20 sec, lasting about 50 sec. Not at the call point yet.")
    }

    @Test("With a hold set, the detail line counts down to it")
    func countdown() {
        let output = GoNoGoEngine.evaluate(
            ukInput(regular(count: 12, every: 240, duration: 50), thresholds: ukWithHour, now: 2700))
        #expect(output.reasons == [.patternNotYetSustained])
        let detail = StateCopy.detail(for: output, region: .uk, thresholds: ukWithHour)
        #expect(
            detail
                == "Call your maternity unit once this has gone on for 1 hour. About 15 min to go. "
                + "Call sooner if you were told to, or if you're worried.")
    }

    @Test("Held advice with nothing recent to measure says so, rather than 'every 0 min'")
    func heldWithoutRate() {
        let empty = ContractionMetrics.compute([], thresholds: defaults, now: at(0))
        for reason in [ReasonCode.regularPatternSustained, .patternNotYetSustained, .patternBuilding] {
            let line = StateCopy.reasonLine(for: reason, metrics: empty, thresholds: defaults)
            #expect(line.hasSuffix("Nothing recent to measure yet."), "\(line)")
        }
    }

    @Test("The quiet-log prompt says how long it has been")
    func quietCopy() {
        let log = regular(count: 17, every: 240, duration: 50)
        let output = GoNoGoEngine.evaluate(ukInput(log, now: 3840 + 840))
        #expect(output.reasons.contains(.noRecentTaps))
        let line = StateCopy.reasonLine(
            for: .noRecentTaps, metrics: output.metrics, thresholds: defaults, now: at(3840 + 840))
        #expect(line.hasPrefix("Nothing logged for 14 min. Are they still coming?"))
    }
}

@Suite("Engine properties")
struct EnginePropertyTests {
    /// Logs that look like labour: a base interval with jitter, sometimes a missed tap or a pause.
    private func patternLog(using rng: inout SeededGenerator) -> (contractions: [Contraction], now: Double) {
        let base = Double.random(in: 120...480, using: &rng)
        let count = Int.random(in: 4...30, using: &rng)
        var cursor = 0.0
        var contractions: [Contraction] = []
        for index in 0..<count {
            var gap = base * Double.random(in: 0.8...1.2, using: &rng)
            if Int.random(in: 0..<10, using: &rng) == 0 {
                gap *= Double(Int.random(in: 2...6, using: &rng))
            }
            if index > 0 { cursor += gap }
            let start = at(cursor)
            let open = index == count - 1 && Int.random(in: 0..<4, using: &rng) == 0
            let duration = Double.random(in: 30...90, using: &rng)
            contractions.append(Contraction(start: start, end: open ? nil : start.addingTimeInterval(duration)))
        }
        return (contractions, cursor + Double.random(in: 0...600, using: &rng))
    }

    /// A random profile and a second one that is the same or looser (calls sooner) in every field.
    private func profilePair(
        _ table: ThresholdTable,
        using rng: inout SeededGenerator
    ) -> (tight: ThresholdProfile, loose: ThresholdProfile) {
        var tight: [ThresholdField: Double] = [:]
        var loose: [ThresholdField: Double] = [:]
        for field in ThresholdField.allCases {
            let limit = table.limit(for: field)
            var values = [Double.random(in: limit.min...limit.max, using: &rng)]
            values.append(Double.random(in: limit.min...limit.max, using: &rng))
            if limit.allowsDisabled && Bool.random(using: &rng) { values[Int.random(in: 0...1, using: &rng)] = 0 }
            let clamped = values.map(limit.clamp)
            let sooner = field.higherCallsSooner ? clamped.max() : clamped.min()
            let later = field.higherCallsSooner ? clamped.min() : clamped.max()
            loose[field] = sooner
            tight[field] = later
        }
        // A switched-off duration or hold is the soonest of all.
        for field in [ThresholdField.adviceDurationSec, .patternWindowSec] where loose[field] != 0 {
            if tight[field] == 0 { swap(&tight[field], &loose[field]) }
        }
        return (table.profile(applying: tight), table.profile(applying: loose))
    }

    @Test("A looser profile never gives later advice than a tighter one, over 2,000 labour-like logs")
    func monotoneInThresholds() {
        var rng = SeededGenerator(seed: 0x5AFE_7001)
        for _ in 0..<2000 {
            let region: ContentRegion = Bool.random(using: &rng) ? .uk : .us
            let table = ThresholdTable.builtIn(for: region)
            let (log, now) = patternLog(using: &rng)
            let (tight, loose) = profilePair(table, using: &rng)
            let profile = LabourProfile(region: region, gestationalAgeDays: 280, travelMinutes: 20)
            let strict = GoNoGoEngine.evaluate(
                EngineInput(contractions: log, profile: profile, thresholds: tight, now: at(now)))
            let lenient = GoNoGoEngine.evaluate(
                EngineInput(contractions: log, profile: profile, thresholds: loose, now: at(now)))
            #expect(lenient.state >= strict.state, "\(region) tight \(tight) loose \(loose)")
        }
    }

    @Test("A labour that only speeds up never gets later advice, over 500 random speed-ups")
    func speedingUpNeverDrops() {
        var rng = SeededGenerator(seed: 0xFA57_E2)
        for _ in 0..<500 {
            let region: ContentRegion = Bool.random(using: &rng) ? .uk : .us
            var gap = Double.random(in: 360...900, using: &rng)
            var gaps: [Double] = []
            for _ in 0..<Int.random(in: 6...30, using: &rng) {
                gaps.append(gap)
                gap = max(90, gap * Double.random(in: 0.8...1.0, using: &rng))
            }
            let log = withGaps(gaps, duration: 65)
            let profile = LabourProfile(region: region, gestationalAgeDays: 280, travelMinutes: 20)
            let thresholds = ThresholdTable.builtIn(for: region).defaults
            var last = LabourState.early
            for contraction in log.dropFirst(3) {
                let now = contraction.start.addingTimeInterval(66)
                let upToNow = log.filter { $0.start <= contraction.start }
                let output = GoNoGoEngine.evaluate(
                    EngineInput(contractions: upToNow, profile: profile, thresholds: thresholds, now: now))
                #expect(output.state >= last, "\(region) gaps \(gaps)")
                last = output.state
            }
        }
    }

    @Test("A red flag never lowers the advice, and holds through hysteresis while it's on")
    func redFlagFloor() {
        var rng = SeededGenerator(seed: 0xF1A6)
        for _ in 0..<300 {
            let (log, now) = patternLog(using: &rng)
            let flag = RedFlag.allCases[Int.random(in: 0..<RedFlag.allCases.count, using: &rng)]
            let without = GoNoGoEngine.evaluate(ukInput(log, now: now))
            var output = GoNoGoEngine.evaluate(ukInput(log, flags: [flag], now: now))
            #expect(output.state >= without.state)
            #expect(output.state >= flag.state)
            for step in 1...6 {
                output = GoNoGoEngine.evaluate(
                    ukInput(log, flags: [flag], previous: output.snapshot, now: now + Double(step) * 600))
                #expect(output.state >= flag.state)
            }
        }
    }
}

@Suite("Missed taps")
struct MissedTapTests {
    private let thresholds = ThresholdTable.builtIn(for: .uk).defaults

    @Test("A gap of whole missed contractions in a regular run is filled in", arguments: [2, 3, 4])
    func filledIn(missed: Int) {
        var gaps = Array(repeating: 240.0, count: 12)
        gaps.insert(240 * Double(missed + 1), at: 8)
        let metrics = ContractionMetrics.compute(
            withGaps(gaps), thresholds: thresholds, now: at(gaps.reduce(0, +) + 60))
        #expect(metrics.missedTapGaps.map(\.estimatedMissed) == [missed])
        #expect(metrics.medianIntervalSec == 240)
        #expect(metrics.segmentStart == at(0))
    }

    @Test("An irregular run never gets gaps filled in")
    func irregularNotFilled() {
        let gaps: [Double] = [180, 540, 240, 720, 200, 600]
        let metrics = ContractionMetrics.compute(
            withGaps(gaps), thresholds: thresholds, now: at(gaps.reduce(0, +) + 60))
        #expect(metrics.missedTapGaps.isEmpty)
    }

    @Test("A gap over 5 typical intervals still starts a new run")
    func longGapSplits() {
        var gaps = Array(repeating: 240.0, count: 10)
        gaps.append(1500)
        gaps += Array(repeating: 240.0, count: 4)
        let metrics = ContractionMetrics.compute(
            withGaps(gaps), thresholds: thresholds, now: at(gaps.reduce(0, +) + 60))
        #expect(metrics.segmentStart == at(gaps.prefix(11).reduce(0, +)))
    }
}

@Suite("Tap policy")
struct TapPolicyTests {
    @Test("No open contraction: a tap starts one")
    func start() {
        #expect(TapPolicy.action(open: nil, now: at(0)) == .start)
    }

    @Test("An open contraction: a tap stops it")
    func stop() {
        let open = Contraction(start: at(0), end: nil)
        #expect(TapPolicy.action(open: open, now: at(45)) == .stop(open.id, at: at(45)))
    }

    @Test("A second tap within 1.5 seconds is a double-tap, not a 1-second contraction")
    func doubleTap() {
        let open = Contraction(start: at(0), end: nil)
        #expect(TapPolicy.action(open: open, now: at(0.8)) == .ignoreDoubleTap)
        #expect(TapPolicy.action(open: open, now: at(1.6)) == .stop(open.id, at: at(1.6)))
    }

    @Test("Another device's clock a little ahead: still a double-tap, and a stop is never before its start")
    func clockSkew() {
        let open = Contraction(start: at(10), end: nil)
        #expect(TapPolicy.action(open: open, now: at(9)) == .ignoreDoubleTap)
        #expect(TapPolicy.action(open: open, now: at(5)) == .stop(open.id, at: at(10)))
    }

    @Test("Past 5 minutes, ask whether it just ended or this is a new one, rather than guess")
    func forgotten() {
        let open = Contraction(start: at(0), end: nil)
        #expect(TapPolicy.action(open: open, now: at(330)) == .askIfEndedOrNew(open.id, elapsedSec: 330))
        #expect(TapPolicy.forgottenStopFixesSec(elapsed: 330) == [30, 60, 90, 330])

        // "It just ended": a real 5:30 contraction is recorded and means call now for the hour.
        let long = [Contraction(start: at(0), end: at(330))]
        let ended = GoNoGoEngine.evaluate(ukInput(long, now: 340))
        #expect(ended.reasons == [.contractionOverUrgentDuration])
        #expect(GoNoGoEngine.evaluate(ukInput(long, previous: ended.snapshot, now: 3000)).state == .callNow)

        // "This is a new one": the forgotten one is flagged, not counted as 10 minutes.
        let log = regular(count: 6, every: 240, duration: 50) + [Contraction(start: at(1440), end: nil)]
        let next = log + [Contraction(start: at(2040), end: nil)]
        let output = GoNoGoEngine.evaluate(ukInput(next, now: 2050))
        #expect(!output.metrics.hasClosedOverUrgent)
        #expect(output.metrics.needsEdit.count == 1)
    }
}

@Suite("Phone numbers")
struct PhoneNumberTests {
    private func dialled(_ text: String, _ region: ContentRegion = .uk) -> String? {
        try? PhoneNumber.parse(text, region: region).get().dialable
    }

    private func problem(_ text: String, _ region: ContentRegion = .uk) -> PhoneNumber.Problem? {
        if case .failure(let problem) = PhoneNumber.parse(text, region: region) { return problem }
        return nil
    }

    @Test(
        "Common ways of writing a UK number all dial the same",
        arguments: [
            "0113 392 6731", "+44 (0)113 392 6731", "+44 (0) 113 392 6731", "+44 113 392 6731", "+44 0113 392 6731",
            "0044 113 392 6731", "(0113) 392-6731", "0113.392.6731", "01133926731", "Tel: 0113 392 6731",
        ]
    )
    func ukFormats(text: String) {
        #expect(dialled(text) == "+441133926731", "\(text)")
    }

    @Test("Menu options and extensions become a note, never digits on the end")
    func afterConnecting() throws {
        let option = try PhoneNumber.parse("0113 392 6731 option 2", region: .uk).get()
        #expect(option.dialable == "+441133926731")
        #expect(option.afterConnecting == "Then press 2")
        #expect(try PhoneNumber.parse("0113 392 6731, opt. 2", region: .uk).get().afterConnecting == "Then press 2")
        #expect(
            try PhoneNumber.parse("0113 392 6731 ext 4", region: .uk).get().afterConnecting == "Ask for extension 4")
        #expect(try PhoneNumber.parse("0113 392 6731 x4", region: .uk).get().afterConnecting == "Ask for extension 4")
        let menu = try PhoneNumber.parse("0113 392 6731 *2#", region: .uk).get()
        #expect(menu.dialable == "+441133926731")
        #expect(menu.afterConnecting == "Then press *2#")
    }

    @Test("Two numbers, letters and bad lengths are caught at setup")
    func rejected() {
        #expect(problem("0113 392 6731 / 0113 206 5781") == .twoNumbers)
        #expect(problem("0113 392 6731 or 0113 206 5781") == .twoNumbers)
        #expect(problem("LGI 0113 392 6731") == .letters)
        #expect(problem("call the ward") == .letters)
        #expect(problem("0113 ½ 392 6731") == .letters)
        #expect(problem("0113 392 6731 option 2 or 0113 206 5781") == .twoNumbers)
        #expect(problem("0113 392 6731 ext 0113 206 5781") == .twoNumbers)
        #expect(problem("0113 392 673") == .tooShort)
        #expect(problem("0020 7946 0000") == .overseas)
        #expect(problem("+4 113 392 6731") == .overseas)
        #expect(problem("00113 392 6731") == .tooShort)
        #expect(problem("0113 392") == .tooShort)
        #expect(problem("0113 392 6731 0113 206 5781") == .tooLong)
        #expect(problem("   ") == .empty)
    }

    @Test("Short codes dial as they are")
    func shortCodes() {
        #expect(dialled("999") == "999")
        #expect(dialled("111") == "111")
        #expect(dialled("116 123") == "116123")
        #expect(dialled("911", .us) == "911")
        #expect(PhoneNumber.shortCode("116123")?.display == "116 123")
    }

    @Test("Display follows UK grouping")
    func display() throws {
        #expect(try PhoneNumber.parse("+44 (0)113 392 6731", region: .uk).get().display == "0113 392 6731")
        #expect(try PhoneNumber.parse("07700900123", region: .uk).get().display == "07700 900123")
        #expect(try PhoneNumber.parse("02079460000", region: .uk).get().display == "020 7946 0000")
        #expect(try PhoneNumber.parse("08001234567", region: .uk).get().display == "0800 123 4567")
        #expect(try PhoneNumber.parse("01234567890", region: .uk).get().display == "01234 567890")
    }

    @Test("US numbers")
    func us() throws {
        #expect(dialled("(415) 555-2671", .us) == "+14155552671")
        #expect(try PhoneNumber.parse("+1 415 555 2671", region: .us).get().display == "(415) 555-2671")
        #expect(problem("(155) 512-3456", .us) == .invalid)
        #expect(problem("0113 392 6731", .us) == .tooShort)
        #expect(problem("0213 392 6731", .us) == .invalid)
        #expect(problem("+1 415 555 267", .us) == .tooShort)
    }

    @Test("The tel: link uses the dialable form")
    func telURL() throws {
        let number = try PhoneNumber.parse("+44 (0)113 392 6731", region: .uk).get()
        #expect(number.telURL?.absoluteString == "tel:+441133926731")
    }
}

@Suite("Can't get through")
struct CallFallbackTests {
    @Test("UK: try again, the labour ward, NHS 111, then 999")
    func uk() throws {
        let unit = try PhoneNumber.parse("0113 392 6731", region: .uk).get()
        let ward = try PhoneNumber.parse("0113 243 3144", region: .uk).get()
        let steps = CallFallback.steps(region: .uk, unit: unit, labourWard: ward)
        #expect(
            steps.map(\.title) == [
                "Try again", "Call the labour ward", "Call NHS 111", "Call 999 if it's an emergency",
            ])
        #expect(steps.map { $0.number?.dialable } == ["+441133926731", "+441132433144", "111", "999"])
    }

    @Test("Nothing saved yet: still 111 and 999")
    func nothingSaved() {
        let steps = CallFallback.steps(region: .uk, unit: nil, labourWard: nil)
        #expect(steps.map { $0.number?.dialable } == ["111", "999"])
    }

    @Test("US: no 111, and 911")
    func us() {
        let steps = CallFallback.steps(region: .us, unit: nil, labourWard: nil)
        #expect(steps.map { $0.number?.dialable } == ["911"])
    }

    @Test("Fallback copy never says what stage she's in")
    func copy() {
        for region in ContentRegion.allCases {
            for step in CallFallback.steps(region: region, unit: nil, labourWard: PhoneNumber.shortCode("111")) {
                let text = (step.title + " " + step.detail).lowercased()
                for phrase in StateCopyTests.forbidden {
                    #expect(!text.contains(phrase))
                }
            }
        }
    }
}

@Suite("Alert delivery")
struct AlertDeliveryTests {
    private let session = UUID(uuidString: "6F9619FF-8B86-D011-B42D-00C04FC964FF") ?? UUID()

    @Test("The same alert gets the same identifier on every device, under the session's prefix")
    func identifiers() {
        let input = ukInput([Contraction(start: at(1000), end: nil)], now: 1030)
        let first = LabourAlertPlanner.scheduled(input: input, output: GoNoGoEngine.evaluate(input))
        let second = LabourAlertPlanner.scheduled(input: input, output: GoNoGoEngine.evaluate(input))
        #expect(first.map { $0.identifier(sessionID: session) } == second.map { $0.identifier(sessionID: session) })
        let prefix = LabourAlertPlanner.identifierPrefix(sessionID: session)
        #expect(prefix == "labour.6f9619ff-8b86-d011-b42d-00c04fc964ff.")
        #expect(first.allSatisfy { $0.identifier(sessionID: session).hasPrefix(prefix) })
    }

    @Test("At launch, only alerts from a labour that isn't running are cleared")
    func leftOverAlerts() {
        let running = LabourAlertPlanner.identifierPrefix(sessionID: session) + "rise.callTriage"
        let old = LabourAlertPlanner.identifierPrefix(sessionID: UUID()) + "rise.callTriage"
        #expect(!LabourAlertPlanner.isLeftOver(running, running: session))
        #expect(LabourAlertPlanner.isLeftOver(old, running: session))
        #expect(LabourAlertPlanner.isLeftOver(running, running: nil))
        #expect(!LabourAlertPlanner.isLeftOver("checklist.week36", running: nil))
    }

    @Test("Alerts that ask him to call are time sensitive, so Focus doesn't hold them back")
    func timeSensitive() {
        let output = GoNoGoEngine.evaluate(ukInput([], flags: [.watersBroken], now: 60))
        #expect(LabourAlertPlanner.immediate(previous: nil, output: output, region: .uk).first?.level == .timeSensitive)
        let calling = GoNoGoEngine.evaluate(ukInput(regular(count: 5, every: 240, duration: 50), now: 1000))
        let rise = LabourAlertPlanner.immediate(previous: nil, output: calling, region: .uk)
        #expect(rise.map(\.state) == [.callTriage])
        #expect(rise.first?.level == .timeSensitive)
        let quiet = PlannedAlert(kind: .rise, fireAt: at(0), state: .establishing, reason: nil, title: "", body: "")
        #expect(quiet.level == .active)
    }

    @Test("No still-going nudge in a 999 state")
    func noNudgeIn999() {
        let input = ukInput([Contraction(start: at(1000), end: nil)], flags: [.heavyBleeding], now: 1030)
        let alerts = LabourAlertPlanner.scheduled(input: input, output: GoNoGoEngine.evaluate(input))
        #expect(alerts.isEmpty)
    }

    @Test("The still-going nudge uses the region's words")
    func usNudge() {
        let open = Contraction(start: at(1000), end: nil)
        let input = EngineInput(
            contractions: [open],
            redFlags: [.watersBroken],
            profile: LabourProfile(region: .us, gestationalAgeDays: 280),
            thresholds: ThresholdTable.builtIn(for: .us).defaults,
            now: at(1030)
        )
        let alerts = LabourAlertPlanner.scheduled(input: input, output: GoNoGoEngine.evaluate(input))
        #expect(alerts.first?.kind == .stillGoing)
        #expect(alerts.first?.body.contains("your provider or labor and delivery unit") == true)
        #expect(alerts.first?.level == .timeSensitive)
    }
}

@Suite("Labour answers in the log")
struct LabourAnswerEventTests {
    @Test("\"They've stopped\" and the 37-week answer sync like any tap, and undo works")
    func reduce() {
        let session = UUID()
        let eased = TapEvent(sessionID: session, kind: .eased, at: at(4000), deviceID: "watch", lamport: 1)
        let answer = TapEvent(
            sessionID: session, kind: .termAnswer, at: at(10), deviceID: "phone", lamport: 2,
            payload: TapPayload(term: .notSure))
        let changed = TapEvent(
            sessionID: session, kind: .termAnswer, at: at(20), deviceID: "phone", lamport: 3,
            payload: TapPayload(term: .term))
        let log = EventLog.reduce([changed, eased, answer])
        #expect(log.easedAt == at(4000))
        #expect(log.termAnswer == .term)

        let undo = TapEvent(
            sessionID: session, kind: .undo, at: at(21), deviceID: "phone", lamport: 4, target: changed.id)
        #expect(EventLog.reduce([answer, changed, eased, undo]).termAnswer == .notSure)
    }
}

@Suite("Triage script: weeks and the call point")
struct TriageWeeksTests {
    private let thresholds = ThresholdTable.builtIn(for: .uk).defaults

    private func card(_ details: TriageDetails, contractions: [Contraction] = [], now: Double = 60) -> TriageScript {
        let output = GoNoGoEngine.evaluate(ukInput(contractions, now: now))
        return TriageScript.build(
            TriageScript.Inputs(
                details: details, output: output, log: ReducedLog(), now: at(now), calendar: utc
            ))
    }

    @Test("Unknown weeks are said, and flagged")
    func unknownWeeks() {
        let script = card(TriageDetails(motherName: "Sam"))
        #expect(script.opening == "Hi, I'm calling about Sam. Weeks not known, first baby.")
        #expect(script.lines.first { $0.label == "Pregnancy" }?.isUrgent == true)
    }

    @Test("A 37-or-more answer without a due date isn't flagged")
    func termAnswer() {
        let script = card(TriageDetails(motherName: "Sam", termAnswer: .term))
        #expect(script.lines.first { $0.label == "Pregnancy" }?.isUrgent == false)
    }

    @Test("The time the call point was reached is on the card")
    func callPoint() {
        let script = card(TriageDetails(), contractions: regular(count: 17, every: 240, duration: 50), now: 3900)
        #expect(script.lines.first { $0.label == "Call point" }?.value == "Reached at 09:05 (just now)")
    }

    @Test("Missed taps are mentioned so the unit isn't misled")
    func missedTaps() {
        var gaps = Array(repeating: 240.0, count: 14)
        gaps.insert(960, at: 8)
        let script = card(TriageDetails(), contractions: withGaps(gaps), now: gaps.reduce(0, +) + 60)
        let value = script.lines.first { $0.label == "Contractions" }?.value ?? ""
        #expect(value.hasSuffix("(possibly 3 not logged)"), "\(value)")
    }
}

@Suite("Threshold direction")
struct ThresholdDirectionTests {
    @Test("Changes that delay the advice are flagged, changes that bring it forward aren't")
    func delays() {
        let uk = ThresholdTable.builtIn(for: .uk)
        #expect(uk.delaysAdvice(.patternWindowSec, value: 3600))
        #expect(!uk.delaysAdvice(.patternWindowSec, value: 0))
        #expect(uk.delaysAdvice(.adviceIntervalSec, value: 240))
        #expect(!uk.delaysAdvice(.adviceIntervalSec, value: 360))
        #expect(uk.delaysAdvice(.adviceDurationSec, value: 45))
        #expect(uk.delaysAdvice(.regularityCV, value: 0.25))
        #expect(!uk.delaysAdvice(.urgentSingleDurationSec, value: 90))
    }

    @Test("Clamping a profile is the same as building it from overrides")
    func clamped() {
        let uk = ThresholdTable.builtIn(for: .uk)
        var wild = uk.defaults
        wild.adviceIntervalSec = 10
        wild.urgentCountIn10Min = 99
        wild.patternWindowSec = -3
        let clamped = uk.clamped(wild)
        #expect(clamped.adviceIntervalSec == 180)
        #expect(clamped.urgentCountIn10Min == 6)
        #expect(clamped.patternWindowSec == 0)
        #expect(uk.clamped(uk.defaults) == uk.defaults)
    }
}
