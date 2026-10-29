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
    case headVisible
    /// Bleeding and constant or severe pain together. NHS: call 999 for bleeding with severe tummy pain.
    case bleedingWithSeverePain
    /// A 999 flag was turned off under a minute ago. Shown with that flag, in case it was a mistake.
    case emergencyJustCleared
    // callNow: red flags and profile
    case watersBroken
    case watersColoured
    case bleeding
    case reducedMovements
    case severePain
    case preEclampsiaSigns
    /// She's GBS positive and her waters have gone, at 37 weeks or more.
    case gbsWithWaters
    /// She's GBS positive and her waters have gone, under 37 weeks or weeks not known. Term advice
    /// (induction straight away) doesn't apply.
    case gbsWithWatersPreterm
    /// A caesarean is planned and labour has started first.
    case plannedCaesarean
    case preterm
    /// No due date and nobody has said she's 37 weeks or more.
    case gestationUnknown
    // callNow: contractions
    case contractionOverUrgentDuration
    case openContractionOverUrgentDuration
    case tooManyInTenMinutes
    // callTriage
    case regularPatternSustained
    /// She's GBS positive and contractions have started: antibiotics should start once labour begins.
    case gbsInLabour
    // establishing
    case patternNotYetSustained
    case patternBuilding
    // early
    case notEnoughContractions
    case noRegularPattern
    /// He said the contractions have stopped.
    case contractionsStopped
    // hysteresis: the advice is being held while contractions ease
    case patternEasing
    /// Added to the shown reasons: nothing has been logged for a while, so ask if they're still coming.
    case noRecentTaps
}

/// The answer to "Is she 37 weeks pregnant or more?", asked when there's no due date.
public enum TermAnswer: String, Codable, Sendable, CaseIterable {
    case term
    case preterm
    case notSure
}

/// Toggles the partner sets in labour mode. Each one forces at least `callNow`; they stay on until
/// he turns them off, so red-flag states never time out on their own. New cases go at the end:
/// the order is the order reasons are listed in.
public enum RedFlag: String, Codable, Sendable, CaseIterable {
    case watersBroken
    case watersColoured
    case bleeding
    /// NHS: a pad soaked soon after putting it on, or bleeding with severe tummy pain, feeling
    /// faint or dizzy.
    case heavyBleeding
    case reducedMovements
    case urgeToPush
    case cordVisible
    case seizureCollapse
    /// Constant or severe pain, with no break between contractions.
    case severePain
    /// NHS pre-eclampsia signs: a bad headache that painkillers don't help, vision problems, pain
    /// below the ribs, sudden swelling, or feeling very unwell.
    case preEclampsiaSigns
    /// He can see the baby's head.
    case headVisible

