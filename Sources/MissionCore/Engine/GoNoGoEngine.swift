import Foundation

public struct EngineInput: Sendable, Hashable {
    public var contractions: [Contraction]
    public var redFlags: Set<RedFlag>
    public var profile: LabourProfile
    public var thresholds: ThresholdProfile
    /// The snapshot from the previous evaluation, for hysteresis. Nil on the first run.
    public var previous: EngineStateSnapshot?
    public var now: Date

    public init(
        contractions: [Contraction],
        redFlags: Set<RedFlag> = [],
        profile: LabourProfile,
        thresholds: ThresholdProfile,
        previous: EngineStateSnapshot? = nil,
        now: Date
    ) {
        self.contractions = contractions
        self.redFlags = redFlags
        self.profile = profile
        self.thresholds = thresholds
        self.previous = previous
        self.now = now
    }
}

/// Persisted after every evaluation and passed back in as `EngineInput.previous`.
public struct EngineStateSnapshot: Codable, Sendable, Hashable {
    public var state: LabourState
    public var enteredAt: Date
    public var reasonCodes: [ReasonCode]
    /// The contraction-driven part, which is the only part with hysteresis.
    public var held: HeldAdvice
}

public struct EngineOutput: Sendable, Hashable {
    public var state: LabourState
    public var reasons: [ReasonCode]
    public var enteredAt: Date
    public var metrics: ContractionMetrics
    /// True while contraction-driven advice is held during the dwell after contractions ease.
    public var isEasing: Bool
    /// How long the pattern has to hold for this profile (shorter for early callers).
    public var requiredSustainedSec: Double
    /// The earliest moment the state could change without another tap, for a scheduled notification.
    public var nextReviewAt: Date?
    public var snapshot: EngineStateSnapshot
}

/// Turns the contraction log, red flags and profile into advice on when to call. A pure,
/// deterministic function: the same input always gives the same output.
///
/// Precedence, first match wins:
/// 1. `call999`: urge to push, cord felt or seen, seizure or collapse, heavy bleeding.
/// 2. `callNow`: waters broken or coloured, bleeding, reduced movements, under 37 weeks, a contraction
///    over the urgent duration (closed or still open), too many in 10 minutes.
/// 3. `callTriage`: regular, at or under the advice interval, long enough, and sustained.
/// 4. `establishing`: that pattern but not yet sustained, or regular within 1.5× the advice interval.
/// 5. `early`: otherwise.
public enum GoNoGoEngine {
    public static func evaluate(_ input: EngineInput) -> EngineOutput {
        let thresholds = input.thresholds
        let metrics = ContractionMetrics.compute(input.contractions, thresholds: thresholds, now: input.now)
        let required = requiredSustainedSec(profile: input.profile, thresholds: thresholds)
        let raw = contractionAdvice(metrics: metrics, thresholds: thresholds, requiredSustainedSec: required)
        let held = Hysteresis.apply(raw: raw, previous: input.previous?.held, now: input.now)
        let flags = flagAdvice(redFlags: input.redFlags, profile: input.profile)

        let state = max(held.advice.state, flags?.state ?? .early)
        let heldIsShown = held.advice.state == state
        let isEasing = heldIsShown && held.pendingDrop != nil
        var reasons: [ReasonCode] = []
        if let flags, flags.state == state {
            reasons += flags.reasons
        }
        if heldIsShown {
            reasons += held.advice.reasons
            if isEasing {
                reasons.append(.patternEasing)
            }
        }

        let enteredAt =
            input.previous.flatMap { $0.state == state ? $0.enteredAt : nil } ?? input.now
        return EngineOutput(
            state: state,
            reasons: reasons,
            enteredAt: enteredAt,
            metrics: metrics,
            isEasing: isEasing,
            requiredSustainedSec: required,
            nextReviewAt: reviewCandidates(
                metrics: metrics,
                raw: raw,
                held: held,
                thresholds: thresholds,
                requiredSustainedSec: required
            ).filter { $0 > input.now }.min(),
            snapshot: EngineStateSnapshot(state: state, enteredAt: enteredAt, reasonCodes: reasons, held: held)
        )
    }

