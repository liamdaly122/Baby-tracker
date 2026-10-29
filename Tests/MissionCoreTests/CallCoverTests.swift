import Foundation
import Testing

@testable import MissionCore

private let term = LabourProfile(region: .uk, gestationalAgeDays: 280)

private func session(_ profile: LabourProfile = term, id: String = "A2") -> SessionStart {
    SessionStart(
        sessionID: UUID(uuidString: "00000000-0000-0000-0000-0000000000\(id)") ?? UUID(),
        startedAt: at(0),
        startedBy: "phone",
        profile: profile,
        thresholds: ThresholdTable.builtIn(for: profile.region).defaults
    )
}

private func isCallBack(_ status: CallStatus?) -> Bool {
    if case .callBack = status { return true }
    return false
}

private func fresh(_ status: CallStatus?) -> [ReasonCode] {
    if case .callBack(_, let reasons) = status { return reasons }
    return []
}

@Suite("What a logged call covers")
struct CallCoverTests {
    @Test("A new run after \"they've stopped\" is news, even hours later, and the screen and alert agree")
    func restartAfterStop() {
        var run = DeviceRun(LabourSessionCore(start: session(), deviceID: "phone"))
        run.contractions(count: 4, every: 240, first: 0)
        run.core.logCall(.stayHome, at: at(810))
        run.refresh(810)
        run.core.markStopped(at: at(2310))
        run.refresh(2310)
        #expect(run.core.output(at: at(2400)).call?.acknowledgedAt == at(810))

        run.alerts = []
        run.contractions(count: 5, every: 240, first: 42000)
        let output = run.core.output(at: at(43300))
        #expect(output.state == .callTriage)
        #expect(fresh(output.call) == [.regularPatternSustained])
        #expect(StateCopy.headline(for: output, region: .uk) == "Call your maternity unit back")
        #expect(run.alerts.map(\.kind) == [.callBack])
    }

    @Test("A flag turned off and on again after the call is news")
    func flagBackOn() {
        var core = LabourSessionCore(start: session(), deviceID: "phone")
        core.setRedFlag(.bleeding, isOn: true, at: at(0))
        core.logCall(.stayHome, at: at(60))
        core.setRedFlag(.bleeding, isOn: false, at: at(1800))
        core.setRedFlag(.bleeding, isOn: true, at: at(7200))
        #expect(fresh(core.output(at: at(7300)).call) == [.bleeding])
    }

    @Test("A long contraction after the call stays news until he calls again")
    func longContractionLatches() {
        var core = LabourSessionCore(start: session(), deviceID: "phone")
        core.setRedFlag(.watersBroken, isOn: true, at: at(0))
        core.logCall(.stayHome, at: at(60))
        tapContractions(&core, count: 1, every: 600, duration: 150, first: 600)
        #expect(fresh(core.output(at: at(800)).call) == [.contractionOverUrgentDuration])
        // The engine lets the long contraction leave its window; the call still doesn't cover it.
        let later = core.output(at: at(6000))
        #expect(!later.reasons.contains(.contractionOverUrgentDuration))
        #expect(fresh(later.call) == [.contractionOverUrgentDuration])
        core.logCall(.stayHome, at: at(6100))
        #expect(core.output(at: at(6200)).call?.acknowledgedAt == at(6100))
    }

    @Test("A call made early isn't undone by a rise below the call point; reaching it is news, alerted once")
    func earlyCallThenRise() {
        var run = DeviceRun(LabourSessionCore(start: session(), deviceID: "phone"))
        run.core.logCall(.stayHome, at: at(30))
        run.refresh(30)
        run.contractions(count: 8, every: 390, first: 100)
        let building = run.core.output(at: at(3300))
        #expect(building.state == .establishing)
        #expect(building.call?.acknowledgedAt == at(30))
        #expect(run.alerts.isEmpty)

        run.contractions(count: 5, every: 240, first: 3400)
        let output = run.core.output(at: at(4500))
        #expect(output.state == .callTriage)
        #expect(isCallBack(output.call))
        #expect(run.count(.callBack) == 1)
        #expect(run.alerts.count == 1)
    }

