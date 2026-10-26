import Foundation
import Testing

@testable import MissionCore

/// Builds tap events for one session, ticking a Lamport clock per device like the apps will.
private struct Recorder {
    let session = UUID()
    var clocks: [String: LamportClock] = [:]
    var events: [TapEvent] = []

    @discardableResult
    mutating func tap(
        _ kind: TapEventKind,
        _ seconds: Double,
        device: String = "phone",
        target: UUID? = nil,
        payload: TapPayload? = nil
    ) -> TapEvent {
        var clock = clocks[device] ?? LamportClock()
        let event = TapEvent(
            sessionID: session,
            kind: kind,
            at: at(seconds),
            deviceID: device,
            lamport: clock.tick(),
            target: target,
            payload: payload
        )
        clocks[device] = clock
        events.append(event)
        return event
    }

    /// Simulates a device receiving another's events: its clock jumps past them.
    mutating func sync(_ device: String) {
        var clock = clocks[device] ?? LamportClock()
        for event in events {
            clock.observe(event.lamport)
        }
        clocks[device] = clock
    }

    /// Start and stop, returning the contraction ID (the start event's ID).
    @discardableResult
    mutating func contraction(_ start: Double, _ duration: Double, device: String = "phone") -> UUID {
        let started = tap(.start, start, device: device)
        tap(.stop, start + duration, device: device, target: started.id)
        return started.id
    }
}

@Suite("Event log")
struct EventLogTests {
    @Test("Start and stop make a contraction whose ID is the start event's ID")
    func startStop() {
        var recorder = Recorder()
        let id = recorder.contraction(0, 50)
        let log = EventLog.reduce(recorder.events)
        #expect(log.contractions == [Contraction(id: id, start: at(0), end: at(50))])
        #expect(log.openContraction == nil)
    }

