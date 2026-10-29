import Foundation

/// Where the latest call to the unit stands.
public enum CallStatus: Sendable, Hashable {
    /// He called about everything that's showing, and nothing new has happened since.
    case acknowledged(LoggedCall)
    /// Something new since he called: a higher level, a new reason, or the contractions reaching the
    /// call point under a flag. `newReasons` says what, most important first.
    case callBack(LoggedCall, newReasons: [ReasonCode])

    /// When the call that still covers the advice was logged.
    public var acknowledgedAt: Date? {
        if case .acknowledged(let call) = self { return call.at }
        return nil
    }
}

/// The contraction advice when a call was logged, worked out in the replay at the call's moment.
public struct CallCover: Codable, Sendable, Hashable {
    public var callAt: Date
    public var contractionState: LabourState

    public init(callAt: Date, contractionState: LabourState) {
        self.callAt = callAt
        self.contractionState = contractionState
    }
}

/// Whether the latest logged call still covers the advice.
extension GoNoGoEngine {
    /// Reasons that ask him to call. Anything below the call point isn't news worth calling back about.
    static let callReasons: Set<ReasonCode> = Set(RedFlag.allCases.map(\.reason)).union([
        .bleedingWithSeverePain, .gbsWithWaters, .gbsWithWatersPreterm, .gbsInLabour, .plannedCaesarean, .preterm,
        .gestationUnknown, .contractionOverUrgentDuration, .openContractionOverUrgentDuration, .tooManyInTenMinutes,
        .regularPatternSustained,
    ])

    /// What an evaluation shows, for checking it against the latest call.
    struct CallCheck {
        var state: LabourState
        var reasons: [ReasonCode]
        var contractionAdvice: Advice
        var cover: CallCover?
        /// "They've stopped", as the engine took it (not a mis-tap).
        var easedAt: Date?
    }

    /// What the contraction pattern said at each logged call, from the replay at the call's own
    /// moment. A call's cover is missing until the chain has evaluated that moment.
    static func callCovers(_ input: EngineInput, contractionState: LabourState) -> [CallCover] {
        var covers = input.previous?.callCovers ?? []
        if let call = input.lastCall, input.now == call.at, !covers.contains(where: { $0.callAt == call.at }) {
            covers.append(CallCover(callAt: call.at, contractionState: contractionState))
        }
        return covers
    }

    /// Whether the latest logged call still covers what's showing. Calling back is needed for a
    /// higher level at or above the call point, a call-level reason he didn't call about, or the
    /// contraction pattern reaching the call point when it hadn't when he called. Worked out from
    /// the log, so it stays news until he logs another call: a flag turned on after the call (even
    /// one that was on before and went off), a long contraction since the call, a new burst of 6 in
    /// 10 (one that starts after a 10-minute gap, if he called about 6 in 10), or a new run after
    /// "they've stopped". If the midwife changes the rule after the call, the pattern is judged
    /// against what it was at the call under the new rule. A contraction tap from before the call
    /// that reached this device late doesn't make the pattern news. A flag or profile reason the
    /// logging device wasn't showing still is, including GBS "labour has started" from a first
    /// contraction it hadn't heard about: the call script he read out didn't have it.
    static func callStatus(_ input: EngineInput, _ check: CallCheck, thresholds: ThresholdProfile) -> CallStatus? {
        guard let call = input.lastCall, check.state < .call999 else { return nil }
        let note = call.note
        var known = Set(note.reasons.map(longKey))
        for (flag, status) in input.redFlagStatus
        where status.isOn && status.changedAt > call.at && input.redFlags.contains(flag) {
            known.remove(flag.reason)
            if flag == .watersBroken {
                known.subtract([.gbsWithWaters, .gbsWithWatersPreterm])
            }
            if flag == .bleeding || flag == .severePain {
                known.remove(.bleedingWithSeverePain)
            }
        }
        let restarted = check.easedAt.map { $0 > call.at } ?? false
        let covered = coveredPattern(note: note, cover: check.cover, restarted: restarted, thresholds: thresholds)
        if covered >= .callTriage {
            known.insert(.regularPatternSustained)
        } else {
            known.remove(.regularPatternSustained)
        }

        var fresh: [ReasonCode] = []
        func add(_ reason: ReasonCode) {
            if !fresh.contains(where: { longKey($0) == longKey(reason) }) {
                fresh.append(reason)
            }
        }
        for reason in check.reasons + check.contractionAdvice.reasons
        where callReasons.contains(reason) && !known.contains(longKey(reason)) {
            add(reason)
        }
        let urgent = thresholds.urgentSingleDurationSec
        if hasLongContraction(input.contractions, after: call.at, now: input.now, limit: urgent) {
            add(.contractionOverUrgentDuration)
        }
        // A burst he called about carries on past the call; one after "they've stopped", or one that
        // starts 10 minutes or more after the contraction before it, is a new one.
        let bursts: [Contraction]
        if restarted, let eased = check.easedAt {
            bursts = input.contractions.filter { $0.start > eased }
        } else if known.contains(.tooManyInTenMinutes) {
            bursts = afterNewEpisode(input.contractions, after: call.at, now: input.now)
        } else {
            bursts = input.contractions
        }
        if hasBurst(bursts, after: call.at, now: input.now, count: thresholds.urgentCountIn10Min) {
            add(.tooManyInTenMinutes)
        }
        let rose = check.state > max(note.state, covered) && check.state >= .callTriage
        let contractionsRose = check.contractionAdvice.state == .callTriage && covered < .callTriage
        return rose || !fresh.isEmpty || contractionsRose ? .callBack(call, newReasons: fresh) : .acknowledged(call)
    }

