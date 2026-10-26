import Foundation

public struct EngineInput: Sendable, Hashable {
    public var contractions: [Contraction]
    public var redFlags: Set<RedFlag>
    public var profile: LabourProfile
    public var thresholds: ThresholdProfile
    /// The snapshot from the previous evaluation, for hysteresis. Nil on the first run.
    public var previous: EngineStateSnapshot?
    /// When he said the contractions have stopped, if he has since the last one started.
    public var easedAt: Date?
    public var now: Date

    public init(
        contractions: [Contraction],
        redFlags: Set<RedFlag> = [],
        profile: LabourProfile,
        thresholds: ThresholdProfile,
        previous: EngineStateSnapshot? = nil,
        easedAt: Date? = nil,
        now: Date
    ) {
        self.contractions = contractions
        self.redFlags = redFlags
        self.profile = profile
        self.thresholds = thresholds
        self.previous = previous
        self.easedAt = easedAt
        self.now = now
    }

    /// The input for a session's log, so the red flags, "they've stopped" and the 37-week answer
    /// can't be left out. `profile` should hold the gestation fixed when the session started.
    public init(
        log: ReducedLog,
        profile: LabourProfile,
        thresholds: ThresholdProfile,
        previous: EngineStateSnapshot?,
        now: Date
    ) {
        var profile = profile
        profile.termAnswer = profile.termAnswer ?? log.termAnswer
        self.init(
            contractions: log.contractions,
            redFlags: log.activeRedFlags,
            profile: profile,
            thresholds: thresholds,
            previous: previous,
            easedAt: log.easedAt,
            now: now
        )
    }
}

/// Persisted after every evaluation and passed back in as `EngineInput.previous`.
public struct EngineStateSnapshot: Codable, Sendable, Hashable {
    public var state: LabourState
    public var enteredAt: Date
    public var reasonCodes: [ReasonCode]
    /// The contraction-driven part, which is the only part with hysteresis.
    public var held: HeldAdvice
    /// When the contractions first met the call rule this session. Kept for the triage call even if
    /// the advice later drops, so a gap in the log can't hide it.
    public var callRuleMetAt: Date?
    /// The latest start this evaluation saw, so the next one can tell a new tap from a correction.
    public var lastStart: Date?
    /// Set while held advice is kept up because taps have resumed after a gap.
    public var holdingForTapsSince: Date?
}

