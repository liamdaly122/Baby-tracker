import Foundation
import MissionCore
import Observation
import SwiftData

/// A practice run: a labour session on a pretend 39+0 labour, in a store that only lives in memory,
/// so it's gone if the app is closed. It has no alerting and no sync, so nothing reaches the watch
/// or the notification centre, and its clock can skip ahead. The real session is never touched.
@MainActor
@Observable
final class DrillController {
    /// The drill's clock: the time now plus however far it has skipped ahead.
    private final class Clock {
        var offset: TimeInterval = 0
        func now() -> Date { Date().addingTimeInterval(offset) }
    }

    let labour: LabourSessionModel
    private let store: ModelContainer
    private let clock: Clock
    /// When the app last went into the background, so a drill left behind can be ended.
    var backgroundedAt: Date?

    /// How long a drill can sit in the background before it's ended.
    static let idleLimit: TimeInterval = 15 * 60

    init(brief: MissionBrief, details: @escaping (Int?) -> TriageDetails) throws {
        let clock = Clock()
        self.clock = clock
        store = try Stores.labourContainer(inMemory: true)
        labour = LabourSessionModel(context: store.mainContext, deviceID: Drill.deviceID, now: clock.now)
        labour.detailsProvider = details
        labour.start(Drill.sessionStart(brief, at: clock.now()))
    }

    var step: Drill.Step { Drill.step(labour.log) }

    var plan: Drill.SkipPlan? { labour.core.map(Drill.skipPlan) }

    /// Skips ahead through a regular run, then moves the clock on to just after it.
    func skipAhead() {
        let now = labour.currentTime
        var resume = now
        labour.applyScripted { core in resume = Drill.skipAhead(&core, from: now) }
        clock.offset += resume.timeIntervalSince(now)
        labour.refresh()
    }

    func debrief() -> Drill.Debrief? {
        guard var core = labour.core else { return nil }
        return Drill.debrief(&core, at: labour.currentTime)
    }

    /// True if the drill was left in the background for longer than `idleLimit`.
    func isStale(at date: Date) -> Bool {
        backgroundedAt.map { date.timeIntervalSince($0) > Self.idleLimit } ?? false
    }
}
