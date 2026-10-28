import Foundation
import Testing

@testable import MissionCore

private let uk = ThresholdTable.builtIn(for: .uk).defaults
private let usDefaults = ThresholdTable.builtIn(for: .us).defaults

private func session(_ profile: LabourProfile = LabourProfile(region: .uk, gestationalAgeDays: 280)) -> SessionStart {
    SessionStart(
        sessionID: UUID(uuidString: "00000000-0000-0000-0000-0000000000B6") ?? UUID(),
        startedAt: at(0),
        startedBy: "phone",
        profile: profile,
        thresholds: ThresholdTable.builtIn(for: profile.region).defaults
    )
}

private func script(_ core: inout LabourSessionCore, now: Double) -> [String: String] {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    let output = core.output(at: at(now))
    let built = TriageScript.build(
        TriageScript.Inputs(details: TriageDetails(), output: output, log: core.log, now: at(now), calendar: calendar))
    return Dictionary(built.lines.map { ($0.label, $0.value) }, uniquingKeysWith: { first, _ in first })
}

@Suite("When her waters went")
struct WatersTimeTests {
    @Test("A second \"on\" from the other device never moves the time he gave, in either merge order")
    func secondOnKeepsTheTime() {
        let start = session()
        var phone = LabourSessionCore(start: start, deviceID: "phone")
        phone.setRedFlag(.watersBroken, isOn: true, at: at(3000), happenedAt: at(600))
        var watch = LabourSessionCore(start: start, deviceID: "watch")
        tapContractions(&watch, count: 1, every: 240, first: 2000)
        watch.setRedFlag(.watersBroken, isOn: true, at: at(2960))
        var later = LabourSessionCore(start: start, deviceID: "watch")
        tapContractions(&later, count: 1, every: 240, first: 2000)
        later.setRedFlag(.watersBroken, isOn: true, at: at(3060))
        for other in [watch, later] {
            var phoneCopy = phone
            var otherCopy = other
            phoneCopy.merge(other.events)
            otherCopy.merge(phone.events)
            #expect(phoneCopy.watersBrokeAt == at(600))
            #expect(otherCopy.watersBrokeAt == at(600))
        }
    }

    @Test("Saying when, after the tap, can't turn the waters back on if they were turned off meanwhile")
    func timeOnItsOwnNeverTurnsItOn() {
        let start = session()
        var phone = LabourSessionCore(start: start, deviceID: "phone")
        phone.setRedFlag(.watersBroken, isOn: true, at: at(3000))
        var watch = LabourSessionCore(start: start, deviceID: "watch")
        watch.merge(phone.events)
        watch.setRedFlag(.watersBroken, isOn: false, at: at(3005))
        phone.setFlagTime(.watersBroken, happenedAt: at(1200), at: at(3010))
        phone.merge(watch.events)
        watch.merge(phone.events)
        #expect(phone.log.activeRedFlags.isEmpty)
        #expect(watch.log.activeRedFlags.isEmpty)
        // And on one device: no answer once it's off.
        #expect(phone.setFlagTime(.watersBroken, happenedAt: at(1200), at: at(3020)) == nil)
    }