    /// Second and later babies, a previous fast labour or a long journey: the pattern only needs to
    /// hold for the early-caller window. Adjustments don't stack.
    public static func requiredSustainedSec(profile: LabourProfile, thresholds: ThresholdProfile) -> Double {
        let longJourney = Double(profile.travelMinutes ?? 0) > thresholds.travelEarlyCallMinutes
        let earlyCaller = profile.parity >= 1 || profile.previousFastLabour || longJourney
        return earlyCaller
            ? min(thresholds.patternWindowSec, thresholds.earlyCallerWindowSec)
            : thresholds.patternWindowSec
    }

    static func contractionAdvice(
        metrics: ContractionMetrics,
        thresholds: ThresholdProfile,
        requiredSustainedSec: Double
    ) -> Advice {
        var urgent: [ReasonCode] = []
        if metrics.hasClosedOverUrgent {
            urgent.append(.contractionOverUrgentDuration)
        }
        if metrics.hasOpenOverUrgent {
            urgent.append(.openContractionOverUrgentDuration)
        }
        if metrics.maxCountInTenMinutes >= thresholds.urgentCountIn10Min {
            urgent.append(.tooManyInTenMinutes)
        }
        if !urgent.isEmpty {
            return Advice(state: .callNow, reasons: urgent)
        }

        guard metrics.analysedCount >= EngineConstants.minimumContractions,
            let interval = metrics.medianIntervalSec
        else {
            return Advice(state: .early, reasons: [.notEnoughContractions])
        }
        let regular = metrics.regularity.map { $0 <= thresholds.regularityCV } ?? false
        let longEnough =
            thresholds.adviceDurationSec <= 0 || (metrics.medianDurationSec ?? 0) >= thresholds.adviceDurationSec
        if regular && longEnough && interval <= thresholds.adviceIntervalSec {
            return metrics.patternSustainedSec >= requiredSustainedSec
                ? Advice(state: .callTriage, reasons: [.regularPatternSustained])
                : Advice(state: .establishing, reasons: [.patternNotYetSustained])
        }
        if regular && interval <= EngineConstants.establishingIntervalFactor * thresholds.adviceIntervalSec {
            return Advice(state: .establishing, reasons: [.patternBuilding])
        }
        return Advice(state: .early, reasons: [.noRegularPattern])
    }

    /// Red flags and the preterm rule. These never time out: they hold while the toggle is on.
    static func flagAdvice(redFlags: Set<RedFlag>, profile: LabourProfile) -> Advice? {
        var found: [(state: LabourState, reason: ReasonCode)] = RedFlag.allCases
            .filter { redFlags.contains($0) }
            .map { ($0.state, $0.reason) }
        if let days = profile.gestationalAgeDays, days < EngineConstants.termDays {
            found.append((.callNow, .preterm))
        }
        guard let top = found.map(\.state).max() else { return nil }
        return Advice(state: top, reasons: found.filter { $0.state == top }.map(\.reason))
    }

    /// Moments the state could change without a tap: the easing dwell finishing, an open contraction
    /// passing the urgent duration, the pattern reaching its required length, or the pattern going stale.
    static func reviewCandidates(
        metrics: ContractionMetrics,
        raw: Advice,
        held: HeldAdvice,
        thresholds: ThresholdProfile,
        requiredSustainedSec: Double
    ) -> [Date] {
        var candidates: [Date] = []
        if let pending = held.pendingDrop {
            candidates.append(pending.since.addingTimeInterval(EngineConstants.demotionDwellSec))
        }
        if let lastStart = metrics.lastStart {
            if let elapsed = metrics.openElapsedSec, elapsed <= thresholds.urgentSingleDurationSec {
                candidates.append(lastStart.addingTimeInterval(thresholds.urgentSingleDurationSec + 1))
            }
            if raw.reasons.contains(.patternNotYetSustained),
                let segmentStart = metrics.segmentStart,
                let interval = metrics.medianIntervalSec
            {
                // Sustained time stops growing one median interval after the last start.
                let reachesRequired = segmentStart.addingTimeInterval(requiredSustainedSec)
                if reachesRequired <= lastStart.addingTimeInterval(interval) {
                    candidates.append(reachesRequired)
                }
            }
        }
        if !metrics.isStale, let staleAt = metrics.staleAt {
            candidates.append(staleAt.addingTimeInterval(1))
        }
        return candidates
    }
}
