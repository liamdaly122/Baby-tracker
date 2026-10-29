import Foundation

/// How a labour session began: who started it, and the profile and thresholds fixed at that moment.
/// Gestation is worked out once here, so the preterm advice can't flip at midnight on 37+0.
public struct SessionStart: Codable, Sendable, Hashable {
    public var sessionID: UUID
    public var startedAt: Date
    /// The device that pressed LAUNCH.
    public var startedBy: String
    public var profile: LabourProfile
    public var thresholds: ThresholdProfile
    /// Goes up each time the phone applies new thresholds to the running labour (a midwife's
    /// advice), so an older copy echoed back by the other device can never undo them.
    public var revision: Int

    public init(
        sessionID: UUID = UUID(),
        startedAt: Date,
        startedBy: String,
        profile: LabourProfile,
        thresholds: ThresholdProfile,
        revision: Int = 0
    ) {
        self.sessionID = sessionID
        self.startedAt = startedAt
        self.startedBy = startedBy
        self.profile = profile
        self.thresholds = thresholds
        self.revision = revision
    }

    /// A start from a build without `revision` is revision 0.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionID = try container.decode(UUID.self, forKey: .sessionID)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        startedBy = try container.decode(String.self, forKey: .startedBy)
        profile = try container.decode(LabourProfile.self, forKey: .profile)
        thresholds = try container.decode(ThresholdProfile.self, forKey: .thresholds)
        revision = try container.decodeIfPresent(Int.self, forKey: .revision) ?? 0
    }

    /// Two starts this close together are one labour started on both devices before they talked.
    /// Further apart, the older one is a session whose end never arrived (the watch was off, say).
    public static let sameLabourWindowSec: TimeInterval = 6 * 3600

    public static func isSameLabour(_ lhs: SessionStart, _ rhs: SessionStart) -> Bool {
        abs(lhs.startedAt.timeIntervalSince(rhs.startedAt)) <= sameLabourWindowSec
    }

    /// Which session both devices keep, whichever of them decides. The same labour started twice:
    /// the earlier start (then the lower ID), and the other's taps move into it with `adopt`. Starts
    /// further apart: the newer one, and the stale one is dropped with its taps, so an old session
    /// can never take over a new labour.
    public static func winner(_ lhs: SessionStart, _ rhs: SessionStart) -> SessionStart {
        if !isSameLabour(lhs, rhs) { return lhs.startedAt > rhs.startedAt ? lhs : rhs }
        if lhs.startedAt != rhs.startedAt { return lhs.startedAt < rhs.startedAt ? lhs : rhs }
        return lhs.sessionID.uuidString < rhs.sessionID.uuidString ? lhs : rhs
    }
}

/// What a tap on the big button did.
public enum TapOutcome: Sendable, Hashable {
    case started(TapEvent)
    case stopped(TapEvent, durationSec: TimeInterval)
    /// The open contraction is past the forgot-to-stop limit: ask before recording anything.
    case askIfEndedOrNew(contractionID: UUID, elapsedSec: TimeInterval)
    case ignoredDoubleTap
}

/// One labour session's log and advice, run the same way on the phone and the watch.
///
/// The advice is a replay of the merged log, so two devices with the same events give the same
/// advice whenever they evaluate. The engine is run at canonical moments only: each tap, and each
/// `nextReviewAt` (the moments the advice could change without a tap), with the log as it stood at
/// that moment. The advice for "now" is one more evaluation from the last canonical snapshot, and is
/// never fed back into the chain. Pure: the clock and the storage belong to the app.
public struct LabourSessionCore: Sendable {
    public private(set) var start: SessionStart
    public let deviceID: String
    /// Every event, in the agreed order.
    public private(set) var events: [TapEvent]
    /// The log with every event applied.
    public private(set) var log: ReducedLog
    private var clock: LamportClock
    private var canonical: Checkpoint?

    private struct Checkpoint: Sendable {
        var at: Date
        var output: EngineOutput
    }

    public init(start: SessionStart, deviceID: String, events: [TapEvent] = []) {
        self.start = start
        self.deviceID = deviceID
        let own = EventMerger.ordered(events.filter { $0.sessionID == start.sessionID })
        self.events = own
        log = EventLog.reduce(own)
        clock = LamportClock(value: own.map(\.lamport).max() ?? 0)
        canonical = nil
    }

    public var sessionID: UUID { start.sessionID }

