import Foundation

/// Weeks and days of pregnancy, written the way midwives do: 36+6.
public struct GestationalAge: Codable, Sendable, Hashable, Comparable, CustomStringConvertible {
    public var totalDays: Int

    public init(totalDays: Int) {
        self.totalDays = totalDays
    }

    public init(weeks: Int, days: Int) {
        totalDays = weeks * 7 + days
    }

    /// Completed weeks. Rounds towards negative infinity, so day -1 is week -1.
    public var weeks: Int { Int((Double(totalDays) / 7).rounded(.down)) }
    public var days: Int { totalDays - weeks * 7 }

    public var description: String { "\(weeks)+\(days)" }

    public static func < (lhs: GestationalAge, rhs: GestationalAge) -> Bool {
        lhs.totalDays < rhs.totalDays
    }
}

/// Dates that follow from the due date: gestational age, the expected week of childbirth and
/// every deadline anchored to them.
///
/// UK employment law counts weeks from Sunday to Saturday. The expected week of childbirth (EWC)
/// is the Sunday-to-Saturday week containing the due date. The qualifying week is the 15th week
/// before it, and paternity leave notice is due by the end of that week. Acas worked example:
/// due Friday 1 May 2026 → qualifying week Sunday 11 to Saturday 17 January 2026.
public struct PregnancyCalendar: Codable, Sendable, Hashable {
    /// 40+0 weeks, counted from the first day of the last period.
    public static let termLengthDays = 280

    public var dueDate: CalendarDay

    public init(dueDate: CalendarDay) {
        self.dueDate = dueDate
    }

    /// The due date from a scan, e.g. a dating scan on `scanDay` that measured 12+3.
    public init(scanDay: CalendarDay, gestationalAgeAtScan: GestationalAge) {
        dueDate = scanDay.adding(days: Self.termLengthDays - gestationalAgeAtScan.totalDays)
    }

    /// Day 0+0 of the pregnancy.
    public var pregnancyStart: CalendarDay {
        dueDate.adding(days: -Self.termLengthDays)
    }

    public func gestationalAge(on day: CalendarDay) -> GestationalAge {
        GestationalAge(totalDays: pregnancyStart.days(until: day))
    }

    /// Gestational age in days at a moment, for `LabourProfile.gestationalAgeDays`.
    public func gestationalAgeDays(at date: Date, in calendar: Calendar) -> Int {
        gestationalAge(on: CalendarDay(date, in: calendar)).totalDays
    }

    /// The first day of gestational week `week` (week+0).
    public func firstDay(ofWeek week: Int) -> CalendarDay {
        pregnancyStart.adding(days: week * 7)
    }

    /// Days to T-0. Negative once the due date has passed.
    public func daysToDueDate(from day: CalendarDay) -> Int {
        day.days(until: dueDate)
    }

    /// The Sunday that starts the week the baby is due.
    public var expectedWeekOfChildbirth: CalendarDay {
        dueDate.adding(days: -(dueDate.weekday.rawValue - CalendarDay.Weekday.sunday.rawValue))
    }

    /// The 15th week before the EWC, Sunday to Saturday. Paternity and maternity pay eligibility
    /// is tested in this week, and both parents must tell their employers by the end of it.
    public var qualifyingWeek: ClosedRange<CalendarDay> {
        let start = expectedWeekOfChildbirth.adding(days: -15 * 7)
        return start...start.adding(days: 6)
    }

    /// The last day to give paternity leave notice: the Saturday that ends the qualifying week.
    public var paternityNoticeDeadline: CalendarDay {
        qualifyingWeek.upperBound
    }

    /// The day a deadline falls on. Birth-anchored deadlines are nil until the baby is born.
    public func day(for deadline: Deadline, birthDay: CalendarDay? = nil) -> CalendarDay? {
        let anchor: CalendarDay? =
            switch deadline.anchor {
            case .ewc: expectedWeekOfChildbirth
            case .edd: dueDate
            case .birth: birthDay
            }
        return anchor?.adding(days: deadline.offsetDays)
    }

    /// Reminder days for a deadline, earliest first.
    public func reminderDays(
        for deadline: Deadline,
        daysBefore: [Int],
        birthDay: CalendarDay? = nil
    ) -> [CalendarDay] {
        guard let due = day(for: deadline, birthDay: birthDay) else { return [] }
        return Set(daysBefore).map { due.adding(days: -$0) }.sorted()
    }

    /// A checklist item shows from its unlock week. Everything is unlocked once the baby is born.
    public func isUnlocked(_ item: ChecklistItem, on day: CalendarDay, birthDay: CalendarDay? = nil) -> Bool {
        if let birthDay, day >= birthDay { return true }
        return gestationalAge(on: day).weeks >= item.unlockWeek
    }
}