    public var state: LabourState {
        switch self {
        case .urgeToPush, .cordVisible, .seizureCollapse, .heavyBleeding, .headVisible: .call999
        case .watersBroken, .watersColoured, .bleeding, .reducedMovements, .severePain, .preEclampsiaSigns:
            .callNow
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
        case .severePain: .severePain
        case .preEclampsiaSigns: .preEclampsiaSigns
        case .headVisible: .headVisible
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
    /// Gestational age when the labour session started, in days (37+0 = 259). Nil if unknown.
    /// Work it out once at the start and keep it: recomputing it would flip the preterm advice at
    /// midnight on 37+0.
    public var gestationalAgeDays: Int?
    /// The answer to "Is she 37 weeks or more?" when `gestationalAgeDays` is nil. Unknown and
    /// "not sure" count as under 37 weeks.
    public var termAnswer: TermAnswer?
    /// Journey time to the maternity unit. Nil if not entered.
    public var travelMinutes: Int?
    /// She carries group B strep. With her waters gone, antibiotics and induction are usually
    /// offered straight away.
    public var gbsPositive: Bool
    /// A caesarean is booked. Labour starting first means calling the unit at once.
    public var plannedCaesarean: Bool

    public init(
        region: ContentRegion,
        parity: Int = 0,
        previousFastLabour: Bool = false,
        gestationalAgeDays: Int? = nil,
        termAnswer: TermAnswer? = nil,
        travelMinutes: Int? = nil,
        gbsPositive: Bool = false,
        plannedCaesarean: Bool = false
    ) {
        self.region = region
        self.parity = parity
        self.previousFastLabour = previousFastLabour
        self.gestationalAgeDays = gestationalAgeDays
        self.termAnswer = termAnswer
        self.travelMinutes = travelMinutes
        self.gbsPositive = gbsPositive
        self.plannedCaesarean = plannedCaesarean
    }

    /// Profiles saved before GBS and planned caesarean existed decode with both off.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        region = try container.decode(ContentRegion.self, forKey: .region)
        parity = try container.decode(Int.self, forKey: .parity)
        previousFastLabour = try container.decode(Bool.self, forKey: .previousFastLabour)
        gestationalAgeDays = try container.decodeIfPresent(Int.self, forKey: .gestationalAgeDays)
        termAnswer = try? container.decodeIfPresent(TermAnswer.self, forKey: .termAnswer)
        travelMinutes = try container.decodeIfPresent(Int.self, forKey: .travelMinutes)
        gbsPositive = try container.decodeIfPresent(Bool.self, forKey: .gbsPositive) ?? false
        plannedCaesarean = try container.decodeIfPresent(Bool.self, forKey: .plannedCaesarean) ?? false
    }
}

/// Fixed engine rules that are not user-editable. Listed in docs/content-review-log.md for review.
public enum EngineConstants {
    /// Fewer contractions than this in the recent segment can't form a pattern.
    public static let minimumContractions = 4
    /// An open contraction older than this is treated as a forgotten stop for duration statistics.
    public static let forgotStopSec: TimeInterval = 300
    /// Statistics, staleness and the urgent rules look back this far. Fixed: no setting changes it.
    public static let analysisWindowSec: TimeInterval = 3600
    /// The call rule is judged on the contractions in this window (at least `minimumContractions`
    /// of them), so a labour that is speeding up is judged on its current rate.
    public static let rateWindowSec: TimeInterval = 1200
    /// The share of recent intervals that must be at or under the advice interval for frequent but
    /// uneven contractions to meet the call rule.
    public static let rateQuantile = 0.75
    /// A gap within this much of a whole multiple (2× to 5×) of the run's typical interval looks like
    /// missed taps, if the run is otherwise regular and the next gap is back on rhythm. It then
    /// counts as that many intervals in the statistics.
    public static let missedTapTolerance = 0.2
    /// How close to the typical interval the gap after a missed-tap gap must be (as a fraction).
    public static let rhythmTolerance = 0.35
    /// Starts later than this after now are bad timestamps (a clock ahead, an edit on the wrong day):
    /// left out of every statistic and flagged to fix.
    public static let futureToleranceSec: TimeInterval = 60
    /// A start-to-start gap over this many times the run's pace splits the log into a new run.
    public static let gapSplitFactor = 5.0
    /// No start for this many times the pace: ask whether contractions are still coming.
    public static let quietFactor = 3.0
    /// Frequent but uneven contractions also meet a rate when, over at least this many intervals of
    /// the run in the last hour, the average gap is at or under it and no gap is longer than twice
    /// it (coupled contractions).
    public static let frequencyMinimumIntervals = 6
    /// Missed-tap gaps can be at most this share of a run's intervals; more than that is a pattern
    /// (coupled contractions, say), not missing data.
    public static let missedTapMaxShare = 0.25
    /// A second tap this soon after a start is a double-tap, not a 1-second contraction.
    public static let doubleTapSec: TimeInterval = 1.5
    /// `establishing` also covers a regular pattern up to this multiple of the advice interval.
    public static let establishingIntervalFactor = 1.5
    /// How long a lower state's conditions must hold before the advice drops.
    public static let demotionDwellSec: TimeInterval = 900
    /// The window for the "N or more in 10 minutes" rule. Starts are counted in [t, t + 600).
    public static let tenMinutesSec: TimeInterval = 600
    /// Under 37+0 weeks, any labour session means call now.
    public static let termDays = 259
    /// A 999 flag turned off stays up this long, in case it was turned off by mistake.
    public static let emergencyClearHoldSec: TimeInterval = 60
    /// After her waters go, a reminder at this point: induction is usually offered if labour
    /// hasn't started (NICE NG235).
    public static let watersReminderSec: TimeInterval = 24 * 3600
}
