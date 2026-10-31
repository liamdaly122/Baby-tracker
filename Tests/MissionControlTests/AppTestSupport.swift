import Foundation
import MissionCore
import SwiftData
import Testing

@testable import MissionControl

/// A clock the test moves by hand.
@MainActor
final class TestClock {
    var now = Date(timeIntervalSince1970: 1_800_000_000)

    func advance(_ seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }
}

/// Records what the session hands to alerting, instead of posting notifications.
@MainActor
final class RecordingAlerts: LabourAlerting {
    private(set) var updates: [(sessionID: UUID, state: LabourState)] = []
    private(set) var ended: [UUID] = []

    func engineDidUpdate(
        sessionID: UUID, previous: EngineStateSnapshot?, input: EngineInput, output: EngineOutput, watersBrokeAt: Date?
    ) {
        updates.append((sessionID, output.state))
    }

    func sessionDidEnd(sessionID: UUID) {
        ended.append(sessionID)
    }
}

/// Records what the session would send to the watch.
@MainActor
final class RecordingSync: LabourSyncing {
    private(set) var starts: [SessionStart] = []
    private(set) var recorded: [TapEvent] = []
    private(set) var ended: [UUID] = []

    func sessionDidStart(_ start: SessionStart) {
        starts.append(start)
    }

    func didRecord(_ events: [TapEvent], sessionID: UUID) {
        recorded += events
    }

    func sessionDidEnd(sessionID: UUID, at date: Date) {
        ended.append(sessionID)
    }
}

/// A labour store in a temporary file, so a test can close the app and open it again.
struct DiskStore {
    let url: URL

    init() throws {
        let folder = FileManager.default.temporaryDirectory.appending(
            path: "MissionControlTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        url = folder.appending(path: "Labour.store")
    }

    func open() throws -> ModelContainer {
        try Stores.labourContainer(at: url)
    }

    func remove() {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}

/// What the app keeps alive between launches: the store, the session model and its hooks.
@MainActor
struct Launch {
    let container: ModelContainer
    let model: LabourSessionModel
    let alerts = RecordingAlerts()
    let sync = RecordingSync()

    /// Opens the store and loads any unfinished labour, as the app does at launch.
    init(_ store: DiskStore, clock: TestClock, deviceID: String = "phone-test") throws {
        container = try store.open()
        model = LabourSessionModel(context: container.mainContext, deviceID: deviceID) { clock.now }
        model.alerting = alerts
        model.sync = sync
        model.loadActiveSession { record in
            Issue.record("Every session in these tests saves its start")
            return labourStart(at: record.startedAt)
        }
    }

    /// Every labour session saved in this store.
    func records() throws -> [LabourSessionRecord] {
        try container.mainContext.fetch(FetchDescriptor<LabourSessionRecord>())
    }
}

/// A UK labour at 39+0 with the built-in thresholds.
func labourStart(
    at date: Date, thresholds: ThresholdProfile = ThresholdTable.builtIn(for: .uk).defaults
) -> SessionStart {
    SessionStart(
        startedAt: date,
        startedBy: "phone-test",
        profile: LabourProfile(region: .uk, gestationalAgeDays: 273),
        thresholds: thresholds
    )
}