    @Test(
        "A second long contraction is news whether the call was logged before or after the first was stopped",
        arguments: [true, false])
    func longContractionEitherOrder(loggedWhileOpen: Bool) {
        var core = LabourSessionCore(start: session(), deviceID: "phone")
        _ = core.tap(at: at(600))
        if loggedWhileOpen {
            core.logCall(.stayHome, at: at(740))
            _ = core.tap(at: at(750))
        } else {
            _ = core.tap(at: at(750))
            core.logCall(.stayHome, at: at(800))
        }
        #expect(core.output(at: at(900)).call?.acknowledgedAt != nil)
        _ = core.tap(at: at(1200))
        let open = core.output(at: at(1340))
        _ = core.tap(at: at(1350))
        let stopped = core.output(at: at(1360))
        #expect(isCallBack(open.call))
        #expect(isCallBack(stopped.call))
        #expect(fresh(open.call).map(GoNoGoEngine.longKey) == fresh(stopped.call).map(GoNoGoEngine.longKey))
    }

    @Test("A call made under 999 covers the waters underneath: no call back once the 999 flag is off")
    func callUnder999CoversLowerFlags() {
        var core = LabourSessionCore(start: session(), deviceID: "phone")
        core.setRedFlag(.watersBroken, isOn: true, at: at(0))
        core.setRedFlag(.heavyBleeding, isOn: true, at: at(10))
        core.logCall(.comeIn, at: at(30))
        core.setRedFlag(.heavyBleeding, isOn: false, at: at(60))
        let output = core.output(at: at(200))
        #expect(output.state == .callNow)
        #expect(output.call?.acknowledgedAt == at(30))
        #expect(StateCopy.headline(for: output, region: .uk) == "They said come in")
    }

    @Test("Contraction taps from before the call that reach the phone late aren't news")
    func lateTapsFromBeforeTheCall() {
        let start = session()
        var watch = LabourSessionCore(start: start, deviceID: "watch")
        tapContractions(&watch, count: 4, every: 240, first: 0)
        var phone = LabourSessionCore(start: start, deviceID: "phone")
        phone.merge(Array(watch.events.prefix(6)))
        #expect(phone.output(at: at(780)).state == .early)
        let call = phone.logCall(.stayHome, at: at(790))
        phone.merge(watch.events)
        watch.merge([call])
        for core in [phone, watch] {
            var core = core
            let output = core.output(at: at(800))
            #expect(output.state == .callTriage)
            #expect(output.call?.acknowledgedAt == at(790))
        }
    }

    @Test("A flag the phone hadn't heard about when he called is news, so he says it on the next call")
    func flagFromTheOtherDeviceBeforeTheCall() {
        let start = session()
        var watch = LabourSessionCore(start: start, deviceID: "watch")
        watch.setRedFlag(.watersBroken, isOn: true, at: at(100))
        var phone = LabourSessionCore(start: start, deviceID: "phone")
        let call = phone.logCall(.stayHome, at: at(130))
        phone.merge(watch.events)
        watch.merge([call])
        #expect(fresh(phone.output(at: at(200)).call) == [.watersBroken])
        #expect(fresh(watch.output(at: at(200)).call) == [.watersBroken])
    }

    @Test("A flag turned on after the call is news even if he says it happened before")
    func backdatedFlagAfterTheCall() {
        var core = LabourSessionCore(start: session(), deviceID: "phone")
        core.setRedFlag(.reducedMovements, isOn: true, at: at(0))
        core.logCall(.stayHome, at: at(100))
        core.setRedFlag(.watersBroken, isOn: true, at: at(1000), happenedAt: at(50))
        #expect(fresh(core.output(at: at(1100)).call) == [.watersBroken])
    }

