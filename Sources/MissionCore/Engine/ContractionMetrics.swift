import Foundation

/// Statistics over the contraction log at a moment `now`. Pure: no clocks and no I/O.
///
/// Intervals are start to start; durations are start to end. The analysis set is the latest unbroken
/// run of the log (split wherever a gap is over 5× the run's pace) inside the last hour. The call rule
/// is judged on the current rate: the contractions in the last 20 minutes, or the last 4 if there are
/// fewer. A gap close to a whole multiple of the run's typical interval, in an otherwise regular run
/// that is back on rhythm after it, counts as missed taps. Starts more than a minute in the future
/// are bad timestamps and are left out. See docs/content-review-log.md for each rule.
public struct ContractionMetrics: Codable, Sendable, Hashable {
    /// Contractions in the analysis set.
    public var analysedCount: Int
    /// Median start-to-start interval over the analysis set.
    public var medianIntervalSec: Double?
    public var medianDurationSec: Double?
    /// Interquartile range of intervals divided by the median interval. Lower is more regular.
    public var regularity: Double?
    /// Contractions in the current-rate set (the last 20 minutes, or the last 4).
    public var recentCount: Int
    /// The current-rate set's intervals, with missed-tap gaps split, in start order.
    public var recentIntervalsSec: [Double]
    /// Median interval of the current-rate set.
    public var recentMedianIntervalSec: Double?
    /// Spread (IQR divided by median) of the current-rate set's intervals.
    public var recentRegularity: Double?
    /// Upper quartile of the current-rate set's intervals: three in four are at or under this.
    public var recentUpperQuartileSec: Double?
    /// The analysis set's intervals, with missed-tap gaps split, in start order.
    public var runIntervalsSec: [Double]
    public var recentShortestIntervalSec: Double?
    public var recentLongestIntervalSec: Double?
    /// The run's pace: the upper quartile of its gaps in the hour before its last start. Splitting,
    /// quiet and stale are measured in it. It only changes when he taps.
    public var paceSec: Double?
    /// The most contraction starts inside any 10 minutes of the last hour.
    public var maxCountInTenMinutes: Int
    /// Longest valid duration in the last hour, counting an open contraction as ending now.
    public var longestRecentDurationSec: Double?
    /// How long the current run has been going, measured to the earlier of now and `sustainedUntil`,
    /// so silence doesn't count as pattern. It never shrinks without a new tap.
    public var patternSustainedSec: Double
    /// One typical interval after the last start: when the sustained time stops growing.
    public var sustainedUntil: Date?
    public var segmentStart: Date?
    public var lastStart: Date?
    /// Seconds the latest contraction has been open, if it is still being timed.
    public var openElapsedSec: Double?
    /// Contractions to fix: forgotten stops, starts that never got a stop, an end before the start,
    /// or a start in the future.
    public var needsEdit: [UUID]
    /// Nothing logged for 3× the pace: time to ask whether contractions are still coming.
    public var isQuiet: Bool
    /// When the log goes quiet if no new contraction starts.
    public var quietAt: Date?
    /// No current pattern: the last start is outside the last hour or long overdue for the next one.
    public var isStale: Bool
    /// When the pattern goes stale if no new contraction starts.
    public var staleAt: Date?
    /// The next moment a contraction leaves the 20-minute rate window or the hour, which can change
    /// the advice with no tap.
    public var nextWindowChangeAt: Date?
    /// Gaps in the current run that look like missed taps.
    public var missedTapGaps: [MissedTapGap]
    /// A closed contraction in the last hour lasted longer than the urgent threshold.
    public var hasClosedOverUrgent: Bool
    /// The open contraction has been running longer than the urgent threshold.
    public var hasOpenOverUrgent: Bool

