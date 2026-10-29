import Foundation
import Testing

@testable import MissionCore

private var utc: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
    return calendar
}

@Suite("Triage script")
struct TriageScriptTests {
    private let thresholds = ThresholdTable.builtIn(for: .uk).defaults
    private let details = TriageDetails(
        motherName: "Sam",
        hospitalNumber: "LTH1234567",
        gestationalAge: GestationalAge(weeks: 39, days: 2),
        parity: 0,
        travelMinutes: 25,
        notes: "GBS positive"
    )

    private func script(contractions: [Contraction], events: [TapEvent] = [], now: Double) -> TriageScript {
        let log = EventLog.reduce(events)
        let output = GoNoGoEngine.evaluate(ukInput(contractions, flags: log.activeRedFlags, now: now))
        return TriageScript.build(
            TriageScript.Inputs(
                details: details,
                output: output,
                log: log,
                now: at(now),
                calendar: utc
            ))
    }

    private func value(_ script: TriageScript, _ label: String) -> String? {
        script.lines.first { $0.label == label }?.value
    }

    @Test("Opens with who and how far along")
    func opening() {
        let card = script(contractions: [], now: 0)
        #expect(card.opening == "Hi, I'm calling about Sam. She's 39+2 weeks, first baby.")
    }

    @Test("Summarises the pattern the unit will ask about")
    func pattern() {
        let card = script(contractions: regular(count: 17, every: 240, duration: 50), now: 3900)
        #expect(value(card, "Contractions") == "Every 4 min, lasting about 50 sec, for 65 min, regular")
        #expect(value(card, "Longest") == "50 sec in the last hour")
        #expect(value(card, "Last one")?.hasSuffix("(1 min ago)") == true)
        #expect(value(card, "Journey") == "25 min to the unit")
        #expect(value(card, "Hospital number") == "LTH1234567")
        #expect(value(card, "Notes") == "GBS positive")
    }

    @Test("Waters, colour, bleeding and movements come from the log")
    func redFlagsAndMovements() {
        let session = UUID()
        let events = [
            TapEvent(
                sessionID: session, kind: .redFlag, at: at(600), deviceID: "phone", lamport: 1,
                payload: TapPayload(flag: .watersBroken, isOn: true)),
            TapEvent(
                sessionID: session, kind: .redFlag, at: at(610), deviceID: "phone", lamport: 2,
                payload: TapPayload(flag: .watersColoured, isOn: true)),
            TapEvent(sessionID: session, kind: .movement, at: at(900), deviceID: "phone", lamport: 3),
        ]
        let card = script(contractions: [], events: events, now: 2400)
        // No time given: the tap is the latest they could have gone.
        #expect(value(card, "Waters") == "Broke by 08:10 (30 min ago), time not confirmed, green, brown or smelly")
        #expect(card.lines.first { $0.label == "Waters" }?.isUrgent == true)
        #expect(value(card, "Bleeding") == "None")
        #expect(value(card, "Baby's movements") == "Last felt at 08:15 (25 min ago)")
        #expect(card.lines.first?.label != "Pushing")
    }

    @Test("Unknowns are prompts, not guesses")
    func unknowns() {
        let card = script(contractions: [], now: 0)
        #expect(value(card, "Contractions") == "None timed yet")
        #expect(value(card, "Waters") == "Not broken, as far as we know")
        #expect(value(card, "Baby's movements") == "Ask her when she last felt the baby move")
    }

    @Test("Emergencies go to the top")
    func emergenciesFirst() {
        let event = TapEvent(
            sessionID: UUID(), kind: .redFlag, at: at(0), deviceID: "phone", lamport: 1,
            payload: TapPayload(flag: .urgeToPush, isOn: true))
        let card = script(contractions: [], events: [event], now: 60)
        #expect(card.lines.first?.label == "Pushing")
        #expect(card.lines.first?.isUrgent == true)
    }

    @Test("Script copy never says what stage she's in")
    func noDiagnosis() {
        let card = script(contractions: regular(count: 17, every: 240, duration: 50), now: 3900)
        let text = ([card.opening] + card.lines.map { "\($0.label) \($0.value)" }).joined(separator: " ").lowercased()
        for phrase in StateCopyTests.forbidden {
            #expect(!text.contains(phrase))
        }
    }