    /// How far the contraction pattern had got when he called. After "they've stopped" since the
    /// call, nothing. If the rule has changed since, the replay at the call's moment under the new
    /// rule. Otherwise the more of that replay and what he saw: the call point only if the pattern
    /// was at it, not because an urgent reason (one long contraction, 6 in 10) was showing.
    static func coveredPattern(note: CallNote, cover: CallCover?, restarted: Bool, thresholds: ThresholdProfile)
        -> LabourState
    {
        if restarted { return .early }
        let replayed = min(cover?.contractionState ?? .early, .callTriage)
        if let rule = note.thresholds, rule != thresholds { return replayed }
        let seen =
            note.reasons.contains(.regularPatternSustained)
            ? LabourState.callTriage : min(note.contractionState, .establishing)
        return max(seen, replayed)
    }

    /// Codes that are one thing for a call: open or stopped, it's the same long contraction; with
    /// her weeks confirmed or not, it's the same GBS with her waters gone.
    static func longKey(_ reason: ReasonCode) -> ReasonCode {
        switch reason {
        case .openContractionOverUrgentDuration: .contractionOverUrgentDuration
        case .gbsWithWatersPreterm: .gbsWithWaters
        default: reason
        }
    }

    /// The contractions from the first one after `moment` that starts 10 minutes or more after the
    /// one before it: a new episode, not the burst carrying on.
    static func afterNewEpisode(_ contractions: [Contraction], after moment: Date, now: Date) -> [Contraction] {
        let starts = contractions.map(\.start).filter { $0 <= now }.sorted()
        var previous: Date?
        for start in starts {
            if start > moment, previous.map({ start.timeIntervalSince($0) >= EngineConstants.tenMinutesSec }) ?? true {
                return contractions.filter { $0.start >= start }
            }
            previous = start
        }
        return []
    }

    /// A contraction that passed `limit` after `moment`, stopped or still open.
    static func hasLongContraction(_ contractions: [Contraction], after moment: Date, now: Date, limit: Double)
        -> Bool
    {
        let latest = contractions.max(by: ContractionMetrics.chronological)
        return contractions.contains { contraction in
            guard contraction.start <= now, contraction.start.addingTimeInterval(limit) > moment else { return false }
            if let end = contraction.end {
                return end >= contraction.start && end.timeIntervalSince(contraction.start) > limit
            }
            return contraction.id == latest?.id && now.timeIntervalSince(contraction.start) > limit
        }
    }

    /// `count` or more starts inside 10 minutes, in a window that ends after `moment`.
    static func hasBurst(_ contractions: [Contraction], after moment: Date, now: Date, count: Int) -> Bool {
        let starts = contractions.map(\.start).filter { $0 <= now }.sorted()
        var tail = 0
        for head in starts.indices {
            while starts[head].timeIntervalSince(starts[tail]) >= EngineConstants.tenMinutesSec {
                tail += 1
            }
            if starts[head] > moment && head - tail + 1 >= count {
                return true
            }
        }
        return false
    }
}