    /// `runStartsAfter`: when he said the contractions stopped. The pattern only counts contractions
    /// after it; the urgent rules still look back over the whole hour.
    public static func compute(
        _ contractions: [Contraction],
        thresholds: ThresholdProfile,
        now: Date,
        runStartsAfter: Date? = nil
    ) -> ContractionMetrics {
        let horizon = now.addingTimeInterval(EngineConstants.futureToleranceSec)
        let all = contractions.sorted(by: chronological)
        let future = all.filter { $0.start > horizon }
        let sorted = all.filter { $0.start <= horizon }
        let durations = validDurations(sorted, now: now)
        let windowStart = now.addingTimeInterval(-EngineConstants.analysisWindowSec)
        let recent = sorted.filter { $0.start >= windowStart }
        let runnable = runStartsAfter.map { cut in sorted.filter { $0.start > cut } } ?? sorted
        let lastStart = sorted.last?.start
        // Anchored at the last start, not now, so the pace (and the run it splits) can't drift in silence.
        let paceStart = (lastStart ?? now).addingTimeInterval(-EngineConstants.analysisWindowSec)
        let pace =
            Stats.quantile(intervals(runnable.filter { $0.start >= paceStart }), 0.75)
            ?? Stats.quantile(intervals(sorted.filter { $0.start >= paceStart }), 0.75)
        let openElapsed = sorted.last.flatMap { $0.end == nil ? max(0, now.timeIntervalSince($0.start)) : nil }

        let measure = pace ?? thresholds.adviceIntervalSec
        let quietAt = lastStart?.addingTimeInterval(EngineConstants.quietFactor * measure)
        let staleAt = lastStart?.addingTimeInterval(EngineConstants.gapSplitFactor * measure)
        let isStale = lastStart.map { $0 < windowStart } ?? false || staleAt.map { now > $0 } ?? false
        let isQuiet = openElapsed == nil && quietAt.map { now > $0 } ?? false
        let segment = isStale ? [] : latestSegment(runnable, pace: pace)
        let analysed = segment.filter { $0.start >= windowStart }
        // Judged on the whole run, which only changes when he taps, so nothing gets filled in during a lull.
        let gaps = missedTapGaps(segment, regularityCV: thresholds.regularityCV)

        var medianInterval: Double?
        var regularity: Double?
        var medianDuration: Double?
        var rate = RateStats()
        var analysedIntervals: [Double] = []
        if analysed.count >= EngineConstants.minimumContractions {
            analysedIntervals = intervals(analysed, imputing: gaps)
            medianInterval = Stats.median(analysedIntervals)
            regularity = Stats.spread(analysedIntervals)
            medianDuration = Stats.median(analysed.compactMap { durations.valid[$0.id] })
            rate = RateStats(analysed, imputing: gaps, now: now)
        }

        // The cap comes from the whole run, the same set as its first start, so it can't move back.
        var sustained = 0.0
        var sustainedUntil: Date?
        if medianInterval != nil, let first = segment.first, let lastStart,
            let runInterval = Stats.median(intervals(segment))
        {
            let until = lastStart.addingTimeInterval(runInterval)
            sustainedUntil = until
            sustained = max(0, min(now, until).timeIntervalSince(first.start))
        }

        let exits =
            rate.set.map { $0.start.addingTimeInterval(EngineConstants.rateWindowSec) }
            + recent.map { $0.start.addingTimeInterval(EngineConstants.analysisWindowSec) }
        let recentDurations = recent.compactMap { durations.valid[$0.id] }
        let urgent = thresholds.urgentSingleDurationSec
        return ContractionMetrics(
            analysedCount: analysed.count,
            medianIntervalSec: medianInterval,
            medianDurationSec: medianDuration,
            regularity: regularity,
            recentCount: rate.set.count,
            recentIntervalsSec: rate.values,
            recentMedianIntervalSec: Stats.median(rate.values),
            recentRegularity: Stats.spread(rate.values),
            recentUpperQuartileSec: Stats.quantile(rate.values, 0.75),
            runIntervalsSec: analysedIntervals,
            recentShortestIntervalSec: rate.values.min(),
            recentLongestIntervalSec: rate.values.max(),
            paceSec: pace,
            maxCountInTenMinutes: maxStartsInTenMinutes(recent),
            longestRecentDurationSec: recentDurations.max(),
            patternSustainedSec: sustained,
            sustainedUntil: sustainedUntil,
            segmentStart: segment.first?.start,
            lastStart: lastStart,
            openElapsedSec: openElapsed,
            needsEdit: durations.needsEdit + future.map(\.id),
            isQuiet: isQuiet,
            quietAt: quietAt,
            isStale: isStale,
            staleAt: staleAt,
            nextWindowChangeAt: exits.filter { $0 > now }.min(),
            missedTapGaps: gaps,
            hasClosedOverUrgent: recent.contains { $0.end != nil && (durations.valid[$0.id] ?? 0) > urgent },
            hasOpenOverUrgent: (openElapsed ?? 0) > urgent
        )
    }

