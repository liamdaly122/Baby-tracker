import Foundation

/// The five stages of the rocket on the home screen, each a stretch of the pregnancy. Ported from
/// the prototype's home.js and made fair (review action 19: ux-07, ux-08, content-06, TCI-07).
public enum BuildStage: Int, Codable, Sendable, CaseIterable, Comparable {
    case launchComplex
    case firstStage
    case secondStage
    case capsule
    case parachutes

    /// The first week the stage opens. The parachutes open at the birth, not by week.
    public var startWeek: Int? {
        switch self {
        case .launchComplex: 4
        case .firstStage: 14
        case .secondStage: 28
        case .capsule: 35
        case .parachutes: nil
        }
    }

    public var name: String {
        switch self {
        case .launchComplex: "Launch complex"
        case .firstStage: "First stage"
        case .secondStage: "Second stage"
        case .capsule: "Crew capsule"
        case .parachutes: "Parachute bay"
        }
    }

    public var weeks: String {
        switch self {
        case .launchComplex: "Weeks 4 to 13"
        case .firstStage: "Weeks 14 to 27"
        case .secondStage: "Weeks 28 to 34"
        case .capsule: "Weeks 35 to 40"
        case .parachutes: "After the birth"
        }
    }

    /// The stage an item belongs to, from the week it opens. After-birth items are the parachutes.
    public static func of(_ item: ChecklistItem) -> BuildStage {
        if item.module == .splashdown { return .parachutes }
        switch item.unlockWeek {
        case ...13: return .launchComplex
        case ...27: return .firstStage
        case ...34: return .secondStage
        default: return .capsule
        }
    }

    /// The stage by week, before the birth.
    public static func current(week: Int) -> BuildStage {
        switch week {
        case ...13: .launchComplex
        case ...27: .firstStage
        case ...34: .secondStage
        default: .capsule
        }
    }

    public var next: BuildStage? { BuildStage(rawValue: rawValue + 1) }

    public static func < (lhs: BuildStage, rhs: BuildStage) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// What he has said about a checklist item.
public enum ItemState: String, Codable, Sendable, CaseIterable {
    case open
    case done
    /// "Doesn't apply to us": self-employed, no car, no pets, her own choice. Out of the count.
    case notForUs
    /// "Missed it": the moment has gone. Never blocks anything; the app suggests what to do instead.
    case missed

    /// Whether it still needs doing.
    public var isOutstanding: Bool { self == .open }
}

/// How a stage of the build stands.
public enum StageStatus: Equatable, Sendable {
    /// Not open yet.
    case locked
    /// Open, with must-dos still to do.
    case active
    /// Every must-do done, or cleared as not for us or missed: "GO" on the rocket.
    case ready
    /// Open, but waiting on must-dos from an earlier stage. Its own items can still be ticked.
    case hold(waitingOn: BuildStage)
}

/// The fair stage rules. Pure: the app passes in the items, what he's said about each, the week,
/// and whether the baby is born.
///
/// Compared with the prototype:
/// - Only must-dos (in his control, marked `must` in the content) can cause a HOLD. Her clinical
///   decisions, such as vaccines, are information, not must-dos.
/// - "Doesn't apply to us" and "Missed it" clear a must-do, so a self-employed dad or a late
///   starter is never stuck.
/// - A stage gets two weeks' grace before an earlier stage can hold it.
/// - Stages that had already ended when he joined never hold anything: their must-dos are a
///   catch-up list instead.
/// - The parachutes open at the birth and are never on HOLD: the baby comes regardless.
/// - Nothing is locked from ticking, except things that can only happen after the birth.
/// - A held stage still shows how much of it is done.
public struct BuildProgress: Sendable {
    public var items: [ChecklistItem]
    public var states: [String: ItemState]
    /// Completed weeks of pregnancy today.
    public var week: Int
    public var isBorn: Bool
    /// The week he started using the app, for late starters.
    public var startedAtWeek: Int

    /// How long a newly opened stage runs before an earlier stage's must-dos can hold it.
    public static let holdGraceWeeks = 2

    public init(
        items: [ChecklistItem], states: [String: ItemState], week: Int, isBorn: Bool, startedAtWeek: Int? = nil
    ) {
        self.items = items
        self.states = states
        self.week = week
        self.isBorn = isBorn
        self.startedAtWeek = startedAtWeek ?? week
    }