    @Test("Off and on again is a new tap with a new time; the earlier one stays in the call script")
    func offThenOn() {
        var core = LabourSessionCore(start: session(), deviceID: "phone")
        core.setRedFlag(.watersBroken, isOn: true, at: at(3600), happenedAt: at(0))
        core.setRedFlag(.watersBroken, isOn: false, at: at(14400))
        core.setRedFlag(.watersBroken, isOn: true, at: at(14460))
        #expect(core.watersBrokeAt == at(14460))
        #expect(
            core.log.redFlags[.watersBroken]?.earlier == [FlagEpisode(onAt: at(0), offAt: at(14400), timeGiven: true)])
        let lines = script(&core, now: 14520)
        #expect(lines["Turned off"] == "Waters broke (on 08:00, off 12:00)")
        #expect(lines["Waters"] == "Broke by 12:01 (1 min ago), time not confirmed, clear")
    }

    @Test("\"Just now\" confirms the tap time; a later answer is never after the tap")
    func justNowConfirms() {
        var core = LabourSessionCore(start: session(), deviceID: "phone")
        core.setRedFlag(.watersBroken, isOn: true, at: at(3000))
        #expect(script(&core, now: 3005)["Waters"]?.hasSuffix("time not confirmed, clear") == true)
        core.setFlagTime(.watersBroken, happenedAt: at(3010), at: at(3010))
        #expect(core.watersBrokeAt == at(3000))
        #expect(script(&core, now: 3060)["Waters"] == "Broke at 08:50 (1 min ago), clear")
    }

    @Test("Two \"on\" taps for the same waters, in either merge order: the earlier tap is the time")
    func earliestTapWins() {
        let start = session()
        var phone = LabourSessionCore(start: start, deviceID: "phone")
        tapContractions(&phone, count: 4, every: 240, first: 0)
        phone.setRedFlag(.watersBroken, isOn: true, at: at(1500))
        phone.setFlagTime(.watersBroken, happenedAt: at(8700), at: at(8700))
        var watch = LabourSessionCore(start: start, deviceID: "watch")
        watch.setRedFlag(.watersBroken, isOn: true, at: at(5100))
        var merged = phone
        merged.merge(watch.events)
        watch.merge(phone.events)
        #expect(merged.watersBrokeAt == at(1500))
        #expect(watch.watersBrokeAt == at(1500))
        #expect(merged.log.redFlags[.watersBroken]?.timeGiven == true)
    }

    @Test("A duplicate \"on\" from the other device after a call doesn't make the waters news")
    func duplicateOnAfterCall() {
        let start = session()
        var phone = LabourSessionCore(start: start, deviceID: "phone")
        tapContractions(&phone, count: 4, every: 240, first: 0)
        phone.setRedFlag(.watersBroken, isOn: true, at: at(1500))
        phone.setFlagTime(.watersBroken, happenedAt: at(1200), at: at(1510))
        let call = phone.logCall(.stayHome, at: at(1600))
        var watch = LabourSessionCore(start: start, deviceID: "watch")
        watch.setRedFlag(.watersBroken, isOn: true, at: at(1650))
        phone.merge(watch.events)
        watch.merge(phone.events + [call])
        #expect(phone.output(at: at(1700)).call?.acknowledgedAt == at(1600))
        #expect(watch.output(at: at(1700)).call?.acknowledgedAt == at(1600))
    }

    @Test("An \"on\" from before the waters were turned off never moves a later episode back")
    func staleOnKeepsTheNewEpisode() {
        var core = LabourSessionCore(start: session(), deviceID: "phone")
        core.setRedFlag(.watersBroken, isOn: true, at: at(100))
        core.setRedFlag(.watersBroken, isOn: false, at: at(200))
        core.setRedFlag(.watersBroken, isOn: true, at: at(300))
        let stale = TapEvent(
            sessionID: core.sessionID, kind: .redFlag, at: at(150), deviceID: "watch", lamport: 99,
            payload: TapPayload(flag: .watersBroken, isOn: true))
        core.merge([stale])
        #expect(core.watersBrokeAt == at(300))
        #expect(core.log.redFlags[.watersBroken]?.earlier.count == 1)
    }

    @Test("Over 24 hours after her waters went, a stay-at-home call says to call if there's no plan yet")
    func watersOver24Hours() {
        var core = LabourSessionCore(start: session(), deviceID: "phone")
        core.setRedFlag(.watersBroken, isOn: true, at: at(0), happenedAt: at(-82800))
        core.logCall(.stayHome, at: at(60))
        let before = core.output(at: at(3000))
        #expect(!StateCopy.detail(for: before, region: .uk, thresholds: uk).contains("24 hours"))
        let after = core.output(at: at(3700))
        #expect(after.call?.acknowledgedAt == at(60))
        #expect(StateCopy.detail(for: after, region: .uk, thresholds: uk).contains("over 24 hours"))
    }
}