public struct EngineOutput: Sendable, Hashable {
    public var state: LabourState
    public var reasons: [ReasonCode]
    public var enteredAt: Date
    /// The moment this evaluation was for.
    public var evaluatedAt: Date
    public var metrics: ContractionMetrics
    /// The thresholds actually used, clamped to their safe bounds. Use these for copy and alerts.
    public var thresholds: ThresholdProfile
    /// What the contractions alone say, even when a red flag or the gestation rule outranks it, so
    /// the screen can always show the contraction line.
    public var contractionAdvice: Advice
    /// True while contraction-driven advice is held during the dwell after contractions ease.
    public var isEasing: Bool
    /// How long the pattern has to hold for this profile (0 means it doesn't have to).
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
/// 2. `callNow`: waters broken or coloured, bleeding, reduced movements, under 37 weeks or weeks not
///    known, a contraction over the urgent duration (closed or still open), too many in 10 minutes.
/// 3. `callTriage`: contractions at the call rate (every 5 minutes or more often, regular or not),
///    long enough if a duration rule is on, and held for the required time if one is set.
/// 4. `establishing`: that rate but not yet held long enough, or within 1.5× the advice interval.
/// 5. `early`: otherwise.
///
/// Being more frequent never reads as less urgent: the rate tests are one-sided.
public enum GoNoGoEngine {
    public static func evaluate(_ input: EngineInput) -> EngineOutput {
        // Clamped here as well as in settings, so a stored or synced profile can't relax a safety rule.
        let thresholds = ThresholdTable.builtIn(for: input.profile.region).clamped(input.thresholds)
        let uncut = ContractionMetrics.compute(input.contractions, thresholds: thresholds, now: input.now)
        let eased = effectiveEasedAt(input, metrics: uncut)
        let stopped = eased.map { eased in uncut.lastStart.map { eased >= $0 } ?? true } ?? false
        let metrics =
            eased != nil && !stopped
            ? ContractionMetrics.compute(
                input.contractions, thresholds: thresholds, now: input.now, runStartsAfter: eased)
            : uncut

        // Once the call point has been reached, a gap in the log doesn't make the pattern hold again,
        // unless he has since said the contractions stopped and the next contraction confirmed it.
        // Until then the stop might be a mis-tap, so the time is kept.
        let previousMet = input.previous?.callRuleMetAt
        let metAt = stopped ? previousMet : previousMet.flatMap { met in eased.map { $0 < met } ?? true ? met : nil }
        let required = metAt != nil ? 0 : requiredSustainedSec(profile: input.profile, thresholds: thresholds)
        let pattern = patternAdvice(metrics: metrics, thresholds: thresholds, requiredSustainedSec: required)
        var raw = urgentAdvice(metrics: metrics, thresholds: thresholds) ?? pattern

        // "They've stopped" ends non-urgent contraction advice at once. Urgent rules still stand.
        let previousHeld = input.previous?.held
        if stopped && raw.state < .callNow {
            raw = Advice(state: .early, reasons: [.contractionsStopped])
        }
        let held: HeldAdvice
        var holdingSince: Date?
        if !stopped, let previousHeld, previousHeld.advice.state > raw.state,
            waitingForPattern(raw: raw, metrics: metrics, previous: input.previous)
        {
            // Taps have resumed after a gap but the new run is too short to measure. That isn't a
            // sign they've eased, so keep the advice and restart the dwell for when they go quiet.
            held = HeldAdvice(advice: previousHeld.advice, enteredAt: previousHeld.enteredAt, pendingDrop: nil)
            holdingSince = input.previous?.holdingForTapsSince ?? input.now
        } else {
            held = Hysteresis.apply(
                raw: raw,
                previous: previousHeld,
                now: input.now,
                dropNow: stopped && (previousHeld?.advice.state ?? .early) < .callNow
            )
        }
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
            if metrics.isQuiet && held.advice.state >= .establishing {
                reasons.append(.noRecentTaps)
            }
        }

        let enteredAt =
            input.previous.flatMap { $0.state == state ? $0.enteredAt : nil } ?? input.now
        return EngineOutput(
            state: state,
            reasons: reasons,
            enteredAt: enteredAt,
            evaluatedAt: input.now,
            metrics: metrics,
            thresholds: thresholds,
            contractionAdvice: held.advice,
            isEasing: isEasing,
            requiredSustainedSec: required,
            nextReviewAt: reviewCandidates(
                metrics: metrics,
                raw: raw,
                held: held,
                thresholds: thresholds,
                requiredSustainedSec: required
            ).filter { $0 > input.now }.min(),
            snapshot: EngineStateSnapshot(
                state: state,
                enteredAt: enteredAt,
                reasonCodes: reasons,
                held: held,
                callRuleMetAt: metAt ?? (!stopped && pattern.state == .callTriage ? input.now : nil),
                lastStart: metrics.lastStart,
                holdingForTapsSince: holdingSince
            )
        )
    }

    /// "They've stopped", unless it's in the future (a bad clock) or the next contraction came on
    /// rhythm anyway, which means it was a mis-tap or a pause too short to count.
    static func effectiveEasedAt(_ input: EngineInput, metrics: ContractionMetrics) -> Date? {
        guard let eased = input.easedAt,
            eased <= input.now.addingTimeInterval(EngineConstants.futureToleranceSec)
        else { return nil }
        let starts = input.contractions.map(\.start).filter {
            $0 <= input.now.addingTimeInterval(EngineConstants.futureToleranceSec)
        }
        guard let before = starts.filter({ $0 <= eased }).max(), let after = starts.filter({ $0 > eased }).min()
        else { return eased }
        let pace =
            metrics.paceSec
            ?? ThresholdTable.builtIn(for: input.profile.region).clamped(input.thresholds).adviceIntervalSec
        return after.timeIntervalSince(before) <= EngineConstants.quietFactor * pace ? nil : eased
    }

