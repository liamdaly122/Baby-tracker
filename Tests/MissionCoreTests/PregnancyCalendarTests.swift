import Foundation
import Testing

@testable import MissionCore

private func day(_ year: Int, _ month: Int, _ day: Int) -> CalendarDay {
    guard let value = CalendarDay(year: year, month: month, day: day) else {
        preconditionFailure("invalid test date \(year)-\(month)-\(day)")
    }
    return value
}

@Suite("Calendar days")
struct CalendarDayTests {
    @Test("Day numbers round-trip across centuries, leap days and month ends")
    func roundTrip() {
        for number in stride(from: -800_000, through: 800_000, by: 997) {
            let value = CalendarDay(dayNumber: number)
            #expect(value.dayNumber == number)
            #expect(CalendarDay(year: value.year, month: value.month, day: value.day) == value)
        }
        #expect(day(1970, 1, 1).dayNumber == 0)
        #expect(day(2028, 2, 28).adding(days: 1) == day(2028, 2, 29))
        #expect(day(2027, 2, 28).adding(days: 1) == day(2027, 3, 1))
        #expect(day(2026, 12, 31).adding(days: 1) == day(2027, 1, 1))
    }

    @Test("Impossible dates are rejected")
    func impossibleDates() {
        #expect(CalendarDay(year: 2027, month: 2, day: 29) == nil)
        #expect(CalendarDay(year: 2100, month: 2, day: 29) == nil)
        #expect(CalendarDay(year: 2000, month: 2, day: 29) != nil)
        #expect(CalendarDay(year: 2026, month: 13, day: 1) == nil)
        #expect(CalendarDay(year: 2026, month: 4, day: 31) == nil)
    }

    @Test("Weekdays")
    func weekdays() {
        #expect(day(1970, 1, 1).weekday == .thursday)
        #expect(day(2026, 10, 26).weekday == .monday)
        #expect(day(2026, 5, 1).weekday == .friday)
        #expect(day(1969, 12, 31).weekday == .wednesday)
    }

    @Test("Encodes as YYYY-MM-DD")
    func codable() throws {
        let data = try JSONEncoder().encode([day(2026, 5, 1)])
        #expect(String(bytes: data, encoding: .utf8) == #"["2026-05-01"]"#)
        #expect(try JSONDecoder().decode([CalendarDay].self, from: data) == [day(2026, 5, 1)])
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode([CalendarDay].self, from: Data(#"["2026-02-30"]"#.utf8))
        }
    }

    @Test("A moment maps to its day in the calendar's time zone")
    func fromDate() throws {
        var london = Calendar(identifier: .gregorian)
        london.timeZone = try #require(TimeZone(identifier: "Europe/London"))
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = try #require(TimeZone(identifier: "UTC"))
        // 23:30 UTC on 30 June 2026 is 00:30 on 1 July in London (BST).
        let moment = try #require(utc.date(from: DateComponents(year: 2026, month: 6, day: 30, hour: 23, minute: 30)))
        #expect(CalendarDay(moment, in: utc) == day(2026, 6, 30))
        #expect(CalendarDay(moment, in: london) == day(2026, 7, 1))
    }
}

@Suite("Pregnancy calendar")
struct PregnancyCalendarTests {
    @Test("Acas worked example: due 1 May 2026")
    func acasExample() {
        let calendar = PregnancyCalendar(dueDate: day(2026, 5, 1))
        #expect(calendar.expectedWeekOfChildbirth == day(2026, 4, 26))
        #expect(calendar.qualifyingWeek == day(2026, 1, 11)...day(2026, 1, 17))
        #expect(calendar.paternityNoticeDeadline == day(2026, 1, 17))
        #expect(calendar.paternityNoticeDeadline.weekday == .saturday)
    }

    @Test("The EWC starts on the Sunday on or before the due date", arguments: 0..<7)
    func ewcIsSunday(offset: Int) {
        let due = day(2027, 3, 7).adding(days: offset)  // 7 March 2027 is a Sunday
        let ewc = PregnancyCalendar(dueDate: due).expectedWeekOfChildbirth
        #expect(ewc == day(2027, 3, 7))
        #expect(ewc.weekday == .sunday)
    }