@Suite("Red flags together, GBS and gestation")
struct ClinicalRuleTests {
    @Test("Bleeding with constant or severe pain is 999 (NHS), and adding the pain alerts at 999")
    func bleedingWithPain() {
        var core = LabourSessionCore(start: session(), deviceID: "phone")
        core.setRedFlag(.bleeding, isOn: true, at: at(0))
        let before = core.output(at: at(50))
        #expect(before.state == .callNow)
        core.setRedFlag(.severePain, isOn: true, at: at(100))
        let output = core.output(at: at(100))
        #expect(output.state == .call999)
        #expect(output.reasons == [.bleedingWithSeverePain])
        let alerts = LabourAlertPlanner.immediate(previous: before.snapshot, output: output, region: .uk)
        #expect(alerts.map(\.kind) == [.rise])
        #expect(alerts.first?.state == .call999)
    }

    @Test("GBS positive: time to call once contractions start; call now once her waters go")
    func gbs() {
        let profile = LabourProfile(region: .uk, gestationalAgeDays: 280, gbsPositive: true)
        var core = LabourSessionCore(start: session(profile), deviceID: "phone")
        _ = core.tap(at: at(10))
        #expect(core.output(at: at(5)).state == .early)
        let started = core.output(at: at(20))
        #expect(started.state == .callTriage)
        #expect(started.reasons.contains(.gbsInLabour))
        core.setRedFlag(.watersBroken, isOn: true, at: at(30))
        let waters = core.output(at: at(40))
        #expect(waters.state == .callNow)
        #expect(waters.reasons == [.watersBroken, .gbsWithWaters])
    }

    @Test(
        "Under 37 weeks or weeks not known: no induction wording and no 24-hour induction reminder",
        arguments: [238, nil] as [Int?])
    func gbsNotTerm(days: Int?) {
        let profile = LabourProfile(region: .uk, gestationalAgeDays: days, gbsPositive: true)
        var core = LabourSessionCore(start: session(profile), deviceID: "phone")
        core.setRedFlag(.watersBroken, isOn: true, at: at(60))
        let output = core.output(at: at(60))
        #expect(output.reasons.contains(.gbsWithWatersPreterm))
        #expect(!output.reasons.contains(.gbsWithWaters))
        let lines = output.reasons.map { StateCopy.reasonLine(for: $0, metrics: output.metrics, thresholds: uk) }
        #expect(!lines.joined().lowercased().contains("induction"))
        let plan = LabourAlertPlanner.scheduled(
            input: core.engineInput(at: at(60), previous: output.snapshot), output: output,
            watersBrokeAt: core.watersBrokeAt)
        #expect(!plan.contains { $0.kind == .watersDay })
    }
}

@Suite("How long the current rate has held")
struct RateHeldTests {
    private func metrics(_ gaps: [Double], thresholds: ThresholdProfile = uk, after: Double = 60)
        -> ContractionMetrics
    {
        let contractions = withGaps(gaps)
        let last = contractions.last?.start ?? at(0)
        return ContractionMetrics.compute(
            contractions, thresholds: thresholds, now: last.addingTimeInterval(after))
    }

    @Test("A stretch every 6:30 or 6:40 isn't time at the call rate")
    func slowerStretchJustUnderTheMargin() {
        let fourAfter = metrics(Array(repeating: 390, count: 9) + Array(repeating: 240, count: 5))
        #expect(fourAfter.earlierMedianIntervalSec == 390)
        #expect((fourAfter.rateHeldSec ?? 0) < 25 * 60)
        let twoAfter = metrics(Array(repeating: 400, count: 9) + Array(repeating: 120, count: 10))
        #expect(twoAfter.earlierMedianIntervalSec == 400)
        #expect((twoAfter.rateHeldSec ?? 0) < 25 * 60)
    }

    @Test("With looser settings a midwife can set, 2 hours every 10 min still isn't time at every 4")
    func looserSettings() {
        let loose = ThresholdTable.builtIn(for: .uk).profile(applying: [.adviceIntervalSec: 420, .regularityCV: 0.5])
        let shape = metrics(Array(repeating: 600, count: 11) + Array(repeating: 240, count: 8), thresholds: loose)
        #expect(shape.earlierMedianIntervalSec == 600)
        #expect((shape.rateHeldSec ?? 0) < 40 * 60)
    }

    @Test("An uneven but steady run is all at this rate")
    func jitteryRun() {
        let shape = metrics([250, 300, 240, 310, 260, 290, 245, 305, 270, 280, 300, 255])
        #expect(shape.earlierMedianIntervalSec == nil)
        #expect(shape.rateHeldSec == shape.patternSustainedSec)
    }

