import Foundation
import MissionCore
import Observation
import SwiftData

/// Receives every engine evaluation so it can post and schedule notifications.
@MainActor
protocol LabourAlerting: AnyObject {
    func engineDidUpdate(previousState: LabourState?, input: EngineInput, output: EngineOutput)
    func sessionDidEnd()
}

/// The engine inputs that come from the pregnancy profile, worked out at a moment.
struct LabourContext {
    var profile: LabourProfile
    var triage: TriageDetails
}

/// Runs a labour session: records taps as events, rebuilds contractions from them, runs the
/// go/no-go engine and keeps its snapshot. Everything is saved on every tap, so the timer
/// survives the app being killed.
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

    private let context: ModelContext
    private let now: () -> Date
    let deviceID: String
    weak var alerting: LabourAlerting?
    /// Supplies the profile at a moment. Set by the app from `MissionProfile`.
    var contextProvider: (Date) -> LabourContext

    private(set) var session: LabourSessionRecord?
    private(set) var events: [TapEvent] = []
    private(set) var log = ReducedLog(contractions: [], redFlags: [:])
    private(set) var output: EngineOutput?
    private(set) var lastInput: EngineInput?
    private(set) var undoable: UndoableAction?
    private var clock = LamportClock()

    init(
        context: ModelContext,
        deviceID: String,
        now: @escaping () -> Date = Date.init,
        contextProvider: @escaping (Date) -> LabourContext
    ) {
        self.context = context
        self.deviceID = deviceID
        self.now = now
        self.contextProvider = contextProvider
        loadActiveSession()
    }

    var isActive: Bool { session != nil }

    var thresholds: ThresholdProfile {
        session?.thresholds ?? ThresholdTable.builtIn(for: session?.region ?? .uk).defaults
    }

    var region: ContentRegion { session?.region ?? .uk }

    /// The contraction being timed right now, if the latest one hasn't been stopped.
    var openContraction: Contraction? {
        guard let last = log.contractions.last, last.end == nil else { return nil }
        return last
    }

    // MARK: Session

    func loadActiveSession() {
        var descriptor = FetchDescriptor<LabourSessionRecord>(
            predicate: #Predicate { $0.endedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        session = try? context.fetch(descriptor).first
        reloadEvents()
        refresh()
    }

    func start(region: ContentRegion, thresholds: ThresholdProfile) {
        guard session == nil else { return }
        let record = LabourSessionRecord(
            startedAt: now(), ownerDeviceID: deviceID, region: region, thresholds: thresholds)
        context.insert(record)
        save()
        session = record
        reloadEvents()
        refresh()
    }

    func end() {
        guard let session else { return }
        session.endedAt = now()
        save()
        self.session = nil
        events = []
        log = ReducedLog(contractions: [], redFlags: [:])
        output = nil
        lastInput = nil
        undoable = nil
        alerting?.sessionDidEnd()
    }

    /// Applies new thresholds (e.g. after a call with the midwife) to the running labour.
    func applyThresholds(_ thresholds: ThresholdProfile) {
        session?.thresholds = thresholds
        save()
        refresh()
    }

    // MARK: Taps

    func toggleContraction() {
        if let open = openContraction {
            record(.stop, target: open.id, label: "stop")
        } else {
            record(.start, label: "start")
        }
    }

    func undo() {
        guard let undoable, undoable.expiresAt > now() else {
            self.undoable = nil
            return
        }
        self.undoable = nil
        record(.undo, target: undoable.event.id, label: nil)
    }

    func moveStart(of contraction: Contraction, byMinutes minutes: Int) {
        let time = contraction.start.addingTimeInterval(Double(minutes) * 60)
        record(.editStart, target: contraction.id, payload: TapPayload(time: time), label: "edit")
    }

    func moveEnd(of contraction: Contraction, byMinutes minutes: Int) {
        guard let end = contraction.end else { return }
        let time = end.addingTimeInterval(Double(minutes) * 60)
        record(.editStop, target: contraction.id, payload: TapPayload(time: time), label: "edit")
    }

    /// Ends a contraction that was never stopped, at its start plus `duration`.
    func close(_ contraction: Contraction, afterSeconds duration: TimeInterval) {
        let time = contraction.start.addingTimeInterval(duration)
        record(.editStop, target: contraction.id, payload: TapPayload(time: time), label: "edit")
    }

    func delete(_ contraction: Contraction) {
        record(.delete, target: contraction.id, label: "delete")
    }

    func mergeWithPrevious(_ contraction: Contraction) {
        record(.merge, target: contraction.id, label: "merge")
    }

    func setRedFlag(_ flag: RedFlag, isOn: Bool) {
        record(.redFlag, payload: TapPayload(flag: flag, isOn: isOn), label: isOn ? "flag" : "flag off")
    }

    func logMovement() {
        record(.movement, label: "movement")
    }

    func canMergeWithPrevious(_ contraction: Contraction) -> Bool {
        log.contractions.contains { ContractionMetrics.chronological($0, contraction) }
    }

    // MARK: Engine

    /// Re-runs the engine at the current time. Called after every tap, on a timer while the
    /// app is open, and when it comes back to the foreground.
    func refresh() {
        guard let session else {
            output = nil
            lastInput = nil
            return
        }
        let moment = now()
        let labourContext = contextProvider(moment)
        let previous = session.engineSnapshot
        let input = EngineInput(
            contractions: log.contractions,
            redFlags: log.activeRedFlags,
            profile: labourContext.profile,
            thresholds: thresholds,
            previous: previous,
            now: moment
        )
        let result = GoNoGoEngine.evaluate(input)
        let previousState = output?.state ?? previous?.state
        output = result
        lastInput = input
        if result.snapshot != previous {
            session.engineSnapshot = result.snapshot
            save()
        }
        if let undoable, undoable.expiresAt <= moment {
            self.undoable = nil
        }
        alerting?.engineDidUpdate(previousState: previousState, input: input, output: result)
    }

    func triageScript(calendar: Calendar = .current) -> TriageScript? {
        guard let output else { return nil }
        let moment = now()
        return TriageScript.build(
            details: contextProvider(moment).triage,
            output: output,
            log: log,
            thresholds: thresholds,
            now: moment,
            calendar: calendar
        )
    }

    // MARK: Storage

    @discardableResult
    private func record(
        _ kind: TapEventKind,
        target: UUID? = nil,
        payload: TapPayload? = nil,
        label: String?,
        at time: Date? = nil,
        evaluate: Bool = true
    ) -> TapEvent? {
        guard let session else { return nil }
        let event = TapEvent(
            sessionID: session.id,
            kind: kind,
            at: time ?? now(),
            deviceID: deviceID,
            lamport: clock.tick(),
            target: target,
            payload: payload
        )
        do {
            context.insert(try TapEventRecord(event: event))
            save()
        } catch {
            return nil
        }
        events.append(event)
        log = EventLog.reduce(events)
        undoable = label.map {
            UndoableAction(event: event, label: $0, expiresAt: event.at.addingTimeInterval(Self.undoWindow))
        }
        if evaluate {
            refresh()
        }
        return event
    }

    #if DEBUG
        /// Records a tap at an earlier time without running the engine, for demo data only. Call
        /// `refresh()` once the batch is in, as the watch sync will after a merge.
        func recordBackdated(_ kind: TapEventKind, at time: Date, target: UUID? = nil) {
            record(kind, target: target, label: nil, at: time, evaluate: false)
        }
    #endif

    private func reloadEvents() {
        guard let session else {
            events = []
            log = ReducedLog(contractions: [], redFlags: [:])
            return
        }
        let id = session.id
        let records =
            (try? context.fetch(FetchDescriptor<TapEventRecord>(predicate: #Predicate { $0.sessionID == id }))) ?? []
        events = EventMerger.ordered(records.compactMap(\.event))
        for event in events {
            clock.observe(event.lamport)
        }
        log = EventLog.reduce(events)
    }

    private func save() {
        try? context.save()
    }
}
