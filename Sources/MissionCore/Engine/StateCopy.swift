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

    /// One line explaining a reason, with the numbers that triggered it.
    public static func reasonLine(
        for reason: ReasonCode,
        metrics: ContractionMetrics,
        thresholds: ThresholdProfile
    ) -> String {
        switch reason {
        case .regularPatternSustained:
            return "Regular, \(patternSummary(metrics))."
        case .patternNotYetSustained:
            return "Regular, \(patternSummary(metrics)) so far."
        case .patternBuilding:
            return "About \(intervalSummary(metrics)). Not at the call point yet."
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
            return "Contractions have eased. This advice stays up for \(minutes) minutes in case they pick up again."
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

    /// "5 minutes", "1 minute", "90 seconds".
    static func phrase(seconds: Double) -> String {
        let whole = Int(seconds.rounded())
        if whole >= 60 && whole % 60 == 0 {
            let minutes = whole / 60
            return minutes == 1 ? "1 minute" : "\(minutes) minutes"
        }
        return whole == 1 ? "1 second" : "\(whole) seconds"
    }

    /// "every 4 min, lasting about 50 sec, for 65 min"
    static func patternSummary(_ metrics: ContractionMetrics) -> String {
        "\(intervalSummary(metrics)), for \(Int((metrics.patternSustainedSec / 60).rounded())) min"
    }

    /// "every 4 min, lasting about 50 sec"
    static func intervalSummary(_ metrics: ContractionMetrics) -> String {
        var text = "every \(Int(((metrics.medianIntervalSec ?? 0) / 60).rounded())) min"
        if let duration = metrics.medianDurationSec {
            text += ", lasting about \(Int(duration.rounded())) sec"
        }
        return text
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
