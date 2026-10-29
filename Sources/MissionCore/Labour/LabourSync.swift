import Foundation

/// What the watch needs from the phone to run labour mode on its own: the profile to fix gestation
/// from, the thresholds, and the numbers to call. The phone sends a fresh one whenever any of it
/// changes, before labour as well as during it, so the watch can launch, apply the preterm rule
/// and call without the phone nearby.
public struct MissionBrief: Codable, Sendable, Hashable {
    public var region: ContentRegion
    /// "2026-12-07", or nil if there's no due date.
    public var dueDateText: String?
    public var parity: Int
    public var previousFastLabour: Bool
    public var travelMinutes: Int?
    public var thresholds: ThresholdProfile
    public var motherName: String
    public var unitName: String
    public var triage: PhoneNumber?
    public var labourWard: PhoneNumber?
    public var gbsPositive: Bool
    public var plannedCaesarean: Bool
    public var updatedAt: Date

    public init(
        region: ContentRegion,
        dueDateText: String?,
        parity: Int,
        previousFastLabour: Bool,
        travelMinutes: Int?,
        thresholds: ThresholdProfile,
        motherName: String,
        unitName: String,
        triage: PhoneNumber?,
        labourWard: PhoneNumber?,
        gbsPositive: Bool = false,
        plannedCaesarean: Bool = false,
        updatedAt: Date
    ) {
        self.region = region
        self.dueDateText = dueDateText
        self.parity = parity
        self.previousFastLabour = previousFastLabour
        self.travelMinutes = travelMinutes
        self.thresholds = thresholds
        self.motherName = motherName
        self.unitName = unitName
        self.triage = triage
        self.labourWard = labourWard
        self.gbsPositive = gbsPositive
        self.plannedCaesarean = plannedCaesarean
        self.updatedAt = updatedAt
    }

    /// Briefs saved before GBS and planned caesarean existed decode with both off.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        region = try container.decode(ContentRegion.self, forKey: .region)
        dueDateText = try container.decodeIfPresent(String.self, forKey: .dueDateText)
        parity = try container.decode(Int.self, forKey: .parity)
        previousFastLabour = try container.decode(Bool.self, forKey: .previousFastLabour)
        travelMinutes = try container.decodeIfPresent(Int.self, forKey: .travelMinutes)
        thresholds = try container.decode(ThresholdProfile.self, forKey: .thresholds)
        motherName = try container.decode(String.self, forKey: .motherName)
        unitName = try container.decode(String.self, forKey: .unitName)
        triage = try? container.decodeIfPresent(PhoneNumber.self, forKey: .triage)
        labourWard = try? container.decodeIfPresent(PhoneNumber.self, forKey: .labourWard)
        gbsPositive = try container.decodeIfPresent(Bool.self, forKey: .gbsPositive) ?? false
        plannedCaesarean = try container.decodeIfPresent(Bool.self, forKey: .plannedCaesarean) ?? false
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    public var dueDate: CalendarDay? {
        guard let parts = dueDateText?.split(separator: "-").compactMap({ Int($0) }), parts.count == 3 else {
            return nil
        }
        return CalendarDay(year: parts[0], month: parts[1], day: parts[2])
    }

    /// The engine profile with gestation fixed at `date`.
    public func labourProfile(at date: Date, calendar: Calendar) -> LabourProfile {
        LabourProfile(
            region: region,
            parity: parity,
            previousFastLabour: previousFastLabour,
            gestationalAgeDays: dueDate.map {
                PregnancyCalendar(dueDate: $0).gestationalAgeDays(at: date, in: calendar)
            },
            travelMinutes: travelMinutes,
            gbsPositive: gbsPositive,
            plannedCaesarean: plannedCaesarean
        )
    }

    /// A session started on this device at `date`.
    public func sessionStart(at date: Date, by deviceID: String, calendar: Calendar) -> SessionStart {
        SessionStart(
            startedAt: date,
            startedBy: deviceID,
            profile: labourProfile(at: date, calendar: calendar),
            thresholds: thresholds
        )
    }
}

/// Everything the phone and the watch say to each other. Taps travel as events, so a lost or
/// repeated message is harmless: the log dedupes by ID and catches up by high-water marks.
public enum SyncMessage: Codable, Sendable, Hashable {
    /// The latest of everything, for the application context: what a device that has just woken up
    /// needs. A nil session never ends one: only `sessionEnded` does.
    case state(brief: MissionBrief?, session: SessionStart?)
    case brief(MissionBrief)
    case sessionStarted(SessionStart)
    case events(sessionID: UUID, [TapEvent])
    /// "This is what I've seen": the other side replies with anything newer.
    case marks(sessionID: UUID, [String: UInt64])
    case sessionEnded(sessionID: UUID, at: Date)

    public static let key = "missionControl.sync"

    /// As a WatchConnectivity payload: one key holding the JSON.
    public func payload() throws -> [String: Any] {
        [Self.key: try JSONEncoder().encode(self)]
    }

    /// Nil for a payload that isn't one of ours or can't be read.
    public init?(payload: [String: Any]) {
        guard let data = payload[Self.key] as? Data,
            let message = try? JSONDecoder().decode(SyncMessage.self, from: data)
        else { return nil }
        self = message
    }
}
