import Foundation
import Testing

@testable import MissionCore

private func brief(
    _ thresholds: ThresholdProfile = ThresholdTable.builtIn(for: .uk).defaults, region: ContentRegion = .uk,
    parity: Int = 0
) -> MissionBrief {
    MissionBrief(
        region: region, dueDateText: "2026-12-07", parity: parity, previousFastLabour: false, travelMinutes: 25,
        thresholds: thresholds, motherName: "Sam", unitName: "Northgate", triage: nil, labourWard: nil,
        gbsPositive: true, plannedCaesarean: true, updatedAt: at(0))
}

@Suite("Launch window")
struct LaunchWindowTests {
    @Test("LAUNCH at every week; the drill sits under it from 30+0 to 36+6 and moves to the hangar at 37+0")
    func boundaries() {
        #expect(LaunchWindow(gestationalAgeDays: 28) == .beforeDrill)
        #expect(LaunchWindow(gestationalAgeDays: 209) == .beforeDrill)
        #expect(LaunchWindow(gestationalAgeDays: 210) == .drill)
        #expect(LaunchWindow(gestationalAgeDays: 258) == .drill)
        #expect(LaunchWindow(gestationalAgeDays: 259) == .term)
        #expect(LaunchWindow(gestationalAgeDays: 294) == .term)
        // Weeks not known: LAUNCH first, the drill under it, as before 37 weeks.
        #expect(LaunchWindow(gestationalAgeDays: nil) == .drill)
        #expect(LaunchWindow(gestationalAgeDays: 258).drillOnLaunchCard)
        #expect(!LaunchWindow(gestationalAgeDays: 259).drillOnLaunchCard)
        #expect(LaunchWindow(gestationalAgeDays: 259).drillInHangar)
        #expect(!LaunchWindow(gestationalAgeDays: 209).drillOnLaunchCard)
        #expect(!LaunchWindow(gestationalAgeDays: 209).drillInHangar)
    }

    @Test("Before 37 weeks the launch wording never says it's too early")
    func wording() {
        for days in [28, 150, 210, 258] {
            #expect(LaunchWindow(gestationalAgeDays: days).launchSubtitle == "Labour started? Any week.")
        }
    }
}

@Suite("Practice run")
struct DrillTests {
    @Test("A drill is its own 39+0 session with his parity and rule, never the real one")
    func session() {
        let real = brief(parity: 1).sessionStart(at: at(0), by: "phone", calendar: .current)
        let drill = Drill.sessionStart(brief(parity: 1), at: at(0))
        #expect(drill.sessionID != real.sessionID)
        #expect(drill.startedBy == Drill.deviceID)
        #expect(drill.profile.gestationalAgeDays == Drill.gestationalAgeDays)
        #expect(drill.profile.parity == 1)
        #expect(!drill.profile.gbsPositive && !drill.profile.plannedCaesarean)
        #expect(drill.thresholds == real.thresholds)
    }

    @Test("Drill taps never reach a real session's log, whichever way they're merged")
    func isolated() {
        var real = LabourSessionCore(
            start: brief().sessionStart(at: at(0), by: "phone", calendar: .current), deviceID: "phone")
        var drill = LabourSessionCore(start: Drill.sessionStart(brief(), at: at(0)), deviceID: Drill.deviceID)
        Drill.skipAhead(&drill, from: at(10))
        drill.setRedFlag(.watersBroken, isOn: true, at: at(3000))
        #expect(real.merge(drill.events).isEmpty)
        #expect(real.log.contractions.isEmpty && real.log.activeRedFlags.isEmpty)
    }

