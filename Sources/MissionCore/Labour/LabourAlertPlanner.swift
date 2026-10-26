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
    /// For `newUrgentReason`, the reason that's new.
    public var reason: ReasonCode?
    public var title: String
    public var body: String

    public var level: Level {
        kind == .stillGoing || state >= .callTriage ? .timeSensitive : .active
    }

    /// The same alert gets the same identifier on every device, and a rise has the same identifier
    /// whether it was posted at once or scheduled, so the phone and the watch don't both buzz. One
    /// long contraction is one alert: the still-going nudge and the over-2-minutes reasons share an
    /// identifier. Before adding a new plan, remove the pending requests under
    /// `identifierPrefix(sessionID:)`, so a plan that no longer applies is dropped and a changed one
    /// replaces the old.
    public func identifier(sessionID: UUID) -> String {
        let prefix = LabourAlertPlanner.identifierPrefix(sessionID: sessionID)
        switch kind {
        case .rise, .scheduledRise: return prefix + "rise.\(state.rawValue)"
        case .stillGoing: return prefix + "overUrgentDuration"
        case .newUrgentReason:
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

    /// Notifications for what just changed: a rise to an actionable state, and any urgent contraction
    /// reason that wasn't there before, even if the level was already up for another reason. Not in
    /// a 999 state: he should be on the phone to 999, not the unit. A contraction that passed 2
    /// minutes while open isn't alerted again when he stops it.
    public static func immediate(
        previous: EngineStateSnapshot?,
        output: EngineOutput,
        region: ContentRegion
    ) -> [PlannedAlert] {
        var alerts: [PlannedAlert] = []
        let rose = output.state > (previous?.state ?? .early)
        if isActionable(output.state) && rose {
            alerts.append(alert(.rise, at: output.snapshot.enteredAt, output: output, region: region))
        }
        guard output.state < .call999 else { return alerts }
        var before = Set(previous?.held.advice.reasons ?? [])
        if before.contains(.openContractionOverUrgentDuration) {
            before.insert(.contractionOverUrgentDuration)
        }
        let shownInRise = rose ? Set(output.reasons) : []
        for reason in output.contractionAdvice.reasons
        where urgentContractionReasons.contains(reason) && !before.contains(reason) && !shownInRise.contains(reason) {
            alerts.append(
                PlannedAlert(
                    kind: .newUrgentReason,
                    fireAt: output.evaluatedAt,
                    state: output.contractionAdvice.state,
                    reason: reason,
                    title: StateCopy.headline(for: output.contractionAdvice.state, region: region),
                    body: StateCopy.reasonLine(for: reason, metrics: output.metrics, thresholds: output.thresholds)
                )
            )
        }
        return alerts
    }

    /// Notifications to schedule, given the latest evaluation. Simulates the engine forward with
    /// no further taps and returns the first future rise, plus a "still going?" nudge for an open
    /// contraction if that isn't already covered by the rise.
    public static func scheduled(input: EngineInput, output: EngineOutput) -> [PlannedAlert] {
        let region = input.profile.region
        var alerts: [PlannedAlert] = []
        var simulated = input
        var current = output
        for _ in 0..<maxLookaheadSteps {
            guard let next = current.nextReviewAt, next > simulated.now else { break }
            simulated.now = next
            simulated.previous = current.snapshot
            let future = GoNoGoEngine.evaluate(simulated)
            if isActionable(future.state) && future.state > current.state {
                alerts.append(alert(.scheduledRise, at: next, output: future, region: region))
                break
            }
            current = future
        }

        // The still-going nudge. Not in a 999 state: he should be on the phone to 999, not the unit.
        let urgent = output.thresholds.urgentSingleDurationSec
        if output.state < .call999, let lastStart = output.metrics.lastStart,
            let elapsed = output.metrics.openElapsedSec, elapsed <= urgent
        {
            let fireAt = lastStart.addingTimeInterval(urgent + 1)
            let coveredByRise = alerts.contains { $0.fireAt == fireAt }
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
            title: StateCopy.headline(for: output.state, region: region),
            body: body
        )
    }
}