    @Test("While the call covers everything, no alert says \"call now\", even after a 999 flag is cleared")
    func noAlertWhileCovered() {
        var core = LabourSessionCore(start: session(), deviceID: "phone")
        core.setRedFlag(.watersBroken, isOn: true, at: at(0))
        core.logCall(.stayHome, at: at(60))
        core.setRedFlag(.cordVisible, isOn: true, at: at(100))
        core.setRedFlag(.cordVisible, isOn: false, at: at(110))
        let held = core.output(at: at(110))
        #expect(held.state == .call999)
        let output = core.output(at: at(175))
        #expect(output.call?.acknowledgedAt == at(60))
        #expect(LabourAlertPlanner.immediate(previous: held.snapshot, output: output, region: .uk).isEmpty)
    }
}

@Suite("Alerts on the phone")
struct DeviceAlertTests {
    @Test("Waters, a call, then contractions reaching the call point: one \"call back\", never repeated")
    func callBackOnce() {
        var run = DeviceRun(LabourSessionCore(start: session(), deviceID: "phone"))
        run.core.setRedFlag(.watersBroken, isOn: true, at: at(0))
        run.refresh(0)
        run.core.logCall(.stayHome, at: at(60))
        run.refresh(60)
        run.contractions(count: 8, every: 240, first: 600)
        run.idle(from: 2600, until: 3300)
        #expect(run.count(.callBack) == 1)
        #expect(run.count(.newUrgentReason) == 0)
    }

    @Test("Under a flag, contractions reaching the call point alert once, not on every refresh")
    func underFlagOnce() {
        var run = DeviceRun(LabourSessionCore(start: session(), deviceID: "phone"))
        run.core.setRedFlag(.watersBroken, isOn: true, at: at(0))
        run.refresh(0)
        run.contractions(count: 8, every: 240, first: 600)
        run.idle(from: 2600, until: 3300)
        #expect(run.alerts.filter { $0.reason == .regularPatternSustained }.count == 1)
    }

    @Test("\"Call back\" for a long contraction replaces the still-going nudge planned for it")
    func callBackSharesTheNudgeIdentifier() {
        let start = session()
        var core = LabourSessionCore(start: start, deviceID: "phone")
        core.setRedFlag(.watersBroken, isOn: true, at: at(0))
        core.logCall(.stayHome, at: at(60))
        _ = core.tap(at: at(1000))
        let opened = core.output(at: at(1000))
        let nudge = LabourAlertPlanner.scheduled(
            input: core.engineInput(at: at(1000), previous: opened.snapshot), output: opened,
            watersBrokeAt: core.watersBrokeAt
        ).first { $0.kind == .stillGoing }
        let alerts = LabourAlertPlanner.immediate(
            previous: opened.snapshot, output: core.output(at: at(1122)), region: .uk)
        #expect(alerts.map(\.kind) == [.callBack])
        #expect(nudge != nil)
        #expect(alerts.first?.identifier(sessionID: start.sessionID) == nudge?.identifier(sessionID: start.sessionID))
    }

    @Test("Turning off a 999 flag by mistake keeps the still-going nudge and the waters reminder")
    func clearedFlagKeepsThePlan() {
        var core = LabourSessionCore(start: session(), deviceID: "phone")
        core.setRedFlag(.watersBroken, isOn: true, at: at(0))
        core.setRedFlag(.cordVisible, isOn: true, at: at(100))
        _ = core.tap(at: at(105))
        core.setRedFlag(.cordVisible, isOn: false, at: at(110))
        let output = core.output(at: at(110))
        #expect(output.state == .call999)
        let plan = LabourAlertPlanner.scheduled(
            input: core.engineInput(at: at(110), previous: output.snapshot), output: output,
            watersBrokeAt: core.watersBrokeAt)
        #expect(plan.first { $0.kind == .stillGoing }?.fireAt == at(226))
        #expect(plan.first { $0.kind == .watersDay }?.fireAt == at(86400))

        core.setRedFlag(.cordVisible, isOn: true, at: at(120))
        let live = core.output(at: at(120))
        let none = LabourAlertPlanner.scheduled(
            input: core.engineInput(at: at(120), previous: live.snapshot), output: live,
            watersBrokeAt: core.watersBrokeAt)
        #expect(none.isEmpty)
    }
}

