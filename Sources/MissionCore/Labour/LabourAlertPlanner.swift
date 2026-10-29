import Foundation

/// A notification to post now or schedule for later.
public struct PlannedAlert: Sendable, Hashable {
    public enum Kind: String, Sendable {
        /// The advice just went up while the app may not be on screen.
        case rise
        /// The advice will go up at `fireAt` with no more taps (a pattern reaching its hold, a
        /// contraction leaving a window, or an open contraction passing 2 minutes).
        case scheduledRise
        /// A new urgent contraction reason at a level that's already showing, such as 6 in 10 while
        /// "call now" is up for another reason.
        case newUrgentReason
        /// The open contraction has run past the urgent duration: still going, or forgot to stop?
        case stillGoing
        /// Something changed after a call he logged: call them back.
        case callBack
        /// 24 hours since her waters went: induction is usually offered around now.
        case watersDay
    }

    /// How hard the alert should push through. Labour alerts that ask him to call are time
    /// sensitive, so a Sleep or other Focus doesn't hold them back.
    public enum Level: String, Sendable {
        case active
        case timeSensitive
    }

    public var kind: Kind
    public var fireAt: Date
    public var state: LabourState
    /// For `newUrgentReason`, the reason that's new. For `callBack`, the main thing that changed.
    public var reason: ReasonCode?
    public var title: String
    public var body: String
    /// For `callBack`: the level went up, so it replaces the rise alert for that level.
    public var rose = false

    public var level: Level {
        kind == .stillGoing || kind == .callBack || kind == .watersDay || state >= .callTriage
            ? .timeSensitive : .active
    }

    /// The same alert gets the same identifier on every device, and a rise has the same identifier
    /// whether it was posted at once or scheduled, so the phone and the watch don't both buzz. One
    /// long contraction is one alert: the still-going nudge and the over-2-minutes reasons share an
    /// identifier. "Call them back" takes the identifier of the change it reports, so it replaces
    /// the rise or nudge already planned for that change instead of adding a second alert. Before
    /// adding a new plan, remove the pending requests under `identifierPrefix(sessionID:)`, so a
    /// plan that no longer applies is dropped and a changed one replaces the old.
    public func identifier(sessionID: UUID) -> String {
        let prefix = LabourAlertPlanner.identifierPrefix(sessionID: sessionID)
        switch kind {
        case .rise, .scheduledRise: return prefix + "rise.\(state.rawValue)"
        case .stillGoing: return prefix + "overUrgentDuration"
        case .watersDay: return prefix + "watersDay"
        case .callBack where rose: return prefix + "rise.\(state.rawValue)"
        case .newUrgentReason, .callBack:
            switch reason {
            case .contractionOverUrgentDuration, .openContractionOverUrgentDuration:
                return prefix + "overUrgentDuration"
            default: return prefix + "reason.\(reason?.rawValue ?? state.rawValue)"
            }
        }
    }
}

/// Decides which notifications to post. Nothing ticks in the background, so instead of a running
/// timer the app schedules a local notification for the next moment the advice could change.
public enum LabourAlertPlanner {
    /// How far ahead the planner simulates without new taps.
    public static let maxLookaheadSteps = 60

    /// Every labour alert for a session starts with this, so ending the session can cancel exactly
    /// those and leave other reminders alone.
    public static func identifierPrefix(sessionID: UUID) -> String {
        "labour.\(sessionID.uuidString.lowercased())."
    }

    /// Notifications are only worth sending when there's something to do.
    static func isActionable(_ state: LabourState) -> Bool {
        state >= .callTriage
    }

    /// Contraction reasons that each deserve their own alert, even at a level already showing.
    static let urgentContractionReasons: Set<ReasonCode> = [
        .contractionOverUrgentDuration, .openContractionOverUrgentDuration, .tooManyInTenMinutes,
    ]

