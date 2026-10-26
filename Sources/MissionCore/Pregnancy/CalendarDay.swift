import Foundation

/// A calendar date with no time or time zone, so deadlines never shift across time zones or
/// clock changes. Arithmetic uses a day count on the proleptic Gregorian calendar, so it behaves
/// the same on every platform. Encodes as "YYYY-MM-DD".
public struct CalendarDay: Sendable, Hashable, Comparable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public enum Weekday: Int, Sendable, CaseIterable {
        case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
    }

    /// Returns nil for dates that don't exist, like 30 February.
    public init?(year: Int, month: Int, day: Int) {
        guard (1...12).contains(month), (1...Self.daysIn(month: month, year: year)).contains(day) else {
            return nil
        }
        self.year = year
        self.month = month
        self.day = day
    }

    /// The day `date` falls on in `calendar`'s time zone.
    public init(_ date: Date, in calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(dayNumber: Self.dayNumber(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1))
    }

    /// Days since 1970-01-01.
    public var dayNumber: Int {
        Self.dayNumber(year: year, month: month, day: day)
    }

    public init(dayNumber: Int) {
        // Howard Hinnant's civil_from_days.
        let shifted = dayNumber + 719_468
        let era = (shifted >= 0 ? shifted : shifted - 146_096) / 146_097
        let dayOfEra = shifted - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36_524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let monthIndex = (5 * dayOfYear + 2) / 153
        day = dayOfYear - (153 * monthIndex + 2) / 5 + 1
        month = monthIndex < 10 ? monthIndex + 3 : monthIndex - 9
        year = yearOfEra + era * 400 + (month <= 2 ? 1 : 0)
    }

    public func adding(days: Int) -> CalendarDay {
        CalendarDay(dayNumber: dayNumber + days)
    }

    /// Whole days from this day to `other`; negative if `other` is earlier.
    public func days(until other: CalendarDay) -> Int {
        other.dayNumber - dayNumber
    }

    public var weekday: Weekday {
        // 1970-01-01 was a Thursday.
        let index = ((dayNumber % 7) + 7 + 4) % 7  // 0 = Sunday
        return Weekday(rawValue: index + 1) ?? .sunday
    }

    /// Midnight at the start of this day in `calendar`'s time zone.
    public func startDate(in calendar: Calendar) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    public var description: String {
        let paddedMonth = month < 10 ? "0\(month)" : "\(month)"
        let paddedDay = day < 10 ? "0\(day)" : "\(day)"
        return "\(year)-\(paddedMonth)-\(paddedDay)"
    }

    public static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
        lhs.dayNumber < rhs.dayNumber
    }

    static func dayNumber(year: Int, month: Int, day: Int) -> Int {
        // Howard Hinnant's days_from_civil.
        let shiftedYear = month <= 2 ? year - 1 : year
        let era = (shiftedYear >= 0 ? shiftedYear : shiftedYear - 399) / 400
        let yearOfEra = shiftedYear - era * 400
        let dayOfYear = (153 * (month > 2 ? month - 3 : month + 9) + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    static func daysIn(month: Int, year: Int) -> Int {
        switch month {
        case 2: (year % 4 == 0 && year % 100 != 0) || year % 400 == 0 ? 29 : 28
        case 4, 6, 9, 11: 30
        default: 31
        }
    }
}

extension CalendarDay: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, let day = CalendarDay(year: parts[0], month: parts[1], day: parts[2]) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected YYYY-MM-DD, got \(text)")
        }
        self = day
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
