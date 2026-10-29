import Foundation

/// What the partner knows about her, for the call to the maternity unit.
public struct TriageDetails: Codable, Sendable, Hashable {
    public var motherName: String
    public var hospitalNumber: String
    /// Gestational age when labour mode started. Nil if there's no due date.
    public var gestationalAge: GestationalAge?
    /// The answer to "Is she 37 weeks or more?" when there's no due date.
    public var termAnswer: TermAnswer?
    /// Previous births.
    public var parity: Int
    public var previousFastLabour: Bool
    public var travelMinutes: Int?
    /// Anything in her notes the unit should hear, e.g. "previous caesarean".
    public var notes: String
    public var gbsPositive: Bool
    public var plannedCaesarean: Bool

    public init(
        motherName: String = "",
        hospitalNumber: String = "",
        gestationalAge: GestationalAge? = nil,
        termAnswer: TermAnswer? = nil,
        parity: Int = 0,
        previousFastLabour: Bool = false,
        travelMinutes: Int? = nil,
        notes: String = "",
        gbsPositive: Bool = false,
        plannedCaesarean: Bool = false
    ) {
        self.motherName = motherName
        self.hospitalNumber = hospitalNumber
        self.gestationalAge = gestationalAge
        self.termAnswer = termAnswer
        self.parity = parity
        self.previousFastLabour = previousFastLabour
        self.travelMinutes = travelMinutes
        self.notes = notes
        self.gbsPositive = gbsPositive
        self.plannedCaesarean = plannedCaesarean
    }

    /// These details with the 37-week answer from the log filled in, if there isn't one already.
    public func applying(log: ReducedLog) -> TriageDetails {
        var details = self
        details.termAnswer = termAnswer ?? log.termAnswer
        return details
    }
}

/// A read-aloud card for the triage call, with everything the unit will ask on one screen:
/// contractions (how often, how long, how strong), waters and their colour, bleeding, the baby's
/// movements, and anything in her notes.
public struct TriageScript: Sendable, Hashable {
    public struct Line: Sendable, Hashable {
        public var label: String
        public var value: String
        /// Lines the partner should say first because they change the advice.
        public var isUrgent: Bool
    }

    /// Everything the card is built from. The thresholds come from the engine output, clamped.
    public struct Inputs: Sendable {
        public var details: TriageDetails
        public var output: EngineOutput
        public var log: ReducedLog
        public var now: Date
        public var calendar: Calendar

        public init(details: TriageDetails, output: EngineOutput, log: ReducedLog, now: Date, calendar: Calendar) {
            self.details = details.applying(log: log)
            self.output = output
            self.log = log
            self.now = now
            self.calendar = calendar
        }
    }

    public var opening: String
    public var lines: [Line]