    @Test("One late tap, in the middle or the latest, doesn't halve the time or invent a slower stretch")
    func oneLateTap() {
        let latest = metrics(Array(repeating: 240, count: 13) + [420], after: 120)
        #expect(latest.earlierMedianIntervalSec == nil)
        #expect(latest.rateHeldSec == latest.patternSustainedSec)
        let middle = metrics(Array(repeating: 240, count: 8) + [420] + Array(repeating: 240, count: 8))
        #expect(middle.earlierMedianIntervalSec == nil)
        #expect(middle.rateHeldSec == middle.patternSustainedSec)
    }

    @Test("A missed tap inside the fast stretch doesn't fold it into the slow one")
    func missedTapInTheFastStretch() {
        let shape = metrics(Array(repeating: 600, count: 12) + [240, 240, 240, 480, 240, 240, 240])
        #expect(shape.earlierMedianIntervalSec == 600)
        #expect(abs((shape.rateHeldSec ?? 0) - 33 * 60) <= 60)
    }

    @Test(
        "A stretch before of one gap, or one that wasn't slower, isn't reported",
        arguments: [
            [240.0, 240, 600], [600.0, 240, 240],
        ])
    func noEarlierStretch(gaps: [Double]) {
        #expect(metrics(gaps).earlierMedianIntervalSec == nil)
    }

    @Test("In silence the time stops growing one current gap after the last start, not one slow gap")
    func stopsGrowing() {
        let gaps = Array(repeating: 600.0, count: 8) + Array(repeating: 240, count: 7)
        let four = metrics(gaps, after: 240)
        let ten = metrics(gaps, after: 600)
        #expect(four.earlierMedianIntervalSec == 600)
        #expect(four.rateHeldSec == ten.rateHeldSec)
    }

    @Test("A stall of slow gaps right before the current rate is \"before\", even after a faster start")
    func stallBeforeTheRate() {
        let four: [Double] = Array(repeating: 240, count: 10)
        let fast: [Double] = Array(repeating: 240, count: 5)
        let cases: [(gaps: [Double], span: Double)] = [
            (four + [600, 600, 600] + fast, 1800),
            (four + [600, 600] + fast, 1200),
            ([600, 600] + fast, 1200),
        ]
        for (gaps, span) in cases {
            let shape = metrics(gaps)
            #expect(shape.earlierMedianIntervalSec == 600, "\(gaps)")
            #expect(shape.earlierSpanSec == span, "\(gaps)")
            #expect(abs((shape.rateHeldSec ?? 0) - 21 * 60) <= 60, "\(gaps)")
        }
    }

    @Test("Coupled contractions read the same whichever beat was tapped last, with no \"before\"")
    func coupled() {
        let long = metrics(cycle([480, 100], times: 10))
        let short = metrics(cycle([100, 480], times: 10))
        #expect(long.earlierMedianIntervalSec == nil)
        #expect(short.earlierMedianIntervalSec == nil)
        #expect(long.rateHeldSec == long.patternSustainedSec)
        #expect(short.rateHeldSec == short.patternSustainedSec)
    }

    @Test("In silence the time at this rate never jumps or shrinks")
    func steadyInSilence() {
        let loose = ThresholdTable.builtIn(for: .uk).profile(applying: [.adviceIntervalSec: 420, .regularityCV: 0.5])
        let speedUp: [Double] = [704, 524, 452, 338, 215, 110]
        let coupledRun: [Double] = cycle([108, 367], times: 10) + [406, 99]
        for gaps in [speedUp, coupledRun] {
            let held: [Double] = stride(from: 30.0, through: 600, by: 30).map {
                metrics(gaps, thresholds: loose, after: $0).rateHeldSec ?? 0
            }
            #expect(zip(held, held.dropFirst()).allSatisfy { $1 >= $0 - 1e-6 && $1 - $0 <= 30 + 1e-6 }, "\(held)")
        }
    }

