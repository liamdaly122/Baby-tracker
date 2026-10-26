import Foundation

/// Where a line of engine copy comes from, shown under it in the UI (App Store 1.4.1).
public struct CopySource: Sendable, Hashable {
    public var title: String
    public var url: URL
}

/// Words for the state banner. Instructional only ("time to call"), never diagnostic, and with no
/// humour variants: this is Flight Surgeon copy. A test checks every line against forbidden phrases.
public enum StateCopy {
    public static func headline(for state: LabourState, region: ContentRegion) -> String {
        switch state {
        case .early: "No regular pattern yet"
        case .establishing: "Keep timing"
        case .callTriage: "Time to call \(unit(region))"
        case .callNow: "Call \(unit(region)) now"
        case .call999: "Call \(emergencyNumber(region)) now"
        }
    }

    /// The detail line for an evaluation. Like `detail(for:region:thresholds:)`, but when the pattern
    /// still has to hold it says how long is left, and after "they've stopped" it says what to do.
    public static func detail(for output: EngineOutput, region: ContentRegion, thresholds: ThresholdProfile) -> String {
        let remaining = output.requiredSustainedSec - output.metrics.patternSustainedSec
        if output.reasons.contains(.patternNotYetSustained) && remaining > 0 {
            let minutesLeft = Int((remaining / 60).rounded(.up))
            return "Call \(unit(region)) once this has gone on for \(phrase(seconds: output.requiredSustainedSec)). "
                + "About \(minutesLeft) min to go. Call sooner if you were told to, or if you're worried."
        }
        if output.state == .early && output.reasons.contains(.contractionsStopped) {
            return "Time them again if they come back. You can call \(unit(region)) any time you're worried."
        }
        return detail(for: output.state, region: region, thresholds: thresholds)
    }

    public static func detail(for state: LabourState, region: ContentRegion, thresholds: ThresholdProfile) -> String {
        switch state {
        case .early:
            return "Rest, eat and drink. Time a few contractions when things change. "
                + "You can call \(unit(region)) any time you're worried."
        case .establishing:
            var rule = "come every \(phrase(seconds: thresholds.adviceIntervalSec)) or more often"
            if thresholds.adviceDurationSec > 0 {
                rule += ", lasting \(phrase(seconds: thresholds.adviceDurationSec)) or more"
            }
            return "Call \(unit(region)) when contractions are regular and \(rule), or sooner if you're worried."
        case .callTriage:
            switch region {
            case .uk: return "Phone before you set off. They may advise staying at home for a while longer."
            case .us: return "Call before you set off. They'll tell you whether to come in yet."
            }
        case .callNow:
            switch region {
            case .uk: return "Don't wait until morning. Phone them now."
            case .us: return "Don't wait. Call them now."
            }
        case .call999:
            return "Then call \(unit(region)). Stay with her."
        }
    }

