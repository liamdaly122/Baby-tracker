import Foundation
import MissionCore
import Observation
import SwiftData

/// Receives every engine evaluation so it can post and schedule notifications.
@MainActor
protocol LabourAlerting: AnyObject {
    func engineDidUpdate(sessionID: UUID, previous: EngineStateSnapshot?, input: EngineInput, output: EngineOutput)
    func sessionDidEnd(sessionID: UUID)
}

/// Sends what happened here to the watch.
@MainActor
protocol LabourSyncing: AnyObject {
    func sessionDidStart(_ start: SessionStart)
    func didRecord(_ events: [TapEvent], sessionID: UUID)
    func sessionDidEnd(sessionID: UUID, at date: Date)
}

/// Runs a labour session on the phone. The log and the advice live in `LabourSessionCore`, shared
/// with the watch; this adds storage, undo, the questions the app asks instead of guessing, and
/// the hooks for alerts and sync. Everything is saved on every tap, so the timer survives the app
/// being killed.
@MainActor
@Observable
final class LabourSessionModel {
    /// How long the undo chip stays up after a tap.
    static let undoWindow: TimeInterval = 10

    struct UndoableAction: Equatable {
        var event: TapEvent
        var label: String
        var expiresAt: Date
    }

    /// A question on the timer that has to be answered before anything is recorded.
    enum Prompt: Equatable {
        /// The open contraction is past 5 minutes: did it just end, or is this a new one?
        case endedOrNew(elapsedSec: TimeInterval)
        /// He started a new one without stopping the last: how long did that one last?
        case fixForgotten(contractionID: UUID, elapsedSec: TimeInterval)
    }

    private let context: ModelContext
    private let now: () -> Date
    let deviceID: String
    weak var alerting: LabourAlerting?
    weak var sync: LabourSyncing?
    /// Her details for the triage card. Set by the app from `MissionProfile`.
    var detailsProvider: (Int?) -> TriageDetails = { TriageDetails(gestationalAge: $0.map(GestationalAge.init)) }

    private(set) var session: LabourSessionRecord?
    private(set) var core: LabourSessionCore?
    private(set) var output: EngineOutput?
    private(set) var undoable: UndoableAction?
    var prompt: Prompt?
    /// A short line for the undo area, such as "Ignored a double tap".
    private(set) var notice: (text: String, until: Date)?
    /// The last start he said was still coming, so the "are they still coming?" question goes away.
    var quietAcknowledgedFor: Date?

    init(context: ModelContext, deviceID: String, now: @escaping () -> Date = Date.init) {
        self.context = context
        self.deviceID = deviceID
        self.now = now
    }

    var isActive: Bool { core != nil }
    var sessionID: UUID? { core?.sessionID }
    var start: SessionStart? { core?.start }

    /// The thresholds in use, clamped. Copy and alerts use these.
    var thresholds: ThresholdProfile {
        output?.thresholds ?? core?.thresholds ?? ThresholdTable.builtIn(for: .uk).defaults
    }

    var region: ContentRegion { core?.start.profile.region ?? .uk }
    var log: ReducedLog { core?.log ?? ReducedLog() }

    /// The contraction being timed right now, if the latest one hasn't been stopped.
    var openContraction: Contraction? { log.openContraction }

    /// No due date, and nobody has said she's 37 weeks or more.
    var needsTermAnswer: Bool {
        guard let start = core?.start, start.profile.gestationalAgeDays == nil else { return false }
        return log.termAnswer != .term && log.termAnswer != .preterm
    }

    // MARK: Session