    /// Whether a device should keep `snapshot` as the one it last alerted from. True when anything
    /// `immediate` reads has changed: the level, the reasons showing, the contractions' own advice
    /// (which can change under a flag without changing what's showing) and the call that covers it.
    /// Keeping it only when the level or shown reasons change would repeat an alert on every refresh
    /// under a flag, and never say "call them back".
    public static func shouldKeep(_ snapshot: EngineStateSnapshot, over previous: EngineStateSnapshot?) -> Bool {
        guard let previous else { return true }
        return previous.state != snapshot.state || previous.reasonCodes != snapshot.reasonCodes
            || previous.held.advice != snapshot.held.advice
            || previous.acknowledgedCallAt != snapshot.acknowledgedCallAt
    }

    /// Notifications for what just changed: a rise to an actionable state, any reason that asks him
    /// to call and wasn't there before (a second red flag, 6 in 10, or the contractions reaching the
    /// call point under a flag), even if the level was already up, and "call them back" once after a
    /// logged call stops covering what's showing. Not in a 999 state: he should be on the phone to
    /// 999, not the unit. A contraction that passed 2 minutes while open isn't alerted again when
    /// he stops it.
    public static func immediate(
        previous: EngineStateSnapshot?,
        output: EngineOutput,
        region: ContentRegion
    ) -> [PlannedAlert] {
        // Once per call: the first evaluation after the call stopped covering things. A 999 state in
        // between has no call status, so coming down from it counts too.
        if case .callBack(let call, let fresh) = output.call, let previous,
            previous.acknowledgedCallAt == call.at || previous.state == .call999
        {
            let lead = fresh.first ?? output.contractionAdvice.reasons.first
            return [
                PlannedAlert(
                    kind: .callBack,
                    fireAt: output.evaluatedAt,
                    state: output.state,
                    reason: lead,
                    title: StateCopy.headline(for: output, region: region),
                    body: lead.map {
                        StateCopy.reasonLine(
                            for: $0, metrics: output.metrics, thresholds: output.thresholds, now: output.evaluatedAt)
                    } ?? StateCopy.detail(for: output, region: region, thresholds: output.thresholds),
                    rose: output.state > previous.state
                )
            ]
        }
        // The logged call still covers everything showing: nothing new to call about.
        if case .acknowledged = output.call {
            return []
        }
        var alerts: [PlannedAlert] = []
        let rose = output.state > (previous?.state ?? .early)
        if isActionable(output.state) && rose {
            alerts.append(alert(.rise, at: output.snapshot.enteredAt, output: output, region: region))
        }
        guard output.state < .call999 else { return alerts }
        // Reasons that turned up while 999 was showing were never alerted (see the guard above).
        let alerted = previous.flatMap { $0.state < .call999 ? $0 : nil }
        var before = Set((alerted?.held.advice.reasons ?? []) + (alerted?.reasonCodes ?? []))
        if before.contains(.openContractionOverUrgentDuration) {
            before.insert(.contractionOverUrgentDuration)
        }
        // Contractions already at or above the call point: coming back down to it isn't news.
        if let alerted, alerted.held.advice.state >= .callTriage {
            before.insert(.regularPatternSustained)
        }
        let shownInRise = rose ? Set(output.reasons) : []
        var seen: Set<ReasonCode> = []
        for reason in output.reasons + output.contractionAdvice.reasons
        where GoNoGoEngine.callReasons.contains(reason) && !before.contains(reason) && !shownInRise.contains(reason)
            && seen.insert(reason).inserted
        {
            let isContraction = output.contractionAdvice.reasons.contains(reason)
            let state =
                isContraction && urgentContractionReasons.contains(reason)
                ? output.contractionAdvice.state : output.state
            alerts.append(
                PlannedAlert(
                    kind: .newUrgentReason,
                    fireAt: output.evaluatedAt,
                    state: state,
                    reason: reason,
                    title: StateCopy.headline(for: state, region: region),
                    body: StateCopy.reasonLine(
                        for: reason, metrics: output.metrics, thresholds: output.thresholds, now: output.evaluatedAt)
                )
            )
        }
        return alerts
    }

