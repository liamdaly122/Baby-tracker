import Foundation

/// Statistics over the contraction log at a moment `now`. Pure: no clocks and no I/O.
///
/// Intervals are start to start; durations are start to end. The analysis set is the latest unbroken
/// segment of the log (split wherever a gap is over 3× the recent median interval) that falls inside
/// the pattern window. See docs/content-review-log.md for the reasoning behind each rule.
public struct ContractionMetrics: Codable, Sendable, Hashable {
    /// Contractions in the analysis set.
    public var analysedCount: Int
    public var medianIntervalSec: Double?
    public var medianDurationSec: Double?
    /// Interquartile range of intervals divided by the median interval. Lower is more regular.
    public var regularity: Double?
    /// The most contraction starts inside any 10 minutes of the pattern window.
    public var maxCountInTenMinutes: Int
    /// Longest valid duration in the pattern window, counting an open contraction as ending now.
    public var longestRecentDurationSec: Double?
    /// How long the current segment has been going, measured to the earlier of now and one median
    /// interval after its last start, so silence doesn't count as pattern.
    public var patternSustainedSec: Double
    public var segmentStart: Date?
    public var lastStart: Date?
    /// Seconds the latest contraction has been open, if it is still being timed.
    public var openElapsedSec: Double?
    /// Contractions to fix: forgotten stops, starts that never got a stop, or an end before the start.
    public var needsEdit: [UUID]
    /// No current pattern: the last start is outside the window or long overdue for the next one.
    public var isStale: Bool
    /// When the pattern goes stale if no new contraction starts.
    public var staleAt: Date?
    /// A closed contraction in the pattern window lasted longer than the urgent threshold.
    public var hasClosedOverUrgent: Bool
    /// The open contraction has been running longer than the urgent threshold.
    public var hasOpenOverUrgent: Bool

    public static func compute(
        _ contractions: [Contraction],
        thresholds: ThresholdProfile,
        now: Date
    ) -> ContractionMetrics {
        let sorted = contractions.sorted(by: chronological)
        let durations = validDurations(sorted, now: now)
        let windowStart = now.addingTimeInterval(-thresholds.patternWindowSec)
        let recent = sorted.filter { $0.start >= windowStart }
        let splitMedian = Stats.median(intervals(recent))
        let lastStart = sorted.last?.start
        let openElapsed = sorted.last.flatMap { $0.end == nil ? max(0, now.timeIntervalSince($0.start)) : nil }

        let staleAt = splitMedian.flatMap { median in
            lastStart?.addingTimeInterval(EngineConstants.gapSplitFactor * median)
        }
        let isStale =
            lastStart.map { $0 < windowStart } ?? false || staleAt.map { now > $0 } ?? false
        let segment = isStale ? [] : latestSegment(sorted, splitMedian: splitMedian)
        let analysed = segment.filter { $0.start >= windowStart }

        var medianInterval: Double?
        var regularity: Double?
        var medianDuration: Double?
        if analysed.count >= EngineConstants.minimumContractions {
            let analysedIntervals = intervals(analysed)
            medianInterval = Stats.median(analysedIntervals)
            if let medianInterval, medianInterval > 0, let iqr = Stats.interquartileRange(analysedIntervals) {
                regularity = iqr / medianInterval
            }
            medianDuration = Stats.median(analysed.compactMap { durations.valid[$0.id] })
        }

        var sustained = 0.0
        if let medianInterval, let first = segment.first, let lastStart {
            let currentUntil = min(now, lastStart.addingTimeInterval(medianInterval))
            sustained = max(0, currentUntil.timeIntervalSince(first.start))
        }

        let recentDurations = recent.compactMap { durations.valid[$0.id] }
        let urgent = thresholds.urgentSingleDurationSec
        return ContractionMetrics(
            analysedCount: analysed.count,
            medianIntervalSec: medianInterval,
            medianDurationSec: medianDuration,
            regularity: regularity,
            maxCountInTenMinutes: maxStartsInTenMinutes(recent),
            longestRecentDurationSec: recentDurations.max(),
            patternSustainedSec: sustained,
            segmentStart: segment.first?.start,
            lastStart: lastStart,
            openElapsedSec: openElapsed,
            needsEdit: durations.needsEdit,
            isStale: isStale,
            staleAt: staleAt,
            hasClosedOverUrgent: recent.contains { $0.end != nil && (durations.valid[$0.id] ?? 0) > urgent },
            hasOpenOverUrgent: (openElapsed ?? 0) > urgent
        )
    }

    /// Start order, with the ID as a tie-break so the result never depends on input order.
    static func chronological(_ lhs: Contraction, _ rhs: Contraction) -> Bool {
        if lhs.start != rhs.start { return lhs.start < rhs.start }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    static func intervals(_ sorted: [Contraction]) -> [Double] {
        zip(sorted, sorted.dropFirst()).map { $1.start.timeIntervalSince($0.start) }
    }

    /// Durations usable for statistics, and the contractions that need fixing.
    private static func validDurations(
        _ sorted: [Contraction],
        now: Date
    ) -> (valid: [UUID: Double], needsEdit: [UUID]) {
        var valid: [UUID: Double] = [:]
        var needsEdit: [UUID] = []
        for (index, contraction) in sorted.enumerated() {
            if let end = contraction.end {
                if end >= contraction.start {
                    valid[contraction.id] = end.timeIntervalSince(contraction.start)
                } else {
                    needsEdit.append(contraction.id)
                }
            } else if index == sorted.count - 1 {
                // Still being timed: counts as ending now, unless it has clearly been forgotten.
                let elapsed = max(0, now.timeIntervalSince(contraction.start))
                if elapsed > EngineConstants.forgotStopSec {
                    needsEdit.append(contraction.id)
                } else {
                    valid[contraction.id] = elapsed
                }
            } else {
                // A later contraction started before this one was stopped.
                needsEdit.append(contraction.id)
            }
        }
        return (valid, needsEdit)
    }

    /// The run of contractions back from the latest one with no gap over 3× the recent median.
    private static func latestSegment(_ sorted: [Contraction], splitMedian: Double?) -> [Contraction] {
        guard let last = sorted.indices.last else { return [] }
        guard let splitMedian else { return [sorted[last]] }
        var first = last
        while first > 0 {
            let gap = sorted[first].start.timeIntervalSince(sorted[first - 1].start)
            if gap > EngineConstants.gapSplitFactor * splitMedian { break }
            first -= 1
        }
        return Array(sorted[first...])
    }

    /// The most starts inside any half-open 10-minute window [t, t + 600).
    private static func maxStartsInTenMinutes(_ sorted: [Contraction]) -> Int {
        var best = 0
        var tail = 0
        for head in sorted.indices {
            while sorted[head].start.timeIntervalSince(sorted[tail].start) >= EngineConstants.tenMinutesSec {
                tail += 1
            }
            best = max(best, head - tail + 1)
        }
        return best
    }
}

/// Order statistics with linear interpolation between ranks (the R type-7 / NumPy default).
enum Stats {
    static func quantile(_ values: [Double], _ probability: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let position = probability * Double(sorted.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = min(lower + 1, sorted.count - 1)
        return sorted[lower] + (position - Double(lower)) * (sorted[upper] - sorted[lower])
    }

    static func median(_ values: [Double]) -> Double? {
        quantile(values, 0.5)
    }

    static func interquartileRange(_ values: [Double]) -> Double? {
        guard let firstQuartile = quantile(values, 0.25), let thirdQuartile = quantile(values, 0.75) else {
            return nil
        }
        return thirdQuartile - firstQuartile
    }
}