    @Test("Paternity notice deadline is the EWC minus 99 days, about 25+6 weeks")
    func paternityDeadline() {
        for offset in 0..<14 {
            let calendar = PregnancyCalendar(dueDate: day(2027, 3, 7).adding(days: offset))
            #expect(calendar.expectedWeekOfChildbirth.days(until: calendar.paternityNoticeDeadline) == -99)
            let age = calendar.gestationalAge(on: calendar.paternityNoticeDeadline)
            #expect(age >= GestationalAge(weeks: 25, days: 0) && age <= GestationalAge(weeks: 25, days: 6))
        }
    }

    @Test("Gestational age at week boundaries")
    func weekBoundaries() {
        let calendar = PregnancyCalendar(dueDate: day(2027, 3, 10))
        #expect(calendar.gestationalAge(on: day(2027, 3, 10)).description == "40+0")
        #expect(calendar.gestationalAge(on: day(2027, 3, 9)).description == "39+6")
        #expect(calendar.gestationalAge(on: day(2027, 2, 17)).description == "37+0")
        #expect(calendar.gestationalAge(on: day(2027, 2, 16)).description == "36+6")
        #expect(calendar.gestationalAge(on: day(2027, 3, 17)).description == "41+0")
        #expect(calendar.firstDay(ofWeek: 37) == day(2027, 2, 17))
        #expect(calendar.pregnancyStart.adding(days: -1) == calendar.firstDay(ofWeek: 0).adding(days: -1))
        #expect(GestationalAge(totalDays: -1).description == "-1+6")
    }

    @Test("Due date from a dating scan")
    func dueDateFromScan() {
        let calendar = PregnancyCalendar(
            scanDay: day(2026, 9, 1), gestationalAgeAtScan: GestationalAge(weeks: 12, days: 3))
        #expect(calendar.gestationalAge(on: day(2026, 9, 1)).description == "12+3")
        #expect(calendar.dueDate == day(2027, 3, 13))
    }

    @Test("Countdown to T-0")
    func countdown() {
        let calendar = PregnancyCalendar(dueDate: day(2027, 3, 10))
        #expect(calendar.daysToDueDate(from: day(2027, 3, 1)) == 9)
        #expect(calendar.daysToDueDate(from: day(2027, 3, 12)) == -2)
    }

    @Test("Deadlines by anchor; birth-anchored ones wait for the birth")
    func deadlines() {
        let calendar = PregnancyCalendar(dueDate: day(2026, 5, 1))
        #expect(calendar.day(for: Deadline(anchor: .ewc, offsetDays: -99)) == day(2026, 1, 17))
        #expect(calendar.day(for: Deadline(anchor: .edd, offsetDays: -28)) == day(2026, 4, 3))
        #expect(calendar.day(for: Deadline(anchor: .birth, offsetDays: 42)) == nil)
        #expect(
            calendar.day(for: Deadline(anchor: .birth, offsetDays: 42), birthDay: day(2026, 5, 4)) == day(2026, 6, 15))
    }

    @Test("Reminders come before the deadline, earliest first, without duplicates")
    func reminders() {
        let calendar = PregnancyCalendar(dueDate: day(2026, 5, 1))
        let reminders = calendar.reminderDays(for: Deadline(anchor: .ewc, offsetDays: -99), daysBefore: [1, 14, 7, 7])
        #expect(reminders == [day(2026, 1, 3), day(2026, 1, 10), day(2026, 1, 16)])
        #expect(calendar.reminderDays(for: Deadline(anchor: .birth, offsetDays: 42), daysBefore: [7]).isEmpty)
    }

    @Test("Items unlock at their week, and everything unlocks after the birth")
    func unlocking() {
        let calendar = PregnancyCalendar(dueDate: day(2027, 3, 10))
        let item = ChecklistItem(
            id: "test.item",
            module: .hospitalBag,
            title: LocalizedCopy(off: "Pack"),
            why: LocalizedCopy(off: "Because"),
            clinicalText: nil,
            unlockWeek: 32,
            deadline: nil,
            reminderDaysBefore: [],
            quizID: nil,
            xp: 5,
            provenance: nil
        )
        #expect(!calendar.isUnlocked(item, on: calendar.firstDay(ofWeek: 31).adding(days: 6)))
        #expect(calendar.isUnlocked(item, on: calendar.firstDay(ofWeek: 32)))
        let early = day(2026, 12, 1)
        #expect(calendar.isUnlocked(item, on: early, birthDay: day(2026, 11, 30)))
    }
}
