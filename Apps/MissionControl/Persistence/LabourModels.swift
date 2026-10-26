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
    /// partner deliberately applies new ones.
    var thresholdsJSON: Data
    /// The engine's last snapshot, for hysteresis across launches.
    var engineSnapshotJSON: Data?

    init(id: UUID = UUID(), startedAt: Date, ownerDeviceID: String, region: ContentRegion, thresholds: ThresholdProfile)
    {
        self.id = id
        self.startedAt = startedAt
        self.ownerDeviceID = ownerDeviceID
        self.regionRaw = region.rawValue
        self.thresholdsJSON = (try? JSONEncoder().encode(thresholds)) ?? Data()
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

    var engineSnapshot: EngineStateSnapshot? {
        get { engineSnapshotJSON.flatMap { try? JSONDecoder().decode(EngineStateSnapshot.self, from: $0) } }
        set { engineSnapshotJSON = newValue.flatMap { try? JSONEncoder().encode($0) } }
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
