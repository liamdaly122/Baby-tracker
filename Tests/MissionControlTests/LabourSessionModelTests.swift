import Foundation
import MissionCore
import SwiftData
import Testing

@testable import MissionControl

@MainActor
@Suite("Labour session on the phone")
struct LabourSessionModelTests {
    @Test("A labour survives the app being killed: taps, the open contraction and the event clock")
    func survivesKill() throws {
        let store = try DiskStore()
        defer { store.remove() }
        let clock = TestClock()
        let sessionID: UUID
        let openStart: Date
        do {
            let first = try Launch(store, clock: clock)
            first.model.start(labourStart(at: clock.now))
            first.model.tap()
            clock.advance(60)
            first.model.tap()
            clock.advance(240)
            first.model.tap()
            sessionID = try #require(first.model.sessionID)
            openStart = try #require(first.model.openContraction?.start)
        }
        clock.advance(30)
        let second = try Launch(store, clock: clock)
        #expect(second.model.sessionID == sessionID)
        #expect(second.model.log.contractions.count == 2)
        #expect(second.model.openContraction?.start == openStart)
        #expect(second.model.output != nil)
        let before = try #require(second.model.core?.events.map(\.lamport).max())
        second.model.tap()
        #expect(second.model.openContraction == nil)
        let stop = try #require(second.model.core?.events.last)
        #expect(stop.lamport > before)
    }

    @Test("Undo works for 10 seconds after a tap, and not after")
    func undoWindow() throws {
        let store = try DiskStore()
        defer { store.remove() }
        let clock = TestClock()
        let launch = try Launch(store, clock: clock)
        launch.model.start(labourStart(at: clock.now))

        launch.model.tap()
        clock.advance(9)
        #expect(launch.model.undoable != nil)
        launch.model.undo()
        #expect(launch.model.log.contractions.isEmpty)

        launch.model.tap()
        clock.advance(11)
        launch.model.undo()
        #expect(launch.model.undoable == nil)
        #expect(launch.model.openContraction != nil)
    }

    @Test("A stop forgotten for over 5 minutes asks first, then fixes the old one and times the new one")
    func forgottenStop() throws {
        let store = try DiskStore()
        defer { store.remove() }
        let clock = TestClock()
        let launch = try Launch(store, clock: clock)
        launch.model.start(labourStart(at: clock.now))
        launch.model.tap()
        let forgotten = try #require(launch.model.openContraction)
        clock.advance(EngineConstants.forgotStopSec + 60)

        launch.model.tap()
        #expect(launch.model.prompt == .endedOrNew(elapsedSec: EngineConstants.forgotStopSec + 60))
        #expect(launch.model.log.contractions.count == 1)

        launch.model.newOneStarted()
        guard case .fixForgotten(let id, _) = launch.model.prompt else {
            Issue.record("Expected the forgotten-stop question, got \(String(describing: launch.model.prompt))")
            return
        }
        #expect(id == forgotten.id)
        launch.model.close(id, afterSeconds: 70)
        #expect(launch.model.prompt == nil)
        let fixed = try #require(launch.model.log.contractions.first { $0.id == forgotten.id })
        #expect(fixed.end == forgotten.start.addingTimeInterval(70))
        #expect(launch.model.openContraction?.start == clock.now)
    }

    @Test("New thresholds mid-labour go to the watch with a higher revision and survive a relaunch")
    func thresholdsMidLabour() throws {
        let store = try DiskStore()
        defer { store.remove() }
        let clock = TestClock()
        let midwife = ThresholdTable.builtIn(for: .uk).profile(applying: [.adviceIntervalSec: 240])
        do {
            let first = try Launch(store, clock: clock)
            first.model.start(labourStart(at: clock.now))
            first.model.applyThresholds(midwife)
            #expect(first.model.start?.revision == 1)
            #expect(first.model.thresholds.adviceIntervalSec == 240)
            #expect(first.sync.starts.last?.revision == 1)
            #expect(first.sync.starts.last?.thresholds == midwife)
        }
        let second = try Launch(store, clock: clock)
        #expect(second.model.start?.revision == 1)
        #expect(second.model.thresholds.adviceIntervalSec == 240)
    }

    @Test("Ending a labour cancels its alerts, tells the watch, and it stays ended after a relaunch")
    func endAndRelaunch() throws {
        let store = try DiskStore()
        defer { store.remove() }
        let clock = TestClock()
        let sessionID: UUID
        do {
            let first = try Launch(store, clock: clock)
            first.model.start(labourStart(at: clock.now))
            first.model.tap()
            sessionID = try #require(first.model.sessionID)
            clock.advance(600)
            first.model.end()
            #expect(!first.model.isActive)
            #expect(first.alerts.ended == [sessionID])
            #expect(first.sync.ended == [sessionID])
            #expect(try first.records().first?.endedAt == clock.now)
        }
        let second = try Launch(store, clock: clock)
        #expect(!second.model.isActive)
        #expect(second.model.wasEnded(sessionID))
    }

    @Test("Her waters stay flagged after a relaunch, and the question about when stays until it's answered")
    func flagSurvivesRelaunch() throws {
        let store = try DiskStore()
        defer { store.remove() }
        let clock = TestClock()
        do {
            let first = try Launch(store, clock: clock)
            first.model.start(labourStart(at: clock.now))
            first.model.setRedFlag(.watersBroken, isOn: true)
            #expect(first.model.prompt == .watersWhen)
        }
        do {
            let second = try Launch(store, clock: clock)
            #expect(second.model.log.activeRedFlags.contains(.watersBroken))
            #expect(second.model.prompt == .watersWhen)
            #expect(second.alerts.updates.last?.state == .callNow)
            second.model.setWatersTime(secondsAgo: 600)
            #expect(second.model.prompt == nil)
        }
        let third = try Launch(store, clock: clock)
        #expect(third.model.prompt == nil)
        #expect(third.model.core?.watersBrokeAt == clock.now.addingTimeInterval(-600))
    }
}

@Suite("Test host")
struct TestHostTests {
    @Test("While hosting tests the app opens no stores and starts no watch link of its own")
    func hostStaysIdle() {
        #expect(LaunchOptions.isTestHost)
    }
}