    @Test("A stop without a target ends the latest open contraction")
    func untargetedStop() {
        var recorder = Recorder()
        let started = recorder.tap(.start, 0)
        recorder.tap(.stop, 45)
        #expect(
            EventLog.reduce(recorder.events).contractions == [Contraction(id: started.id, start: at(0), end: at(45))])
    }

    @Test("Phone and watch starting the same contraction within 20 s are coalesced")
    func coalesce() {
        var recorder = Recorder()
        let phone = recorder.tap(.start, 5, device: "phone")
        let watch = recorder.tap(.start, 0, device: "watch")
        recorder.tap(.stop, 60, device: "watch", target: watch.id)
        let log = EventLog.reduce(recorder.events)
        #expect(log.contractions.count == 1)
        #expect(log.contractions.first?.start == at(0))
        #expect(log.contractions.first?.end == at(60))
        #expect([phone.id, watch.id].contains(log.contractions.first?.id ?? UUID()))
    }

    @Test("Starts more than 20 s apart, or from the same device, are not coalesced")
    func noCoalesce() {
        var apart = Recorder()
        apart.tap(.start, 0, device: "phone")
        apart.tap(.start, 30, device: "watch")
        #expect(EventLog.reduce(apart.events).contractions.count == 2)

        var sameDevice = Recorder()
        sameDevice.tap(.start, 0)
        sameDevice.tap(.start, 5)
        let log = EventLog.reduce(sameDevice.events)
        #expect(log.contractions.count == 2)
        // The earlier one never got a stop, so the engine will flag it for editing.
        #expect(log.contractions.first?.end == nil)
    }

    @Test("Edits are last-writer-wins by Lamport order, across devices")
    func lastWriterWins() {
        var recorder = Recorder()
        let id = recorder.contraction(0, 400)
        recorder.sync("watch")
        recorder.tap(.editStop, 500, device: "watch", target: id, payload: TapPayload(time: at(60)))
        recorder.sync("phone")
        recorder.tap(.editStop, 510, device: "phone", target: id, payload: TapPayload(time: at(55)))
        #expect(EventLog.reduce(recorder.events).contractions.first?.end == at(55))
    }

    @Test("Undo cancels an event from the other device")
    func undoAcrossDevices() {
        var recorder = Recorder()
        recorder.contraction(0, 50)
        let misTap = recorder.tap(.start, 100, device: "watch")
        recorder.sync("phone")
        recorder.tap(.undo, 105, device: "phone", target: misTap.id)
        let log = EventLog.reduce(recorder.events)
        #expect(log.contractions.count == 1)
        #expect(log.openContraction == nil)
    }

    @Test("Undoing an undo restores the original event")
    func undoUndo() {
        var recorder = Recorder()
        let id = recorder.contraction(0, 50)
        let delete = recorder.tap(.delete, 100, target: id)
        let undo = recorder.tap(.undo, 101, target: delete.id)
        #expect(EventLog.reduce(recorder.events).contractions.count == 1)
        recorder.tap(.undo, 102, target: undo.id)
        #expect(EventLog.reduce(recorder.events).contractions.isEmpty)
    }

    @Test("Delete removes a contraction and later edits to it are ignored")
    func delete() {
        var recorder = Recorder()
        let first = recorder.contraction(0, 50)
        let second = recorder.contraction(300, 50)
        recorder.tap(.delete, 400, target: first)
        recorder.tap(.editStop, 410, target: first, payload: TapPayload(time: at(90)))
        #expect(EventLog.reduce(recorder.events).contractions.map(\.id) == [second])
    }

    @Test("Merge folds a contraction into the one before it")
    func merge() {
        var recorder = Recorder()
        let first = recorder.contraction(0, 20)
        let second = recorder.contraction(25, 40)
        recorder.tap(.merge, 100, target: second)
        // A later edit aimed at the merged piece lands on the combined contraction.
        recorder.tap(.editStop, 110, target: second, payload: TapPayload(time: at(70)))
        let log = EventLog.reduce(recorder.events)
        #expect(log.contractions == [Contraction(id: first, start: at(0), end: at(70))])
    }

    @Test("Merging an open contraction leaves the combined one open")
    func mergeOpen() {
        var recorder = Recorder()
        let first = recorder.contraction(0, 20)
        let open = recorder.tap(.start, 25)
        recorder.tap(.merge, 30, target: open.id)
        #expect(EventLog.reduce(recorder.events).openContraction == Contraction(id: first, start: at(0), end: nil))
    }

    @Test("Red flags toggle on and off, and undo restores the previous setting")
    func redFlags() {
        var recorder = Recorder()
        recorder.tap(.redFlag, 10, payload: TapPayload(flag: .watersBroken, isOn: true))
        #expect(EventLog.reduce(recorder.events).activeRedFlags == [.watersBroken])
        let off = recorder.tap(.redFlag, 20, payload: TapPayload(flag: .watersBroken, isOn: false))
        #expect(EventLog.reduce(recorder.events).activeRedFlags.isEmpty)
        recorder.tap(.undo, 21, target: off.id)
        #expect(EventLog.reduce(recorder.events).activeRedFlags == [.watersBroken])
    }

    @Test("Reduce is idempotent and ignores arrival order")
    func idempotentAndOrderFree() {
        var rng = SeededGenerator(seed: 7)
        for _ in 0..<200 {
            let events = randomSession(using: &rng)
            let expected = EventLog.reduce(events)
            #expect(EventLog.reduce(events + events) == expected)
            #expect(EventLog.reduce(events.shuffled(using: &rng)) == expected)
        }
    }

    @Test("An edited log gives the same advice as a fresh log with the right times")
    func editedMatchesFresh() {
        var edited = Recorder()
        var fresh = Recorder()
        var startIDs: [UUID] = []
        for index in 0..<17 {
            let start = Double(index) * 240
            let event = edited.tap(.start, start)
            startIDs.append(event.id)
            // The partner forgot to stop the 10th contraction until 5 minutes later.
            if index == 9 {
                edited.tap(.stop, start + 300, target: event.id)
                edited.tap(.editStop, start + 400, target: event.id, payload: TapPayload(time: at(start + 50)))
            } else {
                edited.tap(.stop, start + 50, target: event.id)
            }
        }
        for (index, id) in startIDs.enumerated() {
            let start = Double(index) * 240
            fresh.events.append(
                TapEvent(
                    id: id, sessionID: fresh.session, kind: .start, at: at(start), deviceID: "phone",
                    lamport: UInt64(index * 2 + 1)))
            fresh.events.append(
                TapEvent(
                    sessionID: fresh.session, kind: .stop, at: at(start + 50), deviceID: "phone",
                    lamport: UInt64(index * 2 + 2), target: id))
        }
        let editedLog = EventLog.reduce(edited.events)
        let freshLog = EventLog.reduce(fresh.events)
        #expect(editedLog.contractions == freshLog.contractions)
        #expect(
            GoNoGoEngine.evaluate(ukInput(editedLog.contractions, now: 3900))
                == GoNoGoEngine.evaluate(ukInput(freshLog.contractions, now: 3900))
        )
    }

    // MARK: Merger

    @Test("Merging logs deduplicates and orders events")
    func mergeLogs() {
        var recorder = Recorder()
        recorder.contraction(0, 50, device: "phone")
        recorder.contraction(300, 50, device: "watch")
        let phoneCopy = Array(recorder.events.prefix(3))
        let watchCopy = Array(recorder.events.suffix(3))
        let merged = EventMerger.merge(phoneCopy, watchCopy)
        #expect(merged.count == 4)
        #expect(merged == EventMerger.ordered(recorder.events))
    }

    @Test("High-water marks tell a peer exactly which events it's missing")
    func highWaterMarks() {
        var recorder = Recorder()
        recorder.contraction(0, 50, device: "phone")  // phone lamport 1, 2
        recorder.contraction(300, 50, device: "watch")  // watch lamport 1, 2
        let watchHasSeen = EventMerger.highWaterMarks(recorder.events.filter { $0.deviceID == "watch" })
        #expect(watchHasSeen == ["watch": 2])
        recorder.contraction(600, 50, device: "phone")  // phone lamport 3, 4
        let toSend = EventMerger.events(recorder.events.filter { $0.deviceID == "phone" }, newerThan: watchHasSeen)
        #expect(toSend.count == 4)
        #expect(EventMerger.events(recorder.events, newerThan: EventMerger.highWaterMarks(recorder.events)).isEmpty)
    }

    @Test("Both devices converge after exchanging what the other is missing")
    func convergence() {
        var rng = SeededGenerator(seed: 99)
        for _ in 0..<100 {
            let all = randomSession(using: &rng)
            var phone = all.filter { _ in Bool.random(using: &rng) }
            var watch = all.filter { _ in Bool.random(using: &rng) }
            // Whatever is missing from both is delivered later by the queued transfers.
            let fromPhone = EventMerger.events(phone, newerThan: EventMerger.highWaterMarks(watch))
            let fromWatch = EventMerger.events(watch, newerThan: EventMerger.highWaterMarks(phone))
            phone = EventMerger.merge(phone, fromWatch)
            watch = EventMerger.merge(watch, fromPhone)
            let rest = all.filter { event in !phone.contains(event) || !watch.contains(event) }
            phone = EventMerger.merge(phone, rest)
            watch = EventMerger.merge(watch, rest)
            #expect(EventLog.reduce(phone) == EventLog.reduce(watch))
            #expect(EventLog.reduce(phone) == EventLog.reduce(all))
        }
    }

    private func randomSession(using rng: inout SeededGenerator) -> [TapEvent] {
        var recorder = Recorder()
        var ids: [UUID] = []
        var cursor = 0.0
        for _ in 0..<Int.random(in: 1...30, using: &rng) {
            let device = Bool.random(using: &rng) ? "phone" : "watch"
            cursor += Double.random(in: 5...400, using: &rng)
            if Int.random(in: 0..<4, using: &rng) == 0 {
                recorder.sync(device)
            }
            switch Int.random(in: 0..<10, using: &rng) {
            case 0..<4:
                ids.append(recorder.tap(.start, cursor, device: device).id)
            case 4..<7:
                recorder.tap(.stop, cursor, device: device, target: ids.randomElement(using: &rng))
            case 7:
                recorder.tap(
                    .editStart, cursor, device: device, target: ids.randomElement(using: &rng),
                    payload: TapPayload(time: at(cursor - 30)))
            case 8:
                let kinds: [TapEventKind] = [.delete, .merge, .undo]
                let kind = kinds.randomElement(using: &rng) ?? .delete
                let target =
                    kind == .undo ? recorder.events.randomElement(using: &rng)?.id : ids.randomElement(using: &rng)
                recorder.tap(kind, cursor, device: device, target: target)
            default:
                let flag = RedFlag.allCases.randomElement(using: &rng)
                recorder.tap(
                    .redFlag, cursor, device: device, payload: TapPayload(flag: flag, isOn: Bool.random(using: &rng)))
            }
        }
        return recorder.events
    }
}