/// The midwife's rule for the running labour, as "Use these for this labour" applies it.
private func applyRule(_ core: inout LabourSessionCore, interval: Double) {
    var start = core.start
    start.thresholds = ThresholdTable.builtIn(for: .uk).profile(applying: [.adviceIntervalSec: interval])
    start.revision += 1
    core.update(start)
}

@Suite("What a logged call covers, second review")
struct CallCoverSecondReviewTests {
    @Test(
        "A stricter rule from the midwife after the call: reaching it is news, whichever was tapped first",
        arguments: [true, false])
    func stricterRule(afterTheCall: Bool) {
        var run = DeviceRun(LabourSessionCore(start: session(), deviceID: "phone"))
        run.contractions(count: 6, every: 240, first: 0)
        if !afterTheCall {
            applyRule(&run.core, interval: 180)
        }
        run.core.logCall(.stayHome, at: at(1300))
        run.refresh(1300)
        if afterTheCall {
            applyRule(&run.core, interval: 180)
            run.refresh(1310)
        }
        run.alerts = []
        run.contractions(count: 4, every: 240, first: 1440)
        run.contractions(count: 8, every: 150, first: 2400)
        let output = run.core.output(at: at(3500))
        #expect(output.state == .callTriage)
        #expect(isCallBack(output.call))
        #expect(StateCopy.headline(for: output, region: .uk) == "Call your maternity unit back")
        #expect(run.alerts.map(\.kind) == [.callBack])
    }

    @Test("A looser rule after the call doesn't undo what the call covered")
    func looserRule() {
        var core = LabourSessionCore(start: session(), deviceID: "phone")
        tapContractions(&core, count: 6, every: 240, first: 0)
        core.logCall(.stayHome, at: at(1300))
        applyRule(&core, interval: 420)
        tapContractions(&core, count: 4, every: 240, first: 1440)
        #expect(core.output(at: at(2300)).call?.acknowledgedAt == at(1300))
    }

    @Test("A call about one long contraction doesn't cover a regular pattern that comes later")
    func longContractionThenPattern() {
        var run = DeviceRun(LabourSessionCore(start: session(), deviceID: "phone"))
        run.contractions(count: 1, every: 600, duration: 150, first: 600)
        run.core.logCall(.stayHome, at: at(800))
        run.refresh(800)
        run.alerts = []
        run.contractions(count: 12, every: 240, first: 4400)
        let output = run.core.output(at: at(7300))
        #expect(output.state == .callTriage)
        #expect(fresh(output.call).contains(.regularPatternSustained) || isCallBack(output.call))
        #expect(run.count(.callBack) == 1)
    }

    @Test("A call about a long contraction in a run already at the call point covers the run")
    func longContractionInsideTheRun() {
        var core = LabourSessionCore(start: session(), deviceID: "phone")
        tapContractions(&core, count: 3, every: 240, first: 0)
        tapContractions(&core, count: 1, every: 240, duration: 150, first: 720)
        core.logCall(.stayHome, at: at(900))
        // The long one leaves the hour at 4320 s, then the 15-minute easing hold runs out.
        tapContractions(&core, count: 20, every: 240, first: 960)
        let output = core.output(at: at(5600))
        #expect(!output.reasons.contains(.contractionOverUrgentDuration))
        #expect(output.call?.acknowledgedAt == at(900))
    }