    /// Loads the unfinished session, if there is one. `legacyStart` builds a start for a session
    /// saved before starts were stored.
    func loadActiveSession(legacyStart: (LabourSessionRecord) -> SessionStart) {
        var descriptor = FetchDescriptor<LabourSessionRecord>(
            predicate: #Predicate { $0.endedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let record = try? context.fetch(descriptor).first else { return }
        let start = record.start ?? legacyStart(record)
        if record.start == nil {
            record.start = start
            save()
        }
        session = record
        core = LabourSessionCore(start: start, deviceID: deviceID, events: storedEvents(for: start.sessionID))
        refresh()
    }

    func start(_ start: SessionStart) {
        guard core == nil else { return }
        let record = LabourSessionRecord(start: start)
        context.insert(record)
        save()
        session = record
        core = LabourSessionCore(start: start, deviceID: deviceID)
        sync?.sessionDidStart(start)
        refresh()
    }

    func end() {
        guard let session, let id = sessionID else { return }
        let moment = now()
        session.endedAt = moment
        save()
        self.session = nil
        core = nil
        output = nil
        undoable = nil
        prompt = nil
        alerting?.sessionDidEnd(sessionID: id)
        sync?.sessionDidEnd(sessionID: id, at: moment)
    }

    /// Applies new thresholds (after a call with the midwife) to the running labour.
    func applyThresholds(_ thresholds: ThresholdProfile) {
        guard var start = core?.start else { return }
        start.thresholds = thresholds
        core?.update(start)
        session?.start = start
        save()
        sync?.sessionDidStart(start)
        refresh()
    }

    // MARK: Taps

    /// The big button, through `TapPolicy`: the same rule as the watch.
    func tap() {
        guard var core else { return }
        let outcome = core.tap(at: now())
        self.core = core
        switch outcome {
        case .started(let event):
            prompt = nil
            stored([event], undoLabel: "start")
        case .stopped(let event, _):
            stored([event], undoLabel: "stop")
        case .askIfEndedOrNew(_, let elapsed):
            prompt = .endedOrNew(elapsedSec: elapsed)
        case .ignoredDoubleTap:
            notice = ("Ignored a double tap", now().addingTimeInterval(4))
        }
    }

    /// "It just ended."
    func endedJustNow() {
        prompt = nil
        perform("stop") { $0.endOpenContraction(at: $1) }
    }

    /// "This is a new one": start it, then ask how long the forgotten one lasted.
    func newOneStarted() {
        guard let open = openContraction else {
            prompt = nil
            return
        }
        let elapsed = now().timeIntervalSince(open.start)
        perform("start") { $0.startNew(at: $1) }
        prompt = .fixForgotten(contractionID: open.id, elapsedSec: elapsed)
    }

    func close(_ contractionID: UUID, afterSeconds seconds: TimeInterval) {
        if case .fixForgotten(let id, _) = prompt, id == contractionID {
            prompt = nil
        }
        perform("edit") { $0.close(contractionID, afterSeconds: seconds, at: $1) }
    }

    func markStopped() {
        quietAcknowledgedFor = nil
        perform("they've stopped") { $0.markStopped(at: $1) }
    }

    func answerTerm(_ answer: TermAnswer) {
        perform("answer") { $0.answerTerm(answer, at: $1) }
    }

    func setRedFlag(_ flag: RedFlag, isOn: Bool) {
        perform(isOn ? "flag" : "flag off") { $0.setRedFlag(flag, isOn: isOn, at: $1) }
    }

    func logMovement() {
        perform("movement") { $0.record(.movement, at: $1) }
    }

    func undo() {
        guard let undoable, undoable.expiresAt > now() else {
            self.undoable = nil
            return
        }
        self.undoable = nil
        perform(nil) { $0.record(.undo, at: $1, target: undoable.event.id) }
    }

    func moveStart(of contraction: Contraction, byMinutes minutes: Int) {
        let time = contraction.start.addingTimeInterval(Double(minutes) * 60)
        perform("edit") { $0.record(.editStart, at: $1, target: contraction.id, payload: TapPayload(time: time)) }
    }

    func moveEnd(of contraction: Contraction, byMinutes minutes: Int) {
        guard let end = contraction.end else { return }
        let time = end.addingTimeInterval(Double(minutes) * 60)
        perform("edit") { $0.record(.editStop, at: $1, target: contraction.id, payload: TapPayload(time: time)) }
    }

    func delete(_ contraction: Contraction) {
        perform("delete") { $0.record(.delete, at: $1, target: contraction.id) }
    }

    func mergeWithPrevious(_ contraction: Contraction) {
        perform("merge") { $0.record(.merge, at: $1, target: contraction.id) }
    }

    func canMergeWithPrevious(_ contraction: Contraction) -> Bool {
        log.contractions.contains { ContractionMetrics.chronological($0, contraction) }
    }

    /// "Still coming": hides the question until the log goes quiet again.
    func acknowledgeQuiet() {
        quietAcknowledgedFor = output?.metrics.lastStart
    }

    // MARK: Sync

    /// Events from the watch.
    func receive(_ events: [TapEvent]) {
        guard var core else { return }
        let fresh = core.merge(events)
        self.core = core
        guard !fresh.isEmpty else { return }
        persist(fresh)
        refresh()
    }

    /// A session the watch started or updated. The earlier of two simultaneous starts wins.
    func receive(_ remote: SessionStart) {
        guard var current = core else {
            start(remote)
            return
        }
        if remote.sessionID == current.sessionID {
            current.update(remote)
            core = current
            session?.start = remote
            save()
            refresh()
            return
        }
        let winner = SessionStart.winner(current.start, remote)
        guard winner == remote else { return }
        alerting?.sessionDidEnd(sessionID: current.sessionID)
        guard SessionStart.isSameLabour(current.start, remote) else {
            // This phone's session is the stale one: close it and take the watch's.
            session?.endedAt = now()
            save()
            session = nil
            core = nil
            prompt = nil
            undoable = nil
            start(remote)
            return
        }
        // The watch started the same labour first: move this device's taps into its session.
        current.adopt(remote)
        core = current
        session?.endedAt = remote.startedAt
        let record = LabourSessionRecord(start: remote)
        context.insert(record)
        session = record
        persist(current.events)
        sync?.didRecord(current.events, sessionID: remote.sessionID)
        refresh()
    }

    /// True if this phone has already ended that session, so a late message can't revive it.
    func wasEnded(_ sessionID: UUID) -> Bool {
        let records =
            (try? context.fetch(FetchDescriptor<LabourSessionRecord>(predicate: #Predicate { $0.id == sessionID })))
            ?? []
        return records.contains { $0.endedAt != nil }
    }

    /// The watch ended the session (or the phone did, on another install).
    func receiveEnd(sessionID: UUID) {
        guard sessionID == self.sessionID else { return }
        end()
    }

    // MARK: Engine

    /// Re-runs the engine at the current time. Called after every tap, on a timer while the
    /// app is open, and when it comes back to the foreground.
    func refresh() {
        guard var core, let session else {
            output = nil
            return
        }
        let moment = now()
        let result = core.output(at: moment)
        self.core = core
        output = result
        if let undoable, undoable.expiresAt <= moment {
            self.undoable = nil
        }
        if let notice, notice.until <= moment {
            self.notice = nil
        }
        let previous = session.alertedSnapshot
        alerting?.engineDidUpdate(
            sessionID: core.sessionID,
            previous: previous,
            input: core.engineInput(at: moment, previous: previous),
            output: result
        )
        if previous?.state != result.snapshot.state || previous?.reasonCodes != result.snapshot.reasonCodes {
            session.alertedSnapshot = result.snapshot
            save()
        }
    }

    func triageScript(calendar: Calendar = .current) -> TriageScript? {
        guard let output, let core else { return nil }
        return TriageScript.build(
            TriageScript.Inputs(
                details: detailsProvider(core.start.profile.gestationalAgeDays),
                output: output,
                log: core.log,
                now: now(),
                calendar: calendar
            )
        )
    }

    // MARK: Storage

    private func perform(_ undoLabel: String?, _ change: (inout LabourSessionCore, Date) -> TapEvent?) {
        guard var core else { return }
        let event = change(&core, now())
        self.core = core
        if let event {
            stored([event], undoLabel: undoLabel)
        }
    }

    private func stored(_ events: [TapEvent], undoLabel: String?) {
        guard let id = sessionID else { return }
        persist(events)
        sync?.didRecord(events, sessionID: id)
        if let undoLabel, let event = events.last {
            undoable = UndoableAction(
                event: event, label: undoLabel, expiresAt: event.at.addingTimeInterval(Self.undoWindow))
        }
        refresh()
    }

    private func persist(_ events: [TapEvent]) {
        for event in events {
            if let record = try? TapEventRecord(event: event) {
                context.insert(record)
            }
        }
        save()
    }

    private func storedEvents(for sessionID: UUID) -> [TapEvent] {
        let records =
            (try? context.fetch(
                FetchDescriptor<TapEventRecord>(predicate: #Predicate { $0.sessionID == sessionID }))) ?? []
        return records.compactMap(\.event)
    }

    private func save() {
        try? context.save()
    }

    #if DEBUG
        /// A finished contraction at an earlier time, for demo data only.
        func recordDemoContraction(start: Date, lasting seconds: TimeInterval) {
            guard var core, let id = sessionID else { return }
            let started = core.record(.start, at: start)
            let stopped = core.record(.stop, at: start.addingTimeInterval(seconds), target: started.id)
            self.core = core
            persist([started, stopped])
            sync?.didRecord([started, stopped], sessionID: id)
        }
    #endif
}
