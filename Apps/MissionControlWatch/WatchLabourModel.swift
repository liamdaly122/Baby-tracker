import Foundation
import MissionCore
import MissionSync
import OSLog
import Observation

/// Labour mode on the watch, the main contraction timer. It runs the same `LabourSessionCore` as
/// the phone, keeps its own copy of the log so it works with the phone out of reach, and trades
/// taps with the phone whenever it can. Launching works from the brief the phone last sent.
@MainActor
@Observable
final class WatchLabourModel {
    enum Prompt: Equatable {
        case endedOrNew(elapsedSec: TimeInterval)
        case fixForgotten(contractionID: UUID, elapsedSec: TimeInterval)
    }

    private(set) var brief: MissionBrief?
    private(set) var core: LabourSessionCore?
    private(set) var output: EngineOutput?
    var prompt: Prompt?
    private(set) var notice: (text: String, until: Date)?
    private(set) var undoable: (event: TapEvent, until: Date)?
    var quietAcknowledgedFor: Date?

    let deviceID: String
    private let transport = SyncTransport()
    private let store = WatchStore()
    private let notifier = WatchNotifier()
    private var ended: Set<UUID>
    private var alerted: EngineStateSnapshot?

    init() {
        deviceID = WatchIdentity.current
        let saved = store.load()
        brief = saved.brief
        ended = Set(saved.ended)
        if let start = saved.start {
            core = LabourSessionCore(start: start, deviceID: deviceID, events: saved.events)
        }
        transport.onMessage = { [weak self] message in self?.handle(message) }
        transport.onReachable = { [weak self] in self?.catchUp() }
        transport.activate()
        if let context = transport.receivedContext {
            handle(context)
        }
        refresh()
    }

    var isActive: Bool { core != nil }
    var log: ReducedLog { core?.log ?? ReducedLog() }
    var openContraction: Contraction? { log.openContraction }

    var needsTermAnswer: Bool {
        guard let start = core?.start, start.profile.gestationalAgeDays == nil else { return false }
        return log.termAnswer != .term && log.termAnswer != .preterm
    }

    /// Gestation today from the brief, for the launch screen.
    var gestationToday: GestationalAge? {
        brief?.dueDate.map { PregnancyCalendar(dueDate: $0).gestationalAge(on: CalendarDay(Date(), in: .current)) }
    }

    // MARK: Session

    /// LAUNCH on the wrist. Without a brief the gestation isn't known, so the advice is to call
    /// until he answers the 37-week question.
    func launch() {
        guard core == nil else { return }
        Task { await notifier.requestAuthorization() }
        let source = brief ?? Self.fallbackBrief
        let start = source.sessionStart(at: Date(), by: deviceID, calendar: .current)
        core = LabourSessionCore(start: start, deviceID: deviceID)
        save()
        transport.send(.sessionStarted(start))
        transport.setContext(.state(brief: nil, session: start))
        refresh()
    }

    // MARK: Taps

    func tap() {
        guard var core else { return }
        let outcome = core.tap(at: Date())
        self.core = core
        switch outcome {
        case .started(let event):
            prompt = nil
            recorded(event, undo: true)
        case .stopped(let event, _):
            recorded(event, undo: true)
        case .askIfEndedOrNew(_, let elapsed):
            prompt = .endedOrNew(elapsedSec: elapsed)
        case .ignoredDoubleTap:
            notice = ("Ignored a double tap", Date().addingTimeInterval(3))
        }
    }

    func endedJustNow() {
        prompt = nil
        perform { $0.endOpenContraction(at: $1) }
    }

    func newOneStarted() {
        guard let open = openContraction else {
            prompt = nil
            return
        }
        let elapsed = Date().timeIntervalSince(open.start)
        perform { $0.startNew(at: $1) }
        prompt = .fixForgotten(contractionID: open.id, elapsedSec: elapsed)
    }

    func close(_ id: UUID, afterSeconds seconds: TimeInterval) {
        prompt = nil
        perform { $0.close(id, afterSeconds: seconds, at: $1) }
    }

    func markStopped() {
        quietAcknowledgedFor = nil
        perform { $0.markStopped(at: $1) }
    }

    func answerTerm(_ answer: TermAnswer) {
        perform { $0.answerTerm(answer, at: $1) }
    }

    func setRedFlag(_ flag: RedFlag, isOn: Bool) {
        perform { $0.setRedFlag(flag, isOn: isOn, at: $1) }
    }

    func acknowledgeQuiet() {
        quietAcknowledgedFor = output?.metrics.lastStart
    }

    func undo() {
        guard let undoable, undoable.until > Date() else { return }
        self.undoable = nil
        perform { $0.record(.undo, at: $1, target: undoable.event.id) }
    }

    // MARK: Advice

    func refresh() {
        guard var core else {
            output = nil
            return
        }
        let now = Date()
        let result = core.output(at: now)
        self.core = core
        output = result
        if let notice, notice.until <= now { self.notice = nil }
        if let undoable, undoable.until <= now { self.undoable = nil }
        notifier.update(
            sessionID: core.sessionID, previous: alerted, input: core.engineInput(at: now, previous: alerted),
            output: result, watersBrokeAt: core.watersBrokeAt)
        alerted = result.snapshot
    }

    // MARK: Sync