    @Test("A call during 6 in 10 covers it while it carries on, a late tap included, but not a new burst later")
    func burstsAfterABurstCall() {
        var carrying = DeviceRun(LabourSessionCore(start: session(), deviceID: "phone"))
        carrying.contractions(count: 7, every: 90, first: 0)
        carrying.core.logCall(.stayHome, at: at(560))
        carrying.refresh(560)
        carrying.alerts = []
        carrying.contractions(count: 2, every: 200, first: 700)
        carrying.contractions(count: 6, every: 90, first: 1100)
        #expect(carrying.core.output(at: at(1700)).call?.acknowledgedAt == at(560))
        #expect(carrying.alerts.isEmpty)

        var later = DeviceRun(LabourSessionCore(start: session(), deviceID: "phone"))
        later.contractions(count: 7, every: 90, first: 0)
        later.core.logCall(.stayHome, at: at(620))
        later.refresh(620)
        later.alerts = []
        later.contractions(count: 7, every: 90, first: 14400)
        #expect(fresh(later.core.output(at: at(15100)).call) == [.tooManyInTenMinutes])
        #expect(later.count(.callBack) == 1)
    }

    @Test("Answering \"37 weeks or more\" after a GBS and waters call isn't news; \"under 37\" is")
    func termAnswerAfterGBSCall() {
        let profile = LabourProfile(region: .uk, gbsPositive: true)
        var term = LabourSessionCore(start: session(profile), deviceID: "phone")
        term.setRedFlag(.watersBroken, isOn: true, at: at(0))
        term.logCall(.comeIn, at: at(60))
        var preterm = term
        term.answerTerm(.term, at: at(120))
        let output = term.output(at: at(130))
        #expect(output.call?.acknowledgedAt == at(60))
        #expect(StateCopy.headline(for: output, region: .uk) == "They said come in")
        preterm.answerTerm(.preterm, at: at(120))
        #expect(fresh(preterm.output(at: at(130)).call) == [.preterm])
    }

    @Test("With GBS, a first contraction the phone hadn't heard about when he called is news")
    func gbsFirstContractionFromTheWatch() {
        let start = session(LabourProfile(region: .uk, gestationalAgeDays: 280, gbsPositive: true))
        var watch = LabourSessionCore(start: start, deviceID: "watch")
        tapContractions(&watch, count: 1, every: 240, first: 0)
        var phone = LabourSessionCore(start: start, deviceID: "phone")
        let call = phone.logCall(.stayHome, at: at(120))
        phone.merge(watch.events)
        watch.merge([call])
        #expect(fresh(phone.output(at: at(130)).call) == [.gbsInLabour])
        #expect(fresh(watch.output(at: at(130)).call) == [.gbsInLabour])
    }

    @Test("Undoing a later call leaves the earlier call's cover in place")
    func undoLaterCall() {
        let start = session()
        var watch = LabourSessionCore(start: start, deviceID: "watch")
        tapContractions(&watch, count: 4, every: 240, first: 0)
        var phone = LabourSessionCore(start: start, deviceID: "phone")
        phone.merge(Array(watch.events.prefix(6)))
        let first = phone.logCall(.stayHome, at: at(790))
        phone.merge(watch.events)
        let second = phone.logCall(.stayHome, at: at(900))
        let undo = phone.record(.undo, at: at(905), target: second.id)
        watch.merge([first, second, undo])
        #expect(phone.output(at: at(906)).call?.acknowledgedAt == at(790))
        #expect(watch.output(at: at(906)).call?.acknowledgedAt == at(790))
    }

