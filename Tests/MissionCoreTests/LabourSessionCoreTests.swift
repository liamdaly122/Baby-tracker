import Foundation
import Testing

@testable import MissionCore

private let ukStart = SessionStart(
    sessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
    startedAt: at(0),
    startedBy: "phone",
    profile: LabourProfile(region: .uk, gestationalAgeDays: 280),
    thresholds: ThresholdTable.builtIn(for: .uk).defaults
)

/// Taps a contraction every `every` seconds, each `duration` long, alternating devices if given two.
private func tapRegular(
    _ cores: inout [LabourSessionCore],
    count: Int,
    every: Double,
    duration: Double,
    first: Double = 0
) {
    for index in 0..<count {
        let start = first + Double(index) * every
        let device = index % cores.count
        _ = cores[device].tap(at: at(start))
        _ = cores[device].tap(at: at(start + duration))
    }
}

@Suite("Labour session core")
struct LabourSessionCoreTests {
    @Test("A tap starts, a quick second tap is ignored, and the next tap stops")
    func tapPolicy() throws {
        var core = LabourSessionCore(start: ukStart, deviceID: "phone")
        guard case .started = core.tap(at: at(0)) else { throw Failure("expected a start") }
        #expect(core.tap(at: at(1)) == .ignoredDoubleTap)
        guard case .stopped(_, let duration) = core.tap(at: at(52)) else { throw Failure("expected a stop") }
        #expect(duration == 52)
        #expect(core.log.contractions.count == 1)
    }

    @Test("Past 5 minutes a tap asks instead of recording, and both answers are handled")
    func forgottenStop() throws {
        var core = LabourSessionCore(start: ukStart, deviceID: "phone")
        _ = core.tap(at: at(0))
        guard case .askIfEndedOrNew(let id, let elapsed) = core.tap(at: at(400)) else {
            throw Failure("expected a question")
        }
        #expect(elapsed == 400)
        #expect(core.log.contractions.count == 1)

        var ended = core
        ended.endOpenContraction(at: at(400))
        #expect(ended.log.contractions.first?.end == at(400))

        core.startNew(at: at(400))
        #expect(core.log.contractions.count == 2)
        #expect(core.output(at: at(401)).metrics.needsEdit == [id])
        core.close(id, afterSeconds: 60, at: at(410))
        #expect(core.log.contractions.first?.end == at(60))
        #expect(core.output(at: at(411)).metrics.needsEdit.isEmpty)
    }

    @Test("The 37-week answer and 'they've stopped' reach the engine")
    func answersReachTheEngine() {
        var start = ukStart
        start.profile.gestationalAgeDays = nil
        var core = LabourSessionCore(start: start, deviceID: "phone")
        var cores = [core]
        tapRegular(&cores, count: 6, every: 240, duration: 50)
        core = cores[0]
        #expect(core.output(at: at(1300)).reasons.contains(.gestationUnknown))
        core.answerTerm(.term, at: at(1300))
        let answered = core.output(at: at(1301))
        #expect(!answered.reasons.contains(.gestationUnknown))
        #expect(answered.state == .callTriage)
        core.markStopped(at: at(1400))
        #expect(core.output(at: at(1401)).reasons == [.contractionsStopped])
    }

