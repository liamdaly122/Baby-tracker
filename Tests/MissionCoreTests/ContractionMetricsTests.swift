import Foundation
import Testing

@testable import MissionCore

@Suite("Contraction metrics")
struct ContractionMetricsTests {
    private let thresholds = ThresholdTable.builtIn(for: .uk).defaults

    @Test("Quantiles interpolate between ranks")
    func quantiles() {
        #expect(Stats.median([]) == nil)
        #expect(Stats.median([5]) == 5)
        #expect(Stats.median([1, 3]) == 2)
        #expect(Stats.median([180, 540, 240, 720]) == 390)
        #expect(Stats.interquartileRange([180, 540, 240, 720]) == 360)
        #expect(Stats.interquartileRange([240, 240, 240]) == 0)
    }

    @Test("Textbook pattern: 4-minute intervals, 50-second durations, perfectly regular")
    func textbook() {
        let metrics = ContractionMetrics.compute(
            regular(count: 17, every: 240, duration: 50),
            thresholds: thresholds,
            now: at(3900)
        )
        #expect(metrics.medianIntervalSec == 240)
        #expect(metrics.medianDurationSec == 50)
        #expect(metrics.regularity == 0)
        #expect(metrics.maxCountInTenMinutes == 3)
        #expect(metrics.patternSustainedSec == 3900)
        #expect(metrics.needsEdit.isEmpty)
        #expect(!metrics.isStale)
    }

    @Test("The analysis set only covers the last pattern window")
    func windowLimitsAnalysis() {
        let metrics = ContractionMetrics.compute(
            regular(count: 17, every: 240, duration: 50),
            thresholds: thresholds,
            now: at(3900)
        )
        // Starts from 300 s onwards: 480 … 3840.
        #expect(metrics.analysedCount == 15)
    }

    @Test("Silence doesn't count as pattern")
    func sustainedStopsGrowing() {
        let log = regular(count: 10, every: 240, duration: 50)  // last start 2160
        let soon = ContractionMetrics.compute(log, thresholds: thresholds, now: at(2200))
        let later = ContractionMetrics.compute(log, thresholds: thresholds, now: at(2600))
        #expect(soon.patternSustainedSec == 2200)
        #expect(later.patternSustainedSec == 2400)
    }

    @Test("Ten-minute counts use a half-open window")
    func tenMinuteWindow() {
        let everyTwoMinutes = ContractionMetrics.compute(
            regular(count: 6, every: 120, duration: 40),
            thresholds: thresholds,
            now: at(650)
        )
        #expect(everyTwoMinutes.maxCountInTenMinutes == 5)
        let every100 = ContractionMetrics.compute(
            regular(count: 6, every: 100, duration: 40),
            thresholds: thresholds,
            now: at(560)
        )
        #expect(every100.maxCountInTenMinutes == 6)
    }

    @Test("A forgotten stop is left out of duration stats and flagged")
    func forgottenStop() {
        var log = regular(count: 4, every: 300, duration: 50)
        let open = Contraction(start: at(1200), end: nil)
        log.append(open)
        let metrics = ContractionMetrics.compute(log, thresholds: thresholds, now: at(1600))
        #expect(metrics.medianDurationSec == 50)
        #expect(metrics.longestRecentDurationSec == 50)
        #expect(metrics.needsEdit == [open.id])
        #expect(metrics.openElapsedSec == 400)
        #expect(metrics.hasOpenOverUrgent)
        #expect(!metrics.hasClosedOverUrgent)
    }

    @Test("An open contraction under 5 minutes counts as ending now")
    func openCountsAsEndingNow() {
        var log = regular(count: 4, every: 300, duration: 50)
        log.append(Contraction(start: at(1200), end: nil))
        let metrics = ContractionMetrics.compute(log, thresholds: thresholds, now: at(1290))
        #expect(metrics.longestRecentDurationSec == 90)
        #expect(metrics.needsEdit.isEmpty)
        #expect(!metrics.hasOpenOverUrgent)
    }

    @Test("An end before its start is flagged and ignored")
    func endBeforeStart() {
        var log = regular(count: 4, every: 300, duration: 50)
        let broken = Contraction(start: at(1200), end: at(1100))
        log.append(broken)
        let metrics = ContractionMetrics.compute(log, thresholds: thresholds, now: at(1300))
        #expect(metrics.needsEdit == [broken.id])
        #expect(metrics.medianDurationSec == 50)
        #expect(metrics.analysedCount == 5)
    }

    @Test("A long gap splits the log and only the latest segment counts")
    func gapSplits() {
        let log =
            regular(count: 11, every: 240, duration: 50) + regular(count: 11, every: 240, duration: 50, first: 5400)
        let metrics = ContractionMetrics.compute(log, thresholds: thresholds, now: at(7860))
        #expect(metrics.segmentStart == at(5400))
        #expect(metrics.patternSustainedSec == 2460)
    }

    @Test("The log goes quiet 3 median intervals after the last start, and stale after 5")
    func staleness() {
        let log = regular(count: 10, every: 240, duration: 50)  // last start 2160
        let beforeQuiet = ContractionMetrics.compute(log, thresholds: thresholds, now: at(2880))
        #expect(!beforeQuiet.isQuiet)
        #expect(beforeQuiet.quietAt == at(2880))
        let quiet = ContractionMetrics.compute(log, thresholds: thresholds, now: at(2881))
        #expect(quiet.isQuiet)
        #expect(!quiet.isStale)
        #expect(quiet.analysedCount == 10)

        let justBefore = ContractionMetrics.compute(log, thresholds: thresholds, now: at(3360))
        #expect(!justBefore.isStale)
        #expect(justBefore.staleAt == at(3360))
        let after = ContractionMetrics.compute(log, thresholds: thresholds, now: at(3361))
        #expect(after.isStale)
        #expect(after.analysedCount == 0)
        #expect(after.patternSustainedSec == 0)
    }

    @Test("Nothing in the last hour is stale")
    func outsideWindowIsStale() {
        let metrics = ContractionMetrics.compute(
            regular(count: 4, every: 240, duration: 50),
            thresholds: thresholds,
            now: at(10_000)
        )
        #expect(metrics.isStale)
    }
}