    @Test("A steady run near a tight call interval isn't split into a stretch \"before\" at the same rate")
    func tightSteady() {
        let tight = ThresholdTable.builtIn(for: .uk).profile(applying: [.adviceIntervalSec: 180, .regularityCV: 0.25])
        let gaps: [Double] = [
            141, 208, 175, 190, 160, 200, 183, 170, 195, 165, 185, 178, 205, 150, 180, 188, 172, 196,
            168, 184, 176, 190, 182, 174,
        ]
        #expect(metrics(gaps, thresholds: tight).earlierMedianIntervalSec == nil)
    }

    @Test("While a hold is counting down, the line gives the time at this rate and, with \"to go\", the hold")
    func soFarAndToGoAddUp() {
        let contractions = withGaps([600, 600, 600, 240, 240, 240, 240, 240], duration: 65)
        let output = GoNoGoEngine.evaluate(
            EngineInput(
                contractions: contractions, profile: LabourProfile(region: .us, gestationalAgeDays: 280),
                thresholds: usDefaults, now: (contractions.last?.start ?? at(0)).addingTimeInterval(60)))
        #expect(output.reasons.contains(.patternNotYetSustained))
        let line = StateCopy.reasonLine(
            for: .patternNotYetSustained, metrics: output.metrics, thresholds: output.thresholds)
        let detail = StateCopy.detail(for: output, region: .us, thresholds: output.thresholds)
        // Only the last stretch was every 4 min: the line says so, and gives the whole run as well.
        #expect(line.contains("every 4 min"))
        #expect(line.contains("for the last 21 min"), "\(line)")
        let all = Int(line.components(separatedBy: "(").last?.components(separatedBy: " min in all").first ?? "")
        let toGo = Int(detail.components(separatedBy: "About ").last?.components(separatedBy: " min").first ?? "")
        #expect((all ?? 0) + (toGo ?? 0) >= 60)
        #expect((all ?? 0) + (toGo ?? 0) <= 61)
    }
}

@Suite("A start echoed by the other device")
struct StartEchoTests {
    @Test("An echo from a build without the newer fields can't clear GBS or a planned caesarean")
    func olderEchoKeepsTheProfile() throws {
        let profile = LabourProfile(region: .uk, gestationalAgeDays: 280, gbsPositive: true, plannedCaesarean: true)
        let start = session(profile)
        var core = LabourSessionCore(start: start, deviceID: "phone")
        var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(start)) as? [String: Any])
        var stripped = try #require(json["profile"] as? [String: Any])
        stripped["gbsPositive"] = nil
        stripped["plannedCaesarean"] = nil
        json["profile"] = stripped
        var echoed = try JSONDecoder().decode(SessionStart.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(!echoed.profile.gbsPositive)
        core.update(echoed)
        #expect(core.start.profile.gbsPositive)
        #expect(core.start.profile.plannedCaesarean)
        // New thresholds still come through, as a newer revision.
        echoed.thresholds = ThresholdTable.builtIn(for: .uk).profile(applying: [.adviceIntervalSec: 240])
        echoed.revision = 1
        core.update(echoed)
        #expect(core.start.thresholds.adviceIntervalSec == 240)
        #expect(core.start.profile.gbsPositive)
    }
}

@Suite("Thresholds from the midwife")
struct ThresholdRevisionTests {
    @Test("An older copy from the other device never undoes thresholds the phone applied, in either order")
    func olderCopyLoses() {
        let launched = session()
        var phone = LabourSessionCore(start: launched, deviceID: "phone")
        var watch = LabourSessionCore(start: launched, deviceID: "watch")
        var applied = launched
        applied.thresholds = ThresholdTable.builtIn(for: .uk).profile(applying: [.adviceIntervalSec: 420])
        applied.revision = 1
        phone.update(applied)
        // Crossing catch-ups: each device gets the other's copy.
        phone.update(watch.start)
        watch.update(phone.start)
        #expect(phone.start.thresholds.adviceIntervalSec == 420)
        #expect(watch.start.thresholds.adviceIntervalSec == 420)
        // The watch's launch-time context replayed to a relaunched phone.
        phone.update(launched)
        #expect(phone.start.thresholds.adviceIntervalSec == 420)
    }

