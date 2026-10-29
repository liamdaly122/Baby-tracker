import Foundation
import MissionCore
import SwiftData

/// One labour, from LAUNCH to "End labour". Lives in the labour store, which is never synced.
@Model
final class LabourSessionRecord {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var ownerDeviceID: String
    var regionRaw: String
    /// Thresholds frozen when the session started, so advice doesn't shift mid-labour unless the
    /// partner deliberately applies new ones. Kept for sessions saved before `startJSON`.
    var thresholdsJSON: Data
    /// The last snapshot an alert was decided on, so relaunching doesn't repeat an alert.
    var engineSnapshotJSON: Data?
    /// The `SessionStart`: profile with gestation fixed, and thresholds. Nil in sessions saved
    /// before it existed.
    var startJSON: Data?

    init(start: SessionStart) {
        id = start.sessionID
        startedAt = start.startedAt
        ownerDeviceID = start.startedBy
        regionRaw = start.profile.region.rawValue
        thresholdsJSON = (try? JSONEncoder().encode(start.thresholds)) ?? Data()
        startJSON = try? JSONEncoder().encode(start)
    }
}

extension LabourSessionRecord {
    var region: ContentRegion {
        ContentRegion(rawValue: regionRaw) ?? .uk
    }

    var thresholds: ThresholdProfile? {
        get { try? JSONDecoder().decode(ThresholdProfile.self, from: thresholdsJSON) }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                thresholdsJSON = data
            }
        }
    }

    var alertedSnapshot: EngineStateSnapshot? {
        get { engineSnapshotJSON.flatMap { try? JSONDecoder().decode(EngineStateSnapshot.self, from: $0) } }
        set { engineSnapshotJSON = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }

    var start: SessionStart? {
        get { startJSON.flatMap { try? JSONDecoder().decode(SessionStart.self, from: $0) } }
        set {
            startJSON = newValue.flatMap { try? JSONEncoder().encode($0) }
            if let thresholds = newValue?.thresholds {
                self.thresholds = thresholds
            }
        }
    }
}

/// One tap, stored as its encoded `TapEvent`. Append-only.
@Model
final class TapEventRecord {
    @Attribute(.unique) var id: UUID
    var sessionID: UUID
    var lamport: Int
    var eventJSON: Data

    init(event: TapEvent) throws {
        id = event.id
        sessionID = event.sessionID
        lamport = Int(clamping: event.lamport)
        eventJSON = try JSONEncoder().encode(event)
    }

    var event: TapEvent? {
        try? JSONDecoder().decode(TapEvent.self, from: eventJSON)
    }
}