    /// One line explaining a reason, with the numbers that triggered it. Pass `now` so the quiet-log
    /// line can say how long it has been.
    public static func reasonLine(
        for reason: ReasonCode,
        metrics: ContractionMetrics,
        thresholds: ThresholdProfile,
        now: Date? = nil
    ) -> String {
        switch reason {
        case .regularPatternSustained:
            guard hasRate(metrics) else { return "They met the call point earlier. Nothing recent to measure yet." }
            return "\(lead(metrics, thresholds)), \(patternSummary(metrics, thresholds: thresholds))."
        case .patternNotYetSustained:
            guard hasRate(metrics) else {
                return "They were close to the call point earlier. Nothing recent to measure yet."
            }
            return "\(lead(metrics, thresholds)), \(patternSummary(metrics, thresholds: thresholds)) so far."
        case .patternBuilding:
            guard hasRate(metrics) else { return "They were building earlier. Nothing recent to measure yet." }
            return "About \(intervalSummary(metrics, thresholds: thresholds)). Not at the call point yet."
        case .noRecentTaps:
            var quiet = "Nothing logged for a while."
            if let now, let lastStart = metrics.lastStart {
                quiet = "Nothing logged for \(Int(now.timeIntervalSince(lastStart) / 60)) min."
            }
            return quiet + " Are they still coming? Keep timing them, or tell the app they've stopped."
        case .contractionsStopped:
            return "You said the contractions have stopped. Time them again if they come back."
        case .gestationUnknown:
            return "We don't know how many weeks she is. If she could be under 37 weeks, call now."
        case .notEnoughContractions:
            return "Not enough recent contractions to see a pattern."
        case .noRegularPattern:
            return "Contractions are irregular so far."
        case .contractionOverUrgentDuration:
            return "A contraction lasted longer than \(phrase(seconds: thresholds.urgentSingleDurationSec))."
        case .openContractionOverUrgentDuration:
            return "This contraction has been timing for over \(phrase(seconds: thresholds.urgentSingleDurationSec)). "
                + "If it's still going, call now. If you forgot to stop the timer, fix it."
        case .tooManyInTenMinutes:
            return "\(thresholds.urgentCountIn10Min) or more contractions in 10 minutes."
        case .watersBroken:
            return "Her waters have broken. Use a pad, not a tampon, so the colour can be checked."
        case .watersColoured:
            return "The waters are green, brown or smell. Tell them straight away."
        case .bleeding:
            return "She's bleeding, more than a small pink-tinged show."
        case .reducedMovements:
            return "The baby is moving less than usual. Call now, even at night."
        case .preterm:
            return "She's under 37 weeks."
        case .urgeToPush:
            return "She has a strong urge to push."
        case .cordVisible:
            return "The cord can be felt or seen. Don't touch it. Help her onto her knees with her bottom up, "
                + "or onto her left side with her hips raised."
        case .heavyBleeding:
            return "Heavy bleeding."
        case .seizureCollapse:
            return "She's had a seizure or collapsed."
        case .patternEasing:
            let minutes = Int(EngineConstants.demotionDwellSec / 60)
            return "The pattern has slowed or paused. "
                + "This advice stays up for \(minutes) minutes in case it picks up again."
        }
    }

    public static func source(for reason: ReasonCode, region: ContentRegion) -> CopySource {
        switch reason {
        case .cordVisible:
            return rcogCordProlapse
        case .regularPatternSustained, .patternNotYetSustained, .patternBuilding, .notEnoughContractions,
            .noRegularPattern:
            return region == .us ? clevelandClinic : nhsSignsOfLabour
        default:
            return nhsSignsOfLabour
        }
    }

    static func unit(_ region: ContentRegion) -> String {
        switch region {
        case .uk: "your maternity unit"
        case .us: "your provider or labor and delivery unit"
        }
    }

    static func emergencyNumber(_ region: ContentRegion) -> String {
        switch region {
        case .uk: "999"
        case .us: "911"
        }
    }

    /// "5 minutes", "1 minute", "90 seconds", "1 hour".
    public static func phrase(seconds: Double) -> String {
        let whole = Int(seconds.rounded())
        if whole >= 3600 && whole % 3600 == 0 {
            let hours = whole / 3600
            return hours == 1 ? "1 hour" : "\(hours) hours"
        }
        if whole >= 60 && whole % 60 == 0 {
            let minutes = whole / 60
            return minutes == 1 ? "1 minute" : "\(minutes) minutes"
        }
        return whole == 1 ? "1 second" : "\(whole) seconds"
    }

    /// The text for the still-going nudge on an open contraction.
    public static func stillGoingTitle(thresholds: ThresholdProfile) -> String {
        "Contraction over \(phrase(seconds: thresholds.urgentSingleDurationSec))?"
    }

    public static func stillGoingBody(region: ContentRegion) -> String {
        "If it's still going, call \(unit(region)) now. If you forgot to stop the timer, fix it."
    }

    /// "Regular" when the recent intervals are even, "Frequent" when they're uneven but quick.
    static func lead(_ metrics: ContractionMetrics, _ thresholds: ThresholdProfile) -> String {
        isUneven(metrics, thresholds) ? "Frequent" : "Regular"
    }

    /// Uneven, or met on frequency with a median over the rule: show the range, never one number
    /// that's over the call point.
    static func isUneven(_ metrics: ContractionMetrics, _ thresholds: ThresholdProfile) -> Bool {
        metrics.recentRegularity.map { $0 > thresholds.regularityCV } ?? false
            || (metrics.recentMedianIntervalSec.map { $0 > thresholds.adviceIntervalSec } ?? false
                && metrics.recentShortestIntervalSec.map { $0 <= thresholds.adviceIntervalSec } ?? false)
    }

