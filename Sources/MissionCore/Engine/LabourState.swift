import Foundation

/// What the app advises, from least to most urgent. Instructional, never a diagnosis: the engine
/// says when to call, never which stage of labour she is in.
public enum LabourState: String, Codable, Sendable, CaseIterable, Comparable {
    case early
    case establishing
    case callTriage
    case callNow
    case call999

    private var rank: Int {
        switch self {
        case .early: 0
        case .establishing: 1
        case .callTriage: 2
        case .callNow: 3
        case .call999: 4
        }
    }

    public static func < (lhs: LabourState, rhs: LabourState) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// Why the engine chose a state. Shown as the reason line and kept for the "how we got here" view.
public enum ReasonCode: String, Codable, Sendable, CaseIterable {
    // call999
    case urgeToPush
    case cordVisible
    case seizureCollapse
    case heavyBleeding
    // callNow: red flags and profile
    case watersBroken
    case watersColoured
    case bleeding
    case reducedMovements
    case preterm
    // callNow: contractions
    case contractionOverUrgentDuration
    case openContractionOverUrgentDuration
    case tooManyInTenMinutes
    // callTriage
    case regularPatternSustained
    // establishing
    case patternNotYetSustained
    case patternBuilding
    // early
    case notEnoughContractions
    case noRegularPattern
    // hysteresis: the advice is being held while contractions ease
    case patternEasing
}

/// Toggles the partner sets in labour mode. Each one forces at least `callNow`; they stay on until
/// he turns them off, so red-flag states never time out on their own.
public enum RedFlag: String, Codable, Sendable, CaseIterable {
    case watersBroken
    case watersColoured
    case bleeding
    case heavyBleeding
    case reducedMovements
    case urgeToPush
    case cordVisible
    case seizureCollapse

    public var state: LabourState {
        switch self {
        case .urgeToPush, .cordVisible, .seizureCollapse, .heavyBleeding: .call999
        case .watersBroken, .watersColoured, .bleeding, .reducedMovements: .callNow
        }
    }

    public var reason: ReasonCode {
        switch self {
        case .watersBroken: .watersBroken
        case .watersColoured: .watersColoured
        case .bleeding: .bleeding
        case .heavyBleeding: .heavyBleeding
        case .reducedMovements: .reducedMovements
        case .urgeToPush: .urgeToPush
        case .cordVisible: .cordVisible
        case .seizureCollapse: .seizureCollapse
        }
    }
}

/// One contraction as derived from the tap log. `end` is nil while it is still being timed.
public struct Contraction: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var start: Date
    public var end: Date?

    public init(id: UUID = UUID(), start: Date, end: Date?) {
        self.id = id
        self.start = start
        self.end = end
    }
}

/// The parts of the pregnancy profile the engine needs.
public struct LabourProfile: Codable, Sendable, Hashable {
    public var region: ContentRegion
    /// Number of previous births. 1 or more makes her an early caller.
    public var parity: Int
    public var previousFastLabour: Bool
    /// Gestational age at the moment of evaluation, in days (37+0 = 259). Nil if unknown.
    public var gestationalAgeDays: Int?
    /// Journey time to the maternity unit. Nil if not entered.
    public var travelMinutes: Int?

    public init(
        region: ContentRegion,
        parity: Int = 0,
        previousFastLabour: Bool = false,
        gestationalAgeDays: Int? = nil,
        travelMinutes: Int? = nil
    ) {
        self.region = region
        self.parity = parity
        self.previousFastLabour = previousFastLabour
        self.gestationalAgeDays = gestationalAgeDays
        self.travelMinutes = travelMinutes
    }
}

/// Fixed engine rules that are not user-editable. Listed in docs/content-review-log.md for review.
public enum EngineConstants {
    /// Fewer contractions than this in the recent segment can't form a pattern.
    public static let minimumContractions = 4
    /// An open contraction older than this is treated as a forgotten stop for duration statistics.
    public static let forgotStopSec: TimeInterval = 300
    /// A start-to-start gap this many times the recent median splits the log into a new segment.
    public static let gapSplitFactor = 3.0
    /// `establishing` also covers a regular pattern up to this multiple of the advice interval.
    public static let establishingIntervalFactor = 1.5
    /// How long a lower state's conditions must hold before the advice drops.
    public static let demotionDwellSec: TimeInterval = 900
    /// The window for the "N or more in 10 minutes" rule. Starts are counted in [t, t + 600).
    public static let tenMinutesSec: TimeInterval = 600
    /// Under 37+0 weeks, any labour session means call now.
    public static let termDays = 259
}