    @Test("A start from a build without a revision reads as revision 0")
    func missingRevision() throws {
        let start = session()
        var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(start)) as? [String: Any])
        json["revision"] = nil
        let decoded = try JSONDecoder().decode(SessionStart.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.revision == 0)
        #expect(decoded == start)
    }
}

/// `pattern` over and over, `times` times.
private func cycle(_ pattern: [Double], times: Int) -> [Double] {
    (0..<times).flatMap { _ in pattern }
}

@Suite("Copy and call script, second review")
struct CopySecondReviewTests {
    @Test("Once a long contraction has left the hour, \"call back\" and the script still say what's new")
    func callBackNamesWhatsNew() {
        var core = LabourSessionCore(start: session(), deviceID: "phone")
        tapContractions(&core, count: 5, every: 240, first: 0)
        core.logCall(.stayHome, at: at(1100))
        tapContractions(&core, count: 1, every: 240, duration: 150, first: 1200)
        tapContractions(&core, count: 30, every: 240, first: 1440)
        let output = core.output(at: at(8700))
        #expect(!output.reasons.contains(.contractionOverUrgentDuration))
        let detail = StateCopy.detail(for: output, region: .uk, thresholds: output.thresholds)
        #expect(detail.contains("A contraction lasted longer than 2 minutes."), "\(detail)")
        #expect(script(&core, now: 8700)["Since the last call"] == "A contraction lasted longer than 2 minutes.")
    }

    @Test("GBS with contractions starting doesn't say \"they may advise staying at home\"")
    func gbsTimeToCall() {
        let profile = LabourProfile(region: .uk, gestationalAgeDays: 280, gbsPositive: true)
        var core = LabourSessionCore(start: session(profile), deviceID: "phone")
        tapContractions(&core, count: 3, every: 480, first: 0)
        let output = core.output(at: at(1100))
        #expect(output.reasons.first == .gbsInLabour)
        let detail = StateCopy.detail(for: output, region: .uk, thresholds: output.thresholds)
        #expect(detail.contains("GBS positive"))
        #expect(!detail.contains("staying at home"))
        // A 5-1-1 run without GBS keeps the usual line.
        var plain = LabourSessionCore(start: session(), deviceID: "phone")
        tapContractions(&plain, count: 5, every: 240, first: 0)
        let usual = plain.output(at: at(1100))
        #expect(StateCopy.detail(for: usual, region: .uk, thresholds: usual.thresholds).contains("staying at home"))
    }

    @Test(
        "Over 24 hours after the waters, under 37 weeks or weeks unknown: call them, no talk of a time to go in",
        arguments: [238, nil] as [Int?])
    func watersOver24HoursNotTerm(days: Int?) {
        var core = LabourSessionCore(
            start: session(LabourProfile(region: .uk, gestationalAgeDays: days)), deviceID: "phone")
        core.setRedFlag(.watersBroken, isOn: true, at: at(0), happenedAt: at(-82800))
        core.logCall(.stayHome, at: at(60))
        let output = core.output(at: at(3700))
        let detail = StateCopy.detail(for: output, region: .uk, thresholds: output.thresholds)
        #expect(detail.contains("over 24 hours since her waters went. Call them and tell them."), "\(detail)")
        #expect(!detail.contains("time to go in"))
    }

    @Test("After more than an hour of timing, \"Longest\" says \"in the last hour\" every time")
    func longestWindow() {
        var core = LabourSessionCore(start: session(), deviceID: "phone")
        tapContractions(&core, count: 40, every: 300, first: 0)
        for now in stride(from: 4000.0, through: 11800, by: 150) {
            #expect(script(&core, now: now)["Longest"]?.hasSuffix("in the last hour") == true, "\(now)")
        }
    }

    @Test("\"For the last\" only when the script also says what came before")
    func forTheLastNeedsBefore() {
        let gaps: [Double] = [140, 140, 140, 140] + Array(repeating: 70, count: 18)
        let contractions = withGaps(gaps)
        let metrics = ContractionMetrics.compute(
            contractions, thresholds: uk, now: (contractions.last?.start ?? at(0)).addingTimeInterval(30))
        let line = TriageScript.contractionSummary(metrics, thresholds: uk)
        #expect(line.contains("for the last") == line.contains("before"), "\(line)")
    }
}
