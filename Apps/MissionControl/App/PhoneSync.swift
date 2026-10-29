import Foundation
import MissionCore
import MissionSync

/// The phone's side of the watch link. The phone owns the profile, so it sends the brief; taps,
/// starts and ends go both ways.
@MainActor
final class PhoneSync: LabourSyncing {
    private let transport = SyncTransport()
    private weak var labour: LabourSessionModel?
    private let briefProvider: () -> MissionBrief

    init(labour: LabourSessionModel, briefProvider: @escaping () -> MissionBrief) {
        self.labour = labour
        self.briefProvider = briefProvider
    }

    func activate() {
        transport.onMessage = { [weak self] message in self?.handle(message) }
        transport.onReachable = { [weak self] in self?.catchUp() }
        transport.activate()
    }

    /// The latest brief and session for the watch. Call after any profile or threshold change.
    /// Sent as the context (for a watch that's asleep) and straight away if it's reachable.
    func publishContext() {
        let state = SyncMessage.state(brief: briefProvider(), session: labour?.start)
        transport.setContext(state)
        transport.send(state, queued: false)
    }

    // MARK: LabourSyncing

    func sessionDidStart(_ start: SessionStart) {
        transport.send(.sessionStarted(start))
        publishContext()
    }

    func didRecord(_ events: [TapEvent], sessionID: UUID) {
        transport.send(.events(sessionID: sessionID, events))
    }

    func sessionDidEnd(sessionID: UUID, at date: Date) {
        transport.send(.sessionEnded(sessionID: sessionID, at: date))
        publishContext()
    }

    // MARK: Receiving

    private func handle(_ message: SyncMessage) {
        guard let labour else { return }
        switch message {
        case .state(_, let session):
            if let session { adopt(session, in: labour) }
        case .brief:
            break  // The phone is the source of the brief.
        case .sessionStarted(let start):
            adopt(start, in: labour)
        case .events(let sessionID, let events):
            if sessionID == labour.sessionID {
                labour.receive(events)
            }
        case .marks(let sessionID, let marks):
            if sessionID == labour.sessionID, let missing = labour.core?.events(newerThan: marks), !missing.isEmpty {
                transport.send(.events(sessionID: sessionID, missing), queued: false)
            }
        case .sessionEnded(let sessionID, _):
            labour.receiveEnd(sessionID: sessionID)
        }
    }

    private func adopt(_ start: SessionStart, in labour: LabourSessionModel) {
        if labour.wasEnded(start.sessionID) {
            // Ended here already: tell the watch again rather than bringing it back, and send the
            // session that's running now, if any.
            transport.send(.sessionEnded(sessionID: start.sessionID, at: Date()))
            publishContext()
            return
        }
        labour.receive(start)
        if labour.sessionID != start.sessionID {
            // Ours won: make sure the watch hears it.
            publishContext()
        }
    }

    /// On reconnecting: the latest state at once (the context channel can lag), then marks so the
    /// watch sends any taps the phone missed.
    private func catchUp() {
        publishContext()
        if let core = labour?.core {
            transport.send(.marks(sessionID: core.sessionID, core.highWaterMarks), queued: false)
        }
    }
}