    public func state(of item: ChecklistItem) -> ItemState {
        states[item.id] ?? .open
    }

    public func items(in stage: BuildStage) -> [ChecklistItem] {
        items.filter { BuildStage.of($0) == stage }
    }

    /// Must-dos in a stage that still need doing.
    public func mustDosLeft(in stage: BuildStage) -> [ChecklistItem] {
        items(in: stage).filter { $0.isMust && state(of: $0).isOutstanding }
    }

    public func isOpen(_ stage: BuildStage) -> Bool {
        guard let start = stage.startWeek else { return isBorn }
        return isBorn || week >= start
    }

    /// Whether a stage had already ended before he started, so it can't hold anything.
    public func endedBeforeStart(_ stage: BuildStage) -> Bool {
        guard let nextStart = stage.next?.startWeek else { return false }
        return startedAtWeek >= nextStart
    }

    public func status(of stage: BuildStage) -> StageStatus {
        guard isOpen(stage) else { return .locked }
        if let blocker = holdingStage(for: stage) {
            return .hold(waitingOn: blocker)
        }
        return mustDosLeft(in: stage).isEmpty ? .ready : .active
    }

    /// The earliest earlier stage whose must-dos are holding this one, if any.
    private func holdingStage(for stage: BuildStage) -> BuildStage? {
        guard stage != .parachutes, let start = stage.startWeek, !isBorn,
            week >= start + Self.holdGraceWeeks
        else { return nil }
        return BuildStage.allCases.first { earlier in
            earlier < stage && !endedBeforeStart(earlier) && !mustDosLeft(in: earlier).isEmpty
        }
    }

    /// How much of a stage is done, from 0 to 1, out of the items that apply. Shown even on HOLD.
    public func paint(_ stage: BuildStage) -> Double {
        let applicable = items(in: stage).filter { state(of: $0) != .notForUs }
        guard !applicable.isEmpty else { return 1 }
        return Double(applicable.filter { state(of: $0) == .done }.count) / Double(applicable.count)
    }

    /// The stage to show first: the one an earlier HOLD is waiting on, otherwise where he is now.
    public var focus: BuildStage {
        if isBorn { return .parachutes }
        let current = BuildStage.current(week: week)
        if case .hold(let waitingOn) = status(of: current) { return waitingOn }
        return current
    }

    /// Must-dos from stages that ended before he joined, still worth a look. They never block.
    public var catchUp: [ChecklistItem] {
        BuildStage.allCases.filter(endedBeforeStart).flatMap(mustDosLeft(in:))
    }

    /// Whether he can tick an item now. Only things that can't happen before the birth wait for it.
    public func canTick(_ item: ChecklistItem) -> Bool {
        item.deadline?.anchor != .birth || isBorn
    }
}

/// When an item is due, in words that never shame. "Late" says what to do, not how late he is.
public enum DueLabel: Equatable, Sendable {
    case none
    /// Opens in a later week. Still tickable now.
    case fromWeek(Int)
    case inDays(Int)
    case today
    /// Past its date: do it now.
    case late
    case afterBirth

    public static func of(
        _ item: ChecklistItem, state: ItemState, week: Int, today: CalendarDay, calendar: PregnancyCalendar?,
        birthDay: CalendarDay? = nil
    ) -> DueLabel {
        guard state == .open else { return .none }
        if let deadline = item.deadline {
            guard let calendar, let due = calendar.day(for: deadline, birthDay: birthDay) else {
                return deadline.anchor == .birth ? .afterBirth : .none
            }
            let days = today.days(until: due)
            if days < 0 { return .late }
            return days == 0 ? .today : .inDays(days)
        }
        return item.unlockWeek > week ? .fromWeek(item.unlockWeek) : .none
    }

    public var text: String? {
        switch self {
        case .none: nil
        case .fromWeek(let week): "From week \(week)"
        case .inDays(let days): days == 1 ? "Tomorrow" : "\(days) days"
        case .today: "Today"
        case .late: "Past the date: still worth doing now"
        case .afterBirth: "After the birth"
        }
    }
}