    public static func build(_ inputs: Inputs) -> TriageScript {
        let details = inputs.details
        let output = inputs.output
        let log = inputs.log
        let thresholds = inputs.output.thresholds
        let now = inputs.now
        let calendar = inputs.calendar
        let metrics = output.metrics
        let flags = log.activeRedFlags
        // Urgent facts first.
        var lines = emergencies(flags)

        lines.append(
            Line(label: "Contractions", value: contractionSummary(metrics, thresholds: thresholds), isUrgent: false)
        )
        if let metAt = output.snapshot.callRuleMetAt {
            lines.append(
                Line(
                    label: "Call point", value: "Reached \(ago(metAt, now: now, calendar: calendar))", isUrgent: false
                )
            )
        }
        if let lastStart = metrics.lastStart {
            lines.append(
                Line(
                    label: "Last one", value: "Started \(ago(lastStart, now: now, calendar: calendar))", isUrgent: false
                )
            )
        }
        if let longest = metrics.longestRecentDurationSec {
            let urgent = thresholds.urgentSingleDurationSec
            let seconds = Int(StateCopy.guardedRound(longest, step: 1, threshold: urgent))
            // "2 min 5 sec", not "125 sec": over 2 minutes is what triage listens for.
            let text =
                seconds < 60
                ? "\(seconds) sec"
                : seconds % 60 == 0 ? "\(seconds / 60) min" : "\(seconds / 60) min \(seconds % 60) sec"
            lines.append(
                Line(label: "Longest", value: "\(text) \(window(log: log, now: now))", isUrgent: longest > urgent)
            )
        }
        // From the numbers, not the reasons showing, so a 999 flag can't hide it.
        if metrics.maxCountInTenMinutes >= thresholds.urgentCountIn10Min {
            lines.append(
                Line(label: "Frequency", value: "\(metrics.maxCountInTenMinutes) in 10 minutes", isUrgent: true))
        }
        if let strength = strengths(log: log) {
            lines.append(Line(label: "Strength", value: strength, isUrgent: false))
        }

        lines.append(waters(log: log, now: now, calendar: calendar))
        lines.append(bleeding(flags))
        lines += symptoms(flags)
        lines.append(movements(log: log, now: now, calendar: calendar))
        if let cleared = cleared(log: log, now: now, calendar: calendar) {
            lines.append(Line(label: "Turned off", value: cleared, isUrgent: false))
        }
        if let call = log.lastCall {
            lines.append(Line(label: "Last call", value: lastCall(call, now: now, calendar: calendar), isUrgent: false))
            // What the call didn't cover, even once it has left the hour: the reason to call back.
            if case .callBack(_, let fresh) = output.call, !fresh.isEmpty {
                let said = fresh.map {
                    StateCopy.reasonLine(for: $0, metrics: metrics, thresholds: thresholds, now: now)
                }
                lines.append(Line(label: "Since the last call", value: said.joined(separator: " "), isUrgent: true))
            }
        }
        lines.append(Line(label: "Pregnancy", value: pregnancy(details), isUrgent: isPreterm(details)))
        if let travel = details.travelMinutes {
            lines.append(Line(label: "Journey", value: "\(travel) min to the unit", isUrgent: false))
        }
        if !details.hospitalNumber.isEmpty {
            lines.append(Line(label: "Hospital number", value: details.hospitalNumber, isUrgent: false))
        }
        if !details.notes.isEmpty {
            lines.append(Line(label: "Notes", value: details.notes, isUrgent: false))
        }

        let name = details.motherName.isEmpty ? "my partner" : details.motherName
        return TriageScript(opening: "Hi, I'm calling about \(name). \(pregnancy(details)).", lines: lines)
    }

    static func contractionSummary(_ metrics: ContractionMetrics, thresholds: ThresholdProfile) -> String {
        guard metrics.recentMedianIntervalSec != nil || metrics.medianIntervalSec != nil else {
            return metrics.lastStart == nil ? "None timed yet" : "Not enough timed for a pattern"
        }
        var text = StateCopy.intervalSummary(metrics, thresholds: thresholds)
        text = text.prefix(1).uppercased() + text.dropFirst()
        // How long this rate has held, not the whole run: two slow hours aren't two hours at this rate.
        let held = metrics.rateHeldSec ?? metrics.patternSustainedSec
        let earlier = StateCopy.earlierSummary(metrics)
        if held >= 60 {
            text += earlier != nil ? ", for the last \(minutes(held)) min" : ", for \(minutes(held)) min"
        }
        if let regularity = metrics.recentRegularity ?? metrics.regularity {
            text += regularity <= thresholds.regularityCV ? ", regular" : ", uneven"
        }
        if let earlier {
            text += " (\(earlier))"
        }
        let missed = metrics.missedTapGaps.reduce(0) { $0 + $1.estimatedMissed }
        if missed > 0 {
            text += missed == 1 ? " (possibly 1 not logged)" : " (possibly \(missed) not logged)"
        }
        return text
    }

