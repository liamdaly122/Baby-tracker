import Foundation
import Testing

@testable import MissionCore

/// A checklist item for these tests.
private func item(
    _ id: String, week: Int, must: Bool = false, module: ChecklistModule = .adminAndLeave,
    deadline: Deadline? = nil
) -> ChecklistItem {
    ChecklistItem(
        id: id, module: module, title: LocalizedCopy(off: id), why: LocalizedCopy(off: "Because"),
        clinicalText: nil, unlockWeek: week, deadline: deadline, reminderDaysBefore: [], quizID: nil, xp: 5,
        provenance: nil, must: must)
}

/// A small build: one must-do and one other item per stage, and two after-birth items.
private let sample: [ChecklistItem] = [
    item("pad.must", week: 6, must: true), item("pad.other", week: 8),
    item("one.must", week: 14, must: true), item("one.other", week: 20),
    item("two.must", week: 30, must: true), item("two.other", week: 32),
    item("capsule.must", week: 36, must: true), item("capsule.other", week: 37),
    item("chutes.learn", week: 36, must: true, module: .splashdown),
    item(
        "chutes.register", week: 36, must: true, module: .splashdown,
        deadline: Deadline(anchor: .birth, offsetDays: 42)),
]

@Suite("Build stages")
struct BuildProgressTests {
    @Test("Each stage opens on its week, and the parachutes only at the birth")
    func opening() {
        let progress = BuildProgress(items: sample, states: [:], week: 13, isBorn: false)
        #expect(progress.status(of: .firstStage) == .locked)
        #expect(BuildProgress(items: sample, states: [:], week: 14, isBorn: false).isOpen(.firstStage))
        let late = BuildProgress(items: sample, states: [:], week: 42, isBorn: false)
        #expect(late.status(of: .parachutes) == .locked)
        #expect(BuildProgress(items: sample, states: [:], week: 38, isBorn: true).isOpen(.parachutes))
    }

    @Test("A stage gets two weeks' grace, then waits on an earlier must-do; ticking it releases the hold")
    func holdAndRelease() {
        var states: [String: ItemState] = ["pad.must": .done]
        let inGrace = BuildProgress(items: sample, states: states, week: 29, isBorn: false)
        #expect(inGrace.status(of: .secondStage) == .active)
        let held = BuildProgress(items: sample, states: states, week: 30, isBorn: false, startedAtWeek: 6)
        #expect(held.status(of: .secondStage) == .hold(waitingOn: .firstStage))
        #expect(held.focus == .firstStage)
        states["one.must"] = .done
        let released = BuildProgress(items: sample, states: states, week: 30, isBorn: false, startedAtWeek: 6)
        #expect(released.status(of: .secondStage) == .active)
        #expect(released.status(of: .firstStage) == .ready)
        #expect(released.focus == .secondStage)
    }

    @Test("Only must-dos hold; 'Doesn't apply to us' and 'Missed it' clear them")
    func clearing() {
        let open = BuildProgress(items: sample, states: ["pad.must": .done], week: 31, isBorn: false, startedAtWeek: 6)
        #expect(open.status(of: .secondStage) == .hold(waitingOn: .firstStage))
        for cleared in [ItemState.notForUs, .missed] {
            let progress = BuildProgress(
                items: sample, states: ["pad.must": .done, "one.must": cleared], week: 31, isBorn: false,
                startedAtWeek: 6)
            #expect(progress.status(of: .secondStage) == .active, "\(cleared)")
            #expect(progress.status(of: .firstStage) == .ready)
        }
        // The optional item left undone in stage 1 never holds anything.
        let others = BuildProgress(
            items: sample, states: ["pad.must": .done, "one.must": .done], week: 31, isBorn: false, startedAtWeek: 6)
        #expect(others.status(of: .secondStage) == .active)
    }

    @Test("A late starter is never held by stages that ended before he joined; they're a catch-up list")
    func lateStarter() {
        let progress = BuildProgress(items: sample, states: [:], week: 31, isBorn: false, startedAtWeek: 30)
        #expect(progress.status(of: .secondStage) == .active)
        #expect(progress.catchUp.map(\.id) == ["pad.must", "one.must"])
        #expect(progress.focus == .secondStage)
    }