    /// Too few contractions to measure, with taps arriving: a new tap since the last evaluation
    /// within an hour of the one before (not a correction, a delete or a tap after a night's sleep),
    /// or a hold that's already running. Ends when the log goes quiet or stale.
    static func waitingForPattern(raw: Advice, metrics: ContractionMetrics, previous: EngineStateSnapshot?) -> Bool {
        guard raw.reasons == [.notEnoughContractions], let lastStart = metrics.lastStart,
            !metrics.isQuiet, !metrics.isStale, let previous
        else { return false }
        if previous.holdingForTapsSince != nil { return true }
        guard let before = previous.lastStart else { return false }
        return lastStart > before && lastStart.timeIntervalSince(before) <= EngineConstants.analysisWindowSec
    }

    /// How long the pattern must hold before "Time to call". 0 when no hold is set (the UK default,
    /// because the NHS gives no time). Second and later babies, a previous fast labour or a long
    /// journey only need the early-caller window. Adjustments don't stack.
    public static func requiredSustainedSec(profile: LabourProfile, thresholds: ThresholdProfile) -> Double {
        let longJourney = Double(profile.travelMinutes ?? 0) > thresholds.travelEarlyCallMinutes
        let earlyCaller = profile.parity >= 1 || profile.previousFastLabour || longJourney
        return earlyCaller
            ? min(thresholds.patternWindowSec, thresholds.earlyCallerWindowSec)
            : thresholds.patternWindowSec
    }

    /// Over the urgent duration (closed or still open), or too many in 10 minutes.
    static func urgentAdvice(metrics: ContractionMetrics, thresholds: ThresholdProfile) -> Advice? {
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
        return urgent.isEmpty ? nil : Advice(state: .callNow, reasons: urgent)
    }

    /// What the pattern alone says: the call rule, the hold and the building band.
    static func patternAdvice(
        metrics: ContractionMetrics,
        thresholds: ThresholdProfile,
        requiredSustainedSec: Double
    ) -> Advice {
        guard metrics.analysedCount >= EngineConstants.minimumContractions, !metrics.recentIntervalsSec.isEmpty
        else {
            return Advice(state: .early, reasons: [.notEnoughContractions])
        }
        let longEnough =
            thresholds.adviceDurationSec <= 0 || (metrics.medianDurationSec ?? 0) >= thresholds.adviceDurationSec
        if longEnough && meetsRate(metrics, limit: thresholds.adviceIntervalSec, regularityCV: thresholds.regularityCV)
        {
            return metrics.patternSustainedSec >= requiredSustainedSec
                ? Advice(state: .callTriage, reasons: [.regularPatternSustained])
                : Advice(state: .establishing, reasons: [.patternNotYetSustained])
        }
        let buildingLimit = EngineConstants.establishingIntervalFactor * thresholds.adviceIntervalSec
        if meetsRate(metrics, limit: buildingLimit, regularityCV: thresholds.regularityCV) {
            return Advice(state: .establishing, reasons: [.patternBuilding])
        }
        return Advice(state: .early, reasons: [.noRegularPattern])
    }

    /// The current rate is at or under `limit` when any of these hold. All are one-sided: shorter
    /// gaps never count against them.
    /// - At least three in four recent intervals are at or under it, whatever the spread.
    /// - The median is at or under it and the upper quartile is no more than `regularityCV` over it,
    ///   so a regular pattern right at the limit counts. Both are measured against the limit, never
    ///   the median, so shortening a gap can't fail this test.
    /// - Over at least 6 intervals of the run in the last hour, the average is at or under it and no
    ///   gap is over twice it, which covers coupled contractions (two close together, then a gap).
    static func meetsRate(_ metrics: ContractionMetrics, limit: Double, regularityCV: Double) -> Bool {
        let values = metrics.recentIntervalsSec
        guard !values.isEmpty, let median = metrics.recentMedianIntervalSec else { return false }
        let within = values.filter { $0 <= limit }.count
        if Double(within) >= EngineConstants.rateQuantile * Double(values.count) {
            return true
        }
        return meetsMedian(
            median: median, upperQuartile: metrics.recentUpperQuartileSec, limit: limit, regularityCV: regularityCV)
            || meetsFrequency(metrics.runIntervalsSec, limit: limit)
    }