    @Test("Relative times read naturally")
    func relativeTimes() {
        #expect(TriageScript.ago(at(0), now: at(30), calendar: utc) == "at 08:00 (just now)")
        #expect(TriageScript.ago(at(0), now: at(3600 * 2 + 600), calendar: utc) == "at 08:00 (2 h 10 min ago)")
        #expect(TriageScript.ago(at(0), now: at(3600), calendar: utc) == "at 08:00 (1 h ago)")
    }
}

@Suite("Alert planner")
struct LabourAlertPlannerTests {
    private let thresholds = ThresholdTable.builtIn(for: .uk).defaults

    @Test("A rise to an actionable state alerts at once")
    func immediateRise() {
        let output = GoNoGoEngine.evaluate(ukInput([], flags: [.watersBroken], now: 60))
        let alerts = LabourAlertPlanner.immediate(previous: nil, output: output, region: .uk)
        let alert = alerts.first
        #expect(alerts.count == 1)
        #expect(alert?.kind == .rise)
        #expect(alert?.title == "Call your maternity unit now")
        #expect(alert?.body.hasPrefix("Her waters have broken.") == true)
    }

    @Test("No alert without a rise, or for early and establishing")
    func noAlert() {
        let urgent = GoNoGoEngine.evaluate(ukInput([], flags: [.watersBroken], now: 60))
        let again = GoNoGoEngine.evaluate(ukInput([], flags: [.watersBroken], previous: urgent.snapshot, now: 120))
        #expect(LabourAlertPlanner.immediate(previous: urgent.snapshot, output: again, region: .uk).isEmpty)
        let building = GoNoGoEngine.evaluate(ukInput(regular(count: 8, every: 360, duration: 50), now: 2600))
        #expect(building.state == .establishing)
        #expect(LabourAlertPlanner.immediate(previous: nil, output: building, region: .uk).isEmpty)
    }

    @Test("Schedules the moment the pattern reaches its hour")
    func scheduledSustained() {
        let input = ukInput(regular(count: 15, every: 240, duration: 50), thresholds: ukWithHour, now: 3540)
        let output = GoNoGoEngine.evaluate(input)
        let alerts = LabourAlertPlanner.scheduled(input: input, output: output)
        #expect(alerts.count == 1)
        #expect(alerts.first?.kind == .scheduledRise)
        #expect(alerts.first?.fireAt == at(3600))
        #expect(alerts.first?.title == "Time to call your maternity unit")
    }

    @Test("An open contraction gets one alert when it passes 2 minutes")
    func openContraction() {
        let open = Contraction(start: at(1000), end: nil)
        let input = ukInput([open], now: 1030)
        let alerts = LabourAlertPlanner.scheduled(input: input, output: GoNoGoEngine.evaluate(input))
        #expect(alerts.count == 1)
        #expect(alerts.first?.fireAt == at(1121))
        #expect(alerts.first?.kind == .scheduledRise)
        #expect(alerts.first?.body.contains("forgot to stop") == true)
    }

    @Test("Already at call now: the still-going nudge still fires")
    func stillGoingWhenAlreadyUrgent() {
        let open = Contraction(start: at(1000), end: nil)
        let input = ukInput([open], flags: [.watersBroken], now: 1030)
        let alerts = LabourAlertPlanner.scheduled(input: input, output: GoNoGoEngine.evaluate(input))
        #expect(alerts.map(\.kind) == [.stillGoing])
        #expect(alerts.first?.fireAt == at(1121))
    }

    @Test("Nothing to schedule once the pattern has gone quiet")
    func nothingScheduled() {
        let input = ukInput(regular(count: 4, every: 600, duration: 40), now: 3000)
        let alerts = LabourAlertPlanner.scheduled(input: input, output: GoNoGoEngine.evaluate(input))
        #expect(alerts.isEmpty)
    }
}

@Suite("Movement events")
struct MovementEventTests {
    @Test("The latest movement wins, and undo removes it")
    func movement() {
        let session = UUID()
        let first = TapEvent(sessionID: session, kind: .movement, at: at(100), deviceID: "phone", lamport: 1)
        let second = TapEvent(sessionID: session, kind: .movement, at: at(500), deviceID: "phone", lamport: 2)
        #expect(EventLog.reduce([first, second]).lastMovementAt == at(500))
        let undo = TapEvent(
            sessionID: session, kind: .undo, at: at(501), deviceID: "phone", lamport: 3, target: second.id)
        #expect(EventLog.reduce([first, second, undo]).lastMovementAt == at(100))
    }
}