    /// The 999 facts, said before anything else.
    private static func emergencies(_ flags: Set<RedFlag>) -> [Line] {
        let facts: [(RedFlag, Line)] = [
            (.urgeToPush, Line(label: "Pushing", value: "Strong urge to push", isUrgent: true)),
            (.cordVisible, Line(label: "Cord", value: "Cord felt or seen", isUrgent: true)),
            (.headVisible, Line(label: "Head", value: "Baby's head visible", isUrgent: true)),
            (.seizureCollapse, Line(label: "Collapse", value: "Seizure or collapse", isUrgent: true)),
        ]
        return facts.filter { flags.contains($0.0) }.map(\.1)
    }

    /// Pain and pre-eclampsia signs, when he's flagged them.
    private static func symptoms(_ flags: Set<RedFlag>) -> [Line] {
        var lines: [Line] = []
        if flags.contains(.severePain) {
            lines.append(
                Line(label: "Pain", value: "Constant or severe, no break between contractions", isUrgent: true))
        }
        if flags.contains(.preEclampsiaSigns) {
            lines.append(
                Line(label: "Other signs", value: "Bad headache, vision changes or feeling very unwell", isUrgent: true)
            )
        }
        return lines
    }

    /// "in the last hour", or "in the last 25 min" if timing started less than an hour ago.
    private static func window(log: ReducedLog, now: Date) -> String {
        // From when timing started, not the first contraction still inside the hour.
        guard let first = log.contractions.map(\.start).filter({ $0 <= now }).min() else {
            return "in the last hour"
        }
        let span = now.timeIntervalSince(first)
        return span >= EngineConstants.analysisWindowSec - 60
            ? "in the last hour" : "in the last \(max(1, minutes(span))) min"
    }

    /// "Strong, strong, moderate (latest first)", from the last three timed contractions he rated.
    private static func strengths(log: ReducedLog) -> String? {
        let rated = log.contractions.suffix(3).reversed().compactMap { log.strengths[$0.id] }
        guard !rated.isEmpty else { return nil }
        let text = rated.map(\.rawValue).joined(separator: ", ")
        return text.prefix(1).uppercased() + text.dropFirst() + (rated.count > 1 ? " (latest first)" : "")
    }

    /// Flags that were on and turned off, so a mistake or a change of mind is still on record, even
    /// if the flag is on again now.
    private static func cleared(log: ReducedLog, now: Date, calendar: Calendar) -> String? {
        let items = RedFlag.allCases.compactMap { flag -> String? in
            guard let status = log.redFlags[flag] else { return nil }
            var episodes = status.earlier
            if !status.isOn, let happened = status.happenedAt {
                episodes.append(FlagEpisode(onAt: happened, offAt: status.changedAt))
            }
            guard !episodes.isEmpty else { return nil }
            let times = episodes.map {
                "on \(clock($0.onAt, calendar: calendar)), off \(clock($0.offAt, calendar: calendar))"
            }
            return "\(label(flag)) (\(times.joined(separator: "; ")))"
        }
        return items.isEmpty ? nil : items.joined(separator: "; ")
    }

    private static func lastCall(_ call: LoggedCall, now: Date, calendar: Calendar) -> String {
        let said =
            switch call.note.outcome {
            case .comeIn: "they said come in"
            case .stayHome: "they said stay at home for now"
            case .other: "logged"
            }
        let when = ago(call.at, now: now, calendar: calendar)
        return "\(when.prefix(1).uppercased())\(when.dropFirst()), \(said)"
    }

    private static func label(_ flag: RedFlag) -> String {
        switch flag {
        case .watersBroken: "Waters broke"
        case .watersColoured: "Waters coloured"
        case .bleeding: "Bleeding"
        case .heavyBleeding: "Heavy bleeding"
        case .reducedMovements: "Moving less"
        case .urgeToPush: "Urge to push"
        case .cordVisible: "Cord"
        case .seizureCollapse: "Seizure or collapse"
        case .severePain: "Severe pain"
        case .preEclampsiaSigns: "Headache or vision"
        case .headVisible: "Head visible"
        }
    }