    /// Start order, with the ID as a tie-break so the result never depends on input order.
    public static func chronological(_ lhs: Contraction, _ rhs: Contraction) -> Bool {
        if lhs.start != rhs.start { return lhs.start < rhs.start }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    static func intervals(_ sorted: [Contraction]) -> [Double] {
        zip(sorted, sorted.dropFirst()).map { $1.start.timeIntervalSince($0.start) }
    }

    /// Intervals with each missed-tap gap split into the intervals it probably held.
    static func intervals(_ sorted: [Contraction], imputing gaps: [MissedTapGap]) -> [Double] {
        var missed: [GapKey: Int] = [:]
        for gap in gaps {
            missed[GapKey(after: gap.after, before: gap.before)] = gap.estimatedMissed
        }
        var result: [Double] = []
        for (earlier, later) in zip(sorted, sorted.dropFirst()) {
            let gap = later.start.timeIntervalSince(earlier.start)
            let pieces = (missed[GapKey(after: earlier.start, before: later.start)] ?? 0) + 1
            result += repeatElement(gap / Double(pieces), count: pieces)
        }
        return result
    }

    /// Gaps of about 2× to 5× the run's typical interval, in a run that is otherwise regular and
    /// back on rhythm straight after the gap, and only a minority of its gaps. A slowdown, an uneven
    /// run or a two-speed pattern such as coupled contractions never gets gaps filled in, so missing
    /// data can't make a pattern look more regular or quicker than it was.
    static func missedTapGaps(_ run: [Contraction], regularityCV: Double) -> [MissedTapGap] {
        let raw = intervals(run)
        guard let typical = Stats.median(raw), typical > 0 else { return [] }
        var candidates: [(index: Int, gap: MissedTapGap)] = []
        for (index, gap) in raw.enumerated() {
            let ratio = gap / typical
            let multiple = Int(ratio.rounded())
            guard (2...Int(EngineConstants.gapSplitFactor)).contains(multiple),
                abs(ratio - Double(multiple)) <= EngineConstants.missedTapTolerance + 1e-9,
                index + 1 < raw.count, abs(raw[index + 1] / typical - 1) <= EngineConstants.rhythmTolerance
            else { continue }
            let gapInfo = MissedTapGap(
                after: run[index].start, before: run[index + 1].start, estimatedMissed: multiple - 1)
            candidates.append((index, gapInfo))
        }
        let candidateIndices = Set(candidates.map(\.index))
        let others = raw.enumerated().filter { !candidateIndices.contains($0.offset) }.map(\.element)
        guard !candidates.isEmpty, others.count >= EngineConstants.minimumContractions - 1,
            Double(candidates.count) <= EngineConstants.missedTapMaxShare * Double(raw.count),
            let spread = Stats.spread(others), spread <= regularityCV
        else { return [] }
        return candidates.map(\.gap)
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

    /// The run of contractions back from the latest one with no gap over 5× the pace.
    private static func latestSegment(_ sorted: [Contraction], pace: Double?) -> [Contraction] {
        guard let last = sorted.indices.last else { return [] }
        guard let pace else { return [sorted[last]] }
        var first = last
        while first > 0 {
            let gap = sorted[first].start.timeIntervalSince(sorted[first - 1].start)
            if gap > EngineConstants.gapSplitFactor * pace { break }
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

/// A gap in the log that probably hides contractions nobody tapped.
public struct MissedTapGap: Codable, Sendable, Hashable {
    /// The start before the gap.
    public var after: Date
    /// The start after the gap.
    public var before: Date
    /// About how many contractions are missing from the gap.
    public var estimatedMissed: Int
}

private struct GapKey: Hashable {
    var after: Date
    var before: Date
}

/// The current rate: the last 20 minutes of the run, or its last 4 contractions if that's more.
private struct RateStats {
    var set: [Contraction] = []
    var values: [Double] = []

    init() {}

    init(_ run: [Contraction], imputing gaps: [MissedTapGap], now: Date) {
        let rateStart = now.addingTimeInterval(-EngineConstants.rateWindowSec)
        set = run.filter { $0.start >= rateStart }
        if set.count < EngineConstants.minimumContractions {
            set = Array(run.suffix(EngineConstants.minimumContractions))
        }
        values = ContractionMetrics.intervals(set, imputing: gaps)
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

    /// Interquartile range divided by the median, or nil for an empty or zero-median set.
    static func spread(_ values: [Double]) -> Double? {
        guard let median = median(values), median > 0, let iqr = interquartileRange(values) else { return nil }
        return iqr / median
    }

}