    static func meetsMedian(median: Double, upperQuartile: Double?, limit: Double, regularityCV: Double) -> Bool {
        guard let upperQuartile else { return false }
        return median <= limit && upperQuartile <= (1 + regularityCV) * limit
    }

    /// The whole rule over plain lists, for testing that it's one-sided.
    static func meetsRate(recent: [Double], run: [Double], limit: Double, regularityCV: Double) -> Bool {
        guard let median = Stats.median(recent) else { return false }
        let within = recent.filter { $0 <= limit }.count
        if Double(within) >= EngineConstants.rateQuantile * Double(recent.count) {
            return true
        }
        return meetsMedian(
            median: median, upperQuartile: Stats.quantile(recent, 0.75), limit: limit, regularityCV: regularityCV)
            || meetsFrequency(run, limit: limit)
    }

    static func meetsFrequency(_ values: [Double], limit: Double) -> Bool {
        guard values.count >= EngineConstants.frequencyMinimumIntervals else { return false }
        let mean = values.reduce(0, +) / Double(values.count)
        return mean <= limit && (values.max() ?? .infinity) <= 2 * limit
    }

    /// Red flags and the gestation rule. These never time out: they hold while the toggle is on.
    static func flagAdvice(redFlags: Set<RedFlag>, profile: LabourProfile) -> Advice? {
        var found: [(state: LabourState, reason: ReasonCode)] = RedFlag.allCases
            .filter { redFlags.contains($0) }
            .map { ($0.state, $0.reason) }
        if let reason = gestationReason(profile) {
            found.append((.callNow, reason))
        }
        guard let top = found.map(\.state).max() else { return nil }
        return Advice(state: top, reasons: found.filter { $0.state == top }.map(\.reason))
    }

    /// Under 37 weeks, or weeks not known and not confirmed as 37 or more, means call now.
    static func gestationReason(_ profile: LabourProfile) -> ReasonCode? {
        if let days = profile.gestationalAgeDays {
            return days < EngineConstants.termDays ? .preterm : nil
        }
        switch profile.termAnswer {
        case .term: return nil
        case .preterm: return .preterm
        case .notSure, nil: return .gestationUnknown
        }
    }

    /// Moments the state could change without a tap: the easing dwell finishing, an open contraction
    /// passing the urgent duration or reaching a duration rule, the pattern reaching its required
    /// length, a contraction leaving the rate window or the hour, the log going quiet, or going stale.
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
        if let lastStart = metrics.lastStart, let elapsed = metrics.openElapsedSec {
            if elapsed <= thresholds.urgentSingleDurationSec {
                candidates.append(lastStart.addingTimeInterval(thresholds.urgentSingleDurationSec + 1))
            }
            if thresholds.adviceDurationSec > 0 && elapsed < thresholds.adviceDurationSec {
                candidates.append(lastStart.addingTimeInterval(thresholds.adviceDurationSec))
            }
        }
        if raw.reasons.contains(.patternNotYetSustained), let segmentStart = metrics.segmentStart,
            let until = metrics.sustainedUntil
        {
            // Sustained time stops growing one typical interval after the last start.
            let reachesRequired = segmentStart.addingTimeInterval(requiredSustainedSec)
            if reachesRequired <= until {
                candidates.append(reachesRequired)
            }
        }
        // These rules flip just after their moment, so look a millisecond later.
        let justAfter = 0.001
        if let change = metrics.nextWindowChangeAt {
            candidates.append(change.addingTimeInterval(justAfter))
        }
        if !metrics.isQuiet, metrics.openElapsedSec == nil, let quietAt = metrics.quietAt {
            candidates.append(quietAt.addingTimeInterval(justAfter))
        }
        if !metrics.isStale, let staleAt = metrics.staleAt {
            candidates.append(staleAt.addingTimeInterval(justAfter))
        }
        return candidates
    }
}