    /// The thresholds this session runs with, clamped to their safe bounds.
    public var thresholds: ThresholdProfile {
        ThresholdTable.builtIn(for: start.profile.region).clamped(start.thresholds)
    }

    // MARK: Taps

    /// The big button, on either device (`TapPolicy`).
    public mutating func tap(at now: Date) -> TapOutcome {
        switch TapPolicy.action(open: log.openContraction, now: now) {
        case .start:
            return .started(record(.start, at: now))
        case .stop(let id, let time):
            let start = log.openContraction?.start ?? time
            return .stopped(record(.stop, at: time, target: id), durationSec: time.timeIntervalSince(start))
        case .askIfEndedOrNew(let id, let elapsed):
            return .askIfEndedOrNew(contractionID: id, elapsedSec: elapsed)
        case .ignoreDoubleTap:
            return .ignoredDoubleTap
        }
    }

    /// "It just ended": a long contraction is exactly what the unit needs to hear about.
    @discardableResult
    public mutating func endOpenContraction(at now: Date) -> TapEvent? {
        guard let open = log.openContraction else { return nil }
        return record(.stop, at: max(now, open.start), target: open.id)
    }

    /// "This is a new one": starts the next contraction and leaves the forgotten one flagged to fix.
    @discardableResult
    public mutating func startNew(at now: Date) -> TapEvent {
        record(.start, at: now)
    }

    /// Ends a contraction that was never stopped, `seconds` after it started.
    @discardableResult
    public mutating func close(_ contractionID: UUID, afterSeconds seconds: TimeInterval, at now: Date) -> TapEvent? {
        guard let contraction = log.contractions.first(where: { $0.id == contractionID }) else { return nil }
        let end = contraction.start.addingTimeInterval(seconds)
        return record(.editStop, at: now, target: contractionID, payload: TapPayload(time: end))
    }

    /// "They've stopped."
    @discardableResult
    public mutating func markStopped(at now: Date) -> TapEvent {
        record(.eased, at: now)
    }

    /// The answer to "Is she 37 weeks or more?".
    @discardableResult
    public mutating func answerTerm(_ answer: TermAnswer, at now: Date) -> TapEvent {
        record(.termAnswer, at: now, payload: TapPayload(term: answer))
    }

    /// Turns a flag on or off. `happenedAt` says when it actually happened (her waters went 40
    /// minutes ago), if he knows.
    @discardableResult
    public mutating func setRedFlag(_ flag: RedFlag, isOn: Bool, at now: Date, happenedAt: Date? = nil) -> TapEvent {
        record(.redFlag, at: now, payload: TapPayload(time: isOn ? happenedAt : nil, flag: flag, isOn: isOn))
    }

    /// When a flag that's on actually happened, said after the tap. Recorded as a time on its own,
    /// so it can't turn the flag back on if it was turned off on the other device meanwhile. Nil if
    /// the flag isn't on here.
    @discardableResult
    public mutating func setFlagTime(_ flag: RedFlag, happenedAt: Date, at now: Date) -> TapEvent? {
        guard log.redFlags[flag]?.isOn == true else { return nil }
        return record(.redFlag, at: now, payload: TapPayload(time: happenedAt, flag: flag))
    }

    /// "I've called them": what they said, and the advice he called about, so anything new later
    /// means calling back. Every flag and profile reason is kept, not just the top level's: the
    /// call script he read out lists them all.
    @discardableResult
    public mutating func logCall(_ outcome: CallOutcome, at now: Date) -> TapEvent {
        let shown = output(at: now)
        let flagReasons = GoNoGoEngine.flagReasons(engineInput(at: now, previous: nil))
        var reasons: [ReasonCode] = []
        for reason in shown.reasons + flagReasons + shown.contractionAdvice.reasons where !reasons.contains(reason) {
            reasons.append(reason)
        }
        let note = CallNote(
            outcome: outcome, state: shown.state, contractionState: shown.contractionAdvice.state, reasons: reasons,
            thresholds: shown.thresholds)
        return record(.called, at: now, payload: TapPayload(call: note))
    }

    /// How strong a contraction felt.
    @discardableResult
    public mutating func rate(_ contractionID: UUID, _ strength: ContractionStrength, at now: Date) -> TapEvent {
        record(.strength, at: now, target: contractionID, payload: TapPayload(strength: strength))
    }

    /// When her waters went, if they're broken: for the 24-hour reminder and the call script.
    public var watersBrokeAt: Date? {
        guard let status = log.redFlags[.watersBroken], status.isOn else { return nil }
        return status.happenedAt ?? status.changedAt
    }