    /// Notifications to schedule, given the latest evaluation. Simulates the engine forward with
    /// no further taps and returns the first future rise, a "still going?" nudge for an open
    /// contraction if that isn't already covered by the rise, and a reminder 24 hours after the
    /// waters went (`watersBrokeAt`, if they're broken).
    public static func scheduled(input: EngineInput, output: EngineOutput, watersBrokeAt: Date? = nil) -> [PlannedAlert]
    {
        let region = input.profile.region
        var alerts: [PlannedAlert] = []
        var simulated = input
        var current = output
        for _ in 0..<maxLookaheadSteps {
            guard let next = current.nextReviewAt, next > simulated.now else { break }
            simulated.now = next
            simulated.previous = current.snapshot
            let future = GoNoGoEngine.evaluate(simulated)
            if isActionable(future.state) && future.state > current.state && future.call?.acknowledgedAt == nil {
                alerts.append(alert(.scheduledRise, at: next, output: future, region: region))
                break
            }
            current = future
        }

        // The still-going nudge and the waters reminder. Not while a 999 flag is on: he should be on
        // the phone to 999, not the unit. The minute 999 stays up after a flag is turned off doesn't
        // count, so turning off a mis-tap doesn't drop them; the nudge just waits for it to pass.
        let live999 = GoNoGoEngine.flagAdvice(input, includingCleared: false)?.state == .call999
        let holdEnds = GoNoGoEngine.clearHoldEnds(input).max()
        let urgent = output.thresholds.urgentSingleDurationSec
        // Inside the hold the nudge stays planned for its end, even once the contraction is past 2
        // minutes: nothing was alerted for it while 999 was showing.
        let inHold = holdEnds.map { $0 > input.now } ?? false
        if !live999, let lastStart = output.metrics.lastStart,
            let elapsed = output.metrics.openElapsedSec, elapsed <= urgent || inHold
        {
            let fireAt = max(lastStart.addingTimeInterval(urgent + 1), holdEnds ?? .distantPast)
            // A rise planned after this contraction passed 2 minutes, and no later than the nudge, is
            // about it: one alert, not two a second apart.
            let overAt = lastStart.addingTimeInterval(urgent)
            let coveredByRise = alerts.contains { $0.fireAt > overAt && $0.fireAt <= fireAt }
            if !coveredByRise {
                alerts.append(
                    PlannedAlert(
                        kind: .stillGoing,
                        fireAt: fireAt,
                        state: .callNow,
                        reason: nil,
                        title: StateCopy.stillGoingTitle(thresholds: output.thresholds),
                        body: StateCopy.stillGoingBody(region: region)
                    )
                )
            }
        }
        // Induction around 24 hours is term advice (NICE NG235): not under 37 weeks or weeks not known.
        if !live999, GoNoGoEngine.gestationReason(input.profile) == nil, let broke = watersBrokeAt {
            let fireAt = broke.addingTimeInterval(EngineConstants.watersReminderSec)
            if fireAt > input.now {
                alerts.append(
                    PlannedAlert(
                        kind: .watersDay,
                        fireAt: fireAt,
                        state: output.state,
                        reason: .watersBroken,
                        title: "24 hours since her waters went",
                        body: "If labour hasn't started and you haven't been told when to go in, call "
                            + "\(StateCopy.unit(region)). Induction is usually offered around now."
                    )
                )
            }
        }
        return alerts.sorted { $0.fireAt < $1.fireAt }
    }

    private static func alert(
        _ kind: PlannedAlert.Kind,
        at date: Date,
        output: EngineOutput,
        region: ContentRegion
    ) -> PlannedAlert {
        let reason = output.reasons.first { $0 != .patternEasing && $0 != .noRecentTaps }
        let thresholds = output.thresholds
        let body =
            reason.map { StateCopy.reasonLine(for: $0, metrics: output.metrics, thresholds: thresholds, now: date) }
            ?? StateCopy.detail(for: output, region: region, thresholds: thresholds)
        return PlannedAlert(
            kind: kind,
            fireAt: date,
            state: output.state,
            reason: reason,
            title: StateCopy.headline(for: output, region: region),
            body: body
        )
    }
}
