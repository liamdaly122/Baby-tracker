import Foundation
import MissionCore
import SwiftData
import Testing

@testable import MissionControl

/// The practice run must never reach the real labour: not its store, its alerts or the watch.
@MainActor
@Suite("Practice run in the app")
struct PracticeRunTests {
    /// Runs a drill through to the debrief: a tap, skip ahead, her waters, the call.
    private func walkThrough(_ drill: DrillController) {
        drill.labour.tap()
        drill.skipAhead()
        drill.labour.setRedFlag(.watersBroken, isOn: true)
        drill.labour.setWatersTime(secondsAgo: 0)
        drill.labour.logCall(.comeIn)
    }

    /// Sessions and taps in the real labour store.
    private func realRecords(_ model: AppModel) throws -> [Int] {
        let context = model.labourStore.mainContext
        return [
            try context.fetchCount(FetchDescriptor<LabourSessionRecord>()),
            try context.fetchCount(FetchDescriptor<TapEventRecord>()),
        ]
    }

    @Test("A drill has no alerts and no watch link, and the real labour hears nothing from it")
    func drillIsSilent() throws {
        let model = try AppModel(inMemory: true)
        let alerts = RecordingAlerts()
        let sync = RecordingSync()
        model.session.alerting = alerts
        model.session.sync = sync

        model.startDrill()
        let drill = try #require(model.drill)
        #expect(drill.labour.alerting == nil)
        #expect(drill.labour.sync == nil)
        walkThrough(drill)
        #expect(drill.step == .debrief)
        #expect(drill.labour.output.map { $0.state >= .callTriage } == true)

        #expect(alerts.updates.isEmpty && alerts.ended.isEmpty)
        #expect(sync.starts.isEmpty && sync.recorded.isEmpty)
        #expect(try realRecords(model) == [0, 0])
    }

    @Test("The screens show the real labour whenever it's running, and the drill only when it isn't")
    func labourPrefersRealSession() throws {
        let model = try AppModel(inMemory: true)
        #expect(model.labour === model.session)
        #expect(!model.isDrilling)

        model.startDrill()
        let drill = try #require(model.drill)
        #expect(model.isDrilling)
        #expect(model.labour === drill.labour)

        model.launch()
        #expect(model.drill == nil)
        #expect(!model.isDrilling)
        #expect(model.labour === model.session)
        #expect(model.session.isActive)

        // A drill can't start over a real labour.
        model.startDrill()
        #expect(model.drill == nil)
    }

    @Test("LAUNCH after an abandoned drill starts a clean labour with nothing carried over")
    func launchAfterDrillIsClean() throws {
        let model = try AppModel(inMemory: true)
        model.startDrill()
        let drill = try #require(model.drill)
        walkThrough(drill)
        let drillSession = try #require(drill.labour.sessionID)

        model.launch()
        let start = try #require(model.session.start)
        #expect(start.sessionID != drillSession)
        #expect(start.startedBy == model.session.deviceID)
        #expect(start.profile.gestationalAgeDays != Drill.gestationalAgeDays)
        #expect(model.session.log.contractions.isEmpty)
        #expect(model.session.log.activeRedFlags.isEmpty)
        #expect(model.session.log.lastCall == nil)
        #expect(model.session.undoable == nil && model.session.prompt == nil)
        // The real store has the new labour only, with no taps yet.
        #expect(try realRecords(model) == [1, 0])
        // Its clock is the real one, not the drill's, which had skipped ahead.
        #expect(abs(start.startedAt.timeIntervalSinceNow) < 5)
    }

    @Test("A drill left in the background for over 15 minutes is ended")
    func staleDrill() throws {
        let model = try AppModel(inMemory: true)
        model.startDrill()
        let drill = try #require(model.drill)
        let left = Date()
        drill.backgroundedAt = left
        #expect(!drill.isStale(at: left.addingTimeInterval(DrillController.idleLimit - 1)))
        #expect(drill.isStale(at: left.addingTimeInterval(DrillController.idleLimit + 1)))
    }
}