    private func handle(_ message: SyncMessage) {
        SyncLog.received(message, session: core?.sessionID)
        switch message {
        case .state(let brief, let session):
            if let brief { receive(brief) }
            if let session { receive(session) }
        case .brief(let brief):
            receive(brief)
        case .sessionStarted(let start):
            receive(start)
        case .events(let sessionID, let events):
            guard var core, sessionID == core.sessionID else { return }
            let fresh = core.merge(events)
            self.core = core
            if !fresh.isEmpty {
                save()
                refresh()
            }
        case .marks(let sessionID, let marks):
            if let core, sessionID == core.sessionID {
                let missing = core.events(newerThan: marks)
                if !missing.isEmpty { transport.send(.events(sessionID: sessionID, missing), queued: false) }
            }
        case .sessionEnded(let sessionID, _):
            endSession(sessionID)
        }
    }

    private func receive(_ newBrief: MissionBrief) {
        guard brief.map({ newBrief.updatedAt >= $0.updatedAt }) ?? true else { return }
        brief = newBrief
        save()
    }

    private func receive(_ start: SessionStart) {
        guard !ended.contains(start.sessionID) else { return }
        guard var current = core else {
            core = LabourSessionCore(start: start, deviceID: deviceID)
            save()
            catchUp()
            refresh()
            return
        }
        if start.sessionID == current.sessionID {
            let revision = current.start.revision
            current.update(start)
            if current.start.revision != revision {
                // Keep the context the phone reads on launch up to date, or it would replay the old start.
                transport.setContext(.state(brief: nil, session: current.start))
            }
        } else if SessionStart.winner(current.start, start) == start {
            notifier.cancel(sessionID: current.sessionID)
            if SessionStart.isSameLabour(current.start, start) {
                // The phone started the same labour first: move the watch's taps into its session.
                current.adopt(start)
                transport.send(.events(sessionID: start.sessionID, current.events))
            } else {
                // The watch's session is stale: drop it and take the phone's.
                ended.insert(current.sessionID)
                current = LabourSessionCore(start: start, deviceID: deviceID)
                core = current
                save()
                catchUp()
                refresh()
                return
            }
        } else {
            // The watch's session stands: make sure the phone hears it.
            transport.send(.state(brief: nil, session: current.start), queued: false)
            return
        }
        core = current
        save()
        refresh()
    }

    private func endSession(_ sessionID: UUID) {
        ended.insert(sessionID)
        if core?.sessionID == sessionID {
            notifier.cancel(sessionID: sessionID)
            core = nil
            output = nil
            prompt = nil
            undoable = nil
        }
        save()
    }

    /// On reconnecting: tell the phone about a session it may not have, then trade marks.
    private func catchUp() {
        if let core {
            transport.send(.state(brief: nil, session: core.start), queued: false)
            transport.send(.marks(sessionID: core.sessionID, core.highWaterMarks), queued: false)
        }
    }

    // MARK: Storage

    private func perform(_ change: (inout LabourSessionCore, Date) -> TapEvent?) {
        guard var core else { return }
        let event = change(&core, Date())
        self.core = core
        if let event {
            recorded(event, undo: false)
        }
    }

    private func recorded(_ event: TapEvent, undo: Bool) {
        save()
        transport.send(.events(sessionID: event.sessionID, [event]))
        if undo {
            undoable = (event, event.at.addingTimeInterval(10))
        }
        refresh()
    }

    private func save() {
        store.save(
            WatchState(brief: brief, start: core?.start, events: core?.events ?? [], ended: Array(ended.suffix(20))))
    }

    /// Used only when the phone has never sent a brief: UK defaults, no due date.
    static let fallbackBrief = MissionBrief(
        region: .uk, dueDateText: nil, parity: 0, previousFastLabour: false, travelMinutes: nil,
        thresholds: ThresholdTable.builtIn(for: .uk).defaults, motherName: "", unitName: "", triage: nil,
        labourWard: nil, updatedAt: .distantPast)
}

/// What the watch keeps between launches.
struct WatchState: Codable {
    var brief: MissionBrief?
    var start: SessionStart?
    var events: [TapEvent]
    var ended: [UUID]

    static let empty = WatchState(brief: nil, start: nil, events: [], ended: [])
}

/// One JSON file in Application Support, readable after first unlock so a wrist raise works.
struct WatchStore {
    private var url: URL? {
        let base = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return base?.appending(path: "labour.json")
    }

    func load() -> WatchState {
        guard let url, let data = try? Data(contentsOf: url),
            let state = try? JSONDecoder().decode(WatchState.self, from: data)
        else { return .empty }
        return state
    }

    func save(_ state: WatchState) {
        guard let url, let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}

/// A stable ID for the watch, so its taps can be told from the phone's.
enum WatchIdentity {
    private static let key = "missionControl.deviceID"

    static var current: String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: key) {
            return existing
        }
        let made = "watch-\(UUID().uuidString.prefix(8).lowercased())"
        defaults.set(made, forKey: key)
        return made
    }
}

/// Sync diagnostics, in Console under the "sync" category.
enum SyncLog {
    private static let logger = Logger(subsystem: "com.liamdaly.missioncontrol", category: "sync")

    static func received(_ message: SyncMessage, session: UUID?) {
        let mine = session?.uuidString.prefix(8) ?? "none"
        switch message {
        case .state(let brief, let start):
            logger.info(
                "state brief=\(brief != nil) session=\(start?.sessionID.uuidString.prefix(8) ?? "none") mine=\(mine)")
        case .brief: logger.info("brief mine=\(mine)")
        case .sessionStarted(let start): logger.info("started \(start.sessionID.uuidString.prefix(8)) mine=\(mine)")
        case .events(let id, let events):
            logger.info("events \(events.count) for \(id.uuidString.prefix(8)) mine=\(mine)")
        case .marks(let id, let marks): logger.info("marks \(marks.count) for \(id.uuidString.prefix(8)) mine=\(mine)")
        case .sessionEnded(let id, _): logger.info("ended \(id.uuidString.prefix(8)) mine=\(mine)")
        }
    }
}
