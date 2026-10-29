import Foundation
import Testing

@testable import MissionCore

private let start = SessionStart(
    sessionID: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1") ?? UUID(),
    startedAt: at(0),
    startedBy: "phone",
    profile: LabourProfile(region: .uk, gestationalAgeDays: 280),
    thresholds: ThresholdTable.builtIn(for: .uk).defaults
)

/// Taps `count` contractions on `core`, every `every` seconds from `first`, each `duration` long.
private func tap(_ core: inout LabourSessionCore, count: Int, every: Double, duration: Double = 50, first: Double) {
    for index in 0..<count {
        let begin = first + Double(index) * every
        _ = core.tap(at: at(begin))
        _ = core.tap(at: at(begin + duration))
    }
}

private func script(_ core: inout LabourSessionCore, now: Double, details: TriageDetails = TriageDetails()) -> [String:
    String]
{
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    let output = core.output(at: at(now))
    let built = TriageScript.build(
        TriageScript.Inputs(details: details, output: output, log: core.log, now: at(now), calendar: calendar))
    return Dictionary(built.lines.map { ($0.label, $0.value) }, uniquingKeysWith: { first, _ in first })
}

@Suite("Red flags")
struct RedFlagReworkTests {
    @Test("Gaps read as durations, never as a time of day")
    func gapsReadAsDurations() {
        #expect(StateCopy.spoken(675, threshold: 300) == "11 min 15 sec")
        #expect(StateCopy.spoken(240, threshold: 300) == "4 min")
        #expect(StateCopy.spoken(45) == "45 sec")
        #expect(StateCopy.clockRange(240, 675, threshold: 300) == "4:00–11:15")
        #expect(StateCopy.clockRange(180, 300, threshold: 300) == "3–5 min")
        // Never rounded across the call point at either end.
        #expect(StateCopy.clockRange(240, 301, threshold: 300) == "4:00–5:05")
    }