    @Test("The parachutes are never on hold: the baby comes regardless")
    func parachutesNeverHeld() {
        let progress = BuildProgress(items: sample, states: [:], week: 39, isBorn: true, startedAtWeek: 6)
        #expect(progress.status(of: .parachutes) == .active)
        #expect(progress.focus == .parachutes)
    }

    @Test("A held stage still shows how much of it is done, and 'not for us' items are out of the count")
    func paintUnderHold() {
        let progress = BuildProgress(
            items: sample, states: ["two.other": .done], week: 31, isBorn: false, startedAtWeek: 6)
        guard case .hold = progress.status(of: .secondStage) else {
            Issue.record("Expected a hold")
            return
        }
        #expect(progress.paint(.secondStage) == 0.5)
        let cleared = BuildProgress(items: sample, states: ["two.other": .notForUs], week: 31, isBorn: false)
        #expect(cleared.paint(.secondStage) == 0)
        let allCleared = BuildProgress(
            items: sample, states: ["two.must": .notForUs, "two.other": .notForUs], week: 31, isBorn: false)
        #expect(allCleared.paint(.secondStage) == 1)
    }

    /// At every week from 4 to 42, whatever is ticked: nothing is locked but after-birth items, holds name a stage
    /// with must-dos left, and clearing every must-do releases every hold.
    @Test("Every week, any ticks: fair locks and holds", arguments: Array(4...42))
    func everyWeek(week: Int) {
        var generator = SeededGenerator(seed: UInt64(week))
        for _ in 0..<50 {
            var states: [String: ItemState] = [:]
            for item in sample {
                states[item.id] = ItemState.allCases.randomElement(using: &generator)
            }
            let started = Int.random(in: 4...week, using: &generator)
            for born in [false, true] {
                let progress = BuildProgress(
                    items: sample, states: states, week: week, isBorn: born, startedAtWeek: started)
                for item in sample {
                    let birthOnly = item.deadline?.anchor == .birth
                    #expect(progress.canTick(item) == (!birthOnly || born), "\(item.id) at \(week)")
                }
                for stage in BuildStage.allCases {
                    let paint = progress.paint(stage)
                    #expect((0...1).contains(paint))
                    if case .hold(let waitingOn) = progress.status(of: stage) {
                        #expect(waitingOn < stage)
                        #expect(!progress.mustDosLeft(in: waitingOn).isEmpty)
                        #expect(stage != .parachutes)
                    }
                }
                var cleared = states
                for item in sample where item.isMust && progress.state(of: item) == .open {
                    cleared[item.id] = .missed
                }
                let released = BuildProgress(
                    items: sample, states: cleared, week: week, isBorn: born, startedAtWeek: started)
                for stage in BuildStage.allCases {
                    if case .hold = released.status(of: stage) {
                        Issue.record("\(stage) still on hold at week \(week) with every must-do cleared")
                    }
                }
            }
        }
    }

    @Test("Due dates never shame: late says what to do, not how many days")
    func dueLabels() throws {
        let calendar = PregnancyCalendar(dueDate: try #require(CalendarDay(year: 2027, month: 1, day: 31)))
        let today = calendar.firstDay(ofWeek: 30)
        let bag = item("bag", week: 32, deadline: Deadline(anchor: .edd, offsetDays: -28))
        let notice = item("notice", week: 20, deadline: Deadline(anchor: .ewc, offsetDays: -99))
        #expect(DueLabel.of(bag, state: .open, week: 30, today: today, calendar: calendar) == .inDays(42))
        #expect(DueLabel.of(notice, state: .open, week: 30, today: today, calendar: calendar) == .late)
        #expect(DueLabel.late.text == "Past the date: still worth doing now")
        #expect(DueLabel.of(notice, state: .done, week: 30, today: today, calendar: calendar) == .none)
        let later = item("later", week: 34)
        #expect(DueLabel.of(later, state: .open, week: 30, today: today, calendar: calendar) == .fromWeek(34))
        let register = try #require(sample.last)
        #expect(DueLabel.of(register, state: .open, week: 39, today: today, calendar: calendar) == .afterBirth)
        for label in [DueLabel.fromWeek(3), .inDays(5), .today, .late, .afterBirth] {
            let text = try #require(label.text)
            #expect(!text.lowercased().contains("days late") && !text.lowercased().contains("behind"))
        }
    }
}