    @Test("GBS and waters called about together, then the waters turned off as a mistake: no call back")
    func gbsWatersOffAfterCall() {
        let profile = LabourProfile(region: .uk, gestationalAgeDays: 280, gbsPositive: true)
        var core = LabourSessionCore(start: session(profile), deviceID: "phone")
        tapContractions(&core, count: 2, every: 600, first: 0)
        core.setRedFlag(.watersBroken, isOn: true, at: at(700), happenedAt: at(690))
        core.logCall(.stayHome, at: at(800))
        core.setRedFlag(.watersBroken, isOn: false, at: at(1400))
        #expect(core.output(at: at(1500)).call?.acknowledgedAt == at(800))

        // Contractions that started after a waters call with none are still news.
        var none = LabourSessionCore(start: session(profile), deviceID: "phone")
        none.setRedFlag(.watersBroken, isOn: true, at: at(0))
        none.logCall(.stayHome, at: at(60))
        tapContractions(&none, count: 1, every: 240, first: 300)
        none.setRedFlag(.watersBroken, isOn: false, at: at(500))
        #expect(fresh(none.output(at: at(600)).call) == [.gbsInLabour])
    }
}

@Suite("Alerts, second review")
struct AlertSecondReviewTests {
    @Test("A contraction passing 2 minutes during the minute after a 999 flag is turned off still alerts")
    func longContractionDuringTheHold() {
        var run = DeviceRun(LabourSessionCore(start: session(), deviceID: "phone"))
        _ = run.core.tap(at: at(30))
        run.refresh(30)
        run.core.setRedFlag(.cordVisible, isOn: true, at: at(100))
        run.refresh(100)
        run.core.setRedFlag(.cordVisible, isOn: false, at: at(110))
        run.refresh(110)
        run.alerts = []
        run.idle(from: 115, until: 160)
        let inside = run.core.output(at: at(160))
        let plan = LabourAlertPlanner.scheduled(
            input: run.core.engineInput(at: at(160), previous: run.alerted), output: inside)
        #expect(plan.contains { $0.kind == .stillGoing })
        run.idle(from: 175, until: 400)
        #expect(run.alerts.contains { $0.reason == .openContractionOverUrgentDuration })
    }

    @Test("Easing back down from 6 in 10 to the regular pattern isn't alerted as news")
    func easingBackDown() {
        var run = DeviceRun(LabourSessionCore(start: session(), deviceID: "phone"))
        run.contractions(count: 8, every: 240, first: 100)
        run.contractions(count: 6, every: 100, first: 2020)
        let burst = run.alerts.count
        run.contractions(count: 22, every: 240, first: 2620)
        #expect(run.core.output(at: at(7900)).contractionAdvice.state == .callTriage)
        #expect(run.alerts.count == burst)
    }

    @Test("One long contraction is one planned alert, even when a rise is due a second before the nudge")
    func riseCoversTheNudge() {
        var core = LabourSessionCore(start: session(), deviceID: "phone")
        tapContractions(&core, count: 16, every: 240, first: 0)
        _ = core.tap(at: at(3960))
        let output = core.output(at: at(3960))
        let plan = LabourAlertPlanner.scheduled(
            input: core.engineInput(at: at(3960), previous: output.snapshot), output: output)
        #expect(plan.contains { $0.kind == .scheduledRise })
        #expect(!plan.contains { $0.kind == .stillGoing })
    }

    @Test("Coming down from 999 to something new since the call alerts \"call back\", as the screen says")
    func callBackAfter999() {
        var run = DeviceRun(LabourSessionCore(start: session(), deviceID: "phone"))
        run.core.setRedFlag(.bleeding, isOn: true, at: at(0))
        run.refresh(0)
        run.core.logCall(.stayHome, at: at(60))
        run.refresh(60)
        run.core.setRedFlag(.severePain, isOn: true, at: at(300))
        run.refresh(300)
        run.alerts = []
        run.core.setRedFlag(.bleeding, isOn: false, at: at(400))
        run.refresh(400)
        run.idle(from: 415, until: 600)
        let output = run.core.output(at: at(400))
        #expect(run.alerts.map(\.kind) == [.callBack])
        #expect(run.alerts.first?.title == StateCopy.headline(for: output, region: .uk))
    }
}