    @Test("Walking through the drill: taps, skip ahead to the call point, waters, the call, the debrief")
    func walkThrough() {
        var core = LabourSessionCore(start: Drill.sessionStart(brief(), at: at(0)), deviceID: Drill.deviceID)
        #expect(Drill.step(core.log) == .tapStart(number: 1))
        _ = core.tap(at: at(5))
        #expect(Drill.step(core.log) == .tapStop(number: 1))
        _ = core.tap(at: at(9))
        #expect(Drill.step(core.log) == .tapStart(number: 2))
        _ = core.tap(at: at(14))
        _ = core.tap(at: at(18))
        #expect(Drill.step(core.log) == .skipAhead)
        let resume = Drill.skipAhead(&core, from: at(20))
        let output = core.output(at: resume)
        #expect(output.state == .callTriage)
        #expect(Drill.step(core.log) == .watersCue)
        core.setRedFlag(.watersBroken, isOn: true, at: resume.addingTimeInterval(30))
        #expect(Drill.step(core.log) == .watersTime)
        core.setFlagTime(.watersBroken, happenedAt: resume, at: resume.addingTimeInterval(40))
        #expect(Drill.step(core.log) == .logCall)
        core.logCall(.comeIn, at: resume.addingTimeInterval(120))
        #expect(Drill.step(core.log) == .debrief)
        let debrief = Drill.debrief(&core, at: resume.addingTimeInterval(130))
        #expect(debrief.callPointAt != nil)
        #expect(debrief.watersAt == resume)
        #expect(debrief.calledAt == resume.addingTimeInterval(120))
    }

    @Test(
        "Skipping ahead reaches the call point under the rule he has set",
        arguments: [
            ThresholdTable.builtIn(for: .uk).defaults, ukWithHour,
            ThresholdTable.builtIn(for: .uk).profile(applying: [.adviceIntervalSec: 180]),
            ThresholdTable.builtIn(for: .us).defaults,
        ])
    func skipReachesCallPoint(thresholds: ThresholdProfile) {
        let region: ContentRegion = thresholds == ThresholdTable.builtIn(for: .us).defaults ? .us : .uk
        var core = LabourSessionCore(
            start: Drill.sessionStart(brief(thresholds, region: region), at: at(0)), deviceID: Drill.deviceID)
        let resume = Drill.skipAhead(&core, from: at(0))
        #expect(core.output(at: resume).contractionAdvice.state == .callTriage)
        #expect(Drill.step(core.log) == .watersCue)
    }

    @Test("A contraction left running when he skips ahead is stopped first")
    func skipStopsOpenContraction() {
        var core = LabourSessionCore(start: Drill.sessionStart(brief(), at: at(0)), deviceID: Drill.deviceID)
        _ = core.tap(at: at(5))
        Drill.skipAhead(&core, from: at(30))
        #expect(core.log.openContraction == nil)
        #expect(core.log.contractions.first?.end == at(30))
    }

    @Test("Every drill line reads cleanly and says what to do", arguments: ContentRegion.allCases)
    func copy(region: ContentRegion) {
        let core = LabourSessionCore(start: Drill.sessionStart(brief(region: region), at: at(0)), deviceID: "drill")
        let plan = Drill.skipPlan(core)
        let steps: [Drill.Step] = [
            .tapStart(number: 1), .tapStop(number: 1), .tapStart(number: 2), .skipAhead, .watersCue, .watersTime,
            .logCall, .debrief,
        ]
        var lines = steps.flatMap { step -> [String] in
            let guide = Drill.guide(step, plan: plan, region: region)
            return [guide.title, guide.detail]
        }
        let debriefLines = Drill.debriefLines(
            Drill.Debrief(startedAt: at(0), callPointAt: at(600), watersAt: at(2820), calledAt: at(2880)), plan: plan,
            region: region)
        #expect(debriefLines.first?.hasPrefix("The call point came 10 min into the drill") == true)
        #expect(debriefLines[1] == "Her waters went 47 min in. On its own, that means call now.")
        lines += debriefLines
        lines += [Drill.startQuestion, Drill.startYes, Drill.startNo]
        for line in lines {
            #expect(!line.isEmpty)
            for phrase in StateCopyTests.forbidden {
                #expect(!line.lowercased().contains(phrase), "\"\(line)\" contains \"\(phrase)\"")
            }
        }
        #expect(Drill.guide(.skipAhead, plan: plan, region: region).title == "Skip ahead 45 minutes")
    }
}