    private static func clock(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    private static func waters(log: ReducedLog, now: Date, calendar: Calendar) -> Line {
        guard let broken = log.redFlags[.watersBroken], broken.isOn else {
            if log.activeRedFlags.contains(.watersColoured) {
                return Line(label: "Waters", value: "Coloured or smelly fluid", isUrgent: true)
            }
            return Line(label: "Waters", value: "Not broken, as far as we know", isUrgent: false)
        }
        // When they went, as he said. If he hasn't said, the tap is the latest they could have gone.
        let when = clockAndAgo(broken.happenedAt ?? broken.changedAt, now: now, calendar: calendar)
        var value = broken.timeGiven ? "Broke at \(when)" : "Broke by \(when), time not confirmed"
        value += log.activeRedFlags.contains(.watersColoured) ? ", green, brown or smelly" : ", clear"
        return Line(label: "Waters", value: value, isUrgent: true)
    }

    private static func bleeding(_ flags: Set<RedFlag>) -> Line {
        if flags.contains(.heavyBleeding) { return Line(label: "Bleeding", value: "Heavy bleeding", isUrgent: true) }
        if flags.contains(.bleeding) { return Line(label: "Bleeding", value: "Some bleeding", isUrgent: true) }
        return Line(label: "Bleeding", value: "None", isUrgent: false)
    }

    private static func movements(log: ReducedLog, now: Date, calendar: Calendar) -> Line {
        if log.activeRedFlags.contains(.reducedMovements) {
            return Line(label: "Baby's movements", value: "Moving less than usual", isUrgent: true)
        }
        guard let last = log.lastMovementAt else {
            return Line(label: "Baby's movements", value: "Ask her when she last felt the baby move", isUrgent: false)
        }
        return Line(
            label: "Baby's movements", value: "Last felt \(ago(last, now: now, calendar: calendar))", isUrgent: false)
    }

    private static func pregnancy(_ details: TriageDetails) -> String {
        var parts: [String] = []
        if let age = details.gestationalAge {
            parts.append("She's \(age) weeks")
        } else {
            switch details.termAnswer {
            case .term: parts.append("She's 37 weeks or more, no due date to hand")
            case .preterm: parts.append("She's under 37 weeks")
            case .notSure, nil: parts.append("Weeks not known")
            }
        }
        parts.append(details.parity == 0 ? "first baby" : "she's had \(details.parity) before")
        if details.previousFastLabour {
            parts.append("fast labour last time")
        }
        if details.gbsPositive {
            parts.append("GBS positive")
        }
        if details.plannedCaesarean {
            parts.append("caesarean planned")
        }
        let text = parts.joined(separator: ", ")
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    /// Under 37 weeks, or not known to be 37 or more.
    private static func isPreterm(_ details: TriageDetails) -> Bool {
        if let age = details.gestationalAge {
            return age.totalDays < EngineConstants.termDays
        }
        return details.termAnswer != .term
    }

    static func minutes(_ seconds: Double) -> Int {
        Int((seconds / 60).rounded())
    }

    /// "at 14:05 (25 min ago)"
    static func ago(_ date: Date, now: Date, calendar: Calendar) -> String {
        "at \(clockAndAgo(date, now: now, calendar: calendar))"
    }

    /// "09:01 (1 min ago)".
    static func clockAndAgo(_ date: Date, now: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let clock = String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
        let elapsed = max(0, now.timeIntervalSince(date))
        let relative: String
        if elapsed < 60 {
            relative = "just now"
        } else if elapsed < 3600 {
            relative = "\(Int(elapsed / 60)) min ago"
        } else {
            let hours = Int(elapsed / 3600)
            let mins = Int(elapsed.truncatingRemainder(dividingBy: 3600) / 60)
            relative = mins == 0 ? "\(hours) h ago" : "\(hours) h \(mins) min ago"
        }
        return "\(clock) (\(relative))"
    }
}