    /// "every 4 min, lasting about 50 sec, for 65 min"
    static func patternSummary(_ metrics: ContractionMetrics, thresholds: ThresholdProfile) -> String {
        let minutes = Int((metrics.patternSustainedSec / 60).rounded())
        return "\(intervalSummary(metrics, thresholds: thresholds)), for \(minutes) min"
    }

    /// False while advice is held and the current log has too few contractions to measure.
    static func hasRate(_ metrics: ContractionMetrics) -> Bool {
        metrics.recentMedianIntervalSec != nil || metrics.medianIntervalSec != nil
    }

    /// "every 4 min, lasting about 50 sec", or "every 2 min to 5 min" when the gaps are uneven.
    /// Uses the current rate, the same numbers the call rule uses.
    static func intervalSummary(_ metrics: ContractionMetrics, thresholds: ThresholdProfile) -> String {
        let limit = thresholds.adviceIntervalSec
        var text: String
        if isUneven(metrics, thresholds), let shortest = metrics.recentShortestIntervalSec,
            let longest = metrics.recentLongestIntervalSec
        {
            text = "every \(clock(shortest, threshold: limit)) to \(clock(longest, threshold: limit))"
        } else {
            let median = metrics.recentMedianIntervalSec ?? metrics.medianIntervalSec ?? 0
            text = "every \(clock(median, threshold: limit))"
        }
        if let duration = metrics.medianDurationSec {
            let rule = thresholds.adviceDurationSec > 0 ? thresholds.adviceDurationSec : nil
            text += ", lasting about \(Int(guardedRound(duration, step: 1, threshold: rule, metAtOrAbove: true))) sec"
        }
        return text
    }

    /// A gap as "4 min" or "5:20", to the nearest 5 seconds but never rounded across `threshold`: a
    /// gap over the rule never reads as meeting it, and one meeting it never reads as over.
    public static func clock(_ seconds: Double, threshold: Double? = nil) -> String {
        let whole = Int(guardedRound(seconds, step: 5, threshold: threshold))
        let minutes = whole / 60
        let rest = whole % 60
        if minutes == 0 { return "\(rest) sec" }
        return rest == 0 ? "\(minutes) min" : String(format: "%d:%02d", minutes, rest)
    }

    /// Rounds to the nearest `step`, then moves to the step on the right side of `threshold` if
    /// rounding crossed it. Intervals meet their rule at or under the threshold; durations meet
    /// theirs at or above it (`metAtOrAbove`), so the side that counts differs.
    static func guardedRound(_ value: Double, step: Double, threshold: Double?, metAtOrAbove: Bool = false) -> Double {
        let nearest = (value / step).rounded() * step
        guard let threshold else { return nearest }
        let meets: (Double) -> Bool = metAtOrAbove ? { $0 >= threshold } : { $0 <= threshold }
        guard meets(nearest) != meets(value) else { return nearest }
        let roundedUp = (value / step).rounded(.up) * step
        let roundedDown = (value / step).rounded(.down) * step
        return meets(roundedUp) == meets(value) ? roundedUp : roundedDown
    }

    private static let nhsSignsOfLabour = CopySource(
        title: "NHS: Signs that labour has begun",
        url: URL(string: "https://www.nhs.uk/pregnancy/labour-and-birth/signs-of-labour/signs-that-labour-has-begun/")
            ?? URL(fileURLWithPath: "/")
    )

    private static let clevelandClinic = CopySource(
        title: "Cleveland Clinic: Labor and delivery",
        url: URL(string: "https://my.clevelandclinic.org/health/articles/9676-labor-delivery")
            ?? URL(fileURLWithPath: "/")
    )

    private static let rcogCordProlapse = CopySource(
        title: "RCOG: Umbilical cord prolapse in late pregnancy",
        url: URL(
            string:
                "https://www.rcog.org.uk/for-the-public/browse-our-patient-information/umbilical-cord-prolapse-in-late-pregnancy/"
        ) ?? URL(fileURLWithPath: "/")
    )
}
