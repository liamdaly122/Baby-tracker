import Foundation
import Testing

@testable import MissionCore

@Suite("Engine review fixes")
struct ReviewFixTests {
    private let defaults = ThresholdTable.builtIn(for: .uk).defaults

    @Test("A regular pattern right at 5 minutes meets the rule through the median, not the three-in-four count")
    func medianBranch() {
        // The last 20 minutes hold gaps of 302, 290, 305 and 296 s: only half are 5 minutes or
        // under, but the median is 299 and they're regular.
        let gaps: [Double] = [300, 300, 300, 302, 290, 305, 296]
        let output = GoNoGoEngine.evaluate(ukInput(withGaps(gaps), now: gaps.reduce(0, +) + 5))
        #expect(output.metrics.recentIntervalsSec == [302, 290, 305, 296])
        let within = output.metrics.recentIntervalsSec.filter { $0 <= 300 }.count
        #expect(Double(within) < 0.75 * Double(output.metrics.recentIntervalsSec.count))
        #expect(output.state == .callTriage)
    }

    @Test("Three in four is a count: 3 of 4 gaps under 5 min meets it, 2 of 3 doesn't")
    func threeInFourCounted() {
        let three = GoNoGoEngine.evaluate(ukInput(withGaps([240, 240, 240, 420]), now: 1200))
        #expect(three.state == .callTriage)
        let twoOfThree = GoNoGoEngine.evaluate(ukInput(withGaps([240, 240, 600]), now: 1140))
        #expect(twoOfThree.state < .callTriage)
    }

    @Test("A closed contraction of exactly 2 minutes isn't over 2 minutes; 121 seconds is")
    func urgentBoundary() {
        let exact = GoNoGoEngine.evaluate(ukInput([Contraction(start: at(0), end: at(120))], now: 200))
        #expect(exact.state < .callNow)
        let over = GoNoGoEngine.evaluate(ukInput([Contraction(start: at(0), end: at(121))], now: 200))
        #expect(over.reasons == [.contractionOverUrgentDuration])
    }

    @Test("Missed-tap tolerance: 2.2× counts, 2.25× and an ordinary 1.75× don't")
    func missedTapTolerance() {
        func gaps(for ratio: Double) -> [MissedTapGap] {
            var gaps = Array(repeating: 240.0, count: 10)
            gaps.insert(240 * ratio, at: 6)
            return ContractionMetrics.compute(
                withGaps(gaps), thresholds: defaults, now: at(gaps.reduce(0, +) + 60)
            ).missedTapGaps
        }
        #expect(gaps(for: 2.2).map(\.estimatedMissed) == [1])
        #expect(gaps(for: 2.25).isEmpty)
        #expect(gaps(for: 1.75).isEmpty)
    }

    @Test("A slowdown is never reported as missed taps")
    func slowdownNotMissed() {
        let metrics = ContractionMetrics.compute(
            withGaps([240, 240, 240, 240, 480, 480, 480]), thresholds: defaults, now: at(2700))
        #expect(metrics.missedTapGaps.isEmpty)
    }

    @Test("A new urgent reason alerts even when call now is already showing for another reason")
    func newUrgentReasonAlerts() {
        let profile = LabourProfile(region: .uk, termAnswer: .notSure)
        let unknown = GoNoGoEngine.evaluate(ukInput([], profile: profile, now: 0))
        let six = regular(count: 6, every: 90, duration: 40, first: 600)
        let later = GoNoGoEngine.evaluate(ukInput(six, profile: profile, previous: unknown.snapshot, now: 1060))
        #expect(later.state == .callNow)
        let alerts = LabourAlertPlanner.immediate(previous: unknown.snapshot, output: later, region: .uk)
        #expect(alerts.map(\.kind) == [.newUrgentReason])
        #expect(alerts.first?.reason == .tooManyInTenMinutes)
        #expect(alerts.first?.level == .timeSensitive)
        #expect(later.contractionAdvice.reasons == [.tooManyInTenMinutes])
    }

    @Test("A rise has the same identifier whether posted at once or scheduled, on any device")
    func riseIdentifiers() {
        let session = UUID()
        let scheduled = PlannedAlert(
            kind: .scheduledRise, fireAt: at(59.4), state: .callNow, reason: nil, title: "", body: "")
        let posted = PlannedAlert(kind: .rise, fireAt: at(60.6), state: .callNow, reason: nil, title: "", body: "")
        #expect(scheduled.identifier(sessionID: session) == posted.identifier(sessionID: session))
    }

