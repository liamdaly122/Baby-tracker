import Foundation

/// The practice run: the real engine on a pretend term labour, so he can rehearse the taps, the
/// call point, a curveball and the call before the day. It runs in a session of its own. The app
/// keeps that session in memory only, with no alerts, no watch link and no dialling, and a real
/// LAUNCH ends it. Where he is in the drill is read from the drill's own log, so any order works.
/// The copy is for midwife review (content review log D1 to D3).
public enum Drill {
    /// 39+0: a term labour whatever week it really is, so the drill never shows the preterm rule
    /// as if it were how her labour would go.
    public static let gestationalAgeDays = 273
    /// Taps in a drill are recorded as this device, never as the phone or the watch.
    public static let deviceID = "drill"
    /// Contractions he times himself before skipping ahead.
    public static let practiceContractions = 2
    /// Contractions skipping ahead adds at least, so his own extra taps don't count as skipping.
    static let minimumSkipped = 8

    /// A new drill session: its own ID, 39+0, his parity, journey and thresholds (so it follows
    /// his midwife's rule). GBS and a planned caesarean are left out so the script's steps hold.
    public static func sessionStart(_ brief: MissionBrief, at date: Date) -> SessionStart {
        SessionStart(
            startedAt: date,
            startedBy: deviceID,
            profile: LabourProfile(
                region: brief.region,
                parity: brief.parity,
                previousFastLabour: brief.previousFastLabour,
                gestationalAgeDays: gestationalAgeDays,
                travelMinutes: brief.travelMinutes
            ),
            thresholds: brief.thresholds
        )
    }

    public enum Step: Equatable, Sendable {
        case tapStart(number: Int)
        case tapStop(number: Int)
        case skipAhead
        case watersCue
        case watersTime
        case logCall
        case debrief
    }

    /// Where the drill is, from what he has done so far in its log.
    public static func step(_ log: ReducedLog) -> Step {
        let count = log.contractions.count
        let skipped = count >= practiceContractions + minimumSkipped
        if !skipped {
            if log.openContraction != nil {
                return .tapStop(number: count)
            }
            return count < practiceContractions ? .tapStart(number: count + 1) : .skipAhead
        }
        guard let waters = log.redFlags[.watersBroken], waters.isOn else { return .watersCue }
        if !waters.timeGiven { return .watersTime }
        return log.lastCall == nil ? .logCall : .debrief
    }

    /// How skipping ahead goes: often enough and long enough to meet the call rule, for long enough
    /// to pass any hold he has set (at least 45 minutes).
    public struct SkipPlan: Equatable, Sendable {
        public var every: Double
        public var lasting: Double
        public var span: Double

        public init(every: Double, lasting: Double, span: Double) {
            self.every = every
            self.lasting = lasting
            self.span = span
        }

        public var minutes: Int { Int((span / 60).rounded()) }
    }

    public static func skipPlan(_ core: LabourSessionCore) -> SkipPlan {
        let thresholds = core.thresholds
        let required = GoNoGoEngine.requiredSustainedSec(profile: core.start.profile, thresholds: thresholds)
        return SkipPlan(
            every: min(240, thresholds.adviceIntervalSec - 30),
            lasting: max(65, thresholds.adviceDurationSec + 5),
            span: max(45 * 60, required + 15 * 60)
        )
    }

    /// Skips ahead from `now`: stops any open contraction, then taps a regular run through the real
    /// tap rule. Returns the drill time to carry on from, just after the last one.
    @discardableResult
    public static func skipAhead(_ core: inout LabourSessionCore, from now: Date) -> Date {
        let plan = skipPlan(core)
        if core.log.openContraction != nil {
            core.endOpenContraction(at: now)
        }
        var start = now.addingTimeInterval(plan.every)
        var resume = now
        while start <= now.addingTimeInterval(plan.span) {
            _ = core.tap(at: start)
            _ = core.tap(at: start.addingTimeInterval(plan.lasting))
            resume = start.addingTimeInterval(plan.lasting + 30)
            start = start.addingTimeInterval(plan.every)
        }
        return resume
    }

    /// What the debrief reports, on the drill's own clock.
    public struct Debrief: Equatable, Sendable {
        public var startedAt: Date
        /// When the contractions met the call rule.
        public var callPointAt: Date?
        public var watersAt: Date?
        public var calledAt: Date?
    }

    public static func debrief(_ core: inout LabourSessionCore, at now: Date) -> Debrief {
        Debrief(
            startedAt: core.start.startedAt,
            callPointAt: core.output(at: now).snapshot.callRuleMetAt,
            watersAt: core.watersBrokeAt,
            calledAt: core.log.lastCall?.at
        )
    }

    // MARK: Copy

    /// The guide card for a step: a title and one or two sentences.
    public static func guide(_ step: Step, plan: SkipPlan, region: ContentRegion) -> (title: String, detail: String) {
        switch step {
        case .tapStart(let number) where number == 1:
            ("Contraction 1: tap START", "Pretend one is starting now. In labour you tap START as each one begins.")
        case .tapStart(let number):
            ("Contraction \(number): tap START", "One more, so you've got the feel of it.")
        case .tapStop:
            (
                "Now tap STOP",
                "Tap STOP when it eases off. The app works out how often they come and how long they last."
            )
        case .skipAhead:
            (
                "Skip ahead \(plan.minutes) minutes",
                "Contractions about every \(StateCopy.spoken(plan.every)) from here. Watch what the app tells you."
            )
        case .watersCue:
            (
                "Curveball: her waters have gone",
                "Find Waters broke and tap it. Waters going means call now, at any week."
            )
        case .watersTime:
            ("Say when they went", "Triage will ask. Answer the question on the timer.")
        case .logCall:
            (
                "Now the call",
                "Open the Call tab. In a real labour the big button rings \(StateCopy.unit(region)). Read the script "
                    + "out loud, then log what they said."
            )
        case .debrief:
            ("Drill complete", "Here's how it went.")
        }
    }

    /// The debrief lines, oldest first, then the rules to keep. Times are minutes into the drill,
    /// because its clock has skipped ahead of the real one.
    public static func debriefLines(_ debrief: Debrief, plan: SkipPlan, region: ContentRegion) -> [String] {
        func minutesIn(_ date: Date) -> Int {
            max(0, Int((date.timeIntervalSince(debrief.startedAt) / 60).rounded()))
        }
        var lines: [String] = []
        if let met = debrief.callPointAt {
            let every = StateCopy.spoken(plan.every)
            lines.append(
                "The call point came \(minutesIn(met)) min into the drill: regular contractions, about every \(every).")
        }
        if let waters = debrief.watersAt {
            lines.append("Her waters went \(minutesIn(waters)) min in. On its own, that means call now.")
        }
        if let called = debrief.calledAt {
            lines.append("You logged the call \(minutesIn(called)) min in.")
        }
        lines.append(
            "To time real tightenings, always use LAUNCH. If they're painful or regular before 37 weeks, call "
                + "\(StateCopy.unit(region)).")
        lines.append("Before 37 weeks, skip all this: launch and call.")
        return lines
    }

    /// Asked before a drill starts, so practice never times a real labour.
    public static let startQuestion = "Is she having tightenings, pain, a show or any fluid now?"
    public static let startYes = "Yes: then this isn't a drill. Launch now."
    public static let startNo = "No, just practising"
}