    @Test("Gestation is fixed at the start: a session at 36+6 stays preterm after midnight")
    func gestationFixedAtStart() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
        // Due 15 Jan 2027: 36+6 is 22 days earlier, 24 Dec 2026.
        let brief = MissionBrief(
            region: .uk, dueDateText: "2027-01-15", parity: 0, previousFastLabour: false, travelMinutes: nil,
            thresholds: ThresholdTable.builtIn(for: .uk).defaults, motherName: "", unitName: "", triage: nil,
            labourWard: nil, updatedAt: at(0))
        let lateEvening =
            calendar.date(from: DateComponents(year: 2026, month: 12, day: 24, hour: 23, minute: 50)) ?? at(0)
        let start = brief.sessionStart(at: lateEvening, by: "watch", calendar: calendar)
        #expect(start.profile.gestationalAgeDays == 36 * 7 + 6)
        var core = LabourSessionCore(start: start, deviceID: "watch")
        _ = core.tap(at: lateEvening)
        let afterMidnight = lateEvening.addingTimeInterval(3600)
        #expect(core.output(at: afterMidnight).reasons.contains(.preterm))
    }

    @Test("Two devices with the same taps give the same advice, whatever order the taps arrive in")
    func devicesAgree() {
        var cores = [
            LabourSessionCore(start: ukStart, deviceID: "phone"),
            LabourSessionCore(start: ukStart, deviceID: "watch"),
        ]
        tapRegular(&cores, count: 14, every: 250, duration: 55)
        var phone = cores[0]
        var watch = cores[1]
        // The watch hears about the phone's taps late; the phone hears in reverse order.
        _ = watch.output(at: at(1000))
        watch.merge(phone.events)
        phone.merge(Array(cores[1].events.reversed()))
        for moment in [3600.0, 3700, 4400, 5200] {
            let fromPhone = phone.output(at: at(moment))
            let fromWatch = watch.output(at: at(moment))
            #expect(fromPhone.state == fromWatch.state, "at \(moment)")
            #expect(fromPhone.reasons == fromWatch.reasons, "at \(moment)")
            #expect(fromPhone.snapshot == fromWatch.snapshot, "at \(moment)")
        }
    }

    @Test("Advice doesn't depend on how often the screen asked for it")
    func pureReplay() {
        var cores = [LabourSessionCore(start: ukStart, deviceID: "phone")]
        tapRegular(&cores, count: 12, every: 270, duration: 50)
        var often = cores[0]
        var once = cores[0]
        for second in stride(from: 0.0, through: 6000, by: 7) {
            _ = often.output(at: at(second))
        }
        let end = at(6000)
        #expect(often.output(at: end).snapshot == once.output(at: end).snapshot)
    }

    @Test("Taps that arrive late rewrite history to match a log built in one go")
    func lateArrivals() {
        var cores = [
            LabourSessionCore(start: ukStart, deviceID: "phone"),
            LabourSessionCore(start: ukStart, deviceID: "watch"),
        ]
        tapRegular(&cores, count: 10, every: 240, duration: 50)
        var phone = cores[0]
        _ = phone.output(at: at(2500))
        phone.merge(cores[1].events)
        var whole = LabourSessionCore(start: ukStart, deviceID: "other", events: cores[0].events + cores[1].events)
        #expect(phone.output(at: at(2600)).snapshot == whole.output(at: at(2600)).snapshot)
        #expect(phone.output(at: at(2600)).state == .callTriage)
    }

    @Test("Catch-up sends only what the other device hasn't seen")
    func catchUp() {
        var cores = [
            LabourSessionCore(start: ukStart, deviceID: "phone"),
            LabourSessionCore(start: ukStart, deviceID: "watch"),
        ]
        tapRegular(&cores, count: 4, every: 240, duration: 50)
        var watch = cores[1]
        let missing = cores[0].events(newerThan: watch.highWaterMarks)
        #expect(missing.count == cores[0].events.count)
        watch.merge(missing)
        #expect(cores[0].events(newerThan: watch.highWaterMarks).isEmpty)
        // Merging the same events again changes nothing.
        #expect(watch.merge(missing).isEmpty)
    }

    @Test("Two labours started at once become one: the earlier wins and the other's taps move over")
    func simultaneousStarts() {
        var watchStart = ukStart
        watchStart.sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID()
        watchStart.startedAt = at(5)
        watchStart.startedBy = "watch"
        var phone = LabourSessionCore(start: ukStart, deviceID: "phone")
        var watch = LabourSessionCore(start: watchStart, deviceID: "watch")
        _ = watch.tap(at: at(10))
        _ = watch.tap(at: at(60))
        #expect(SessionStart.winner(ukStart, watchStart) == ukStart)
        #expect(SessionStart.winner(watchStart, ukStart) == ukStart)
        watch.adopt(SessionStart.winner(watchStart, ukStart))
        #expect(watch.sessionID == ukStart.sessionID)
        #expect(phone.merge(watch.events).count == 2)
        #expect(phone.log.contractions.count == 1)
    }

    @Test("A stale session never takes over a new labour: starts far apart keep the newer one")
    func staleSessionLoses() {
        var stale = ukStart
        stale.sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000003") ?? UUID()
        stale.startedAt = at(-7 * 24 * 3600)
        #expect(!SessionStart.isSameLabour(stale, ukStart))
        #expect(SessionStart.winner(stale, ukStart) == ukStart)
        #expect(SessionStart.winner(ukStart, stale) == ukStart)
        var justUnder = ukStart
        justUnder.sessionID = stale.sessionID
        justUnder.startedAt = at(SessionStart.sameLabourWindowSec)
        #expect(SessionStart.isSameLabour(justUnder, ukStart))
        #expect(SessionStart.winner(justUnder, ukStart) == ukStart)
    }

    @Test("Events from another session are ignored")
    func otherSessionIgnored() {
        var phone = LabourSessionCore(start: ukStart, deviceID: "phone")
        let stray = TapEvent(sessionID: UUID(), kind: .start, at: at(0), deviceID: "watch", lamport: 1)
        #expect(phone.merge([stray]).isEmpty)
        #expect(phone.log.contractions.isEmpty)
    }

    @Test("Sync messages survive the round trip through a WatchConnectivity payload")
    func syncPayload() throws {
        let brief = MissionBrief(
            region: .uk, dueDateText: "2026-12-07", parity: 1, previousFastLabour: false, travelMinutes: 25,
            thresholds: ThresholdTable.builtIn(for: .uk).defaults, motherName: "Sam", unitName: "Northgate",
            triage: try PhoneNumber.parse("01632 960118 option 2", region: .uk).get(), labourWard: nil,
            updatedAt: at(0))
        var core = LabourSessionCore(start: ukStart, deviceID: "watch")
        _ = core.tap(at: at(0))
        let messages: [SyncMessage] = [
            .state(brief: brief, session: ukStart), .state(brief: nil, session: nil), .brief(brief),
            .sessionStarted(ukStart), .events(sessionID: ukStart.sessionID, core.events),
            .marks(sessionID: ukStart.sessionID, ["phone": 3]), .sessionEnded(sessionID: ukStart.sessionID, at: at(9)),
        ]
        for message in messages {
            #expect(SyncMessage(payload: try message.payload()) == message)
        }
        #expect(SyncMessage(payload: ["other": 1]) == nil)
        #expect(brief.dueDate == CalendarDay(year: 2026, month: 12, day: 7))
        #expect(brief.triage?.afterConnecting == "Then press 2")
    }
}

private struct Failure: Error, CustomStringConvertible {
    var description: String
    init(_ description: String) { self.description = description }
}