    @Test("Head visible is 999; severe pain and pre-eclampsia signs are call now")
    func newFlags() {
        #expect(RedFlag.headVisible.state == .call999)
        #expect(RedFlag.severePain.state == .callNow)
        #expect(RedFlag.preEclampsiaSigns.state == .callNow)
        #expect(
            StateCopy.reasonLine(for: .heavyBleeding, metrics: emptyMetrics, thresholds: ukDefaults).contains("pad"))
    }

    @Test("GBS positive with her waters gone says so; a planned caesarean means call now")
    func profileReasons() {
        let gbs = LabourProfile(region: .uk, gestationalAgeDays: 280, gbsPositive: true)
        let waters = GoNoGoEngine.evaluate(ukInput([], flags: [.watersBroken], profile: gbs, now: 60))
        #expect(waters.reasons == [.watersBroken, .gbsWithWaters])
        #expect(GoNoGoEngine.evaluate(ukInput([], profile: gbs, now: 60)).state == .early)
        let caesarean = LabourProfile(region: .uk, gestationalAgeDays: 280, plannedCaesarean: true)
        let planned = GoNoGoEngine.evaluate(ukInput([], profile: caesarean, now: 60))
        #expect(planned.state == .callNow)
        #expect(planned.reasons == [.plannedCaesarean])
    }

    @Test("Turning off a 999 flag keeps 999 up for a minute; other flags clear at once")
    func emergencyClearHold() {
        var core = LabourSessionCore(start: start, deviceID: "phone")
        core.setRedFlag(.urgeToPush, isOn: true, at: at(0))
        core.setRedFlag(.urgeToPush, isOn: false, at: at(100))
        let held = core.output(at: at(130))
        #expect(held.state == .call999)
        #expect(held.reasons == [.urgeToPush, .emergencyJustCleared])
        #expect(held.nextReviewAt == at(160.001))
        #expect(core.output(at: at(161)).state == .early)

        var waters = LabourSessionCore(start: start, deviceID: "phone")
        waters.setRedFlag(.watersBroken, isOn: true, at: at(0))
        waters.setRedFlag(.watersBroken, isOn: false, at: at(100))
        #expect(waters.output(at: at(101)).state == .early)
    }

    @Test("A logged call covers what's showing; contractions reaching the call point later mean calling back")
    func callThenPattern() {
        var core = LabourSessionCore(start: start, deviceID: "phone")
        core.setRedFlag(.watersBroken, isOn: true, at: at(0))
        core.logCall(.stayHome, at: at(60))
        let after = core.output(at: at(120))
        #expect(after.call == .acknowledged(LoggedCall(at: at(60), note: core.log.lastCall?.note ?? anyNote)))
        #expect(StateCopy.headline(for: after, region: .uk) == "They said stay at home for now")
        #expect(StateCopy.detail(for: after, region: .uk, thresholds: after.thresholds).contains("temperature"))

        tap(&core, count: 6, every: 240, first: 600)
        let changed = core.output(at: at(2000))
        guard case .callBack(_, let fresh) = changed.call else {
            Issue.record("expected call back, got \(String(describing: changed.call))")
            return
        }
        #expect(fresh == [.regularPatternSustained])
        #expect(StateCopy.headline(for: changed, region: .uk) == "Call your maternity unit back")
    }

    @Test("A call, its note and a strength reach the watch through the sync format and read the same there")
    func callSyncsToWatch() throws {
        var phone = LabourSessionCore(start: start, deviceID: "phone")
        phone.setRedFlag(.watersBroken, isOn: true, at: at(0), happenedAt: at(-1800))
        tap(&phone, count: 1, every: 240, first: 30)
        if let first = phone.log.contractions.first { phone.rate(first.id, .strong, at: at(100)) }
        phone.logCall(.stayHome, at: at(120))
        phone.setRedFlag(.bleeding, isOn: true, at: at(180))

        let message = SyncMessage.events(sessionID: start.sessionID, phone.events)
        let received = try #require(SyncMessage(payload: try message.payload()))
        guard case .events(_, let events) = received else {
            Issue.record("expected events")
            return
        }
        var watch = LabourSessionCore(start: start, deviceID: "watch")
        _ = watch.merge(events)

        let onPhone = phone.output(at: at(200))
        let onWatch = watch.output(at: at(200))
        #expect(onWatch.call == onPhone.call)
        guard case .callBack(_, let fresh) = onWatch.call else {
            Issue.record("expected call back on the watch, got \(String(describing: onWatch.call))")
            return
        }
        #expect(fresh.contains(.bleeding))
        #expect(watch.log.lastCall?.note.outcome == .stayHome)
        #expect(watch.log.strengths.values.contains(.strong))
        #expect(watch.watersBrokeAt == at(-1800))
    }

    @Test("After a call, 6 in 10 or a contraction over 2 minutes means calling back")
    func callThenUrgent() {
        var sixInTen = LabourSessionCore(start: start, deviceID: "phone")
        sixInTen.setRedFlag(.watersBroken, isOn: true, at: at(0))
        sixInTen.logCall(.stayHome, at: at(60))
        tap(&sixInTen, count: 6, every: 95, duration: 40, first: 600)
        guard case .callBack(_, let fresh) = sixInTen.output(at: at(1200)).call else {
            Issue.record("expected call back")
            return
        }
        #expect(fresh.contains(.tooManyInTenMinutes))

        var long = LabourSessionCore(start: start, deviceID: "phone")
        long.setRedFlag(.watersBroken, isOn: true, at: at(0))
        long.logCall(.stayHome, at: at(60))
        _ = long.tap(at: at(600))
        guard case .callBack(_, let urgent) = long.output(at: at(730)).call else {
            Issue.record("expected call back")
            return
        }
        #expect(urgent == [.openContractionOverUrgentDuration])
    }

    @Test("Calling back is alerted once, as one time-sensitive alert")
    func callBackAlert() {
        var core = LabourSessionCore(start: start, deviceID: "phone")
        core.setRedFlag(.watersBroken, isOn: true, at: at(0))
        core.logCall(.stayHome, at: at(60))
        tap(&core, count: 3, every: 240, first: 600)
        let before = core.output(at: at(1200))
        #expect(before.snapshot.acknowledgedCallAt == at(60))
        _ = core.tap(at: at(1320))
        _ = core.tap(at: at(1370))
        let after = core.output(at: at(1380))
        let alerts = LabourAlertPlanner.immediate(previous: before.snapshot, output: after, region: .uk)
        #expect(alerts.map(\.kind) == [.callBack])
        #expect(alerts.first?.level == .timeSensitive)
        #expect(LabourAlertPlanner.immediate(previous: after.snapshot, output: after, region: .uk).isEmpty)
    }

    @Test("With no call logged, contractions reaching the call point under a flag still alert")
    func patternUnderFlagAlerts() {
        var core = LabourSessionCore(start: start, deviceID: "phone")
        core.setRedFlag(.watersBroken, isOn: true, at: at(0))
        tap(&core, count: 3, every: 240, first: 600)
        let before = core.output(at: at(1200))
        #expect(before.contractionAdvice.state < .callTriage)
        _ = core.tap(at: at(1320))
        _ = core.tap(at: at(1370))
        let after = core.output(at: at(1380))
        #expect(after.contractionAdvice.state == .callTriage)
        let alerts = LabourAlertPlanner.immediate(previous: before.snapshot, output: after, region: .uk)
        #expect(alerts.map(\.reason) == [.regularPatternSustained])
    }

    @Test("A call doesn't cover 999, and undoing the call removes it")
    func callLimits() {
        var core = LabourSessionCore(start: start, deviceID: "phone")
        core.setRedFlag(.urgeToPush, isOn: true, at: at(0))
        core.logCall(.other, at: at(30))
        #expect(core.output(at: at(40)).call == nil)

        var undone = LabourSessionCore(start: start, deviceID: "phone")
        undone.setRedFlag(.bleeding, isOn: true, at: at(0))
        let call = undone.logCall(.stayHome, at: at(30))
        undone.record(.undo, at: at(35), target: call.id)
        #expect(undone.output(at: at(40)).call == nil)
    }

    @Test("When her waters went can be set and corrected, and the reminder comes 24 hours after")
    func watersTime() {
        var core = LabourSessionCore(start: start, deviceID: "phone")
        core.setRedFlag(.watersBroken, isOn: true, at: at(3000), happenedAt: at(600))
        #expect(core.watersBrokeAt == at(600))
        core.setRedFlag(.watersBroken, isOn: true, at: at(3100), happenedAt: at(300))
        #expect(core.watersBrokeAt == at(300))
        // A time in the future is a slip of the finger: no later than the tap that turned it on.
        core.setRedFlag(.watersBroken, isOn: true, at: at(3200), happenedAt: at(9000))
        #expect(core.watersBrokeAt == at(3000))
        core.setRedFlag(.watersBroken, isOn: true, at: at(3300), happenedAt: at(300))

        let output = core.output(at: at(3400))
        let scheduled = LabourAlertPlanner.scheduled(
            input: core.engineInput(at: at(3400), previous: output.snapshot), output: output,
            watersBrokeAt: core.watersBrokeAt)
        let reminder = scheduled.first { $0.kind == .watersDay }
        #expect(reminder?.fireAt == at(300 + 24 * 3600))
        #expect(reminder?.level == .timeSensitive)
        #expect(script(&core, now: 3400)["Waters"]?.hasPrefix("Broke at 08:05") == true)
    }

    @Test("The script says how long this rate has held, with the slower stretch before it")
    func noOverstatement() {
        var core = LabourSessionCore(start: start, deviceID: "phone")
        tap(&core, count: 12, every: 600, first: 0)
        tap(&core, count: 8, every: 240, first: 6600 + 240)
        let lines = script(&core, now: 8900)
        let contractions = lines["Contractions"] ?? ""
        #expect(contractions.contains("for the last"))
        #expect(contractions.contains("about every 10 min for"))
        let output = core.output(at: at(8900))
        #expect((output.metrics.rateHeldSec ?? 0) < output.metrics.patternSustainedSec)
    }

    @Test("A steady run reads the same as before")
    func steadyRun() {
        let output = GoNoGoEngine.evaluate(ukInput(regular(count: 16, every: 240, duration: 50), now: 3700))
        #expect(output.metrics.rateHeldSec == output.metrics.patternSustainedSec)
        #expect(output.metrics.earlierMedianIntervalSec == nil)
    }

    @Test("The script keeps frequency under a 999 flag, the real window, strength, turned-off flags and the last call")
    func scriptLines() {
        var core = LabourSessionCore(start: start, deviceID: "phone")
        tap(&core, count: 6, every: 95, duration: 40, first: 0)
        core.setRedFlag(.urgeToPush, isOn: true, at: at(600))
        let lines = script(&core, now: 610)
        #expect(lines["Frequency"] == "6 in 10 minutes")
        #expect(lines["Longest"]?.hasSuffix("in the last 10 min") == true)

        var rated = LabourSessionCore(start: start, deviceID: "phone")
        tap(&rated, count: 3, every: 240, first: 0)
        let ids = rated.log.contractions.map(\.id)
        rated.rate(ids[0], .moderate, at: at(100))
        rated.rate(ids[1], .strong, at: at(400))
        rated.rate(ids[2], .strong, at: at(700))
        rated.setRedFlag(.bleeding, isOn: true, at: at(720))
        rated.setRedFlag(.bleeding, isOn: false, at: at(780))
        rated.logCall(.stayHome, at: at(800))
        let more = script(
            &rated, now: 900, details: TriageDetails(gbsPositive: true, plannedCaesarean: true))
        #expect(more["Strength"] == "Strong, strong, moderate (latest first)")
        #expect(more["Turned off"] == "Bleeding (on 08:12, off 08:13)")
        #expect(more["Last call"]?.contains("stay at home") == true)
        #expect(more["Pregnancy"]?.contains("GBS positive, caesarean planned") == true)
    }

    @Test("Older saves still decode, and a newer reason in a call is dropped, not the call")
    func tolerantDecoding() throws {
        let oldProfile = #"{"region":"uk","parity":0,"previousFastLabour":false,"gestationalAgeDays":280}"#
        let profile = try JSONDecoder().decode(LabourProfile.self, from: Data(oldProfile.utf8))
        #expect(!profile.gbsPositive && !profile.plannedCaesarean)
        let note =
            #"{"outcome":"stayHome","state":"callNow","contractionState":"early","#
            + #""reasons":["watersBroken","fromTheFuture"]}"#
        let decoded = try JSONDecoder().decode(CallNote.self, from: Data(note.utf8))
        #expect(decoded.reasons == [.watersBroken])
        var brief = MissionBrief(
            region: .uk, dueDateText: nil, parity: 0, previousFastLabour: false, travelMinutes: nil,
            thresholds: ukDefaults, motherName: "", unitName: "", triage: nil, labourWard: nil, updatedAt: at(0))
        brief.gbsPositive = true
        let encoded = try JSONEncoder().encode(brief)
        #expect(
            try JSONDecoder().decode(MissionBrief.self, from: encoded).labourProfile(at: at(0), calendar: .current)
                .gbsPositive)
    }

    @Test("Two devices with the same call and flags agree")
    func devicesAgreeOnCalls() {
        var phone = LabourSessionCore(start: start, deviceID: "phone")
        var watch = LabourSessionCore(start: start, deviceID: "watch")
        watch.setRedFlag(.watersBroken, isOn: true, at: at(0), happenedAt: at(-600))
        phone.merge(watch.events)
        phone.logCall(.stayHome, at: at(60))
        tap(&watch, count: 6, every: 240, first: 600)
        watch.merge(phone.events)
        phone.merge(watch.events)
        let fromPhone = phone.output(at: at(2100))
        let fromWatch = watch.output(at: at(2100))
        #expect(fromPhone.call == fromWatch.call)
        #expect(fromPhone.snapshot == fromWatch.snapshot)
    }
}

private let ukDefaults = ThresholdTable.builtIn(for: .uk).defaults
private let emptyMetrics = ContractionMetrics.compute([], thresholds: ukDefaults, now: at(0))
private let anyNote = CallNote(outcome: .other, state: .early, contractionState: .early, reasons: [])
