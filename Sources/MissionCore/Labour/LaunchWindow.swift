import Foundation

/// What the launch card offers at this week. LAUNCH is the same full-size key at every week: a
/// preterm labour must open real labour mode with the gesture he has rehearsed. Only the practice
/// run moves. From 30+0 to 36+6, and when the weeks aren't known, a smaller "Run the drill" key sits
/// under LAUNCH. From 37+0 (the engine's term rule) the drill moves to the training hangar, behind
/// "Is she having contractions now?". Before 30 weeks there's no drill.
public enum LaunchWindow: Sendable, Equatable {
    case beforeDrill
    case drill
    case term

    /// When the drill unlocks: 30+0.
    public static let drillFromDays = 210

    public init(gestationalAgeDays: Int?) {
        guard let days = gestationalAgeDays else {
            self = .drill
            return
        }
        if days >= EngineConstants.termDays {
            self = .term
        } else if days >= Self.drillFromDays {
            self = .drill
        } else {
            self = .beforeDrill
        }
    }

    /// The drill key sits on the launch card, under LAUNCH.
    public var drillOnLaunchCard: Bool { self == .drill }

    /// The drill is in the training hangar, away from the launch card.
    public var drillInHangar: Bool { self == .term }

    /// Under LAUNCH. Window wording only ever says when births are most likely, never that it's
    /// too early to launch.
    public var launchSubtitle: String {
        switch self {
        case .beforeDrill, .drill: "Labour started? Any week."
        case .term: "Labour started? Launch window open."
        }
    }
}