    /// Records any event from this device. Ticks the Lamport clock.
    @discardableResult
    public mutating func record(
        _ kind: TapEventKind,
        at time: Date,
        target: UUID? = nil,
        payload: TapPayload? = nil
    ) -> TapEvent {
        let event = TapEvent(
            sessionID: start.sessionID,
            kind: kind,
            at: time,
            deviceID: deviceID,
            lamport: clock.tick(),
            target: target,
            payload: payload
        )
        apply([event])
        return event
    }

    // MARK: Sync

    /// Adds events from the other device. Returns the ones that were new.
    @discardableResult
    public mutating func merge(_ remote: [TapEvent]) -> [TapEvent] {
        let known = Set(events.map(\.id))
        let fresh = remote.filter { $0.sessionID == start.sessionID && !known.contains($0.id) }
        guard !fresh.isEmpty else { return [] }
        for event in fresh {
            clock.observe(event.lamport)
        }
        apply(fresh)
        return fresh
    }

    /// The events the other device hasn't seen, given its high-water marks.
    public func events(newerThan marks: [String: UInt64]) -> [TapEvent] {
        EventMerger.events(events, newerThan: marks)
    }

    public var highWaterMarks: [String: UInt64] {
        EventMerger.highWaterMarks(events)
    }

    /// New thresholds for the running labour (a midwife's advice on the phone). The advice is
    /// replayed with them, and the other device gets the same start through sync. Only a newer
    /// revision is taken, so a copy echoed back late (a crossing catch-up, or the context the
    /// watch set at launch) can't undo them. Only the thresholds are taken: the profile is fixed
    /// at launch, and an echo from a build that doesn't know a newer field would otherwise clear it.
    /// The other way round, a watch upgraded mid-labour keeps the profile it stored at launch.
    public mutating func update(_ newStart: SessionStart) {
        guard newStart.sessionID == start.sessionID, newStart.revision > start.revision else { return }
        start.thresholds = newStart.thresholds
        start.revision = newStart.revision
        canonical = nil
    }

    /// Moves this device's events into the session that won (`SessionStart.winner`), so a labour
    /// started on both devices at once becomes one log.
    public mutating func adopt(_ winner: SessionStart) {
        guard winner.sessionID != start.sessionID else { return }
        let moved = events.map { event -> TapEvent in
            var copy = event
            copy.sessionID = winner.sessionID
            return copy
        }
        start = winner
        events = EventMerger.ordered(moved)
        log = EventLog.reduce(events)
        canonical = nil
    }

    private mutating func apply(_ new: [TapEvent]) {
        events = EventMerger.ordered(events + new)
        log = EventLog.reduce(events)
        // An event from before the last canonical moment changes history from that moment on.
        if let checkpoint = canonical, new.contains(where: { $0.at < checkpoint.at }) {
            canonical = nil
        }
    }

    // MARK: Advice

    /// The advice at `now`. Walks the canonical moments up to `now` first.
    public mutating func output(at now: Date) -> EngineOutput {
        advance(to: now)
        return evaluate(at: now, previous: canonical?.output.snapshot)
    }

    private mutating func advance(to now: Date) {
        let times = events.map(\.at).sorted()
        guard let first = times.first, first <= now else {
            canonical = nil
            return
        }
        if canonical == nil {
            canonical = Checkpoint(at: first, output: evaluate(at: first, previous: nil))
        }
        // Bounded so a damaged log can't spin: a labour has far fewer moments than this.
        for _ in 0..<20_000 {
            guard let checkpoint = canonical else { return }
            let nextEvent = times.first { $0 > checkpoint.at }
            let candidates = [nextEvent, checkpoint.output.nextReviewAt].compactMap { $0 }.filter { $0 > checkpoint.at }
            guard let next = candidates.min(), next <= now else { return }
            canonical = Checkpoint(at: next, output: evaluate(at: next, previous: checkpoint.output.snapshot))
        }
    }

    /// The engine input at `moment`, with the log as it stood then. For planning alerts.
    public func engineInput(at moment: Date, previous: EngineStateSnapshot?) -> EngineInput {
        EngineInput(
            log: EventLog.reduce(events.filter { $0.at <= moment }),
            profile: start.profile,
            thresholds: start.thresholds,
            previous: previous,
            now: moment
        )
    }

    private func evaluate(at moment: Date, previous: EngineStateSnapshot?) -> EngineOutput {
        GoNoGoEngine.evaluate(engineInput(at: moment, previous: previous))
    }
}