    @Test("The planner finds the first rise a 5-second walk would find, over 200 random logs")
    func plannerMatchesWalk() {
        var rng = SeededGenerator(seed: 0x0F1A_4E57)
        var checked = 0
        for _ in 0..<200 {
            let region: ContentRegion = Bool.random(using: &rng) ? .uk : .us
            var gaps: [Double] = []
            for _ in 0..<Int.random(in: 3...12, using: &rng) {
                gaps.append(Double.random(in: 150...560, using: &rng))
            }
            let log = withGaps(gaps, duration: Double.random(in: 40...75, using: &rng))
            let profile = LabourProfile(region: region, gestationalAgeDays: 280, travelMinutes: 20)
            let thresholds = ThresholdTable.builtIn(for: region).defaults
            let input = EngineInput(
                contractions: log, profile: profile, thresholds: thresholds, now: at(gaps.reduce(0, +) + 70))
            let output = GoNoGoEngine.evaluate(input)
            let planned = LabourAlertPlanner.scheduled(input: input, output: output).first { $0.kind == .scheduledRise }

            var walk = input
            var current = output
            var firstRise: Date?
            for step in 1...480 {
                walk.now = input.now.addingTimeInterval(Double(step) * 5)
                walk.previous = current.snapshot
                let next = GoNoGoEngine.evaluate(walk)
                if next.state >= .callTriage && next.state > current.state {
                    firstRise = walk.now
                    break
                }
                current = next
            }
            if let firstRise {
                checked += 1
                #expect(planned != nil, "\(region) \(gaps)")
                if let planned {
                    #expect(
                        planned.fireAt <= firstRise, "\(region) \(gaps): planned \(planned.fireAt) walk \(firstRise)")
                }
            }
        }
        #expect(checked > 0)
    }

    @Test("The sustained time never shrinks without a tap")
    func sustainedNeverShrinks() {
        let gaps: [Double] = [538, 487, 540, 442, 375, 307, 250, 259]
        let log = withGaps(gaps, duration: 65)
        let us = ThresholdTable.builtIn(for: .us).defaults
        let profile = LabourProfile(region: .us, gestationalAgeDays: 280)
        var last = 0.0
        for now in stride(from: 3300.0, through: 4300, by: 10) {
            let output = GoNoGoEngine.evaluate(
                EngineInput(contractions: log, profile: profile, thresholds: us, now: at(now)))
            #expect(output.metrics.patternSustainedSec >= last, "at \(now)")
            last = output.metrics.patternSustainedSec
        }
    }

    @Test("Reopening the app an hour after the last tap starts the dwell; it doesn't hold for ever")
    func reopenAfterAnHour() {
        let log = regular(count: 10, every: 240, duration: 50)
        let calling = GoNoGoEngine.evaluate(ukInput(log, now: 2200))
        #expect(calling.state == .callTriage)
        let reopened = GoNoGoEngine.evaluate(ukInput(log, previous: calling.snapshot, now: 2160 + 3661))
        #expect(reopened.isEasing)
        let later = GoNoGoEngine.evaluate(ukInput(log, previous: reopened.snapshot, now: 2160 + 3661 + 900))
        #expect(later.state == .early)
    }

    @Test("A forgotten stop fixed straight away drops after the dwell, not never")
    func correctedForgottenStop() {
        let open = [Contraction(start: at(0), end: nil)]
        let urgent = GoNoGoEngine.evaluate(ukInput(open, now: 150))
        #expect(urgent.state == .callNow)
        let fixed = [Contraction(start: at(0), end: at(60))]
        var output = GoNoGoEngine.evaluate(ukInput(fixed, previous: urgent.snapshot, now: 160))
        #expect(output.isEasing)
        output = GoNoGoEngine.evaluate(ukInput(fixed, previous: output.snapshot, now: 160 + 900))
        #expect(output.state < .callNow)
        #expect(output.snapshot.callRuleMetAt == nil)
    }

    @Test("Durations never round across a duration rule")
    func durationRounding() {
        #expect(StateCopy.guardedRound(59.6, step: 1, threshold: 60, metAtOrAbove: true) == 59)
        #expect(StateCopy.guardedRound(60, step: 1, threshold: 60, metAtOrAbove: true) == 60)
        #expect(StateCopy.guardedRound(120.4, step: 1, threshold: 120) == 121)
    }

    @Test("The triage card flags a contraction over 2 minutes and never rounds it down to 2 minutes")
    func longestLine() {
        let output = GoNoGoEngine.evaluate(ukInput([Contraction(start: at(0), end: at(120.4))], now: 200))
        let script = TriageScript.build(
            TriageScript.Inputs(
                details: TriageDetails(), output: output, log: ReducedLog(), now: at(200), calendar: .current))
        let line = script.lines.first { $0.label == "Longest" }
        #expect(line?.value == "2 min 1 sec in the last hour")
        #expect(line?.isUrgent == true)
    }

    @Test(
        "Pasted forms parse",
        arguments: [
            "\u{202D}+44 113 392 6731\u{202C}", "\u{200E}0113 392 6731", "\u{FEFF}0113 392 6731", "0113‐392‐6731",
            "0113–392–6731", "0113−392−6731", "Telephone: 0113 392 6731", "tel:+441133926731", "0113 392 6731.",
            "0113\u{00A0}392\u{00A0}6731", "０１１３ ３９２ ６７３１",
        ]
    )
    func pastedForms(text: String) {
        #expect((try? PhoneNumber.parse(text, region: .uk).get().dialable) == "+441133926731", "\(text)")
    }

    @Test("Bracketed and dashed options become a note")
    func bracketedOptions() throws {
        #expect(try PhoneNumber.parse("0113 392 6731 (option 2)", region: .uk).get().afterConnecting == "Then press 2")
        #expect(
            try PhoneNumber.parse("0113 392 6731 (option 2 for triage)", region: .uk).get().afterConnecting
                == "Then press 2 for triage")
        #expect(try PhoneNumber.parse("0113 392 6731 – option 2", region: .uk).get().afterConnecting == "Then press 2")
    }

    @Test("Display groups 6-digit area codes, 9-digit 0800 and 05x numbers properly")
    func displayGroups() throws {
        #expect(try PhoneNumber.parse("016977 1234", region: .uk).get().display == "016977 1234")
        #expect(try PhoneNumber.parse("015394 12345", region: .uk).get().display == "015394 12345")
        #expect(try PhoneNumber.parse("0800 123 456", region: .uk).get().display == "0800 123 456")
        #expect(try PhoneNumber.parse("056 1234 5678", region: .uk).get().display == "056 1234 5678")
    }

    @Test("A saved number that has been tampered with doesn't decode, and never makes a tel: link")
    func decodeChecks() throws {
        let json = #"{"raw":"x","dialable":"+44113;rm","display":"x"}"#
        #expect(throws: (any Error).self) { try JSONDecoder().decode(PhoneNumber.self, from: Data(json.utf8)) }
        let good = try PhoneNumber.parse("0113 392 6731", region: .uk).get()
        let round = try JSONDecoder().decode(PhoneNumber.self, from: JSONEncoder().encode(good))
        #expect(round == good)
    }

    @Test("Events of a kind this build doesn't know are kept and ignored, not fatal to the batch")
    func forwardCompatibleEvents() throws {
        let session = UUID()
        let start = TapEvent(sessionID: session, kind: .start, at: at(0), deviceID: "watch", lamport: 1)
        var json = String(bytes: try JSONEncoder().encode([start]), encoding: .utf8) ?? ""
        let newer =
            #"{"id":"\#(UUID().uuidString)","sessionID":"\#(session.uuidString)","kind":"somethingNew","#
            + #""at":1,"deviceID":"watch","lamport":2}"#
        json = json.replacingOccurrences(of: "]", with: "," + newer + "]")
        let events = try JSONDecoder().decode([TapEvent].self, from: Data(json.utf8))
        #expect(events.map(\.kind) == [.start, .unknown])
        #expect(EventLog.reduce(events).contractions.count == 1)
    }

    @Test("The input built from a log carries \"they've stopped\" and the 37-week answer")
    func inputFromLog() {
        let log = ReducedLog(contractions: [], easedAt: at(10), termAnswer: .term)
        let input = EngineInput(
            log: log, profile: LabourProfile(region: .uk), thresholds: defaults, previous: nil, now: at(20))
        #expect(input.easedAt == at(10))
        #expect(input.profile.termAnswer == .term)
        #expect(TriageDetails().applying(log: log).termAnswer == .term)
    }
}
