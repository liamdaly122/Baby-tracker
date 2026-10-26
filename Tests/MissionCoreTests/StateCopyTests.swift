import Foundation
import Testing

@testable import MissionCore

@Suite("State copy")
struct StateCopyTests {
    /// Engine copy must say what to do, never what is happening to her body.
    static let forbidden = [
        "established labour", "established labor", "active labour", "active labor",
        "you are in labour", "you are in labor", "you're in labour", "you're in labor", "diagnos",
    ]

    @Test("No engine copy contains a forbidden phrase", arguments: ContentRegion.allCases)
    func noForbiddenPhrases(region: ContentRegion) {
        let table = ThresholdTable.builtIn(for: region)
        let profiles = [
            table.defaults, table.profile(applying: [.adviceDurationSec: 45, .urgentSingleDurationSec: 90]),
        ]
        let metrics = [
            ContractionMetrics.compute([], thresholds: table.defaults, now: at(0)),
            ContractionMetrics.compute(
                regular(count: 17, every: 240, duration: 50), thresholds: table.defaults, now: at(3900)),
        ]
        var lines: [String] = []
        for thresholds in profiles {
            for state in LabourState.allCases {
                lines.append(StateCopy.headline(for: state, region: region))
                lines.append(StateCopy.detail(for: state, region: region, thresholds: thresholds))
            }
            for reason in ReasonCode.allCases {
                for metric in metrics {
                    lines.append(StateCopy.reasonLine(for: reason, metrics: metric, thresholds: thresholds))
                }
            }
        }
        for line in lines {
            #expect(!line.isEmpty)
            for phrase in Self.forbidden {
                #expect(!line.lowercased().contains(phrase), "\"\(line)\" contains \"\(phrase)\"")
            }
        }
    }

    @Test("UK headlines use NHS wording")
    func ukHeadlines() {
        #expect(StateCopy.headline(for: .callTriage, region: .uk) == "Time to call your maternity unit")
        #expect(StateCopy.headline(for: .callNow, region: .uk) == "Call your maternity unit now")
        #expect(StateCopy.headline(for: .call999, region: .uk) == "Call 999 now")
        #expect(StateCopy.headline(for: .call999, region: .us) == "Call 911 now")
    }

    @Test("Copy carries the thresholds actually in use")
    func thresholdsInCopy() {
        let midwife = ThresholdTable.builtIn(for: .uk).profile(applying: [
            .adviceIntervalSec: 240, .adviceDurationSec: 45,
        ])
        #expect(
            StateCopy.detail(for: .establishing, region: .uk, thresholds: midwife)
                == "Call your maternity unit when contractions are regular and come every 4 minutes or more often, "
                + "lasting 45 seconds or more, or sooner if you're worried."
        )
        let defaults = ThresholdTable.builtIn(for: .uk).defaults
        let empty = ContractionMetrics.compute([], thresholds: defaults, now: at(0))
        #expect(
            StateCopy.reasonLine(for: .contractionOverUrgentDuration, metrics: empty, thresholds: defaults)
                == "A contraction lasted longer than 2 minutes."
        )
    }

    @Test("Reason line summarises the pattern")
    func patternSummary() {
        let defaults = ThresholdTable.builtIn(for: .uk).defaults
        let metrics = ContractionMetrics.compute(
            regular(count: 17, every: 240, duration: 50), thresholds: defaults, now: at(3900))
        #expect(
            StateCopy.reasonLine(for: .regularPatternSustained, metrics: metrics, thresholds: defaults)
                == "Regular, every 4 min, lasting about 50 sec, for 65 min."
        )
    }

    @Test("Every reason has an https source")
    func sources() {
        for region in ContentRegion.allCases {
            for reason in ReasonCode.allCases {
                #expect(StateCopy.source(for: reason, region: region).url.scheme == "https")
            }
        }
    }

    @Test("Durations read naturally")
    func phrases() {
        #expect(StateCopy.phrase(seconds: 300) == "5 minutes")
        #expect(StateCopy.phrase(seconds: 60) == "1 minute")
        #expect(StateCopy.phrase(seconds: 90) == "90 seconds")
        #expect(StateCopy.phrase(seconds: 120) == "2 minutes")
    }
}
